#!/bin/sh

cd "$(dirname $0)"
WD="$(pwd)"
DOC="../docs"
TIME="$(date +%Y%m%d%H%M)"
mkdir -p "${DOC}"/assets

gen_schema() {
    NAME="$1"
    DESC="${2:-${NAME}}"
    if [ -z "${NAME}" ]; then
        return 1
    fi
    SCHEMA="${DOC}/${NAME}"
    # /tmp/wafel, ../docs/wafel
    mkdir -p /tmp/"${NAME}" "${SCHEMA}/lua/smyh" "${SCHEMA}/opencc"
    # 默認 wafel 數據
    cp ../table/*.txt /tmp/"${NAME}"
    cp ../template/*.yaml ../template/*.txt "${SCHEMA}"
    cp ../template/lua/smyh/*.lua "${SCHEMA}/lua/smyh"
    cp ../template/opencc/*.json "${SCHEMA}/opencc"
    sed -i "s/name: 吉旦餅/name: 吉旦餅·${NAME}/g" "${SCHEMA}"/smyh.{custom,schema}.yaml
    sed -i "s/version: beta/version: beta.${TIME}/g" "${SCHEMA}"/*.dict.yaml "${SCHEMA}"/smyh.schema.yaml
    # 使用 deploy/wafel 覆蓋默認值
    if [ -d "${NAME}" ]; then
        cp -r "${NAME}"/*.txt /tmp/"${NAME}"
    fi
    cat /tmp/"${NAME}"/smyh_map.txt | python ../assets/gen_mappings_table.py >"${SCHEMA}"/smyh.mappings_table.txt
    # 生成簡化字碼表
    ./generator -q \
        -d /tmp/"${NAME}"/smyh_div.txt \
        -s /tmp/"${NAME}"/smyh_simp.txt \
        -m /tmp/"${NAME}"/smyh_map.txt \
        -f /tmp/"${NAME}"/freq.txt \
        -w /tmp/"${NAME}"/cjkext_whitelist.txt \
        || exit 1
    cat /tmp/char.txt >>"${SCHEMA}/smyh.base.dict.yaml"
    grep -v '#' /tmp/"${NAME}"/smyh_quick.txt >>"${SCHEMA}/smyh.base.dict.yaml"
    cat /tmp/fullcode.txt >>"${SCHEMA}/smyh.yuhaofull.dict.yaml"
    cat /tmp/div.txt >"${SCHEMA}/opencc/smyh_div.txt"
    # 生成傳統字碼表
    ./generator -q \
        -d /tmp/"${NAME}"/smyh_div.txt \
        -s /tmp/"${NAME}"/smyh_simp_tc.txt \
        -m /tmp/"${NAME}"/smyh_map.txt \
        -f /tmp/"${NAME}"/freq_tc.txt \
        -w /tmp/"${NAME}"/cjkext_whitelist.txt \
        || exit 1
    cat /tmp/char.txt >>"${SCHEMA}/smyh_tc.base.dict.yaml"
    grep -v '#' /tmp/"${NAME}"/smyh_quick_tc.txt >>"${SCHEMA}/smyh_tc.base.dict.yaml"
    cat /tmp/fullcode.txt >>"${SCHEMA}/smyh_tc.yuhaofull.dict.yaml"
    # 打包
    cd "${SCHEMA}"
    zip -rq "../assets/${NAME}-${TIME}.zip" "./" || return 1
    cd "../assets" && ln -fs "${NAME}-${TIME}.zip" "${NAME}-latest.zip"
    cd "${WD}"
    echo "<li> ${DESC} <a href=\"./assets/${NAME}-${TIME}.zip\"> ${NAME}-latest.zip </a></li>" >>"${DOC}"/index.html
    # 清理
    rm /tmp/{char,fullcode,div}.txt
    rm -rf "${SCHEMA}"
    rm -rf /tmp/"${NAME}"
}

echo >"${DOC}"/index.html
echo "<!DOCTYPE html><html>" \
    "<head><meta charset=\"utf-8\" /><title>雞蛋餅·下載</title></head>" \
    "<body><p>可用的方案列表:</p><ul>" \
    >>"${DOC}"/index.html

# 打包 Into 方案
gen_schema into 半音托版 || exit 1
# 打包標準 Wafel 方案
gen_schema wafel 純亂序版 || exit 1
# 打包 Star 方案
# gen_schema star 星陳版 || exit 1

echo "</ul></body></html>" >>"${DOC}/index.html"
