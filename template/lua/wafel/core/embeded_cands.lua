local embeded_cands = {}

local bus = require("wafel.core.bus")
local librime = require("wafel.base.librime")
local reg = require("wafel.core.reg")

---@type (fun(dict: table<string, string>): string), (fun(dict: table<string, string>): string)
local first_formatter, next_formatter

---@type WafelFilter
local function do_nothing(iter, _, yield)
    for cand in iter() do
        yield(cand)
    end
end

---@param format string
---@return fun(dict: table<string, string>): string
local function compile_formatter(format)
    -- `"${Stash}[${候選}${Seq}]${Code}${Comment}"`
    local pattern = "%$%{[^{}]+%}"

    -- `"%s[%s%s]%s%s"`
    local template = string.gsub(format, pattern, "%%s")

    ---@type string[]
    -- `{ "${Stash}", "${...}", "${...}", ... }`
    local verbs = {}
    for s in string.gmatch(format, pattern) do
        table.insert(verbs, s)
    end

    return function(dict)
        ---@type string[]
        -- `{ a1, a2, ... }`
        local args = {}
        for _, pat in ipairs(verbs) do
            table.insert(args, dict[pat] or "")
        end
        return string.format(template, table.unpack(args))
    end
end

---@param _ Env
---@param index integer
---@param stash string
---@param text string
---@param digested boolean
local function render_stash(_, index, stash, text, digested)
    if string.len(stash) ~= 0 and string.match(text, "^" .. stash) then
        if index == 1 then
            -- 首選含延迟串, 原樣返回
            digested = true
            stash, text = stash, string.sub(text, string.len(stash) + 1)
        elseif not digested then
            -- 首選不含延迟串, 其他候選含延迟串, 標記之
            digested = true
            stash, text = "[" .. stash .. "]", string.sub(text, string.len(stash) + 1)
        else
            -- 非首個候選, 延迟串標記爲空
            local placeholder = string.gsub(reg.options.embeded_cands.stash_placeholder, "%${Stash}", stash)
            stash, text = "", placeholder .. string.sub(text, string.len(stash) + 1)
        end
    else
        -- 普通候選, 延迟串標記爲空
        stash, text = "", text
    end
    return stash, text, digested
end

---@param comment string
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

---@param env Env
---@param index integer
---@param code string
---@param stash string
---@param text string
---@param comment string
---@param digested boolean
local function render_cand(env, index, code, stash, text, comment, digested)
    first_formatter = first_formatter or compile_formatter(reg.options.embeded_cands.first_format)
    next_formatter = next_formatter or compile_formatter(reg.options.embeded_cands.next_format)

    local formatter = index == 1 and first_formatter or next_formatter
    stash, text, digested = render_stash(env, index, stash, text, digested)
    if index == 1 and text == "" then
        return "", digested
    end
    comment = render_comment(comment)
    local cand = formatter({
        ["${Seq}"] = reg.options.embeded_cands.index_indicators[index],
        ["${Code}"] = code,
        ["${Stash}"] = stash,
        ["${候選}"] = text,
        ["${Comment}"] = comment,
    })
    return cand, digested
end

---@type WafelFilter
local function render_embeded(iter, env, yield)
    local page_size = env.engine.schema.page_size
    ---@type Candidate[], string[]
    local cand_list, page_rendered = {}, {}
    ---@type Candidate|nil, string
    local first, preedit = nil, ""

    -- 活動輸入串
    local input_code = ""
    if #bus.input.code ~= 0 then
        input_code = bus.input.code
    else
        input_code = bus.input.init_code
    end

    local digested = false
    local index = 0
    local get_next = iter
    local next = get_next()
    while next do
        index = index % page_size + 1
        local cand = librime.New.Candidate(next.type, next.start, next._end, next.text, next.comment)
        cand.quality = next.quality
        cand.preedit = next.preedit

        if index == 1 then
            first = cand
        end

        -- 帶有暫存串的候選合併同類項
        preedit, digested =
            render_cand(env, index, input_code, table.concat(bus.stash.cands), cand.text, cand.comment, digested)

        -- 存入候選
        table.insert(cand_list, cand)
        if preedit ~= "" then
            table.insert(page_rendered, preedit)
        end

        next = get_next()
        -- 遍歷完一頁候選後, 刷新預編輯文本
        if index == page_size or not next then
            first.preedit = table.concat(page_rendered, reg.options.embeded_cands.separator)
            for _, c in ipairs(cand_list) do
                yield(c)
            end
            first, preedit = nil, ""
            cand_list, page_rendered = {}, {}
            digested = false
        end
    end
end

---@type WafelFilter
function embeded_cands.filter(iter, env, yield)
    if not reg.switches[reg.options.embeded_cands.option_name] then
        do_nothing(iter, env, yield)
    else
        render_embeded(iter, env, yield)
    end
end

return embeded_cands
