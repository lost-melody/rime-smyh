local processor = {}
local core = require("smyh.core")

local kRejected = 0 -- 拒: 不作響應, 由操作系統做默認處理
local kAccepted = 1 -- 收: 由rime響應該按鍵
local kNoop     = 2 -- 無: 請下一個processor繼續看

local cA  = string.byte("a") -- 字符: 'a'
local cZ  = string.byte("z") -- 字符: 'z'
local cSC = string.byte(";") -- 字符: ';'
local cSp = string.byte(" ") -- 空格鍵
local cSl = 0xffe1           -- 左Shift
local cSr = 0xffe2           -- 右Shift
local cCl = 0xffe3           -- 左Ctrl
local cCr = 0xffe4           -- 右Ctrl
local cRt = 0xff0d           -- 回車鍵

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

-- 設置開關狀態, 並更新保存的配置值
local function set_option(env, ctx, option_name, value)
    ctx:set_option(option_name, value)
    local swt = env.switcher
    if swt ~= nil then
        if swt:is_auto_save(option_name) and swt.user_config ~= nil then
            swt.user_config:set_bool("var/option/"..option_name, value)
        end
    end
end

-- 開關狀態切換
local function toggle_switch(env, ctx, option)
    if not option then
        return
    end
    if option.type == core.switch_types.switch then
        -- 開關項: { type = 1, name = "", display = "" }
        local current_value = ctx:get_option(option.name)
        if current_value ~= nil then
            set_option(env, ctx, option.name, not current_value)
        end
    elseif option.type == core.switch_types.radio then
        -- 單選項: { type = 2, states = {{name="", display=""}, {}} }
        for i, op in ipairs(option.states) do
            local value = ctx:get_option(op.name)
            if value then
                -- 關閉當前選項, 開啓下一選項
                set_option(env, ctx, op.name, not value)
                set_option(env, ctx, option.states[i%#option.states+1].name, value)
                break
            end
        end
    end
end

-- 執行開關同步
local function sync_switches(env, ctx, key_event)
    if env.sync_at < core.sync_at then
        env.sync_at = core.sync_at
        -- 當總線更新時間比會話晚時, 將總線值同步到會話中
        for op_name, value in pairs(core.sync_bus.switches) do
            if env.sync_options[op_name] ~= value then
                env.sync_options[op_name] = value
                if not ctx:get_option("unsync_"..op_name) and ctx:get_option(op_name) ~= value then
                    ctx:set_option(op_name, value)
                end
            end
        end
    end
end

-- 提交候選文本, 並刷新輸入串
local function commit_text(env, ctx, text, input)
    ctx:clear()
    env.engine:commit_text(text)
    ctx:push_input(input)
end

-- 處理開關項調整
local function handle_switch(env, ctx, idx)
    -- 清理預輸入串, 达到調整後複位爲無輸入編碼的效果
    -- ctx:clear()
    toggle_switch(env, ctx, core.switch_options[idx+1])
    return kAccepted
end

-- 處理頂字
local function handle_push(env, ctx, ch)
    if core.single_smyh_seg(ctx.input) and ((ch == cZ or ch == cSC) or string.match(ctx.input, "[a-y][z;][z;]")) then
        if ch ~= cSC then
            -- 單字Z鍵頂, 加重複上屏; 或雙分號一簡詞任意鍵頂
            -- 提交當前候選
            ctx:commit()
            -- 字符 'z' 插入輸入串
            ctx:push_input(string.char(ch))
            return kAccepted
        else
            -- 分號頂, 空碼卽可, 無須處理
            return kNoop
        end
    elseif core.valid_smyh_input(ctx.input) then
        -- 輸入串分詞列表
        local code_segs, remain = core.get_code_segs(ctx.input)

        -- 純單字模式
        if env.option[core.switch_names.single_char] and #code_segs == 1 and #remain == 1 then
            local cands = core.query_cand_list(core.base_mem, code_segs)
            if #cands ~= 0 then
                ctx:clear()
                env.engine:commit_text(cands[1])
                ctx:push_input(remain..string.char(ch))
            end
            return kAccepted
        end

        if #remain ~= 0 then
            return kNoop
        end

        if ch == cZ or ch == cSC then
            -- 查詢全碼候選
            local entries = core.dict_lookup(core.base_mem, ctx.input, 2)
            if #entries > 1 then
                -- 全碼多重候選
                ctx:clear()
                env.engine:commit_text(entries[2].text)
                return kAccepted
            elseif #entries == 0 then
                -- 全碼無候選
                local cands = core.query_cand_list(core.base_mem, code_segs)
                ctx:clear()
                -- 延迟串逐次上屏, 以便Z重複上屏單字
                for _, cand in ipairs(cands) do
                    if #cand ~= 0 then
                        env.engine:commit_text(cand)
                    end
                end
                if ch == cZ then
                    -- Z鍵重複上屏
                    ctx:push_input(string.char(ch))
                    return kAccepted
                else
                    return kNoop
                end
            end

            -- 全碼唯一候選, 打斷施法
            local cands, remain = core.query_cand_list(core.base_mem, code_segs, true)
            if #cands > 1 then
                local text = table.concat(cands, "", 1, #cands-1)
                commit_text(env, ctx, text, remain)
                return kAccepted
            end
            return kNoop
        else
            -- 頂字
            local cands, remain = core.query_cand_list(core.base_mem, code_segs)
            if #cands > 1 then
                local text = table.concat(cands, "", 1, #cands-1)
                commit_text(env, ctx, text, remain..string.char(ch))
                return kAccepted
            end
            return kNoop
        end

        return kNoop
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
    ctx:pop_input(#remain)
    return kAccepted
end

function processor.init(env)
    if Switcher ~= nil then
        env.switcher = Switcher(env.engine)
    end

    -- 讀取配置項
    env.config = {}
    env.config.sync_options = core.parse_conf_str_list(env, "sync_options")
    env.config.sync_options.synced_at = 0

    -- 讀取需要同步的開關項列表
    env.sync_at = 0
    env.sync_options = {}
    for _, op_name in ipairs(env.config.sync_options) do
        env.sync_options[op_name] = true
    end
    -- 注册回調
    env.engine.context.option_update_notifier:connect(function(ctx, op_name)
        if env.sync_options[op_name] ~= nil then
            -- 當選項在同步列表中時, 將變更同步到總線
            local value = ctx:get_option(op_name)
            if env.sync_at == 0 and core.sync_at ~= 0 and core.sync_bus.switches[op_name] ~= nil then
                -- 當前會話未同步過, 且總線有值, 可能是由 reset 觸發
            elseif ctx:get_option("unsync_"..op_name) then
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
    local handler = core.get_switch_handler(env, core.switch_names.single_char)
    -- 初始化爲選項實際值, 如果設置了 reset, 則會再次觸發 handler
    handler(env.engine.context, core.switch_names.single_char)
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
    if ctx.input == core.helper_code then
        -- 開關管理
        local idx = select_index(key_event, env)
        if ch == cSp or ch == cRt then
            ctx:clear()
            return kAccepted
        elseif idx >= 0 then
            return handle_switch(env, ctx, idx)
        else
            return kNoop
        end
    elseif ch >= cA and ch <= cZ or ch == cSC then
        -- 按鍵在 'a'~'z' 之間, 或按鍵是分號
        return handle_push(env, ctx, ch)
    elseif ch == cRt then
        -- 按鍵是回車鍵
        return handle_clean(env, ctx, ch)
    end

    return kNoop
end

function processor.fini(env)
    env.switcher = nil
    env.option = nil
end

return processor
