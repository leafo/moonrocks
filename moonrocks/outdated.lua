local parse_version, compare_versions, match_constraints, parse_constraints
do
  local _obj_0 = require("moonrocks.semver")
  parse_version, compare_versions, match_constraints, parse_constraints = _obj_0.parse_version, _obj_0.compare_versions, _obj_0.match_constraints, _obj_0.parse_constraints
end
local insert, sort, concat
do
  local _obj_0 = table
  insert, sort, concat = _obj_0.insert, _obj_0.sort, _obj_0.concat
end
local colors = require("ansicolors")
local MANIFEST_URL = "https://luarocks.org/manifest"
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
  return rockspec
end
local load_lockfile
load_lockfile = function(fname)
  local fn, err = loadfile(fname)
  if not (fn) then
    error("failed to load lock file `" .. tostring(fname) .. "`: " .. tostring(err))
  end
  local data = fn()
  if not (type(data) == "table" and type(data.dependencies) == "table") then
    error("lock file `" .. tostring(fname) .. "` does not return a table with `dependencies`")
  end
  return data.dependencies
end
local find_rockspec_in_cwd
find_rockspec_in_cwd = function()
  local matches = { }
  local pfile = io.popen("ls *.rockspec 2>/dev/null")
  if pfile then
    for line in pfile:lines() do
      insert(matches, line)
    end
    pfile:close()
  end
  if #matches == 0 then
    error("no .rockspec file found in current directory; pass one as argument")
  end
  if #matches > 1 then
    error("multiple .rockspec files found:\n  " .. concat(matches, "\n  ") .. "\nPass one as argument.")
  end
  return matches[1]
end
local debug_log
debug_log = function(debug, msg)
  if not (debug) then
    return 
  end
  return io.stderr:write(colors("%{dim}[debug]%{reset} " .. tostring(msg) .. "\n"))
