local logger = require('utils.logger')

local mode = {
    modes={},
    mode_names={}
}

function mode:new(name, set_camp, is_assist, is_tank, is_pull, is_return)
    local m = {}
    setmetatable(m, self)
    self.__index = self
    m.name = name
    m.set_camp = set_camp
    m.is_assist = is_assist
    m.is_tank = is_tank
    m.is_pull = is_pull
    m.is_return = is_return
    table.insert(mode.modes, m)
    mode.modes[name] = m
    table.insert(mode.mode_names, name)
    return m
end

function mode:get_name()
    return self.name
end

function mode:is_manual_mode()
    return self.name == 'manual'
end

function mode:set_camp_mode()
    return self.set_camp
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

function mode:return_to_camp()
    return self.is_return
end

function mode.from_string(a_mode)
    if tonumber(a_mode) then
        return mode.modes[tonumber(a_mode)+1]
    else
        return mode.modes[a_mode]
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

--for i,mode in ipairs(mode.modes) do
--    logger.printf('modes[%s]: name=%s', i, mode.name)
--end

return mode