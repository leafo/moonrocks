
import Api from require "moonrocks.api"

actions = {
  login: =>
    api = Api @
    api\login!

  install: =>
    print "install..."

  push: (fname) =>
    api = Api @
    print "pushing #{fname}"
}

run = (params, flags) ->
  action_name = assert params[1], "missing command"
  fn = assert actions[action_name], "unknown action `#{action_name}`"
  params = [p for p in *params[2,]]
  fn flags, unpack params

{ :run, :actions }

