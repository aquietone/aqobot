local timer = {}

function timer:new(expiration)
    local t = {}
    setmetatable(t, self)
    self.__index = self
    t.start_time = 0
    t.expiration = expiration
    return t
end

---Return the current time in seconds.
---@return number @Returns a number representing the current time in seconds.
function timer.current_time()
    return os.time()
end

function timer:reset()
    self.start_time = timer.current_time()
end

---Check whether the specified timer has passed the given expiration.
---@param t number @The current value of the timer.
---@param expiration number @The number of seconds which must have passed for the timer to be expired.
---@return boolean
function timer:timer_expired()
    if os.difftime(timer.current_time(), self.start_time) > self.expiration then
        return true
    else
        return false
    end
end

---Check whether the time remaining on the given timer is less than the provided value.
---@param t number @The current value of the timer.
---@param less_than number @The maximum number of seconds remaining to return true.
---@return boolean @Returns true if the timer has less than the specified number of seconds remaining.
function timer:time_remaining(less_than)
    return not timer:timer_expired()
end

return timer