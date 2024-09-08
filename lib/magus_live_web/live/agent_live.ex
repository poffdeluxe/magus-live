defmodule MagusLiveWeb.AgentLive do
  use MagusLiveWeb, :live_view

  alias Magus.AgentExecutor

  def mount(%{"slug" => slug}, _session, socket) do
    lookup = :syn.lookup(:agents, slug)

    case lookup do
      {pid, _} ->
        %{agent: agent, steps: steps, status: status, cur_agent_state: cur_agent_state} =
          AgentExecutor.get_state(pid)

        AgentExecutor.subscribe_to_state(pid)

        {:ok, dot_graph_raw} = Graph.Serializers.DOT.serialize(agent.graph)

        {:ok,
         socket
         |> assign(:agent_slug, slug)
         |> assign(:agent, agent)
         |> assign(:status, status)
         |> assign(:cur_agent_state, cur_agent_state)
         |> assign(:dot_graph_raw, dot_graph_raw)
         |> assign(:steps, steps)}

      :undefined ->
        {:ok,
         socket
         |> put_flash(:error, "Agent could not be found. Node might have disconnected?")
         |> redirect(to: "/agents")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-row items-center mb-6">
      <div class="grow">
        <h1 class="font-bold text-lg"><%= @agent.name %>: <%= @agent_slug %></h1>
        <h3>Status: <%= @status %></h3>

        <%= if @status == :running do %>
          <.link
            navigate={~p"/agents/#{@agent_slug}/live"}
            class="text-sm underline font-semibold leading-6 text-cyan-300 hover:text-cyan-200"
          >
            Live Tail
          </.link>
        <% end %>
      </div>
      <div>
        <%= Phoenix.HTML.raw(Dot.to_svg(@dot_graph_raw)) %>
      </div>
    </div>

    <section class="mb-6">
      <h2 class="section-header text-2xl mb-2 magus_live-header font-serif">Steps</h2>
      <ul class="flex flex-col gap-2">
        <%= for {step, index} <- Enum.with_index(@steps) do %>
          <li
            id={"step_#{index}"}
            class={[
              "p-4 rounded border-solid border-2",
              step.status == :notstarted && "border-gray-500",
              step.status == :running && "border-blue-500",
              step.status == :done && "border-green-500",
              step.status == :failed && "border-red-500"
            ]}
          >
            <div class="flex flex-row">
              <div class="grow flex flex-row gap-2">
                <span class="font-bold"><%= step.node %></span>
                <span>•</span>
                <span><%= step.status %></span>
              </div>
              <button
                class="chevron transition-all duration-300"
                phx-click={
                  JS.toggle_class("hidden", to: "#step_#{index} > .state-content")
                  |> JS.toggle_class("rotate-90", to: "#step_#{index} .chevron", time: 300)
                }
              >
                <.icon name="hero-chevron-right" class="text-lg" />
              </button>
            </div>
            <div class="state-content mt-4 hidden">
              <h4 class="text-gray-500">State</h4>
              <pre class="whitespace-pre-wrap"><%= inspect(step.output_state, pretty: true) %></pre>
            </div>
          </li>
        <% end %>
      </ul>
    </section>

    <%= if @status == :done do %>
      <section class="mb-6">
        <h2 class="section-header text-2xl mb-2 magus_live-header font-serif">Output</h2>
        <p class="whitespace-pre-line">
          <%= Magus.GraphAgent.get_final_output(@agent, @cur_agent_state) %>
        </p>
      </section>
    <% end %>
    """
  end

  def handle_info({:agent_state, _from, state}, socket) do
    steps = state.steps
    agent = state.agent
    status = state.status
    cur_agent_state = state.cur_agent_state

    {:noreply,
     socket
     |> assign(:agent, agent)
     |> assign(:status, status)
     |> assign(:steps, steps)
     |> assign(:cur_agent_state, cur_agent_state)}
  end
end
