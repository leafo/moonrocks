
import appfile from require "pl.app"
import makepath from require "pl.dir"
import dirname from require "pl.path"

import concat from table

colors = require "ansicolors"
pretty = require "pl.pretty"
multipart = require "moonrocks.multipart"

local encode_query_string

class Api
  server: "rocks.moonscript.org"
  version: "1"

  new: (flags={}, name="config") =>
    @config_fname = appfile(name) .. ".lua"
    @server = flags.server
    @debug = flags.debug
    @config = setmetatable {}, __index: @
    @read!

    os.exit 1 unless @config.key or @login!

  login: =>
    print colors "%{bright yellow}You need an API key to continue."
    print "Navigate to http://#{@config.server}/settings to get a key."
    while true
      io.stdout\write "Paste API key: "
      key = io.stdin\read "*l"
      break if not key or key == ""
      @config.key = key
      res = @raw_method "status"
      if errors = res.errors
        print colors "%{bright yellow}Server says:%{reset} #{errors[1]}"
      else
        break

    if @config.key
      @write!
      true
    else
      print colors "%{bright red}Aborting"
      false

  check_version: =>
    tool_version = require "moonrocks.version"
    unless @_server_tool_version
      res = @request "http://#{@config.server}/api/tool_version", current: tool_version
      @_server_tool_version = assert res.version, "failed to fetch tool version"

      if res.force_update
        print colors "%{bright red}Error:%{reset} Your moonrocks is too out of date to continue (need #{res.version}, have #{tool_version})"
        os.exit 1

      if res.version != tool_version
        print colors "%{bright yellow}Warning:%{reset} Your moonrocks is out of date (latest #{res.version}, have #{tool_version})"


  method: (...) =>
    with res = @raw_method ...
      if res.errors
        if res.errors[1] == "Invalid key"
          res.errors[1] ..= " (run `moonrocks login` to change)"

        msg = table.concat res.errors, ", "
        error "API Failed: " .. msg

  raw_method: (path, ...) =>
    @check_version!
    url = "http://#{@config.server}/api/#{@config.version}/#{@config.key}/#{path}"
    @request url, ...

  request: do
    http = require "socket.http"
    ltn12 = require "ltn12"
    json = require "cjson"

    (url, params, post_params=nil) =>
      assert @config.key, "Must have API key before performing any actions"

      local body
      headers = {}

      if params and next(params)
        url ..= "?" .. encode_query_string params

      if post_params
        body, boundary = multipart.encode post_params
        headers["Content-length"] = #body
        headers["Content-type"] = "multipart/form-data; boundary=#{boundary}"

      method = post_params and "POST" or "GET"

      if @debug
        io.stdout\write colors "%{yellow}[#{method}]%{reset} #{url} ... "

      out = {}
      _, status = http.request {
        :url, :headers, :method
        sink: ltn12.sink.table out
        source: body and ltn12.source.string body
      }

      if @debug
        print colors "%{green}#{status}"

      assert status == 200, "API returned #{status} - #{url}"
      json.decode concat out


  read: =>
    if f = io.open @config_fname, "r"
      content = f\read "*a"
      f\close!

      config = pretty.read content
      if config
        for k,v in pairs config
          @config[k] = v

  write: =>
    makepath dirname @config_fname
    with io.open @config_fname, "w"
      \write pretty.write @config
      \close!
    true

encode_query_string = do
  url = require "socket.url"
  (t, sep="&") ->
    i = 0
    buf = {}
    for k,v in pairs t
      if type(k) == "number" and type(v) == "table"
        {k,v} = v

      buf[i + 1] = url.escape k
      buf[i + 2] = "="
      buf[i + 3] = url.escape v
      buf[i + 4] = sep
      i += 4

    buf[i] = nil
    concat buf

{ :Api }

