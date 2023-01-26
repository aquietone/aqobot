---@class Timer
local Timer = {
    expiration=0,
    start_time = 0,
}

---Initialize a new timer istance.
---@param expiration number @The number of seconds after the start time which the timer will be expired.
---@param reset? boolean @Indicate whether or not the timer start time should be now (reset) or 0 (expired)
---@return Timer @The timer instance.
function Timer:new(expiration, reset)
    local t = {}
    setmetatable(t, self)
    self.__index = self
    if reset then
        t.start_time = os.time()
    else
        t.start_time = 0
    end
    t.expiration = expiration
    return t
end

---Return the current time in seconds.
---@return number @Returns a number representing the current time in seconds.
function Timer.currentTime()
    return os.time()
end

---Reset the start time value to the current time.
---@param to_value? number @The value to reset the timer to.
function Timer:reset(to_value)
    self.start_time = to_value or Timer.currentTime()
end

---Check whether the specified timer has passed its expiration.
---@return boolean @Returns true if the timer has expired, otherwise false.
function Timer:timerExpired()
    if os.difftime(Timer.currentTime(), self.start_time) > self.expiration then
        return true
    else
        return false
    end
end

---Get the time remaining before the timer expires.
---@return number @Returns the number of seconds remaining until the timer expires.
function Timer:timeRemaining()
    return self.expiration - os.difftime(Timer.currentTime(), self.start_time)
end


--[[local mq = require('mq')
local myTimer = Timer:new(10)

-- by default, timer begins expired because initial start time is 0, so this loop ends immediately
while true do
    if myTimer:timerExpired() then
        print('timer expired')
        break
    else
        print('not yet')
    end
    mq.delay(1000)
end

-- reset sets start time to current time, so it will take full expiration time after that
myTimer:reset()
while true do
    if myTimer:timerExpired() then
        print('timer expired')
        break
    else
        print(myTimer:timeRemaining())
    end
    mq.delay(1000)
end]]--

return Timer