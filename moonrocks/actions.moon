
import Api from require "moonrocks.api"
import File from require "moonrocks.multipart"

colors = require "ansicolors"

pretty = require "pl.pretty"

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
    io.stdout\write colors "#{msg} [Y/n]: "
    line = io.stdin\read "*l"
    return false if line == "n"
    return true if line == "Y"

actions = {
  login: =>
    api = Api @
    api\login!

  install: =>
    error "TODO"

  upload: (fname) =>
    api = Api @
    rockspec = load_rockspec fname

    print colors "%{cyan}Sending%{reset} #{fname}..."

    res = api\method "check_rockspec", {
      package: rockspec.package
      version: rockspec.version
    }

    unless res.module
      print "Will create new module. (#{rockspec.package})"

    if res.version
      print colors "%{bright yellow}A version of this module already exists.%{reset} (#{rockspec.package} #{rockspec.version})"
      return unless prompt "Overwite existing rockspec?"
    else
      print "Will create new version. (#{rockspec.version})"

    res = api\method "upload", nil, rockspec_file: File(fname)

    if res.is_new and #res.manifests == 0
      print colors "%{bright yellow}Warning: module not added to root manifest due to name taken"

    if res.module_url
      print colors "%{bright green}Rockspec uploaded:%{reset} #{res.module_url}"
}

run = (params, flags) ->
  action_name = assert params[1], "missing command"
  fn = assert actions[action_name], "unknown action `#{action_name}`"
  params = [p for p in *params[2,]]
  fn flags, unpack params

{ :run, :actions }

