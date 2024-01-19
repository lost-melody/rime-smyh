local charset = require("wafel.core.charset_filter")
local embeded_cands = require("wafel.core.embeded_cands")
local macro = require("wafel.core.macro")
local mem = require("wafel.core.mem")
local reg = require("wafel.core.reg")
local stash = require("wafel.core.stash")
local switch = require("wafel.core.switch")

reg.add_init(mem.init)
reg.add_init(switch.init)

-- preprocess; macro; push; backspace; space; fullci; break; repeat; clearactive
reg.add_processor(stash.preprocess)
reg.add_processor(macro.processor)

-- macro; single; stash(fullcode; smart)
reg.add_translator(macro.translator)

-- charset
reg.add_translator(charset.filter)

-- embeded
reg.add_post_filter(embeded_cands.filter)
