defmodule TrebekWeb.MCQLive.Show do
  use TrebekWeb, :live_view

  alias Trebek.Quiz

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:mcq, Quiz.get_mcq!(id))}
  end

  defp page_title(:show), do: "Show Mcq"
  defp page_title(:edit), do: "Edit Mcq"
end
