#!/usr/bin/env lua
local parse_args
parse_args = require("pl.app").parse_args
local run
run = require("moonrocks.actions").run
local original_args
do
  local _tbl_0 = { }
  for k, v in pairs(arg) do
    _tbl_0[k] = v
  end
  original_args = _tbl_0
end
local flags = parse_args()
local params
do
  local _accum_0 = { }
  local _len_0 = 1
  local _list_0 = {
    ...
  }
  for _index_0 = 1, #_list_0 do
    local arg = _list_0[_index_0]
    if not arg:match("^%-") then
      _accum_0[_len_0] = arg
      _len_0 = _len_0 + 1
    end
  end
  params = _accum_0
end
flags.original_args = original_args
return run(params, flags)
-- vim: set filetype=lua:
