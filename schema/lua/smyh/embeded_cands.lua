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

-- 首選/非首選格式定義
-- Stash: 延迟候選; Seq: 候選序號; Code: 編碼; 候選: 候選文本; Comment: 候選提示
local first_format = "Stash[候選Seq]CodeComment"
local next_format = "Stash候選SeqComment"
local separator = " "

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

-- 處理候選文本和延迟串
local function render_stashcand(seq, stash, text, digested)
    if string.len(stash) ~= 0 and string.match(text, "^"..stash) then
        if seq == 1 then
            -- 首選含延迟串, 原樣返回
            digested = true
            stash, text = stash, string.sub(text, string.len(stash)+1)
        elseif not digested then
            -- 首選不含延迟串, 其他候選含延迟串, 標記之
            digested = true
            stash, text = "["..stash.."]", string.sub(text, string.len(stash)+1)
        else
            -- 非首個候選, 延迟串標記爲空
            stash, text = "", string.sub(text, string.len(stash)+1)
        end
    else
        -- 普通候選, 延迟串標記爲空
        stash, text = "", text
    end
    return stash, text, digested
end

-- 渲染提示, 因爲提示經常有可能爲空, 抽取爲函數更昜操作
local function render_comment(comment)
    if string.match(comment, "^~") then
        -- 丟棄以"~"開頭的提示串, 這通常是補全提示
        comment = ""
    else
        -- 自定義提示串格式
        -- comment = "<"..comment..">"
    end
    return comment
end

-- 渲染單個候選項
local function render_cand(seq, code, stashed, text, comment, digested)
    local cand = ""
    -- 選擇渲染格式
    if seq == 1 then
        cand = first_format
    else
        cand = next_format
    end
    -- 渲染延迟串與候選文字
    stashed, text, digested = render_stashcand(seq, stashed, text, digested)
    if seq ~= 1 and text == "" then
        return "", digested
    end
    -- 渲染提示串
    comment = render_comment(comment)
    cand = string.gsub(cand, "Seq", index_indicators[seq])
    cand = string.gsub(cand, "Code", code)
    cand = string.gsub(cand, "Stash", stashed)
    cand = string.gsub(cand, "候選", text)
    cand = string.gsub(cand, "Comment", comment)
    return cand, digested
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
    local page_cands, page_rendered = {}, {}
    -- 暫存索引, 首選和預編輯文本
    local index, first_cand, preedit = 0, nil, ""
    local digested = false

    local function refresh_preedit()
        first_cand.preedit = table.concat(page_rendered, separator)
        -- 將暫存的一頁候選批次送出
        for _, c in ipairs(page_cands) do
            yield(c)
        end
        -- 清空暫存
        first_cand, preedit = nil, ""
        page_cands, page_rendered = {}, {}
        digested = false
    end

    -- 迭代器
    local iter, obj = input:iter()
    -- 迭代由翻譯器輸入的候選列表
    local next = iter(obj)
    -- local first_stash = true
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
        preedit, digested = render_cand(index, input_code, core.stashed_text, cand.text, cand.comment, digested)

        -- 存入候選
        table.insert(page_cands, cand)
        table.insert(page_rendered, preedit)

        -- 遍歷完一頁候選後, 刷新預編輯文本
        if index == page_size then
            refresh_preedit()
        end

        -- 當前候選處理完畢, 查詢下一個
        next = iter(obj)

        -- 如果當前暫存候選不足page_size但没有更多候選, 則需要刷新預編輯並送出
        if not next and index < page_size then
            refresh_preedit()
        end

        -- 下一頁, index歸零
        index = index % page_size
    end
end

function embeded_cands_filter.fini(env)
end

return embeded_cands_filter
