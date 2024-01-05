local libmacro = require("wafel.base.libmacro")

---@class WafelOptions
---@field dicts? WafelDictsOptions
---@field embeded_cands? WafelEmbededCandsOptions
---@field macros? WafelMacrosOptions
---@field funckeys? WafelFunckeysOptions
local options = {
    ---@class WafelDictsOptions
    ---@field base? string 主詞典的 `schema_id`
    ---@field full? string 四碼全碼詞典的 `schema_id`
    dicts = {
        base = "wafel.base",
        full = "wafel.full",
    },
    ---@class WafelEmbededCandsOptions
    ---@field index_indicators? string[]
    ---@field first_format? string
    ---@field next_format? string
    ---@field separator? string
    ---@field stash_placeholder? string
    embeded_cands = {
        index_indicators = { "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹", "⁰" },
        first_format = "${Stash}[${候選}${Seq}]${Code}${Comment}",
        next_format = "${Stash}${候選}${Seq}${Comment}",
        separator = " ",
        stash_placeholder = "~",
    },
    ---@alias WafelMacrosOptions table<string, Macro[]>
    macros = {
        help = {
            libmacro.new_tip("配置中心", ""),
            libmacro.new_switch("single_char", { "□智能", "■純單" }),
            libmacro.new_radio({
                { name = "full.word", display = "■■字詞" },
                { name = "full.char", display = "□■全單" },
                { name = "full.off", display = "□□三碼" },
            }),
            libmacro.new_switch("embeded_cands", { "□嵌入", "■嵌入" }),
            libmacro.new_switch("completion", { "□簡潔", "■補全" }),
            libmacro.new_radio({
                { name = "division.off", display = "□□□□註解" },
                { name = "division.lv1", display = "■□□□註解一" },
                { name = "division.lv2", display = "□■□□註解二" },
                { name = "division.lv3", display = "□□■□註解三" },
                { name = "division.lv4", display = "□□□■註解四" },
            }),
        },
        date = {
            libmacro.new_func("日期", function()
                ---@type string
                return os.date("%Y-%m-%d")
            end),
            libmacro.new_func("年月日", function()
                ---@type string
                return os.date("%Y年%m月%d日")
            end),
        },
        time = {
            libmacro.new_func("時間", function()
                ---@type string
                return os.date("%H-%M-%S")
            end),
            libmacro.new_func("時間", function()
                ---@type string
                return os.date("%Y%m%d%H%M")
            end),
            libmacro.new_func("時間戳", function()
                ---@type string
                return tostring(os.time())
            end),
        },
        div = {
            libmacro.new_radio({
                { name = "division.off", display = "□□□□無註解" },
                { name = "division.lv1", display = "■□□□拆分註解" },
                { name = "division.lv2", display = "□■□□編碼註解" },
                { name = "division.lv3", display = "□□■□拼音註解" },
                { name = "division.lv4", display = "□□□■字集註解" },
            }),
        },
        embeded = {
            libmacro.new_switch("embeded_cands", { "□嵌入編碼", "■嵌入候選" }),
        },
        full = {
            libmacro.new_radio({
                { name = "full.word", display = "■■四碼字詞: 顯示所有候選" },
                { name = "full.char", display = "□■四碼全單: 隱藏四碼詞語" },
                { name = "full.off", display = "□□僅三碼: 隱藏四碼候選" },
            }),
        },
        smart = {
            libmacro.new_switch("single_char", { "□智能組詞", "■純單模式" }),
        },
        comp = {
            libmacro.new_switch(
                "completion",
                { "□簡潔模式: 不顯示編碼預測結果", "■自動補全: 顯示編碼預測結果" }
            ),
        },
        charset = {
            libmacro.new_radio({
                { name = "charset.all", display = "■□全字集: 無過濾" },
                { name = "charset.freqly", display = "□■常用字集: 過濾非常用字" },
            }),
        },
    },
    ---@class WafelFunckeysOptions
    funckeys = {},
}

return options
