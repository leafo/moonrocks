package = "moonrocks"
version = "dev-1"

source = {
  url = "git://github.com/leafo/moonrocks.git"
}


description = {
  summary = "A tool for installing and uploading Lua packages to rocks.moonscript.org",
  homepage = "http://rocks.moonscript.org/",
  maintainer = "Leaf Corcoran <leafot@gmail.com>",
  license = "MIT"
}

dependencies = {
  "lua >= 5.1",
  "penlight >= 1.1.0",
  "ansicolors",
  "luasocket",
  "lua-cjson",
}

build = {
  type = "builtin",
  modules = {
    ["moonrocks.actions"] = "moonrocks/actions.lua",
    ["moonrocks.api"] = "moonrocks/api.lua",
    ["moonrocks.multipart"] = "moonrocks/multipart.lua",
    ["moonrocks.util"] = "moonrocks/util.lua",
    ["moonrocks.version"] = "moonrocks/version.lua",
  },
  install = {
    bin = { "bin/moonrocks" }
  }
}