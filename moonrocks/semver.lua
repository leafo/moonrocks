-- Version parsing, comparison, and constraint matching.
--
-- Vendored from luarocks (MIT-licensed):
--   parse_version / compare_versions / partial_match / match_constraints
--     -> luarocks/src/luarocks/core/semver.lua
--   parse_constraint / parse_constraints
--     -> luarocks/src/luarocks/queries.lua
--
-- Adapted: removed the _tl_compat shim (we run on Lua 5.1+ directly) and
-- replaced the single util.warning() call inside parse_version with error().
-- Kept semantics identical so rockspec constraints behave exactly as luarocks
-- itself would interpret them.

local semver = {}

local deltas = {
   dev = 120000000,
   scm = 110000000,
   cvs = 100000000,
   rc = -1000,
   pre = -10000,
   beta = -100000,
   alpha = -1000000,
}

local version_mt = {
   __eq = function(v1, v2)
      if #v1 ~= #v2 then
         return false
      end
      for i = 1, #v1 do
         if v1[i] ~= v2[i] then
            return false
         end
      end
      if v1.revision and v2.revision then
         return (v1.revision == v2.revision)
      end
      return true
   end,

   __lt = function(v1, v2)
      for i = 1, math.max(#v1, #v2) do
         local v1i, v2i = v1[i] or 0, v2[i] or 0
         if v1i ~= v2i then
            return (v1i < v2i)
         end
      end
      if v1.revision and v2.revision then
         return (v1.revision < v2.revision)
      end
      return false
   end,

   __le = function(v1, v2)
      return not (v2 < v1)
   end,

   __tostring = function(v)
      return v.string
   end,
}

local version_cache = {}
setmetatable(version_cache, { __mode = "kv" })

function semver.parse_version(vstring)
   if not vstring then return nil end

   local cached = version_cache[vstring]
   if cached then
      return cached
   end

   local version = {}
   local i = 1

   local function add_token(number)
      version[i] = version[i] and version[i] + number / 100000 or number
      i = i + 1
   end

   local v = vstring:match("^%s*(.*)%s*$")
   version.string = v

   local main, revision = v:match("(.*)%-(%d+)$")
   if revision then
      v = main
      version.revision = tonumber(revision)
   end
   while #v > 0 do
      local token, rest = v:match("^(%d+)[%.%-%_]*(.*)")
      if token then
         add_token(tonumber(token))
      else
         token, rest = v:match("^(%a+)[%.%-%_]*(.*)")
         if not token then
            error("version number '" .. v .. "' could not be parsed.")
         end
         version[i] = deltas[token] or (token:byte() / 1000)
      end
      v = rest
   end
   setmetatable(version, version_mt)
   version_cache[vstring] = version
   return version
end

function semver.compare_versions(a, b)
   if a == b then
      return false
   end
   return semver.parse_version(b) < semver.parse_version(a)
end

local function partial_match(input_version, input_requested)
   local version, requested

   if not (type(input_version) == "table") then
      version = semver.parse_version(input_version)
   else
      version = input_version
   end
   if not (type(input_requested) == "table") then
      requested = semver.parse_version(input_requested)
   else
      requested = input_requested
   end
   if not (type(version) == "table") or not (type(requested) == "table") then
      return false
   end

   for i, ri in ipairs(requested) do
      local vi = version[i] or 0
      if ri ~= vi then return false end
   end
   if requested.revision then
      return requested.revision == version.revision
   end
   return true
end

function semver.match_constraints(version, constraints)
   local ok = true
   setmetatable(version, version_mt)
   for _, constr in ipairs(constraints) do
      local constr_version, constr_op = constr.version, constr.op
      local cv
      if type(constr_version) == "string" then
         cv = semver.parse_version(constr_version)
         constr.version = cv
      else
         cv = constr_version
      end
      setmetatable(cv, version_mt)
      if     constr_op == "==" then ok = version == cv
      elseif constr_op == "~=" then ok = version ~= cv
      elseif constr_op == ">"  then ok = cv < version
      elseif constr_op == "<"  then ok = version < cv
      elseif constr_op == ">=" then ok = cv <= version
      elseif constr_op == "<=" then ok = version <= cv
      elseif constr_op == "~>" then ok = partial_match(version, cv)
      end
      if not ok then break end
   end
   return ok
end

local operators = {
   ["=="] = "==",
   ["~="] = "~=",
   [">"]  = ">",
   ["<"]  = "<",
   [">="] = ">=",
   ["<="] = "<=",
   ["~>"] = "~>",
   [""]   = "==",
   ["="]  = "==",
   ["!="] = "~=",
}

local function parse_constraint(input)
   local no_upgrade, op, versionstr, rest =
      input:match("^(@?)([<>=~!]*)%s*([%w%.%_%-]+)[%s,]*(.*)")
   if not op then
      return nil, "could not parse constraint: '" .. input .. "'"
   end
   local _op = operators[op]
   if not _op then
      return nil, "bad constraint operator: '" .. tostring(op) .. "' in '" .. input .. "'"
   end
   local version = semver.parse_version(versionstr)
   if not version then
      return nil, "could not parse version from constraint: '" .. input .. "'"
   end
   return {
      op = _op,
      version = version,
      no_upgrade = no_upgrade == "@" and true or nil,
   }, rest
end

function semver.parse_constraints(input)
   local constraints, oinput = {}, input
   local constraint
   input = input:match("^%s*(.-)%s*$")
   while #input > 0 do
      constraint, input = parse_constraint(input)
      if constraint then
         table.insert(constraints, constraint)
      else
         return nil, "failed to parse constraint '" .. tostring(oinput) .. "': " .. input
      end
   end
   return constraints
end

return semver
