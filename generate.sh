#!/bin/sh

set -x
cd "$(dirname $0)"
WD="$(pwd)"

# 创建目录
SCHEMA="schema"
mkdir -p "${SCHEMA}"
mkdir -p "${SCHEMA}/lua/smyh"
mkdir -p "${SCHEMA}/opencc"

# 拷贝模板文件
cp template/smyh.*.yaml "${SCHEMA}/"
cp template/lua/smyh/*.lua "${SCHEMA}/lua/smyh/"
cp template/opencc/smyh_*.{json,txt} "${SCHEMA}/opencc/"

cd generator
# 运行码表生成器
go run . || exit 1
cd "${WD}"

# 单字码表
grep -v '#' table/smyh_quick.txt >>"${SCHEMA}/smyh.base.dict.yaml"
cat /tmp/char.txt >>"${SCHEMA}/smyh.base.dict.yaml"
# 引號詩詞成語碼表
grep -v '#' table/quote.txt >>"${SCHEMA}/smyh.phrase.dict.yaml"
# 智能词码表
cat /tmp/phrase.txt >>"${SCHEMA}/smyh.smart.dict.yaml"
# 拆分提示
cat /tmp/div.txt >>"${SCHEMA}/opencc/smyh_div.txt"

# 清理生成文件
rm /tmp/{char,div,phrase}.txt
