local libmerge = {}

---@param obj table
---@return table
function libmerge.clone(obj)
    local copy = {}
    for key, value in pairs(obj) do
        if type(value) == "table" then
            copy[key] = libmerge.clone(value)
        else
            copy[key] = value
        end
    end
    return copy
end

---@param obj table
---@param patch table
---@return table
function libmerge.patch_table(obj, patch)
    for key, value in pairs(patch) do
        local typ = type(value)
        if typ == "table" then
            if type(obj[key]) ~= "table" then
                -- 覆蓋
                obj[key] = value
            elseif #value == 0 then
                -- 對象, 合併
                libmerge.merge_table(obj[key], value)
            else
                -- 列表, 覆蓋
                obj[key] = value
            end
        elseif typ == "number" or typ == "string" or typ == "boolean" or typ == "function" then
            -- 覆蓋
            obj[key] = value
        end
    end
    return obj
end

return libmerge
