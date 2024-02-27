local mq = require 'mq'
local config = require('interface.configuration')
local camp = require('routines.camp')
local helpers = require('utils.helpers')
local logger = require('utils.logger')
local movement = require('utils.movement')
local timer = require('libaqo.timer')
local abilities = require('ability')
local constants = require('constants')
local common = require('common')
local mode = require('mode')
local state = require('state')

local class
local pull = {}

function pull.init(_class)
    class = _class
end

-- Pull Functions

local PULL_TARGET_SKIP = {}

-- mob at 135, SE
-- pull arc left 90
-- pull arc right 180

-- false invalid, true valid
---Determine whether the pull spawn is within the configured pull arc, if there is one.
---@param pull_spawn MQSpawn @The MQ Spawn to check.
---@return boolean @Returns true if the spawn is within the pull arc, otherwise false.
local function checkMobAngle(pull_spawn)
    local pull_arc = config.get('PULLARC')
    if pull_arc == 360 or pull_arc == 0 then return true end
    -- TODO: pull arcs without camp set???
    if not camp.Active then return true end
    local direction_to_mob = pull_spawn.HeadingTo(camp.Y, camp.X).Degrees()
    if not direction_to_mob then return false end
    -- switching from non-puller mode to puller mode, the camp may not be updated yet
    if not (camp.PullArcLeft and camp.PullArcRight) then return false end
    logger.debug(logger.flags.routines.pull, 'arcleft: %s, arcright: %s, dirtomob: %s', camp.PullArcLeft, camp.PullArcRight, direction_to_mob)
    if camp.PullArcLeft >= camp.PullArcRight then
        if direction_to_mob < camp.PullArcLeft and direction_to_mob > camp.PullArcRight then return false end
    else
        if direction_to_mob < camp.PullArcLeft or direction_to_mob > camp.PullArcRight then return false end
    end
    return true
end

-- z check done separately so that high and low values can be different
---Determine whether the pull spawn is within the configured Z high and Z low values.
---@param pull_spawn MQSpawn @The MQ Spawn to check.
---@return boolean @Returns true if the spawn is within the Z high and Z low, otherwise false.
local function checkZRadius(pull_spawn)
    local mob_z = pull_spawn.Z()
    if not mob_z then return false end
    if camp.Active then
        if mob_z > camp.Z+config.get('PULLHIGH') or mob_z < camp.Z-config.get('PULLLOW') then return false end
    else
        if mob_z > mq.TLO.Me.Z()+config.get('PULLHIGH') or mob_z < mq.TLO.Me.Z()-config.get('PULLLOW') then return false end
    end
    return true
end

---Determine whether the pull spawn is within the configured pull level range.
---@param pull_spawn MQSpawn @The MQ Spawn to check.
---@return boolean @Returns true if the spawn is within the configured level range, otherwise false.
local function checkMobLevel(pull_spawn)
    if config.get('PULLMINLEVEL') == 0 and config.get('PULLMAXLEVEL') == 0 then return true end
    local mob_level = pull_spawn.Level()
    if not mob_level then return false end
    return mob_level >= config.get('PULLMINLEVEL') and mob_level <= config.get('PULLMAXLEVEL')
end

---Validate that the spawn is good for pulling
---@param pull_spawn MQSpawn @The MQ Spawn to validate.
---@param path_len number @The navigation path length to the spawn.
---@param zone_sn string @The current zone short name.
---@return boolean @Returns true if the spawn meets all the criteria for pulling, otherwise false.
local function validatePull(pull_spawn, path_len, zone_sn)
    local mob_id = pull_spawn.ID()
    if not mob_id or mob_id == 0 or PULL_TARGET_SKIP[mob_id] or pull_spawn.Type() == 'Corpse' or pull_spawn.Surname() ~= '' then
        logger.debug(logger.flags.routines.pull, 'Invalid mob ID %s (type=%s, skip=%s)', mob_id, pull_spawn.Type(), PULL_TARGET_SKIP[mob_id])
        return false
    end
    if path_len < 0 or path_len > config.get('PULLRADIUS') then
        logger.debug(logger.flags.routines.pull, 'Navigation PathLength %s exceeds PullRadius %s', path_len, config.get('PULLRADIUS'))
        return false
    end
    return checkMobAngle(pull_spawn) and checkZRadius(pull_spawn) and checkMobLevel(pull_spawn) and not config.ignoresContains(zone_sn, pull_spawn.CleanName())
