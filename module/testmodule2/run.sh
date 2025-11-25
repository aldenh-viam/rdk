#!/usr/bin/env sh
cd `dirname $0`

go build ./
exec ./testmodule $@
