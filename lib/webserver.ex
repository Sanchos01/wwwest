defmodule Wwwest.WebServer do
	use Silverb, 	[
						{"@port", :application.get_env(:wwwest, :server_port, nil)},
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
					{"@error_post", %Wwwest.Proto{result: "Bad req, use POST"} |> Jazz.encode!},
					{"@error_ok", %Wwwest.Proto{result: "Your req is ok, but these funcs are not written yet"} |> Jazz.encode!}
				 ]
	defp reply(ans, req, state), do: {:ok, :cowboy_req.reply(200, [{"Content-Type","application/json; charset=utf-8"}], ans, req), state}
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
					 	{:ok, term} -> decode_and_process(term, req)
					 	error -> %Wwwest.Proto{result: "Error on decoding req #{inspect error}"} |> Wwwest.encode |> reply(req, nil)
					 end
		end
	end
	#
	#	priv
	#
	defp decode_and_process(term, req) do
		#
		#	TODO
		#
		reply(@error_ok, req, nil)
	end
end