end

--local medding = false
local healers = {CLR=true,DRU=true,SHM=true}
local holdPullTimer = timer:new(5000)
local holdPulls = false
function pull.checkPullConditions()
    if config.get('GROUPSTAYCLOSE') and mq.TLO.Group.Members() then
        for i=1,mq.TLO.Group.Members() do
            local member = mq.TLO.Group.Member(i)
            if member() then
                if (member.Distance3D() or 300) > 150 then
                    -- group member not nearby, hold pulls until they catch up
                    if not holdPulls then holdPullTimer:reset() holdPulls = true end
                    return false
                end
            end
        end
    end
    if config.get('GROUPWATCHWHO') == 'none' then return true end
    -- groupwatch self when self or healer is selected
    if config.get('GROUPWATCHWHO') ~= 'none' then
        if mq.TLO.Me.PctHPs() < config.get('MEDHPSTART') or mq.TLO.Me.PctEndurance() < config.get('MEDENDSTART') or (mq.TLO.Me.MaxMana() > 0 and mq.TLO.Me.PctMana() < config.get('MEDMANASTART')) and not state.medding then
            state.medding = true
            if not mq.TLO.Me.Sitting() and state.sitTimer:expired() then
                mq.cmd('/sit')
                state.sitTimer:reset()
            end
            return false
        end
        if (mq.TLO.Me.PctHPs() < config.get('MEDHPSTOP') or mq.TLO.Me.PctEndurance() < config.get('MEDENDSTOP') or (mq.TLO.Me.MaxMana() > 0 and mq.TLO.Me.PctMana() < config.get('MEDMANASTOP'))) and state.medding then
            if not mq.TLO.Me.Sitting() and state.sitTimer:expired() then
                mq.cmd('/sit')
                state.sitTimer:reset()
            end
            return false
        end
    end
    if mq.TLO.Group.Members() then
        for i=1,mq.TLO.Group.Members() do
            local member = mq.TLO.Group.Member(i)
            if member() then
                if config.get('GROUPSTAYCLOSE') and (member.Distance3D() or 300) > 150 then
                    -- group member not nearby, hold pulls until they catch up
                    if not holdPulls then holdPullTimer:reset() holdPulls = true end
                    return false
                end
                local pcthp = member.PctHPs()
                local pctmana = member.PctMana()
                if member.Dead() then
                    return false
                elseif healers[member.Class.ShortName()] and config.get('GROUPWATCHWHO') == 'healer' and pctmana then
                    if pcthp < config.get('MEDHPSTOP') and state.groupWatchWaiting then
                        return false
                    end
                    if pctmana < config.get('MEDMANASTOP') and state.groupWatchWaiting then
                        return false
                    end
                    if pctmana < config.get('MEDMANASTART') then
                        state.groupWatchWaiting = true
                        return false
                    elseif pcthp < config.get('MEDHPSTART') then
                        state.groupWatchWaiting = true
                        return false
                    end
                end
            end
        end
    end
    state.groupWatchWaiting = false
    return true
end

local pullRadarTimer = timer:new(1000)
function pull.pullRadarB()
    if not pullRadarTimer:expired() then return 0 end
    pullRadarTimer:reset()
    local pull_radius = config.get('PULLRADIUS')
    if not pull_radius then return 0 end
    local shortest_path = pull_radius
    local pull_id = 0

    local function pullPredicate(spawn)
        if spawn.Type() ~= 'NPC' then return false end
        if spawn.Distance3D() > pull_radius then return false end
        local path_len = mq.TLO.Navigation.PathLength(string.format('id %s', spawn.ID()))()
        if not validatePull(spawn, path_len, mq.TLO.Zone.ShortName()) then return false end
        if path_len < shortest_path then
            shortest_path = path_len
            pull_id = spawn.ID()
        end
        return true
    end

    mq.getFilteredSpawns(pullPredicate)
    state.pullMobID = pull_id
    return pull_id
