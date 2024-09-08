defmodule MagusLiveWeb.PageController do
  use MagusLiveWeb, :controller

  alias MagusLiveWeb.Plugs.Password

  def home(conn, _params) do
    if Password.already_authenticated?(conn) do
      conn
      |> Phoenix.Controller.redirect(to: "/agents")
      |> halt
    else
      # The home page is often custom made,
      # so skip the default app layout.
      render(conn, :home, layout: false)
    end
  end
end
