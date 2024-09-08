defmodule MagusLive.Agents.Storm.RefineOutline do
  alias LangChain.PromptTemplate
  alias Magus.AgentChain
  alias MagusLive.Agents.StormState
  alias MagusLive.Agents.Storm.Util

  @json_schema_path "agent_schema/storm/generate_outline.json"

  @base_prompt_template ~S|
You are a Wikipedia writer. You have gathered information from experts and search engines. Now, you are refining the outline of the Wikipedia page. \
You need to make sure that the outline is comprehensive and specific. \
Topic you are writing about: <%= @topic %>

Old outline:

<%= @outline %>
|

  @message_prompt_template ~S|
Refine the outline based on your conversations with subject-matter experts:\n\nConversations:\n\n<%= @conversations %>\n",
|

  def get_fn do
    refine_outline_template =
      PromptTemplate.from_template!(@base_prompt_template)

    message_outline_template =
      PromptTemplate.from_template!(@message_prompt_template)

    path = Path.join(:code.priv_dir(:magus_live), @json_schema_path)
    {:ok, schema_file} = File.read(path)
    outline_schema = Poison.decode!(schema_file)

    refine_outline = fn chain, state ->
      all_messages =
        List.flatten(
          state.previous_interviews
          |> Enum.map(fn interview -> interview.messages end)
        )

      {:ok, outline, _response} =
        chain
        |> AgentChain.add_message(
          PromptTemplate.to_message!(refine_outline_template, %{
            topic: state.topic,
            outline: Util.outline_as_str(state.original_outline)
          })
        )
        |> AgentChain.add_message(
          PromptTemplate.to_message!(message_outline_template, %{
            conversations: all_messages |> conversation_as_str()
          })
        )
        |> AgentChain.ask_for_json_response(outline_schema)
        |> AgentChain.run()

      sections = outline["sections"]

      %StormState{state | refined_outline: outline, sections_to_write: sections}
    end

    refine_outline
  end

  defp conversation_as_str(messages) do
    messages
    |> Enum.map(fn {name, content} ->
      case name do
        :sme -> "### Expert\n\n#{content}"
        :editor -> "### You\n\n#{content}"
      end
    end)
  end
end
