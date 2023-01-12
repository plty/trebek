defmodule Trebek.MCQ do
  defstruct [:id, :q, :a, :c]
end

defmodule Trebek.Choice do
  defstruct [:id, :s]
end

defmodule Trebek.Freq do
  defstruct [:id, :freq]
end

defmodule TrebekWeb.MCQLive.Index do
  use TrebekWeb, :live_view
  alias Uniq.UUID
  alias Trebek.Choice
  alias Trebek.MCQ

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      TrebekWeb.Endpoint.subscribe("freqs")
    end

    id = UUID.uuid7()
    IO.inspect(id)

    mcq = %MCQ{
      id: "0185a1fb-6073-7e17-b598-139d9787c36a",
      q: "Apa bunyi sila ke-3 Pancasila",
      a: 2,
      c: [
        %Choice{
          id: 0,
          s: "Ketuhanan yang Maha Esa"
        },
        %Choice{
          id: 1,
          s: "Kemanusiaan yang adil dan beradab"
        },
        %Choice{
          id: 2,
          s: "Persatuan Indonesia"
        },
        %Choice{
          id: 3,
          s: "Kerakyatan yang dipimpin oleh hikmat kebijaksanaan dalam permusyawaratan/perwakilan"
        },
        %Choice{
          id: 4,
          s: "Keadilan sosial bagi seluruh rakyat Indonesia"
        }
      ]
    }

    {:ok,
     socket
     |> assign(:id, id)
     |> assign(:mcq, mcq)
     |> assign(:guess, nil)
     |> assign(:freqs, get_freqs())}
  end

  @impl true
  def handle_event("guess", %{"id" => g}, socket) do
    Trebek.Credo.put(socket.assigns.id, g)

    TrebekWeb.Endpoint.broadcast(
      "freqs",
      "vote_changed",
      get_freqs()
    )

    {:noreply, socket |> assign(:guess, g)}
  end

  @impl true
  def handle_info(%{event: "vote_changed", payload: freqs}, socket) do
    {:noreply, socket |> assign(:freqs, freqs)}
  end

  def get_freqs() do
    Map.values(Trebek.Credo.get())
    |> Enum.frequencies()
    |> Map.to_list()
    |> Enum.map(fn {x, y} -> %Trebek.Freq{id: x, freq: y} end)
  end
end
