--- @type mq
local mq = require 'mq'
local common = require('aqo.common')
local config = require('aqo.configuration')
local logger = require('aqo.utils.logger')
local timer = require('aqo.utils.timer')
local state = require('aqo.state')

local pull = {}

-- Pull Functions

local PULL_TARGET_SKIP = {}

-- mob at 135, SE
-- pull arc left 90
-- pull arc right 180

-- false invalid, true valid
---Determine whether the pull spawn is within the configured pull arc, if there is one.
---@param pull_spawn Spawn @The MQ Spawn to check.
---@return boolean @Returns true if the spawn is within the pull arc, otherwise false.
local function check_mob_angle(pull_spawn)
    local pull_arc = config.get_pull_arc()
    if pull_arc == 360 or pull_arc == 0 then return true end
    local camp = state.get_camp()
    -- TODO: pull arcs without camp set???
    if not camp then return true end
    local direction_to_mob = pull_spawn.HeadingTo(camp.Y, camp.X).Degrees()
    if not direction_to_mob then return false end
    -- switching from non-puller mode to puller mode, the camp may not be updated yet
    if not camp.PULL_ARC_LEFT or not camp.PULL_ARC_RIGHT then return false end
    logger.debug(state.get_debug(), 'arcleft: %s, arcright: %s, dirtomob: %s', camp.PULL_ARC_LEFT, camp.PULL_ARC_RIGHT, direction_to_mob)
    if camp.PULL_ARC_LEFT >= camp.PULL_ARC_RIGHT then
        if direction_to_mob < camp.PULL_ARC_LEFT and direction_to_mob > camp.PULL_ARC_RIGHT then return false end
    else
        if direction_to_mob < camp.PULL_ARC_LEFT or direction_to_mob > camp.PULL_ARC_RIGHT then return false end
    end
    return true
end

-- z check done separately so that high and low values can be different
---Determine whether the pull spawn is within the configured Z high and Z low values.
---@param pull_spawn Spawn @The MQ Spawn to check.
---@return boolean @Returns true if the spawn is within the Z high and Z low, otherwise false.
local function check_z_rad(pull_spawn)
    local mob_z = pull_spawn.Z()
    if not mob_z then return false end
    local camp = state.get_camp()
    if camp then
        if mob_z > camp.Z+config.get_pull_z_high() or mob_z < camp.Z-config.get_pull_z_low() then return false end
    else
        if mob_z > mq.TLO.Me.Z()+config.get_pull_z_high() or mob_z < mq.TLO.Me.Z()-config.get_pull_z_low() then return false end
    end
    return true
end

---Determine whether the pull spawn is within the configured pull level range.
---@param pull_spawn Spawn @The MQ Spawn to check.
---@return boolean @Returns true if the spawn is within the configured level range, otherwise false.
local function check_level(pull_spawn)
    if config.get_pull_min_level() == 0 and config.get_pull_max_level() == 0 then return true end
    local mob_level = pull_spawn.Level()
    if not mob_level then return false end
    if mob_level >= config.get_pull_min_level() and mob_level <= config.get_pull_max_level() then return true end
    return false
end

---Validate that the spawn is good for pulling
---@param pull_spawn Spawn @The MQ Spawn to validate.
---@param path_len number @The navigation path length to the spawn.
---@param zone_sn string @The current zone short name.
---@return boolean @Returns true if the spawn meets all the criteria for pulling, otherwise false.
local function validate_pull(pull_spawn, path_len, zone_sn)
    local mob_id = pull_spawn.ID()
    if mob_id == 0 or PULL_TARGET_SKIP[mob_id] or pull_spawn.Type() == 'Corpse' then return false end
    if path_len < 0 or path_len > config.get_pull_radius() then return false end
    if check_mob_angle(pull_spawn) and check_z_rad(pull_spawn) and check_level(pull_spawn) and not config.ignores_contains(zone_sn, pull_spawn.CleanName()) then
        return true
    end
    return false
end

