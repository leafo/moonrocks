local Api
Api = require("moonrocks.api").Api
local File
File = require("moonrocks.multipart").File
local columnize
columnize = require("moonrocks.util").columnize
local colors = require("ansicolors")
local pretty = require("pl.pretty")
local load_rockspec, parse_rock_fname, prompt, actions, get_action, run
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
parse_rock_fname = function(fname)
  local base = fname:match("([^/]+)%.rock$")
  if not (base) then
    return nil, "not rock"
  end
  return base:match("^(.-)-([^-]+-[^-]+)%.([^.]+)$")
end
local _ = parse
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
actions = {
  {
    name = "upload",
    usage = "upload <rockspec|rock>",
    help = "Pack source rock, upload rockspec and source rock to server. Pass --skip-pack to skip sending source rock. Development rockspecs will skip uploading packed module by default, pass --upload-rock to force upload. Can also upload rock for existing module and version.",
    function(self, fname)
      if not (fname) then
        error("missing rockspec (moonrocks " .. tostring(get_action("upload").usage) .. ")")
      end
      local api = Api(self)
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
      if not (self["skip-pack"]) then
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
      if res.version.development and not self["upload-rock"] then
        print(colors("%{cyan}Skipping uploading rock for development version%{reset}"))
      elseif rock_fname then
        print(colors("%{cyan}Sending%{reset} " .. tostring(rock_fname) .. "..."))
        api:method("upload_rock/" .. tostring(res.version.id), nil, {
          rock_file = File(rock_fname)
        })
      end
      return print(colors("%{bright green}Success:%{reset} " .. tostring(res.module_url)))
    end
  },
  {
    name = "install",
    help = "Install a rock using `luarocks`, sets server to rocks.moonscript.org",
    function(self)
      local escaped_args
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = self.original_args
        for _index_0 = 1, #_list_0 do
          local arg = _list_0[_index_0]
          if arg:match("%s") then
            _accum_0[_len_0] = "'" .. arg:gsub("'", "'\'") .. "'"
          else
            _accum_0[_len_0] = arg
          end
          _len_0 = _len_0 + 1
        end
        escaped_args = _accum_0
      end
      local server = Api.server
      if not (server:match("^%w+://")) then
        server = "https://" .. server
      end
      table.insert(escaped_args, 1, "--server=" .. tostring(server))
      local cmd = "luarocks " .. tostring(table.concat(escaped_args, " "))
      return os.execute(cmd)
    end
  },
  {
    name = "login",
    help = "Set or change api key",
    function(self)
      local api = Api(self)
      if api:login() then
        return print(colors("%{bright green}Ok"))
      end
    end
  },
  {
    name = "help",
    help = "Show this text",
    function()
      print("MoonRocks " .. tostring(require("moonrocks.version")) .. " (using " .. tostring(Api.server) .. ")")
      print("usage: moonrocks <action> [arguments]")
      print()
      print("Available actions:")
      print()
      print(columnize((function()
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #actions do
          local t = actions[_index_0]
          _accum_0[_len_0] = {
            t.usage or t.name,
            t.help
          }
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)()))
      return print()
    end
  }
}
get_action = function(name)
  for _index_0 = 1, #actions do
    local action = actions[_index_0]
    if action.name == name then
      return action
    end
  end
end
run = function(params, flags)
  local action_name = params[1] or "help"
  local action = get_action(action_name)
  if not (action) then
    print(colors("%{bright red}Error:%{reset} unknown action `" .. tostring(action_name) .. "`"))
    run({
      "help"
    })
    return os.exit(1)
  end
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 2, #params do
      local p = params[_index_0]
      _accum_0[_len_0] = p
      _len_0 = _len_0 + 1
    end
    params = _accum_0
  end
  local fn = assert(action[1], "action is missing fn")
  return xpcall((function()
    return fn(flags, unpack(params))
  end), function(err)
    if not (flags.trace) then
      err = err:match("^.-:.-:.(.*)$") or err
    end
    local msg = colors("%{bright red}Error:%{reset} " .. tostring(err))
    if flags.trace then
      print(debug.traceback(msg, 2))
    else
      print(msg)
      print(" * Run with --trace to see traceback")
      print(" * Report issues to https://github.com/leafo/moonrocks/issues")
    end
    return os.exit(1)
  end)
end
return {
  run = run,
  actions = actions
}
