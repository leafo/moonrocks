
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

    rock_fname = unless @["skip-pack"]
      print colors "%{cyan}Packing %{reset}#{rockspec.package}"
      ret = os.execute "luarocks pack '#{fname}'"
      unless ret == 0
        print colors "%{bright red}Failed to pack source rock!%{reset} (--skip-pack to disable)"
        return

      fname\gsub "rockspec$", "src.rock"

    print colors "%{cyan}Sending%{reset} #{fname}..."

    res = api\method "check_rockspec", {
      package: rockspec.package
      version: rockspec.version
    }

    unless res.module
      print colors "%{magenta}Will create new module.%{reset} (#{rockspec.package})"

    if res.version
      print colors "%{bright yellow}A version of this module already exists.%{reset} (#{rockspec.package} #{rockspec.version})"
      return unless prompt "Overwite?"
    else
      print colors "%{magenta}Will create new version.%{reset} (#{rockspec.version})"

    res = api\method "upload", nil, rockspec_file: File(fname)

    if res.is_new and #res.manifests == 0
      print colors "%{bright yellow}Warning: module not added to root manifest due to name taken"

    if rock_fname
      print colors "%{cyan}Sending%{reset} #{rock_fname}..."
      api\method "upload_rock/#{res.version.id}", nil, rock_file: File(rock_fname)

    print colors "%{bright green}Success:%{reset} #{res.module_url}"
}

run = (params, flags) ->
  action_name = assert params[1], "missing command"
  fn = assert actions[action_name], "unknown action `#{action_name}`"
  params = [p for p in *params[2,]]

  xpcall (-> fn flags, unpack params), (err) ->
    err = err\match("^.-:.-:.(.*)$") or err unless flags.trace
    msg = colors "%{bright red}Error:%{reset} #{err}"
    if flags.trace
      print debug.traceback msg, 2
    else
      print msg
      print " * Run with --trace to see traceback"
      print " * Report issues to https://github.com/leafo/moonrocks/issues"

    os.exit 1

{ :run, :actions }

