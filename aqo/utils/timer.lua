--- @type Mq
local mq = require('mq')
---@class Timer
---@field expiration number #Time, in milliseconds, after which the timer expires.
---@field start_time number #Time since epoch, in milliseconds, when timer is counting from.
local Timer = {
    expiration = 0,
    start_time = 0,
}

---Initialize a new timer istance.
---@param expiration number @The time, in milliseconds, after which the timer expires.
---@return Timer @The timer instance.
function Timer:new(expiration)
    local t = {
        start_time = mq.gettime(),
        expiration = expiration
    }
    setmetatable(t, self)
    self.__index = self
    return t
end

---Reset the start time value to the current time or specified time, such as 0.
---@param to_value? number @The value to reset the timer to.
function Timer:reset(to_value)
    self.start_time = to_value or mq.gettime()
end

---Check whether the specified timer has passed its expiration.
---@return boolean @Returns true if the timer has expired, otherwise false.
function Timer:timerExpired()
    return mq.gettime() - self.start_time > self.expiration
end

---Get the time remaining before the timer expires.
---@return number @Returns the number of milliseconds remaining until the timer expires.
function Timer:timeRemaining()
    return self.expiration - (mq.gettime() - self.start_time)
end

return Timer