defmodule MagusLive.Agents.Storm.AskQuestion do
  alias LangChain.PromptTemplate
  alias LangChain.Message
  alias Magus.AgentChain
  alias MagusLive.Agents.StormState

  @base_prompt_template ~S|
  You are an experienced Wikipedia writer and want to edit a specific page. \
  Besides your identity as a Wikipedia writer, you have a specific focus when researching the topic. \
  Now, you are chatting with an expert to get information. Ask good questions to get more useful information.

  When you have no more questions to ask, say "Thank you so much for your help!" to end the conversation.\
  Please only ask one question at a time and don't ask what you have asked before.\
  Your questions should be related to the topic you want to write.
  Be comprehensive and curious, gaining as much unique insight from the expert as possible.\

  Stay true to your specific perspective:

  <%= @editor_persona %>
  |

  def get_fn do
    ask_question_template =
      PromptTemplate.from_template!(@base_prompt_template)

    ask_question = fn chain, state ->
      current_interview = state.current_interview
      messages = current_interview.messages

      editor_persona = build_persona(current_interview.editor)

      {:ok, content, _response} =
        chain
        |> AgentChain.add_message(
          PromptTemplate.to_message!(ask_question_template, %{editor_persona: editor_persona})
        )
        |> AgentChain.add_messages(build_messages_for_input(messages))
        |> AgentChain.run()

      current_interview = %{
        current_interview
        | messages: messages ++ [{:editor, content}],
          num_of_turns: current_interview.num_of_turns + 1
      }

      %StormState{state | current_interview: current_interview}
    end

    ask_question
  end

  defp build_messages_for_input(messages) do
    messages
    |> Enum.map(fn message ->
      case message do
        {:sme, content} ->
          Message.new_user!(content)

        {:editor, content} ->
          Message.new_assistant!(content)
      end
    end)
  end

  defp build_persona(expert) do
    "Name: #{expert["name"]}\nRole: #{expert["role"]}\nAffiliation: #{expert["affiliation"]}\nDescription: #{expert["description"]}"
  end
end
