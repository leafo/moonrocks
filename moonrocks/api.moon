
import appfile from require "pl.app"
import makepath from require "pl.dir"
import dirname from require "pl.path"

import concat from table

pretty = require "pl.pretty"
multipart = require "moonrocks.multipart"

local encode_query_string

class Api
  server: "rocks.moonscript.org"
  version: "1"

  new: (flags={}, name="config") =>
    @config_fname = appfile(name) .. ".lua"
    @server = flags.server
    @config = setmetatable {}, __index: @
    @read!

    unless @config.key
      @login!

  login: =>
    print "You need an API key to continue."
    print "Navigate to http://#{@config.server}/settings and create a new key."
    while true
      io.stdout\write "Paste API key: "
      key = io.stdin\read "*l"
      break if key == ""
      @config.key = key
      res = @method "status"
      if errors = res.errors
        print "Server says: #{errors[1]}"
      else
        break

    if @config.key
      @write!
    else
      print "Aborting"

  method: do
    http = require "socket.http"
    ltn12 = require "ltn12"
    json = require "cjson"

    (path, params, post_params=nil) =>
      assert @config.key, "Must have api key before performing any actions"

      local body
      headers = {}

      url = "http://#{@config.server}/api/#{@config.version}/#{@config.key}/#{path}"
      if params and next(params)
        url ..= "?" .. encode_query_string params

      if post_params
        body, boundary = multipart.encode post_params
        headers["Content-length"] = #body
        headers["Content-type"] = "multipart/form-data; boundary=#{boundary}"

      out = {}
      _, status = http.request {
        :url, :headers
        method: post_params and "POST" or "GET"
        sink: ltn12.sink.table out
        source: body and ltn12.source.string body
      }

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

