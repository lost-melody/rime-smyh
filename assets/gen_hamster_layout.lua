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
    clear = "重输",
    trad = "繁简切换",
    eng = "中英切换",
    head = "行首",
    tail = "行尾",
    second = "次选上屏",
    third = "三选上屏",
    last_schema = "上个输入方案",
    ret = "换行",
    switcher = "RimeSwitcher",
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

---YAML純數據節點
---@class Scalar: Node
---@field set fun(self, value: string): Scalar
---@field clone fun(self): Scalar
local _Scalar = {}

---YAML列表節點
---@class List: Node
---@field append fun(self, value: Node): List
---@field clone fun(self): List
local _List = {}

---YAML字典節點
---@class Map: Node
---@field set fun(self, key: string, value: Node): Map
---@field clone fun(self): Map
local _Map = {}

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

---構造鍵盤對象, 由鍵盤名和各列按鍵組成
---@param name string
---@param rows List
---@return Map
local function Keyboard(name, rows)
    return Map({
        name = Scalar(name),
        rows = rows,
    })
end

---構造按鍵列對象, 由一組按鍵構成, 可指定行高
---@param keys List
---@param rowHeight number|nil
---@return Map
local function Row(keys, rowHeight)
    local row = Map({ keys = keys })
    if rowHeight then
        row:set("rowHeight", Scalar(tostring(rowHeight)))
    end
    return row
end

---構造一個按鍵對象, 指定其按下和滑動時的行爲
---@param action string
---@param viaRime boolean
---@param label string|nil
---@param width number|nil
---@param swipe List|nil
---@return Map
local function Key(action, viaRime, label, width, swipe)
    width = width or 1
    local width_scalar = Scalar(width == 1 and "input" or string.format("inputPercentage(%s)", tostring(width)))
    local width_map = Map({
        portrait  = width_scalar,
        landscape = width_scalar,
    })
    local label_scalar = Scalar(label)
    local label_map = Map({
        text        = label_scalar,
        loadingText = label_scalar,
    })
    return Map({
        action        = Scalar(action),
        width         = width_map,
        label         = label_map,
        processByRIME = Scalar(tostring(viaRime)),
        swipe         = swipe or List(),
    })
end

---構造一個滑動對象, 指定按鍵上滑和下滑時觸發的動作
---@param direction Direction
---@param viaRime boolean
---@param action string
---@param display boolean
---@param label string|nil
---@return Map
local function Swipe(direction, action, viaRime, display, label)
    return Map({
        direction     = Scalar(direction),
        action        = Scalar(action),
        label         = Scalar(label),
        display       = Scalar(tostring(display)),
        processByRIME = Scalar(tostring(viaRime)),
    })
end

---按鍵行爲對象構造方法集合
local Action = {}

---字符按鍵, 如字母鍵, 數字鍵, 符號鍵等
---@param char string
function Action.Char(char)
    return string.format("character(%s)", char)
end

---退格鍵
function Action.Backspace()
    return "backspace"
end

---回車鍵
function Action.Enter()
    return "enter"
end

---Shift鍵
function Action.Shift()
    return "shift"
end

---Tab鍵
function Action.Tab()
    return "tab"
end

---空格鍵
function Action.Space()
    return "space"
end

---空白佔位符
---@param char string|nil
function Action.Empty(char)
    return string.format("characterMargin(%s)", char or " ")
end

---切換到另一個鍵盤
---
---可用值如下:
---
---- `alphabetic`: 默認英文鍵盤
---- `classifySymbolic`: 分類符號鍵盤
---- `chinese`: 默認中文鍵盤
---- `chineseNineGrid`: 中文九宫格鍵盤
---- `numericNineGrid`: 數字九宫格鍵盤
---- `custom(name)`: 自定義鍵盤, 通過 `Keyboard` 對象的 `name` 字段檢索
---- `emojis`: Emoji鍵盤
---
---@param char string
function Action.Keyboard(char)
    return string.format("keyboardType(%s)", char)
end

---字符串短語, 如 "你好", "2.718281828"
---@param text string
function Action.Text(text)
    return string.format("symbol(%s)", text)
end

---快捷指令, 如 清空輸入串, 中英切換
---@param cmd Command
function Action.Command(cmd)
    return string.format("shortCommand(#%s)", cmd)
end

