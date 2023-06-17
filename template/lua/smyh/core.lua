local core = {}

-- 由translator記録輸入串, 傳遞給filter
core.input_code = ''
-- 由translator計算暫存串, 傳遞給filter
core.stashed_text = ''
-- 由translator初始化基础碼表數據
core.base_mem = nil

-- ######## 工具函数 ########

-- 是否單個宇三全碼編碼段, 如: "abc", "a;", "a;;", "ab;"
function core.single_smyh_seg(input)
    return string.match(input, "^[a-y][z;]$")       -- 一簡
        or string.match(input, "^[a-y][z;][z;]$")   -- 一簡詞
        or string.match(input, "^[a-y][a-y][z;]$")  -- 二簡詞
        or string.match(input, "^[a-y][a-y][a-y]$") -- 單字全碼
end

-- 是否合法宇三分詞串
function core.valid_smyh_input(input)
    -- 輸入串完全由 [a-z;] 構成, 且不以 [z;] 開頭
    return string.match(input, "^[a-z;]*$") and not string.match(input, "^[z;]")
end

-- 计算分词列表
-- "dkdqgxfvt;" -> ["dkd","qgx","fvt"], ";"
-- "d;nua"     -> ["d;", "nua"]
core.get_code_segs = function(input)
    local code_segs = {}
    while string.len(input) ~= 0 do
        if string.match(string.sub(input, 1, 2), "[a-y][z;]") then
            -- 匹配到一简
            table.insert(code_segs, string.sub(input, 1, 2))
            input = string.sub(input, 3)
        elseif string.match(string.sub(input, 1, 3), "[a-y][a-y][a-z;]") then
            -- 匹配到全码或二简
            table.insert(code_segs, string.sub(input, 1, 3))
            input = string.sub(input, 4)
        -- elseif input == ";" then
        --     -- 匹配到冗余分号
        --     break
        else
            -- 不完整或不合法分词输入串
            return code_segs, input
        end
    end
    return code_segs, input
end

-- 查询编码对应候选列表
-- "dkd" -> ["南", "電"]
core.dict_lookup = function(mem, code, count, comp)
    -- 是否补全编码
    count = count or 1
    comp = comp or false
    local result = {}
    code = string.gsub(code, "z", ";")
    if mem:dict_lookup(code, comp, count) then
        for entry in mem:iter_dict() do
            table.insert(result, entry)
        end
    end
    return result
end

-- 最大匹配查詢分詞候選列表
-- ["dkd", "qgx", "fvt"] -> ["電動", "杨"]
-- ["dkd", "qgx"]        -> ["南", "動"]
core.query_cand_list = function(mem, code_segs, skipfull)
    local index = 1
    local cand_list = {}
    local code = table.concat(code_segs, "", index)
    while index <= #code_segs do
        -- 最大匹配
        for viewport = #code_segs, index, -1 do
            if not skipfull or viewport-index+1 < #code_segs then
                code = table.concat(code_segs, "", index, viewport)
                local entries = core.dict_lookup(mem, code)
                if entries[1] then
                    -- 當前viewport有候選, 擇之並進入下一輪
                    table.insert(cand_list, entries[1].text)
                    index = viewport + 1
                    break
                elseif viewport == index then
                    -- 最小viewport無候選, 以空串作爲候選
                    table.insert(cand_list, "")
                    index = viewport + 1
                    break
                end
            end
        end
    end
    -- 返回候選字列表及末候選編碼
    return cand_list, code
end

return core
