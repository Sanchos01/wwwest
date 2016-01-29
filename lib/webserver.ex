defmodule Wwwest.WebServer do
	use Silverb, 	[
						{"@port", (  res = :application.get_env(:wwwest, :server_port, nil); true = (is_integer(res) and (res > 0)); res  )},
						{"@routes", [
										{"/crossdomain.xml", Wwwest.WebServer.CrossDomain, []},
										{"/[...]", Wwwest.WebServer.Handler, []}
									]}
					]
	@compiled_routes :cowboy_router.compile([_: @routes])
	def start do
		case :cowboy.start_http(:wwwest, 5000, [port: @port], [env: [dispatch: @compiled_routes]]) do
			{:ok, _} -> Wwwest.notice("web listener on port #{Integer.to_string @port} started")
			{_, reason} ->
				Wwwest.error("failed to start listener, reason: #{inspect reason}")
				receive do after 1000 -> nil end
				:erlang.halt
		end
	end
end

defmodule Wwwest.WebServer.Commons do
	defmacro init_macro(req) do
		case Application.get_env(:wwwest, :basic_auth) do
			%{login: login, password: password} when (is_binary(login) and is_binary(password)) ->
				quote location: :keep do
					case :cowboy_req.parse_header("authorization", unquote(req)) do
						{:ok, {"basic",{unquote(login), unquote(password)}}, req} ->
							init_proc(req)
						_ ->
							{:ok, req} = :cowboy_req.reply(401, [{"WWW-Authenticate", "Basic realm=\"private server\""},{"Connection","Keep-Alive"}], "", unquote(req))
							{:ok, req, :reply}
					end
				end
			none when (none == :none) or (none == nil) ->
				quote location: :keep do
					init_proc(unquote(req))
				end
		end
	end
end

defmodule Wwwest.WebServer.CrossDomain do
	require Wwwest.WebServer.Commons
	use Silverb, [
		{"@crossdomain", (case Application.get_env(:wwwest, :crossdomain) do ; true -> true ; false -> false ; nil -> false ; end)},
		{"@crossdomainxml", ((Exutils.priv_dir(:wwwest)<>"/crossdomain.xml") |> File.read!)}
	]

	def terminate(_reason, _req, _state), do: :ok
	def init(_, req, _opts), do: Wwwest.WebServer.Commons.init_macro(req)
	def handle(req, :reply), do: {:ok, req, nil}
	def handle(req, _state), do: Wwwest.WebServer.Commons.init_macro(req)

	case Application.get_env(:wwwest, :crossdomain) do
		true ->
			defp init_proc(req) do
				{:ok, req} = :cowboy_req.reply(200, [{"Content-Type","text/xml; charset=utf-8"},{"Access-Control-Allow-Origin", "*"},{"Connection","Keep-Alive"}], @crossdomainxml, req)
				{:ok, req, :reply}
			end
		no when (no in [false, nil]) ->
			defp init_proc(req) do
				{:ok, req} = :cowboy_req.reply(404, [{"Content-Type","text/xml; charset=utf-8"},{"Connection","Keep-Alive"}], "File not found. Note, crossdomain is not allowed.", req)
				{:ok, req, :reply}
			end
	end
end

defmodule Wwwest.WebServer.Handler do
	require Wwwest.WebServer.Commons
	use Silverb, [
					{"@callback_module", ( res = :application.get_env(:wwwest, :callback_module, nil); true = is_atom(res); res  )},
					{"@server_timeout",  ( res = :application.get_env(:wwwest, :server_timeout, nil); true = (is_integer(res) and (res > 0)); res  )},
					{"@trx_ttl", (  res = :application.get_env(:wwwest, :trx_ttl, nil);  true = (is_integer(res) and (res > 0)); res )},
					{"@error_timeout", %Wwwest.Proto{result: "request timeout #{:application.get_env(:wwwest, :server_timeout, nil)} ms"} |> Jazz.encode!},
					{"@crossdomain", (case Application.get_env(:wwwest, :crossdomain) do ; true -> true ; false -> false ; nil -> false ; end)}
				 ]

	defmacrop options_macro(req) do
		case Application.get_env(:wwwest, :crossdomain) do
			true ->
				quote location: :keep do
					{headers, req} = unquote(req) |> :cowboy_req.headers
					headers = Enum.map(headers, fn({k,v}) ->
						case String.downcase(k) do
							"access-control-request-method" -> {"access-control-allow-method",v}
							"access-control-request-headers" -> {"access-control-allow-headers",v}
							_ -> {k,v}
						end
					end)
					{:ok, req} = :cowboy_req.reply(200, ([{"Access-Control-Allow-Origin", "*"},{"Connection","Keep-Alive"}]++headers), "", req)
					{:ok, req, :reply}
				end
			no when (no in [false, nil]) ->
				quote location: :keep do
					"You should use POST method instead OPTIONS. Note, crossdomain is not allowed."
					|> bad_reply(400, unquote(req))
				end
		end
	end

	defmacrop headers_macro do
		case Application.get_env(:wwwest, :crossdomain) do
			true ->
				quote location: :keep do
					[{"Content-Type","application/json; charset=utf-8"},{"Connection","Keep-Alive"},{"Access-Control-Allow-Origin", "*"}]
				end
			no when (no in [false, nil]) ->
				quote location: :keep do
					[{"Content-Type","application/json; charset=utf-8"},{"Connection","Keep-Alive"}]
				end
		end
	end

	defmacrop bad_reply(error, code, req) when (is_binary(error) and is_integer(code) and (code >= 400)) do
		ans = %Wwwest.Proto{result: error} |> Jazz.encode!
		quote location: :keep do
			reply(unquote(ans), unquote(code), unquote(req))
		end
	end

	#
	#	public
	#

	# purge message
	def info({:json, _, _}, req, state), do: {:ok, req, state}
	def terminate(_,_,_), do: :ok
	def init(_,req,_), do: Wwwest.WebServer.Commons.init_macro(req)
	def handle(req, :reply), do: {:ok, req, nil}
	def handle(req, _), do: Wwwest.WebServer.Commons.init_macro(req)
	defp init_proc(req) do
		case :cowboy_req.method(req) do
			{"POST", req} ->
				case :cowboy_req.has_body(req) do
					false -> bad_reply("Empty request body.", 402, req)
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
									|> reply(403, req)
							end
				end
			{"OPTIONS", req} ->
				options_macro(req)
			{method, req} ->
				%Wwwest.Proto{result: "you should use POST method instead #{inspect method}"}
				|> Wwwest.encode
				|> reply(405, req)
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
			@server_timeout -> reply(@error_timeout, 408, req)
		end
	end

	defp reply(ans, code, req) do
		{:ok, req} = :cowboy_req.reply(code, headers_macro, ans, req)
		{:ok, req, :reply}
	end

end
