local _module_0 = {}
local clone
clone = function(obj)
    if (type(obj)) == "table" then
        local copy = {}
        for key, value in pairs(obj) do
            if (type(value)) == "table" then
                copy[key] = clone(value)
            else
                copy[key] = value
            end
        end
        return copy
    else
        return obj
    end
end
_module_0["clone"] = clone
local _anon_func_0 = function(type, value)
    local _val_0 = (type(value))
    return "boolean" == _val_0 or "number" == _val_0 or "string" == _val_0 or "function" == _val_0
end
local patch
patch = function(obj, p)
    if (type(obj)) == "table" and (type(p)) == "table" then
        for key, value in pairs(p) do
            if (type(value)) == "table" then
                if (type(obj[key])) ~= "table" then
                    obj[key] = clone(value)
                elseif #value == 0 then
                    obj[key] = patch(obj[key], value)
                else
                    local _accum_0 = {}
                    local _len_0 = 1
                    for _index_0 = 1, #value do
                        local i = value[_index_0]
                        _accum_0[_len_0] = i
                        _len_0 = _len_0 + 1
                    end
                    obj[key] = _accum_0
                end
            elseif _anon_func_0(type, value) then
                obj[key] = clone(value)
            end
        end
    end
    return obj
end
_module_0["patch"] = patch
return _module_0
