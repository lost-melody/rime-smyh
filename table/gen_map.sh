#!/bin/sh

# 從宇浩倉庫中將碼位映射表中提取到smyh_map中
#
# Usage:
#   cat ../yuhao/wafel/chaifen/三碼宇浩字根碼位映射表.csv | table/gen_map.sh >table/smyh_map.txt

# 忽略首行 => "{左上},𠂇,So" -> "So\t{左上}" => 排序并去重
tail -n +2 | sed 's/\(.*\),.*,\(.*\)/\2\t\1/g' | sort --unique
