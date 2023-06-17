local processor = {}
local core = require("smyh.core")

-- 讀取 schema.yaml 開關設置:
local single_char_option_name = "single_char"

local kRejected = 0 -- 拒: 不作響應, 由操作系統做默認處理
local kAccepted = 1 -- 收: 由rime響應該按鍵
local kNoop     = 2 -- 無: 請下一個processor繼續看

local cA  = string.byte("a") -- 字符: 'a'
local cZ  = string.byte("z") -- 字符: 'z'
local cSC = string.byte(";") -- 字符: ';'
local cVS = string.byte("|") -- 字符: '|'

-- 提交候選文本, 並刷新輸入串
local function commit_text(env, ctx, text, input)
    ctx:clear()
    env.engine:commit_text(text)
    ctx:push_input(input)
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
        if env.option.single_char and #code_segs == 1 and #remain == 1 then
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
    local option = {}
    env.option = option
    local handler = function(ctx, name)
        -- 通知回調, 當改變選項值時更新暫存的值
        if name == single_char_option_name then
            option.single_char = ctx:get_option(name)
            if option.single_char == nil then
                -- 當選項不存在時默認爲啟用狀態
                option.single_char = true
            end
        end
    end
    -- 初始化爲選項實際值, 如果設置了 reset, 則會再次觸發 handler
    handler(env.engine.context, single_char_option_name)
    -- 注册通知回調
    env.engine.context.option_update_notifier:connect(handler)
end

function processor.func(key_event, env)
    if key_event:release() or key_event:alt() then
        -- 不是我關注的鍵按下事件, 棄之
        return kNoop
    end

    local ctx = env.engine.context
    if #ctx.input == 0 then
        -- 當前無輸入, 略之
        return kNoop
    end

    local ch = key_event.keycode
    if ch >= cA and ch <= cZ or ch == cSC then
        -- 按鍵在 'a'~'z' 之間, 或按鍵是分號
        return handle_push(env, ctx, ch)
    elseif ch == cVS then
        -- 按鍵是 shift+'\', 卽竪線
        return handle_clean(env, ctx, ch)
    end

    return kNoop
end

function processor.fini(env)
    env.option = nil
end

return processor
