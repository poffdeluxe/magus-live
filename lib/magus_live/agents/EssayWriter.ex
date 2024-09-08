defmodule MagusLive.Agents.EssayWriterState do
  defstruct [
    :topic,
    :latest_revision,
    :latest_feedback,
    num_of_revisions: 0
  ]
end

defmodule MagusLive.Agents.EssayWriter do
  alias MagusLive.Agents.EssayWriterState
  alias Magus.GraphAgent
  alias Magus.AgentChain

  alias LangChain.PromptTemplate

  @base_writer_first_draft_template ~S|
You are a writer who is working on a three-paragraph essay on the following topic: <%= @topic %>.
|

  @base_writer_with_revision_template ~S|
You are a writer who is working on a three-paragraph essay on the following topic: <%= @topic %>.
This is a previous revision of the essay:

  <%= @latest_revision %>

  On the latest revision, you received the following feedback:

  <%= @latest_feedback %>

  Write a new revision of the essay, incorporating the feedback where applicable. Begin immediately below:
|

  @base_grader_template ~S|
You are a professor grading and providing feedback on an essay on the following topic: <%= @topic %>.

This is the essay:

<%= @latest_revision %>

Provide feedback on this essay below:
|

  def get_agent() do
    writer_first_draft_template =
      PromptTemplate.from_template!(@base_writer_first_draft_template)

    writer_template =
      PromptTemplate.from_template!(@base_writer_with_revision_template)

    write_first_draft_node = fn chain, state ->
      {:ok, content, _response} =
        chain
        |> AgentChain.add_message(PromptTemplate.to_message!(writer_first_draft_template, state))
        |> AgentChain.run()

      %EssayWriterState{state | latest_revision: content, num_of_revisions: 1}
    end

    write_node = fn chain, state ->
      {:ok, content, _response} =
        chain
        |> AgentChain.add_message(PromptTemplate.to_message!(writer_template, state))
        |> AgentChain.run()

      %EssayWriterState{
        state
        | latest_revision: content,
          num_of_revisions: state.num_of_revisions + 1
      }
    end

    feedback_node = fn chain, state ->
      grade_template =
        PromptTemplate.from_template!(@base_grader_template)

      {:ok, content, _response} =
        chain
        |> AgentChain.add_message(PromptTemplate.to_message!(grade_template, state))
        |> AgentChain.run()

      %EssayWriterState{state | latest_feedback: content}
    end

    should_continue = fn %EssayWriterState{num_of_revisions: num_of_revisions} = _state ->
      case num_of_revisions > 2 do
        true -> :end
        false -> :provide_feedback
      end
    end

    %GraphAgent{
      name: "Essay Writer",
      final_output_property: :latest_revision,
      initial_state: %EssayWriterState{}
    }
    |> GraphAgent.add_node(:first_draft, write_first_draft_node)
    |> GraphAgent.add_node(:write, write_node)
    |> GraphAgent.add_node(:provide_feedback, feedback_node)
    |> GraphAgent.set_entry_point(:first_draft)
    |> GraphAgent.add_edge(:first_draft, :provide_feedback)
    |> GraphAgent.add_edge(:provide_feedback, :write)
    |> GraphAgent.add_conditional_edges(:write, [:end, :provide_feedback], should_continue)
  end
end
