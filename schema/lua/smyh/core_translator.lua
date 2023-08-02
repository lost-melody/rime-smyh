local translator = {}
local core = require("smyh.core")

-- ######## 翻译器 ########

function translator.init(env)
    -- 初始化碼表
    if not core.base_mem then
        core.base_mem = Memory(env.engine, Schema("smyh.base"))
        core.full_mem = Memory(env.engine, Schema("smyh.yuhaofull"))
        core.yuhao_mem = Memory(env.engine, Schema("smyh.yuhao"))
    end
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

-- 處理開關管理候選
local function handle_switch(env, ctx, seg, input)
    core.input_code = "help "
    local text_list = {}
    for idx, option in ipairs(core.switch_options) do
        local text = ""
        if option.type == core.switch_types.switch then
            -- 開關項, 渲染形如 "■選項¹"
            local state = ""
            local current_value = ctx:get_option(option.name)
            if current_value then
                text = text.."■"
                state = option.display[1]
            else
                text = text.."□"
                state = option.display[2]
            end
            text = text..state..index_indicators[idx]
        elseif option.type == core.switch_types.radio then
            -- 單選項, 渲染形如 "□■□狀態二"
            local state = ""
            for _, op in ipairs(option.states) do
                local value = ctx:get_option(op.name)
                if value then
                    text = text.."■"
                    state = op.display
                else
                    text = text.."□"
                end
            end
            text = text..state..index_indicators[idx]
        end
        table.insert(text_list, text)
    end
    -- 避免選項翻頁, 直接渲染到首選提示中
    local cand = Candidate("switch", seg.start, seg._end, "", table.concat(text_list, " "))
    yield(cand)
end

-- 處理單字輸入
local function handle_singlechar(env, ctx, code_segs, remain, seg, input)
    core.input_code = display_input(remain)

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
    core.input_code = display_input(remain)

    -- 先查出全串候選列表
    local full_entries = core.dict_lookup(core.base_mem, input, 10)

    if #input == 4 then
        local mem
        if env.option[core.switch_names.fullcode_char] then
            -- 純單模式, 查詢單字全碼
            mem = core.full_mem
        else
            -- 非純單時, 查詢官宇字詞
            mem = core.yuhao_mem
        end
        local entries = core.dict_lookup(mem, input, 10)
        local stashed = {}
        -- 詞語前置, 單字暫存
        for _, entry in ipairs(entries) do
            if utf8.len(entry.text) == 1 then
                table.insert(stashed, entry)
            else
                table.insert(full_entries, entry)
            end
        end
        -- 收錄暫存候選
        for _, entry in ipairs(stashed) do
            table.insert(full_entries, entry)
        end
    end

    -- 查詢分詞串暫存值
    local text_list = core.query_first_cand_list(core.base_mem, code_segs)
    if #text_list ~= 0 then
        core.stashed_text = table.concat(text_list, "")
    end

    -- 查詢活動輸入串候選列表
    local entries = core.dict_lookup(core.base_mem, remain, 100 - #full_entries, true)
    if #entries == 0 then
        -- 以空串爲空碼候選
        table.insert(entries, {text="", comment=""})
    end

    -- 送出候選
    for _, entry in ipairs(full_entries) do
        if #input ~= 4 and #entries ~= 0 then
            -- 單字組合串總是首選, 智能詞次之
            local entry = table.remove(entries, 1)
            local cand = Candidate("table", seg.start, seg._end, core.stashed_text..entry.text, entry.comment)
            yield(cand)
        end
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
        -- "/help" 快捷開關
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
    env.option = nil
end

return translator
