#!/bin/sh

cd "$(dirname "$(dirname "$(realpath "$0")")")"
yue -s -j -t lua/ yue/
cd lua/
stylua wafel/
