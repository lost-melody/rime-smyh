local librime = require("wafel.base.librime")
local reg = require("wafel.core.reg")

---@param segmentation Segmentation
---@param env Env
local function segmentor(segmentation, env)
    for _, handler in ipairs(reg.segmentors) do
        local success, err = pcall(handler, segmentation, env)
        if not success then
            librime.log.warnf("failed to call translator: %s", err)
        end
    end
end

return segmentor
