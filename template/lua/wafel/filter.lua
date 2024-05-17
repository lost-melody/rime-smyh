local libiter = require("wafel.utils.libiter")
local librime = require("wafel.base.librime")
local reg = require("wafel.core.reg")

---@param input Translation
---@param env Env
local function filter(input, env)
    ---@param yield fun(cand: Candidate)
    local iterator = libiter.wrap_iterator(input, function(inp, yield)
        for cand in inp:iter() do
            yield(cand)
        end
    end)

    -- lua_filter@wafel.filter
    -- lua_filter@wafel.filter@post
    if env.name_space ~= "post" then
        for i, handler in ipairs(reg.filters) do
            ---@param yield fun(cand: Candidate)
            iterator = libiter.wrap_iterator(iterator, function(iterable, yield)
                local success, err = pcall(handler, iterable, env, yield)
                if not success then
                    librime.log.warnf("failed to call filter[%d]: %s", i, err)
                end
            end)
        end
    else
        for i, handler in ipairs(reg.post_filters) do
            ---@param yield fun(cand: Candidate)
            iterator = libiter.wrap_iterator(iterator, function(iterable, yield)
                local success, err = pcall(handler, iterable, env, yield)
                if not success then
                    librime.log.warnf("failed to call post filter[%d]: %s", i, err)
                end
            end)
        end
    end

    for cand in iterator do
        librime.yield(cand)
    end
end

return filter