end

--loc ${s_WorkSpawn.X} ${s_WorkSpawn.Y}
local pull_count = 'npc targetable nopet radius %d'-- zradius 50'
local pull_spawn = '%d, npc targetable nopet radius %d'-- zradius 50'
local pull_count_camp = 'npc targetable nopet loc %d %d radius %d'-- zradius 50'
local pull_spawn_camp = '%d, npc targetable nopet loc %d %d radius %d'-- zradius 50'
local pc_near = 'pc radius 30 loc %d %d'
---Search for pullable mobs within the configured pull radius.
---Sets common.pullMobID to the mob ID of the first matching spawn.
function pull.pullRadar()
    if not pullRadarTimer:expired() then return 0 end
    pullRadarTimer:reset()
    local pull_radius_count
    local pull_radius = config.get('PULLRADIUS')
    if not pull_radius then return 0 end
    if camp.Active then
        pull_radius_count = mq.TLO.SpawnCount(pull_count_camp:format(camp.X, camp.Y, pull_radius))()
        logger.debug(logger.flags.routines.pull, ('%s: %s'):format(pull_radius_count or 0, pull_count_camp:format(camp.X, camp.Y, pull_radius)))
    else
        pull_radius_count = mq.TLO.SpawnCount(pull_count:format(pull_radius))()
        -- error here
        logger.debug(logger.flags.routines.pull, ('%s: %s'):format(pull_radius_count or 0, pull_count:format(pull_radius)))
    end
    local shortest_path = pull_radius
    local pull_id = 0
    if pull_radius_count > 0 then
        local zone_sn = mq.TLO.Zone.ShortName()
        for i=1,pull_radius_count do
            -- try not to iterate through the whole world if there's a pretty large pull radius
            if i > 100 then break end
            local mob
            if camp.Active then
                mob = mq.TLO.NearestSpawn(pull_spawn_camp:format(i, camp.X, camp.Y, pull_radius))
            else
                mob = mq.TLO.NearestSpawn(pull_spawn:format(i, pull_radius))
            end
            local path_len = mq.TLO.Navigation.PathLength(string.format('id %s', mob.ID()))()
            if validatePull(mob, path_len, zone_sn) then
                -- TODO: check for people nearby, check level, check z radius if high/low differ
                --local pc_near_count = mq.TLO.SpawnCount(pc_near:format(mob.X(), mob.Y()))
                --if pc_near_count == 0 then
                local dist3d = mob.Distance3D()
                if mob.LineOfSight() or (dist3d and path_len < dist3d+50) then
                    -- don't bother to check path length if mob already in los.
                    -- if path length is within 50 of distance3d then its probably safe to pull also
                    state.pullMobID = mob.ID()
                    return mob.ID()
                elseif path_len < shortest_path then
                    logger.debug(logger.flags.routines.pull, ("Found closer pull, %s < %s"):format(path_len, shortest_path))
                    shortest_path = path_len
                    pull_id = mob.ID()
                end
            end
        end
    end
    if pull_id ~= 0 then
        state.pullMobID = pull_id
    end
    return pull_id
end

---Reset common mob ID variables to 0 to reset pull status.
function pull.clearPullVars(caller)
    logger.debug(logger.flags.routines.pull, 'Resetting pull status. beforeState=%s, caller=%s', state.pullStatus, caller)
    state.pullMobID = 0
    state.pullStatus = nil
end