local medding = false
local healers = {CLR=true,DRU=true,SHM=true}
pull.check_pull_conditions = function()
    if common.am_i_dead() then return false end
    if config.get_group_watch_who() == 'none' then return true end
    if config.get_group_watch_who() == 'self' then
        if mq.TLO.Me.PctEndurance() < config.get_med_end_start() or mq.TLO.Me.PctMana() < config.get_med_mana_start() then
            medding = true
            return false
        end
        if (mq.TLO.Me.PctEndurance() < config.get_med_end_stop() or mq.TLO.Me.PctMana() < config.get_med_mana_stop()) and medding then
            return false
        else
            medding = false
        end
    end
    if mq.TLO.Group.Members() then
        for i=1,mq.TLO.Group.Members() do
            local member = mq.TLO.Group.Member(i)
            if member then
                local pctmana = member.PctMana()
                if member.Dead() then
                    return false
                elseif healers[member.Class.ShortName()] and config.get_group_watch_who() == 'healer' and pctmana then
                    if pctmana < config.get_med_mana_stop() then
                        medding = true
                        return false
                    end
                    if pctmana < config.get_med_mana_start() and medding then
                        return false
                    else
                        medding = false
                    end
                end
            end
        end
    end
    return true
end

--loc ${s_WorkSpawn.X} ${s_WorkSpawn.Y}
local pull_count = 'npc nopet radius %d'-- zradius 50'
local pull_spawn = '%d, npc nopet radius %d'-- zradius 50'
local pull_count_camp = 'npc nopet loc %d %d radius %d'-- zradius 50'
local pull_spawn_camp = '%d, npc nopet loc %d %d radius %d'-- zradius 50'
local pc_near = 'pc radius 30 loc %d %d'
---Search for pullable mobs within the configured pull radius.
---Sets common.PULL_MOB_ID to the mob ID of the first matching spawn.
local pull_radar_timer = timer:new(3)
pull.pull_radar = function()
    if not pull_radar_timer:timer_expired() then return end
    pull_radar_timer:reset()
    local pull_radius_count
    local pull_radius = config.get_pull_radius()
    local camp = state.get_camp()
    if camp then
        pull_radius_count = mq.TLO.SpawnCount(pull_count_camp:format(camp.X, camp.Y, pull_radius))()
    else
        pull_radius_count = mq.TLO.SpawnCount(pull_count:format(pull_radius))()
    end
    local shortest_path = pull_radius
    local pull_id = 0
    if pull_radius_count > 0 then
        local zone_sn = mq.TLO.Zone.ShortName()
        for i=1,pull_radius_count do
            -- try not to iterate through the whole world if there's a pretty large pull radius
            if i > 100 then break end
            local mob
            if camp then
                mob = mq.TLO.NearestSpawn(pull_spawn_camp:format(i, camp.X, camp.Y, pull_radius))
            else
                mob = mq.TLO.NearestSpawn(pull_spawn:format(i, pull_radius))
            end
            local path_len = mq.TLO.Navigation.PathLength('id '..mob.ID())()
            if validate_pull(mob, path_len, zone_sn) then
                -- TODO: check for people nearby, check level, check z radius if high/low differ
                --local pc_near_count = mq.TLO.SpawnCount(pc_near:format(mob.X(), mob.Y()))
                --if pc_near_count == 0 then
                local dist3d = mob.Distance3D()
                if mob.LineOfSight() or (dist3d and path_len < dist3d+50) then
                    -- don't bother to check path length if mob already in los.
                    -- if path length is within 50 of distance3d then its probably safe to pull also
                    state.set_pull_mob_id(mob.ID())
                    return mob.ID()
                elseif path_len < shortest_path then
                    shortest_path = path_len
                    pull_id = mob.ID()
                end
            end
        end
    end
    if pull_id ~= 0 then
        state.set_pull_mob_id(pull_id)
    end
    return pull_id
end

