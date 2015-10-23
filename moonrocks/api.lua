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
      do
        local res = self:raw_method(...)
        if res.errors then
          if res.errors[1] == "Invalid key" then
            res.errors[1] = res.errors[1] .. " (run `moonrocks login` to change)"
          end
          local msg = table.concat(res.errors, ", ")
          error("API Failed: " .. msg)
        end
        return res
      end
    end,
    raw_method = function(self, path, ...)
      self:check_version()
      local url = "https://" .. tostring(self.config.server) .. "/api/" .. tostring(self.config.version) .. "/" .. tostring(self.config.key) .. "/" .. tostring(path)
      return self:request(url, ...)
    end,
    request = (function()
      local http = require("socket.http")
      local ltn12 = require("ltn12")
      local json = require("cjson")
      return function(self, url, params, post_params)
        if post_params == nil then
          post_params = nil
        end
        assert(self.config.key, "Must have API key before performing any actions")
        local body
        local headers = { }
        if params and next(params) then
          url = url .. ("?" .. encode_query_string(params))
        end
        if post_params then
          local boundary
          body, boundary = multipart.encode(post_params)
          headers["Content-length"] = #body
          headers["Content-type"] = "multipart/form-data; boundary=" .. tostring(boundary)
        end
        local method = post_params and "POST" or "GET"
        if self.debug then
          io.stdout:write(colors("%{yellow}[" .. tostring(method) .. "]%{reset} " .. tostring(url) .. " ... "))
        end
        local out = { }
        local _, status = http.request({
          url = url,
          headers = headers,
          method = method,
          sink = ltn12.sink.table(out),
          source = body and ltn12.source.string(body)
        })
        if self.debug then
          print(colors("%{green}" .. tostring(status)))
        end
        assert(status == 200, "API returned " .. tostring(status) .. " - " .. tostring(url))
        return json.decode(concat(out))
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
  local _class_0 = setmetatable({
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
