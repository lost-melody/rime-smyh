local mem = {}

local libmem = require("wafel.base.libmem")
local reg = require("wafel.core.reg")

---@type Memory|nil
local main_mem
---@type Memory|nil
local word_mem
---@type Memory|nil
local smart_mem

---空迭代器
local nil_iter = function()
    return nil
end

---@type WafelInit
function mem.init(env)
    main_mem = libmem.get(env, reg.options.dicts.main)
    word_mem = libmem.get(env, reg.options.dicts.word)
    smart_mem = libmem.get(env, reg.options.dicts.smart)
end

---@param input string
---@param predictive? boolean
---@param limit? integer
---@return fun(): DictEntry|nil
function mem.query_main(input, predictive, limit)
    if main_mem and main_mem:dict_lookup(input, predictive or false, limit or 100) then
        return main_mem:iter_dict()
    else
        return nil_iter
    end
end

---@param input string
---@param predictive? boolean
---@param limit? integer
---@return fun(): DictEntry|nil
function mem.query_word(input, predictive, limit)
    if word_mem and word_mem:dict_lookup(input, predictive or false, limit or 100) then
        return word_mem:iter_dict()
    else
        return nil_iter
    end
end

---@param input string
---@param predictive? boolean
---@param limit? integer
---@return fun(): DictEntry|nil
function mem.query_smart(input, predictive, limit)
    if smart_mem and smart_mem:dict_lookup(input, predictive or false, limit or 100) then
        return smart_mem:iter_dict()
    else
        return nil_iter
    end
end

return mem
