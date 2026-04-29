
import parse_version, compare_versions, match_constraints, parse_constraints
  from require "moonrocks.semver"

import insert, sort, concat from table

colors = require "ansicolors"

MANIFEST_URL = "https://luarocks.org/manifest"

load_rockspec = (fname) ->
  rockspec = {}
  fn, err = loadfile fname
  unless fn
    error "failed to load rockspec `#{fname}`: #{err}"
  setfenv fn, rockspec
  assert pcall fn
  assert rockspec.package, "Invalid rockspec `#{fname}` (missing package)"
  rockspec

load_lockfile = (fname) ->
  fn, err = loadfile fname
  unless fn
    error "failed to load lock file `#{fname}`: #{err}"
  data = fn!
  unless type(data) == "table" and type(data.dependencies) == "table"
    error "lock file `#{fname}` does not return a table with `dependencies`"
  data.dependencies

find_rockspec_in_cwd = ->
  matches = {}
  pfile = io.popen "ls *.rockspec 2>/dev/null"
  if pfile
    for line in pfile\lines!
      insert matches, line
    pfile\close!

  if #matches == 0
    error "no .rockspec file found in current directory; pass one as argument"
  if #matches > 1
    error "multiple .rockspec files found:\n  " .. concat(matches, "\n  ") ..
      "\nPass one as argument."
  matches[1]

debug_log = (debug, msg) ->
  return unless debug
  io.stderr\write colors "%{dim}[debug]%{reset} #{msg}\n"

local _manifest_cache
fetch_manifest = (debug=false) ->
  return _manifest_cache if _manifest_cache
  https = require "ssl.https"
  debug_log debug, colors "%{yellow}--> GET%{reset} #{MANIFEST_URL}"
  body, status, response_headers, status_line = https.request MANIFEST_URL
  unless body
    error "failed to fetch #{MANIFEST_URL}: #{status}"
  if debug
    debug_log debug, colors "%{green}<-- #{status_line or status}%{reset}"
    if response_headers
      for k, v in pairs response_headers
        debug_log debug, "    #{k}: #{v}"
    debug_log debug, "    response body: #{#body} bytes"
  unless status == 200
    error "failed to fetch #{MANIFEST_URL}: HTTP #{status}"
  fn, err = loadstring body
  unless fn
    error "failed to parse manifest: #{err}"
  env = {}
  setfenv fn, env
  fn!
  _manifest_cache = env
  env

fetch_installed = (debug=false) ->
  cmd = "luarocks list --porcelain 2>/dev/null"
  debug_log debug, colors "%{yellow}--> exec%{reset} #{cmd}"
  pfile = io.popen cmd
  unless pfile
    error "failed to run `luarocks list --porcelain`"
  installed = {}
  for line in pfile\lines!
    name, version = line\match "^([^\t]+)\t([^\t]+)"
    if name and version
      key = name\lower!
      existing = installed[key]
      if not existing or parse_version(existing) < parse_version(version)
        installed[key] = version
  pfile\close!
  installed

parse_dep = (s) ->
  name, rest = s\match "^%s*([%w_%-%.]+)%s*(.*)$"
  return nil unless name
  constraints, err = parse_constraints rest or ""
  unless constraints
    error "could not parse dependency `#{s}`: #{err}"
  name, constraints, (rest\match "^%s*(.-)%s*$") or ""

is_dev_version = (vstring) -> vstring\match("^%a") != nil

latest_matching = (versions_table, constraints, include_dev=false) ->
  best = nil
  for v in pairs versions_table
    continue if not include_dev and is_dev_version v
    pv = parse_version v
    matches = if constraints and #constraints > 0
      match_constraints pv, constraints
    else
      true
    if matches and (not best or best.parsed < pv)
      best = {version: v, parsed: pv}
  best and best.version

pad = (s, n) ->
  s = tostring s
  s ..= string.rep " ", n - #s if #s < n
  s

