defmodule Wwwest.Structs do
	use Silverb
	defmacro __using__(_) do
		quote location: :keep do
			defmodule Proto do
				defstruct 	id: nil, # request id
							cmd: nil,
							args: nil,
							trx: nil,
							ok: false,
							result: nil
			end
		end
	end
end