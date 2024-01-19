local macro = {}

local bus = require("wafel.core.bus")
local librime = require("wafel.base.librime")

---@type WafelProcessor
function macro.processor(key_event, env)
    return librime.process_results.kNoop
end

---@type WafelTranslator
function macro.translator(input, seg, env)
    if string.match(bus.input.code, "^/") then
    end
end

return macro
