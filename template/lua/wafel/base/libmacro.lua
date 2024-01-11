---wafel 自定義宏核心庫
local libmacro = {}

local libos = require("wafel.base.libos")
local librime = require("wafel.base.librime")

---@class Macro
---@field hijack? boolean
---@field display fun(self: self, env: Env, ctx: Context, args: string[]): string
---@field trigger fun(self: self, env: Env, ctx: Context, args: string[])
local _Macro

---@type Switcher|nil
local switcher

---設置開關狀態, 並更新保存的配置值
---@param env Env
---@param ctx Context
---@param option_name string
---@param value boolean
local function set_option(env, ctx, option_name, value)
    ctx:set_option(option_name, value)
    if not switcher then
        switcher = librime.New.Switcher(env.engine)
    end
    if switcher then
        if switcher:is_auto_save(option_name) and switcher.user_config ~= nil then
            switcher.user_config:set_bool("var/option/" .. option_name, value)
        end
    end
end

-- 下文的 new_tip, new_switch, new_radio 等是目前已實現的宏類型
-- 其返回類型統一定義爲:
-- {
--   display = function(self, env, ctx) ... end -> string
--   trigger = function(self, env, ctx) ... end
-- }
-- 其中:
-- display() 爲該宏在候選欄中顯示的效果
-- trigger() 爲該宏被選中時, 執行的操作

---提示語或快捷短語
---@param name string 候選提示詞
---@param text string 候選上屏字符
---@return Macro
function libmacro.new_tip(name, text)
    ---@type Macro
    return {
        ---@diagnostic disable-next-line: unused-local
        display = function(self, env, ctx)
            return #name ~= 0 and name or text
        end,
        ---@diagnostic disable-next-line: unused-local
        trigger = function(self, env, ctx)
            if #text ~= 0 then
                env.engine:commit_text(text)
            end
            ctx:clear()
        end,
    }
end

---顯示開關狀態, 並在選中時切換狀態
---@param name string 開關名稱
---@param states string[] 開關狀態爲 關 和 開 時的顯示效果
---@return Macro
function libmacro.new_switch(name, states)
    ---@type Macro
    return {
        ---@diagnostic disable-next-line: unused-local
        display = function(self, env, ctx)
            local current_value = ctx:get_option(name)
            local state
            if current_value then
                state = states[2] or "開"
            else
                state = states[1] or "關"
            end
            return state
        end,
        ---@diagnostic disable-next-line: unused-local
        trigger = function(self, env, ctx)
            local current_value = ctx:get_option(name)
            if current_value ~= nil then
                set_option(env, ctx, name, not current_value)
            end
        end,
    }
end

---顯示一組開關當前的狀態, 並在選中切換關閉當前項, 開啓下一項
---@param states { name: string, display: string }[] 各組開關的名稱及其開啓時的顯示效果
---@return Macro
function libmacro.new_radio(states)
    ---@type Macro
    return {
        ---@diagnostic disable-next-line: unused-local
        display = function(self, env, ctx)
            local state = ""
            for _, op in ipairs(states) do
                local value = ctx:get_option(op.name)
                if value then
                    state = op.display
                    break
                end
            end
            return state
        end,
        ---@diagnostic disable-next-line: unused-local
        trigger = function(self, env, ctx)
            for i, op in ipairs(states) do
                local value = ctx:get_option(op.name)
                if value then
                    -- 關閉當前選項, 開啓下一選項
                    set_option(env, ctx, op.name, not value)
                    set_option(env, ctx, states[i % #states + 1].name, value)
                    return
                end
            end
            -- 全都没開, 那就開一下第一個吧
            set_option(env, ctx, states[1].name, true)
        end,
    }
end

local cmd_template = "__macrowrapper() { %s ; }; __macrowrapper %s <<<''"

---@param cmd string
---@param args string[]
local function get_cmd_fd(cmd, args)
    local cmdargs = {}
    for _, arg in ipairs(args) do
        table.insert(cmdargs, '"' .. arg .. '"')
    end
    return io.popen(string.format(cmd_template, cmd, table.concat(cmdargs, " ")), "r")
end

---Shell 命令, 僅支持 Linux/Mac 系統, 其他平臺可通過 lua 宏自行擴展
---@param name string 非空時顯示爲候選文本, 否则顯示實時執行結果
---@param cmd string 待執行的命令内容
---@param commit_text boolean 爲 true 時, 命令執行結果上屏, 否则僅執行
---@param hijack? boolean
---@return Macro
function libmacro.new_shell(name, cmd, commit_text, hijack)
    if not libos.os:android() and not libos.os:linux() and not libos.os:darwin() then
        return libmacro.new_tip(name, cmd)
    end

    ---@type Macro
    return {
        hijack = hijack,
        ---@diagnostic disable-next-line: unused-local
        display = function(self, env, ctx, args)
            return #name ~= 0 and name or commit_text and get_cmd_fd(cmd, args):read("a")
        end,
        ---@diagnostic disable-next-line: unused-local
        trigger = function(self, env, ctx, args)
            local fd = get_cmd_fd(cmd, args)
            if commit_text then
                local t = fd:read("a")
                fd:close()
                if #t ~= 0 then
                    env.engine:commit_text(t)
                end
            end
            ctx:clear()
        end,
    }
end

---Evaluate 宏, 執行給定的 lua 函數
---@param name string 非空時顯示爲候選文本, 否则顯示實時調用結果
---@param func fun(args: string[], env: Env): string 待調用的 lua 函數
---@param hijack? boolean
---@return Macro
function libmacro.new_func(name, func, hijack)
    ---@type Macro
    return {
        hijack = hijack,
        ---@diagnostic disable-next-line: unused-local
        display = function(self, env, ctx, args)
            if #name ~= 0 then
                return name
            else
                return func(args, env)
            end
        end,
        ---@diagnostic disable-next-line: unused-local
        trigger = function(self, env, ctx, args)
            local res = func(args, env)
            if #res ~= 0 then
                env.engine:commit_text(res)
            end
            ctx:clear()
        end,
    }
end

return libmacro
