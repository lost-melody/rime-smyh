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


local _unix_supported
-- 是否支持 Unix 命令
function core.unix_supported()
    if _unix_supported == nil then
        local res
        _unix_supported, res = pcall(io.popen, "sleep 0")
        if _unix_supported and res then
            res:close()
        end
    end
    return _unix_supported
end

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


core.funckeys_map = {
    primary   = " a",
    secondary = " b",
    tertiary  = " c",
}

local funckeys_replacer = {
    a = "1",
    b = "2",
    c = "3",
}

local funckeys_restorer = {
    ["1"] = " a",
    ["2"] = " b",
    ["3"] = " c",
}

---@param input string
function core.input_replace_funckeys(input)
    return string.gsub(input, " ([a-c])", funckeys_replacer)
end

---@param input string
function core.input_restore_funckeys(input)
    return string.gsub(input, "([1-3])", funckeys_restorer)
end

-- 設置開關狀態, 並更新保存的配置值
local function set_option(env, ctx, option_name, value)
    ctx:set_option(option_name, value)
    local swt = env.switcher
    if swt then
        if swt:is_auto_save(option_name) and swt.user_config ~= nil then
            swt.user_config:set_bool("var/option/" .. option_name, value)
        end
    end
end


-- 下文的 new_tip, new_switch, new_radio 等是目前已實現的宏類型
-- 其返回類型統一定義爲:
-- {
--   type = "string",
--   name = "string",
--   display = function(self, ctx) ... end -> string
--   trigger = function(self, ctx) ... end
-- }
-- 其中:
-- type 字段僅起到標識作用
-- name 字段亦非必須
-- display() 爲該宏在候選欄中顯示的效果, 通常 name 非空時直接返回 name 的值
-- trigger() 爲該宏被選中時, 上屏的文本内容, 返回空卽不上屏

---提示語或快捷短語
---顯示爲 name, 上屏爲 text
---@param name string
local function new_tip(name, text)
    local tip = {
        type = core.macro_types.tip,
        name = name,
        text = text,
    }
    function tip:display(ctx)
        return #self.name ~= 0 and self.name or ""
    end

    function tip:trigger(env, ctx)
        if #text ~= 0 then
            env.engine:commit_text(text)
        end
        ctx:clear()
    end

    return tip
end

---開關
---顯示 name 開關當前的狀態, 並在選中切換狀態
---states 分别指定開關狀態爲 開 和 關 時的顯示效果
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

---單選
---顯示一組 names 開關當前的狀態, 並在選中切換關閉當前開啓項, 並打開下一項
---states 指定各組開關的 name 和當前開啓的開關時的顯示效果
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

---Shell 命令, 僅支持 Linux/Mac 系統, 其他平臺可通過下文提供的 eval 宏自行擴展
---name 非空時顯示其值, 爲空则顯示實時的 cmd 執行結果
---cmd 爲待執行的命令内容
---text 爲 true 時, 命令執行結果上屏, 否则僅執行
---@param name string
---@param cmd string
---@param text boolean
local function new_shell(name, cmd, text)
    if not core.unix_supported() then
        return nil
    end

    local template = "__macrowrapper() { %s ; }; __macrowrapper %s <<<''"
    local function get_fd(args)
        local cmdargs = {}
        for _, arg in ipairs(args) do
            table.insert(cmdargs, '"' .. arg .. '"')
        end
        return io.popen(string.format(template, cmd, table.concat(cmdargs, " ")), 'r')
    end

    local shell = {
        type = core.macro_types.tip,
        name = name,
        text = text,
    }

    function shell:display(ctx, args)
        return #self.name ~= 0 and self.name or self.text and get_fd(args):read('a')
    end

    function shell:trigger(env, ctx, args)
        local fd = get_fd(args)
        if self.text then
            local t = fd:read('a')
            fd:close()
            if #t ~= 0 then
                env.engine:commit_text(t)
            end
        end
        ctx:clear()
    end

    return shell
end

