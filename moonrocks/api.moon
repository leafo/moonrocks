
import appfile from require "pl.app"
import makepath from require "pl.dir"
import dirname from require "pl.path"

import concat from table

colors = require "ansicolors"
pretty = require "pl.pretty"
multipart = require "moonrocks.multipart"

local encode_query_string

class Api
  server: "luarocks.org"
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
    print "Navigate to https://#{@config.server}/settings to get a key."
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
      res = @request "https://#{@config.server}/api/tool_version", current: tool_version
      @_server_tool_version = assert res.version, "failed to fetch tool version"

      if res.force_update
        print colors "%{bright red}Error:%{reset} Your moonrocks is too out of date to continue (need #{res.version}, have #{tool_version})"
        os.exit 1

      if res.version != tool_version
        print colors "%{bright yellow}Warning:%{reset} Your moonrocks is out of date (latest #{res.version}, have #{tool_version})"


  method: (...) =>
    res = @raw_method ...

    if res.two_factor_required
      assert @on_tfa_required, "Server requires two-factor verification but no handler is configured"
      @on_tfa_required @
      res = @raw_method ...

      if res.two_factor_required
        error "API Failed: two-factor verification required after successful verification"

    if res.errors
      if res.errors[1] == "Invalid key"
        res.errors[1] ..= " (run `moonrocks login` to change)"

      msg = table.concat res.errors, ", "
      error "API Failed: " .. msg

    res

  raw_method: (path, params, post_params) =>
    @check_version!
    extra_headers = nil
    if @tfa_token
      extra_headers = { "X-TFA-Token": @tfa_token }
    url = "https://#{@config.server}/api/#{@config.version}/#{@config.key}/#{path}"
    @request url, params, post_params, extra_headers

  debug_log: (msg) =>
    return unless @debug
    io.stderr\write colors "%{dim}[debug]%{reset} #{msg}\n"

  redact_url: (url) =>
    url\gsub "(/api/[^/]+/)([^/]+)/", (prefix, key) ->
      visible = key\sub 1, 4
      "#{prefix}#{visible}#{string.rep '*', math.max(0, #key - 4)}/"

  debug_dump_body: (label, body) =>
    return unless @debug
    if not body or body == ""
      @debug_log "#{label}: (empty)"
      return
    @debug_log "#{label} (#{#body} bytes):"
    limit = 4096
    shown = if #body > limit
      body\sub(1, limit) .. "\n... (truncated, #{#body - limit} more bytes)"
    else
      body
    for line in shown\gmatch "[^\n]*"
      io.stderr\write "  #{line}\n"

  request: do
    http = require "socket.http"
    ltn12 = require "ltn12"
    json = require "cjson"

    (url, params, post_params=nil, extra_headers=nil) =>
      assert @config.key, "Must have API key before performing any actions"

      local body
      headers = {}

      if extra_headers
        for k, v in pairs extra_headers
          headers[k] = v

      if params and next(params)
        url ..= "?" .. encode_query_string params

      is_multipart = false
      if post_params
        body, boundary = multipart.encode post_params
        headers["Content-length"] = #body
        headers["Content-type"] = "multipart/form-data; boundary=#{boundary}"
        is_multipart = true

      method = post_params and "POST" or "GET"

      if @debug
        @debug_log colors "%{yellow}--> #{method}%{reset} #{@redact_url url}"
        for k, v in pairs headers
          @debug_log "    #{k}: #{v}"
        if body
          if is_multipart
            @debug_log "    request body: #{#body} bytes (multipart, not shown)"
          else
            @debug_dump_body "    request body", body

      out = {}
      _, status, response_headers, status_line = http.request {
        :url, :headers, :method
        sink: ltn12.sink.table out
        source: body and ltn12.source.string body
      }

      response_body = concat out

      if @debug
        @debug_log colors "%{green}<-- #{status_line or status}%{reset}"
        if response_headers
          for k, v in pairs response_headers
            @debug_log "    #{k}: #{v}"
        @debug_dump_body "    response body", response_body

      ok, decoded = pcall json.decode, response_body
      unless ok and type(decoded) == "table"
        error "API returned #{status} - #{url}"
      unless status == 200 or decoded.errors or decoded.two_factor_required
        error "API returned #{status} - #{url}"
      decoded


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
