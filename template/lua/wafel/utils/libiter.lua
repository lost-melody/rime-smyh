---迭代器基础庫
local libiter = {}

---在現有的迭代器上通過 `handler` 封裝一個新的迭代器
---傳入處理器 `handler` 須能正確處理傳入迭代器 `iterable`, 並通過 `yield` 函數送出
---包裝後的簡易迭代器, 可通過 `for v in iter() do ... end` 進行迭代
---
---從數組遍歷數據, 並進行修飾:
---
--- ```
--- local arr = { 2, 3, 5, 7 }
--- -- 過濾和衍生
--- local filter = function(arr, yield)
---     for index, v in ipairs(arr) do
---         -- 過濾第奇數個元素
---         if index % 2 == 0 then
---             yield(v)
---             -- 衍生元素
---             yield(v+1)
---         end
---     end
--- end
--- -- 構造迭代器
--- local iter = wrap_iterator(arr, filter)
--- for v in iter() do print(v) end
--- ```
---
---@param iterable any
---@param handler fun(iter: any, yield: function)
---@return function
function libiter.wrap_iterator(iterable, handler)
    return function()
        return coroutine.wrap(function()
            handler(iterable, coroutine.yield)
        end)
    end
end

---從數組創建迭代器, 通過 `wrap_iterator` 實現
---
---簡例:
---
--- ```
--- local arr = { 3, 1, 4, 1, 5, 9 }
--- local iter = wrap_iterator_from_array(arr)
--- for v in iter() do print(v) end
--- ```
---
---@param array table
function libiter.wrap_iterator_from_array(array)
    return libiter.wrap_iterator(array, function(arr, yield)
        for _, v in ipairs(arr) do
            yield(v)
        end
    end)
end

return libiter
