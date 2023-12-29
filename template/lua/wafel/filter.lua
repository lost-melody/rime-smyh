local librime = require("wafel.base.librime")
local reg = require("wafel.core.reg")

---@param input Translation
---@param env Env
local function filter(input, env)
    for _, handler in ipairs(reg.filters) do
        local success, err = pcall(handler, input, env)
        if not success then
            librime.log.warnf("failed to call filter: %s", err)
        end
    end
end

return filter
