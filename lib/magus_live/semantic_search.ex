defmodule MagusLive.SemanticSearch do
  use GenServer

  alias MagusLive.SemanticSearch.Document

  # Default dimensions for OpenAI embeddings
  # TODO: Make these all configurable later
  @dimensions 1536
  @max_elements 100
  @search_default_results 5

  # Client

  def start_link() do
    GenServer.start_link(__MODULE__, %{})
  end

  def start() do
    GenServer.start(__MODULE__, %{})
  end

  def add_document(pid, %Document{} = doc) do
    GenServer.cast(pid, {:add, doc})
  end

  def search(pid, text) do
    GenServer.call(pid, {:search, text}, :infinity)
  end

  # Server (callbacks)

  @impl true
  def init(_) do
    # Create index
    {:ok, index} = HNSWLib.Index.new(:cosine, @dimensions, @max_elements)

    # Create map
    id_to_doc = Map.new()

    {:ok, %{index: index, id_to_doc: id_to_doc, id_counter: 0}}
  end

  @impl true
  def handle_cast(
        {:add, %Document{} = doc},
        %{index: index, id_to_doc: id_to_doc, id_counter: id_counter} = state
      ) do
    # Generate id (HNSW wants integer ids)
    new_id = id_counter

    # Generate embeddings for doc
    embedding = MagusLive.Embedding.create(doc.content)

    # Add embeddings with id to the index
    data =
      Nx.tensor(
        [
          embedding
        ],
        type: :f32
      )

    index |> HNSWLib.Index.add_items(data, ids: [new_id])

    # Add doc to the map with id as key
    id_to_doc = id_to_doc |> Map.put(new_id, doc)

    {:noreply, %{state | index: index, id_to_doc: id_to_doc, id_counter: id_counter + 1}}
  end

  @impl true
  def handle_call({:search, text}, _from, %{index: index, id_to_doc: id_to_doc} = state) do
    # Get embeddings for text
    embedding = MagusLive.Embedding.create(text)

    # Find similar results
    query = Nx.tensor(embedding, type: :f32)

    # knn_query throws an error if k > current count
    {:ok, count} = HNSWLib.Index.get_current_count(index)

    {:ok, id_tensor, dist_tensor} =
      HNSWLib.Index.knn_query(index, query, k: min(count, @search_default_results))

    ids = id_tensor[0] |> Nx.to_list()
    dists = dist_tensor[0] |> Nx.to_list()

    # Return docs
    docs = ids |> Enum.map(fn id -> id_to_doc[id] end)

    {:reply, Enum.zip(docs, dists), state}
  end
end
