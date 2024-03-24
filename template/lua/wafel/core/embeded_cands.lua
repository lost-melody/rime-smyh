local embeded_cands = {}

local reg = require("wafel.core.reg")

---@type WafelFilter
local function do_nothing(iter, env, yield)
    for cand in iter() do
        yield(cand)
    end
end

---@type WafelFilter
local function render_embeded(iter, env, yield)
    for cand in iter() do
    end
end

---@type WafelFilter
function embeded_cands.filter(iter, env, yield)
    if not reg.switches[reg.options.embeded_cands.option_name] then
        do_nothing(iter, env, yield)
    else
        render_embeded(iter, env, yield)
    end
end

return embeded_cands
