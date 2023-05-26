-- 将要被返回的過濾器對象
local embeded_cands_filter = {}
local core = require("smyh.core")

--[[
# xxx.schema.yaml
switches:
  - name: embeded_cands
    states: [ 普通, 嵌入 ]
    reset: 1
engine:
  filters:
    - lua_filter@*smyh.embeded_cands
key_binder:
  bindings:
    - { when: always, accept: "Control+Shift+E", toggle: embeded_cands }
--]]

local index_indicators = {"¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹", "⁰"}

-- 讀取 schema.yaml 開關設置:
local option_name = "embeded_cands"
local embeded_cands = nil

function embeded_cands_filter.init(env)
    local handler = function(ctx, name)
        -- 通知回調, 當改變選項值時更新暫存的值
        if name == option_name then
            embeded_cands = ctx:get_option(name)
            if embeded_cands == nil then
                -- 當選項不存在時默認爲啟用狀態
                embeded_cands = true
            end
        end
    end
    -- 初始化爲選項實際值, 如果設置了 reset, 則會再次觸發 handler
    handler(env.engine.context, option_name)
    -- 注册通知回調
    env.engine.context.option_update_notifier:connect(handler)
end

-- 過濾器
function embeded_cands_filter.func(input, env)
    if not embeded_cands then
        for cand in input:iter() do
            yield(cand)
        end
        return
    end

    -- 要顯示的候選數量
    local page_size = env.engine.schema.page_size
    -- 暫存當前頁候選, 然后批次送出
    local page_cands = {}
    -- 暫存索引, 首選和預編輯文本
    local index, first_cand, preedit = 0, nil, ""

    -- 迭代器
    local iter, obj = input:iter()
    -- 迭代由翻譯器輸入的候選列表
    local next = iter(obj)
    local first_stash = true
    while next do
        -- 頁索引自增, 滿足 1 <= index <= page_size
        index = index + 1
        -- 當前遍歷候選項
        local cand = next

        if index == 1 then
            -- 把首選捉出來
            first_cand = cand:get_genuine()
        end

        -- 活動輸入串
        local input_code = ""
        if string.len(core.input_code) == 0 then
            input_code = cand.preedit
        else
            input_code = core.input_code
        end

        -- 帶有暫存串的候選合併同類項
        local cand_text = cand.text
        local stash_len = string.len(core.stashed_text)
        if string.len(core.stashed_text) ~= 0 and string.sub(cand_text, 1, stash_len) == core.stashed_text then
            if index == 1 then
                first_stash = false
                -- "iwl"+"宇浩" => "宇[浩iwl]"
                preedit = core.stashed_text.."["..string.sub(cand_text, stash_len+1)..input_code.."]"
            elseif first_stash then
                first_stash = false
                -- "kjr"+"時間,峙沓" => "[時間kjr][峙]²沓"
                preedit = preedit.."["..core.stashed_text.."]"..index_indicators[index]..string.sub(cand_text, stash_len+1)
            else
                -- "kjr"+"時間,峙沓,峙間" => "[時間kjr][峙]²沓³間"
                preedit = preedit..index_indicators[index]..string.sub(cand_text, stash_len+1)
            end
        else
            if index == 1 then
                -- "kjr"+"時間" => "[時間kjr]"
                preedit = "["..cand_text..input_code.."]"
            elseif string.len(cand_text) > 0 then
                -- "kjr"+"沓,間" => "[沓kjr]²間"
                preedit = preedit..index_indicators[index]..cand_text
            end
        end

        -- 如果候選有提示且不以 "~" 開頭(补全提示), 識别爲反查提示
        if string.len(cand.comment) ~= 0 and string.sub(cand.comment, 1, 1) ~= "~" then
            preedit = preedit..cand.comment
        end
        -- 存入首選
        table.insert(page_cands, cand)

        -- 遍歷完一頁候選後, 刷新預編輯文本
        if index == page_size then
            first_cand.preedit = preedit
            -- 将暫存的一頁候選批次送出
            for _, c in ipairs(page_cands) do
                yield(c)
            end
            -- 清空暫存
            first_cand, preedit = nil, ""
            page_cands = {}
        end

        -- 當前候選處理完畢, 查詢下一個
        next = iter(obj)

        -- 如果當前暫存候選不足page_size但没有更多候選, 則需要刷新預編輯並送出
        if not next and index < page_size then
            first_cand.preedit = preedit
            -- 将暫存的前三候選批次送出
            for _, c in ipairs(page_cands) do
                yield(c)
            end
            -- 清空暫存
            first_cand, preedit = nil, ""
            page_cands = {}
        end

        -- 下一頁, index歸零
        index = index % page_size
    end
end

function embeded_cands_filter.fini(env)
end

return embeded_cands_filter
