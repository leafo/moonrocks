local Api
Api = require("moonrocks.api").Api
local File
File = require("moonrocks.multipart").File
local colors = require("ansicolors")
local load_rockspec
load_rockspec = function(fname)
  local rockspec = { }
  local fn, err = loadfile(fname)
  if not (fn) then
    error("failed to load rockspec `" .. tostring(fname) .. "`: " .. tostring(err))
  end
  setfenv(fn, rockspec)
  assert(pcall(fn))
  assert(rockspec.package, "Invalid rockspec `" .. tostring(fname) .. "` (missing package)")
  assert(rockspec.version, "Invalid rockspec `" .. tostring(fname) .. " `(missing version)")
  return rockspec
end
local parse_rock_fname
parse_rock_fname = function(fname)
  local base = fname:match("([^/]+)%.rock$")
  if not (base) then
    return nil, "not rock"
  end
  return base:match("^(.-)-([^-]+-[^-]+)%.([^.]+)$")
end
local prompt
prompt = function(msg)
  while true do
    io.stdout:write(colors(tostring(msg) .. " [Y/n]: "))
    local line = io.stdin:read("*l")
    if line == "" then
      return true
    end
    if line == "n" then
      return false
    end
    if line:lower() == "y" then
      return true
    end
  end
end
local upload
upload = function(args)
  local fname = args.file
  local api = Api(args)
  local module_name, module_version = parse_rock_fname(fname)
  if module_name then
    local res = api:method("check_rockspec", {
      package = module_name,
      version = module_version
    })
    if not (res.version) then
      error("You don't have a module named " .. tostring(module_name) .. " with version " .. tostring(module_version) .. " in your account, did you upload a rockspec yet?")
    end
    print(colors("%{cyan}Sending%{reset} " .. tostring(fname) .. "..."))
    res = api:method("upload_rock/" .. tostring(res.version.id), nil, {
      rock_file = File(fname)
    })
    print(colors("%{bright green}Success:%{reset} " .. tostring(res.module_url)))
    return 
  end
  local rockspec = load_rockspec(fname)
  local rock_fname
  if not (args.skip_pack) then
    print(colors("%{cyan}Packing %{reset}" .. tostring(rockspec.package)))
    local ret = os.execute("luarocks pack '" .. tostring(fname) .. "'")
    if not (ret == 0) then
      print(colors("%{bright red}Failed to pack source rock!%{reset} (--skip-pack to disable)"))
      return 
    end
    rock_fname = fname:gsub("rockspec$", "src.rock")
  end
  print(colors("%{cyan}Sending%{reset} " .. tostring(fname) .. "..."))
  local res = api:method("check_rockspec", {
    package = rockspec.package,
    version = rockspec.version
  })
  if not (res.module) then
    print(colors("%{magenta}Will create new module.%{reset} (" .. tostring(rockspec.package) .. ")"))
  end
  if res.version then
    print(colors("%{bright yellow}A version of this module already exists.%{reset} (" .. tostring(rockspec.package) .. " " .. tostring(rockspec.version) .. ")"))
    if not (prompt("Overwite?")) then
      return 
    end
  else
    print(colors("%{magenta}Will create new version.%{reset} (" .. tostring(rockspec.version) .. ")"))
  end
  res = api:method("upload", nil, {
    rockspec_file = File(fname)
  })
  if res.is_new and #res.manifests == 0 then
    print(colors("%{bright yellow}Warning: module not added to root manifest due to name taken"))
  end
  if res.version.development and not args.upload_rock then
    print(colors("%{cyan}Skipping uploading rock for development version%{reset}"))
  elseif rock_fname then
    print(colors("%{cyan}Sending%{reset} " .. tostring(rock_fname) .. "..."))
    api:method("upload_rock/" .. tostring(res.version.id), nil, {
      rock_file = File(rock_fname)
    })
  end
  return print(colors("%{bright green}Success:%{reset} " .. tostring(res.module_url)))
end
local login
login = function(args)
  local api = Api(args)
  if api:login() then
    return print(colors("%{bright green}Ok"))
  end
end
return {
  upload = upload,
  login = login
}
