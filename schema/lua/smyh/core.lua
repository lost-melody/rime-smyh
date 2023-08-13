local core = {}

-- librime-lua: https://github.com/hchunhui/librime-lua
-- wiki: https://github.com/hchunhui/librime-lua/wiki/Scripting

-- 由translator記録輸入串, 傳遞給filter
core.input_code = ''
-- 由translator計算暫存串, 傳遞給filter
core.stashed_text = ''
-- 由translator初始化基础碼表數據
core.base_mem = nil
-- 附加官宇詞庫
core.full_mem = nil

-- 消息同步: 更新時間
core.sync_at = 0
-- 消息同步: 總線
core.sync_bus = {
    switches = {}, -- 開關狀態
}

-- 宏類型枚舉
core.macro_types = {
    tip    = "tip",
    switch = "switch",
    radio  = "radio",
    shell  = "shell",
    eval   = "eval",
}

-- 開關枚舉
core.switch_names = {
    single_char   = "single_char",
    full_word     = "full.word",
    full_char     = "full.char",
    full_off      = "full.off",
    embeded_cands = "embeded_cands",
    smyh_tc       = "smyh_tc"
}

-- 設置開關狀態, 並更新保存的配置值
local function set_option(env, ctx, option_name, value)
    ctx:set_option(option_name, value)
    local swt = env.switcher
    if swt ~= nil then
        if swt:is_auto_save(option_name) and swt.user_config ~= nil then
            swt.user_config:set_bool("var/option/" .. option_name, value)
        end
    end
end

---@param name string
local function new_tip(name, text)
    local tip = {
        type = core.macro_types.tip,
        name = name,
        text = text,
    }
    function tip:display(ctx)
        return self.name
    end

    function tip:trigger(env, ctx)
        if #text ~= 0 then
            env.engine:commit_text(text)
        end
        ctx:clear()
    end

    return tip
end

---新開關
---@param name string
---@param states table
local function new_switch(name, states)
    local switch = {
        type = core.macro_types.switch,
        name = name,
        states = states,
    }
    function switch:display(ctx)
        local state = ""
        local current_value = ctx:get_option(self.name)
        if current_value then
            state = self.states[2]
        else
            state = self.states[1]
        end
        return state
    end

    function switch:trigger(env, ctx)
        local current_value = ctx:get_option(self.name)
        if current_value ~= nil then
            set_option(env, ctx, self.name, not current_value)
        end
    end

    return switch
end

