defmodule MagusLive.Agents.Storm.GenerateEditors do
  alias LangChain.PromptTemplate
  alias Magus.AgentChain
  alias MagusLive.Agents.StormState

  @json_schema_path "agent_schema/storm/generate_editors.json"

  @base_prompt_template ~S|
  You need to select a diverse (and distinct) group of Wikipedia editors who will work together to create a comprehensive article on the topic. Each of them represents a different perspective, role, or affiliation related to this topic.\
  You can use other Wikipedia pages of related topics for inspiration. For each editor, add a description of what they will focus on.

  Wiki page outlines of related topics for inspiration:
  <%= @examples %>

  Topic of interest: <%= @topic %>
  |

  def get_page_with_summary(topic) do
    search_params = [
      action: "query",
      list: "search",
      srprop: "",
      srlimit: 1,
      limit: 1,
      srsearch: topic,
      format: "json"
    ]

    search_response =
      Req.get!("https://en.wikipedia.org/w/api.php", params: search_params).body

    result = search_response["query"]["search"] |> List.first()
    page_title = result["title"]

    # Now that we know we have a page, get the summary for the page
    # https://en.wikipedia.org/w/api.php?format=json&action=query&prop=extracts&exintro&explaintext&redirects=1&titles=Stack%20Overflow
    page_params = [
      action: "query",
      format: "json",
      prop: "extracts",
      exintro: "",
      explaintext: "",
      redirects: 1,
      titles: page_title
    ]

    # TODO: Handle rate limiting it a better way
    :timer.sleep(300)

    page_response =
      Req.get!("https://en.wikipedia.org/w/api.php", params: page_params).body

    result = page_response["query"]["pages"] |> Map.values() |> List.first()
    page_summary = result["extract"]

    # TODO: The STORM doc uses categories as well but I don't retrieve
    # them here because I'm lazy

    {page_title, page_summary}
  end

  def get_fn do
    generate_editors_template =
      PromptTemplate.from_template!(@base_prompt_template)

    path = Path.join(:code.priv_dir(:magus_live), @json_schema_path)
    {:ok, schema_file} = File.read(path)
    editors_schema = Poison.decode!(schema_file)

    generate_editors = fn chain, state ->
      # TODO: Temporary for this demo but only take the first five topics
      topics = state.expanded_topics |> Enum.take(5)

      examples =
        topics
        |> Enum.map(fn topic -> get_page_with_summary(topic) end)
        |> Enum.reduce("", fn {title, summary}, acc -> "#{acc}\n\n ### #{title}\n#{summary}" end)

      {:ok, content, _response} = chain
      |> AgentChain.add_message(
        PromptTemplate.to_message!(generate_editors_template, %{
          examples: examples,
          topic: state.topic
        })
      )
      |> AgentChain.ask_for_json_response(editors_schema)
      |> AgentChain.run()

      # XXX: remove this for full version
      #%StormState{state | editors: tool_call.arguments["editors"] |> Enum.take(1)}
      %StormState{state | editors: content["editors"]}
    end

    generate_editors
  end
end
