local logger = {
    flags = {
        routines={assist=false,buff=false,camp=false,cure=false,debuff=false,events=false,heal=false,mez=false,movement=false,pull=false,tank=false},
        class={ae=false,aggro=false,burn=false,cast=false,findspell=false,managepet=false,mash=false,ohshit=false,recover=false,rest=false},
        ability={validation=false,all=false,spell=false,aa=false,disc=false,item=false,skill=false},
        common={chase=false,cast=false,memspell=false,misc=false,loot=false},
        aqo={main=false,commands=false,configuration=false},
        announce={spell=true,aa=true,disc=true,item=true,skill=true},
    },
    timestamps = false,
}

local log_prefix = '\a-t[\ax\ayAQOBot\ax\a-t]\ax \aw'

function logger.logLine(...)
    local timestampPrefix = logger.timestamps and '\a-w['..os.date('%X')..']\ax' or ''
    return string.format(timestampPrefix..log_prefix..string.format(...)..'\ax')
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