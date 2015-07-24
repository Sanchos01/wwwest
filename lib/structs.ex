defmodule Wwwest.Structs do
	use Silverb
	defmacro __using__(_) do
		quote location: :keep do
			use Hashex, [
							__MODULE__.Proto
						]
			defmodule Proto do
				defstruct 	cmd: nil,
							args: nil,
							trx: nil,
							ok: false,
							result: nil
			end
		end
	end
end