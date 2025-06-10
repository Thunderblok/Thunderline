defmodule ThunderlineWeb.PageController do
  use ThunderlineWeb, :controller

  def home(conn, _params) do
    # The home page is often custom, but here we'll render a simple welcome
    render(conn, :home, layout: false)
  end
end
