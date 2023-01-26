local logger = {}

local log_prefix = '\a-t[\ax\ayAQOBot\ax\a-t]\ax \aw'

logger.flags = {
    routines={assist=false,buff=false,camp=false,cure=false,debuff=false,events=false,heal=false,mez=false,movement=false,pull=false,tank=false},
    class={ae=false,aggro=false,burn=false,cast=false,findspell=false,managepet=false,mash=false,ohshit=false,recover=false,rest=false},
    ability={validation=false,spell=false,aa=false,disc=false,item=false,skill=false},
    common={chase=false,cast=false,memspell=false,misc=false},
    aqo={main=false,commands=false,configuration=false},
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