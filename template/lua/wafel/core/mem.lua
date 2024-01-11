local mem = {}

local libmem = require("wafel.base.libmem")
local reg = require("wafel.core.reg")

---@type Memory|nil
local base_mem
---@type Memory|nil
local full_mem

---空迭代器
local nil_iter = function()
    return nil
end

---@type WafelInit
function mem.init(env)
    base_mem = libmem.get(env, reg.options.dicts.base)
    full_mem = libmem.get(env, reg.options.dicts.full)
end

---@param input string
---@param predictive? boolean
---@param limit? integer
---@return fun(): DictEntry|nil
function mem.query_base(input, predictive, limit)
    if base_mem and base_mem:dict_lookup(input, predictive or false, limit or 100) then
        return base_mem:iter_dict()
    else
        return nil_iter
    end
end

---@param input string
---@param predictive? boolean
---@param limit? integer
---@return fun(): DictEntry|nil
function mem.query_full(input, predictive, limit)
    if full_mem and full_mem:dict_lookup(input, predictive or false, limit or 100) then
        return full_mem:iter_dict()
    else
        return nil_iter
    end
end

return mem
