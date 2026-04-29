# `moonrocks`

`moonrocks` is a companion CLI to [LuaRocks][1] that serves as a **testbed for
new luarocks.org integrations** before they're finalized for the main LuaRocks
CLI. Commands here may eventually be upstreamed; in the meantime the tool is a
useful place to try out new workflows against the public registry.

Current commands:

* **`outdated`** — given a rockspec and a `luarocks.lock`, report which locked
  modules have newer versions available on luarocks.org *within the rockspec's
  version constraints*. Like `npm outdated` or `bundle outdated` for Lua.
* **`upload`** — pack and upload a rockspec/rock to luarocks.org. Predates the
  equivalent `luarocks upload`; if you only need to upload, modern LuaRocks
  does it natively.

## How to install

```bash
$ luarocks install moonrocks
```

> Add `--local` or `--tree` if you need to install to a different location.

## Commands

Run `moonrocks --help` for full options. The current commands are:

### `moonrocks outdated [<rockspec>]`

Compares the dependency version ranges in your `*.rockspec` against the pinned
versions in `./luarocks.lock`, then queries luarocks.org for the newest
available version of each dependency. Reports any module whose locked version
is behind the latest version that still satisfies the rockspec constraint.

```
$ moonrocks outdated
Fetching https://luarocks.org/manifest...
Package           Current    Wanted   Latest   Constraint
argparse          0.7.1-1    0.7.2-1  0.7.2-1  (any)
basexx            (missing)  -        -        (any)
date              2.2.1-1    2.2.1-2  2.2.1-2  (no constraint)
lapis-exceptions  2.4.0-1    2.5.0-1  2.5.0-1  ~> 2
tableshape        2.6.0-1    2.7.0-1  2.7.0-1  >= 2.4
```

* `Current` is the version pinned in `luarocks.lock`.
* `Wanted` is the highest version on luarocks.org that satisfies the
  rockspec's constraint (i.e. what you'd get from a fresh install).
* `Latest` is the highest version on luarocks.org overall — when this is
  ahead of `Wanted`, a newer release exists outside the rockspec range, hinting
  the constraint itself could be relaxed.
* `Constraint` shows the rockspec's version range. `(no constraint)` means a
  transitive dependency that's locked but not directly listed in the rockspec.

If no rockspec path is given and the current directory contains exactly one
`*.rockspec` file, it's used automatically. Constraint parsing and version
comparison match LuaRocks' own semantics (the relevant code is vendored from
upstream LuaRocks).

Flags:

* `--all` — show every dependency, not just outdated ones.
* `--lock <path>` — path to the lock file (default `./luarocks.lock`).
* `--installed` — add an `Installed` column showing the version currently
  installed in your local rocks tree (via `luarocks list --porcelain`). Rows
  where the installed version differs from `Current` (i.e. your lockfile and
  your rocks tree have drifted apart — you probably need to run `luarocks
  install`) are highlighted and shown by default even when they aren't
  otherwise outdated. Missing installs are reported as `(not installed)`.

```
$ moonrocks outdated --installed
Fetching https://luarocks.org/manifest...
Package    Current   Installed        Wanted    Latest    Constraint
argparse   0.7.2-1   0.7.1-1          0.7.2-1   0.7.2-1   (any)
basexx     0.4.1-1   (not installed)  0.4.1-1   0.4.1-1   (any)
penlight   1.15.0-1  1.14.0-3         1.15.0-1  1.15.0-1  >= 1.1.0
```

### `moonrocks upload <rockspec>`

Uploads a rockspec to luarocks.org. If the module doesn't exist yet it will be
created; if it does, a new version is added. If the version already exists
you'll be prompted to overwrite.

By default `upload` runs `luarocks pack` to build a `.src.rock` and uploads
that alongside the rockspec. Pass `--skip-pack` to skip the source rock.

All remote actions require a luarocks.org account and an API key. The first
time you run a remote command you'll be prompted to paste a key — generate one
at <https://luarocks.org/settings/api-keys>.

### `moonrocks login`

Set or replace your stored API key. You don't normally need to call this —
`upload` prompts for a key automatically when one isn't configured. Keys are
stored in `~/.config/moonrocks/config.lua`.

## Dependencies

* [argparse](https://github.com/luarocks/argparse)
* [Penlight](https://github.com/lunarmodules/Penlight)
* [ansicolors](https://github.com/kikito/ansicolors.lua)
* [luasocket](https://github.com/lunarmodules/luasocket)
* [lua-cjson](https://github.com/openresty/lua-cjson)

The `outdated` command's version-comparison code is vendored from
[LuaRocks](https://github.com/luarocks/luarocks) (MIT-licensed).

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

 [1]: https://luarocks.org
