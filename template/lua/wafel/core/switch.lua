local switch = {}

local reg = require("wafel.core.reg")

---@param ctx Context
---@param name string
local function option_update_handler(ctx, name)
    reg.switches[name] = ctx:get_option(name)
    ctx:refresh_non_confirmed_composition()
end

---@type WafelInit
function switch.init(env)
    local ctx = env.engine.context
    ctx.option_update_notifier:connect(option_update_handler)
end

return switch
