local mq = require 'mq'
local config = require('interface.configuration')
local camp = require('routines.camp')
local helpers = require('utils.helpers')
local logger = require('utils.logger')
local movement = require('utils.movement')
local timer = require('libaqo.timer')
local mode = require('mode')
local state = require('state')

local assist = {}
local class

function assist.init(_class)
    class = _class
end

state.enrageTimer = timer:new(10000)
--|------------------------------------------------------------|
--|-  Turns off attack, when a mob you're attacking enrages.  -|
--|------------------------------------------------------------|
local function eventEnraged(line, name)
    if mq.TLO.Target.ID() == mq.TLO.Spawn(name).ID() then
        if mq.TLO.Me.Combat() then
            -- target is enraged
            mq.cmd('/squelch /face fast')
            if math.abs(mq.TLO.Me.Heading.Degrees()-mq.TLO.Target.Heading.Degrees()) > 85 and not mq.TLO.Stick.Behind() then
                --state.dontAttack = true
                mq.cmd('/attack off')
            end
        end
    end
    if mq.TLO.Pet.ID() > 0 and mq.TLO.Pet.Target.ID() == mq.TLO.Target.ID() then
        mq.cmd('/pet back')
        --state.petDontAttack = true
    end
    state.enrageTimer:reset()
end
mq.event('enrageOn', '#1# has become ENRAGED.', eventEnraged)

--|------------------------------------------------|
--|-  Turns attack back on, after enrage is over. -|
--|------------------------------------------------|
local function eventEnragedOff(line, name)
    if mq.TLO.Target.ID() == mq.TLO.Spawn(name).ID() then
        -- target is no longer enraged
        mq.cmd('/attack on')
    end
    if mq.TLO.Pet.ID() > 0 then
        mq.cmd('/pet attack')
    end
    state.dontAttack = nil
    state.petDontAttack = nil
end
mq.event('enrageOff', '#1# is no longer enraged.', eventEnragedOff)

---@return integer @Returns the spawn ID of the configured main assist, otherwise 0.
function assist.getAssistID()
    local assist_id = 0
    local assistValue = config.get('ASSIST')
    if assistValue == 'group' then
        assist_id = mq.TLO.Group.MainAssist.ID()
    elseif assistValue == 'raid1' then
        assist_id = mq.TLO.Raid.MainAssist(1).ID()
    elseif assistValue == 'raid2' then
        assist_id = mq.TLO.Raid.MainAssist(2).ID()
    elseif assistValue == 'raid3' then
        assist_id = mq.TLO.Raid.MainAssist(3).ID()
    end
    return assist_id
end

---@return spawn|integer @Returns the MQ Spawn userdata of the configured main assists current target or -1 if manual assist
function assist.getAssistSpawn()
    local assist_target = nil
    local assistValue = config.get('ASSIST')
    if assistValue == 'group' then
        assist_target = mq.TLO.Me.GroupAssistTarget
    elseif assistValue == 'raid1' then
        assist_target = mq.TLO.Me.RaidAssistTarget(1)
    elseif assistValue == 'raid2' then
        assist_target = mq.TLO.Me.RaidAssistTarget(2)
    elseif assistValue == 'raid3' then
        assist_target = mq.TLO.Me.RaidAssistTarget(3)
    else
        assist_target = -1
    end
    return assist_target
end

function assist.forceAssist(assist_id)
    if assist_id then
        state.assistMobID = assist_id
    else
        local assist_spawn = assist.getAssistSpawn()
        if assist_spawn == -1 then
            mq.cmdf('/assist %s', config.get('CHASETARGET'))
            mq.delay(100)
            state.assistMobID = mq.TLO.Target.ID()
        end
    end
end

