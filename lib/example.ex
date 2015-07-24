defmodule Wwwest.Example do
	require Wwwest
	Wwwest.callback_module do
		def handle_wwwest(req = %Wwwest.Proto{cmd: "sum", args: args}) when is_list(args), do: HashUtils.set(req, :result, Enum.reduce(args,0,&(&1+&2))) |> Wwwest.ok |> Wwwest.encode
		def handle_wwwest(req = %Wwwest.Proto{cmd: "time"}), do: HashUtils.set(req, :result, Exutils.makestamp) |> Wwwest.ok |> Wwwest.encode
	end
end