#!/usr/bin/env moon

argparse = require "argparse"
import Api from require "moonrocks.api"
version = require "moonrocks.version"
colors = require "ansicolors"

import upload, login from require "moonrocks.actions"
import outdated from require "moonrocks.outdated"

parser = argparse "moonrocks", "MoonRocks #{version} (using #{Api.server})"
parser\require_command false
parser\command_target "action"

parser\flag "--trace", "Show full traceback on errors"
parser\option "--server", "Custom server URL"
parser\flag "--debug", "Enable debug output"

with parser\command "upload", "Pack and upload rockspec/rock to server"
  \argument "file", "Rockspec or rock file to upload"
  \flag "--skip-pack", "Skip packing source rock"
  \flag "--upload-rock", "Force uploading rock for development versions"
  \option "--code", "Two-factor code (or set $MOONROCKS_TFA_CODE)"

parser\command "login", "Set or change API key"

with parser\command "outdated", "Show outdated locked dependencies"
  \argument("rockspec", "Path to rockspec (auto-detected if omitted)")\args "?"
  \option "--lock", "Path to luarocks.lock (default: ./luarocks.lock)"
  \flag "--all", "Show all dependencies, not just outdated ones"
  \flag "--installed", "Show currently installed versions from luarocks"

args = parser\parse!

run_action = ->
  switch args.action
    when "upload"
      upload args
    when "login"
      login args
    when "outdated"
      outdated args
    else
      print parser\get_help!

xpcall run_action, (err) ->
  err = err\match("^.-:.-:.(.*)$") or err unless args.trace
  msg = colors "%{bright red}Error:%{reset} #{err}"
  if args.trace
    print debug.traceback msg, 2
  else
    print msg
    print " * Run with --trace to see traceback"
    print " * Report issues to https://github.com/leafo/moonrocks/issues"
  os.exit 1

-- vim: set filetype=moon:
