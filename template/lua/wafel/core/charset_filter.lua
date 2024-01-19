local charset_filter = {}

---@type WafelFilter
function charset_filter.filter(iter, env, yield)
    for cand in iter() do
        yield(cand)
    end
end

return charset_filter
