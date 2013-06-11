
import appfile from require "pl.app"
import makepath from require "pl.dir"
import dirname from require "pl.path"

pretty = require "pl.pretty"

class Api
  new: (config="config") =>
    @_config_fname = appfile(config) .. ".lua"
    @read!

  read: =>
    if f = io.open @_config_fname, "r"
      content = f\read "*a"
      f\close!

      config = pretty.read content
      if config
        for k,v in pairs config
          @[k] = v

  write: =>
    makepath dirname @_config_fname
    filtered = { k,v for k,v in pairs(@) when not k\match "^_" }
    with io.open @_config_fname, "w"
      \write pretty.write filtered
      \close!
    true

{ :Api }

