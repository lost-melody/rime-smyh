local translator = {}
local core = require("smyh.core")

-- ######## 翻译器 ########

function translator.init(env)
    core.base_mem = Memory(env.engine, Schema("smyh.base"))
    core.full_mem = Memory(env.engine, Schema("smyh.yuhaofull"))
end

local index_indicators = {"¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹", "⁰"}

-- 處理開關管理候選
local function handle_switch(env, ctx, seg, input)
    core.input_code = "help "
    local text_list = {}
    for idx, option_name in ipairs(core.switch_options) do
        -- 渲染形如 "■選項¹"
        local text = ""
        local current_value = ctx:get_option(option_name)
        if current_value then
            text = text.."■"
        else
            text = text.."□"
        end
        text = text..core.switch_options[option_name]..index_indicators[idx]
        table.insert(text_list, text)
    end
    -- 避免選項翻頁, 直接渲染到首選提示中
    local cand = Candidate("switch", seg.start, seg._end, "", table.concat(text_list, " "))
    yield(cand)
end

-- 處理單字輸入
local function handle_singlechar(env, ctx, code_segs, remain, seg, input)
    core.input_code = string.gsub(remain, "[z;]", "-")

    -- 查询最多一百個候選
    local entries = core.dict_lookup(core.base_mem, remain, 100, true)
    if #entries == 0 then
        table.insert(entries, {text="", comment=""})
    end

    -- 依次送出候選
    for _, entry in ipairs(entries) do
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
    core.input_code = string.gsub(remain, "[z;]", "-")

    -- 先查出全串候選列表
    local full_entries = core.dict_lookup(core.base_mem, input, 10)
    if #full_entries > 1 then
        full_entries[2].comment = "↵"
    end

    if #input == 4 then
        local entries = core.dict_lookup(core.full_mem, input, 10)
        for _, entry in ipairs(entries) do
            table.insert(full_entries, entry)
        end
    end

    -- 查詢分詞串暫存值
    local text_list = core.query_cand_list(core.base_mem, code_segs)
    if #text_list ~= 0 then
        core.stashed_text = table.concat(text_list, "")
    end

    -- 查詢活動輸入串候選列表
    local entries = core.dict_lookup(core.base_mem, remain, 100 - #full_entries, true)
    if #entries == 0 then
        -- 以空串爲空碼候選
        table.insert(entries, {text="", comment=""})
    end
    if #full_entries == 1 then
        entries[1].comment = "☯"
    end

    -- 送出候選
    for _, entry in ipairs(full_entries) do
        local cand = Candidate("table", seg.start, seg._end, entry.text, entry.comment)
        yield(cand)
    end
    for _, entry in ipairs(entries) do
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

    if input == core.helper_code then
        -- zhelp 快捷開關
        handle_switch(env, ctx, seg, input)
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
end

return translator
