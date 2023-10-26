---wafel namespace配置信息核心庫
local libns = {}

local ctypes = require("librime").config_types

---默認配置原型定義
local empty_config = {}

---從配置原型派生出新配置對象
function empty_config:derive()
    return {
        clone = self.derive,
    }
end

---按namespace組織的配置集合
libns.namespaces = {
    _by_ns = {},
}

---從配置集合中獲取當前namespace下的配置
function libns.namespaces:by_env(env)
    local ns = env.name_space
    local config = self._by_ns[ns]
    if not config then
        -- 若集合中尚無當前ns配置, 則先初始化之
        config = empty_config:derive()
        self._by_ns[ns] = config
    end
    return config
end

---遍歷一個ConfigMap的所有鍵值
---@param config_map ConfigMap|nil
---@param handler fun(key: string, item: ConfigItem)
function libns.for_map(config_map, handler)
    if config_map and config_map.type == ctypes.kMap then
        for _, key in ipairs(config_map:keys()) do
            local item = config_map:get(key)
            if item then
                handler(key, item)
            end
        end
    end
end

---遍歷一個ConfigList的所有項目
---@param config_list ConfigList|nil
---@param handler fun(i: integer, item: ConfigItem)
function libns.for_list(config_list, handler)
    if config_list and config_list.type == ctypes.kList then
        for i = 0, config_list.size - 1 do
            local item = config_list:get_at(i)
            if item then
                handler(i, item)
            end
        end
    end
end

return libns
