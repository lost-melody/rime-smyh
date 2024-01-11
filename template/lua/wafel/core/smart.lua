local smart = {}

local librime = require("wafel.base.librime")
local reg = require("wafel.core.reg")

---@type LevelDb|nil
local userdb
---@type boolean
local readonly = true

---@type WafelInit
function smart.init(_)
    userdb = librime.New.LevelDb(reg.options.smart.userdb)
    if userdb then
        -- 詞典爲空時, 嘗試讀取詞庫文件
        local empty = true
        for _ in smart.query(":"):iter() do
            empty = false
            break
        end
        if empty then
            smart.load_dict(reg.options.smart.userdict)
        end
    end
end

---@param dictpath string
function smart.load_dict(dictpath)
    if userdb then
        local file, err = io.open(librime.api.get_user_data_dir() .. "/" .. dictpath, "r")
        if not file then
            librime.log.warnf("failed to open user dict file %s: %s", dictpath, err)
            return
        end

        local weight = os.time()
        for line in file:lines() do
            ---@type string[]
            local chars = {}
            for _, c in utf8.codes(line) do
                local char = utf8.char(c)
                table.insert(chars, char)
            end

            for i = 1, #chars - 1, 1 do
                local word = chars[i]
                for j = i + 1, #chars, 1 do
                    word = word .. chars[j]
                    -- `{ key: ":詞語:", value: "權重" }`
                    smart.update(word, weight)
                end
            end
            weight = weight - 1
        end
        file:close()
    end
end

function smart.clear()
    local count = 0

    if userdb then
        if not userdb:loaded() then
            userdb:open()
        elseif readonly then
            userdb:close()
            userdb:open()
        end
        readonly = false

        for key in userdb:query(":"):iter() do
            userdb:erase(key)
            count = count + 1
        end
    end

    return count
end

---@param word string
---@return integer|nil
function smart.fetch(word)
    if userdb then
        if not userdb:loaded() then
            userdb:open_read_only()
        elseif not readonly then
            userdb:close()
            userdb:open_read_only()
        end
        readonly = true

        local key = string.format(":%s:", word)
        local value = userdb:fetch(key)
        if value then
            return tonumber(value)
        end
    end
end

---@param key string
function smart.query(key)
    if userdb then
        if not userdb:loaded() then
            userdb:open_read_only()
        elseif not readonly then
            userdb:close()
            userdb:open_read_only()
        end
        readonly = true

        return userdb:query(key)
    end
end

---@param word string
function smart.delete(word)
    if userdb then
        if not userdb:loaded() then
            userdb:open()
        elseif readonly then
            userdb:close()
            userdb:open()
        end
        readonly = false

        local key = string.format(":%s:", word)
        return userdb:erase(key)
    end
end

---@param word string
---@param weight? integer
function smart.update(word, weight)
    if userdb then
        if not userdb:loaded() then
            userdb:open()
        elseif readonly then
            userdb:close()
            userdb:open()
        end
        readonly = false

        local key = string.format(":%s:", word)
        local value = tostring(weight or 0)
        return userdb:update(key, value)
    end
end

return smart
