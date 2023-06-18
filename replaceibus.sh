#!/bin/sh

set -x
cd "$(dirname $0)"

RIME="${HOME}/.config/ibus/rime"
mkdir -p "${RIME}"
mkdir -p "${RIME}/lua/smyh"
mkdir -p "${RIME}/opencc"

cp schema/smyh.*.yaml "${RIME}/"
cp schema/lua/smyh/*.lua "${RIME}/lua/smyh/"
cp schema/opencc/smyh_*.{json,txt} "${RIME}/opencc/"
