local logger = {}

local log_prefix = '\a-t[\ax\ayAQOBot\ax\a-t]\ax '

logger.log_flags = {
    class={cast=false,mash=false,assist=false,tank=false,rest=false,recover=false,burn=false,heal=false,managepet=false},
    routines={camp=false,assist=false,mez=false,pull=false,tank=false},
    common={chase=false,cast=false,memspell=false,misc=false},
    aqo={main=false},
}

---The formatted string and zero or more replacement variables for the formatted string.
---@vararg string
function logger.printf(...)
    print(log_prefix..string.format(...))
end

---The formatted string and zero or more replacement variables for the formatted string.
---@vararg string
function logger.debug(debug_flag, ...)
    if debug_flag then logger.printf(...) end
end

return logger