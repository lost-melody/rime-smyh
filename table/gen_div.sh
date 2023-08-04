#!/bin/sh

# 從宇浩倉庫中將全字拆分表中提取到smyh_div中
#
# Usage:
# cat ../yuhao/beta/schema/yuaho_chaifen.dict.yaml | table/gen_div.sh >table/smyh_div.txt

# "\t" -> "{TAB}" => 過濾帶有"CJK-"的行 => 過滤帶有"兼容"的行 =>
# 提取"[拆分,xx,xx,xx]"中的"拆分" => 過濾以"{TAB}"結束的行 =>
# 將"{TAB}"轉回"\t" => 分離拆分以空格分隔 => 去除無用的空格
sed 's/\t/{TAB}/g' | \
    grep '{TAB}' | \
    grep -v 'CJK-' | \
    grep -v '兼容' | \
    sed 's/{TAB}\[\?\([^,]*\),.*/{TAB}\1/g' | \
    grep -v '{TAB}$' | \
    sed 's/{TAB}/\t/g' | \
    sed 's/\({[^{}]*}\|.\)/\1 /g' | \
    sed 's/^\(.*\) \t /\1\t/g' | \
    sed 's/ $//g'
