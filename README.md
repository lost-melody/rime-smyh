# 宇浩三码顶

> *宇浩三码顶* 是一个 [宇浩输入法](https://github.com/forfudan/yuhao) 的衍生方案,
    基于宇浩的字根布局和拆分数据, 引入三码顶字的输入方式.
    由于其不改变原宇浩的布局和拆分, 可以实现和宇浩标准版间的无缝切换.

## 一些说明

- 拆字方法:
    - 单根字: 大码+小码+小码互击键`d`或`k`. 即小码在左补`k`, 小码在右补`d`.
        - 女: `女: Cv`, `Cvk`.
        - 一: `一: Fi`, `Fid`.
    - 两根字: 首根大码+次根大小码.
        - 字: `宀子: OvVk`, `OVk`.
        - 配: `酉己: GoBj`, `GBj`.
    - 多根字: 首次末根大码.
        - 的: `白勹丶: EbWvOd`, `EWO`.
        - 是: `日一龰: JvFiNh`, `JFN`.
- 简码:
    - 简码分为一简和二简, 由一码或二码后补分号构成, 分号也可以 `z` 键代替.
    - 由于三码中, 二简码长没有收益, 故二简设置较少, 仅为避重而设.
    - 当输入字有简码存在时, 会以 `a_` 或 `ab_` 形式提示一简或二简.
- 反查:
    - 正常输入时, 按组合键 `Ctrl`+`Shift`+`c` 打开常态拆分提示.
    - 上屏一字后, 按 `z` 键反查该字拆分.
    - 按 `z` 键后输入字或词的全拼, 反查其拆分.
- 为了去重, 引入 [三码郑码](http://zhengma.plus) 的 *智能选重*:
    - 例如 "時間" 一词, 编码为 `jhakjv`, 其中 `jha`/`kjv` 的首选分别是 "峙"/"沓", 为了打出 "時間", 引入该六码词.
    - 如果希望输入双首选字却触发了智能选重, 可在打完全码 `jhakjv` 后追加分号或 `z` 来 "打断施法", 上屏首选单字 "峙", 而保留编码 `kjv` 和候选 "沓".

## 自定义构建

- 需要 *Go* 语言开发环境.
- 只经过 *Linux* 环境测试, 不保证其他平台可用性.
- 可在 `table/smyh_simp.txt` 中预先定制一简和二简.
- 执行 `generate.sh` 开始生成码表, 输出方案文件到 `schema/` 目录.
- 执行 `replaceibus.sh` 将已生成的方案文件替换到 `~/.config/ibus/rime/` 目录.
- 执行 `packagezip.sh` 将已生成的方案文件打包到 `/tmp/smyh-xxx.zip` 中.

## 数据源声明

- 字频数据: [25亿字语料汉字字频表](https://faculty.blcu.edu.cn/xinghb/zh_CN/article/167473/content/1437.htm).
- 字根及拆分数据: [yuhao/schema/yuhao_chaifen.dict.yaml](https://github.com/forFudan/yuhao/blob/main/schema/yuhao_chaifen.dict.yaml).
- 袖珍简化字拼音: [rime-pinyin-simp](https://github.com/rime/rime-pinyin-simp).
