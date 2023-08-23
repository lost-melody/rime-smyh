local processor = {}
local core      = require("smyh.core")


local kRejected = 0 -- 拒: 不作響應, 由操作系統做默認處理
local kAccepted = 1 -- 收: 由rime響應該按鍵
local kNoop     = 2 -- 無: 請下一個processor繼續看


local char_a         = string.byte("a") -- 字符: 'a'
local char_z         = string.byte("z") -- 字符: 'z'
local char_a_upper   = string.byte("A") -- 字符: 'A'
local char_z_upper   = string.byte("Z") -- 字符: 'Z'
local char_0         = string.byte("0") -- 字符: '0'
local char_9         = string.byte("9") -- 字符: '9'
local char_space     = 0x20             -- 空格
local char_del       = 0x7f             -- 删除
local char_backspace = 0xff08           -- 退格


-- 按命名空間歸類方案配置, 而不是按会話, 以减少内存佔用
local namespaces = {}

function namespaces:init(env)
    -- 讀取配置項
    if not namespaces:config(env) then
        local config = {}
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

-- 返回被選中的候選的索引, 來自 librime-lua/sample 示例
local function select_index(key, env)
    local ch = key.keycode
    local index = -1
    local select_keys = env.engine.schema.select_keys
    if select_keys ~= nil and select_keys ~= "" and not key.ctrl() and ch >= 0x20 and ch < 0x7f then
        local pos = string.find(select_keys, string.char(ch))
        if pos ~= nil then index = pos end
    elseif ch >= 0x30 and ch <= 0x39 then
        index = (ch - 0x30 + 9) % 10
    elseif ch >= 0xffb0 and ch < 0xffb9 then
        index = (ch - 0xffb0 + 9) % 10
    elseif ch == 0x20 then
        index = 0
    end
    return index
end


-- 提交候選文本, 並刷新輸入串
local function commit_text(env, ctx, text, input)
    ctx:clear()
    if #text ~= 0 then
        env.engine:commit_text(text)
    end
    ctx:push_input(core.input_restore_funckeys(input))
end


local function handle_macros(env, ctx, macro, args, idx)
    if macro then
        if macro[idx] then
            macro[idx]:trigger(env, ctx, args)
        end
        return kAccepted
    end
    return kNoop
end

-- 處理頂字
local function handle_push(env, ctx, ch)
    if core.valid_smyh_input(ctx.input) then
        -- 輸入串分詞列表
        local code_segs, remain = core.get_code_segs(ctx.input)

        -- 純單字模式
        if env.option[core.switch_names.single_char] and #code_segs == 1 and #remain == 1 then
            local cands = core.query_cand_list(core.base_mem, code_segs)
            if #cands ~= 0 then
                commit_text(env, ctx, cands[1], remain .. string.char(ch))
            end
            return kAccepted
        end

        -- 智能詞延遲頂
        if #remain == 0 and #code_segs > 1 then
            local entries, remain = core.query_cand_list(core.base_mem, code_segs)
            if #entries > 1 then
                commit_text(env, ctx, entries[1], remain .. string.char(ch))
                return kAccepted
            end
        end
    end
    return kNoop
end

-- 處理空格分號選字
local function handle_select(env, ctx, ch, funckeys)
    if core.valid_smyh_input(ctx.input) then
        -- 輸入串分詞列表
        local _, remain = core.get_code_segs(ctx.input)
        if string.match(remain, "^[a-z][a-z]?$") then
            if funckeys.primary[ch] then
                ctx:push_input(core.funckeys_map.primary)
                return kAccepted
            elseif funckeys.secondary[ch] then
                ctx:push_input(core.funckeys_map.secondary)
                return kAccepted
            elseif funckeys.tertiary[ch] then
                ctx:push_input(core.funckeys_map.tertiary)
                return kAccepted
            end
        end
    end
    return kNoop
end

local function handle_fullcode(env, ctx, ch)
    if not env.option[core.switch_names.full_off] and #ctx.input == 4 and not string.match(ctx.input, "[^a-z]") then
        local fullcode_char = env.option[core.switch_names.full_char]
        local entries = core.dict_lookup(core.full_mem, ctx.input, 50)
        -- 查找四碼首選
        local first
        for _, entry in ipairs(entries) do
            -- 是否單字候選
            if utf8.len(entry.text) == 1 then
                -- 是否啓用單字狀態
                if fullcode_char then
                    -- 單字模式, 首字上屏
                    first = entry
                    break
                elseif not first then
                    -- 非單字模式, 首字暫存
                    first = entry
                end
            elseif not fullcode_char then
                -- 字詞模式, 首詞上屏
                first = entry
                break
            end
        end
        -- 上屏暫存的候選
        if first then
            ctx:clear()
            env.engine:commit_text(first.text)
        end
        return kAccepted
    end
    return kNoop
