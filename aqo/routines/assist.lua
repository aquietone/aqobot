--- @type Mq
local mq = require 'mq'
local camp = require('routines.camp')
local movement = require('routines.movement')
local logger = require('utils.logger')
local timer = require('utils.timer')
local common = require('common')
local config = require('configuration')
local state = require('state')

local assist = {}

function assist.init(aqo)

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

---Returns the MQ Spawn userdata of the configured main assists current target.
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
    elseif assistValue == 'manual' then
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

local manualAssistTimer = timer:new(3000)
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
        if camp.Active and common.checkDistance(camp.X, camp.Y, mob_x, mob_y) <= config.get('CAMPRADIUS') then
            return true
        elseif not camp.Active and common.checkDistance(mq.TLO.Me.X(), mq.TLO.Me.Y(), mob_x, mob_y) <= config.get('CAMPRADIUS') then
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

---Acquire the correct target when running in an assist mode. Clears target if the main assist targets themself.
---Targets the main assists target if assist conditions are met.
---If currently engaged, remains on the current target unless the switch with MA option is enabled.
---Sets state.assistMobID to 0 or the ID of the mob to assist on.
---@param resetTimers function @An optional function to be called to reset combat timers specific to the class calling this function.
function assist.checkTarget(resetTimers)
    if config.get('MODE'):getName() ~= 'manual' then
        local assist_target = assist.getAssistSpawn()
        local originalTargetID = mq.TLO.Target.ID()
        -- manual assist mode hacks
        -- if mobs are on xtarget and 3sec timer is expired, try a manual assist to get target
        -- if the toon already has an npc on target (like something is hitting them), then that appears like the assist target too...
        if assist_target == -1 then
            if mq.TLO.Me.XTarget() > 0 then
                if manualAssistTimer:timerExpired() or not mq.TLO.Target() then
                    local assistNames = common.split(config.get('ASSISTNAMES'), ',')
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
                    assist_target = mq.TLO.Target
                else
                    return
                end
            else
                return
            end
        end
        if not assist_target() then return end
        -- if we are targeting a mob, but the MA is targeting themself, then stop what we're doing
        if mq.TLO.Target.Type() == 'NPC' and assist_target.ID() == assist.getAssistID() then
            mq.cmd('/multiline ; /target clear; /pet back; /attack off; /autofire off;')
            state.assistMobID = 0
            return
        end
        -- If already fighting, check whether we're already on the MA's target. If not, only continue if switch with MA is enabled.
        if mq.TLO.Me.CombatState() == 'COMBAT' then
            logger.debug(logger.flags.routines.assist, "state is combat")
            if mq.TLO.Target.ID() == assist_target.ID() then
                -- already fighting the MAs target, make sure assistMobID is accurate
                state.assistMobID = assist_target.ID()
                return
            elseif not config.get('SWITCHWITHMA') then
                -- not fighting the MAs target, and switch with MA is disabled, so stay on current target
                logger.debug(logger.flags.routines.assist, "checkTarget not switching targets with MA, staying on "..(mq.TLO.Target.CleanName() or ''))
                return
            end
        end
        if state.assistMobID == assist_target.ID() and assist_target.Type() ~= 'Corpse' then
            -- MAs target didn't change but we aren't currently fighting it for some reason, so reacquire target
            assist_target.DoTarget()
            return
        end
        -- this is a brand new assist target
        if assist.shouldAssist(assist_target) then
            if mq.TLO.Target.ID() ~= assist_target.ID() then
                assist_target.DoTarget()
                if state.useStateMachine then
                    state.acquireTarget = assist_target.ID()
                    state.queuedAction = function()
                        state.assist_mob_id = assist_target.ID()
                        if mq.TLO.Me.Sitting() then mq.cmd('/stand') end
                        if mq.TLO.Target.ID() ~= originalTargetID then
                            resetCombatTimers()
                            if resetTimers then resetTimers() end
                            printf(logger.logLine('Assisting on >>> \at%s\ax <<<', mq.TLO.Target.CleanName()))
                        end
                    end
                    state.actionTaken = true
                    state.acquireTargetTimer:reset()
                    return true
                end
            end
            state.assistMobID = assist_target.ID()
            if mq.TLO.Me.Sitting() then mq.cmd('/stand') end
            if mq.TLO.Target.ID() ~= originalTargetID then
                state.resists = {}
                resetCombatTimers()
                if resetTimers then resetTimers() end
                print(logger.logLine('Assisting on >>> \at%s\ax <<<', mq.TLO.Target.CleanName()))
            end
        end
    end
end

---Navigate to the current target if the target is within the camp radius.
function assist.getCombatPosition()
    local target_id = mq.TLO.Target.ID()
    local target_distance = mq.TLO.Target.Distance3D()
    local max_range_to = mq.TLO.Target.MaxRangeTo() or 0
    if not target_id or target_id == 0 or (target_distance and target_distance > config.get('CAMPRADIUS')) or state.paused then
        return
    end
    if state.useStateMachine then
        movement.navToTarget('dist='..max_range_to*.6)
        state.positioning = true
        state.positioningTimer:reset()
    else
        movement.navToTarget(nil, 5000)
    end
end

---Navigate to the current target if if isn't in LOS and should be.
function assist.checkLOS()
    local cur_mode = config.get('MODE')
    if (cur_mode:isTankMode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:isAssistMode() and assist.shouldAssist()) then
        local maxRangeTo = (mq.TLO.Target.MaxRangeTo() or 0) + 20
        if not mq.TLO.Target.LineOfSight() and maxRangeTo then
            if state.useStateMachine then
                movement.navToTarget('dist='..maxRangeTo*.6)
                state.positioning = true
                state.positioningTimer:reset()
            else
                movement.navToTarget('dist='..maxRangeTo, 5000)
            end
        end
    end
end

---Begin attacking the assist target if not already attacking.
function assist.attack(skip_no_los)
    if config.get('MODE'):getName() == 'manual' then return end
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
    if config.get('MODE'):getName() ~= 'manual' and not mq.TLO.Stick.Active() and stickTimer:timerExpired() then
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
    elseif state.dontAttack and state.enrageTimer:timerExpired() then
        state.dontAttack = false
    end
end

function assist.isFighting()
    local cur_mode = config.get('MODE')
    return (cur_mode:isTankMode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:isAssistMode() and assist.shouldAssist()) or (cur_mode:isManualMode() and mq.TLO.Me.CombatState() == 'COMBAT')
end

---Send pet and swarm pets against the assist target if assist conditions are met.
function assist.sendPet()
    local targethp = mq.TLO.Target.PctHPs()
    if sendPetTimer:timerExpired() and targethp and targethp <= config.get('AUTOASSISTAT') then
        if assist.isFighting() then
            if mq.TLO.Pet.ID() > 0 and mq.TLO.Pet.Target.ID() ~= mq.TLO.Target.ID() and not state.petDontAttack then
                mq.cmd('/multiline ; /pet attack ; /pet swarm')
            else
                mq.cmd('/pet swarm')
            end
            sendPetTimer:reset()
        end
    end
end

return assist