local mq = require('mq')

local defaultNavOptions = 'log=off'
local spawnNavOptions = '| log=off'

local movement = {}

local function canNav(input)
    return not mq.TLO.Navigation.Active() and mq.TLO.Navigation.PathExists(input)()
end

local function waitForNav(timeout)
    -- Nav doesn't seem to report Active immediately, force a yield
    mq.delay(100, function() return mq.TLO.Navigation.Active() end)
    mq.delay(timeout, function() return not mq.TLO.Navigation.Active() end)
    movement.stop()
end

local function navCommand(command, options, timeout)
    if canNav(command) then mq.cmdf('/nav %s %s', command, options) end
    if timeout then waitForNav(timeout) end
end

local function setOptions(baseOptions, additionalOptions)
    return additionalOptions and baseOptions..' '..additionalOptions or baseOptions
end

function movement.navToSpawn(spawnSearch, options, timeout)
    local input = 'spawn '..spawnSearch
    navCommand(input, setOptions(spawnNavOptions, options), timeout)
end

function movement.navToLoc(x, y, z, options, timeout)
    local input = ('locyxz %d %d %d'):format(y, x, z)
    navCommand(input, setOptions(defaultNavOptions, options), timeout)
end

function movement.navToTarget(options, timeout)
    navCommand('target', setOptions(defaultNavOptions, options), timeout)
end

function movement.navToID(id, options, timeout)
    local input = 'id '..id
    navCommand(input, setOptions(defaultNavOptions, options), timeout)
end

function movement.stop()
    if mq.TLO.Navigation.Active() or mq.TLO.Stick.Active() then
        mq.cmd('/squelch /multiline ; /nav stop ; /stick off')
        mq.delay(50, function() return not mq.TLO.Navigation.Active() end)
    end
end

return movement