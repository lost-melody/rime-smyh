# 雞蛋餅 lua 設計文檔

## 目録結構

- `lua/`
  - `wafel/`
    - `base/`: _librime-lua_ 和 _wafel_ 基礎類型, 函數, 功能封裝
    - `utils/`: 常用的工具函數封裝
    - `core/`: _wafel_ 功能核心實現代碼
    - `default/`: 系統默認配置參數
    - `custom/`: 用户自定義配置參數
    - `proc.lua`: 按鍵處理器
    - `seg.lua`: 分段器
    - `tr.lua`: 翻譯器
    - `filter.lua`: 過濾器

## 入口

- 根據 _librime-lua_ 接口設計, _lua_ 共提供四類入口: _processor_, _segmentor_, _translator_, _filter_.
- 四類入口的定義文件參考 `lua/wafel/{proc,seg,tr,filter}.lua`, 代碼上均採用預注册路由的方式.
- 入口注册在 `lua/wafel/core/reg.lua` 文件中, 原則上應當直接調用相應的 `add_xxx` 函數注册.
- 特别地, 還有兩類特殊入口 `init` 和 `fini` 用於初始化和清理, 實際上會随 _translator_ 一同初始化和清理.

# 定制

- 入口的定義可以在 `lua/wafel/default/config.lua` 和 `lua/wafel/custom/config.lua` 中修改, 原則上應以 `custom` 爲重, `default` 中不建議作修改.
- 除入口定義外, 其他未開放配置的部分也可在 `config` 中進行修改, 盡管目前並不建議如此操作.

# 配置

- 對於一些常用的定制項, 系統將其抽取爲簡單的 `table` 配置集以供簡便修改, 這部分配置在文件 `lua/wafel/default/options.lua` 和 `lua/wafel/custom/options.lua` 中定義.
- 同樣的, 原則上應以修改 `custom` 中的配置項爲重, `default` 中的配置不建議修改.
