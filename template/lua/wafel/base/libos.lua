---wafel 操作系統環境檢測核心庫
local libos = {}

---操作系統環境檢測
libos.os = {
    ---操作系統類型枚舉
    types = {
        android = "android",
        ios     = "ios",
        linux   = "linux",
        mac     = "mac",
        windows = "windows",
    },
    ---當前操作系統平臺
    name = "",
}

---通過 *rime_api* 查詢 *librime* 發行版本, 從而獲知系統版本
---@param get_distribution_code_name function
function libos.os:init(get_distribution_code_name)
    local dist = get_distribution_code_name()
    if dist == "trime" then
        self.name = self.types.android
    elseif dist == "Hamster" then
        self.name = self.types.ios
    elseif dist == "fcitx-rime" or dist == "ibus-rime" then
        self.name = self.types.linux
    elseif dist == "Squirrel" then
        self.name = self.types.mac
    elseif dist == "Weasel" then
        self.name = self.types.windows
    end
end

---是否爲 Android 平臺
function libos.os:android()
    return self.name == self.types.android
end

---是否爲 iOS 平臺
function libos.os:ios()
    return self.name == self.types.ios
end

---是否爲 Linux 平臺
function libos.os:linux()
    return self.name == self.types.linux
end

---是否爲 Mac 平臺
function libos.os:darwin()
    return self.name == self.types.darwin
end

---是否爲 Windows 平臺
function libos.os:windows()
    return self.name == self.types.windows
end

---是否未知平臺
function libos.os:unknown()
    return self.name == ""
end

-- 初始化
if rime_api and rime_api.get_distribution_code_name then
    libos.os:init(rime_api.get_distribution_code_name)
end

return libos