end

local function handle_break(env, ctx, ch)
    if core.valid_smyh_input(ctx.input) then
        -- 輸入串分詞列表
        local code_segs, remain = core.get_code_segs(ctx.input)
        if #remain == 0 then
            remain = table.remove(code_segs)
        end
        -- 打斷施法
        if #code_segs ~= 0 then
            local text_list = core.query_cand_list(core.base_mem, code_segs)
            commit_text(env, ctx, table.concat(text_list, ""), remain)
            return kAccepted
        end
    end
    return kNoop
end

local function handle_repeat(env, ctx, ch)
    if core.valid_smyh_input(ctx.input) then
        -- 查詢當前首選項
        local code_segs, remain = core.get_code_segs(ctx.input)
        local text_list, _ = core.query_cand_list(core.base_mem, code_segs)
        local text = table.concat(text_list, "")
        if #remain ~= 0 then
            local entries = core.dict_lookup(core.base_mem, remain, 1)
            text = text .. (entries[1] and entries[1].text or "")
        end
        -- 逐個上屏
        ctx:clear()
        for _, c in utf8.codes(text) do
            env.engine:commit_text(utf8.char(c))
        end
    end
    return kNoop
end

-- 清理活動串
local function handle_clean(env, ctx, ch)
    if not core.valid_smyh_input(ctx.input) then
        return kNoop
    end

    -- 輸入串分詞列表
    local code_segs, remain = core.get_code_segs(ctx.input)
    -- 取出活動串
    if #remain == 0 then
        remain = table.remove(code_segs)
    end

    -- 回删活動串
    ctx:pop_input(#core.input_restore_funckeys(remain))
    return kAccepted
end


function processor.init(env)
    if Switcher then
        env.switcher = Switcher(env.engine)
    end

    -- 讀取配置項
    local ok = pcall(namespaces.init, namespaces, env)
    if not ok then
        local config = {}
        config.macros = {}
        config.funckeys = {}
        namespaces:set_config(env, config)
    end

    -- 構造回調函數
    local option_names = {
        core.switch_names.single_char,
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

function processor.func(key_event, env)
    local ctx = env.engine.context
    if #ctx.input == 0 or key_event:release() or key_event:alt() then
        -- 當前無輸入, 或不是我關注的鍵按下事件, 棄之
        return kNoop
    end

    local ch = key_event.keycode
    local funckeys = namespaces:config(env).funckeys
    if funckeys.macro[string.byte(string.sub(ctx.input, 1, 1))] then
        -- starts with funckeys/macro set
        local name, args = core.get_macro_args(string.sub(ctx.input, 2), namespaces:config(env).funckeys.macro)
        local macro = namespaces:config(env).macros[name]
        if macro then
            if macro.hijack and ch > char_space and ch < char_del then
                ctx:push_input(string.char(ch))
                return kAccepted
            else
                local idx = select_index(key_event, env)
                if funckeys.clearact[ch] then
                    ctx:clear()
                    return kAccepted
                elseif idx >= 0 then
                    return handle_macros(env, ctx, macro, args, idx + 1)
                end
            end
            return kNoop
        end
    end

    if ch >= char_a and ch <= char_z then
        -- 'a'~'z'
        return handle_push(env, ctx, ch)
    end

    if ch == char_backspace then
        if string.match(ctx.input, " [a-c]$") then
            ctx:pop_input(1)
        end
        return kNoop
    end

    local res = kNoop
    if res == kNoop and (funckeys.primary[ch] or funckeys.secondary[ch] or funckeys.tertiary[ch]) then
        res = handle_select(env, ctx, ch, funckeys)
    end
    if res == kNoop and funckeys.fullci[ch] then
        -- 四碼單字
        res = handle_fullcode(env, ctx, ch)
    end
    if res == kNoop and funckeys["break"][ch] then
        -- 打斷施法
        res = handle_break(env, ctx, ch)
    end
    if res == kNoop and funckeys["repeat"][ch] then
        -- 重複上屏
        res = handle_repeat(env, ctx, ch)
    end
    if res == kNoop and funckeys.clearact[ch] then
        -- 清除活動編碼
        res = handle_clean(env, ctx, ch)
    end
    return res
end

function processor.fini(env)
    env.switcher = nil
    env.option = nil
end

return processor
