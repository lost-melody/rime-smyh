#!/bin/lua

---倉輸入法佈局配置生成器
---
---Author: 王牌餅乾
---GitHub: https://github.com/lost-melody

---滑動方向
---@enum Direction
local Dir = {
    up   = "up",
    down = "down",
}

---可用快捷指令類型
---@enum Command
local Cmd = {
    clear       = "重输",
    trad        = "繁简切换",
    eng         = "中英切换",
    head        = "行首",
    tail        = "行尾",
    second      = "次选上屏",
    third       = "三选上屏",
    last_schema = "上个输入方案",
    ret         = "换行",
    switcher    = "RimeSwitcher",
}

---預置鍵盤類型
---@enum KeyboardType
---
--- ```
--- Act.Keyboard(Kbd.num_ng)
--- Act.Keyboard(Kbd.custom:format("my_kbd"))
--- ```
---
local Kbd = {
    custom  = "custom(%s)",       -- 自定義鍵盤, 通過 `Keyboard` 對象的 `name` 字段檢索
    alpha   = "alphabetic",       -- 默認英文鍵盤
    symbol  = "classifySymbolic", -- 分類符號鍵盤
    chinese = "chinese",          -- 默認中文鍵盤
    chn_ng  = "chineseNineGrid",  -- 中文九宫格鍵盤
    num_ng  = "numericNineGrid",  -- 數字九宫格鍵盤
    emoji   = "emojis",           -- Emoji鍵盤
}

---YAML配置節點類型
---@enum NodeType
local NodeTypes = {
    Scalar = "Scalar",
    List   = "List",
    Map    = "Map",
}

---YAML配置節點
---@class Node
---@field type fun(self): NodeType
---@field render fun(self): string[]
---@field clone fun(self): Node
local _Node = {}

---YAML純數據節點
---@class Scalar: Node
---@field set fun(self, value: string): Scalar
---@field clone fun(self): Scalar

---構造純數據節點, 形如:
---
--- ```
--- key: value
--- ```
---
---@param val string|nil
---@return Scalar
local function Scalar(val)
    local scalar = { value = val or "\"\"" }

    ---@param value string
    function scalar:set(value)
        if type(value) ~= "string" then
            value = tostring(value)
        end
        self.value = value
        return self
    end

    ---@return NodeType
    function scalar:type()
        return NodeTypes.Scalar
    end

    ---@return string[]
    function scalar:render()
        return { string.format("%s", self.value) }
    end

    ---@return Scalar
    function scalar:clone()
        local s = Scalar()
        s:set(self.value)
        return s
    end

    return scalar
end

---YAML列表節點
---@class List: Node
---@field append fun(self, value: Node): List
---@field clone fun(self): List

---構造列表節點, 形如:
---
--- ```
--- key:
--- - value
--- - value
--- ```
---
---@param nodes Node[] | nil
---@return List
local function List(nodes)
    local list = {
        ---@type Node[]
        nodes = nodes or {},
    }

    ---@return List
    function list:append(node)
        table.insert(self.nodes, node)
        return self
    end

    ---@return NodeType
    function list:type()
        return NodeTypes.List
    end

    ---@return string[]
    function list:render()
        if #self.nodes == 0 then
            return {}
        end

        local res = {}
        for _, node in ipairs(self.nodes) do
            for i, line in ipairs(node:render()) do
                table.insert(res, string.format("%s%s", (i == 1 and "- " or "  "), line))
            end
        end
        return res
    end

    ---@return List
    function list:clone()
        local l = List()
        for _, v in ipairs(self.nodes) do
            l:append(v:clone())
        end
        return l
    end

    return list
end

---YAML字典節點
---@class Map: Node
---@field nodes { [string]: Node }
---@field set fun(self, key: string, value: Node): Map
---@field clone fun(self): Map

