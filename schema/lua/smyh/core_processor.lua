local processor   = {}
local core        = require("smyh.core")

local kRejected   = 0        -- 拒: 不作響應, 由操作系統做默認處理
local kAccepted   = 1        -- 收: 由rime響應該按鍵
local kNoop       = 2        -- 無: 請下一個processor繼續看

local cA          = string.byte("a") -- 字符: 'a'
local cZ          = string.byte("z") -- 字符: 'z'
local cBs         = 0xff08           -- 退格

-- 按命名空間歸類方案配置, 而不是按会話, 以减少内存佔用
local namespaces = {}
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

-- 執行開關同步
local function sync_switches(env, ctx, key_event)
    if env.sync_at < core.sync_at then
        env.sync_at = core.sync_at
        -- 當總線更新時間比會話晚時, 將總線值同步到會話中
        for op_name, value in pairs(core.sync_bus.switches) do
            if env.sync_options[op_name] ~= value then
                env.sync_options[op_name] = value
                if not ctx:get_option("unsync_" .. op_name) and ctx:get_option(op_name) ~= value then
                    ctx:set_option(op_name, value)
                end
            end
        end
    end
end

-- 提交候選文本, 並刷新輸入串
local function commit_text(env, ctx, text, input)
    ctx:clear()
    if #text ~= 0 then
        env.engine:commit_text(text)
    end
    ctx:push_input(core.input_restore_funckeys(input))
end

local function handle_macros(env, ctx, input, idx)
    local name, args = core.get_macro_args(input, namespaces:config(env).funckeys.macro)
    local macro = namespaces:config(env).macros[name]
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
        ctx:commit()
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
    if not namespaces:config(env) then
        local config = {}
        config.sync_options = core.parse_conf_str_list(env, "sync_options")
        config.sync_options.synced_at = 0
        config.macros = core.parse_conf_macro_list(env)
        config.funckeys = core.parse_conf_funckeys(env)
        namespaces:set_config(env, config)
    end

    -- 讀取需要同步的開關項列表
    env.sync_at = 0
    env.sync_options = {}
    for _, op_name in ipairs(namespaces:config(env).sync_options) do
        env.sync_options[op_name] = true
    end
    -- 注册回調
    env.engine.context.option_update_notifier:connect(function(ctx, op_name)
        if env.sync_options[op_name] ~= nil then
            -- 當選項在同步列表中時, 將變更同步到總線
            local value = ctx:get_option(op_name)
            if env.sync_at == 0 and core.sync_at ~= 0 and core.sync_bus.switches[op_name] ~= nil then
                -- 當前會話未同步過, 且總線有值, 可能是由 reset 觸發
            elseif ctx:get_option("unsync_" .. op_name) then
                -- 當前會話設置禁用了此開關同步
            elseif core.sync_bus.switches[op_name] ~= value then
                -- 同步到總線
                core.sync_at = os.time()
                core.sync_bus.switches[op_name] = value
            end
            -- 會話值總是賦值爲當前實際值
            env.sync_options[op_name] = value
        end
    end)

    -- 構造回調函數
    local option_names = {
        core.switch_names.single_char,
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
    if #ctx.input == 0 then
        -- 開關狀态同步
        sync_switches(env, ctx, key_event)
    end

    if #ctx.input == 0 or key_event:release() or key_event:alt() then
        -- 當前無輸入, 或不是我關注的鍵按下事件, 棄之
        return kNoop
    end

    local ch = key_event.keycode
    local funckeys = namespaces:config(env).funckeys
    if funckeys.macro[string.byte(string.sub(ctx.input, 1, 1))] then
        -- starts with funckeys/macro set
        local idx = select_index(key_event, env)
        if funckeys.clearact[ch] then
            ctx:clear()
            return kAccepted
        elseif idx >= 0 then
            return handle_macros(env, ctx, string.sub(ctx.input, 2), idx + 1)
        elseif funckeys.macro[ch] then
            ctx:push_input(string.char(ch))
            return kAccepted
        else
            return kNoop
        end
    end

    if ch >= cA and ch <= cZ then
        -- 'a'~'z'
        return handle_push(env, ctx, ch)
    end

    if ch == cBs then
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
