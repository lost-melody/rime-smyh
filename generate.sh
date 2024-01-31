#!/bin/bash

# set -x
cd "$(dirname $0)"
WD="$(pwd)"
TIME="$(date +%Y%m%d%H%M)"
NAME="${1:-into}"

mkdir -p /tmp/"${NAME}"
cp table/*.txt /tmp/"${NAME}"
if [ -d deploy/"${NAME}" ]; then
    cp -r deploy/"${NAME}"/*.txt /tmp/"${NAME}"
fi

# 创建目录
SCHEMA="schema"
mkdir -p "${SCHEMA}"
mkdir -p "${SCHEMA}/lua/smyh"
mkdir -p "${SCHEMA}/opencc"

# 簡體碼表
cd generator
# 运行码表生成器
go run . \
    -d /tmp/"${NAME}"/smyh_div.txt \
    -s /tmp/"${NAME}"/smyh_simp.txt \
    -m /tmp/"${NAME}"/smyh_map.txt \
    -f /tmp/"${NAME}"/freq.txt \
    -w /tmp/"${NAME}"/cjkext_whitelist.txt \
    || exit 1
cd "${WD}"
# 拷贝模板文件
cp template/default.*.yaml template/smyh.*.yaml template/smyh.*.txt "${SCHEMA}/"
cp template/lua/smyh/*.lua "${SCHEMA}/lua/smyh/"
cp template/opencc/*.json template/opencc/*.txt "${SCHEMA}/opencc/"
sed -i "s/name: 吉旦餅/name: 吉旦餅·${NAME}/g" "${SCHEMA}"/smyh.{custom,schema}.yaml
sed -i "s/version: beta/version: beta.${TIME}/g" "${SCHEMA}"/*.dict.yaml "${SCHEMA}"/smyh.schema.yaml
# 单字码表
cat /tmp/char.txt >>"${SCHEMA}/smyh.base.dict.yaml"
grep -v '#' /tmp/"${NAME}"/smyh_quick.txt >>"${SCHEMA}/smyh.base.dict.yaml"
# 单字四码码表
cat /tmp/fullcode.txt >>"${SCHEMA}/smyh.full.dict.yaml"
# 拆分提示
cat /tmp/div.txt >"${SCHEMA}/opencc/smyh_div.txt"
# 生成字根表
cat /tmp/"${NAME}"/smyh_map.txt | python assets/gen_mappings_table.py >"${SCHEMA}"/smyh.mappings_table.txt

rm -r /tmp/"${NAME}"
# 清理生成文件
rm /tmp/{char,fullcode,div}.txt
