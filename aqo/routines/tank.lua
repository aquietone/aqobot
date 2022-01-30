--- @type mq
local mq = require 'mq'
local common = require('aqo.common')
local config = require('aqo.configuration')
local logger = require('aqo.utils.logger')
local state = require('aqo.state')

local tank = {}

--- Tank Functions

---Iterate through mobs in the common.TARGETS table and find a mob in camp to begin tanking.
---Sets common.TANK_MOB_ID to the ID of the mob to tank.
tank.find_mob_to_tank = function()
    if state.get_mob_count() == 0 then return end
    if common.am_i_dead() then return end
    if state.get_tank_mob_id() > 0 and mq.TLO.Target() and mq.TLO.Target.Type() ~= 'Corpse' then
        return
    else
        state.set_tank_mob_id(0)
    end
    logger.debug(state.get_debug(), 'Find mob to tank')
    local highestlvl = 0
    local highestlvlid = 0
    local lowesthp = 100
    local lowesthpid = 0
    local firstid = 0
    for id,_ in pairs(state.get_targets()) do
        -- loop through for named, highest level, unmezzed, lowest hp
        local mob = mq.TLO.Spawn(id)
        if mob() then
            if firstid == 0 then firstid = mob.ID() end
            if mob.Named() then
                logger.debug(state.get_debug(), 'Selecting Named mob to tank next (%s)', mob.ID())
                state.set_tank_mob_id(mob.ID())
                return
            else--if not mob.Mezzed() then -- TODO: mez check requires targeting
                if mob.Level() > highestlvl then
                    highestlvlid = id
                    highestlvl = mob.Level()
                end
                if mob.PctHPs() < lowesthp then
                    lowesthpid = id
                    lowesthp = mob.PctHPs()
                end
            end
        end
    end
    if lowesthpid ~= 0 and lowesthp < 100 then
        logger.debug(state.get_debug(), 'Selecting lowest HP mob to tank next (%s)', lowesthpid)
        state.set_tank_mob_id(lowesthpid)
        return
    elseif highestlvlid ~= 0 then
        logger.debug(state.get_debug(), 'Selecting highest level mob to tank next (%s)', highestlvlid)
        state.set_tank_mob_id(highestlvlid)
        return
    end
    -- no named or unmezzed mobs, break a mez
    if firstid ~= 0 then
        logger.debug(state.get_debug(), 'Selecting first available mob to tank next (%s)', firstid)
        state.set_tank_mob_id(firstid)
        return
    end
end

---Determine whether the target to be tanked is within the camp radius.
---@return boolean @Returns true if the target is within the camp radius, otherwise false.
local function tank_mob_in_range(tank_spawn)
    local mob_x = tank_spawn.X()
    local mob_y = tank_spawn.Y()
    if not mob_x or not mob_y then return false end
    local camp = state.get_camp()
    local camp_radius = config.get_camp_radius()
    if camp then
        if common.check_distance(camp.X, camp.Y, mob_x, mob_y) < camp_radius then
            return true
        else
            return false
        end
    else
        if common.check_distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), mob_x, mob_y) < camp_radius then
            return true
        else
            return false
        end
    end
end

---Tank the mob whose ID is stored in common.TANK_MOB_ID.
tank.tank_mob = function()
    if state.get_tank_mob_id() == 0 then return end
    if common.am_i_dead() then return end
    local tank_spawn = mq.TLO.Spawn(state.get_tank_mob_id())
    if not tank_spawn() or tank_spawn.Type() == 'Corpse' then
        state.set_tank_mob_id(0)
        return
    end
    if not tank_mob_in_range(tank_spawn) then
        --logger.printf('tank mob not in range')
        return
    end
    if not mq.TLO.Target() then
        tank_spawn.DoTarget()
        mq.delay(50, function() return mq.TLO.Target.ID() == tank_spawn.ID() end)
    end
    if not mq.TLO.Target() then
        state.set_tank_mob_id(0)
        return
    end
    if mq.TLO.Navigation.Active() then
        mq.cmd('/squelch /nav stop')
    end
    mq.cmd('/face fast')
    if not mq.TLO.Me.Combat() then
        logger.printf('Tanking %s (%s)', mq.TLO.Target.CleanName(), state.get_tank_mob_id())
        mq.cmd('/squelch /stick front loose')-- moveback 10')
        -- /stick snaproll front moveback
        -- /stick mod -2
        mq.cmd('/attack on')
    end
end

return tank