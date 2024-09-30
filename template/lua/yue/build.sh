#!/bin/sh

cd "$(dirname "$(dirname "$(realpath "$0")")")"
yue -s -j -t ./wafel/ ./yue/
stylua ./wafel/
