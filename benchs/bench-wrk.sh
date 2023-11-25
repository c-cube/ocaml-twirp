#!/bin/sh
set -x
exec wrk -c 100 -d 10s -t 20 --latency http://localhost:8084/twirp/Calculator/add_all -s `dirname $0`/bench-wrk.lua
