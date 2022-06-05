--- @type mq
local mq = require 'mq'
local config = require('aqo.configuration')
local logger = require('aqo.utils.logger')
local timer = require('aqo.utils.timer')
local common = require('aqo.common')
local state = require('aqo.state')

local assist = {}

--- Assist Functions

---Get the spawn ID of the configured main assist, NOT the assists target.
---@return integer @Returns the spawn ID of the main assist, NOT the assists target.
assist.get_assist_id = function()
    local assist_id = 0
    local assist = config.get_assist()
    if assist == 'group' then
        assist_id = mq.TLO.Group.MainAssist.ID()
    elseif assist == 'raid1' then
        assist_id = mq.TLO.Raid.MainAssist(1).ID()
    elseif assist == 'raid2' then
        assist_id = mq.TLO.Raid.MainAssist(2).ID()
    elseif assist == 'raid3' then
        assist_id = mq.TLO.Raid.MainAssist(3).ID()
    end
    return assist_id
end

---Get the MQ Spawn of the configured main assists current target.
---@return Spawn @Returns the MQ Spawn userdata of the assists target.
assist.get_assist_spawn = function()
    local assist_target = nil
    local assist = config.get_assist()
    if assist == 'group' then
        assist_target = mq.TLO.Me.GroupAssistTarget
    elseif assist == 'raid1' then
        assist_target = mq.TLO.Me.RaidAssistTarget(1)
    elseif assist == 'raid2' then
        assist_target = mq.TLO.Me.RaidAssistTarget(2)
    elseif assist == 'raid3' then
        assist_target = mq.TLO.Me.RaidAssistTarget(3)
    end
    return assist_target
end

---Determine whether to begin assisting on a mob.
---@param assist_target Spawn @The MQ Spawn currently targeted by the main assist.
---@return boolean @Returns true if the spawn matches the assist criteria, otherwise false.
assist.should_assist = function(assist_target)
    if not assist_target then assist_target = assist.get_assist_spawn() end
    if not assist_target then return false end
    local id = assist_target.ID()
    local hp = assist_target.PctHPs()
    local mob_type = assist_target.Type()
    local mob_x = assist_target.X()
    local mob_y = assist_target.Y()
    if not id or id == 0 or not hp or hp == 0 or not mob_x or not mob_y then return false end
    local camp = state.get_camp()
    local camp_radius = config.get_camp_radius()
    if mob_type == 'NPC' and hp < config.get_auto_assist_at() then
        if camp and common.check_distance(camp.X, camp.Y, mob_x, mob_y) <= camp_radius then
            return true
        elseif not camp and common.check_distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), mob_x, mob_y) <= camp_radius then
            return true
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
---Sets common.ASSIST_TARGET_ID to 0 or the ID of the mob to assist on.
---@param reset_timers function @An optional function to be called to reset combat timers specific to the class calling this function.
assist.check_target = function(reset_timers)
    if common.am_i_dead() then return end
    if config.get_mode():get_name() ~= 'manual' then
        local assist_target = assist.get_assist_spawn()
        if not assist_target() then return end
        if mq.TLO.Target() and mq.TLO.Target.Type() == 'NPC' and assist_target.ID() == assist.get_assist_id() then
            -- if we are targeting a mob, but the MA is targeting themself, then stop what we're doing
            mq.cmd('/multiline ; /target clear; /pet back; /attack off; /autofire off;')
            state.set_assist_mob_id(0)
            return
        end
        if common.is_fighting() then
            -- already fighting
            if mq.TLO.Target.ID() == assist_target.ID() then
                -- already fighting the MAs target
                state.set_assist_mob_id(assist_target.ID())
                return
            elseif not config.get_switch_with_ma() then
                -- not fighting the MAs target, and switch with MA is disabled, so stay on current target
                return
            end
        end
        if state.get_assist_mob_id() == assist_target.ID() and assist_target.Type() ~= 'Corpse' then
            -- MAs target didn't change but we aren't currently fighting it for some reason, so reacquire target
            assist_target.DoTarget()
            return
        end
        if mq.TLO.Target.ID() ~= assist_target.ID() and assist.should_assist(assist_target) then
            -- this is a brand new assist target
            state.set_assist_mob_id(assist_target.ID())
            assist_target.DoTarget()
            if mq.TLO.Me.Sitting() then mq.cmd('/stand') end
            reset_combat_timers()
            if reset_timers then reset_timers() end
            logger.printf('Assisting on >>> \ay%s\ax <<<', mq.TLO.Target.CleanName())
        end
    end
end

---Navigate to the current target if the target is within the camp radius.
assist.get_combat_position = function()
    local target_id = mq.TLO.Target.ID()
    local target_distance = mq.TLO.Target.Distance3D()
    if not target_id or target_id == 0 or (target_distance and target_distance > config.get_camp_radius()) or state.get_paused() then
        return
    end
    mq.cmdf('/nav id %d log=off', target_id)
    local begin_time = timer.current_time()
    while true do
        if mq.TLO.Target.LineOfSight() then
            mq.cmd('/squelch /nav stop')
            break
        end
        if os.difftime(begin_time, timer.current_time()) > 5 then
            break
        end
        mq.delay(1)
    end
    if mq.TLO.Navigation.Active() then mq.cmd('/squelch /nav stop') end
end

---Navigate to the current target if if isn't in LOS and should be.
assist.check_los = function()
    if config.get_mode():get_name() ~= 'manual' and (common.is_fighting() or assist.should_assist()) then
        if not mq.TLO.Target.LineOfSight() and not mq.TLO.Navigation.Active() then
            mq.cmd('/nav target log=off')
        end
    end
end

---Begin attacking the assist target if not already attacking.
assist.attack = function()
    if state.get_assist_mob_id() == 0 or mq.TLO.Target.ID() ~= state.get_assist_mob_id() or not assist.should_assist() then
        if mq.TLO.Me.Combat() then mq.cmd('/attack off') end
        return
    end
    if not mq.TLO.Target.LineOfSight() then assist.get_combat_position() end
    if mq.TLO.Navigation.Active() then
        mq.cmd('/squelch /nav stop')
    end
    if config.get_mode():get_name() ~= 'manual' and not mq.TLO.Stick.Active() and stick_timer:timer_expired() then
        --mq.cmd('/squelch /stick loose moveback 10 uw')
        mq.cmd('/squelch /stick snaproll rear moveback 10 uw')
        stick_timer:reset()
    end
    if not mq.TLO.Me.Combat() and mq.TLO.Target() then
        mq.cmd('/attack on')
    end
end

---Send pet and swarm pets against the assist target if assist conditions are met.
assist.send_pet = function()
    if send_pet_timer:timer_expired() and (common.is_fighting() or assist.should_assist()) then
        if mq.TLO.Pet.ID() > 0 and mq.TLO.Pet.Target.ID() ~= mq.TLO.Target.ID() then
            mq.cmd('/multiline ; /pet attack ; /pet swarm')
        else
            mq.cmd('/pet swarm')
        end
        send_pet_timer:reset()
    end
end

return assist