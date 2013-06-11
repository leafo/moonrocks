#!/usr/bin/env moon

import parse_args from require "pl.app"
import run from require "moonrocks.actions"

flags = parse_args!
params = [arg for arg in *{...} when not arg\match "^%-"]

run params, flags

-- vim: set filetype=moon:
