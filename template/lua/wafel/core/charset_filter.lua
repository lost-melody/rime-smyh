local charset_filter = {}

local librime = require("wafel.base.librime")
local reg = require("wafel.core.reg")

---@type table<string, boolean>
local charset

---@param filename string
local function load_charset_file(filename)
    local filepath = librime.api.get_user_data_dir() .. "/" .. filename

    local file, err = io.open(filepath, "r")
    if err or not file then
        librime.log.warnf("failed to open file: %s", filepath)
        return {}
    end

    local set = {}
    for line in file:lines() do
        set[line] = true
    end

    return set
end

---@type WafelFilter
function charset_filter.filter(iter, _, yield)
    if reg.switches[reg.options.charset_filter.option_name] then
        -- filter enabled
        charset = charset or load_charset_file(reg.options.charset_filter.filename)
        for cand in iter do
            if utf8.len(cand.text) ~= 1 or charset[cand.text] then
                yield(cand)
            end
        end
    else
        -- filter disabled
        for cand in iter do
            yield(cand)
        end
    end
end

return charset_filter
