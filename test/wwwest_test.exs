defmodule WwwestTest do
use ExUnit.Case
	defp exec(req) do
		ans = 	case String.to_char_list(req) |> :os.cmd |> to_string |> String.split("\n") do
					[_,_,_,ans] -> Jazz.decode!(ans) |> Map.get("result")
					some -> Enum.join(some,"\n")
				end
		:timer.sleep(100)
		IO.puts(req)
		IO.puts(to_string(ans)<>"\n")
	end
	test "the truth" do
		:timer.sleep(1000)
		[
			"curl -d '{\"cmd\":\"sum\",\"args\":[1,2,3]}' -u login:password http://127.0.0.1:9868",
			"curl -d '{\"cmd\":\"time\"}' -u login:password http://127.0.0.1:9868",
			"curl -d '{\"cmd\":\"time\"}' -u login:password http://127.0.0.1:9868",
			"curl -d '{\"cmd\":\"time\",\"trx\":123}' -u login:password http://127.0.0.1:9868",
			"curl -d '{\"cmd\":\"time\",\"trx\":123}' -u login:password http://127.0.0.1:9868",
			"curl -d '{\"cmd\":\"time\",\"trx\":123}' -u login:password http://127.0.0.1:9868",
			"curl -d '{\"cmd\":\"time\",\"trx\":\"qweqweqwe\"}' -u login:password http://127.0.0.1:9868",
			"curl -d '{\"cmd\":\"time\",\"trx\":\"qweqweqwe\"}' -u login:password http://127.0.0.1:9868",
			"curl -d '{\"cmd\":\"wrong\"}' -u login:password http://127.0.0.1:9868",
			"curl -u login:password http://127.0.0.1:9868",
			"curl -d '{\"cmd\":\"wrong\"}}}}}}' -u login:password http://127.0.0.1:9868",
			"curl -d '{\"cmd\":\"sum\",\"args\":[1,2,3]}' -u not:auth -v http://127.0.0.1:9868"
		]
		|> Enum.each(&exec/1)
		assert 1 + 1 == 2
	end
end
