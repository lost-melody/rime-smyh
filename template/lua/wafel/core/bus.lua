local bus = {}

---完整編碼
bus.input = {
    ---轉譯後的完整輸入串
    ---@type string
    code = "",
    ---原始輸入串
    ---@type string
    init_code = "",
}

---暫存編碼
bus.stash = {
    ---暫存輸入串
    ---@type string
    code = "",
    ---暫存候選
    ---@type string[]
    cands = {},
}

---活動編碼
bus.active = {
    ---活動輸入串
    ---@type string
    code = "",
}

return bus
