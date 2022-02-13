--- @type mq
local mq = require 'mq'
local common = require('aqo.common')
local config = require('aqo.configuration')
local logger = require('aqo.utils.logger')
local timer = require('aqo.utils.timer')
local state = require('aqo.state')

local pull = {}

-- Pull Functions

local PULL_IN_PROGRESS = false
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

local medding = false
local healers = {CLR=true,DRU=true,SHM=true}
pull.check_pull_conditions = function()
    if common.am_i_dead() then return false end
    if mq.TLO.Me.PctEndurance() < 10 then
        medding = true
        return false
    end
    if mq.TLO.Me.PctEndurance() < 30 and medding then
        return false
    end
    for i=1,mq.TLO.Group.Members() do
        local member = mq.TLO.Group.Member(i)
        if member then
            local pctmana = member.PctMana()
            if member.Dead() then
                return false
            elseif healers[member.Class.ShortName()] and pctmana and pctmana < 20 then
                return false
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
    if pull_radius_count > 0 then
        local zone_sn = mq.TLO.Zone.ShortName()
        for i=1,pull_radius_count do
            local mob
            if camp then
                mob = mq.TLO.NearestSpawn(pull_spawn_camp:format(i, camp.X, camp.Y, pull_radius))
            else
                mob = mq.TLO.NearestSpawn(pull_spawn:format(i, pull_radius))
            end 
            local mob_id = mob.ID()
            local pathlen = mq.TLO.Navigation.PathLength('id '..mob_id)()
            if mob_id > 0 and not PULL_TARGET_SKIP[mob_id] and mob.Type() ~= 'Corpse' and pathlen > 0 and pathlen < pull_radius and check_mob_angle(mob) and check_z_rad(mob) and check_level(mob) and not config.ignores_contains(zone_sn, mob.CleanName()) then
                -- TODO: check for people nearby, check level, check z radius if high/low differ
                --local pc_near_count = mq.TLO.SpawnCount(pc_near:format(mob.X(), mob.Y()))
                --if pc_near_count == 0 then
                state.set_pull_mob_id(mob_id)
                return
                --end
            end
        end
    end
end

---Navigate to the pull spawn. Stop when it is within bow distance and line of sight, or when within melee distance.
---@param pull_spawn Spawn @The MQ Spawn to navigate to.
---@return boolean @Returns false if the pull spawn became invalid during navigation, otherwise true.
local function pull_nav_to(pull_spawn)
    local mob_x = pull_spawn.X()
    local mob_y = pull_spawn.Y()
    local mob_z = pull_spawn.Z()
    if not mob_x or not mob_y or not mob_z then
        state.set_pull_mob_id(0)
        return false
    end
    if common.check_distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), mob_x, mob_y) > 10 then
        logger.debug(state.get_debug(), 'Moving to pull target (%s)', state.get_pull_mob_id())
        if not mq.TLO.Navigation.Active() and mq.TLO.Navigation.PathExists(string.format('id %d', state.get_pull_mob_id()))() then
            mq.cmdf('/nav spawn id %d | dist=15 log=off', state.get_pull_mob_id())
            mq.delay(100, function() return mq.TLO.Navigation.Active() end)
        end
        -- TODO: disrupt if mob aggro otw to pull
        mq.delay('15s', function()
            if not pull_spawn or not mq.TLO.Navigation.Active() then
                return true
            end
            local dist3d = pull_spawn.Distance3D()
            -- return right away if we can't read distance, as pull spawn is probably no longer valid
            if not dist3d then return true end
            -- return true once target is in range and in LOS, or if something appears on xtarget
            return (pull_spawn.LineOfSight() and dist3d < 200) or dist3d < 15 or common.hostile_xtargets()
        end)
    end
    return true
end

---Reset common mob ID variables to 0 to reset pull status.
local function clear_pull_vars()
    state.set_tank_mob_id(0)
    state.set_pull_mob_id(0)
    PULL_IN_PROGRESS = false
end

