--- @type Mq
local mq = require 'mq'
local config = require('interface.configuration')
local camp = require('routines.camp')
local helpers = require('utils.helpers')
local logger = require('utils.logger')
local movement = require('utils.movement')
local timer = require('utils.timer')
local mode = require('mode')
local state = require('state')

local tank = {}

function tank.init() end

local campBuffer = 20

--- Tank Functions

---Iterate through mobs in the common.TARGETS table and find a mob in camp to begin tanking.
---Sets common.tankMobID to the ID of the mob to tank.
function tank.findMobToTank()
    if state.mobCount == 0 then
        -- No mobs present to tank
        return false
    end
    if state.tankMobID > 0 and mq.TLO.Target() and mq.TLO.Target.Type() ~= 'Corpse' and state.tankMobID == mq.TLO.Target.ID() then
        -- Already actively tanking a mob
        tank.stickToMob()
        return false
    else
        state.tankMobID = 0
    end
    logger.debug(logger.flags.routines.tank, 'Find mob to tank')
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
                logger.debug(logger.flags.routines.tank, 'Selecting Named mob to tank next (%s)', mob.ID())
                state.tankMobID = mob.ID()
                return true
            else--if not mob.Mezzed() then -- TODO: mez check requires targeting
                if (mob.Level() or 0) > highestlvl then
                    highestlvlid = id
                    highestlvl = mob.Level()
                end
                if (mob.PctHPs() or 100) < lowesthp then
                    lowesthpid = id
                    lowesthp = mob.PctHPs()
                end
            end
        end
    end
    if lowesthpid ~= 0 and lowesthp < 100 then
        logger.debug(logger.flags.routines.tank, 'Selecting lowest HP mob to tank next (%s)', lowesthpid)
        state.tankMobID = lowesthpid
        return true
    elseif highestlvlid ~= 0 then
        logger.debug(logger.flags.routines.tank, 'Selecting highest level mob to tank next (%s)', highestlvlid)
        state.tankMobID = highestlvlid
        return true
    end
    -- no named or unmezzed mobs, break a mez
    if firstid ~= 0 then
        logger.debug(logger.flags.routines.tank, 'Selecting first available mob to tank next (%s)', firstid)
        state.tankMobID = firstid
        return true
    end
    return false
end

---Determine whether the target to be tanked is within the camp radius.
---@return boolean @Returns true if the target is within the camp radius, otherwise false.
local function tankMobInRange(tank_spawn)
    local mob_x = tank_spawn.X()
    local mob_y = tank_spawn.Y()
    if not mob_x or not mob_y then return false end
    local camp_radius = config.get('CAMPRADIUS')
    if mode.currentMode:isReturnToCampMode() and camp.Active then
        local dist = helpers.distance(camp.X, camp.Y, mob_x, mob_y)
        if dist < camp_radius^2 then
            return true
        else
            local targethp = tank_spawn.PctHPs()
            if targethp and targethp < 95 and dist < camp_radius+campBuffer then
                return true
            end
            return false
        end
    else
        if helpers.distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), mob_x, mob_y) < camp_radius^2 then
            return true
        else
            return false
        end
    end
end

function tank.approachMob()
    if state.tankMobID == 0 then return false end
    local tank_spawn = mq.TLO.Spawn(state.tankMobID)
    if not tank_spawn() or tank_spawn.Type() == 'Corpse' then
        state.tankMobID = 0
        return false
    end
    if not tankMobInRange(tank_spawn) then
        state.tankMobID = 0
        return false
    end
    if not tank_spawn.LineOfSight() then
        movement.navToTarget(nil, 2000)
        return true
    end
    return true
end

function tank.acquireTarget()
    if state.tankMobID == 0 then return false end
    local tank_spawn = mq.TLO.Spawn(state.tankMobID)
    if not mq.TLO.Target() or mq.TLO.Target.ID() ~= tank_spawn.ID() then
        tank_spawn.DoTarget()
    end
    return true
end

local stickTimer = timer:new(3000)
local tankAnnounced = nil
---Tank the mob whose ID is stored in common.tankMobID.
function tank.tankMob()
    --[[if state.tankMobID == 0 then return end
    local tank_spawn = mq.TLO.Spawn(state.tankMobID)
    if not tank_spawn() or tank_spawn.Type() == 'Corpse' then
        state.tankMobID = 0
        return
    end
    if not tankMobInRange(tank_spawn) then
        state.tankMobID = 0
        return
    end
    if not tank_spawn.LineOfSight() then
        movement.navToTarget(nil, 2000)
        return
    end
    if not mq.TLO.Target() or mq.TLO.Target.ID() ~= tank_spawn.ID() then
        tank_spawn.DoTarget()
    end]]
    if not mq.TLO.Target() or mq.TLO.Target.Type() == 'Corpse' then
        state.tankMobID = 0
        return false
    end
    --movement.stop()
    if mq.TLO.Navigation.Active() then mq.cmd('/squelch /nav stop') end
    mq.cmd('/multiline ; /stand ; /squelch /face fast')
    if not mq.TLO.Me.Combat() and not state.dontAttack then
        if state.tankMobID ~= tankAnnounced then
            logger.info('Tanking \at%s\ax (\at%s\ax)', mq.TLO.Target.CleanName(), state.tankMobID)
            tankAnnounced = state.tankMobID
        end
        -- /stick snaproll front moveback
        -- /stick mod -2
        state.resists = {}
        mq.cmd('/attack on')
        stickTimer:reset(0)
    elseif state.dontAttack and state.enrageTimer:timerExpired() then
        state.dontAttack = false
    end
    return true
    --[[if mq.TLO.Me.Combat() and stickTimer:timerExpired() and not mq.TLO.Stick.Active() and mode.currentMode:getName() ~= 'manual' then
        mq.cmd('/squelch /stick front loose moveback 10')
        stickTimer:reset()
    end]]
end

function tank.stickToMob()
    if mq.TLO.Me.Combat() and stickTimer:timerExpired() and not mq.TLO.Stick.Active() and mode.currentMode:getName() ~= 'manual' then
        mq.cmd('/squelch /stick front loose moveback 10')
        stickTimer:reset()
    end
end

return tank