---構造字典節點, 形如:
---
--- ```
--- key:
---   key1: value1
---   key2: value2
--- ```
---
---@param nodes { [string]: Node } | nil
---@return Map
local function Map(nodes)
    local map = {
        ---@type { [string]: Node }
        nodes = nodes or {},
    }

    ---@return Map
    function map:set(key, node)
        self.nodes[key] = node
        return self
    end

    ---@return NodeType
    function map:type()
        return NodeTypes.Map
    end

    ---@return string[]
    function map:render()
        local keys = {}
        for key in pairs(self.nodes) do
            table.insert(keys, key)
        end
        if #keys == 0 then
            return {}
        end
        table.sort(keys)

        local res = {}
        for _, key in ipairs(keys) do
            local node = self.nodes[key]
            local lines = node:render()
            if node:type() == NodeTypes.Scalar then
                table.insert(res, string.format("%s: %s", key, lines[1]))
            else
                local indent = "  "
                if node:type() == NodeTypes.List then
                    indent = ""
                end
                table.insert(res, string.format("%s:", key))
                for _, line in ipairs(lines) do
                    table.insert(res, string.format("%s%s", indent, line))
                end
            end
        end
        return res
    end

    ---@return Map
    function map:clone()
        local m = Map()
        for key, node in pairs(self.nodes) do
            m:set(key, node:clone())
        end
        return m
    end

    return map
end

---@class Keyboard: Map
---@field name fun(self, name: string): Keyboard
---@field rows fun(self, rows: Row[]): Keyboard
---@field clone fun(self): Keyboard

---構造鍵盤對象, 由鍵盤名和各列按鍵組成
---@param name string|nil
---@param rows List|nil
---@return Keyboard
local function Keyboard(name, rows)
    local keyboard = Map({
        name = Scalar(name),
        rows = rows or List(),
    })
    ---@cast keyboard Keyboard

    ---@param n string
    function keyboard:name(n)
        self:set("name", Scalar(n))
        return self
    end

    ---@param r Key[]
    function keyboard:rows(r)
        self:set("rows", List(r))
        return self
    end

    function keyboard:clone()
        local s = Keyboard()
        for k, node in pairs(self.nodes) do
            s:set(k, node:clone())
        end
        return s
    end

    return keyboard
end

---@class Row: Map
---@field keys fun(self, keys: Key[]): Row
---@field height fun(self, height: number): Row
---@field clone fun(self): Row

---構造按鍵列對象, 由一組按鍵構成, 可指定行高
---@param keys List|nil
---@param rowHeight number|nil
---@return Row
local function Row(keys, rowHeight)
    local row = Map({ keys = keys or List() })
    if rowHeight then
        row:set("rowHeight", Scalar(tostring(rowHeight)))
    end
    ---@cast row Row

    ---@param k Key[]
    function row:keys(k)
        self:set("keys", List(k))
        return self
    end

    ---@param h number
    function row:height(h)
        self:set("rowHeight", Scalar(tostring(h)))
        return self
    end

    function row:clone()
        local s = Row()
        for k, node in pairs(self.nodes) do
            s:set(k, node:clone())
        end
        return s
    end

    return row
end

---@class Width: Map
---@field width fun(self, width: number): Width
---@field clone fun(self): Width

---@param width number|nil
---@return Width
local function Width(width)
    width = width or 1
    local width_scalar = Scalar(width == 1 and "input" or string.format("inputPercentage(%s)", tostring(width)))
    local width_map = Map({
        portrait  = width_scalar,
        landscape = width_scalar,
    })
    ---@cast width_map Width

    ---@param w number
    function width_map:width(w)
        local s = Scalar(w == 1 and "input" or string.format("inputPercentage(%s)", tostring(width)))
        self:set("portrait", s)
        self:set("landscape", s)
        return self
    end

    function width_map:clone()
        local s = Width()
        for k, node in pairs(self.nodes) do
            s:set(k, node:clone())
        end
        return s
    end

    return width_map
end

---@class Label: Map
---@field label fun(self, label: string): Label
---@field clone fun(self): Label

