defmodule TrebekWeb.MCQLive.Index do
  use TrebekWeb, :live_view

  alias Trebek.Quiz
  alias Trebek.Quiz.MCQ

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :mcqs, list_mcqs())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Mcq")
    |> assign(:mcq, Quiz.get_mcq!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Mcq")
    |> assign(:mcq, %MCQ{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Mcqs")
    |> assign(:mcq, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    mcq = Quiz.get_mcq!(id)
    {:ok, _} = Quiz.delete_mcq(mcq)

    {:noreply, assign(socket, :mcqs, list_mcqs())}
  end

  defp list_mcqs do
    Quiz.list_mcqs()
  end
end
