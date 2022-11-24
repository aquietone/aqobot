--- @type Mq
local mq = require 'mq'
local camp = require(AQO..'.routines.camp')
local config = require(AQO..'.configuration')
local logger = require(AQO..'.utils.logger')
local timer = require(AQO..'.utils.timer')
local common = require(AQO..'.common')
local state = require(AQO..'.state')

local assist = {}

state.enrageTimer = timer:new(10)
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
assist.get_assist_id = function()
    local assist_id = 0
    if config.ASSIST == 'group' then
        assist_id = mq.TLO.Group.MainAssist.ID()
    elseif config.ASSIST == 'raid1' then
        assist_id = mq.TLO.Raid.MainAssist(1).ID()
    elseif config.ASSIST == 'raid2' then
        assist_id = mq.TLO.Raid.MainAssist(2).ID()
    elseif config.ASSIST == 'raid3' then
        assist_id = mq.TLO.Raid.MainAssist(3).ID()
    end
    return assist_id
end

---@return spawn @Returns the MQ Spawn userdata of the configured main assists current target.
assist.get_assist_spawn = function()
    local assist_target = nil
    if config.ASSIST == 'group' then
        assist_target = mq.TLO.Me.GroupAssistTarget
    elseif config.ASSIST == 'raid1' then
        assist_target = mq.TLO.Me.RaidAssistTarget(1)
    elseif config.ASSIST == 'raid2' then
        assist_target = mq.TLO.Me.RaidAssistTarget(2)
    elseif config.ASSIST == 'raid3' then
        assist_target = mq.TLO.Me.RaidAssistTarget(3)
    elseif config.ASSIST == 'manual' then
        assist_target = -1
    end
    return assist_target
end

local manual_assist_timer = timer:new(3)
---Determine whether to begin assisting on a mob.
---@param assist_target spawn|nil @The MQ Spawn to be checked, otherwise the main assists target.
---@return boolean @Returns true if the spawn matches the assist criteria (within the camp radius and below autoassistat %), otherwise false.
assist.should_assist = function(assist_target)
    if not assist_target then assist_target = assist.get_assist_spawn() end
    if not assist_target then return false end
    if assist_target == -1 then
        if mq.TLO.Target.Type() == 'NPC' then
            assist_target = mq.TLO.Target
        else
            return false
        end
    end
    --[[if assist_target == -1 and manual_assist_timer:timer_expired() then
        if mq.TLO.Target.Type() ~= 'NPC' then
            mq.cmdf('/assist %s', config.CHASETARGET)
            mq.delay(100)
        end
        if mq.TLO.Target.Type() == 'NPC' then
            assist_target = mq.TLO.Target
        else
            return false
        end
    end]]
    local id = assist_target.ID()
    local hp = assist_target.PctHPs()
    local mob_type = assist_target.Type()
    local mob_x = assist_target.X()
    local mob_y = assist_target.Y()
    if not id or id == 0 or not hp or hp == 0 or not mob_x or not mob_y then return false end
    if mob_type == 'NPC' and hp < config.AUTOASSISTAT then
        if camp.Active and common.check_distance(camp.X, camp.Y, mob_x, mob_y) <= config.CAMPRADIUS then
            return true
        elseif not camp.Active and common.check_distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), mob_x, mob_y) <= config.CAMPRADIUS then
            return true
        else
            return false
        end
    else
        return false
    end
end

local send_pet_timer = timer:new(5)
local stick_timer = timer:new(3)

---Reset common combat timers to 0.
local function reset_combat_timers()
    stick_timer:reset(0)
    send_pet_timer:reset(0)
end

