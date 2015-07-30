Wwwest
======

Amazing simple long pooling wrapper around erlang cowboy. First, write config, like this

```
config :wwwest, 
	server_port: 9868, 
	server_timeout: 20000, # timeout for all requests
	memo_ttl: 3600000, # timeout for memorize json encode and decode
	trx_ttl: 3600000, # timeout for all trx transactions
	callback_module: Wwwest.Example, # here are handlers for requests
	basic_auth: %{login: "login", password: "password"} # | :none
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
curl -d '{"cmd":"sum", "args":[1,2,3]}' -u login:password http://127.0.0.1:9868
{"args":[1,2,3],"cmd":"sum","ok":true,"result":6,"trx":null}

curl -d '{"cmd":"time"}' -u login:password http://127.0.0.1:9868
{"args":null,"cmd":"time","ok":true,"result":1437748263691,"trx":null}

curl -d '{"cmd":"time"}' -u login:password http://127.0.0.1:9868
{"args":null,"cmd":"time","ok":true,"result":1437748295939,"trx":null}
```

We can execute transactions

```
curl -d '{"cmd":"time","trx":123}' -u login:password http://127.0.0.1:9868
{"args":null,"cmd":"time","ok":true,"result":1437748333362,"trx":123}

curl -d '{"cmd":"time","trx":123}' -u login:password http://127.0.0.1:9868
{"args":null,"cmd":"time","ok":true,"result":1437748333362,"trx":123}

curl -d '{"cmd":"time","trx":123}' -u login:password http://127.0.0.1:9868
{"args":null,"cmd":"time","ok":true,"result":1437748333362,"trx":123}

curl -d '{"cmd":"time","trx":"qweqweqwe"}' -u login:password http://127.0.0.1:9868
{"args":null,"cmd":"time","ok":true,"result":1437748813080,"trx":"qweqweqwe"}

curl -d '{"cmd":"time","trx":"qweqweqwe"}' -u login:password http://127.0.0.1:9868
{"args":null,"cmd":"time","ok":true,"result":1437748813080,"trx":"qweqweqwe"}
```

Also it can handle incorrect requests

```
curl -d '{"cmd":"wrong"}' -u login:password http://127.0.0.1:9868
{"args":null,"cmd":"wrong","ok":false,"result":"unexpected query %Wwwest.Proto{args: nil, cmd: \"wrong\", ok: false, result: nil, trx: nil}","trx":null}

curl -u login:password http://127.0.0.1:9868 
{"args":null,"cmd":null,"ok":false,"result":"Bad req, use POST","trx":null}

curl -d '{"cmd":"wrong"}}}}}}' -u login:password http://127.0.0.1:9868
{"args":null,"cmd":null,"ok":false,"result":"Error on decoding req {:error, :invalid, \"}\"}","trx":null}
```

And basic auth is avalible

```
curl -d '{"cmd":"sum", "args":[1,2,3]}' -u not:auth -v http://127.0.0.1:9868
* Rebuilt URL to: http://127.0.0.1:9868/
* Hostname was NOT found in DNS cache
*   Trying 127.0.0.1...
* Connected to 127.0.0.1 (127.0.0.1) port 9868 (#0)
* Server auth using Basic with user 'not'
> POST / HTTP/1.1
> Authorization: Basic bm90OmF1dGg=
> User-Agent: curl/7.37.1
> Host: 127.0.0.1:9868
> Accept: */*
> Content-Length: 29
> Content-Type: application/x-www-form-urlencoded
>
* upload completely sent off: 29 out of 29 bytes
< HTTP/1.1 401 Unauthorized
* Server Cowboy is not blacklisted
< server: Cowboy
< date: Thu, 30 Jul 2015 13:30:48 GMT
< content-length: 0
* Authentication problem. Ignoring this.
< WWW-Authenticate: Basic realm="wwwest server"
< connection: close
<
* Closing connection 0
```