---@param label string|nil
---@return Label
local function Label(label)
    local label_scalar = Scalar(label)
    local label_map = Map({
        text        = label_scalar,
        loadingText = label_scalar,
    })
    ---@cast label_map Label
    ---@param l string
    function label_map:label(l)
        local s = Scalar(l)
        self:set("text", s)
        self:set("loadingText", s)
        return self
    end

    function label_map:clone()
        local s = Label()
        for k, node in pairs(self.nodes) do
            s:set(k, node:clone())
        end
        return s
    end

    return label_map
end

---按鍵行爲對象構造方法集合
local Act = {
    ---字符按鍵, 如字母鍵, 數字鍵, 符號鍵等
    ---@param char string
    Char = function(char) return string.format("character(%s)", char) end,
    ---退格鍵
    Backspace = function() return "backspace" end,
    ---回車鍵
    Enter = function() return "enter" end,
    ---Shift鍵
    Shift = function() return "shift" end,
    ---Tab鍵
    Tab = function() return "tab" end,
    ---空格鍵
    Space = function() return "space" end,
    ---空白佔位符
    ---@param char string|nil
    Empty = function(char) return string.format("characterMargin(%s)", char or " ") end,
    ---切換到另一個鍵盤
    ---@param char KeyboardType|string
    Keyboard = function(char) return string.format("keyboardType(%s)", char) end,
    ---字符串短語, 如 "你好", "2.718281828"
    ---@param text string
    Text = function(text) return string.format("symbol(%s)", text) end,
    ---快捷指令, 如 清空輸入串, 中英切換
    ---@param cmd Command
    Cmd = function(cmd) return string.format("shortCommand(#%s)", cmd) end,
}

---@class Key: Map
---@field act fun(self, action: string): Key
---@field via_rime fun(self, viaRime: boolean): Key
---@field label fun(self, label: string): Key
---@field width fun(self, width: number): Key
---@field swipe fun(self, swipe: Swipe[]): Key
---@field clone fun(self): Key

---構造一個按鍵對象, 指定其按下和滑動時的行爲
---@param action string|nil
---@param viaRime boolean|nil
---@param label string|nil
---@param width number|nil
---@param swipe List|nil
---@return Key
local function Key(action, viaRime, label, width, swipe)
    local key = Map({
        action        = Scalar(action or Act.Empty()),
        width         = Width(width),
        label         = Label(label),
        processByRIME = Scalar(tostring(viaRime or false)),
        swipe         = swipe or List(),
    })
    ---@cast key Key

    ---@param a string
    function key:act(a)
        self:set("action", Scalar(a))
        return self
    end

    ---@param b boolean
    function key:via_rime(b)
        self:set("processByRIME", Scalar(tostring(b)))
        return self
    end

    ---@param l string
    function key:label(l)
        self:set("label", Label(l))
        return self
    end

    ---@param w number
    function key:width(w)
        self:set("width", Width(w))
        return self
    end

    ---@param s Swipe[]
    function key:swipe(s)
        self:set("swipe", List(s))
        return self
    end

    function key:clone()
        local s = Key()
        for k, node in pairs(self.nodes) do
            s:set(k, node:clone())
        end
        return s
    end

    return key
end

---@class Swipe: Map
---@field dir fun(self, dir: Direction): Swipe
---@field via_rime fun(self, viaRime: boolean): Swipe
---@field act fun(self, action: string): Swipe
---@field display fun(self, display: boolean): Swipe
---@field label fun(self, label: string): Swipe
---@field clone fun(self): Swipe

---構造一個滑動對象, 指定按鍵上滑和下滑時觸發的動作
---@param direction Direction|nil
---@param viaRime boolean|nil
---@param action string|nil
---@param display boolean|nil
---@param label string|nil
---@return Swipe
local function Swipe(direction, action, viaRime, display, label)
    local swipe = Map({
        direction     = Scalar(direction or Dir.up),
        action        = Scalar(action or Act.Empty()),
        label         = Label(label),
        display       = Scalar(tostring(display or false)),
        processByRIME = Scalar(tostring(viaRime)),
    })
    ---@cast swipe Swipe

    ---@param d Direction
    function swipe:dir(d)
        self:set("direction", Scalar(d))
        return self
    end

    ---@param b boolean
    function swipe:via_rime(b)
        self:set("processByRIME", Scalar(tostring(b)))
        return self
    end

    ---@param a string
    function swipe:act(a)
        self:set("action", Scalar(a))
        return self
    end

    ---@param b boolean
    function swipe:display(b)
        self:set("display", Scalar(tostring(b)))
        return self
    end

    ---@param l string
    function swipe:label(l)
        self:set("label", Label(l))
        return self
    end

    function swipe:clone()
        local s = Swipe()
        for key, node in pairs(self.nodes) do
            s:set(key, node:clone())
        end
        return s
    end

    return swipe