---主函數
local function main()
    -- 是否顯示上下滑動符
    local show_up, show_down = true, true

    local qwert = Row(List({
        Key(Action.Char("q"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("1"), true, show_up), Swipe(Dir.down, Action.Char("|"), true, show_down) })),
        Key(Action.Char("w"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("2"), true, show_up), Swipe(Dir.down, Action.Char("@"), true, show_down) })),
        Key(Action.Char("e"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("3"), true, show_up), Swipe(Dir.down, Action.Char("#"), true, show_down) })),
        Key(Action.Char("r"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("4"), true, show_up), Swipe(Dir.down, Action.Char("$"), true, show_down) })),
        Key(Action.Char("t"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("5"), true, show_up), Swipe(Dir.down, Action.Char("%"), true, show_down) })),
        Key(Action.Char("y"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("6"), true, show_up), Swipe(Dir.down, Action.Char("^"), true, show_down) })),
        Key(Action.Char("u"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("7"), true, show_up), Swipe(Dir.down, Action.Char("&"), true, show_down) })),
        Key(Action.Char("i"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("8"), true, show_up), Swipe(Dir.down, Action.Char("*"), true, show_down) })),
        Key(Action.Char("o"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("9"), true, show_up), Swipe(Dir.down, Action.Char("("), true, show_down) })),
        Key(Action.Char("p"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("0"), true, show_up), Swipe(Dir.down, Action.Char(")"), true, show_down) })),
    }))
    local asdfg = Row(List({
        Key(Action.Empty(), true, nil, 0.5, List()),
        Key(Action.Char("a"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("!"), true, show_up), Swipe(Dir.down, Action.Char("?"), true, show_down) })),
        Key(Action.Char("s"), true, nil, nil, List({ Swipe(Dir.up, Action.Command(Cmd.last_schema), true, show_up), Swipe(Dir.down, Action.Command(Cmd.switcher), true, show_down) })),
        Key(Action.Char("d"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("*"), true, show_up), Swipe(Dir.down, Action.Char("°"), true, show_down) })),
        Key(Action.Char("f"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("-"), true, show_up), Swipe(Dir.down, Action.Char("_"), true, show_down) })),
        Key(Action.Char("g"), true, nil, nil, List({ Swipe(Dir.up, Action.Command(Cmd.head), true, show_up), Swipe(Dir.down, Action.Command(Cmd.head), true, show_down) })),
        Key(Action.Char("h"), true, nil, nil, List({ Swipe(Dir.up, Action.Command(Cmd.tail), true, show_up), Swipe(Dir.down, Action.Command(Cmd.tail), true, show_down) })),
        Key(Action.Char("j"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("<"), true, show_up), Swipe(Dir.down, Action.Char(">"), true, show_down) })),
        Key(Action.Char("k"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("["), true, show_up), Swipe(Dir.down, Action.Char("]"), true, show_down) })),
        Key(Action.Char("l"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("{"), true, show_up), Swipe(Dir.down, Action.Char("}"), true, show_down) })),
        Key(Action.Empty(), true, nil, 0.5, List()),
    }))
    local zxcvb = Row(List({
        Key(Action.Shift(), true, nil, nil, List()),
        Key(Action.Char("z"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("~"), true, show_up), Swipe(Dir.down, Action.Char("`"), true, show_down) })),
        Key(Action.Char("x"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("-"), true, show_up), Swipe(Dir.down, Action.Char("_"), true, show_down) })),
        Key(Action.Char("c"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("+"), true, show_up), Swipe(Dir.down, Action.Char("="), true, show_down) })),
        Key(Action.Char("v"), true, nil, nil, List({ Swipe(Dir.up, Action.Char('"'), true, show_up), Swipe(Dir.down, Action.Char("'"), true, show_down) })),
        Key(Action.Char("b"), true, nil, nil, List({ Swipe(Dir.up, Action.Char("/"), true, show_up), Swipe(Dir.down, Action.Char("\\"), true, show_down) })),
        Key(Action.Char("n"), true, nil, nil, List({ Swipe(Dir.up, Action.Char(";"), true, show_up), Swipe(Dir.down, Action.Char(":"), true, show_down) })),
        Key(Action.Char("m"), true, nil, nil, List({ Swipe(Dir.up, Action.Char(","), true, show_up), Swipe(Dir.down, Action.Char("."), true, show_down) })),
        Key(Action.Backspace(), true, nil, 2, List({ Swipe(Dir.down, Action.Command(Cmd.clear), true, show_up) })),
    }))
    local space = Row(List({
        Key(Action.Keyboard("numericNineGrid"), true, nil, 2, List()),
        Key(Action.Char(";"), true, nil, nil, List()),
        Key(Action.Space(), true, "吉旦餅", 4, List({ Swipe(Dir.up, Action.Command(Cmd.second), true, show_up), Swipe(Dir.down, Action.Command("三选上屏"), true, show_down) })),
        Key(Action.Command(Cmd.eng), true, nil, nil, List()),
        Key(Action.Enter(), true, nil, 2, List({ Swipe(Dir.up, Action.Command(Cmd.ret), true, false) })),
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

main()
