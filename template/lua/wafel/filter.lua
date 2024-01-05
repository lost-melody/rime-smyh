local librime = require("wafel.base.librime")
local reg = require("wafel.core.reg")

---@param input Translation
---@param env Env
local function filter(input, env)
    -- lua_filter@wafel.filter
    -- lua_filter@wafel.filter@post
    if env.name_space ~= "post" then
        for i, handler in ipairs(reg.filters) do
            local success, err = pcall(handler, input, env)
            if not success then
                librime.log.warnf("failed to call filter[%d]: %s", i, err)
            end
        end
    else
        for i, handler in ipairs(reg.post_filters) do
            local success, err = pcall(handler, input, env)
            if not success then
                librime.log.warnf("failed to call post filter[%d]: %s", i, err)
            end
        end
    end
end

return filter
