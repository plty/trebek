defmodule TrebekWeb.MCQLive.FormComponent do
  use TrebekWeb, :live_component

  alias Trebek.Quiz

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage mcq records in your database.</:subtitle>
      </.header>

      <.simple_form
        :let={f}
        for={@changeset}
        id="mcq-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={{f, :question}} type="text" label="Question" />
        <.input
          field={{f, :choices}}
          type="select"
          multiple
          label="Choices"
          options={[{"Option 1", "option1"}, {"Option 2", "option2"}]}
        />
        <.input field={{f, :answer}} type="number" label="Answer" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Mcq</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{mcq: mcq} = assigns, socket) do
    changeset = Quiz.change_mcq(mcq)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"mcq" => mcq_params}, socket) do
    changeset =
      socket.assigns.mcq
      |> Quiz.change_mcq(mcq_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"mcq" => mcq_params}, socket) do
    save_mcq(socket, socket.assigns.action, mcq_params)
  end

  defp save_mcq(socket, :edit, mcq_params) do
    case Quiz.update_mcq(socket.assigns.mcq, mcq_params) do
      {:ok, _mcq} ->
        {:noreply,
         socket
         |> put_flash(:info, "Mcq updated successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_mcq(socket, :new, mcq_params) do
    case Quiz.create_mcq(mcq_params) do
      {:ok, _mcq} ->
        {:noreply,
         socket
         |> put_flash(:info, "Mcq created successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