end

---方法一: 使用構造函數生成
local function constructor()
    -- 是否顯示上下滑動符
    local show_up, show_down = true, true

    local qwert = Row(List({
        Key(Act.Char("q"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("1"), true, show_up), Swipe(Dir.down, Act.Char("|"), true, show_down) })),
        Key(Act.Char("w"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("2"), true, show_up), Swipe(Dir.down, Act.Char("@"), true, show_down) })),
        Key(Act.Char("e"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("3"), true, show_up), Swipe(Dir.down, Act.Char("#"), true, show_down) })),
        Key(Act.Char("r"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("4"), true, show_up), Swipe(Dir.down, Act.Char("$"), true, show_down) })),
        Key(Act.Char("t"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("5"), true, show_up), Swipe(Dir.down, Act.Char("%"), true, show_down) })),
        Key(Act.Char("y"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("6"), true, show_up), Swipe(Dir.down, Act.Char("^"), true, show_down) })),
        Key(Act.Char("u"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("7"), true, show_up), Swipe(Dir.down, Act.Char("&"), true, show_down) })),
        Key(Act.Char("i"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("8"), true, show_up), Swipe(Dir.down, Act.Char("*"), true, show_down) })),
        Key(Act.Char("o"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("9"), true, show_up), Swipe(Dir.down, Act.Char("("), true, show_down) })),
        Key(Act.Char("p"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("0"), true, show_up), Swipe(Dir.down, Act.Char(")"), true, show_down) })),
    }))
    local asdfg = Row(List({
        Key(Act.Empty("a"), true, nil, 0.5, List()),
        Key(Act.Char("a"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("!"), true, show_up), Swipe(Dir.down, Act.Char("?"), true, show_down) })),
        Key(Act.Char("s"), true, nil, nil, List({ Swipe(Dir.up, Act.Cmd(Cmd.last_schema), true, show_up), Swipe(Dir.down, Act.Cmd(Cmd.switcher), true, show_down) })),
        Key(Act.Char("d"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("*"), true, show_up), Swipe(Dir.down, Act.Char("°"), true, show_down) })),
        Key(Act.Char("f"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("+"), true, show_up), Swipe(Dir.down, Act.Char("-"), true, show_down) })),
        Key(Act.Char("g"), true, nil, nil, List({ Swipe(Dir.up, Act.Cmd(Cmd.head), true, show_up), Swipe(Dir.down, Act.Cmd(Cmd.head), true, show_down) })),
        Key(Act.Char("h"), true, nil, nil, List({ Swipe(Dir.up, Act.Cmd(Cmd.tail), true, show_up), Swipe(Dir.down, Act.Cmd(Cmd.tail), true, show_down) })),
        Key(Act.Char("j"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("<"), true, show_up), Swipe(Dir.down, Act.Char(">"), true, show_down) })),
        Key(Act.Char("k"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("["), true, show_up), Swipe(Dir.down, Act.Char("]"), true, show_down) })),
        Key(Act.Char("l"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("{"), true, show_up), Swipe(Dir.down, Act.Char("}"), true, show_down) })),
        Key(Act.Empty("l"), true, nil, 0.5, List()),
    }))
    local zxcvb = Row(List({
        Key(Act.Shift(), true, nil, nil, List()),
        Key(Act.Char("z"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("~"), true, show_up), Swipe(Dir.down, Act.Char("`"), true, show_down) })),
        Key(Act.Char("x"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("-"), true, show_up), Swipe(Dir.down, Act.Char("_"), true, show_down) })),
        Key(Act.Char("c"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("+"), true, show_up), Swipe(Dir.down, Act.Char("="), true, show_down) })),
        Key(Act.Char("v"), true, nil, nil, List({ Swipe(Dir.up, Act.Char('"'), true, show_up), Swipe(Dir.down, Act.Char("'"), true, show_down) })),
        Key(Act.Char("b"), true, nil, nil, List({ Swipe(Dir.up, Act.Char("/"), true, show_up), Swipe(Dir.down, Act.Char("\\"), true, show_down) })),
        Key(Act.Char("n"), true, nil, nil, List({ Swipe(Dir.up, Act.Char(";"), true, show_up), Swipe(Dir.down, Act.Char(":"), true, show_down) })),
        Key(Act.Char("m"), true, nil, nil, List({ Swipe(Dir.up, Act.Char(","), true, show_up), Swipe(Dir.down, Act.Char("."), true, show_down) })),
        Key(Act.Backspace(), true, nil, 2, List({ Swipe(Dir.down, Act.Cmd(Cmd.clear), true, show_up) })),
    }))
    local space = Row(List({
        Key(Act.Keyboard(Kbd.num_ng), true, nil, 2, List()),
        Key(Act.Char(";"), true, nil, nil, List()),
        Key(Act.Space(), true, "吉旦餅", 4, List({ Swipe(Dir.up, Act.Cmd(Cmd.second), true, show_up), Swipe(Dir.down, Act.Cmd("三选上屏"), true, show_down) })),
        Key(Act.Cmd(Cmd.eng), true, nil, nil, List()),
        Key(Act.Enter(), true, nil, 2, List({ Swipe(Dir.up, Act.Cmd(Cmd.ret), true, false) })),
    }))

    local patch = Map({
        keyboards = List({
            -- 鍵盤列表
            Keyboard("吉旦餅", List({ qwert, asdfg, zxcvb, space })),
        }),
    })
    local hamster = Map({ patch = patch })
    for _, line in ipairs(hamster:render()) do
        print(line)
    end
end

---方法二: 使用 builder 模式生成
local function builder()
    local _row = Row()
    local _key = Key():via_rime(true)
    local _swipe = Swipe():via_rime(true)
    local _keyboard = Keyboard()
    local row = function() return _row:clone() end
    local key = function() return _key:clone() end
    local swipe = function() return _swipe:clone() end
    local keyboard = function() return _keyboard:clone() end

    -- 主鍵盤
    local main_keyboard = keyboard():rows({
        row():keys({
            key():act(Act.Char("q")):swipe({swipe():act(Act.Char("1")), swipe():dir(Dir.down):act(Act.Char("|"))}),
            key():act(Act.Char("w")):swipe({swipe():act(Act.Char("2")), swipe():dir(Dir.down):act(Act.Char("@"))}),
            key():act(Act.Char("e")):swipe({swipe():act(Act.Char("3")), swipe():dir(Dir.down):act(Act.Char("#"))}),
            key():act(Act.Char("r")):swipe({swipe():act(Act.Char("4")), swipe():dir(Dir.down):act(Act.Char("$"))}),
            key():act(Act.Char("t")):swipe({swipe():act(Act.Char("5")), swipe():dir(Dir.down):act(Act.Char("%"))}),
            key():act(Act.Char("y")):swipe({swipe():act(Act.Char("6")), swipe():dir(Dir.down):act(Act.Char("^"))}),
            key():act(Act.Char("u")):swipe({swipe():act(Act.Char("7")), swipe():dir(Dir.down):act(Act.Char("&"))}),
            key():act(Act.Char("i")):swipe({swipe():act(Act.Char("8")), swipe():dir(Dir.down):act(Act.Char("*"))}),
            key():act(Act.Char("o")):swipe({swipe():act(Act.Char("9")), swipe():dir(Dir.down):act(Act.Char("("))}),
            key():act(Act.Char("p")):swipe({swipe():act(Act.Char("0")), swipe():dir(Dir.down):act(Act.Char(")"))}),
        }),
            row():keys({
            key():act(Act.Empty("a")):width(0.5),
            key():act(Act.Char("a")):swipe({swipe():act(Act.Char("!")), swipe():dir(Dir.down):act(Act.Char("?"))}),
            key():act(Act.Char("s")):swipe({swipe():act(Act.Cmd(Cmd.last_schema)), swipe():dir(Dir.down):act(Act.Cmd(Cmd.switcher))}),
            key():act(Act.Char("d")):swipe({swipe():act(Act.Char("*")), swipe():dir(Dir.down):act(Act.Char("°"))}),
            key():act(Act.Char("f")):swipe({swipe():act(Act.Char("+")), swipe():dir(Dir.down):act(Act.Char("-"))}),
            key():act(Act.Char("g")):swipe({swipe():act(Act.Cmd(Cmd.head)), swipe():dir(Dir.down):act(Act.Cmd(Cmd.head))}),
            key():act(Act.Char("h")):swipe({swipe():act(Act.Cmd(Cmd.tail)), swipe():dir(Dir.down):act(Act.Cmd(Cmd.tail))}),
            key():act(Act.Char("j")):swipe({swipe():act(Act.Char("<")), swipe():dir(Dir.down):act(Act.Char(">"))}),
            key():act(Act.Char("k")):swipe({swipe():act(Act.Char("[")), swipe():dir(Dir.down):act(Act.Char("]"))}),
            key():act(Act.Char("l")):swipe({swipe():act(Act.Char("{")), swipe():dir(Dir.down):act(Act.Char("}"))}),
            key():act(Act.Empty("l")):width(0.5),
        }),
            row():keys({
            key():act(Act.Shift()),
            key():act(Act.Char("z")):swipe({swipe():act(Act.Char("~")), swipe():dir(Dir.down):act(Act.Char("`"))}),
            key():act(Act.Char("x")):swipe({swipe():act(Act.Char("-")), swipe():dir(Dir.down):act(Act.Char("_"))}),
            key():act(Act.Char("c")):swipe({swipe():act(Act.Char("+")), swipe():dir(Dir.down):act(Act.Char("="))}),
            key():act(Act.Char("v")):swipe({swipe():act(Act.Char('"')), swipe():dir(Dir.down):act(Act.Char("'"))}),
            key():act(Act.Char("b")):swipe({swipe():act(Act.Char("/")), swipe():dir(Dir.down):act(Act.Char("\\"))}),
            key():act(Act.Char("n")):swipe({swipe():act(Act.Char(";")), swipe():dir(Dir.down):act(Act.Char(":"))}),
            key():act(Act.Char("m")):swipe({swipe():act(Act.Char(",")), swipe():dir(Dir.down):act(Act.Char("."))}),
            key():act(Act.Backspace()):swipe({swipe():act(Act.Cmd(Cmd.clear))}):width(2),
        }),
            row():keys({
            key():act(Act.Keyboard(Kbd.num_ng)):width(2),
            key():act(Act.Char(";")),
            key():act(Act.Space()):label("吉旦餅"):width(4):swipe({swipe():act(Act.Cmd(Cmd.second)), swipe():dir(Dir.down):act(Act.Cmd(Cmd.third))}),
            key():act(Act.Cmd(Cmd.eng)),
            -- key():act(Act.Keyboard(Kbd.custom:format("吉旦餅·英文"))),
            key():act(Act.Enter()):width(2),
        }),
    })

    -- 英文鍵盤
    local eng_keyboard = keyboard():rows({
    })

    -- 大寫鍵盤
    local cap_keyboard = keyboard():rows({
    })

    local patch = Map({
        keyboards = List({
            -- 鍵盤列表
            main_keyboard:name("吉旦餅"),
            -- eng_keyboard:name("吉旦餅·英文"),
            -- cap_keyboard:name("吉旦餅·大寫"),
        }),
    })

    local hamster = Map({ patch = patch })
    for _, line in ipairs(hamster:render()) do
        print(line)
    end
end

---主函數
local function main()
    -- constructor()
    builder()
end

main()
