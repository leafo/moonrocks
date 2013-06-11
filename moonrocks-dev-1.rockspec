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
  "penlight >= 1.1.0"
}

build = {
  type = "builtin",
  modules = {
  },
  install = {
    bin = { "bin/moonrocks" }
  }
}