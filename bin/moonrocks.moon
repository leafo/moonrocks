#!/usr/bin/env moon

import parse_args from require "pl.app"
import run from require "moonrocks.actions"

original_args = { k,v for k,v in pairs(arg) }

flags = parse_args!
params = [arg for arg in *{...} when not arg\match "^%-"]

flags.original_args = original_args
run params, flags

-- vim: set filetype=moon:
