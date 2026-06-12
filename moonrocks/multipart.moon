import insert, concat from table

class File
  new: (@fname, @_mime) =>
  mime: =>
    unless @_mime
      pcall ->
        mimetypes = require "mimetypes"
        @_mime = mimetypes.guess @fname
      @_mime = "application/octet-stream" unless @_mime
    @_mime

  content: =>
    file = assert io.open @fname, "rb"
    with file\read "*a"
      file\close!

seeded = false
rand_string = (len) ->
  unless seeded
    math.randomseed os.time!
    seeded = true

  chars = for i=1,len
    r = math.random 97, 122
    r -= 32 if math.random! >= 0.5
    r
  string.char unpack chars

-- escape quotes and control characters for use inside a quoted-string
-- header parameter (eg. name="...", filename="...")
escape_quoted = (str) ->
  (str\gsub '[%c"]', (c) -> "%%%02X"\format c\byte!)

-- multipart encodes params
-- returns encoded string,boundary
-- params is an a table of tuple tables:
-- params = {
--   {key1, value2},
--   {key2, value2},
--   key3: value3
-- }
encode = (params) ->
  tuples = [t for t in *params]

  string_keys = [k for k in pairs params when type(k) == "string"]
  table.sort string_keys
  for k in *string_keys
    insert tuples, { k, params[k] }

  chunks = for tuple in *tuples
    k,v = unpack tuple

    k = escape_quoted k
    buffer = { 'Content-Disposition: form-data; name="'.. k .. '"' }

    content = if type(v) == "table" and v.__class == File
      buffer[1] ..= '; filename="' .. escape_quoted(v.fname) .. '"'
      insert buffer, "Content-type: #{v\mime!}"
      v\content!
    else
      v

    insert buffer, ""
    insert buffer, content
    concat buffer, "\r\n"

  local boundary
  while true
    boundary = "Boundary#{rand_string 16}"
    collision = false
    for c in *chunks
      if c\find boundary, 1, true
        collision = true
        break
    break unless collision

  inner = concat { "\r\n", "--", boundary, "\r\n" }

  (concat {
    "--", boundary, "\r\n"
    concat chunks, inner
   "\r\n", "--", boundary, "--", "\r\n"
  }), boundary

if "test" == ...
  http = require "socket.http"
  ltn12 = require "ltn12"
  out = {}

  body, boundary = encode {
    wang: "bang"
    dad: "mad"
    f: File"Makefile"
  }

  http.request {
    url: "http://localhost/dump.php"
    method: "POST"
    sink: ltn12.sink.table out
    source: ltn12.source.string body
    headers: {
      "Content-length": #body
      "Content-type": "multipart/form-data; boundary=#{boundary}"
    }
  }

  print concat out
  -- END TEST

{ :encode, :File }
