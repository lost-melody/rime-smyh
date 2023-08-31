local custom = {}

---簡易計算器實現
---qwertyuiop => 1234567890
---hjkl => *-+/
---x => *
---s(square) => ^
---d(dot) => .
---m(mod) => %
---a(remainder) => //
function custom.easy_calc()
    local calc = {
        nums  = { q = '1', w = '2', e = '3', r = '4', t = '5', y = '6', u = '7', i = '8', o = '9', p = '0' },
        signs = { h = '*', j = '-', k = '+', l = '/', s = '^', d = '.', m = '%', x = '*', a = '//' },
    }
    setmetatable(calc.signs, { __index = function(self, key) return key end })

    ---計算表達式結果
    function calc:calc(args, peek_only)
        if #args == 0 then return "" end
        local expr = table.concat(args, "/")
        expr = string.gsub(string.gsub(expr, "[qwertyuiop]", self.nums), "[^0-9%+%-*/^.%%]", self.signs)
        local eval = load("return " .. expr)
        return (peek_only and expr .. "=" or "") .. (eval and eval() or "?")
    end

    ---實時顯示表達式和結果
    function calc:peek(args)
        return self:calc(args, true)
    end

    ---上屏計算結果
    function calc:eval(args)
        return self:calc(args, false)
    end

    return calc
end

---手動造詞
function custom.add_smart()
    local adder = {
        indicators = { "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹" },
    }

    ---計算當前輸入串的造詞結果
    function adder:get_word(args)
        local chars, codes, index = {}, {}, nil

        -- 遍歷當前輸入的單字編碼
        for _, code in ipairs(args) do
            if string.match(code, "^[a-z][1-3][1-9]$") or string.match(code, "^[a-z][a-z][a-z1-3][1-9]$") then
                -- 帶有數字選重的單字編碼
                index = tonumber(string.sub(code, #code)) or 1
                code = string.sub(code, 1, #code - 1)
            elseif string.match(code, "^[a-z][a-z]?$") then
                -- 不帶簡碼鍵的一二簡單字
                index = nil
                code = code .. "1"
            else
                -- 不帶選重的單字全碼
                index = nil
            end

            -- 查詢當前單字
            local entries = WafelCore.dict_lookup(WafelCore.base_mem, code, 1)
            local char = entries[index or 1] and entries[index or 1].text or ""
            if #char ~= 0 then
                -- 录入單字及其編碼
                table.insert(chars, char)
                table.insert(codes, code)
            end
        end

        return chars, codes, index
    end

    ---顯示造詞結果
    function adder:peek(args)
        local chars, codes, index = self:get_word(args)
        if #chars == 0 or index then
            -- 無單字, 或最末單字有選重鍵, 直接返回
            return table.concat(chars)
        else
            -- 顯示最末單字的候選
            local entries = WafelCore.dict_lookup(WafelCore.base_mem, codes[#codes], 9)
            local cands = ""
            for i, entry in ipairs(entries) do
                -- 最多顯示九重
                if i > 9 then break end
                cands = cands .. entry.text .. self.indicators[i]
            end
            return string.format("%s[%s]", table.concat(chars, "", 1, #chars - 1), cands)
        end
    end

    ---將造詞結果添加到詞庫
    function adder:eval(args)
        local chars, codes = self:get_word(args)
        local weight = os.time()
        for i = 1, #chars - 1, 1 do
            local code, word = codes[i], chars[i]
            for j = i + 1, #chars, 1 do
                code = code .. codes[j]
                word = word .. chars[j]
                WafelCore.word_trie:update(code, word, weight)
            end
        end
        return ""
    end

    return adder
end

---手動删詞
function custom.del_smart()
    local deleter = {
        indicators = { "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹" },
    }

    ---查看當前命中的待删智能詞
    function deleter:peek(args)
        if #args ~= 0 then
            -- 首個參數爲編碼, 第二個參數爲選重
            local words = WafelCore.word_trie:query(args[1], nil, 9)
            local index
            if #args > 1 then
                index = args[2] and tonumber(args[2]) or 1
            end

            if index then
                -- 顯示選中的詞
                return words[index] or ""
            else
                -- 顯示符合編碼的候選
                local cands = ""
                for i, word in ipairs(words) do
                    -- 最多顯示九重
                    if i > 9 then break end
                    cands = cands .. word .. self.indicators[i]
                end
                return cands
            end
        end
        return ""
    end

    ---删除選定的智能詞
    function deleter:eval(args)
        if #args ~= 0 then
            local code, index = args[1], args[2] and tonumber(args[2]) or 1
            local words = WafelCore.word_trie:query(code, nil, 9)
            WafelCore.word_trie:delete(code, words[index] or "")
        end
        return ""
    end

    return deleter
end

---導出智能詞庫
function custom.export_smart()
    ---獲取數據庫對象
    local db = WafelCore.word_trie:db()
    if db then
        ---打開備份文件
        local userdir = rime_api.get_user_data_dir()
        local dbname = db:fetch("\x01/db_name")
        local file, err = io.open(string.format("%s/%s.userdb.bak", userdir, dbname), "w")
        if not file then
            return err
        end

        ---迭代數據並寫入到備份文件
        local count = 0
        for key, value in db:query(":"):iter() do
            key = string.sub(key, 2, -1)
            if #key ~= 0 then
                count = count + 1
                file:write(string.format("%s\t%s\n", key, value))
            end
        end

        file:close()
        return string.format("exported %d phrases", count)
    else
        return "cannot open smart db"
    end
end

---導入智能詞庫
function custom.import_smart()
    ---獲取數據庫對象
    local db = WafelCore.word_trie:db()
    if db then
        ---打開備份文件
        local userdir = rime_api.get_user_data_dir()
        local dbname = db:fetch("\x01/db_name")
        local file, err = io.open(string.format("%s/%s.userdb.bak", userdir, dbname), "r")
        if not file then
            return err
        end

        ---從備份文件讀取數據並入庫
        local count = 0
        for line in file:lines() do
            local key = string.match(line, "^(.-)\t")
            if key then
                local value = string.sub(line, #key + 2, -1)
                count = count + 1
                db:update(":" .. key, value)
            end
        end

        file:close()
        return string.format("imported %d phrases", count)
    else
        return "cannot open smart db"
    end
end

---查詢 librime 版本
function custom.librime_version()
    return function(args)
        return string.format("librime: [%s]", rime_api.get_rime_version())
    end
end

---查詢 librime 發行平臺信息
function custom.librime_dist_info()
    return function(args)
        return string.format("distribution: [%s](%s/%s)",
            rime_api.get_distribution_name(),
            rime_api.get_distribution_code_name(),
            rime_api.get_distribution_version())
    end
end

return custom