---Aggro the specified target to be pulled. Attempts to use bow and moves closer to melee pull if necessary.
---@param pull_spawn Spawn @The MQ Spawn to be pulled.
---@param pull_func function @The function to use to ranged pull.
local function pull_engage(pull_spawn, pull_func)
    -- pull  mob
    local pull_mob_id = state.get_pull_mob_id()
    local dist3d = pull_spawn.Distance3D()
    if not dist3d or not pull_spawn.LineOfSight() or dist3d > 200 then
        logger.printf('\arPull target no longer valid \ax(\at%s\ax)', pull_mob_id)
        clear_pull_vars()
        return
    end
    pull_spawn.DoTarget()
    mq.delay(50, function() return mq.TLO.Target.ID() == pull_spawn.ID() end)
    if not mq.TLO.Target() then
        logger.printf('\arPull target no longer valid \ax(\at%s\ax)', pull_mob_id)
        clear_pull_vars()
        return
    end
    local tot_id = mq.TLO.Me.TargetOfTarget.ID()
    if (tot_id > 0 and tot_id ~= mq.TLO.Me.ID()) then --or mq.TLO.Target.PctHPs() < 100 then
        logger.printf('\arPull target already engaged, skipping \ax(\at%s\ax)', pull_mob_id)
        -- TODO: clear skip targets
        PULL_TARGET_SKIP[pull_mob_id] = 1
        clear_pull_vars()
        return
    end
    logger.printf('Pulling \ay%s\ax (\at%s\ax)', mq.TLO.Target.CleanName(), mq.TLO.Target.ID())
    --logger.printf('facing mob')
    if mq.TLO.Navigation.Active() then
        mq.cmd('/squelch /nav stop')
        mq.delay(100, function() return not mq.TLO.Navigation.Active() end)
    end
    mq.cmd('/squelch /face fast')
    --logger.printf('agroing mob')
    -- TODO: class pull abilities
    local get_closer = false
    if mq.TLO.Target.Distance3D() < 35 then
        -- use class close range pull ability
        mq.cmd('/squelch /stick front loose moveback 10')
        -- /stick mod 0
        mq.cmd('/attack on')
        mq.delay('3s', function() return mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID() end)
    else
        if mq.TLO.Me.Combat() then
            mq.cmd('/attack off')
            mq.delay(100)
        end
        if pull_func then
            pull_func()
        else
            mq.cmd('/autofire on')
            mq.delay(100)
            if not mq.TLO.Me.AutoFire() then
                mq.cmd('/autofire on')
            end
        end
        -- use class long range pull ability
        -- tag with range
        get_closer = true
        mq.delay('3s', function() return mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID() end)
    end
    --logger.printf('mob agrod or timed out')
    mq.cmd('/multiline ; /attack off; /autofire off; /stick off;')

    if not common.hostile_xtargets() and get_closer then
        if not mq.TLO.Navigation.Active() and mq.TLO.Navigation.PathExists(string.format('id %d', state.get_pull_mob_id()))() then
            mq.cmdf('/nav id %d | dist=15 log=off', pull_mob_id)
            mq.delay(100, function() return mq.TLO.Navigation.Active() end)
        end
        -- TODO: disrupt if mob aggro otw to pull
        mq.delay('15s', function()
            if not pull_spawn or not mq.TLO.Navigation.Active() then
                return true
            end
            local dist3d = pull_spawn.Distance3D()
            -- return right away if we can't read distance, as pull spawn is probably no longer valid
            if not dist3d then return true end
            -- return true once target is in range and in LOS, or if something appears on xtarget
            return pull_spawn.LineOfSight() and dist3d < 20 or common.hostile_xtargets()
        end)

        if mq.TLO.Navigation.Active() then
            mq.cmd('/squelch /nav stop')
            mq.delay(100, function() return not mq.TLO.Navigation.Active() end)
        end

        local dist3d = mq.TLO.Target.Distance3D()
        if not dist3d or dist3d > 25 or not mq.TLO.Target.LineOfSight() then return end
        -- use class close range pull ability
        mq.cmd('/squelch /stick front loose moveback 10')
        -- /stick mod 0
        mq.cmd('/attack on')

        mq.delay('1s', function() return mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID() end)
        --logger.printf('mob agrod or timed out')
        mq.cmd('/multiline ; /attack off; /autofire off; /stick off;')
    end
    --if mq.TLO.Navigation.Active() then
    --    mq.cmd('/squelch /nav stop')
    --    mq.delay(100, function() return not mq.TLO.Navigation.Active() end)
    --end
end

---Return to camp and wait for the pull target to arrive in camp. Stops early if adds appear on xtarget.
local function pull_return()
    --logger.printf('Bringing pull target back to camp (%s)', common.PULL_MOB_ID)
    local camp = state.get_camp()
    mq.cmdf('/nav locyxz %d %d %d log=off', camp.Y, camp.X, camp.Z)
    mq.delay('50', function() return mq.TLO.Navigation.Active() end)
    mq.delay('30s', function() return not mq.TLO.Navigation.Active() end)
    -- wait for mob to show up
    logger.debug(state.get_debug(), 'Waiting for pull target to reach camp (%s)', state.get_pull_mob_id())
    mq.cmd('/multiline ; /squelch /face fast; /squelch /target clear;')
    -- TODO: swap to closer mobs in camp if any
    --if mq.TLO.Me.XTarget() == 0 then
    --    clear_pull_vars()
    --    return
    --end
    --mq.delay('15s', function()
    --    local mob_x = mq.TLO.Target.X()
    --    local mob_y = mq.TLO.Target.Y()
    --    if not mob_x or not mob_y then return true end
    --    return mq.TLO.Me.XTarget() > 1 or common.check_distance(common.CAMP.X, common.CAMP.Y, mob_x, mob_y) < common.OPTS.CAMPRADIUS and mq.TLO.Target.LineOfSight()
    --end)
end

---Attempt to pull the mob whose ID is stored in common.PULL_MOB_ID.
---Sets common.TANK_MOB_ID to the mob being pulled.
---@param pull_func function @The function to use to ranged pull.
pull.pull_mob = function(pull_func)
    local pull_mob_id = state.get_pull_mob_id()
    if pull_mob_id == 0 then return end
    if common.am_i_dead() then return end
    local pull_spawn = mq.TLO.Spawn(pull_mob_id)
    if not pull_spawn then
        state.set_pull_mob_id(0)
        return
    end

    PULL_IN_PROGRESS = true
    -- move to pull target
    if not pull_nav_to(pull_spawn) then return end
    if not common.hostile_xtargets() then
        pull_engage(pull_spawn, pull_func)
    else
        logger.printf('\ayMobs on xtarget, canceling pull and returning to camp\ax')
        clear_pull_vars()
    end
    -- return to camp
    if config.get_mode():is_camp_mode() and state.get_camp() then
        pull_return()
    end
    --common.TANK_MOB_ID = common.PULL_MOB_ID -- pull mob reached camp, mark it as tank mob
    state.set_pull_mob_id(0) -- pull done, clear pull mob id
    PULL_IN_PROGRESS = false
end

return pull