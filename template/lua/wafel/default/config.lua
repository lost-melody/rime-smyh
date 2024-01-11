local mem = require("wafel.core.mem")
local reg = require("wafel.core.reg")
local switch = require("wafel.core.switch")

reg.add_init(mem.init)
reg.add_init(switch.init)
