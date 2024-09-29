local _module_0 = {}
local wrap_iter
wrap_iter = function(iter, handler)
    return coroutine.wrap(function()
        return handler(iter, coroutine.yield)
    end)
end
_module_0["wrap_iter"] = wrap_iter
local wrap_iter_from_array
wrap_iter_from_array = function(array)
    return wrap_iter(array, function(arr, yield)
        for _index_0 = 1, #arr do
            local v = arr[_index_0]
            yield(v)
        end
    end)
end
_module_0["wrap_iter_from_array"] = wrap_iter_from_array
return _module_0
