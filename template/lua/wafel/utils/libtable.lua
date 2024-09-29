local _module_0 = {}
local clone
clone = function(obj)
    if (type(obj)) == "table" then
        local _tbl_0 = {}
        for k, v in pairs(obj) do
            _tbl_0[k] = clone(v)
        end
        return _tbl_0
    else
        return obj
    end
end
_module_0["clone"] = clone
local merge
merge = function(obj, patch)
    if (type(obj)) == "table" and (type(patch)) == "table" then
        if #patch == 0 then
            for key, value in pairs(patch) do
                obj[key] = merge(obj[key], value)
            end
        else
            while not (#obj == 0) do
                table.remove(obj)
            end
            for _index_0 = 1, #patch do
                local value = patch[_index_0]
                table.insert(obj, value)
            end
        end
        return obj
    elseif patch == nil then
        return obj
    else
        return clone(patch)
    end
end
_module_0["merge"] = merge
return _module_0
