local filter = {}
local core = require("smyh.core")

-- ######## 过滤器 ########

function filter.init(env)
end

-- 过滤器
function filter.func(input, env)
    local is_first = true
    for cand in input:iter() do
        if is_first and core.pass_comment and string.len(core.pass_comment) ~= 0 then
            -- 施法提示
            cand.comment = "["..core.pass_comment.."]"
            is_first = false
        end
        yield(cand)
    end
end

function filter.fini(env)
end

return filter
