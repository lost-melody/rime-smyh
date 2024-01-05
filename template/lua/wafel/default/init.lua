local libload = require("wafel.utils.libload")

libload.load_or_nil("wafel.default.config")
---@type WafelOptions
local options = libload.load_or_nil("wafel.default.options") or {}

return options
