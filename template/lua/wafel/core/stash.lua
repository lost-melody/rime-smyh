local stash = {}

local bus = require("wafel.core.bus")
local librime = require("wafel.base.librime")

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

return stash
