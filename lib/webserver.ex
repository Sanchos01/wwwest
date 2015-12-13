defmodule Wwwest.WebServer do
	use Silverb, 	[
						{"@port", (  res = :application.get_env(:wwwest, :server_port, nil); true = (is_integer(res) and (res > 0)); res  )},
						{"@routes", [{"/[...]", Wwwest.WebServer.Handler, []}]}
					]
	@compiled_routes :cowboy_router.compile([_: @routes])
	def start do
		case :cowboy.start_http(:wwwest, 5000, [port: @port], [env: [dispatch: @compiled_routes]]) do
			{:ok, _} -> Wwwest.notice("web listener on port #{Integer.to_string @port} started")
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
					{"@error_post", %Wwwest.Proto{result: "Bad req, use POST"} |> Jazz.encode!},
					{"@error_timeout", %Wwwest.Proto{result: "request timeout"} |> Jazz.encode!}
				 ]

	defmacrop init_macro(req) do
		case Application.get_env(:wwwest, :basic_auth) do
			%{login: login, password: password} when (is_binary(login) and is_binary(password)) ->
				quote location: :keep do
					case :cowboy_req.parse_header("authorization", unquote(req)) do
						{:ok, {"basic",{unquote(login), unquote(password)}}, req} ->
							init_proc(req)
						_ ->
							{:ok, req} = :cowboy_req.reply(401, [{"WWW-Authenticate", "Basic realm=\"wwwest server\""},{"Connection","Keep-Alive"}], "", unquote(req))
							{:ok, req, :reply}
					end
				end
			none when (none == :none) or (none == nil) ->
				quote location: :keep do
					init_proc(unquote(req))
				end
		end
	end

	#
	#	public
	#

	# purge message
	def info({:json, _, _}, req, state), do: {:ok, req, state}
	def terminate(_,_,_), do: :ok
	def init(_,req,_), do: init_macro(req)
	def handle(req, :reply), do: {:ok, req, nil}
	def handle(req, _), do: init_macro(req)
	defp init_proc(req) do
		case :cowboy_req.has_body(req) do
			false -> reply(@error_post, 400, req)
			true ->  {:ok, req_body, req} = :cowboy_req.body(req)
					 case Wwwest.decode_safe(req_body) do
					 	{:ok, term = %{}} ->
							%Wwwest.Proto{}
							|> HashUtils.keys
							|> Enum.reduce(%Wwwest.Proto{}, fn(k,acc) -> HashUtils.set(acc, k, Map.get(term, k)) end)
							|> HashUtils.set(:ok, false)
							|> run_request(req)
					 	error ->
							%Wwwest.Proto{result: "Error on decoding req #{inspect error}"}
							|> Wwwest.encode
							|> reply(402, req)
					 end
		end
	end

	#
	#	priv
	#

	defp run_request(client_req = %Wwwest.Proto{trx: trx}, req) do
		daddy = self()
		case trx do
			nil -> spawn(fn() -> send(daddy, {:json, client_req, @callback_module.handle_wwwest(client_req)}) end)
			_ -> spawn(fn() -> send(daddy, Tinca.trx(fn() -> {:json, client_req, @callback_module.handle_wwwest(client_req)} end, &Wwwest.roll_trx/1, trx, @trx_ttl)) end)
		end
		receive do
			{:json, ^client_req, json} -> reply(json, 200, req)
		after
			@server_timeout -> reply(@error_timeout, 403, req)
		end
	end

	defp reply(ans, code, req) do
		{:ok, req} = :cowboy_req.reply(code, [{"Content-Type","application/json; charset=utf-8"},{"Connection","Keep-Alive"}], ans, req)
		{:ok, req, :reply}
	end

end