---Navigate to the pull spawn. Stop when it is within bow distance and line of sight, or when within melee distance.
---@param pull_spawn Spawn @The MQ Spawn to navigate to.
---@return boolean @Returns false if the pull spawn became invalid during navigation, otherwise true.
local function pull_nav_to(pull_spawn)
    local mob_x = pull_spawn.X()
    local mob_y = pull_spawn.Y()
    local mob_z = pull_spawn.Z()
    if not mob_x or not mob_y or not mob_z then
        clear_pull_vars()
        return false
    end
    logger.printf('Pulling \ay%s\ax (\at%s\ax)', pull_spawn.CleanName(), pull_spawn.ID())
    if common.check_distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), mob_x, mob_y) > 10 then
        logger.debug(state.get_debug(), 'Moving to pull target (%s)', state.get_pull_mob_id())
        --if not mq.TLO.Navigation.Active() and mq.TLO.Navigation.PathExists(string.format('id %d', state.get_pull_mob_id()))() then
        if mq.TLO.Navigation.PathExists(string.format('id %d', state.get_pull_mob_id()))() then
            mq.cmdf('/nav spawn id %d | dist=15 log=off', state.get_pull_mob_id())
            mq.delay(100, function() return mq.TLO.Navigation.Active() end)
        end
    end
    return true
end

local function pull_approaching(pull_spawn)
    if not pull_spawn or not mq.TLO.Navigation.Active() then
        return true
    end
    local dist3d = pull_spawn.Distance3D()
    -- return right away if we can't read distance, as pull spawn is probably no longer valid
    if not dist3d then return true end
    -- return true once target is in range and in LOS, or if something appears on xtarget
    return (pull_spawn.LineOfSight() and dist3d < 200) or dist3d < 15 or common.hostile_xtargets()
end

---Reset common mob ID variables to 0 to reset pull status.
local function clear_pull_vars()
    state.set_pull_mob_id(0)
    state.set_pull_in_progress(nil)
end

---Aggro the specified target to be pulled. Attempts to use bow and moves closer to melee pull if necessary.
---@param pull_spawn Spawn @The MQ Spawn to be pulled.
---@param pull_func function @The function to use to ranged pull.
local function pull_engage(pull_spawn, pull_func)
    -- pull  mob
    local pull_mob_id = state.get_pull_mob_id()
    local dist3d = pull_spawn.Distance3D()
    if not dist3d then
        logger.printf('\arPull target no longer valid \ax(\at%s\ax)', pull_mob_id)
        clear_pull_vars()
        return false
    end
    if not pull_spawn.LineOfSight() or dist3d > 200 then
        state.set_pull_in_progress(common.PULL_STATES.APPROACHING)
        pull_nav_to(pull_spawn)
        return false
    end
    pull_spawn.DoTarget()
    mq.delay(50, function() return mq.TLO.Target.ID() == pull_spawn.ID() end)
    if not mq.TLO.Target() then
        logger.printf('\arPull target no longer valid \ax(\at%s\ax)', pull_mob_id)
        clear_pull_vars()
        return false
    end
    local tot_id = mq.TLO.Me.TargetOfTarget.ID()
    local targethp = mq.TLO.Target.PctHPs()
    --if (tot_id > 0 and tot_id ~= mq.TLO.Me.ID()) or (targethp and targethp < 100) then --or mq.TLO.Target.PctHPs() < 100 then
    if targethp and targethp < 99 then
        logger.printf('\arPull target already engaged, skipping \ax(\at%s\ax) %s %s %s', pull_mob_id, tot_id, mq.TLO.Me.ID(), targethp)
        -- TODO: clear skip targets
        PULL_TARGET_SKIP[pull_mob_id] = 1
        clear_pull_vars()
        return false
    end
    if mq.TLO.Navigation.Active() then
        mq.cmd('/squelch /nav stop')
        mq.delay(100, function() return not mq.TLO.Navigation.Active() end)
    end
    mq.cmd('/squelch /face fast')
    --logger.printf('agroing mob')
    if mq.TLO.Target.Distance3D() < 35 then
        -- use class close range pull ability
        mq.cmd('/squelch /stick front loose moveback 10')
        -- /stick mod 0
        mq.cmd('/attack on')
        mq.delay(5000, function() return mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID() or common.hostile_xtargets() end)
    else
        if mq.TLO.Me.Combat() then
            mq.cmd('/attack off')
            mq.delay(100)
        end
        if pull_func then
            pull_func()
        else
            mq.cmd('/autofire on')
            mq.delay(1000)
            if not mq.TLO.Me.AutoFire() then
                mq.cmd('/autofire on')
            end
        end
        -- use class long range pull ability
        -- tag with range
        mq.delay(1000, function() return mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID() or common.hostile_xtargets() end)
    end
    --logger.printf('mob agrod or timed out')
    mq.cmd('/multiline ; /attack off; /autofire off; /stick off;')
    return mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID() or common.hostile_xtargets()
