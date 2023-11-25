#!/bin/sh

DUNE_OPTS="--display=quiet --profile=release"
exec dune exec $DUNE_OPTS -- benchs/calc/server.exe $@
