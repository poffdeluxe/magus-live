defmodule MagusLiveWeb.AgentsLive do
  use MagusLiveWeb, :live_view

  alias MagusLive.Agents.{EssayWriter, EssayWriterState}
  alias MagusLive.Agents.{Storm, StormState}
  alias Magus.AgentExecutor

  def mount(_params, _session, socket) do
    agent_members = :syn.members(:agents, :essay_agents)

    all_agents =
      agent_members
      |> Enum.map(fn member ->
        {pid, _} = member
        exe_state = AgentExecutor.get_state(pid)

        # For each currently running agent, subscribe to their topic
        AgentExecutor.subscribe_to_state(pid)

        # And retreive their current state
        exe_state
      end)
      |> Enum.sort_by(fn exe_state -> exe_state.created_at end, {:desc, DateTime})

    # Listen for new agents to start running
    AgentExecutor.subscribe_to_new_agents()

    {:ok,
     socket
     |> stream(:agents, all_agents)
     |> assign(:form, to_form(%{"topic" => "", "agent_type" => "essay"}))}
  end

  def render(assigns) do
    ~H"""
    <h1 class="magus_live-header font-serif text-4xl leading-relaxed">Agents</h1>

    <.simple_form for={@form} phx-submit="generate">
      <.input field={@form[:topic]} label="Input" required />
      <.input field={@form[:agent_type]} label="Agent type" type="select" options={["Essay Writer": "essay", "STORM": "storm"]} />
      <:actions>
        <.button>Start</.button>
      </:actions>
    </.simple_form>

    <hr class="section-header mt-4" />

    <%= if @streams.agents.inserts |> length  == 0 do %>
      <div class="mt-4 text-center font-serif italic text-lg text-gray-500">
        No agents currently active
      </div>
    <% else %>
      <ul class="mt-4 flex flex-col gap-4" id="all-agents" phx-update="stream">
      <%= for {slug, agent_state} <- @streams.agents do %>
        <li
          class={[
            "p-4 rounded border-solid border-2",
            agent_state.status == :notstarted && "border-gray-500",
            agent_state.status == :running && "border-blue-500",
            agent_state.status == :done && "border-green-500",
            agent_state.status == :failed && "border-red-500"
          ]}
          id={"#{slug}"}
        >
          <div class="flex flex-row">
            <div class="grow flex flex-row gap-2">
              <span class="font-bold"><%= agent_state.agent.name %>: <%= agent_state.id %></span>
              <span>•</span>
              <span><%= agent_state.status %></span>
            </div>

            <.link href={~p"/agents/#{agent_state.id}"}>Details</.link>
          </div>
        </li>
      <% end %>
      </ul>
    <% end %>
    """
  end

  def handle_info({:agent_state, _slug, state}, socket) do
    socket = stream_insert(socket, :agents, state)
    {:noreply, socket}
  end

  def handle_info({:agent_starting, slug}, socket) do
    {pid, _} = :syn.lookup(:agents, slug)

    exe_state = AgentExecutor.get_state(pid)
    AgentExecutor.subscribe_to_state(pid)

    socket = stream_insert(socket, :agents, exe_state, at: 0)
    {:noreply, socket}
  end

  def handle_event("generate", %{"topic" => topic, "agent_type" => "essay"}, socket) do
    agent = EssayWriter.get_agent()
    start_agent(%{agent | initial_state: %EssayWriterState{topic: topic}})

    {:noreply, socket}
  end

  def handle_event("generate", %{"topic" => topic, "agent_type" => "storm"}, socket) do
    agent = Storm.get_agent()
    start_agent(%{agent | initial_state: %StormState{topic: topic}})

    {:noreply, socket}
  end

  def start_agent(agent) do
    slug = MnemonicSlugs.generate_slug(3)
    {:ok, pid} = AgentExecutor.new(agent: agent, id: slug)
    :syn.join(:agents, :essay_agents, pid)
    :syn.register(:agents, slug, pid)

    # No need to call subscribe() directly as we're already listening
    # for new agents to be started
    AgentExecutor.run(pid)
  end
end
