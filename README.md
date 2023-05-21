# 宇浩三码顶

> *宇浩三码顶* 是一个 [宇浩输入法](https://zhuyuhao.com/yuhao) (*GitHub*: [forfudan/yuhao](https://github.com/forfudan/yuhao)) 的衍生方案,
    基于宇浩的字根布局和拆分数据, 引入三码顶字的输入方式.
    由于其不改变原宇浩的布局和拆分, 可以实现和宇浩标准版间的无缝切换.

## 一些说明

![宇浩输入法字根图](https://zhuyuhao.com/yuhao/image/宇浩输入法宋体字根图测试版.png)

- 拆字方法:
    - 单根字: 大码+小码+小码互击键`d`或`k`. 即小码在左补`k`, 小码在右补`d`.
        - 女: `女: Cn`, `Cnd`.
        - 一: `一: Fi`, `Fid`.
    - 两根字: 首根大码+次根大小码.
        - 字: `宀子: OoVk`, `OVk`.
        - 配: `酉己: GoBj`, `GBj`.
    - 多根字: 首次末根大码.
        - 的: `白勹丶: EbWyOd`, `EWO`.
        - 是: `日一龰: JrFiNh`, `JFN`.
- 简码:
    - 简码分为一简和二简, 由一码或二码后补分号构成, 分号也可以 `z` 键代替.
    - 由于三码中, 二简码长没有收益, 故二简设置较少, 仅为避重而设.
- 反查:
    - 正常输入时, 按组合键 `Ctrl`+`Shift`+`c` 打开常态拆分提示.
    - 上屏一字后, 按 `z` 键反查该字拆分.
    - 按 `z` 键后输入字或词的全拼, 反查其拆分.
- 智能选重:
    - 为了去重, 引入 [三码郑码](http://zhengma.plus) 的 *智能选重*:
    - 例如 "時間" 一词, 编码为 `jhakjr`, 其中 `jha`/`kjr` 的首选分别是 "峙"/"沓", 为了打出 "時間", 引入该六码词.
- 打断施法:
    - 有时我们可能希望输入双首选字, 却触发了智能选重, 这时就需要打断施法.
    - 可以在打完全码 `jhakjr` 后追加分号或 `z` 来 "打断施法", 上屏首选单字 "峙, 同时保留编码 `kjr` 和候选 "沓".
- 内嵌候選
    - 通过编辑首选的 *preedit* 串, 将候选项展示在嵌入式编码中.
    - 内嵌候选功能默认开启, 可通过 `Ctrl`+`Shift`+`e` 开关.
- 二二得四:
    - 宇浩三码顶只收录 *GBK* 字集, 合计约两万一千字.
    - 如需临时输入 *GBK* 以外的非常用字, 可借助临时官宇模式.
    - 可以先输入字的前两码, 补 `/` 键, 再输入后二码, 从而实现官宇二、三、四码字的输入.
    - 若要连续输入生僻字, 请切换官宇.
- 外挂词库:
    - 通过 `'` 键引导进入成语、诗词输入模式, 可导入其他词库.

> 拼音反查和 "二二得四" 功能需要调用官宇码表,
    可手动导入 `yuhao_pinyin.{dict,schema}.yaml`, `yuhao.{quick,full}.dict.yaml` 或安装官宇 *rime* 包.
    "智能选重" 词条收录自官宇简繁词库.
    "外挂词库" 词条收录自官宇简繁词库.

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
- 宇浩拼音: [yuhao/schema/yuhao_pinyin.dict.yaml](https://github.com/forFudan/yuhao/blob/main/schema/yuhao_pinyin.dict.yaml).