end

---Return to camp and wait for the pull target to arrive in camp. Stops early if adds appear on xtarget.
local function pull_return()
    --logger.printf('Bringing pull target back to camp (%s)', common.PULL_MOB_ID)
    local camp = state.get_camp()
    if not mq.TLO.Navigation.Active() and mq.TLO.Navigation.PathExists(string.format('locyxz %d %d %d', camp.Y, camp.X, camp.Z))() then
        mq.cmdf('/nav locyxz %d %d %d log=off', camp.Y, camp.X, camp.Z)
        mq.delay(50, function() return mq.TLO.Navigation.Active() end)
    end
end

---Attempt to pull the mob whose ID is stored in common.PULL_MOB_ID.
---Sets common.TANK_MOB_ID to the mob being pulled.
---@param pull_func function @The function to use to ranged pull.
pull.pull_mob = function(pull_func)
    local pull_state = state.get_pull_in_progress()
    -- if dead or currently assisting or tanking something, or stuff is on xtarget, then don't start new pulling things
    if not pull_state and (common.am_i_dead() or state.get_assist_mob_id() ~= 0 or state.get_tank_mob_id() ~= 0 or common.hostile_xtargets()) then
        --[[if state.get_pull_in_progress() then
            local camp = state.get_camp()
            if common.check_distance(camp.X, camp.Y, mq.TLO.Me.X(), mq.TLO.Me.Y()) < config.get_camp_radius() then
                clear_pull_vars()
            else
                pull_return()
            end
        end]]--
        --clear_pull_vars()
        return
    end

    -- account for any odd pull state discrepancies?
    if (pull_state and state.get_pull_mob_id() == 0) or (state.get_pull_mob_id() ~= 0 and not pull_state) then
        clear_pull_vars()
        pull_return()
        return
    end
    if not pull_state then
        -- don't start a new pull if tanking or assisting or hostiles on xtarget or conditions aren't met
        if common.am_i_dead() or state.get_assist_mob_id() ~= 0 or state.get_tank_mob_id() ~= 0 or common.hostile_xtargets() then return end
        if not pull.check_pull_conditions() then return end
        -- find a mob to pull
        local pull_mob_id = pull.pull_radar()
        local pull_spawn = mq.TLO.Spawn(pull_mob_id)
        if pull_spawn.ID() == 0 then
            -- didn't seem to find the mob returned by pull_radar
            clear_pull_vars()
            return
        end
        -- valid pull spawn acquired, begin approach
        state.set_pull_in_progress(common.PULL_STATES.APPROACHING)
        pull_nav_to(pull_spawn)
    elseif pull_state == common.PULL_STATES.APPROACHING then
        local pull_spawn = mq.TLO.Spawn(state.get_pull_mob_id())
        if pull_approaching(pull_spawn) then
            -- movement stopped, either spawn became invalid, we're in range, or other stuff agro'd
            state.set_pull_in_progress(common.PULL_STATES.ENGAGING)
        end
    elseif pull_state == common.PULL_STATES.ENGAGING then
        local pull_spawn = mq.TLO.Spawn(state.get_pull_mob_id())
        if pull_engage(pull_spawn, pull_func) then
            -- successfully agro'd the mob, or something else agro'd in the process
            if config.get_mode():return_to_camp() and state.get_camp() then
                state.set_pull_in_progress(common.PULL_STATES.RETURNING)
                pull_return()
            else
                clear_pull_vars()
            end
        end
    elseif pull_state == common.PULL_STATES.RETURNING then
        local camp = state.get_camp()
        if common.check_distance(camp.X, camp.Y, mq.TLO.Me.X(), mq.TLO.Me.Y()) < config.get_camp_radius() then
            clear_pull_vars()
        else
            pull_return()
        end
    end
end

return pull