local manualAssistTimer = timer:new(1500)
---Determine whether to begin assisting on a mob.
---Param: The MQ Spawn to be checked, otherwise the main assists target.
---@return boolean @Returns true if the spawn matches the assist criteria (within the camp radius and below autoassistat %), otherwise false.
function assist.shouldAssist(assist_target)
    if not assist_target then assist_target = assist.getAssistSpawn() end
    if not assist_target then return false end
    if assist_target == -1 then
        if mq.TLO.Target.Type() == 'NPC' then
            assist_target = mq.TLO.Target
        else
            return false
        end
    end
    local id = assist_target.ID()
    local hp = assist_target.PctHPs()
    local mob_type = assist_target.Type()
    local mob_x = assist_target.X()
    local mob_y = assist_target.Y()
    if not id or id == 0 or not hp or not mob_x or not mob_y then return false end
    if mob_type == 'NPC' and hp < config.get('AUTOASSISTAT') then
        if camp.Active and helpers.distance(camp.X, camp.Y, mob_x, mob_y) <= config.get('CAMPRADIUS')^2 then
            return true
        elseif not camp.Active and helpers.distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), mob_x, mob_y) <= config.get('CAMPRADIUS')^2 then
            return true
        else
            return false
        end
    else
        return false
    end
end

local sendPetTimer = timer:new(2000)
local stickTimer = timer:new(1000)

---Reset common combat timers to 0.
local function resetCombatTimers()
    stickTimer:reset(0)
    sendPetTimer:reset(0)
end

function assist.getAssistSpawnIncludeManual()
    local assistMobID = 0
    if mode.currentMode:getName() == 'manual' then return assistMobID end
    local assistTarget = assist.getAssistSpawn()
    -- manual assist mode hacks
    -- if mobs are on xtarget and 3sec timer is expired, try a manual assist to get target
    -- if the toon already has an npc on target (like something is hitting them), then that appears like the assist target too...
    if assistTarget == -1 then
        if mq.TLO.Me.XTarget() > 0 then
            if manualAssistTimer:expired() or not mq.TLO.Target() then
                local assistNames = helpers.split(config.get('ASSISTNAMES'), ',')
                for _,assistName in ipairs(assistNames) do
                    if mq.TLO.Spawn('pc ='..assistName)() then
                        mq.cmdf('/assist %s', assistName)
                        mq.delay(100)
                        manualAssistTimer:reset()
                        break
                    end
                end
            end
            if mq.TLO.Target.Type() == 'NPC' then
                assistMobID = mq.TLO.Target.ID()
            end
        end
    else
        assistMobID = assistTarget.ID()
    end
    return assistMobID
end

---@param assistMobID number @The Spawn ID of the target to assist on
function assist.checkMATargetSwitch(assistMobID)
    -- if we are targeting a mob, but the MA is targeting themself, then stop what we're doing
    if mq.TLO.Target.Type() == 'NPC' and assistMobID == assist.getAssistID() then
        mq.cmd('/multiline ; /target clear; /pet back; /attack off; /autofire off;')
        state.assistMobID = 0
        return false
    end
    -- If already fighting, check whether we're already on the MA's target. If not, only continue if switch with MA is enabled.
    if mq.TLO.Me.CombatState() == 'COMBAT' then
        logger.debug(logger.flags.routines.assist, "state is combat")
        if mq.TLO.Target.ID() == assistMobID then
            -- already fighting the MAs target, make sure assistMobID is accurate
            state.assistMobID = assistMobID
            return false
        elseif not config.get('SWITCHWITHMA') then
            -- not fighting the MAs target, and switch with MA is disabled, so stay on current target
            logger.debug(logger.flags.routines.assist, "checkTarget not switching targets with MA, staying on "..(mq.TLO.Target.CleanName() or ''))
            return false
        end
    end
    return true
end

---@param assistMobID number @The Spawn ID of the target to assist on
function assist.targetAssistSpawn(assistMobID)
    local assistSpawn = mq.TLO.Spawn('id '..assistMobID)
    if state.assistMobID == assistMobID and assistSpawn.Type() ~= 'Corpse' then
        -- MAs target didn't change but we aren't currently fighting it for some reason, so reacquire target
        assistSpawn.DoTarget()
    elseif assist.shouldAssist(assistSpawn) then
        -- this is a brand new assist target
        if mq.TLO.Target.ID() ~= assistMobID then
            assistSpawn.DoTarget()
            return true
        end
        return state.assistMobID ~= assistMobID
    else
        return false
    end
