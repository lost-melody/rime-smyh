---wafel 自定義宏核心庫
local libmacro = {}

local libos = require("wafel.base.libos")

---@class Macro
---@field display fun(self: self, env: Env, ctx: Context, args: string[]): string
---@field trigger fun(self: self, env: Env, ctx: Context, args: string[])
local _Macro

---宏類型枚舉
libmacro.macro_types = {
    tip = "tip",
    switch = "switch",
    radio = "radio",
    shell = "shell",
    eval = "eval",
}

---設置開關狀態, 並更新保存的配置值
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
--   display = function(self, env, ctx) ... end -> string
--   trigger = function(self, env, ctx) ... end
-- }
-- 其中:
-- type 字段僅起到標識作用
-- name 字段亦非必須
-- display() 爲該宏在候選欄中顯示的效果, 通常 name 非空時直接返回 name 的值
-- trigger() 爲該宏被選中時, 上屏的文本内容, 返回空卽不上屏

---提示語或快捷短語
---顯示爲 name, 上屏爲 text
---@param name string
---@return Macro
function libmacro.new_tip(name, text)
    local tip = {
        type = libmacro.macro_types.tip,
        name = name,
        text = text,
    }

    function tip:display(env, ctx)
        return #self.name ~= 0 and self.name or self.text
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
---@return Macro
function libmacro.new_switch(name, states)
    local switch = {
        type = libmacro.macro_types.switch,
        name = name,
        states = states,
    }

    function switch:display(env, ctx)
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
---@return Macro
function libmacro.new_radio(states)
    local radio = {
        type = libmacro.macro_types.radio,
        states = states,
    }

    function radio:display(env, ctx)
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
---@return Macro
function libmacro.new_shell(name, cmd, text)
    if not libos.os:android() and not libos.os:linux() and not libos.os:darwin() then
        return libmacro.new_tip(name, cmd)
    end

    local template = "__macrowrapper() { %s ; }; __macrowrapper %s <<<''"
    local function get_fd(args)
        local cmdargs = {}
        for _, arg in ipairs(args) do
            table.insert(cmdargs, '"' .. arg .. '"')
        end
        return io.popen(string.format(template, cmd, table.concat(cmdargs, " ")), "r")
    end

    local shell = {
        type = libmacro.macro_types.tip,
        name = name,
        text = text,
    }

    function shell:display(env, ctx, args)
        return #self.name ~= 0 and self.name or self.text and get_fd(args):read("a")
    end

    function shell:trigger(env, ctx, args)
        local fd = get_fd(args)
        if self.text then
            local t = fd:read("a")
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
---@return Macro
function libmacro.new_eval(name, expr)
    local f = load(expr)
    if not f then
        return nil
    end

    local eval = {
        type = libmacro.macro_types.eval,
        name = name,
        expr = f,
    }

    function eval:get_text(args, env, getter)
        if type(self.expr) == "function" then
            local res = self.expr(args, env)
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
            res = self.expr(args, env)
        elseif type(self.expr) == "table" then
            local get_text = self.expr[getter]
            res = type(get_text) == "function" and get_text(self.expr, args, env) or nil
        end
        return type(res) == "string" and res or ""
    end

    function eval:display(env, ctx, args)
        if #self.name ~= 0 then
            return self.name
        else
            local _, res = pcall(self.get_text, self, args, env, "peek")
            return res
        end
    end

    function eval:trigger(env, ctx, args)
        local ok, res = pcall(self.get_text, self, args, env, "eval")
        if ok and #res ~= 0 then
            env.engine:commit_text(res)
        end
        ctx:clear()
    end

    return eval
end

return libmacro
