#!/bin/sh

cd "$(dirname $0)"
WD="$(pwd)"
DOC="../docs"
TIME="$(date +%Y%m%d%H%M)"
mkdir -p "${DOC}"/assets

gen_schema() {
    NAME="$1"
    if [ -z "${NAME}" ]; then
        return 1
    fi
    SCHEMA="${DOC}/${NAME}"
    # /tmp/wafel, ../docs/wafel
    mkdir -p /tmp/"${NAME}" "${SCHEMA}/lua/smyh" "${SCHEMA}/opencc"
    # 默認 wafel 數據
    cp ../table/*.txt /tmp/"${NAME}"
    cp ../schema/*.yaml ../schema/*.txt "${SCHEMA}"
    cp ../schema/lua/smyh/*.lua "${SCHEMA}/lua/smyh"
    cp ../schema/opencc/*.json "${SCHEMA}/opencc"
    cp ../template/smyh.*.yaml "${SCHEMA}"
    # 使用 deploy/wafel 覆蓋默認值
    if [ -d "${NAME}" ]; then
        cp -r "${NAME}"/*.txt /tmp/"${NAME}"
    fi
    # 生成簡化字碼表
    ./generator \
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
    ./generator \
        -d /tmp/"${NAME}"/smyh_div.txt \
        -s /tmp/"${NAME}"/smyh_simp_tc.txt \
        -m /tmp/"${NAME}"/smyh_map.txt \
        -f /tmp/"${NAME}"/freq_tc.txt \
        -w /tmp/"${NAME}"/cjkext_whitelist.txt \
        || exit 1
    cp ../template/smyh_tc.*.yaml "${SCHEMA}/"
    cat /tmp/char.txt >>"${SCHEMA}/smyh_tc.base.dict.yaml"
    grep -v '#' /tmp/"${NAME}"/smyh_quick_tc.txt >>"${SCHEMA}/smyh_tc.base.dict.yaml"
    cat /tmp/fullcode.txt >>"${SCHEMA}/smyh_tc.yuhaofull.dict.yaml"
    # 打包
    cd "${DOC}"
    tar -zcf "assets/${NAME}-${TIME}.tar.gz" "${NAME}" || return 1
    cd "assets" && ln -s "${NAME}-${TIME}.tar.gz" "${NAME}-latest.tar.gz"
    cd "${WD}"
    echo "<li><a href=\"./assets/${NAME}-${TIME}.tar.gz\">${NAME}-latest.tar.gz</a></li>" >>"${DOC}"/index.html
    # 清理
    rm /tmp/{char,fullcode,div}.txt
    rm -rf "${SCHEMA}"
    rm -rf /tmp/"${NAME}"
}

echo >"${DOC}"/index.html
echo "<p> 可用的方案列表: </p>" >>"${DOC}"/index.html
echo "<ul>" >>"${DOC}"/index.html

# 打包 Into 方案
gen_schema into || exit 1
# 打包標準 Wafel 方案
gen_schema wafel || exit 1

echo "</ul>" >>"${DOC}/index.html"