end
local _manifest_cache
local fetch_manifest
fetch_manifest = function(debug)
  if debug == nil then
    debug = false
  end
  if _manifest_cache then
    return _manifest_cache
  end
  local https = require("ssl.https")
  debug_log(debug, colors("%{yellow}--> GET%{reset} " .. tostring(MANIFEST_URL)))
  local body, status, response_headers, status_line = https.request(MANIFEST_URL)
  if not (body) then
    error("failed to fetch " .. tostring(MANIFEST_URL) .. ": " .. tostring(status))
  end
  if debug then
    debug_log(debug, colors("%{green}<-- " .. tostring(status_line or status) .. "%{reset}"))
    if response_headers then
      for k, v in pairs(response_headers) do
        debug_log(debug, "    " .. tostring(k) .. ": " .. tostring(v))
      end
    end
    debug_log(debug, "    response body: " .. tostring(#body) .. " bytes")
  end
  if not (status == 200) then
    error("failed to fetch " .. tostring(MANIFEST_URL) .. ": HTTP " .. tostring(status))
  end
  local fn, err = loadstring(body)
  if not (fn) then
    error("failed to parse manifest: " .. tostring(err))
  end
  local env = { }
  setfenv(fn, env)
  fn()
  _manifest_cache = env
  return env
end
local parse_dep
parse_dep = function(s)
  local name, rest = s:match("^%s*([%w_%-%.]+)%s*(.*)$")
  if not (name) then
    return nil
  end
  local constraints, err = parse_constraints(rest or "")
  if not (constraints) then
    error("could not parse dependency `" .. tostring(s) .. "`: " .. tostring(err))
  end
  return name, constraints, (rest:match("^%s*(.-)%s*$")) or ""
end
local is_dev_version
is_dev_version = function(vstring)
  return vstring:match("^%a") ~= nil
end
local latest_matching
latest_matching = function(versions_table, constraints, include_dev)
  if include_dev == nil then
    include_dev = false
  end
  local best = nil
  for v in pairs(versions_table) do
    local _continue_0 = false
    repeat
      if not include_dev and is_dev_version(v) then
        _continue_0 = true
        break
      end
      local pv = parse_version(v)
      local matches
      if constraints and #constraints > 0 then
        matches = match_constraints(pv, constraints)
      else
        matches = true
      end
      if matches and (not best or best.parsed < pv) then
        best = {
          version = v,
          parsed = pv
        }
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return best and best.version
end
local pad
pad = function(s, n)
  s = tostring(s)
  if #s < n then
    s = s .. string.rep(" ", n - #s)
  end
  return s
end
local print_rows
print_rows = function(rows, show_all)
  local filtered
  if show_all then
    filtered = rows
  else
    do
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #rows do
        local r = rows[_index_0]
        if r.outdated or r.behind_rockspec or r.invalid then
          _accum_0[_len_0] = r
          _len_0 = _len_0 + 1
        end
      end
      filtered = _accum_0
    end
  end
  if #filtered == 0 then
    print(colors("%{bright green}All locked dependencies are up to date.%{reset}"))
    return 
  end
  local headers = {
    "Package",
    "Current",
    "Wanted",
    "Latest",
    "Constraint"
  }
  local widths = {
    0,
    0,
    0,
    0,
    0
  }
  local rendered = { }
  for _index_0 = 1, #filtered do
    local r = filtered[_index_0]
    insert(rendered, {
      r.name,
      r.current,
      r.wanted or "-",
      r.latest or "-",
      r.constraint_str
    })
  end
  for i, h in ipairs(headers) do
    widths[i] = #h
  end
  for _index_0 = 1, #rendered do
    local row = rendered[_index_0]
    for i, cell in ipairs(row) do
      widths[i] = math.max(widths[i], #cell)
    end
  end
  local hcells
  do
    local _accum_0 = { }
    local _len_0 = 1
    for i, c in ipairs(headers) do
      _accum_0[_len_0] = pad(c, widths[i] + 2)
      _len_0 = _len_0 + 1
    end
    hcells = _accum_0
  end
  print(colors("%{bright}" .. tostring(concat(hcells))))
  for i, row in ipairs(rendered) do
    local cells
    do
      local _accum_0 = { }
      local _len_0 = 1
      for j, c in ipairs(row) do
        _accum_0[_len_0] = pad(c, widths[j] + 2)
        _len_0 = _len_0 + 1
      end
      cells = _accum_0
    end
    local line = concat(cells)
    local orig = filtered[i]
    local color
    if orig.invalid then
      color = "bright red"
    elseif orig.outdated then
      color = "red"
    elseif orig.behind_rockspec then
      color = "yellow"
    elseif orig.transitive then
      color = "dim"
    end
    if color then
      print(colors("%{" .. tostring(color) .. "}" .. tostring(line)))
    else
      print(line)
    end
  end
end
local outdated
outdated = function(args)
  local rockspec_fname = args.rockspec or find_rockspec_in_cwd()
  local lock_fname = args.lock or "luarocks.lock"
  local rockspec = load_rockspec(rockspec_fname)
  local locked = load_lockfile(lock_fname)
  io.stderr:write(colors("%{cyan}Fetching " .. tostring(MANIFEST_URL) .. "...%{reset}\n"))
  local manifest = fetch_manifest(args.debug)
  local rockspec_deps = { }
  local _list_0 = (rockspec.dependencies or { })
  for _index_0 = 1, #_list_0 do
    local spec = _list_0[_index_0]
    local name, constraints, raw_constraint = parse_dep(spec)
    if name and name:lower() ~= "lua" then
      rockspec_deps[name:lower()] = {
        constraints = constraints,
        raw_constraint = raw_constraint,
        original_name = name
      }
    end
  end
  local rows = { }
  local seen_in_lock = { }
  for name, current in pairs(locked) do
    seen_in_lock[name:lower()] = true
    local repo_entry = manifest.repository and manifest.repository[name:lower()]
    local rd = rockspec_deps[name:lower()]
    local constraints = rd and rd.constraints
    local locked_is_dev = is_dev_version(current)
    local wanted, latest = nil, nil
    if repo_entry then
      wanted = latest_matching(repo_entry, constraints, locked_is_dev)
      latest = latest_matching(repo_entry, nil, locked_is_dev)
    end
    local constraint_str
    if rd then
      if rd.raw_constraint == "" then
        constraint_str = "(any)"
      else
        constraint_str = rd.raw_constraint
      end
    else
      constraint_str = "(no constraint)"
    end
    local row = {
      name = name,
      current = current,
      wanted = wanted,
      latest = latest,
      constraint_str = constraint_str,
      transitive = rd == nil,
      on_server = repo_entry ~= nil
    }
    if not repo_entry then
      row.invalid = true
      row.wanted = "(not on luarocks.org)"
      row.latest = "-"
    else
      if wanted then
        local cur_pv = parse_version(current)
        local wanted_pv = parse_version(wanted)
        row.outdated = cur_pv < wanted_pv
      elseif constraints and #constraints > 0 then
        row.invalid = true
        row.wanted = "(no match for constraint)"
      end
      if wanted and latest then
        if parse_version(wanted) < parse_version(latest) then
          row.behind_rockspec = true
        end
      end
    end
    insert(rows, row)
  end
  for lname, rd in pairs(rockspec_deps) do
    if not (seen_in_lock[lname]) then
      insert(rows, {
        name = rd.original_name,
        current = "(missing)",
        wanted = "-",
        latest = "-",
        constraint_str = rd.raw_constraint == "" and "(any)" or rd.raw_constraint,
        invalid = true
      })
    end
  end
  sort(rows, function(a, b)
    return a.name:lower() < b.name:lower()
  end)
  return print_rows(rows, args.all)
end
return {
  outdated = outdated
}