---Acquire the correct target when running in an assist mode. Clears target if the main assist targets themself.
---Targets the main assists target if assist conditions are met.
---If currently engaged, remains on the current target unless the switch with MA option is enabled.
---Sets state.assist_mob_id to 0 or the ID of the mob to assist on.
---@param reset_timers function @An optional function to be called to reset combat timers specific to the class calling this function.
assist.check_target = function(reset_timers)
    if common.am_i_dead() then return end
    if config.MODE:get_name() ~= 'manual' then
        local assist_target = assist.get_assist_spawn()
        local originalTargetID = mq.TLO.Target.ID()
        -- manual assist mode hacks
        -- if mobs are on xtarget and 3sec timer is expired, try a manual assist to get target
        -- if the toon already has an npc on target (like something is hitting them), then that appears like the assist target too...
        if assist_target == -1 then
            if manual_assist_timer:timer_expired() and mq.TLO.Me.XTarget() > 0 then
                mq.cmdf('/assist %s', config.CHASETARGET)
                mq.delay(100)
                manual_assist_timer:reset()
            end
            if mq.TLO.Target.Type() == 'NPC' then
                assist_target = mq.TLO.Target
            else
                return
            end
        end
        if not assist_target() then return end
        -- if we are targeting a mob, but the MA is targeting themself, then stop what we're doing
        if mq.TLO.Target.Type() == 'NPC' and assist_target.ID() == assist.get_assist_id() then
            mq.cmd('/multiline ; /target clear; /pet back; /attack off; /autofire off;')
            state.assist_mob_id = 0
            return
        end
        -- If already fighting, check whether we're already on the MA's target. If not, only continue if switch with MA is enabled.
        if mq.TLO.Me.CombatState() == 'COMBAT' then
            logger.debug(logger.log_flags.routines.assist, "state is combat")
            if mq.TLO.Target.ID() == assist_target.ID() then
                -- already fighting the MAs target, make sure assist_mob_id is accurate
                state.assist_mob_id = assist_target.ID()
                return
            elseif not config.SWITCHWITHMA then
                -- not fighting the MAs target, and switch with MA is disabled, so stay on current target
                logger.debug(logger.log_flags.routines.assist, "check_target not switching targets with MA, staying on "..(mq.TLO.Target.CleanName() or ''))
                return
            end
        end
        if state.assist_mob_id == assist_target.ID() and assist_target.Type() ~= 'Corpse' then
            -- MAs target didn't change but we aren't currently fighting it for some reason, so reacquire target
            assist_target.DoTarget()
            return
        end
        -- this is a brand new assist target
        --if mq.TLO.Target.ID() ~= assist_target.ID() and assist.should_assist(assist_target) then
        if assist.should_assist(assist_target) then
            if mq.TLO.Target.ID() ~= assist_target.ID() then
                assist_target.DoTarget()
                mq.delay(100, function() return mq.TLO.Target.ID() == assist_target.ID() end)
            end
            state.assist_mob_id = assist_target.ID()
            if mq.TLO.Me.Sitting() then mq.cmd('/stand') end
            if mq.TLO.Target.ID() ~= originalTargetID then
                reset_combat_timers()
                if reset_timers then reset_timers() end
                logger.printf('Assisting on >>> \at%s\ax <<<', mq.TLO.Target.CleanName())
            end
        end
    end
end

---Navigate to the current target if the target is within the camp radius.
assist.get_combat_position = function()
    local target_id = mq.TLO.Target.ID()
    local target_distance = mq.TLO.Target.Distance3D()
    if not target_id or target_id == 0 or (target_distance and target_distance > config.CAMPRADIUS) or state.paused then
        return
    end
    if not mq.TLO.Navigation.PathExists('target')() then return end
    mq.cmd('/multiline ; /stick off ; /nav target log=off')
    mq.delay(100)
    local position_timer = timer:new(5)
    while true do
        if mq.TLO.Target.LineOfSight() then
            break
        end
        if position_timer:timer_expired() then
            break
        end
        mq.delay(100)
    end
    if mq.TLO.Navigation.Active() then mq.cmd('/squelch /nav stop') end
end

---Navigate to the current target if if isn't in LOS and should be.
assist.check_los = function()
    local cur_mode = config.MODE
    if (cur_mode:is_tank_mode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:is_assist_mode() and assist.should_assist()) then
        if not mq.TLO.Target.LineOfSight() and not mq.TLO.Navigation.Active() and mq.TLO.Navigation.PathExists('target')() then
            mq.cmd('/multiline ; /stick off ; /nav target log=off')
        end
    end
end

---Begin attacking the assist target if not already attacking.
assist.attack = function(skip_no_los)
    if config.MODE:get_name() == 'manual' then return end
    if state.assist_mob_id == 0 or mq.TLO.Target.ID() ~= state.assist_mob_id or not assist.should_assist() then
        if mq.TLO.Me.Combat() then mq.cmd('/attack off') end
        return
    end
    if not mq.TLO.Target.LineOfSight() and not mq.TLO.Navigation.Active() then
        -- incase this is called during bard song, to avoid mq.delay inside mq.delay
        if skip_no_los then return end
        assist.get_combat_position()
    end
    -- check_los may have nav running already.. why separate get_combat_position and check_los???
    if not mq.TLO.Target.LineOfSight() and mq.TLO.Navigation.Active() then return end
    if mq.TLO.Navigation.Active() then
        mq.cmd('/squelch /nav stop')
    end
    if config.MODE:get_name() ~= 'manual' and not mq.TLO.Stick.Active() and stick_timer:timer_expired() then
        mq.cmd('/squelch /stick loose behind moveback 10 uw')
        stick_timer:reset()
    end
    if not mq.TLO.Me.Combat() and mq.TLO.Target() and not state.dontAttack then
        mq.cmd('/attack on')
    elseif state.dontAttack and state.enrageTimer:timer_expired() then
        state.dontAttack = false
    end
end

assist.is_fighting = function()
    local cur_mode = config.MODE
    return (cur_mode:is_tank_mode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:is_assist_mode() and assist.should_assist()) or (cur_mode:is_manual_mode() and mq.TLO.Me.CombatState() == 'COMBAT')
end

---Send pet and swarm pets against the assist target if assist conditions are met.
assist.send_pet = function()
    local targethp = mq.TLO.Target.PctHPs()
    if send_pet_timer:timer_expired() and targethp and targethp <= config.AUTOASSISTAT then
        if assist.is_fighting() then
            if mq.TLO.Pet.ID() > 0 and mq.TLO.Pet.Target.ID() ~= mq.TLO.Target.ID() and not state.petDontAttack then
                mq.cmd('/multiline ; /pet attack ; /pet swarm')
            else
                mq.cmd('/pet swarm')
            end
            send_pet_timer:reset()
        end
    end
end

return assist