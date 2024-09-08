defmodule MagusLiveWeb.AgentTailLive do
  use MagusLiveWeb, :live_view

  alias Magus.AgentExecutor

  def mount(%{"slug" => slug}, _session, socket) do
    lookup = :syn.lookup(:agents, slug)

    case lookup do
      {pid, _} ->
        %{agent: agent, status: status} = AgentExecutor.get_state(pid)
        AgentExecutor.subscribe_to_logs(pid)
        AgentExecutor.subscribe_to_state(pid)

        {:ok,
         socket
         |> assign(:log, "")
         |> assign(:agent_slug, slug)
         |> assign(:agent, agent)
         |> assign(:status, status)}

      :undefined ->
        {:ok,
         socket
         |> put_flash(:error, "Agent could not be found. Node might have disconnected?")
         |> redirect(to: "/agents")}
    end
  end

  def render(assigns) do
    ~H"""
    <h1 class="font-bold text-lg"><%= @agent.name %>: <%= @agent_slug %></h1>
    <h3>Status: <%= @status %></h3>

    <div
      id="tail-scroller"
      class="mt-6 p-6 overflow-auto font-mono whitespace-pre-line rounded-md text-sm tail-scroller"
    >
      <span><%= @log %></span>
      <div class="tail-scroller-anchor"></div>
    </div>
    """
  end

  def handle_info({:agent_log, _from, msg}, socket) do
    socket = assign(socket, :log, "#{socket.assigns.log}#{msg}")
    {:noreply, socket}
  end

  def handle_info({:agent_state, _from, state}, socket) do
    socket = assign(socket, :status, state.status)
    {:noreply, socket}
  end
end
