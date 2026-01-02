
import Api from require "moonrocks.api"
import File from require "moonrocks.multipart"

colors = require "ansicolors"

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

prompt = (msg) ->
  while true
    io.stdout\write colors "#{msg} [Y/n]: "
    line = io.stdin\read "*l"
    return true if line == ""
    return false if line == "n"
    return true if line\lower! == "y"

upload = (args) ->
  fname = args.file

  api = Api args

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

  rock_fname = unless args.skip_pack
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

  if res.version.development and not args.upload_rock
    print colors "%{cyan}Skipping uploading rock for development version%{reset}"
  elseif rock_fname
    print colors "%{cyan}Sending%{reset} #{rock_fname}..."
    api\method "upload_rock/#{res.version.id}", nil, rock_file: File(rock_fname)

  print colors "%{bright green}Success:%{reset} #{res.module_url}"

login = (args) ->
  api = Api args
  if api\login!
    print colors "%{bright green}Ok"

{ :upload, :login }
