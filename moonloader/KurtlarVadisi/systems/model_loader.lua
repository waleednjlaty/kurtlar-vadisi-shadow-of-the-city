local logger = require 'KurtlarVadisi.systems.logger'
local runtime = require 'KurtlarVadisi.systems.runtime'
local M = {}
function M.load(modelId, timeoutMs)
    if type(modelId) ~= 'number' or modelId % 1 ~= 0 or modelId < 0 or modelId > 19999 then
        logger.error('Refused invalid model ID ' .. tostring(modelId)); return false
    end
    if not runtime.worldReady() then return false end
    local epoch = runtime.epoch
    local ok, err = pcall(requestModel, modelId)
    if not ok then logger.error('Model request failed: ' .. tostring(err)); return false end
    local deadline = getGameTimer() + (timeoutMs or 10000)
    while runtime.epoch == epoch do
        if not runtime.worldReady() then
            wait(0)
        elseif hasModelLoaded(modelId) then
            return true
        elseif getGameTimer() >= deadline then
            M.release(modelId)
            logger.error('Timed out loading model ' .. tostring(modelId)); return false
        else
            wait(0)
        end
    end
    return false -- Old world's requests are invalid after New/Load.
end
function M.release(modelId)
    if modelId and runtime.worldReady() then pcall(markModelAsNoLongerNeeded, modelId) end
end
return M
