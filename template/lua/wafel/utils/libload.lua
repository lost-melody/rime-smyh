local libload = {}

---@param modname string
function libload.load_or_nil(modname)
    local success, result = pcall(require, modname)
    if success and result ~= true then
        return result
    end
end

return libload
