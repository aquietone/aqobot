local logger = {}

local log_prefix = '\a-t[\ax\ayAQOBot\ax\a-t]\ax \aw'

logger.log_flags = {
    class={cast=false,mash=false,assist=false,tank=false,rest=false,recover=false,burn=false,heal=false,managepet=false},
    routines={camp=false,assist=false,mez=false,pull=false,tank=false},
    common={chase=false,cast=false,memspell=false,misc=false},
    aqo={main=false},
}

function logger.logLine(...)
    return string.format(log_prefix..string.format(...)..'\ax')
end

function logger.putLogData(message, key, value, separator)
    return string.format('%s%s%s=%s', message, separator or ' ', key, value)
end

function logger.putAllLogData(message, data, separator)
    for key, value in pairs(data) do
        message = message .. string.format('%s%s=%s', separator or ' ', key, value)
    end
    return message
end

---The formatted string and zero or more replacement variables for the formatted string.
---@vararg string
function logger.debug(debug_flag, ...)
    if debug_flag then print(logger.logLine(...)) end
end

--[[
local msg = logger.logLine('testing %s', '123')
msg = logger.putLogData(msg, 'a', 'b')
print(msg)
local data = {c='d',e=1}
msg = logger.putAllLogData(msg, data, '\n')
print(msg)
]]

return logger