end

local assistAnnounced = nil
---@param assistMobID number @The Spawn ID of the target to assist on
---@param reset_timers function @An optional function to be called to reset combat timers specific to the class calling this function.
function assist.setAndAnnounceNewAssistTarget(assistMobID, reset_timers)
    state.assistMobID = assistMobID
    if mq.TLO.Me.Sitting() then mq.cmd('/stand') end
    state.resists = {}
    state.rotationIndex = nil
    resetCombatTimers()
    if reset_timers then reset_timers() end
    if state.assistMobID ~= assistAnnounced then
        logger.info('Assisting on >>> \at%s\ax <<<', mq.TLO.Target.CleanName())
        assistAnnounced = state.assistMobID
    end
end

---Acquire the correct target when running in an assist mode. Clears target if the main assist targets themself.
---Targets the main assists target if assist conditions are met.
---If currently engaged, remains on the current target unless the switch with MA option is enabled.
---Sets state.assistMobID to 0 or the ID of the mob to assist on.

---Navigate to the current target if the target is within the camp radius.
function assist.getCombatPosition()
    if mode.currentMode:getName() == 'manual' then return end
    if state.assistMobID == 0 or mq.TLO.Target.ID() ~= state.assistMobID or not assist.shouldAssist() then
        if mq.TLO.Me.Combat() then mq.cmd('/attack off') end
        return false
    end
    if mq.TLO.Target.LineOfSight() or mq.TLO.Navigation.Active() then return false end
    --
    local target_id = mq.TLO.Target.ID()
    local target_distance = mq.TLO.Target.Distance3D()
    local max_range_to = mq.TLO.Target.MaxRangeTo() or 0
    if not target_id or target_id == 0 or (target_distance and target_distance > config.get('CAMPRADIUS')) or state.paused then
        return false
    end
    movement.navToTarget('dist='..max_range_to*.6)
    state.positioning = true
    state.positioningTimer:reset()
    return true
end

---Navigate to the current target if if isn't in LOS and should be.
function assist.checkLOS()
    local cur_mode = mode.currentMode
    if (cur_mode:isTankMode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:isAssistMode() and assist.shouldAssist()) then
        local maxRangeTo = (mq.TLO.Target.MaxRangeTo() or 0) + 20
        if not mq.TLO.Target.LineOfSight() and maxRangeTo then
            movement.navToTarget('dist='..maxRangeTo*.6)
            state.positioning = true
            state.positioningTimer:reset()
        end
    end
end

function assist.engage()
    if mq.TLO.Navigation.Active() then mq.cmd('/squelch /nav stop') end
    if mode.currentMode:getName() ~= 'manual' and not mq.TLO.Stick.Active() and stickTimer:expired() then
        mq.cmd('/squelch /face fast')
        -- pin, behindonce, behind, front, !front
        local maxRangeTo = mq.TLO.Target.MaxRangeTo() or 0
        if config.get('ASSIST') == 'manual' then
            mq.cmdf('/squelch /stick snaproll moveback behind %s uw', math.min(maxRangeTo*.75, 25))
        else
            mq.cmdf('/squelch /stick !front uw')
        end
        stickTimer:reset()
    end
    if not mq.TLO.Me.Combat() and mq.TLO.Target() and not state.dontAttack then
        mq.cmd('/attack on')
    elseif state.dontAttack and state.enrageTimer:expired() then
        state.dontAttack = false
    end
end

