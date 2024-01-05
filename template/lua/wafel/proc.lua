local librime = require("wafel.base.librime")
local reg = require("wafel.core.reg")

---@param key_event KeyEvent
---@param env Env
local function processor(key_event, env)
    -- 處理快捷鍵
    local accelerator = reg.get_keymap(key_event.modifier, key_event.keycode)
    if accelerator then
        local success, result = pcall(accelerator, key_event, env)
        if not success then
            librime.log.warnf("failed to call accelerator[%d:%d]: %s", key_event.modifier, key_event.keycode, result)
            return librime.process_results.kNoop
        end
        if result == librime.process_results.kRejected or result == librime.process_results.kAccepted then
            return result
        end
    end

    -- 調用注册的 Processor 路由
    for i, handler in ipairs(reg.processors) do
        local success, result = pcall(handler, key_event, env)
        if not success then
            librime.log.warnf("failed to call processor[%d]: %s", i, result)
        elseif result == librime.process_results.kRejected or result == librime.process_results.kAccepted then
            return result
        end
    end

    return librime.process_results.kNoop
end

return processor
