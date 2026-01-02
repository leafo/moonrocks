local insert, concat
do
  local _obj_0 = table
  insert, concat = _obj_0.insert, _obj_0.concat
end
local escape_pattern
do
  local punct = "[%^$()%.%[%]*+%-?%%]"
  escape_pattern = function(str)
    return (str:gsub(punct, function(p)
      return "%" .. p
    end))
  end
end
local split
split = function(str, delim)
  str = str .. delim
  local _accum_0 = { }
  local _len_0 = 1
  for part in str:gmatch("(.-)" .. escape_pattern(delim)) do
    _accum_0[_len_0] = part
    _len_0 = _len_0 + 1
  end
  return _accum_0
end
return {
  split = split,
  escape_pattern = escape_pattern
}
