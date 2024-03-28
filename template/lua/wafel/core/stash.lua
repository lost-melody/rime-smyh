local stash = {}

local bus = require("wafel.core.bus")
local librime = require("wafel.base.librime")
local reg = require("wafel.core.reg")

local cBackspace = 0xff08

---@param input string
---@return boolean
local function is_valid_input(input)
    return string.match(input, "^[a-z ]+$") and not string.match(input, "^[ z]")
end

---@param input string
local function replace_funckeys(input)
    return string.gsub(input, " ([a-c])", {
        a = "1",
        b = "2",
        c = "3",
    })
end

---@param input string
local function restore_funckeys(input)
    return string.gsub(input, "([1-3])", {
        ["1"] = "a",
        ["2"] = "b",
        ["3"] = "c",
    })
end

---@param input string
---@return string[] code_segs, string remaining
local function get_code_segs(input)
    local code_segs = {}
    while #input ~= 0 do
        if string.match(input, "^[a-y][z1-3]") then
            -- 一簡, 以z結束的單根字
            table.insert(code_segs, string.sub(input, 1, 2))
            input = string.sub(input, 3)
        elseif string.match(input, "^[a-y][a-y][a-z1-3]") then
            -- 二簡, 全碼
            table.insert(code_segs, string.sub(input, 1, 3))
            input = string.sub(input, 4)
        else
            -- 不正確的編碼
            break
        end
    end
    return code_segs, input
end

---@type WafelProcessor
function stash.preprocess(_, env)
    bus.input.init_code = env.engine.context.input

    if is_valid_input(bus.input.init_code) then
        bus.input.code = replace_funckeys(bus.input.init_code)
        bus.stash.code_segs, bus.active.code = get_code_segs(bus.input.code)
        if #bus.active.code == 0 and #bus.stash.code_segs ~= 0 then
            ---@type string
            bus.active.code = table.remove(bus.stash.code_segs)
        end
    end

    return librime.process_results.kNoop
end

---@type WafelProcessor
function stash.backspace(key_event, env)
    if key_event.keycode == cBackspace then
        if string.match(bus.input.init_code, " [a-c]$") then
            env.engine.context:pop_input(1)
        end
    end

    return librime.process_results.kNoop
end

---@type table<integer, boolean>, table<integer, boolean>, table<integer, boolean>
local primary, secondary, tertiary
---@type table<integer, boolean>
local clearact

---@param list integer[]|nil
---@return table<integer, boolean>
local function list_to_set(list)
    local set = {}
    for _, value in ipairs(list or {}) do
        set[value] = true
    end
    return set
end

---@type WafelProcessor
function stash.selectionkeys(key_event, env)
    local ctx = env.engine.context

    local keycode = key_event.keycode
    local funckeys = reg.options.funckeys or {}

    primary = primary or list_to_set(funckeys.primary)
    secondary = secondary or list_to_set(funckeys.secondary)
    tertiary = tertiary or list_to_set(funckeys.tertiary)

    if primary[keycode] or secondary[keycode] or tertiary[keycode] then
        if string.match(bus.active.code, "^[a-y][a-z]?$") then
            if primary[keycode] then
                ctx:push_input(" a")
            elseif secondary[keycode] then
                ctx:push_input(" b")
            elseif tertiary[keycode] then
                ctx:push_input(" c")
            end
            return librime.process_results.kAccepted
        end
    end

    return librime.process_results.kNoop
end

---@type WafelProcessor
function stash.clearact(key_event, env)
    local ctx = env.engine.context

    local keycode = key_event.keycode
    local funckeys = reg.options.funckeys or {}
    clearact = clearact or list_to_set(funckeys.clearact)

    if clearact[keycode] and bus.active.code ~= "" then
        bus.active.code = table.remove(bus.stash.code_segs)
        ctx:pop_input(#restore_funckeys(bus.active.code))
        return librime.process_results.kAccepted
    end

    return librime.process_results.kNoop
end

return stash
