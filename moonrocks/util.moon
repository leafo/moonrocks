import insert, concat from table

escape_pattern = do
  punct = "[%^$()%.%[%]*+%-?%%]"
  (str) -> (str\gsub punct, (p) -> "%"..p)

split = (str, delim using nil) ->
  str ..= delim
  [part for part in str\gmatch "(.-)" .. escape_pattern delim]

{ :split, :escape_pattern }
