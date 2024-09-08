defmodule MagusLive.Tools.TavilySearch do
  def search(query) do
    tavily_key = Application.fetch_env!(:magus_live, :tavily_key)

    params = %{
      api_key: tavily_key,
      query: query,
      max_results: 5
    }

    Req.post!("https://api.tavily.com/search", json: params).body
  end

  def build_search_function() do
    LangChain.Function.new!(%{
      name: "Search",
      description: "Searches the web for information related to the query.",
      parameters_schema: %{
        type: "object",
        properties: %{
          query: %{type: "string", description: "A query to search the web for."}
        },
        required: ["query"]
      },
      function: fn args, _context ->
        response = search(args["query"])
        {:ok, response}
      end,
    })
  end
end
