local librime = require("wafel.base.librime")
local reg = require("wafel.core.reg")

---@param segmentation Segmentation
---@param env Env
local function segmentor(segmentation, env)
    for i, handler in ipairs(reg.segmentors) do
        local success, err = pcall(handler, segmentation, env)
        if not success then
            librime.log.warnf("failed to call translator[%d]: %s", i, err)
        end
    end
end

return segmentor
