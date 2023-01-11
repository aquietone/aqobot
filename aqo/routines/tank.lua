--- @type Mq
local mq = require 'mq'
local camp = require('routines.camp')
local movement = require('routines.movement')
local common = require('common')
local config = require('configuration')
local logger = require('utils.logger')
local timer = require('utils.timer')
local state = require('state')

local tank = {}

local camp_buffer = 20

--- Tank Functions

---Iterate through mobs in the common.TARGETS table and find a mob in camp to begin tanking.
---Sets common.TANK_MOB_ID to the ID of the mob to tank.
tank.find_mob_to_tank = function()
    if state.mob_count == 0 then return end
    if state.tank_mob_id > 0 and mq.TLO.Target() and mq.TLO.Target.Type() ~= 'Corpse' and state.tank_mob_id == mq.TLO.Target.ID() then
        return
    else
        state.tank_mob_id = 0
    end
    logger.debug(logger.log_flags.routines.tank, 'Find mob to tank')
    local highestlvl = 0
    local highestlvlid = 0
    local lowesthp = 100
    local lowesthpid = 0
    local firstid = 0
    for id,_ in pairs(state.targets) do
        -- loop through for named, highest level, unmezzed, lowest hp
        local mob = mq.TLO.Spawn(id)
        if mob() then
            if firstid == 0 then firstid = mob.ID() end
            if mob.Named() then
                logger.debug(logger.log_flags.routines.tank, 'Selecting Named mob to tank next (%s)', mob.ID())
                state.tank_mob_id = mob.ID()
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
        logger.debug(logger.log_flags.routines.tank, 'Selecting lowest HP mob to tank next (%s)', lowesthpid)
        state.tank_mob_id = lowesthpid
        return
    elseif highestlvlid ~= 0 then
        logger.debug(logger.log_flags.routines.tank, 'Selecting highest level mob to tank next (%s)', highestlvlid)
        state.tank_mob_id = highestlvlid
        return
    end
    -- no named or unmezzed mobs, break a mez
    if firstid ~= 0 then
        logger.debug(logger.log_flags.routines.tank, 'Selecting first available mob to tank next (%s)', firstid)
        state.tank_mob_id = firstid
        return
    end
end

---Determine whether the target to be tanked is within the camp radius.
---@return boolean @Returns true if the target is within the camp radius, otherwise false.
local function tank_mob_in_range(tank_spawn)
    local mob_x = tank_spawn.X()
    local mob_y = tank_spawn.Y()
    if not mob_x or not mob_y then return false end
    local camp_radius = config.CAMPRADIUS
    if config.MODE:return_to_camp() and camp.Active then
        local dist = common.check_distance(camp.X, camp.Y, mob_x, mob_y)
        if dist < camp_radius then
            return true
        else
            local targethp = tank_spawn.PctHPs()
            if targethp and targethp < 95 and dist < camp_radius+camp_buffer then
                return true
            end
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

local stick_timer = timer:new(3)
---Tank the mob whose ID is stored in common.TANK_MOB_ID.
tank.tank_mob = function()
    if state.tank_mob_id == 0 then return end
    local tank_spawn = mq.TLO.Spawn(state.tank_mob_id)
    if not tank_spawn() or tank_spawn.Type() == 'Corpse' then
        state.tank_mob_id = 0
        return
    end
    if not tank_mob_in_range(tank_spawn) or not tank_spawn.LineOfSight() then
        ---- los around benches and junk
        --if config.MODE:get_name() == 'huntertank' and not mq.TLO.Navigation.Active() then
        --    mq.cmdf('/nav id %s | log=off', state.tank_mob_id)
        --end
        state.tank_mob_id = 0
        return
    end
    if not mq.TLO.Target() or mq.TLO.Target.ID() ~= tank_spawn.ID() then
        tank_spawn.DoTarget()
    end
    if not mq.TLO.Target() or mq.TLO.Target.Type() == 'Corpse' then
        state.tank_mob_id = 0
        return
    end
    movement.stop()
    mq.cmd('/multiline ; /stand ; /squelch /face fast')
    if not mq.TLO.Me.Combat() and not state.dontAttack then
        printf(logger.logLine('Tanking \at%s\ax (\at%s\ax)', mq.TLO.Target.CleanName(), state.tank_mob_id))
        -- /stick snaproll front moveback
        -- /stick mod -2
        mq.cmd('/attack on')
        stick_timer:reset(0)
    elseif state.dontAttack and state.enrageTimer:timer_expired() then
        state.dontAttack = false
    end
    if mq.TLO.Me.Combat() and stick_timer:timer_expired() and not mq.TLO.Stick.Active() and config.MODE:get_name() ~= 'manual' then
        mq.cmd('/squelch /stick front loose moveback 10')
        stick_timer:reset()
    end
end

return tank