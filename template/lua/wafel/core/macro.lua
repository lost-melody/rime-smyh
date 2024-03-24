local macro = {}

local bus = require("wafel.core.bus")
local librime = require("wafel.base.librime")
local reg = require("wafel.core.reg")

local cSpace = 0x20
local cDel = 0x7f

-- 返回被選中的候選的索引, 來自 librime-lua/sample 示例
---@param key_event KeyEvent
---@param env Env
local function select_index(key_event, env)
    local ch = key_event.keycode
    local index = -1
    local select_keys = env.engine.schema.select_keys
    if select_keys ~= nil and select_keys ~= "" and not key_event:ctrl() and ch >= 0x20 and ch < 0x7f then
        local pos = string.find(select_keys, string.char(ch))
        if pos ~= nil then
            index = pos
        end
    elseif ch >= 0x30 and ch <= 0x39 then
        index = (ch - 0x30 + 9) % 10
    elseif ch >= 0xffb0 and ch < 0xffb9 then
        index = (ch - 0xffb0 + 9) % 10
    elseif ch == 0x20 then
        index = 0
    end
    return index
end

---@param input string
---@return string, string[]
local function get_macro_args(input)
    local name = ""
    local args = {}
    for str in string.gmatch(input, "[^/]*") do
        table.insert(args, str)
    end
    if #args ~= 0 then
        name = table.remove(args, 1)
    end
    return name, args
end

---@type WafelProcessor
function macro.processor(key_event, env)
    if string.match(bus.input.code, "^/") then
        local ctx = env.engine.context

        local name, args = get_macro_args(bus.input.code)
        local macros = reg.options.macros[name] or {}

        local hijack = false
        for _, m in ipairs(macros) do
            if m.hijack then
                hijack = true
                break
            end
        end

        if hijack and key_event.keycode > cSpace and key_event.keycode < cDel then
            -- hijack key input and append
            ctx:push_input(string.char(key_event.keycode))
            return librime.process_results.kAccepted
        else
            -- clear active input
            if reg.options.funckeys.clearact[key_event.keycode] then
                ctx:clear()
                return librime.process_results.kAccepted
            end

            -- activate the selected macro
            local index = select_index(key_event, env)
            if index >= 0 then
                local m = macros[index]
                if m then
                    m:trigger(env, ctx, args)
                end
                return librime.process_results.kAccepted
            end
        end
    end

    return librime.process_results.kNoop
end

---@type WafelTranslator
function macro.translator(input, seg, env)
    if string.match(bus.input.code, "^/") then
        local ctx = env.engine.context

        local name, args = get_macro_args(bus.input.code)
        local macros = reg.options.macros[name] or {}
        if #macros == 0 then
            return
        end

        local text_list = {}
        for i, m in ipairs(macros) do
            local text = m:display(env, ctx, args)
            table.insert(text_list, text .. reg.options.embeded_cands.index_indicators[i])
        end

        local cand = librime.New.Candidate("macro", seg.start, seg._end, "", table.concat(text_list, " "))
        librime.yield(cand)
    end
end

return macro