---Evaluate 宏, 執行給定的 lua 表達式
---name 非空時顯示其值, 否则顯示實時調用結果
---expr 必須 return 一個值, 其類型可以是 string, function 或 table
---返回 function 時, 該 function 接受一個 table 參數, 返回 string
---返回 table 時, 該 table 成員方法 peek 和 eval 接受 self 和 table 參數, 返回 string, 分别指定顯示效果和上屏文本
---@param name string
---@param expr string
local function new_eval(name, expr)
    local f = load(expr)
    if not f then
        return nil
    end

    local eval = {
        type = core.macro_types.eval,
        name = name,
        expr = f,
    }

    function eval:get_text(args, getter)
        if type(self.expr) == "function" then
            local res = self.expr(args)
            if type(res) == "string" then
                return res
            elseif type(res) == "function" or type(res) == "table" then
                self.expr = res
            else
                return ""
            end
        end

        local res
        if type(self.expr) == "function" then
            res = self.expr(args)
        elseif type(self.expr) == "table" then
            local get_text = self.expr[getter]
            res = type(get_text) == "function" and get_text(self.expr, args) or nil
        end
        return type(res) == "string" and res or ""
    end

    function eval:display(ctx, args)
        if #self.name ~= 0 then
            return self.name
        else
            local _, res = pcall(self.get_text, self, args, "peek")
            return res
        end
    end

    function eval:trigger(env, ctx, args)
        local ok, res = pcall(self.get_text, self, args, "eval")
        if ok and #res ~= 0 then
            env.engine:commit_text(res)
        end
        ctx:clear()
    end

    return eval
end


-- ######## 工具函数 ########

---@param input string
---@param keylist table
function core.get_macro_args(input, keylist)
    local sepset = ""
    for key in pairs(keylist) do
        -- only ascii keys
        sepset = key >= 0x20 and key <= 0x7f and sepset .. string.char(key) or sepset
    end
    -- matches "[^/]"
    local pattern = "[^" .. (#sepset ~= 0 and sepset or " ") .. "]*"
    local args = {}
    -- "echo/hello/world" -> "/hello", "/world"
    for str in string.gmatch(input, "/" .. pattern) do
        table.insert(args, string.sub(str, 2))
    end
    -- "echo/hello/world" -> "echo"
    return string.match(input, pattern) or "", args
end

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
                if key_map:has_key("name") or key_map:has_key("text") then
                    local name = key_map:has_key("name") and key_map:get_value("name"):get_string() or ""
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
                if key_map:has_key("cmd") and (key_map:has_key("name") or key_map:has_key("text")) then
                    local cmd = key_map:get_value("cmd"):get_string()
                    local name = key_map:has_key("name") and key_map:get_value("name"):get_string() or ""
                    local text = key_map:has_key("text") and key_map:get_value("text"):get_bool() or false
                    local hijack = key_map:has_key("hijack") and key_map:get_value("hijack"):get_bool() or false
                    if #cmd ~= 0 and (#name ~= 0 or text) then
                        table.insert(cands, new_shell(name, cmd, text))
                        cands.hijack = cands.hijack or hijack
                    end
                end
            elseif type == core.macro_types.eval then
                -- {type: eval, name: foo, expr: "os.date()"}
                if key_map:has_key("expr") then
                    local name = key_map:has_key("name") and key_map:get_value("name"):get_string() or ""
                    local expr = key_map:get_value("expr"):get_string()
                    local hijack = key_map:has_key("hijack") and key_map:get_value("hijack"):get_bool() or false
                    if #expr ~= 0 then
                        table.insert(cands, new_eval(name, expr))
                        cands.hijack = cands.hijack or hijack
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
        macro      = {},
        primary    = {},
        secondary  = {},
        tertiary   = {},
        fullci     = {},
        ["break"]  = {},
        ["repeat"] = {},
        clearact   = {},
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
    -- 輸入串完全由 [a-z_] 構成, 且不以 [_] 開頭
    return string.match(input, "^[a-z ]*$") and not string.match(input, "^[ ]")
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
    input = core.input_replace_funckeys(input)
    local code_segs = {}
    while string.len(input) ~= 0 do
        if string.match(string.sub(input, 1, 2), "[a-z][1-3]") then
            -- 匹配到一简
            table.insert(code_segs, string.sub(input, 1, 2))
            input = string.sub(input, 3)
        elseif string.match(string.sub(input, 1, 3), "[a-z][a-z][a-z1-3]") then
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
            -- 剩餘編碼大於一, 則不收
            if entry.remaining_code_length <= 1 then
                local exist = res_set[entry.text]
                -- 候選去重, 但未完成編碼提示取有
                if not exist then
                    res_set[entry.text] = entry
                    table.insert(result, entry)
                elseif #exist.comment == 0 then
                    exist.comment = entry.comment
                end
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
