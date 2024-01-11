local reg = {}

local librime = require("wafel.base.librime")

---@alias WafelInit fun(env: Env)
---@alias WafelFini fun(env: Env)
---@alias WafelProcessor fun(key_event: KeyEvent, env: Env): ProcessResult
---@alias WafelSegmentor fun(segmentation: Segmentation, env: Env)
---@alias WafelTranslator fun(input: string, seg: Segment, env: Env)
---@alias WafelFilter fun(input: Translation, env: Env)

---配置项
---@type WafelOptions
reg.options = {}

---開關狀態
---@type table<string, boolean>
reg.switches = {}

---@type WafelInit[]
reg.inits = {}
---@type WafelFini[]
reg.finis = {}

---@type WafelProcessor[]
reg.processors = {}
---@type WafelSegmentor[]
reg.segmentors = {}
---@type WafelTranslator[]
reg.translators = {}
---@type WafelFilter[]
reg.filters = {}
---@type WafelFilter[]
reg.post_filters = {}

---@type table<ModifierMask, table<integer, WafelProcessor>>
local keymaps = {}

---@param init WafelInit
function reg.add_init(init)
    table.insert(reg.inits, init)
end

---@param fini WafelFini
function reg.add_fini(fini)
    table.insert(reg.finis, fini)
end

---@param processor WafelProcessor
function reg.add_processor(processor)
    table.insert(reg.processors, processor)
end

---@param segmentor WafelSegmentor
function reg.add_segmentor(segmentor)
    table.insert(reg.segmentors, segmentor)
end

---@param translator WafelTranslator
function reg.add_translator(translator)
    table.insert(reg.translators, translator)
end

---@param filter WafelFilter
function reg.add_filter(filter)
    table.insert(reg.filters, filter)
end

---@param filter WafelFilter
function reg.add_post_filter(filter)
    table.insert(reg.post_filters, 1, filter)
end

---@param modifier ModifierMask
---@param keycode integer
---@param handler WafelProcessor
function reg.set_keymap(modifier, keycode, handler)
    if not keymaps[modifier] then
        keymaps[modifier] = {}
    end
    if not keymaps[modifier][keycode] then
        -- 注册鍵映射
        keymaps[modifier][keycode] = handler
    else
        -- 重復的鍵映射, 警告
        librime.log.warnf("duplicated keymap entries: <%d:%d>", modifier, keycode)
    end
end

---@param modifier ModifierMask
---@param keycode integer
---@return WafelProcessor|nil
function reg.get_keymap(modifier, keycode)
    local keymap = keymaps[modifier]
    if keymap then
        local handler = keymap[keycode]
        if handler then
            return handler
        end
    end
end

return reg
