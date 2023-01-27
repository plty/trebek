defmodule TrebekWeb.AuthLive do
  import Phoenix.Component

  def on_mount(_, _params, session, socket) do
    case session["guardian_default_token"] do
      nil ->
        {:cont, socket |> assign(current_user: nil)}

      token ->
        {:ok, resource, _claims} = TrebekWeb.Guardian.resource_from_token(token)
        {:cont, socket |> assign(current_user: resource)}
    end
  end
end

defmodule TrebekWeb.EnsureAuthLive do
  import Phoenix.LiveView

  def on_mount(_, _params, _session, socket) do
    if socket.assigns.current_user do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/auth")}
    end
  end
end