print_rows = (rows, show_all, show_installed) ->
  filtered = if show_all
    rows
  else
    [r for r in *rows when r.outdated or r.behind_rockspec or r.invalid or r.drift]

  if #filtered == 0
    print colors "%{bright green}All locked dependencies are up to date.%{reset}"
    return

  headers = if show_installed
    {"Package", "Current", "Installed", "Wanted", "Latest", "Constraint"}
  else
    {"Package", "Current", "Wanted", "Latest", "Constraint"}
  widths = [0 for _ in *headers]

  rendered = {}
  for r in *filtered
    row = if show_installed
      {
        r.name
        r.current
        r.installed or "(not installed)"
        r.wanted or "-"
        r.latest or "-"
        r.constraint_str
      }
    else
      {
        r.name
        r.current
        r.wanted or "-"
        r.latest or "-"
        r.constraint_str
      }
    insert rendered, row

  for i, h in ipairs headers
    widths[i] = #h
  for row in *rendered
    for i, cell in ipairs row
      widths[i] = math.max widths[i], #cell

  -- header
  hcells = [pad(c, widths[i] + 2) for i, c in ipairs headers]
  print colors "%{bright}#{concat hcells}"

  for i, row in ipairs rendered
    cells = [pad(c, widths[j] + 2) for j, c in ipairs row]
    line = concat cells
    orig = filtered[i]
    color = if orig.invalid
      "bright red"
    elseif orig.outdated
      "red"
    elseif orig.behind_rockspec
      "yellow"
    elseif orig.drift
      "magenta"
    elseif orig.transitive
      "dim"
    if color
      print colors "%{#{color}}#{line}"
    else
      print line

outdated = (args) ->
  rockspec_fname = args.rockspec or find_rockspec_in_cwd!
  lock_fname = args.lock or "luarocks.lock"

  rockspec = load_rockspec rockspec_fname
  locked = load_lockfile lock_fname

  io.stderr\write colors "%{cyan}Fetching #{MANIFEST_URL}...%{reset}\n"
  manifest = fetch_manifest args.debug

  installed_map = if args.installed
    fetch_installed args.debug

  -- index rockspec deps by lowercase name
  rockspec_deps = {}
  for spec in *(rockspec.dependencies or {})
    name, constraints, raw_constraint = parse_dep spec
    if name and name\lower! != "lua"
      rockspec_deps[name\lower!] = {
        :constraints
        :raw_constraint
        original_name: name
      }

  rows = {}
  seen_in_lock = {}

  for name, current in pairs locked
    seen_in_lock[name\lower!] = true
    repo_entry = manifest.repository and manifest.repository[name\lower!]
    rd = rockspec_deps[name\lower!]
    constraints = rd and rd.constraints
    locked_is_dev = is_dev_version current

    wanted, latest = nil, nil
    if repo_entry
      wanted = latest_matching repo_entry, constraints, locked_is_dev
      latest = latest_matching repo_entry, nil, locked_is_dev

    constraint_str = if rd
      if rd.raw_constraint == "" then "(any)" else rd.raw_constraint
    else
      "(no constraint)"

    installed_version = installed_map and installed_map[name\lower!]

    row = {
      :name
      :current
      :wanted
      :latest
      :constraint_str
      installed: installed_version
      drift: installed_map != nil and installed_version != current
      transitive: rd == nil
      on_server: repo_entry != nil
    }

    if not repo_entry
      row.invalid = true
      row.wanted = "(not on luarocks.org)"
      row.latest = "-"
    else
      if wanted
        cur_pv = parse_version current
        wanted_pv = parse_version wanted
        row.outdated = cur_pv < wanted_pv
      elseif constraints and #constraints > 0
        row.invalid = true
        row.wanted = "(no match for constraint)"

      if wanted and latest
        if parse_version(wanted) < parse_version(latest)
          row.behind_rockspec = true

    insert rows, row

  -- rockspec deps not in the lock
  for lname, rd in pairs rockspec_deps
    unless seen_in_lock[lname]
      insert rows, {
        name: rd.original_name
        current: "(missing)"
        wanted: "-"
        latest: "-"
        constraint_str: rd.raw_constraint == "" and "(any)" or rd.raw_constraint
        installed: installed_map and installed_map[lname]
        invalid: true
      }

  sort rows, (a, b) -> a.name\lower! < b.name\lower!
  print_rows rows, args.all, args.installed

{ :outdated }
