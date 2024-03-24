local translator = {}

local libload = require("wafel.utils.libload")
local librime = require("wafel.base.librime")
local libtable = require("wafel.utils.libtable")
local reg = require("wafel.core.reg")

---@param env Env
function translator.init(env)
    -- 加載配置, 執行初始設置
    reg.options = libtable.patch_table(reg.options, require("wafel.default.options") or {})
    reg.options = libtable.patch_table(reg.options, libload.load_or_nil("wafel.custom.options") or {})
    require("wafel.defaul.config")
    libload.load_or_nil("wafel.custom.config")

    -- 執行初始化鈎子
    for i, handler in ipairs(reg.inits) do
        local success, err = pcall(handler, env)
        if not success then
            librime.log.warnf("failed to call init[%d]: %s", i, err)
        end
    end
end

---@param env Env
function translator.fini(env)
    -- 執行資源釋放鈎子
    for i, handler in ipairs(reg.finis) do
        local success, err = pcall(handler, env)
        if not success then
            librime.log.warnf("failed to call fini[%d]: %s", i, err)
        end
    end
end

---@param input string
---@param seg Segment
---@param env Env
function translator.func(input, seg, env)
    for i, handler in ipairs(reg.translators) do
        local success, err = pcall(handler, input, seg, env)
        if not success then
            librime.log.warnf("failed to call translator[%d]: %s", i, err)
        end
    end
end

return translator
