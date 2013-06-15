
local: build
	luarocks make --local

build::
	moonc moonrocks
	echo '#!/usr/bin/env lua' > bin/moonrocks
	moonc -p bin/moonrocks.moon >> bin/moonrocks
	echo '-- v''im: set filetype=lua:' >> bin/moonrocks
	chmod +x bin/moonrocks
