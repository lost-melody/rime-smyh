#!/bin/lua

---打印日志
---@param msg string
local function log(msg)
    io.stderr:write(msg)
    io.stderr:write("\n")
end

---打印日志并退出
---@param msg string
local function fatal(msg)
    log(msg)
    os.exit(1)
end

---打印日志并輸出註釋
---@param msg string
local function comment(msg)
    log(msg)
    print("# " .. msg)
end

-- 显示帮助手册
if #arg < 3 then
    log("error: invalid arguments!")
    log("usage:")
    log("\t" .. arg[0] .. " <freq_simp> <freq_trad> <prop>")
    log("example:")
    log("\t" .. arg[0] .. " freq_simp.txt freq_trad.txt 7:3 >freq.txt")
    return
end

---简体字频表文件名
---@type string
local simp_freq = arg[1]
---繁体字频表文件名
---@type string
local trad_freq = arg[2]

---转换比例串: "12:8" -> "12/8" -> 1.5 -> 0.6:0.4
local prop = load("return " .. string.gsub(arg[3], ":", "/"))
if not prop or type(prop()) ~= "number" then
    fatal("invalid prop: " .. arg[3])
    return
end

---简体字频权重
---@type number
local simp_weight = prop() / (1 + prop())
---繁体字频权重
---@type number
local trad_weight = 1 / (1 + prop())

-- 打印配置值到 stderr
comment("simp: " .. simp_freq)
comment("trad: " .. trad_freq)
comment(string.format("prop: %.2f:%.2f", simp_weight, trad_weight))

---字频集合
local freq_set = {}
setmetatable(freq_set, {
    __index = function()
        -- 默认返回零
        return 0
    end,
    __newindex = function(t, k, v)
        if v and type(v) == "number" and v >= 1e-10 then
            -- 只收录非零值
            rawset(t, k, v)
        end
    end,
})

---@param filename string
---@param weight number
local function read_file(filename, weight)
    -- 打开文件
    local file, err = io.open(filename, "r")
    if err or not file then
        fatal("error: " .. err)
        return
    end

    -- 逐行读取
    local total = 0
    for line in file:lines() do
        local index_tab = string.find(line, "\t", 1, true)
        if not index_tab then
            fatal("error: not '\\t' found at line: `" .. line .. "`")
            return
        end

        -- 收录字频
        local char = string.sub(line, 1, index_tab - 1)
        local freq = tonumber(string.sub(line, index_tab + 1))
        total = total + freq
        freq_set[char] = freq_set[char] + freq * weight
    end
    comment(string.format("%s total freq: %.8f", filename, total))
end

read_file(simp_freq, simp_weight)
read_file(trad_freq, trad_weight)

---字符列表
local char_list = {}
for char, freq in pairs(freq_set) do
    if freq >= 5 * 1e-9 then
        table.insert(char_list, char)
    end
end

---按字频排序, 字頻相同時按字符串原始排序
---@param a string
---@param b string
---@return boolean
table.sort(char_list, function(a, b)
    return freq_set[a] > freq_set[b] or freq_set[a] == freq_set[b] and a > b
end)

-- 输出到 stdout
local total = 0
for _, v in ipairs(char_list) do
    total = total + freq_set[v]
    print(string.format("%s\t%.8f", v, freq_set[v]))
end
comment(string.format("total freq: %.8f", total))
