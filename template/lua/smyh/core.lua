local core = {}

-- 由translator記録輸入串, 傳遞給filter
core.input_code = ''
-- 由translator計算施法提示, 傳遞給filter
core.pass_comment = ''

-- ######## 工具函数 ########

-- 单字Z键顶, 记录上屏历史
core.commit_history = function(input, seg, env)
    -- if string.match(string.sub(input, 1, 3), "[a-y][z;]z") then
    --     -- 一简补Z
    --     input = string.sub(input, 1, 1)..";"
    -- elseif string.match(string.sub(input, 1, 4), "[a-y][a-y][z;]z") then
    if string.match(string.sub(input, 1, 4), "[a-y][z;][z;]z") then
        -- 一简二简词补Z
        input = string.sub(input, 1, 1)..";;"
    elseif string.match(string.sub(input, 1, 4), "[a-y][a-y][z;]z") then
        -- 二简补Z
        input = string.sub(input, 1, 2)..";"
    elseif string.match(string.sub(input, 1, 4), "[a-y][a-y][a-z]z") then
        -- 全码补Z
        input = string.sub(input, 1, 3)
    else
        -- 不满足条件, 不处理
        return
    end
    -- 上屏, 清理编码, 历史候选
    if env.mem:dict_lookup(input, false, 1) then
        for entry in env.mem:iter_dict() do
            env.engine:commit_text(entry.text)
            env.engine.context:clear()
            env.engine.context:push_input("z")
            yield(Candidate("table", seg.start, seg._end, entry.text, ""))
            yield(Candidate("table", seg.start, seg._end, "", ""))
            -- 返回真
            return true
        end
    end
end

-- 计算分词列表
-- "jnuhsklll;" -> ["jnu","hsk","lll"], ";"
-- "o;gso"     -> ["o;", "gso"]
core.get_code_segs = function(input)
    local code_segs = {}
    while string.len(input) ~= 0 do
        if string.match(string.sub(input, 1, 2), "[a-y];") then
            -- 匹配到一简
            table.insert(code_segs, string.sub(input, 1, 2))
            input = string.sub(input, 3)
        elseif string.match(string.sub(input, 1, 3), "[a-y][a-y][a-z;]") then
            -- 匹配到全码或二简
            table.insert(code_segs, string.sub(input, 1, 3))
            input = string.sub(input, 4)
        elseif input == ";" then
            -- 匹配到冗余分号
            break
        else
            -- 不合法或不完整分词输入串
            return
        end
    end
    return code_segs, input
end

-- 查询编码对应候选列表
-- "hsk" -> ["考", "示"]
core.dict_lookup = function(code, env, comp)
    -- 是否补全编码
    comp = comp or false
    local result = {}
    if env.mem:dict_lookup(code, comp, 2) then
        for entry in env.mem:iter_dict() do
            table.insert(result, entry)
        end
    end
    return result
end

-- 最大匹配查詢分詞候選列表
-- ["jnu", "hsk", "lll"] -> ["显示", "品"]
-- ["jnu", "hsk"]        -> ["显", "考"]
core.query_cand_list = function(code_segs, env)
    if code_segs and #code_segs > 1 then
        local seg_length = #code_segs
        local cand_list = {}
        local code = ''
        while #code_segs ~= 0 do
            -- 最大匹配
            for viewport = #code_segs, 1, -1 do
                if viewport ~= seg_length then
                    code = table.concat(code_segs, '', 1, viewport)
                    local entries = core.dict_lookup(code, env)
                    if entries and #entries ~= 0 then
                        -- 當前viewport有候選, 擇之並進入下一輪
                        table.insert(cand_list, entries[1].text)
                        if viewport ~= #code_segs then
                            for _ = 1, viewport do
                                table.remove(code_segs, 1)
                            end
                        else
                            return cand_list, code
                        end
                        break
                    elseif viewport == 1 then
                        -- 最小viewport无候選, 返回
                        return
                    end
                end
            end
        end
        -- 返回候選字列表及末候選編碼
        return cand_list, code
    end
end

return core