---Navigate to the pull spawn. Stop when it is within bow distance and line of sight, or when within melee distance.
---@param pull_spawn MQSpawn @The MQ Spawn to navigate to.
---@return boolean @Returns false if the pull spawn became invalid during navigation, otherwise true.
local function pullNavToMob(pull_spawn, announce_pull)
    local mob_x = pull_spawn.X()
    local mob_y = pull_spawn.Y()
    if not (mob_x and mob_y) then
        pull.clearPullVars('navToMob')
        return false
    end
    if announce_pull then
        logger.info('Pulling \at%s\ax (\at%s\ax)', pull_spawn.CleanName(), pull_spawn.ID())
    end
    if helpers.distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), mob_x, mob_y) > 100 then
        logger.debug(logger.flags.routines.pull, 'Moving to pull target (\at%s\ax)', state.pullMobID)
        movement.navToSpawn('id '..state.pullMobID, 'dist=5')
    end
    return true
end

local function pullApproaching(pull_spawn)
    if not pull_spawn or not mq.TLO.Navigation.Active() then
        return true
    end
    local dist3d = pull_spawn.Distance3D()
    -- return right away if we can't read distance, as pull spawn is probably no longer valid
    if not dist3d then return true end
    -- return true once target is in range and in LOS, or if something appears on xtarget
    return (config.get('PULLWITH') ~= 'melee' and pull_spawn.LineOfSight() and dist3d < 200) or dist3d < 5 or common.hostileXTargets()
end

---Aggro the specified target to be pulled. Attempts to use bow and moves closer to melee pull if necessary.
---@param pull_spawn MQSpawn @The MQ Spawn to be pulled.
local function pullEngage(pull_spawn)
    -- pull  mob
    local pullMobID = state.pullMobID
    local dist3d = pull_spawn.Distance3D()
    if not dist3d then
        logger.info('\arPull target no longer valid \ax(\at%s\ax)', pullMobID)
        pull.clearPullVars('pullEngage-distanceCheck')
        return false
    end
    if not pull_spawn.LineOfSight() or dist3d > 200 then
        state.pullStatus = constants.pullStates.APPROACHING
        pullNavToMob(pull_spawn, false)
        return false
    end
    pull_spawn.DoTarget()
    if not mq.TLO.Target() then
        logger.info('\arPull target no longer valid \ax(\at%s\ax)', pullMobID)
        pull.clearPullVars('pullEngage-targetCheck')
        return false
    end
    local tot_id = mq.TLO.Me.TargetOfTarget.ID()
    local targethp = mq.TLO.Target.PctHPs()
    --if (tot_id > 0 and tot_id ~= mq.TLO.Me.ID()) or (targethp and targethp < 100) then --or mq.TLO.Target.PctHPs() < 100 then
    if tot_id > 0 and tot_id ~= mq.TLO.Me.ID() and tot_id ~= mq.TLO.Pet.ID() then
        if targethp and targethp < 99 then
            logger.info('\arPull target already engaged, skipping \ax(\at%s\ax) %s %s %s', pullMobID, tot_id, mq.TLO.Me.ID(), targethp)
            -- TODO: clear skip targets
            PULL_TARGET_SKIP[pullMobID] = 1
            pull.clearPullVars('pullEngage-hpCheck')
            return false
        end
    end
    if mq.TLO.Target.Distance3D() < 35 then
        --movement.stop()
        if mq.TLO.Navigation.Active() then mq.cmd('/squelch /nav stop') end
        mq.cmd('/squelch /face fast')
        mq.cmd('/squelch /stick front loose moveback 10')
        mq.cmd('/attack on')
        state.pullStatus = constants.pullStates.WAIT_FOR_AGGRO
    else
        if mq.TLO.Me.Combat() then
            mq.cmd('/attack off')
            -- mq.delay(100)
        end
        local pullWith = config.get('PULLWITH')
        if pullWith == 'item' then
            local pull_item = nil
            for _,clicky in ipairs(class.pullClickies) do
                if clicky.enabled and mq.TLO.Me.ItemReady(clicky.CastName)() then
                    pull_item = clicky
                    break
                end
            end
            if pull_item then
                movement.stop()
                -- mq.delay(50)
                abilities.use(pull_item, class)
                state.pullStatus = constants.pullStates.WAIT_FOR_AGGRO
            end
        elseif pullWith == 'ranged' then
            local ranged_item = mq.TLO.InvSlot('ranged').Item
            local ammo_item = mq.TLO.InvSlot('ammo').Item
            if ranged_item() and ranged_item.Damage() > 0 and ammo_item() and ammo_item.Damage() > 0 then
                mq.cmd('/squelch /face fast')
                mq.cmd('/autofire on')
                -- mq.delay(1000)
                if not mq.TLO.Me.AutoFire() then
                    mq.cmd('/autofire on')
                end
                state.pullStatus = constants.pullStates.WAIT_FOR_AGGRO
            end
        elseif pullWith == 'spell' then
            if mq.TLO.Me.SpellReady(class.pullSpell.CastName)() then
                movement.stop()
                -- mq.delay(50)
                abilities.use(class.pullSpell, class)
                state.pullStatus = constants.pullStates.WAIT_FOR_AGGRO
            end
        elseif pullWith == 'custom' and class.pullCustom then
            class:pullCustom()
        elseif config.get('PULLWITH') == 'melee' then
            state.pullStatus = constants.pullStates.APPROACHING
            pullNavToMob(pull_spawn, false)
            return false
        end
    end
    return true
