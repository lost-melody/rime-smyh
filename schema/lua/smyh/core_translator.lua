local translator = {}
local core = require("smyh.core")


local schemas = nil


-- 按命名空間歸類方案配置, 而不是按会話, 以减少内存佔用
local namespaces = {}

function namespaces:init(env)
    -- 讀取配置項
    if not namespaces:config(env) then
        local config = {}
        config.comp = core.parse_conf_bool(env, "enable_completion")
        config.macros = core.parse_conf_macro_list(env)
        config.funckeys = core.parse_conf_funckeys(env)
        namespaces:set_config(env, config)
    end
end

function namespaces:set_config(env, config)
    namespaces[env.name_space] = namespaces[env.name_space] or {}
    namespaces[env.name_space].config = config
end

function namespaces:config(env)
    return namespaces[env.name_space] and namespaces[env.name_space].config
end

-- ######## 翻译器 ########

function translator.init(env)
    local ok = pcall(namespaces.init, namespaces, env)
    if not ok then
        local config = {}
        config.comp = false
        config.macros = {}
        config.funckeys = {}
        namespaces:set_config(env, config)
    end

    -- 初始化碼表
    if not schemas and Memory then
        local smyh_rev = ReverseLookup and ReverseLookup("smyh.base")
        local smyh_tc_rev = ReverseLookup and ReverseLookup("smyh_tc.base")
        schemas = {
            smyh_base = Memory(env.engine, Schema("smyh.base")),
            smyh_full = Memory(env.engine, Schema("smyh.yuhaowords")),
            smyh_trie = core.gen_smart_trie(smyh_rev, "smyh.smart.userdb", "smyh.smart.txt"),
            smyh_tc_base = Memory(env.engine, Schema("smyh_tc.base")),
            smyh_tc_full = Memory(env.engine, Schema("smyh_tc.yuhaowords")),
            smyh_tc_trie = core.gen_smart_trie(smyh_tc_rev, "smyh_tc.smart.userdb", "smyh_tc.smart.txt"),
        }
    elseif not schemas then
        schemas = {}
    end
    if not core.base_mem and schemas then
        core.base_mem = schemas.smyh_base
        core.full_mem = schemas.smyh_full
        core.word_trie = schemas.smyh_trie
    end

    -- 同步開關狀態, 更新碼表
    local function schema_switcher(ctx, name)
        if name == core.switch_names.smyh_tc then
            local enabled = ctx:get_option(name)
            if enabled then
                core.base_mem = schemas.smyh_tc_base
                core.full_mem = schemas.smyh_tc_full
                core.word_trie = schemas.smyh_tc_trie
            else
                core.base_mem = schemas.smyh_base
                core.full_mem = schemas.smyh_full
                core.word_trie = schemas.smyh_trie
            end
        end
    end
    schema_switcher(env.engine.context, core.switch_names)
    env.engine.context.option_update_notifier:connect(schema_switcher)

    -- 構造回調函數
    local option_names = {
        core.switch_names.full_word,
        core.switch_names.full_char,
        core.switch_names.full_off,
    }
    local handler = core.get_switch_handler(env, option_names)
    -- 初始化爲選項實際值, 如果設置了 reset, 則會再次觸發 handler
    for _, name in ipairs(option_names) do
        handler(env.engine.context, name)
    end
    -- 注册通知回調
    env.engine.context.option_update_notifier:connect(handler)
end

local index_indicators = { "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹", "⁰" }

local display_map = {
    ["1"] = "-",
    ["2"] = "+",
    ["3"] = "=",
}

local comment_map = {
    ["1"] = "␣",
    ["2"] = "⌥",
    ["3"] = "⌃",
}

local function display_input(input)
    input = string.gsub(input, "([1-3])", display_map)
    return input
end

local function display_comment(comment)
    comment = string.gsub(comment, "([1-3])", comment_map)
    return comment
end


