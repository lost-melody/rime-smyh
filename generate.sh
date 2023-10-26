#!/bin/sh

set -x
cd "$(dirname $0)"
WD="$(pwd)"

# 创建目录
SCHEMA="schema"
mkdir -p "${SCHEMA}"
mkdir -p "${SCHEMA}/lua/smyh"
mkdir -p "${SCHEMA}/opencc"

# 簡體碼表
cd generator
# 运行码表生成器
go run . || exit 1
cd "${WD}"
# 拷贝模板文件
cp template/*.yaml template/*.txt "${SCHEMA}/"
cp template/lua/smyh/*.lua "${SCHEMA}/lua/smyh/"
cp template/opencc/*.json "${SCHEMA}/opencc/"
# 单字码表
cat /tmp/char.txt >>"${SCHEMA}/smyh.base.dict.yaml"
grep -v '#' table/smyh_quick.txt >>"${SCHEMA}/smyh.base.dict.yaml"
# 单字四码码表
cat /tmp/fullcode.txt >>"${SCHEMA}/smyh.yuhaofull.dict.yaml"
# 拆分提示
cat /tmp/div.txt >"${SCHEMA}/opencc/smyh_div.txt"
# 生成字根表
# cat table/smyh_map.txt | python assets/gen_mappings_table.py >assets/mappings_table.txt

# 繁體碼表
cd generator
go run . \
    -f "../table/freq_tc.txt" \
    -s "../table/smyh_simp_tc.txt" \
    || exit 1
cd "${WD}"
cat /tmp/char.txt >>"${SCHEMA}/smyh_tc.base.dict.yaml"
grep -v '#' table/smyh_quick_tc.txt >>"${SCHEMA}/smyh_tc.base.dict.yaml"
cat /tmp/fullcode.txt >>"${SCHEMA}/smyh_tc.yuhaofull.dict.yaml"

# 清理生成文件
rm /tmp/{char,fullcode,div}.txt
