local mode = {
    modes={},
    mode_names={}
}

function mode:new(name, setCamp, is_assist, is_tank, is_pull, is_return)
    local m = {
        name = name,
        setCamp = setCamp,
        is_assist = is_assist,
        is_tank = is_tank,
        is_pull = is_pull,
        is_return = is_return,
    }
    setmetatable(m, self)
    self.__index = self
    table.insert(mode.modes, m)
    mode.modes[name] = m
    table.insert(mode.mode_names, name)
    return m
end

function mode:getName()
    return self.name
end

function mode:isManualMode()
    return self.name == 'manual'
end

function mode:isCampMode()
    return self.setCamp
end

function mode:isAssistMode()
    return self.is_assist
end

function mode:isTankMode()
    return self.is_tank
end

function mode:isPullMode()
    return self.is_pull
end

function mode:isReturnToCampMode()
    return self.is_return
end

function mode.fromString(a_mode)
    if tonumber(a_mode) then
        return mode.modes[tonumber(a_mode)+1]
    else
        return mode.modes[a_mode]
    end
end

function mode.nameFromString(a_mode)
    if tonumber(a_mode) then
        return mode.modes[tonumber(a_mode)+1] and mode.modes[tonumber(a_mode)+1].name
    else
        return mode.modes[a_mode] and mode.modes[a_mode].name
    end
end

mode:new('manual',false,false,false,false,false)
mode:new('assist',true,true,false,false,true)
mode:new('chase',false,true,false,false,false)
mode:new('vorpal',false,true,false,false,false)
mode:new('tank',true,false,true,false,true)
mode:new('pullertank',true,false,true,true,true)
mode:new('puller',true,true,false,true,true)
mode:new('huntertank',true,false,true,true,false)

mode.currentMode = mode.modes.manual

return mode