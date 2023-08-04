#!/bin/sh

# 生成大竹碼表
#
# Usage:
#   cat schema/smyh.base.dict.yaml | assets/gen_dazhu.sh >/tmp/wafel-dazhu.txt

sed 's/\t/{TAB}/g' | \
    grep '.*{TAB}.*{TAB}.*' | \
    sed 's/1/_/g' | \
    sed 's/2/;/g' | \
    sed 's/\(.*\){TAB}\(.*\){TAB}.*/\2\t\1/g'
