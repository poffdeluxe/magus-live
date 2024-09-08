defmodule MagusLiveWeb.Plugs.Password do
  import Plug.Conn

  defp password, do: [Application.get_env(:magus_live, :plug_password)]

  def init(options), do: options

  def call(conn, _options) do
    if already_authenticated?(conn) do
      conn
    else
      password()
      |> Enum.member?(conn.body_params["password"])
      |> handle_authentication(conn)
    end
  end

  def already_authenticated?(conn) do
    cookie_password = password_from_cookies(conn)
    cookie_password && Enum.member?(password(), cookie_password)
  end

  defp password_from_cookies(conn) do
    fetch_cookies(conn, encrypted: ~w(plug_password)).cookies["plug_password"]
  end

  defp handle_authentication(true, conn) do
    conn
    |> put_resp_cookie("plug_password", fetch_password(conn), encrypt: true)
    |> Phoenix.Controller.redirect(to: "/agents") # TODO: make this configurable
    |> halt
  end

  defp handle_authentication(false, conn) do
    conn
    |> Phoenix.Controller.put_flash(:error, "Incorrect password")
    |> Phoenix.Controller.redirect(to: "/")
    |> halt
  end

  defp fetch_password(conn) do
    password_from_cookies(conn) || conn.body_params["password"]
  end
end
