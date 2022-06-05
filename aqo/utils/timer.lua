---@class Timer
local Timer = {
    expiration=0,
    start_time = 0,
}

---Initialize a new timer istance.
---@param expiration number @The number of seconds after the start time which the timer will be expired.
---@return Timer @The timer instance.
function Timer:new(expiration)
    local t = {}
    setmetatable(t, self)
    self.__index = self
    t.start_time = 0
    t.expiration = expiration
    return t
end

---Return the current time in seconds.
---@return number @Returns a number representing the current time in seconds.
function Timer.current_time()
    return os.time()
end

---Reset the start time value to the current time.
---@param to_value number @The value to reset the timer to.
function Timer:reset(to_value)
    self.start_time = to_value or Timer.current_time()
end

---Check whether the specified timer has passed its expiration.
---@return boolean @Returns true if the timer has expired, otherwise false.
function Timer:timer_expired()
    if os.difftime(Timer.current_time(), self.start_time) > self.expiration then
        return true
    else
        return false
    end
end

---Get the time remaining before the timer expires.
---@return number @Returns the number of seconds remaining until the timer expires.
function Timer:time_remaining()
    return self.expiration - os.difftime(Timer.current_time(), self.start_time)
end


--[[local mq = require('mq')
local my_timer = Timer:new(10)

-- by default, timer begins expired because initial start time is 0, so this loop ends immediately
while true do
    if my_timer:timer_expired() then
        print('timer expired')
        break
    else
        print('not yet')
    end
    mq.delay(1000)
end

-- reset sets start time to current time, so it will take full expiration time after that
my_timer:reset()
while true do
    if my_timer:timer_expired() then
        print('timer expired')
        break
    else
        print(my_timer:time_remaining())
    end
    mq.delay(1000)
end]]--

return Timer