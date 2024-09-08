defmodule MagusLive.StormTest do
  use ExUnit.Case

  test "make sure the STORM agent can finish", %{} do
    agent = MagusLive.Agents.Storm.get_agent()

    assert agent.entry_point_node == :generate_outline

    has_path = agent.graph
      |> Graph.get_paths(agent.entry_point_node, :end)
      |> length() > 0
    assert has_path
  end
end
