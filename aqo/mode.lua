local logger = require('aqo.logger')

local mode = {
    modes={},
    mode_names={},
    valid_modes={},
}

function mode:new(name, is_camp, is_assist, is_tank, is_pull)
    local m = {}
    setmetatable(m, self)
    self.__index = self
    m.name = name
    m.is_camp = is_camp
    m.is_assist = is_assist
    m.is_tank = is_tank
    m.is_pull = is_pull
    table.insert(mode.modes, m)
    mode.modes[name] = m
    return m
end

function mode:get_name()
    return self.name
end

function mode:is_camp_mode()
    return self.is_camp
end

function mode:is_assist_mode()
    return self.is_assist
end

function mode:is_tank_mode()
    return self.is_tank
end

function mode:is_pull_mode()
    return self.is_pull
end

function mode.from_string(a_mode)
    if tonumber(a_mode) then
        return mode.modes[tonumber(a_mode)]
    else
        return mode.modes[a_mode]
    end
end

mode:new('manual',false,false,false,false)
mode:new('assist',true,true,false,false)
mode:new('chase',false,true,false,false)
mode:new('vorpal',false,true,false,false)
mode:new('tank',true,false,true,false)
mode:new('pullertank',true,false,true,true)
mode:new('puller',true,true,false,true)

--for i,mode in ipairs(mode.modes) do
--    logger.printf('modes[%s]: name=%s', i, mode.name)
--end

return mode