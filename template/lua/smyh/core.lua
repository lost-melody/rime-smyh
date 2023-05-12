local M = {}
M.filter = {}
M.translator = {}

local pass_comment = ''

-- ######## 工具函数 ########

-- 单字Z键顶, 记录上屏历史
local function commit_history(input, seg, env)
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
local function get_code_segs(input)
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
local function dict_lookup(code, env, comp)
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
local function query_cand_list(code_segs, env)
    if code_segs and #code_segs > 1 then
        local seg_length = #code_segs
        local cand_list = {}
        local code = ''
        while #code_segs ~= 0 do
            -- 最大匹配
            for viewport = #code_segs, 1, -1 do
                if viewport ~= seg_length then
                    code = table.concat(code_segs, '', 1, viewport)
                    local entries = dict_lookup(code, env)
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

-- ######## 过滤器 ########

function M.filter.init(env)
end

-- 过滤器
function M.filter.func(input, env)
    -- 施法提示
    local comment = pass_comment
    -- 暫存索引, 首選和預編輯文本
    local index, first_cand, first_preedit = 0, nil, ""
    -- 暫存前三候選, 然后單批次送出, 以解決閃屏問題, 並解決Hamster下顯示問題
    local three_cands = {}
    -- 迭代器
    local iter, obj = input:iter()
    local next = iter(obj)
    while next do
        index = index + 1
        local cand = next

        if not first_cand then
            -- 把首選捉出來
            first_cand = cand:get_genuine()
            -- 下划线不太好看, 换成减
            first_preedit = string.gsub(first_cand.preedit, '_', '-')
        end

        -- 修改首選的預编輯文本, 這会作爲内嵌編碼顯示到輸入處
        if index == 1 then
            -- 首選和編碼
            if string.len(cand.text) <= string.len("三個字") then
                -- 三字以内, 先字後碼
                first_preedit = cand.text..first_preedit
            else
                -- 三字以上, 先碼後字
                first_preedit = first_preedit..cand.text
            end
            -- 施法提示
            if comment and string.len(comment) ~= 0 then
                first_preedit = first_preedit.." ["..comment.."]"
            end
            -- 注入首選
            table.insert(three_cands, cand)
        elseif index <= 3 then
            -- 二三選處理
            if string.len(cand.text) ~= 0 then
                -- 限定非空候选, 因爲占位候選不需要顯示
                first_preedit = first_preedit.." "..tostring(index).."."..cand.text
            end
            -- 注入次選和三選
            table.insert(three_cands, cand)

            if index == 3 then
                -- 三選時, 刷新預編輯文本
                first_cand.preedit = first_preedit
                first_preedit = ""
                -- 将暫存的前三候選批次送出
                for _, c in ipairs(three_cands) do
                    yield(c)
                end
            end
        end

        if string.len(comment) ~= 0 and comment ~= cand.text then
            -- 给首个与打断提示不同的候选添加施法提示
            local c = cand:get_genuine()
            c.comment, comment = "["..comment.."]", ""
        end

        next = iter(obj)
        if not next then
            -- not next 表示没有下一候選, 説明當前遍歷結束
            -- 這時有可能不足三選, 暫存的候選也就有可能没有批次送出
            if index < 3 then
                -- 不足三選, 刷新預編輯文本
                first_cand.preedit = first_preedit
                first_preedit = ""
            end
            -- 将暫存的前三候選批次送出
            for _, c in ipairs(three_cands) do
                yield(c)
            end
        end

        if index > 3 then
            yield(cand)
        end
    end
end

function M.filter.fini(env)
end

-- ######## 翻译器 ########

function M.translator.init(env)
    env.mem = Memory(env.engine, env.engine.schema)
end

-- 翻译器
function M.translator.func(input, seg, env)
    -- 单字Z键顶, 记录上屏历史
    if commit_history(input, seg, env) then
        return
    end

    -- 清空施法提示
    pass_comment = ''

    -- 分词
    input = string.gsub(input, 'z', ';')
    local code_segs, remaining = get_code_segs(input)
    local fullcode_entries

    if remaining and remaining == ";" and code_segs and #code_segs > 1 then
        -- 有单个冗余分号, 且分词数大于一, 触发 "打断施法"
        fullcode_entries = dict_lookup(table.concat(code_segs, ''), env)
        local char_list, retain = query_cand_list(code_segs, env)
        if char_list then
            if fullcode_entries and #fullcode_entries > 1 and fullcode_entries[1].text == table.concat(char_list, '') then
                -- 多重智能詞, 且首選與單字相同, 上屏第二候選
                yield(Candidate("table", seg.start, seg._end, fullcode_entries[2].text, fullcode_entries[2].comment))
                return
            end

            -- 移除末位候選
            table.remove(char_list)
            remaining = ''
            for _, char in ipairs(char_list) do
                -- 上屏
                env.engine:commit_text(char)
            end
            -- 清空编码, 追加保留串
            env.engine.context:clear()
            env.engine.context:push_input(retain)
            -- 假装table_translator
            if env.mem:dict_lookup(retain, true, 100) then
                for entry in env.mem:iter_dict() do
                    yield(Candidate("table", seg.start, seg._end, entry.text, entry.comment))
                end
            end
        end
    end
    if (not remaining or remaining == "") and code_segs and #code_segs > 1 then
        -- 没有冗余编码, 分词数大于一, 触发施法提示
        -- local pass_comment = ""
        fullcode_entries = dict_lookup(table.concat(code_segs, ''), env)
        local char_list, _ = query_cand_list(code_segs, env)
        if char_list then
            if fullcode_entries and #fullcode_entries > 1 and fullcode_entries[1].text == table.concat(char_list, '') then
                -- 多重智能詞, 且首選與單字相同, 提示第二候選
                pass_comment = "↩"..fullcode_entries[2].text
            else
                -- 單個候選詞, 或首選與單字不同, 提示首選
                pass_comment = "☯"..table.concat(char_list, '')
            end
        end

        -- 唯一候选添加占位候选
        local entries = dict_lookup(input, env, true)
        if entries and #entries == 1 then
            yield(Candidate("table", seg.start, seg._end, "", ""))
        end
    end
end

function M.translator.fini(env)
end

return M
