local translator = {}
local core = require("smyh.core")

-- ######## 翻译器 ########

function translator.init(env)
    -- env.mem = Memory(env.engine, env.engine.schema)
    env.base = Memory(env.engine, Schema("smyh.base"))
end

local function deal_semicolon(code_segs, remain, seg, env, init_input)
    if string.len(remain) > 1 then
        -- 不對勁
        return
    elseif #code_segs == 1 then
        -- 單字全/簡碼+分號
        -- 二重一簡詞
        local entries = core.dict_lookup(env.base, table.concat(code_segs, "")..remain, 100, true)
        for _, entry in ipairs(entries) do
            yield(Candidate("table", seg.start, seg._end, entry.text, entry.comment))
        end
        if #entries == 1 then
            -- 唯一候選加竞爭
            yield(Candidate("table", seg.start, seg._end, "", ""))
        end
        -- 分號頂
        if #entries == 0 and string.sub(init_input, string.len(init_input)) == "z" then
            -- 單字Z鍵頂
            local entries = core.dict_lookup(env.base, table.concat(code_segs, ""))
            if entries[1] then
                env.engine:commit_text(entries[1].text)
                env.engine.context:clear()
                env.engine.context:push_input("z")
                yield(Candidate("table", seg.start, seg._end, entries[1].text, ""))
                yield(Candidate("table", seg.start, seg._end, "", ""))
            end
        end
        return
    elseif #code_segs ~= 0 then
        -- 智能詞+分號: 打斷施法
        local entries = core.dict_lookup(env.base, table.concat(code_segs, ""), 2)
        if #entries > 1 then
            -- 多個智能詞, 选中次選
            yield(Candidate("table", seg.start, seg._end, entries[2].text, entries[2].comment))
            return
        end

        -- 獲取分詞候選
        local text_list, last_code = core.query_cand_list(env.base, code_segs, true)
        env.engine:commit_text(table.concat(text_list, "", 1, #text_list-1))

        -- 處理頂字
        remain = last_code
        env.engine.context:clear()
        env.engine.context:push_input(remain)
        core.input_code = string.gsub(remain, ";", "-")

        local entries = core.dict_lookup(env.base, remain, 100, true)
        if #entries == 0 then
            table.insert(entries, {text="", comment=""})
        end
        for _, entry in ipairs(entries) do
            yield(Candidate("table", seg.start, seg._end, entry.text, entry.comment))
        end
        if #entries == 1 then
            -- 唯一候選加竞爭
            yield(Candidate("table", seg.start, seg._end, "", ""))
        end
        return
    else
        -- 孤獨的分號
        return
    end
end

local function deal_singlechar(code_segs, remain, seg, env, init_input)
    local entries = core.dict_lookup(env.base, remain, 100, true)
    if #entries == 0 then
        table.insert(entries, {text="", comment=""})
    end
    for _, entry in ipairs(entries) do
        yield(Candidate("table", seg.start, seg._end, entry.text, entry.comment))
    end
    if #entries == 1 then
        -- 唯一候選添加占位
        yield(Candidate("table", seg.start, seg._end, "", ""))
    end
end

local function deal_delayed(code_segs, remain, seg, env, init_input)
    -- 先查出全串候選列表
    local full_entries = core.dict_lookup(env.base, table.concat(code_segs, "")..remain, 10)
    if #full_entries > 1 then
        full_entries[2].comment = "↵"
    end

    -- 查詢分詞串暫存值
    local text_list, last_code = core.query_cand_list(env.base, code_segs)
    if #text_list > 1 and #full_entries == 0 then
        -- 延遲串大於一, 全碼无候選, 頂之
        -- ["電動", "機"] -> commit "電動", ["機"]
        env.engine:commit_text(table.concat(text_list, "", 1, #text_list-1))
        -- ["機"] -> stash "機"
        core.stashed_text = text_list[#text_list]

        -- 處理頂字
        local input = last_code..remain
        env.engine.context:clear()
        env.engine.context:push_input(input)
        core.input_code = string.gsub(input, ";", "-")
    else
        -- 延遲串小於或等於一, 存之
        core.stashed_text = table.concat(text_list, "")
    end

    -- 查詢活動輸入串候選列表
    core.input_code = string.gsub(remain, ";", "-")
    local entries = core.dict_lookup(env.base, remain, 100-#full_entries, true)
    if #entries == 0 then
        table.insert(entries, {text=remain, comment=""})
    end
    if #full_entries == 1 then
        entries[1].comment = "☯"
    end

    -- 送出候選
    for _, entry in ipairs(full_entries) do
        yield(Candidate("table", seg.start, seg._end, entry.text, entry.comment))
    end
    for _, entry in ipairs(entries) do
        yield(Candidate("table", seg.start, seg._end, core.stashed_text..entry.text, entry.comment))
    end

    -- 唯一候選添加占位
    if #full_entries+#entries == 1 then
        yield(Candidate("table", seg.start, seg._end, "", ""))
    end
end

function translator.func(input, seg, env)
    core.input_code = ""
    core.stashed_text = ""

    if not string.match(input, "^[a-z;]*$") or string.match(input, "^[z;]") then
        -- 非吾所願矣
        return
    end


    -- Z鍵統一變更爲分號
    local init_input = input
    input = string.gsub(input, "z", ";")
    core.input_code = string.gsub(input, ";", "-")

    -- code_segs 是按 "abc"/"a;" 單字全簡碼分組的串列表, 其每個元素都滿足這一條件
    local code_segs, remain = core.get_code_segs(input)
    if string.match(remain, "^[z;]") then
        -- 處理分號
        deal_semicolon(code_segs, remain, seg, env, init_input)
        return
    end

    -- 若余串 remain 爲空, 則將 code_segs 最末單字串提出
    if #code_segs ~= 0 and string.len(remain) == 0 then
        if #code_segs ~= 0 then
            -- ["dkd"], "" => [], "dkd"
            -- ["dkd"], "q" => remains
            -- ["dkd","qgx","fvt"], "" => ["dkd","qgx"], "fvt"
            remain = table.remove(code_segs)
        end
    end

    if #code_segs == 0 then
        -- code_segs 爲空, 僅單字
        deal_singlechar(code_segs, remain, seg, env, init_input)
    else
        -- code_segs 非空, 延遲頂組合串
        deal_delayed(code_segs, remain, seg, env, init_input)
    end
end

function translator.fini(env)
end

return translator
