local filter = {}

---@param env Env
function filter.init(env)
end

---@param input Translation
---@param env Env
function filter.func(input, env)
end

---@param env Env
function filter.fini(env)
end

---@param seg Segment
---@param env Env
function filter.tags_match(seg, env)
end

return filter
