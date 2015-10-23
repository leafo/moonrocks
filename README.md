# `moonrocks`

A command line tool for uploading and installing from the public Lua module
hosting site, [LuaRocks][1].

This tool is no longer necessary as this functionality has been added to the
main [LuaRocks tool](https://github.com/keplerproject/luarocks/wiki/upload).

## How To Install

Install using LuaRocks:

```bash
$ luarocks install moonrocks
```

> Add `--local` or `--tree` if you need to install to a different location

This will give us the command line tool `moonrocks`.

## How To Use

`moonrocks` comes with two main commands, `install` and `upload`. You can run
`moonrocks help` to see help from the command line.

### `moonrocks install`

> This command is no longer necessary as rocks.moonrocks.org has become luarocks.org

`install` is a simple wrapper for running `luarocks install`, except that it
prepends `--server=http://rocks.moonscript.org` to the argument list, ensuring
that MoonRocks is checked as a module source.

For example, the following two commands are equivalent:

```bash
$ moonrocks install --local moonscript # install with moonrocks

$ luarocks --server=http://rocks.moonscript.org install --local moonscript # install with luarocks
```

### `moonrocks upload <rockspec>`

`upload` will upload a rockspec to the server. If the module doesn't exist yet
it will be created, if it already exists the new version will be added to it.
If a version for that rockspec already exists then you will be prompted to
overwrite.

This is equivalent to going to <http://rocks.moonscript.org/upload> and
uploading a rockspec.

By default `upload` will use `luarocks pack` to pack the rockspec into a rock.
That rock will also be uploaded along with the rockspec. (This creates a src
rock). If you don't wish to pack and upload a rock then include the flag
`--skip-pack`

All remote actions (such as uploading a rockspec) require an associated account
on [MoonRocks][1]. You give access to your account by generating and API key.
The first time you issue a remote command you will be asked to log in. This
involves generating an API key at <http://rocks.moonscript.org/settings> and
pasting it into the tool.


### `moonrocks login`

You can call `login` to set or replace your API key. You shouldn't normally
need to call this, `upload` will attempt to log you in automatically if a key
is not configured.

Your API key is stored in `USER_HOME/.moonrocks/config.lua`.


## Dependencies

Thanks to the following libraries:

* [Penlight](https://github.com/stevedonovan/Penlight)
* [ansicolors](https://github.com/kikito/ansicolors.lua)
* [luasocket](http://w3.impa.br/~diego/software/luasocket/)
* [lua-cjson](http://www.kyne.com.au/~mark/software/lua-cjson.php)


## License (MIT)

Copyright (C) 2013 by Leaf Corcoran

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

 [1]: http://rocks.moonscript.org

