local libload = require("wafel.utils.libload")

libload.load_or_nil("wafel.custom.config")
---@type WafelOptions
local options = libload.load_or_nil("wafel.custom.options") or {}

return options
