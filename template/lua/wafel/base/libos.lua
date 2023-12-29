---wafel 操作系統環境檢測核心庫
local libos = {}

local librime = require("wafel.base.librime")

---操作系統環境檢測
libos.os = {}

---@enum RimeOSType
---操作系統類型枚舉
libos.os.types = {
    unknown = "unknown",
    android = "android",
    ios = "ios",
    linux = "linux",
    mac = "mac",
    windows = "windows",
}

---@type RimeOSType
---當前操作系統平臺
libos.os.name = libos.os.types.unknown

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
    return self.name == self.types.unknown
end

---通過 *rime_api* 查詢 *librime* 發行版本, 從而獲知系統版本
local dist = librime.api.get_distribution_code_name()
if dist == "trime" then
    libos.os.name = libos.os.types.android
elseif dist == "Hamster" then
    libos.os.name = libos.os.types.ios
elseif dist == "fcitx-rime" or dist == "ibus-rime" then
    libos.os.name = libos.os.types.linux
elseif dist == "Squirrel" then
    libos.os.name = libos.os.types.mac
elseif dist == "Weasel" then
    libos.os.name = libos.os.types.windows
end

return libos
