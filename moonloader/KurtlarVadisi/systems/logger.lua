local M = {}
local logPath = 'moonloader\\KurtlarVadisi\\debug\\kv.log'
local function write(level, message)
    print('[KVS] '..tostring(message))
    local file = io.open(logPath, 'a')
    if file then file:write(os.date('[%Y-%m-%d %H:%M:%S] ') .. level .. ' ' .. tostring(message) .. '\n'); file:close() end
end
function M.info(message) write('INFO ', message) end
function M.warn(message) write('WARN ', message) end
function M.error(message) write('ERROR', message) end
function M.exception(context, err) M.error(context .. ': ' .. tostring(err)) end
return M
