local translator = {}
local core = require("smyh.core")

local schemas = nil

-- ######## 翻译器 ########

function translator.init(env)
    env.config = {}
    env.config.comp = core.parse_conf_bool(env, "enable_completion")
    env.config.macros = core.parse_conf_macro_list(env)

    -- 初始化碼表
    if not schemas then
        schemas = {
            smyh_base = Memory(env.engine, Schema("smyh.base")),
            smyh_full = Memory(env.engine, Schema("smyh.yuhaofull")),
            smyh_tc_base = Memory(env.engine, Schema("smyh_tc.base")),
            smyh_tc_full = Memory(env.engine, Schema("smyh_tc.yuhaofull")),
        }
    end
    if not core.base_mem then
        core.base_mem = schemas.smyh_base
        core.full_mem = schemas.smyh_full
    end

    -- 同步開關狀態, 更新碼表
    local function schema_switcher(ctx, name)
        if name == core.switch_names.smyh_tc then
            local enabled = ctx:get_option(name)
            if enabled then
                core.base_mem = schemas.smyh_tc_base
                core.full_mem = schemas.smyh_tc_full
            else
                core.base_mem = schemas.smyh_base
                core.full_mem = schemas.smyh_full
            end
        end
    end
    schema_switcher(env.engine.context, core.switch_names)
    env.engine.context.option_update_notifier:connect(schema_switcher)

    -- 構造回調函數
    local handler = core.get_switch_handler(env, core.switch_names.fullcode_char)
    -- 初始化爲選項實際值, 如果設置了 reset, 則會再次觸發 handler
    handler(env.engine.context, core.switch_names.fullcode_char)
    -- 注册通知回調
    env.engine.context.option_update_notifier:connect(handler)
end

local index_indicators = {"¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹", "⁰"}

local function display_input(input)
    input = string.gsub(input, " ", "-")
    input = string.gsub(input, ";", "+")
    return input
end

local function display_comment(comment)
    comment = string.gsub(comment, "1", "␣")
    comment = string.gsub(comment, "2", "⌥")
    return comment
end

-- 處理宏
local function handle_macros(env, ctx, seg, input)
    local macro = env.config.macros[input]
    if macro then
        core.input_code = ":" .. input .. " "
        local text_list = {}
        for i, m in ipairs(macro) do
            table.insert(text_list, m:display(ctx) .. index_indicators[i])
        end
        local cand = Candidate("macro", seg.start, seg._end, "", table.concat(text_list, " "))
        yield(cand)
    end
end

-- 處理單字輸入
local function handle_singlechar(env, ctx, code_segs, remain, seg, input)
    core.input_code = display_input(remain)

    -- 查询最多一百個候選
    local entries = core.dict_lookup(core.base_mem, remain, 100, env.config.comp)
    if #entries == 0 then
        table.insert(entries, {text="", comment=""})
    end

    -- 依次送出候選
    for _, entry in ipairs(entries) do
        entry.comment = display_comment(entry.comment)
        local cand = Candidate("table", seg.start, seg._end, entry.text, entry.comment)
        yield(cand)
    end

    -- 唯一候選添加占位
    if #entries == 1 then
        local cand = Candidate("table", seg.start, seg._end, "", "")
        yield(cand)
    end
end

-- 處理含延遲串的編碼
local function handle_delayed(env, ctx, code_segs, remain, seg, input)
    core.input_code = display_input(remain)

    -- 先查出全串候選列表
    local full_entries = core.dict_lookup(core.base_mem, input, 10)
    if #full_entries ~= 0 then
        full_entries[1].comment = "☯"
    end

    if #input == 4 then
        local fullcode_cands = 0
        local fullcode_char = env.option[core.switch_names.fullcode_char] or false
        local entries = core.dict_lookup(core.full_mem, input, 10)
        local stashed = {}
        -- 詞語前置, 單字暫存
        for _, entry in ipairs(entries) do
            if utf8.len(entry.text) == 1 then
                table.insert(stashed, entry)
                fullcode_cands = fullcode_cands + 1
            else
                -- 全單模式, 詞語過濾
                -- 字詞模式, 詞語前置
                if not fullcode_char then
                    table.insert(full_entries, entry)
                    fullcode_cands = fullcode_cands + 1
                end
            end
        end
        -- 收錄暫存候選
        for _, entry in ipairs(stashed) do
            table.insert(full_entries, entry)
        end
        if fullcode_cands ~= 0 then
            core.input_code = display_input(input)
        end
    end

    -- 查詢分詞串暫存值
    local text_list = core.query_cand_list(core.base_mem, code_segs)
    if #text_list ~= 0 then
        core.stashed_text = table.concat(text_list, "")
    end

    -- 查詢活動輸入串候選列表
    local entries = core.dict_lookup(core.base_mem, remain, 100 - #full_entries, env.config.comp)
    if #entries == 0 then
        -- 以空串爲空碼候選
        table.insert(entries, {text="", comment=""})
    end

    -- 送出候選
    for _, entry in ipairs(full_entries) do
        entry.comment = display_comment(entry.comment)
        local cand = Candidate("table", seg.start, seg._end, entry.text, entry.comment)
        yield(cand)
    end
    for _, entry in ipairs(entries) do
        entry.comment = display_comment(entry.comment)
        local cand = Candidate("table", seg.start, seg._end, core.stashed_text..entry.text, entry.comment)
        yield(cand)
    end

    -- 唯一候選添加占位
    if #full_entries + #entries == 1 then
        local cand = Candidate("table", seg.start, seg._end, "", "")
        yield(cand)
    end
end

function translator.func(input, seg, env)
    local ctx = env.engine.context
    core.input_code = ""
    core.stashed_text = ""

    if string.match(input, "^/") then
        handle_macros(env, ctx, seg, string.sub(input, 2))
        return
    end

    -- 是否合法宇三編碼
    if not core.valid_smyh_input(input) then
        return
    end

    local code_segs, remain = core.get_code_segs(input)
    if #remain == 0 then
        remain = table.remove(code_segs)
    end

    -- 活動串不是合法宇三編碼, 空碼
    if not core.valid_smyh_input(remain) then
        return
    end

    if #code_segs == 0 then
        -- 僅單字
        handle_singlechar(env, ctx, code_segs, remain, seg, input)
    else
        -- 延遲頂組合串
        handle_delayed(env, ctx, code_segs, remain, seg, input)
    end
end

function translator.fini(env)
    env.option = nil
end

return translator