---新單選
---@param states table
local function new_radio(states)
    local radio = {
        type   = core.macro_types.radio,
        states = states,
    }
    function radio:display(ctx)
        local state = ""
        for _, op in ipairs(self.states) do
            local value = ctx:get_option(op.name)
            if value then
                state = op.display
                break
            end
        end
        return state
    end

    function radio:trigger(env, ctx)
        for i, op in ipairs(self.states) do
            local value = ctx:get_option(op.name)
            if value then
                -- 關閉當前選項, 開啓下一選項
                set_option(env, ctx, op.name, not value)
                set_option(env, ctx, self.states[i % #self.states + 1].name, value)
                return
            end
        end
        -- 全都没開, 那就開一下第一個吧
        set_option(env, ctx, self.states[1].name, true)
    end

    return radio
end

---@param name string
---@param cmd string
---@param text boolean
local function new_shell(name, cmd, text)
    local shell = {
        type = core.macro_types.tip,
        name = name,
        cmd  = cmd,
    }
    function shell:display(ctx)
        return self.name
    end

    function shell:trigger(env, ctx)
        if text then
            local t = io.popen(cmd):read('a')
            t = string.gsub(string.gsub(t, "^%s+", ""), "%s+$", "")
            if #t ~= 0 then
                env.engine:commit_text(t)
            end
        else
            io.popen(cmd)
        end
        ctx:clear()
    end

    return shell
end

local function new_eval(name, expr)
    local f = load(expr)
    local function get_text()
        local text = f and f()
        return text and type(text) == "string" and #text ~= 0 and text or ""
    end
    local eval = {
        type = core.macro_types.eval,
        name = name,
        get_text = get_text,
    }
    function eval:display(ctx)
        return #self.name ~= 0 and self.name or self.get_text()
    end

    function eval:trigger(env, ctx)
        local text = self.get_text()
        if #text ~= 0 then
            env.engine:commit_text(text)
        end
        ctx:clear()
    end

    return eval
end

-- ######## 工具函数 ########

-- 從方案配置中讀取布爾值
function core.parse_conf_bool(env, path)
    local value = env.engine.schema.config:get_bool(env.name_space .. "/" .. path)
    return value and true or false
end

-- 從方案配置中讀取字符串
function core.parse_conf_str(env, path, default)
    local str = env.engine.schema.config:get_string(env.name_space .. "/" .. path)
    if not str and default and #default ~= 0 then
        str = default
    end
    return str
end

-- 從方案配置中讀取字符串列表
function core.parse_conf_str_list(env, path, default)
    local list = {}
    local conf_list = env.engine.schema.config:get_list(env.name_space .. "/" .. path)
    if conf_list then
        for i = 0, conf_list.size - 1 do
            table.insert(list, conf_list:get_value_at(i):get_string())
        end
    elseif default then
        list = default
    end
    return list
end

-- 從方案配置中讀取宏配置
function core.parse_conf_macro_list(env)
    local macros = {}
    local macro_map = env.engine.schema.config:get_map(env.name_space .. "/macros")
    -- macros:
    for _, key in ipairs(macro_map and macro_map:keys() or {}) do
        local cands = {}
        local cand_list = macro_map:get(key):get_list() or { size = 0 }
        -- macros/help:
        for i = 0, cand_list.size - 1 do
            local key_map = cand_list:get_at(i):get_map()
            -- macros/help[1]/type:
            local type = key_map and key_map:has_key("type") and key_map:get_value("type"):get_string() or ""
            if type == core.macro_types.tip then
                -- {type: tip, name: foo}
                if key_map:has_key("name") then
                    local name = key_map:get_value("name"):get_string()
                    local text = key_map:has_key("text") and key_map:get_value("text"):get_string() or ""
                    table.insert(cands, new_tip(name, text))
                end
            elseif type == core.macro_types.switch then
                -- {type: switch, name: single_char, states: []}
                if key_map:has_key("name") and key_map:has_key("states") then
                    local name = key_map:get_value("name"):get_string()
                    local states = {}
                    local state_list = key_map:get("states"):get_list() or { size = 0 }
                    for idx = 0, state_list.size - 1 do
                        table.insert(states, state_list:get_value_at(idx):get_string())
                    end
                    if #name ~= 0 and #states > 1 then
                        table.insert(cands, new_switch(name, states))
                    end
                end
            elseif type == core.macro_types.radio then
                -- {type: radio, names: [], states: []}
                if key_map:has_key("names") and key_map:has_key("states") then
                    local names, states = {}, {}
                    local name_list = key_map:get("names"):get_list() or { size = 0 }
                    for idx = 0, name_list.size - 1 do
                        table.insert(names, name_list:get_value_at(idx):get_string())
                    end
                    local state_list = key_map:get("states"):get_list() or { size = 0 }
                    for idx = 0, state_list.size - 1 do
                        table.insert(states, state_list:get_value_at(idx):get_string())
                    end
                    if #names > 1 and #names == #states then
                        local radio = {}
                        for idx, name in ipairs(names) do
                            if #name ~= 0 and #states[idx] ~= 0 then
                                table.insert(radio, { name = name, display = states[idx] })
                            end
                        end
                        table.insert(cands, new_radio(radio))
                    end
                end
            elseif type == core.macro_types.shell then
                -- {type: shell, name: foo, cmd: "echo hello"}
                if key_map:has_key("name") and key_map:has_key("cmd") then
                    local name = key_map:get_value("name"):get_string()
                    local cmd = key_map:get_value("cmd"):get_string()
                    local text = key_map:has_key("text") and key_map:get_value("text"):get_bool() or false
                    if #name ~= 0 and #cmd ~= 0 then
                        table.insert(cands, new_shell(name, cmd, text))
                    end
                end
            elseif type == core.macro_types.eval then
                -- {type: eval, name: foo, expr: "os.date()"}
                if key_map:has_key("expr") then
                    local name = key_map:has_key("name") and key_map:get_value("name"):get_string() or ""
                    local expr = key_map:get_value("expr"):get_string()
                    if #expr ~= 0 then
                        table.insert(cands, new_eval(name, expr))
                    end
                end
            end
        end
        if #cands ~= 0 then
            macros[key] = cands
        end
    end
    return macros
end

-- 從方案配置中讀取功能鍵配置
function core.parse_conf_funckeys(env)
    local funckeys = {
        fullci     = {},
        ["break"]  = {},
        ["repeat"] = {},
        clearact   = {},
        macro      = {},
    }
    local keys_map = env.engine.schema.config:get_map(env.name_space .. "/funckeys")
    for _, key in ipairs(keys_map and keys_map:keys() or {}) do
        if funckeys[key] then
            local char_list = keys_map:get(key):get_list() or { size = 0 }
            for i = 0, char_list.size - 1 do
                funckeys[key][char_list:get_value_at(i):get_int() or 0] = true
            end
        end
    end
    return funckeys
end

-- 是否單個編碼段, 如: "abc", "ab_", "a;", "a_"
function core.single_smyh_seg(input)
    return string.match(input, "^[a-z][ ;]$")       -- 一簡
        or string.match(input, "^[a-z][a-z] ;$")    -- 二簡
        or string.match(input, "^[a-z][a-z][a-z]$") -- 單字全碼
end

-- 是否合法宇三分詞串
function core.valid_smyh_input(input)
    -- 輸入串完全由 [a-z_;] 構成, 且不以 [_;] 開頭
    return string.match(input, "^[a-z ;]*$") and not string.match(input, "^[ ;]")
end

-- 構造開關變更回調函數
---@param option_names table
function core.get_switch_handler(env, option_names)
    env.option = env.option or {}
    local option = env.option
    local name_set = {}
    if option_names and #option_names ~= 0 then
        for _, name in ipairs(option_names) do
            name_set[name] = true
        end
    end
    -- 返回通知回調, 當改變選項值時更新暫存的值
    ---@param name string
    return function(ctx, name)
        if name_set[name] then
            option[name] = ctx:get_option(name)
            if option[name] == nil then
                -- 當選項不存在時默認爲啟用狀態
                option[name] = true
            end
        end
    end
end

-- 计算分词列表
-- "dkdqgxfvt;" -> ["dkd","qgx","fvt"], ";"
-- "d;nua"     -> ["d;", "nua"]
function core.get_code_segs(input)
    local code_segs = {}
    while string.len(input) ~= 0 do
        if string.match(string.sub(input, 1, 2), "[a-z][ ;]") then
            -- 匹配到一简
            table.insert(code_segs, string.sub(input, 1, 2))
            input = string.sub(input, 3)
        elseif string.match(string.sub(input, 1, 3), "[a-z][a-z][a-z ;]") then
            -- 匹配到全码或二简
            table.insert(code_segs, string.sub(input, 1, 3))
            input = string.sub(input, 4)
        else
            -- 不完整或不合法分词输入串
            return code_segs, input
        end
    end
    return code_segs, input
end

-- 查询编码对应候选列表
-- "dkd" -> ["南", "電"]
function core.dict_lookup(mem, code, count, comp)
    -- 是否补全编码
    count = count or 1
    comp = comp or false
    local result = {}
    if not mem then
        return result
    end
    if mem:dict_lookup(code, comp, count) then
        -- 根據 entry.text 聚合去重
        local res_set = {}
        for entry in mem:iter_dict() do
            local exist = res_set[entry.text]
            if not exist then
                res_set[entry.text] = entry
                table.insert(result, entry)
            elseif #exist.comment == 0 then
                exist.comment = entry.comment
            end
        end
    end
    return result
end

-- 查詢分詞首選列表
function core.query_first_cand_list(mem, code_segs)
    local cand_list = {}
    for _, code in ipairs(code_segs) do
        local entries = core.dict_lookup(mem, code)
        table.insert(cand_list, entries[1] and entries[1].text or "")
    end
    return cand_list
end

-- 最大匹配查詢分詞候選列表
-- ["dkd", "qgx", "fvt"] -> ["電動", "杨"]
-- ["dkd", "qgx"]        -> ["南", "動"]
function core.query_cand_list(mem, code_segs, skipfull)
    local index = 1
    local cand_list = {}
    local code = table.concat(code_segs, "", index)
    while index <= #code_segs do
        -- 最大匹配
        for viewport = #code_segs, index, -1 do
            if skipfull and viewport - index + 1 >= #code_segs and #code_segs > 1 then
                -- continue
            else
                code = table.concat(code_segs, "", index, viewport)
                local entries = core.dict_lookup(mem, code)
                if entries[1] then
                    -- 當前viewport有候選, 擇之並進入下一輪
                    table.insert(cand_list, entries[1].text)
                    index = viewport + 1
                    break
                elseif viewport == index then
                    -- 最小viewport無候選, 以空串作爲候選
                    table.insert(cand_list, "")
                    index = viewport + 1
                    break
                end
            end
        end
    end
    -- 返回候選字列表及末候選編碼
    return cand_list, code
end

return core
