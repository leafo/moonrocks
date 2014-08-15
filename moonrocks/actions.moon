
import Api from require "moonrocks.api"
import File from require "moonrocks.multipart"
import columnize from require "moonrocks.util"

colors = require "ansicolors"

pretty = require "pl.pretty"

local *

load_rockspec = (fname) ->
  rockspec = {}
  fn, err = loadfile fname
  unless fn
    error "failed to load rockspec `#{fname}`: #{err}"

  setfenv fn, rockspec
  assert pcall fn

  assert rockspec.package, "Invalid rockspec `#{fname}` (missing package)"
  assert rockspec.version, "Invalid rockspec `#{fname} `(missing version)"

  rockspec

parse_rock_fname = (fname) ->
  base = fname\match "([^/]+)%.rock$"
  unless base
    return nil, "not rock"

  base\match "^(.-)-([^-]+-[^-]+)%.([^.]+)$"

parse

prompt = (msg) ->
  while true
    io.stdout\write colors "#{msg} [Y/n]: "
    line = io.stdin\read "*l"
    return false if line == "n"
    return true if line == "Y"

actions = {
  {
    name: "upload"
    usage: "upload <rockspec|rock>"
    help: "Pack source rock, upload rockspec and source rock to server. Pass --skip-pack to skip sending source rock. Development rockspecs will skip uploading packed module by default, pass --upload-rock to force upload. Can also upload rock for existing module and version."

    (fname) =>
      unless fname
        error "missing rockspec (moonrocks #{get_action"upload".usage})"

      api = Api @

      -- see if just uploading rock
      module_name, module_version = parse_rock_fname fname
      if module_name
        res = api\method "check_rockspec", {
          package: module_name
          version: module_version
        }

        unless res.version
          error "You don't have a module named #{module_name} with version #{module_version} in your account, did you upload a rockspec yet?"

        print colors "%{cyan}Sending%{reset} #{fname}..."
        res = api\method "upload_rock/#{res.version.id}", nil, rock_file: File(fname)
        print colors "%{bright green}Success:%{reset} #{res.module_url}"
        return

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

      if res.version.development and not @["upload-rock"]
        print colors "%{cyan}Skipping uploading rock for development version%{reset}"
      elseif rock_fname
        print colors "%{cyan}Sending%{reset} #{rock_fname}..."
        api\method "upload_rock/#{res.version.id}", nil, rock_file: File(rock_fname)

      print colors "%{bright green}Success:%{reset} #{res.module_url}"

  }

  {
    name: "install"
    help: "Install a rock using `luarocks`, sets server to rocks.moonscript.org"
    =>
      escaped_args = for arg in *@original_args
        -- hope this is good enough ;)
        if arg\match "%s"
          "'" ..arg\gsub("'", "'\'") .. "'"
        else
          arg

      server = Api.server
      server = "http://" .. server unless server\match "^%w+://"

      table.insert escaped_args, 1, "--server=#{server}"

      cmd = "luarocks #{table.concat escaped_args, " "}"
      os.execute cmd
  }

  {
    name: "login"
    help: "Set or change api key"

    =>
      api = Api @
      if api\login!
        print colors "%{bright green}Ok"
  }

  {
    name: "help"
    help: "Show this text"
    ->
      print "MoonRocks #{require "moonrocks.version"} (using #{Api.server})"
      print "usage: moonrocks <action> [arguments]"

      print!
      print "Available actions:"
      print!
      print columnize [ { t.usage or t.name, t.help } for t in *actions ]
      print!
  }
}

get_action = (name) ->
  for action in *actions
    if action.name == name
      return action

run = (params, flags) ->
  action_name = params[1] or "help"
  action = get_action(action_name)

  unless action
    print colors "%{bright red}Error:%{reset} unknown action `#{action_name}`"
    run { "help" }
    return os.exit 1

  params = [p for p in *params[2,]]

  fn = assert action[1], "action is missing fn"
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

