defmodule MagusLive.Agents.Storm.AnswerQuestion do
  alias Expo.Message
  alias LangChain.PromptTemplate
  alias LangChain.Message
  alias Magus.AgentChain
  alias MagusLive.Agents.StormState

  @json_schema_path "agent_schema/storm/answer_question.json"

  @base_prompt_template ~S|
You are an expert who can use information effectively. You are chatting with a Wikipedia writer who wants\
 to write a Wikipedia page on the topic you know. You have gathered the related information and will now use the information to form a response.

Make your response as informative as possible and make sure every sentence is supported by the gathered information.
Each response must be backed up by a citation from a reliable source, formatted as a footnote, reproducing the URLs after your response.

Below is the gathered information:

<%= @references %>
  |

  def get_fn do
    answer_question_template =
      PromptTemplate.from_template!(@base_prompt_template)

    path = Path.join(:code.priv_dir(:magus_live), @json_schema_path)
    {:ok, schema_file} = File.read(path)
    answer_question_schema = Poison.decode!(schema_file)

    search_tool = MagusLive.Tools.TavilySearch.build_search_function()

    answer_question = fn chain, state ->
      current_interview = state.current_interview
      messages = current_interview.messages
      references_by_url = current_interview.references_by_url

      # First, do research
      research_prompt = """
      You are a helpful research assistant.
      Generate a few queries that could help answer the user's latest question and then use the Search tool for each query.
      """

      {:ok, _content, response} =
        chain
        |> AgentChain.add_message(Message.new_system!(research_prompt))
        |> AgentChain.add_messages(build_messages_for_input(messages))
        |> AgentChain.add_tool(search_tool)
        |> AgentChain.run()

      # Actually run the tool search
      # TODO: clean this up because I hate how this works
      tool_calls = response.tool_calls

      searches =
        tool_calls
        |> Enum.map(fn call -> MagusLive.Tools.TavilySearch.search(call.arguments["query"]) end)

      # ok, we have our results. Now, build a system prompt that includes the content and the urls
      # as research materials and then tell the SME to answer based on that content and to
      # format it with references

      result_by_url =
        searches
        |> Enum.map(fn search -> search["results"] end)
        |> List.flatten()
        |> Map.new(fn result -> {result["url"], result} end)

      references_str = build_references_str(result_by_url |> Map.values())

      {:ok, answer, _response} =
        chain
        |> AgentChain.add_message(
          Message.new_system!(
            PromptTemplate.format(answer_question_template, %{references: references_str})
          )
        )
        |> AgentChain.add_messages(build_messages_for_input(messages))
        |> AgentChain.ask_for_json_response(answer_question_schema)
        |> AgentChain.run()

      updated_references_by_url =
        if answer["cited_urls"] != nil do
          answer["cited_urls"]
          |> Map.new(fn ref_url -> {ref_url, result_by_url[ref_url]["content"]} end)
          |> Map.merge(references_by_url)
        else
          references_by_url
        end

      current_interview = %{
        current_interview
        | messages: messages ++ [{:sme, answer["answer"]}],
          references_by_url: updated_references_by_url
      }

      %StormState{state | current_interview: current_interview}
    end

    answer_question
  end

  defp build_messages_for_input(messages) do
    messages
    |> Enum.map(fn message ->
      case message do
        {:sme, content} ->
          Message.new_assistant!(content)

        {:editor, content} ->
          Message.new_user!(content)
      end
    end)
  end

  defp build_references_str(search_results) do
    search_results
    |> Enum.map(fn raw_result ->
      "Title: #{raw_result["title"]}\nContent: #{raw_result["content"]}\nURL: #{raw_result["url"]}"
    end)
    |> Enum.join("\n\n")
  end
end
