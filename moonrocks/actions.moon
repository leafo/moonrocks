
import Api from require "moonrocks.api"
import File from require "moonrocks.multipart"

pretty = require "pl.pretty"

moon = require "moon"

load_rockspec = (fname) ->
  rockspec = {}
  fn = assert loadfile fname
  setfenv fn, rockspec
  assert pcall fn

  assert rockspec.package, "Invalid rockspec `#{fname}` (missing package)"
  assert rockspec.version, "Invalid rockspec `#{fname} `(missing version)"

  rockspec

prompt = (msg) ->
  while true
    io.stdout\write "#{msg} [Y/n]: "
    line = io.stdin\read "*l"
    return false if line == "n"
    return true if line == "Y"

actions = {
  login: =>
    api = Api @
    api\login!

  install: =>
    error "TODO"

  push: (fname) =>
    api = Api @
    rockspec = load_rockspec fname

    print "Sending #{fname}..."

    res = api\method "check_rockspec", {
      package: rockspec.package
      version: rockspec.version
    }

    unless res.module
      print "Will create new module. (#{rockspec.package})"

    if res.version
      print "A version of this module already exists. (#{rockspec.package} #{rockspec.version})"
      return unless prompt "Overwite existing rockspec?"
    else
      print "Will create new version. (#{rockspec.version})"

    res = api\method "upload", nil, rockspec_file: File(fname)

    if res.module_url
      print "Rockspec uploaded: #{res.module_url}"
}

run = (params, flags) ->
  action_name = assert params[1], "missing command"
  fn = assert actions[action_name], "unknown action `#{action_name}`"
  params = [p for p in *params[2,]]
  fn flags, unpack params

{ :run, :actions }

