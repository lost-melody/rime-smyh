#!/bin/sh

set -x
cd "$(dirname $0)"

RIME="${HOME}/.config/ibus/rime"
mkdir -p "${RIME}"
mkdir -p "${RIME}/lua/smyh"
mkdir -p "${RIME}/opencc"

cp schema/smyh.*.yaml "${RIME}/"
cp schema/rime.lua "${RIME}/"
cp schema/lua/smyh/core.lua "${RIME}/lua/smyh/"
cp schema/opencc/smyh_*.{json,txt} "${RIME}/opencc/"
