---@class WafelOptions
---@field embeded_cands? WafelEmbededCandsOptions
---@field macros? WafelMacrosOptions
---@field funckeys? WafelFunckeysOptions
local options = {
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
    ---@class WafelMacrosOptions
    macros = {},
    ---@class WafelFunckeysOptions
    funckeys = {},
}

return options
