local translator = {}
local core = require("smyh.core")

-- ######## 翻译器 ########

function translator.init(env)
    env.mem = Memory(env.engine, env.engine.schema)
end

-- 翻译器
function translator.func(input, seg, env)
    core.input_code = input

    -- 单字Z键顶, 记录上屏历史
    if core.commit_history(input, seg, env) then
        return
    end

    -- 清空施法提示
    core.pass_comment = ''

    -- 分词
    input = string.gsub(input, 'z', ';')
    local code_segs, remaining = core.get_code_segs(input)
    local fullcode_entries

    if remaining and remaining == ";" and code_segs and #code_segs > 1 then
        -- 有单个冗余分号, 且分词数大于一, 触发 "打断施法"
        fullcode_entries = core.dict_lookup(table.concat(code_segs, ''), env)
        local char_list, retain = core.query_cand_list(code_segs, env)
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
                    local cand = Candidate("table", seg.start, seg._end, entry.text, entry.comment)
                    cand.preedit = retain
                    yield(cand)
                end
            end
        end
    end
    if (not remaining or remaining == "") and code_segs and #code_segs > 1 then
        -- 没有冗余编码, 分词数大于一, 触发施法提示
        -- local pass_comment = ""
        fullcode_entries = core.dict_lookup(table.concat(code_segs, ''), env)
        local char_list, _ = core.query_cand_list(code_segs, env)
        if char_list then
            if fullcode_entries and #fullcode_entries > 1 and fullcode_entries[1].text == table.concat(char_list, '') then
                -- 多重智能詞, 且首選與單字相同, 提示第二候選
                core.pass_comment = "↵"..fullcode_entries[2].text
            else
                -- 單個候選詞, 或首選與單字不同, 提示首選
                core.pass_comment = "☯"..table.concat(char_list, '')
            end
        end

        -- 唯一候选添加占位候选
        local entries = core.dict_lookup(input, env, true)
        if entries and #entries == 1 then
            yield(Candidate("table", seg.start, seg._end, "", ""))
        end
    end
end

function translator.fini(env)
end

return translator
