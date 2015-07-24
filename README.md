Wwwest
======

Amazing simple long pooling wrapper around erlang cowboy. First, write config, like this

```
config :wwwest, 
	server_port: 9868, 
	server_timeout: 20000, # timeout for all requests
	memo_ttl: 3600000, # timeout for memorize json encode and decode
	trx_ttl: 3600000, # timeout for all trx transactions
	callback_module: Wwwest.Example # here are handlers for requests
```

Second, write callback module with only one function "handle_wwwest(%Wwwest.Proto{}) -> binary"

```
defmodule Wwwest.Example do
	require Wwwest
	Wwwest.callback_module do
		def handle_wwwest(req = %Wwwest.Proto{cmd: "sum", args: args}) when is_list(args), do: HashUtils.set(req, :result, Enum.reduce(args,0,&(&1+&2))) |> Wwwest.ok |> Wwwest.encode
		def handle_wwwest(req = %Wwwest.Proto{cmd: "time"}), do: HashUtils.set(req, :result, Exutils.makestamp) |> Wwwest.ok |> Wwwest.encode
	end
end
```

Next, run app and do some POST requests

```
curl -d '{"cmd":"sum", "args":[1,2,3]}' http://127.0.0.1:9868
{"args":[1,2,3],"cmd":"sum","ok":true,"result":6,"trx":null}

curl -d '{"cmd":"time"}' http://127.0.0.1:9868
{"args":null,"cmd":"time","ok":true,"result":1437748263691,"trx":null}

curl -d '{"cmd":"time"}' http://127.0.0.1:9868
{"args":null,"cmd":"time","ok":true,"result":1437748295939,"trx":null}
```

We can execute transactions

```
curl -d '{"cmd":"time","trx":123}' http://127.0.0.1:9868
{"args":null,"cmd":"time","ok":true,"result":1437748333362,"trx":123}

curl -d '{"cmd":"time","trx":123}' http://127.0.0.1:9868
{"args":null,"cmd":"time","ok":true,"result":1437748333362,"trx":123}

curl -d '{"cmd":"time","trx":123}' http://127.0.0.1:9868
{"args":null,"cmd":"time","ok":true,"result":1437748333362,"trx":123}

curl -d '{"cmd":"time","trx":"qweqweqwe"}' http://127.0.0.1:9868
{"args":null,"cmd":"time","ok":true,"result":1437748813080,"trx":"qweqweqwe"}

curl -d '{"cmd":"time","trx":"qweqweqwe"}' http://127.0.0.1:9868
{"args":null,"cmd":"time","ok":true,"result":1437748813080,"trx":"qweqweqwe"}
```

Also it can handle incorrect requests

```
curl -d '{"cmd":"wrong"}' http://127.0.0.1:9868
{"args":null,"cmd":"wrong","ok":false,"result":"unexpected query %Wwwest.Proto{args: nil, cmd: \"wrong\", ok: false, result: nil, trx: nil}","trx":null}

curl http://127.0.0.1:9868
{"args":null,"cmd":null,"ok":false,"result":"Bad req, use POST","trx":null}

curl -d '{"cmd":"wrong"}}}}}}' http://127.0.0.1:9868
{"args":null,"cmd":null,"ok":false,"result":"Error on decoding req {:error, :invalid, \"}\"}","trx":null}
```