function assist.doAssist(reset_timers, returnAfterAnnounce)
    local assistMobID = assist.getAssistSpawnIncludeManual()
    if assistMobID == 0 then return false end
    if assist.checkMATargetSwitch(assistMobID) then
        if assist.targetAssistSpawn(assistMobID) then
            assist.setAndAnnounceNewAssistTarget(assistMobID, reset_timers)
            if returnAfterAnnounce then return true end
        end
    end
    if state.assistMobID == 0 then return false end
    if not state.medding or not config.get('MEDCOMBAT') then
        if class:isAbilityEnabled('USEMELEE') then
            assist.getCombatPosition()
            if state.assistMobID and state.assistMobID > 0 and not mq.TLO.Me.Combat() and class.beforeEngage then
                class:beforeEngage()
            end
            assist.engage()
        else
            assist.checkLOS()
        end
    end
    assist.sendPet()
    return true
end

-- function assist.fsm(reset_timers)--, skip_no_los)
--     local assistMobID = assist.getAssistSpawnIncludeManual()
--     if assistMobID == 0 then return false end
--     if not assist.checkMATargetSwitch(assistMobID) then return false end
--     if not assist.targetAssistSpawn(assistMobID) then return false end
--     assist.setAndAnnounceNewAssistTarget(assistMobID, reset_timers)
--     --if not assist.six(skip_no_los) then return false end
--     --assist.seven()
-- end

---Begin attacking the assist target if not already attacking.
function assist.attack(skip_no_los)
    if mode.currentMode:getName() == 'manual' then return end
    if state.assistMobID == 0 or mq.TLO.Target.ID() ~= state.assistMobID or not assist.shouldAssist() then
        if mq.TLO.Me.Combat() then mq.cmd('/attack off') end
        return
    end
    if not mq.TLO.Target.LineOfSight() then
        if not mq.TLO.Navigation.Active() then
            -- incase this is called during bard song, to avoid mq.delay inside mq.delay
            if skip_no_los then return end
            assist.getCombatPosition()
        else
            return
        end
    end
    --movement.stop()
    if mq.TLO.Navigation.Active() then mq.cmd('/squelch /nav stop') end
    if mode.currentMode:getName() ~= 'manual' and not mq.TLO.Stick.Active() and stickTimer:expired() then
        mq.cmd('/squelch /face fast')
        -- pin, behindonce, behind, front, !front
        --mq.cmd('/stick snaproll uw')
        --mq.delay(200, function() return mq.TLO.Stick.Behind() and mq.TLO.Stick.Stopped() end)
        local maxRangeTo = mq.TLO.Target.MaxRangeTo() or 0
        --mq.cmdf('/squelch /stick hold moveback behind %s uw', math.min(maxRangeTo*.75, 25))
        if config.get('ASSIST') == 'manual' then
            mq.cmdf('/squelch /stick snaproll moveback behind %s uw', math.min(maxRangeTo*.75, 25))
        else
            mq.cmdf('/squelch /stick !front uw')
        end
        stickTimer:reset()
    end
    if not mq.TLO.Me.Combat() and mq.TLO.Target() and not state.dontAttack then
        mq.cmd('/attack on')
    elseif state.dontAttack and state.enrageTimer:expired() then
        state.dontAttack = false
    end
end

function assist.isFighting()
    local cur_mode = mode.currentMode
    local targetName = mq.TLO.Target.CleanName()
    return (cur_mode:isTankMode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:isAssistMode() and assist.shouldAssist()) or (cur_mode:isManualMode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:isManualMode() and mq.TLO.Me.Combat() and targetName and targetName:find('Combat Dummy')) or state.forceEngage
end

---Send pet and swarm pets against the assist target if assist conditions are met.
function assist.sendPet()
    local targethp = mq.TLO.Target.PctHPs()
    if sendPetTimer:expired() and targethp and targethp <= config.get('AUTOASSISTAT') then
        if assist.isFighting() then
            if mq.TLO.Pet.ID() > 0 and mq.TLO.Pet.Target.ID() ~= mq.TLO.Target.ID() and not state.petDontAttack then
                if class.summonCompanion and helpers.distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), mq.TLO.Pet.X(), mq.TLO.Pet.Y()) > 625 then
                    class.summonCompanion:use()
                end
                mq.cmd('/multiline ; /pet attack ; /pet swarm')
            else
                mq.cmd('/pet swarm')
            end
            sendPetTimer:reset()
        end
    end
end

return assist