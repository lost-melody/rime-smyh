local libload = require("wafel.utils.libload")

libload.load_or_nil("wafel.core.config")
---@type WafelOptions
local options = libload.load_or_nil("wafel.core.options") or {}

return options
