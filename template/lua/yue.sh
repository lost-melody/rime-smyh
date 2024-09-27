#!/bin/sh

cd "$(dirname "$(realpath "$0")")"
yue -s -j ./wafel/
stylua ./wafel/
