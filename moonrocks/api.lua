local appfile
appfile = require("pl.app").appfile
local makepath
makepath = require("pl.dir").makepath
local dirname
dirname = require("pl.path").dirname
local concat
concat = table.concat
local colors = require("ansicolors")
local pretty = require("pl.pretty")
local multipart = require("moonrocks.multipart")
local encode_query_string
local Api
do
  local _class_0
  local _base_0 = {
    server = "luarocks.org",
    version = "1",
    login = function(self)
      print(colors("%{bright yellow}You need an API key to continue."))
      print("Navigate to https://" .. tostring(self.config.server) .. "/settings to get a key.")
      while true do
        io.stdout:write("Paste API key: ")
        local key = io.stdin:read("*l")
        if not key or key == "" then
          break
        end
        self.config.key = key
        local res = self:raw_method("status")
        do
          local errors = res.errors
          if errors then
            print(colors("%{bright yellow}Server says:%{reset} " .. tostring(errors[1])))
          else
            break
          end
        end
      end
      if self.config.key then
        self:write()
        return true
      else
        print(colors("%{bright red}Aborting"))
        return false
      end
    end,
    check_version = function(self)
      local tool_version = require("moonrocks.version")
      if not (self._server_tool_version) then
        local res = self:request("https://" .. tostring(self.config.server) .. "/api/tool_version", {
          current = tool_version
        })
        self._server_tool_version = assert(res.version, "failed to fetch tool version")
        if res.force_update then
          print(colors("%{bright red}Error:%{reset} Your moonrocks is too out of date to continue (need " .. tostring(res.version) .. ", have " .. tostring(tool_version) .. ")"))
          os.exit(1)
        end
        if res.version ~= tool_version then
          return print(colors("%{bright yellow}Warning:%{reset} Your moonrocks is out of date (latest " .. tostring(res.version) .. ", have " .. tostring(tool_version) .. ")"))
        end
      end
    end,
    method = function(self, ...)
      local res = self:raw_method(...)
      if res.two_factor_required then
        assert(self.on_tfa_required, "Server requires two-factor verification but no handler is configured")
        self:on_tfa_required(self)
        res = self:raw_method(...)
        if res.two_factor_required then
          error("API Failed: two-factor verification required after successful verification")
        end
      end
      if res.errors then
        if res.errors[1] == "Invalid key" then
          local _update_0 = 1
          res.errors[_update_0] = res.errors[_update_0] .. " (run `moonrocks login` to change)"
        end
        local msg = table.concat(res.errors, ", ")
        error("API Failed: " .. msg)
      end
      return res
    end,
    raw_method = function(self, path, params, post_params)
      self:check_version()
      local extra_headers = nil
      if self.tfa_token then
        extra_headers = {
          ["X-TFA-Token"] = self.tfa_token
        }
      end
      local url = "https://" .. tostring(self.config.server) .. "/api/" .. tostring(self.config.version) .. "/" .. tostring(self.config.key) .. "/" .. tostring(path)
      return self:request(url, params, post_params, extra_headers)
    end,
    debug_log = function(self, msg)
      if not (self.debug) then
        return 
      end
      return io.stderr:write(colors("%{dim}[debug]%{reset} " .. tostring(msg) .. "\n"))
    end,
    redact_url = function(self, url)
      return url:gsub("(/api/[^/]+/)([^/]+)/", function(prefix, key)
        local visible = key:sub(1, 4)
        return tostring(prefix) .. tostring(visible) .. tostring(string.rep('*', math.max(0, #key - 4))) .. "/"
      end)
    end,
    debug_dump_body = function(self, label, body)
      if not (self.debug) then
        return 
      end
      if not body or body == "" then
        self:debug_log(tostring(label) .. ": (empty)")
        return 
      end
      self:debug_log(tostring(label) .. " (" .. tostring(#body) .. " bytes):")
      local limit = 4096
      local shown
      if #body > limit then
        shown = body:sub(1, limit) .. "\n... (truncated, " .. tostring(#body - limit) .. " more bytes)"
      else
        shown = body
      end
      for line in shown:gmatch("[^\n]*") do
        io.stderr:write("  " .. tostring(line) .. "\n")
      end
    end,
    request = (function()
      local http = require("socket.http")
      local ltn12 = require("ltn12")
      local json = require("cjson")
      return function(self, url, params, post_params, extra_headers)
        if post_params == nil then
          post_params = nil
        end
        if extra_headers == nil then
          extra_headers = nil
        end
        assert(self.config.key, "Must have API key before performing any actions")
        local body
        local headers = { }
        if extra_headers then
          for k, v in pairs(extra_headers) do
            headers[k] = v
          end
        end
        if params and next(params) then
          url = url .. ("?" .. encode_query_string(params))
        end
        local is_multipart = false
        if post_params then
          local boundary
          body, boundary = multipart.encode(post_params)
          headers["Content-length"] = #body
          headers["Content-type"] = "multipart/form-data; boundary=" .. tostring(boundary)
          is_multipart = true
        end
        local method = post_params and "POST" or "GET"
        if self.debug then
          self:debug_log(colors("%{yellow}--> " .. tostring(method) .. "%{reset} " .. tostring(self:redact_url(url))))
          for k, v in pairs(headers) do
            self:debug_log("    " .. tostring(k) .. ": " .. tostring(v))
          end
          if body then
            if is_multipart then
              self:debug_log("    request body: " .. tostring(#body) .. " bytes (multipart, not shown)")
            else
              self:debug_dump_body("    request body", body)
            end
          end
        end
        local out = { }
        local _, status, response_headers, status_line = http.request({
          url = url,
          headers = headers,
          method = method,
          sink = ltn12.sink.table(out),
          source = body and ltn12.source.string(body)
        })
        local response_body = concat(out)
        if self.debug then
          self:debug_log(colors("%{green}<-- " .. tostring(status_line or status) .. "%{reset}"))
          if response_headers then
            for k, v in pairs(response_headers) do
              self:debug_log("    " .. tostring(k) .. ": " .. tostring(v))
            end
          end
          self:debug_dump_body("    response body", response_body)
        end
        local ok, decoded = pcall(json.decode, response_body)
        if not (ok and type(decoded) == "table") then
          error("API returned " .. tostring(status) .. " - " .. tostring(url))
        end
        if not (status == 200 or decoded.errors or decoded.two_factor_required) then
          error("API returned " .. tostring(status) .. " - " .. tostring(url))
        end
        return decoded
      end
    end)(),
    read = function(self)
      do
        local f = io.open(self.config_fname, "r")
        if f then
          local content = f:read("*a")
          f:close()
          local config = pretty.read(content)
          if config then
            for k, v in pairs(config) do
              self.config[k] = v
            end
          end
        end
      end
    end,
    write = function(self)
      makepath(dirname(self.config_fname))
      do
        local _with_0 = io.open(self.config_fname, "w")
        _with_0:write(pretty.write(self.config))
        _with_0:close()
      end
      return true
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, flags, name)
      if flags == nil then
        flags = { }
      end
      if name == nil then
        name = "config"
      end
      self.config_fname = appfile(name) .. ".lua"
      self.server = flags.server
      self.debug = flags.debug
      self.config = setmetatable({ }, {
        __index = self
      })
      self:read()
      if not (self.config.key or self:login()) then
        return os.exit(1)
      end
    end,
    __base = _base_0,
    __name = "Api"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Api = _class_0
end
do
  local url = require("socket.url")
  encode_query_string = function(t, sep)
    if sep == nil then
      sep = "&"
    end
    local i = 0
    local buf = { }
    for k, v in pairs(t) do
      if type(k) == "number" and type(v) == "table" then
        k, v = v[1], v[2]
      end
      buf[i + 1] = url.escape(k)
      buf[i + 2] = "="
      buf[i + 3] = url.escape(v)
      buf[i + 4] = sep
      i = i + 4
    end
    buf[i] = nil
    return concat(buf)
  end
end
return {
  Api = Api
}
