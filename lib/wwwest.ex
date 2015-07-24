defmodule Wwwest do
  use Application
  use Silverb, [{"@memo_ttl", (  res = :application.get_env(:wwwest, :memo_ttl, nil); true = (is_integer(res) and (res > 0)); res  )}]
  use Wwwest.Structs
  use Logex, [ttl: 100]

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      # worker(Wwwest.Worker, [arg1, arg2, arg3])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Wwwest.Supervisor]
    res = Supervisor.start_link(children, opts)
    Wwwest.WebServer.start
    res
  end

  def encode(some), do: Tinca.memo(&Jazz.encode!/1, [some], @memo_ttl)
  def decode(some), do: Tinca.memo(&Jazz.decode!/2, [some, [keys: :atoms]], @memo_ttl)
  def decode_safe(some), do: Tinca.memo(&Jazz.decode/2, [some, [keys: :atoms]], @memo_ttl)

  defmacro callback_module([do: body]) do
    quote location: :keep do
      unquote(body)
      def handle_wwwest(some = %Wwwest.Proto{}), do: HashUtils.set(some, :result, "unexpected query #{inspect some}") |> Wwwest.encode
      def handle_wwwest(some), do: %Wwwest.Proto{result: "unexpected query #{inspect some}"} |> Wwwest.encode
    end
  end

  def ok(some = %Wwwest.Proto{}), do: HashUtils.set(some, :ok, true)

  def roll_trx(error), do: Wwwest.error("got exception in processing trx : #{inspect error}")

end