-- 處理宏
local function handle_macros(env, ctx, seg, input)
    local name, args = core.get_macro_args(input, namespaces:config(env).funckeys.macro)
    local macro = namespaces:config(env).macros[name]
    if macro then
        core.input_code = ":" .. input .. " "
        local text_list = {}
        for i, m in ipairs(macro) do
            table.insert(text_list, m:display(env, ctx, args) .. index_indicators[i])
        end
        local cand = Candidate("macro", seg.start, seg._end, "", table.concat(text_list, " "))
        yield(cand)
    end
end

-- 處理單字輸入
local function handle_singlechar(env, ctx, code_segs, remain, seg, input)
    core.input_code = display_input(remain)

    -- 查询最多一百個候選
    local entries = core.dict_lookup(core.base_mem, remain, 100, namespaces:config(env).comp)
    if #entries == 0 then
        table.insert(entries, { text = "", comment = "" })
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
    local full_entries = {}
    -- TODO: 優化智能詞查詢
    if #code_segs ~= 0 then
        local full_segs = {}
        for _, seg in ipairs(code_segs) do
            table.insert(full_segs, seg)
        end
        if #remain ~= 0 then
            table.insert(full_segs, remain)
        end
        local chars = core.query_first_cand_list(core.base_mem, full_segs)
        local words = core.word_trie:query(full_segs, chars, 10)
        for _, word in ipairs(words) do
            table.insert(full_entries, { text = word, comment = "☯" })
        end
    end

    if not env.option[core.switch_names.full_off] and #input == 4 and not string.match(input, "[^a-z]") then
        local fullcode_cands = 0
        local fullcode_char = env.option[core.switch_names.full_char]
        local entries = core.dict_lookup(core.full_mem, input, 50)
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
            full_entries[1].comment = "⇥"
            core.input_code = display_input(input)
        end
    end

    -- 查詢分詞串暫存值
    local text_list = core.query_cand_list(core.base_mem, code_segs)
    if #text_list ~= 0 then
        core.stashed_text = table.concat(text_list, "")
    end

    -- 查詢活動輸入串候選列表
    local entries = core.dict_lookup(core.base_mem, remain, 100 - #full_entries, namespaces:config(env).comp)
    if #entries == 0 then
        -- 以空串爲空碼候選
        table.insert(entries, { text = "", comment = "" })
    end

    -- 送出候選
    local cand_count = #entries + #full_entries
    if #input == 4 and #entries ~= 0 then
        -- abc|a 時, a_ 總是前置
        local entry = table.remove(entries, 1)
        entry.comment = display_comment(entry.comment)
        local cand = Candidate("table", seg.start, seg._end, core.stashed_text .. entry.text, entry.comment)
        yield(cand)
    end
    for _, entry in ipairs(full_entries) do
        -- 全碼候選, 含 abc|a 和 abc|abc 兩類
        entry.comment = display_comment(entry.comment)
        local cand = Candidate("table", seg.start, seg._end, entry.text, entry.comment)
        yield(cand)
    end
    for _, entry in ipairs(entries) do
        -- 單字候選, 含延遲串
        entry.comment = display_comment(entry.comment)
        local cand = Candidate("table", seg.start, seg._end, core.stashed_text .. entry.text, entry.comment)
        yield(cand)
    end

    -- 唯一候選添加占位
    if cand_count == 1 then
        local cand = Candidate("table", seg.start, seg._end, "", "")
        yield(cand)
    end
end


function translator.func(input, seg, env)
    local ctx = env.engine.context
    core.input_code = ""
    core.stashed_text = ""

    local funckeys = namespaces:config(env).funckeys
    if funckeys.macro[string.byte(string.sub(ctx.input, 1, 1))] then
        handle_macros(env, ctx, seg, string.sub(input, 2))
        return
    end

    -- 是否合法宇三編碼
    if not core.valid_smyh_input(input) then
        return
    end

    input = core.input_replace_funckeys(input)
    local code_segs, remain = core.get_code_segs(input)
    if #remain == 0 then
        remain = table.remove(code_segs)
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