end

local pullReturnTimer = timer:new(120000)
---Return to camp and wait for the pull target to arrive in camp. Stops early if adds appear on xtarget.
local function pullReturn(noMobs)
    --logger.info('Bringing pull target back to camp (%s)', common.pullMobID)
    if noMobs and not pullReturnTimer:expired() then return end
    if helpers.distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), camp.X, camp.Y) < 225 then return end
    movement.navToLoc(camp.X, camp.Y, camp.Z)
    if noMobs then pullReturnTimer:reset() end
end

local function pullMobOnXTarget()
    for i=1,20 do
        if mq.TLO.Me.XTarget(i).ID() == state.pullMobID then return true end
    end
    return false
end

local function anyoneDead()
    local groupSize = mq.TLO.Group.GroupSize()
    if not groupSize then return false end
    for i=1,groupSize-1 do
        if mq.TLO.Group.Member(i).Dead() then return true end
    end
    return false
end

local pullEngageTimer = timer:new(3000)
---Attempt to pull the mob whose ID is stored in common.pullMobID.
---Sets common.tankMobID to the mob being pulled.
function pull.pullMob()
    local pull_state = state.pullStatus
    -- or (mq.TLO.Group.Injured(config.get('MEDHPSTART'))() or 0) > 0
    if anyoneDead() or mq.TLO.Me.PctHPs() < config.get('MEDHPSTART') or constants.DMZ[mq.TLO.Zone.ID()] then-- or (state.holdForBuffs and not state.holdForBuffs:expired()) then
        if pull_state == constants.pullStates.APPROACHING or pull_state == constants.pullStates.ENGAGING then
            pull.clearPullVars('pullMob-deadOrInjured')
            movement.stop()
            return
        elseif not pull_state then
            -- let this fall through to pull validation which already checks groupwatch stuff
            --return
        end
    end
    if state.emu and config.get('LOOTMOBS') and mq.TLO.SpawnCount('npccorpse radius '..config.get('CAMPRADIUS')..' zradius 10')() > 0 then
        logger.debug(logger.flags.routines.pull, 'Not pulling due to lootable corpses nearby')
        pull.clearPullVars('pullMob-lootablecorpses')
        return
    end
    -- if currently assisting or tanking something, or stuff is on xtarget, then don't start new pulling things
    if not pull_state and (state.assistMobID ~= 0 or state.tankMobID ~= 0 or common.hostileXTargets()) then
        --logger.debug(logger.flags.routines.pull, 'returning at weird state')
        return
    end

    -- account for any odd pull state discrepancies?
    if (pull_state and state.pullMobID == 0) or (state.pullMobID ~= 0 and not pull_state) then
        pull.clearPullVars('pullMob-consistencyCheck')
        pullReturn()
        return
    end

    -- try to break if something agro'd that isn't the pull mob? thought this was already happening somewhere...
    if pull_state and common.hostileXTargets() and not pullMobOnXTarget() then
        pull.clearPullVars('pullMob-onXTargetCheck')
        return
    end
    if not pull_state then
        logger.debug(logger.flags.routines.pull, 'a pull search can start')
        -- don't start a new pull if tanking or assisting or hostiles on xtarget or conditions aren't met
        if state.assistMobID ~= 0 or state.tankMobID ~= 0 or common.hostileXTargets() then return end
        if not pull.checkPullConditions() then
            if holdPulls and holdPullTimer:expired() then
                local furthest = 0
                local furthestID = 0
                for i=1,mq.TLO.Group.Members() do
                    local member = mq.TLO.Group.Member(i)
                    if member() and (member.Distance3D() or 0) > furthest then
                        furthest = member.Distance3D()
                        furthestID = member.ID()
                    end
                end
                if furthestID > 0 then movement.navToID(furthestID, 'dist=10') end
            end
            return
        elseif holdPulls then
            holdPulls = false
        end
        -- find a mob to pull
        logger.debug(logger.flags.routines.pull, 'searching for pulls')
        local pullMobID = pull.pullRadar()
        local pull_spawn = mq.TLO.Spawn(pullMobID)
        if pull_spawn.ID() == 0 then
            -- didn't seem to find the mob returned by pullRadar
            pull.clearPullVars('pullMob-mobMissingCheck')
            pullReturn(true)
            return
        end
        if pull_spawn.Type() ~= 'NPC' then pull.clearPullVars('pullMob-nonNPC') return end
        -- valid pull spawn acquired, begin approach
        state.pullStatus = constants.pullStates.APPROACHING
        pullNavToMob(pull_spawn, true)
    elseif pull_state == constants.pullStates.APPROACHING then
        local pull_spawn = mq.TLO.Spawn(state.pullMobID)
        if pull_spawn.Type() ~= 'NPC' then pull.clearPullVars('pullMob-nonNPC') return end
        if pullApproaching(pull_spawn) then
            -- movement stopped, either spawn became invalid, we're in range, or other stuff agro'd
            state.pullStatus = constants.pullStates.ENGAGING
        end
    elseif pull_state == constants.pullStates.ENGAGING then
        local pull_spawn = mq.TLO.Spawn(state.pullMobID)
        if pull_spawn.Type() ~= 'NPC' then pull.clearPullVars('pullMob-nonNPC') return end
        pullEngage(pull_spawn)
        pullEngageTimer:reset()
    elseif pull_state == constants.pullStates.WAIT_FOR_AGGRO then
        if (mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID() and common.hostileXTargets()) or not mq.TLO.Target() then
            if mq.TLO.Me.Combat() then mq.cmd('/attack off') end
            if mq.TLO.Me.AutoFire() then mq.cmd('/autofire off') end
            if mq.TLO.Stick.Active() then mq.cmd('/stick off') end
            -- successfully agro'd the mob, or something else agro'd in the process
            pullEngageTimer:reset()
            if mode.currentMode:isReturnToCampMode() and camp.Active then
                state.pullStatus = constants.pullStates.RETURNING
                pullReturn(false)
            else
                pullReturnTimer:reset()
                state.pullStatus = constants.pullStates.PULLED
            end
        elseif pullEngageTimer:expired() then
            pullEngageTimer:reset()
            pullReturnTimer:reset()
            pull.clearPullVars('pullMob-aggroTimerExpired')
        end
    elseif pull_state == constants.pullStates.RETURNING then
        if helpers.distance(camp.X, camp.Y, mq.TLO.Me.X(), mq.TLO.Me.Y()) < config.get('CAMPRADIUS')^2 then
            state.pullStatus = constants.pullStates.PULLED
        else
            pullReturn(false)
        end
    end
end

return pull