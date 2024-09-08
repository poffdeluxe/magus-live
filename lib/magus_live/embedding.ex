defmodule MagusLive.Embedding do
  @route "https://api.openai.com/v1/embeddings"
  @default_model "text-embedding-3-small"

  def create(input) do
    openai_key = Application.fetch_env!(:magus_live, :openai_key)

    params = %{
      input: input,
      model: @default_model,
      encoding_format: "float"
    }

    body = Req.post!(@route, json: params, auth: {:bearer, openai_key}).body

    List.first(body["data"])["embedding"]
  end
end
