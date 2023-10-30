---方案詞典查詢庫
local libmem = {}

local librime = require("librime")

---@type { string: Memory }
local loaded_mem = {}

---獲取詞典接口對象
---@param env Env
---@param schema_id string
---@return Memory|nil
function libmem.get(env, schema_id)
    local mem = loaded_mem[schema_id]
    if not mem then
        ---Schema 對象
        local schema = librime.New.Schema(schema_id)
        ---Memory 對象
        mem = librime.New.Memory(env.engine, schema)
        loaded_mem[schema_id] = mem
        if not mem then
            -- 初始化失敗, 返回空
            return nil
        end
    end
    return mem
end

return libmem;