defmodule Wwwest.WebServer do
	use Silverb, 	[
						{"@port", (  res = :application.get_env(:wwwest, :server_port, nil); true = (is_integer(res) and (res > 0)); res  )},
						{"@routes", [{"/[...]", Wwwest.WebServer.Handler, []}]}
					]
	@compiled_routes :cowboy_router.compile([_: @routes])
	def start do
		case :cowboy.start_http(:wwwest, 5000, [port: @port], [env: [dispatch: @compiled_routes]]) do
			{:ok, _} -> Wwwest.notice("web listener on port #{@port} started")
			{_, reason} ->
				Wwwest.error("failed to start listener, reason: #{inspect reason}")
				receive do after 1000 -> end
				:erlang.halt
		end
	end
end

defmodule Wwwest.WebServer.Handler do
	use Silverb, [
					{"@callback_module", ( res = :application.get_env(:wwwest, :callback_module, nil); true = is_atom(res); res  )},
					{"@server_timeout",  ( res = :application.get_env(:wwwest, :server_timeout, nil); true = (is_integer(res) and (res > 0)); res  )},
					{"@trx_ttl", (  res = :application.get_env(:wwwest, :trx_ttl, nil);  true = (is_integer(res) and (res > 0)); res )},
					{"@error_post", %Wwwest.Proto{result: "Bad req, use POST"} |> Jazz.encode!}
				 ]
	#
	#	public
	#
	def info({:json, json}, req, state), do: reply(json, req, state)
	def terminate(_reason, _req, _state), do: :ok
	def init(req, _opts) do
		case :cowboy_req.has_body(req) do
			false -> reply(@error_post, req, nil)
			true ->  {:ok, req_body, req} = :cowboy_req.body(req)
					 case Wwwest.decode_safe(req_body) do
					 	{:ok, term = %{}} -> %Wwwest.Proto{} |> HashUtils.keys |> Enum.reduce(%Wwwest.Proto{}, fn(k,acc) -> HashUtils.set(acc, k, Map.get(term, k)) end) |> HashUtils.set(:ok, false) |> run_request(req)
					 	error -> %Wwwest.Proto{result: "Error on decoding req #{inspect error}"} |> Wwwest.encode |> reply(req, nil)
					 end
		end
	end
	#
	#	priv
	#
	defp reply(ans, req, state), do: {:ok, :cowboy_req.reply(200, [{"Content-Type","application/json; charset=utf-8"}], ans, req), state}
	defp run_request(client_req = %Wwwest.Proto{trx: trx}, req) do
		daddy = self()
		case trx do
			nil -> spawn(fn() -> send(daddy, {:json, @callback_module.handle_wwwest(client_req)}) end)
			_ -> spawn(fn() -> send(daddy, Tinca.trx(fn() -> {:json, @callback_module.handle_wwwest(client_req)} end, nil, trx, @trx_ttl)) end)
		end
		{:cowboy_loop, req, nil, @server_timeout}
	end
end