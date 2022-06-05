local logger = {}

local log_prefix = '\a-t[\ax\ayAQOBot\ax\a-t]\ax '

---The formatted string and zero or more replacement variables for the formatted string.
---@vararg string
function logger.printf(...)
    print(log_prefix..string.format(...))
end

---The formatted string and zero or more replacement variables for the formatted string.
---@vararg string
function logger.debug(debug_flag, ...)
    if debug_flag then logger:printf(...) end
end

return logger