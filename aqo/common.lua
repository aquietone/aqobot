--- @type mq
local mq = require 'mq'
local config = require('aqo.configuration')
local logger = require('aqo.logger')
local state = require('aqo.state')

local common = {}

common.ASSISTS = {group=1,raid1=1,raid2=1,raid3=1}
common.FD_CLASSES = {mnk=1,bst=1,shd=1,nec=1}

local familiar = mq.TLO.Familiar.Stat.Item.ID() or mq.TLO.FindItem('Personal Hemic Source').ID()
-- Familiar: Personal Hemic Source
local illusion = mq.TLO.Illusion.Stat.Item.ID() or mq.TLO.FindItem('Jann\'s Veil').ID()
-- Illusion Benefit Greater Jann
local mount = mq.TLO.Mount.Stat.Item.ID() or mq.TLO.FindItem('Golden Owlbear Saddle').ID()
-- Mount Blessing Meda

-- Generic Helper Functions

---Check whether the specified file exists or not.
---@param file_name string @The name of the file to check existence of.
---@return boolean @Returns true if the file exists, false otherwise.
common.file_exists = function(file_name)
    local f = io.open(file_name, "r")
    if f ~= nil then io.close(f) return true else return false end
end

---Return the current time in seconds. TODO: is the os.date("!*t") really necessary? "!*t" returns UTC instead of local time.
---@return number @Returns a number representing the current time.
common.current_time = function()
    return os.time(os.date("!*t"))
end

---Check whether the specified timer has passed the given expiration.
---@param t number @The current value of the timer.
---@param expiration number @The number of seconds which must have passed for the timer to be expired.
---@return boolean
common.timer_expired = function(t, expiration)
    if os.difftime(common.current_time(), t) > expiration then
        return true
    else
        return false
    end
end

---Check whether the time remaining on the given timer is less than the provided value.
---@param t number @The current value of the timer.
---@param less_than number @The maximum number of seconds remaining to return true.
---@return boolean @Returns true if the timer has less than the specified number of seconds remaining.
common.time_remaining = function(t, less_than)
    return not common.timer_expired(t, less_than)
end

---Count the number of keys in the given table
---@param t table @The table.
---@return number @The number of keys in the table.
common.table_size = function(t)
    local count = 0
    for _,_ in pairs(t) do
        count = count + 1
    end
    return count
end

-- MQ Helper Functions

---Lookup the ID for a given spell.
---@param spell_name string @The name of the spell.
---@param option_name string @The name of the option which controls whether this spell should be used.
---@return table @Returns a table containing the spell name with rank, spell ID and the provided option name.
common.get_spellid_and_rank = function(spell_name, option_name)
    local spell_rank = mq.TLO.Spell(spell_name).RankName()
    return {['id']=mq.TLO.Spell(spell_rank).ID(), ['name']=spell_rank, ['opt']=option_name}
end
---Lookup the ID for a given AA.
---@param aa_name string @The name of the AA.
---@param option_name string @The name of the option which controls whether this AA should be used.
---@return table @Returns a table containing the AA name, AA ID and the provided option name.
common.get_aaid_and_name = function(aa_name, option_name)
    return {['id']=mq.TLO.Me.AltAbility(aa_name).ID(), ['name']=aa_name, ['opt']=option_name}
end
---Lookup the ID for a given disc.
---@param disc_name string @The name of the disc.
---@param option_name string @The name of the option which controls whether this disc should be used.
---@return table @Returns a table containing the disc name with rank, disc ID and the provided option name.
common.get_discid_and_name = function(disc_name, option_name)
    local disc_rank = mq.TLO.Spell(disc_name).RankName()
    return {['id']=mq.TLO.Spell(disc_rank).ID(), ['name']=disc_rank, ['opt']=option_name}
end

---Check that we nothing is currently being cast.
---@return boolean @Returns true if not currently casting anything, false otherwise.
common.can_cast_weave = function()
    return not mq.TLO.Me.Casting()
end

---Check whether the specified dot is applied to the target.
---@param spell_id number @The ID of the spell to check.
---@param spell_name string @The name of the spell to check.
---@return boolean @Returns true if the spell is applied to the target, false otherwise.
common.is_target_dotted_with = function(spell_id, spell_name)
    if not mq.TLO.Target.MyBuff(spell_name)() then return false end
    return spell_id == mq.TLO.Target.MyBuff(spell_name).ID()
end

---Determine whether currently fighting a target.
---@return boolean @True if standing with an NPC targeted, and not in a resting state, false otherwise.
common.is_fighting = function()
    --if mq.TLO.Target.CleanName() == 'Combat Dummy Beza' then return true end -- Dev hook for target dummy
    return mq.TLO.Target.ID() ~= nil and mq.TLO.Me.CombatState() ~= "ACTIVE" and mq.TLO.Me.CombatState() ~= "RESTING" and mq.TLO.Me.Standing() and not mq.TLO.Me.Feigning() and mq.TLO.Target.Type() == "NPC" and mq.TLO.Target.Type() ~= "Corpse"
end

---Calculate the distance between two points (x1,y1), (x2,y2).
---@param x1 number @The X value of the first coordinate.
---@param y1 number @The Y value of the first coordinate.
---@param x2 number @The X value of the second coordinate.
---@param y2 number @The Y value of the second coordinate.
---@return number @Returns the distance between the two points.
common.check_distance = function(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

---Determine whether currently alive or dead.
---@return boolean @Returns true if currently dead, false otherwise.
common.am_i_dead = function()
    if state.get_i_am_dead() and (mq.TLO.Me.Buff('Resurrection Sickness').ID() or mq.TLO.SpawnCount('pccorpse '..mq.TLO.Me.CleanName())() == 0) then
        state.set_i_am_dead(false)
    end
    return state.get_i_am_dead()
end

---Determine whether currently in control of the character, i.e. not CC'd, stunned, mezzed, etc.
---@return boolean @Returns true if not under any loss of control effects, false otherwise.
common.in_control = function()
    return not mq.TLO.Me.Stunned() and not mq.TLO.Me.Silenced() and not mq.TLO.Me.Feigning() and not mq.TLO.Me.Mezzed() and not mq.TLO.Me.Invulnerable() and not mq.TLO.Me.Hovering()
end

-- Movement Functions

---Chase after the assigned chase target if alive and in chase mode and the chase distance is exceeded.
common.check_chase = function()
    if config.get_mode():get_name() ~= 'chase' then return end
    if common.am_i_dead() or mq.TLO.Stick.Active() then return end
    local chase_spawn = mq.TLO.Spawn('pc ='..config.get_chase_target())
    local me_x = mq.TLO.Me.X()
    local me_y = mq.TLO.Me.Y()
    local chase_x = chase_spawn.X()
    local chase_y = chase_spawn.Y()
    if not chase_x or not chase_y then return end
    if common.check_distance(me_x, me_y, chase_x, chase_y) > config.get_chase_distance() then
        if not mq.TLO.Nav.Active() then
            mq.cmdf('/nav spawn pc =%s | log=off', config.get_chase_target())
        end
    end
end

---Return to camp if alive and in a camp mode and not currently fighting and more than 15ft from the camp center location.
common.check_camp = function()
    if not config.get_mode():is_camp_mode() then return end
    if common.am_i_dead() then return end
    if common.is_fighting() or not state.get_camp() then return end
    if mq.TLO.Zone.ID() ~= state.get_camp().ZoneID then
        logger.printf('Clearing camp due to zoning.')
        state.set_camp(nil)
        return
    end
    local camp = state.get_camp()
    if common.check_distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), camp.X, camp.Y) > 15 then
        if not mq.TLO.Nav.Active() then
            mq.cmdf('/nav locyxz %d %d %d log=off', camp.Y, camp.X, camp.Z)
        end
    end
end

--[[
Lua math degrees start from 0 on the right and go ccw
      90
       |
190____|____0
       |
       |
      270

MQ degrees start from 0 on the top and go cw
       0
       |
270____|____90
       |
       |
      180
]]--
---Convert an MQ heading degrees value to a "regular" degrees value.
---@param heading number @The MQ heading degrees value to convert.
---@return number @The regular heading degrees value.
common.convert_heading = function(heading)
    if heading > 270 then
        heading = 180 - heading + 270
    elseif heading > 180 then
        heading = 270 - heading + 180
    elseif heading > 90 then
        heading = 360 - heading + 90
    else
        heading = 90 - heading
    end
    return heading
end

---Draw a maploc at the given heading on the pull radius circle.
---@param heading number @The MQ heading degrees pointing to where to draw the maploc.
---@param color string @The color input to the /maploc command.
local function draw_maploc(heading, color)
    local my_x = mq.TLO.Me.X()
    local my_y = mq.TLO.Me.Y()
    if heading < 0 then
        heading = 360 - heading
    elseif heading > 360 then
        heading = heading - 360
    end
    local x_move = math.cos(math.rad(common.convert_heading(heading)))
    if x_move > 0 and heading > 0 and heading < 180 then
        x_move = x_move * -1
    elseif x_move < 0 and heading >= 180 then
        x_move = math.abs(x_move)
    end
    local y_move = math.sin(math.rad(common.convert_heading(heading)))
    if y_move > 0 and heading > 90 and heading < 270 then
        y_move = y_move * -1
    elseif y_move < 0 and (heading <= 90 or heading >= 270) then
        y_move = math.abs(y_move)
    end
    local x_off = my_x + config.get_pull_radius() * x_move
    local y_off = my_y + config.get_pull_radius() * y_move
    mq.cmdf('/squelch /maploc size 10 width 2 color %s radius 5 rcolor 0 0 0 %s %s', color, y_off, x_off)
end

---Set the left and right pull arc values based on the configured PULLARC option.
local function set_pull_angles()
    local pull_arc = config.get_pull_arc()
    if not pull_arc or pull_arc == 0 then return end
    local camp = state.get_camp()
    if not camp.HEADING then camp.HEADING = 0 end
    if camp.HEADING-(pull_arc*.5) < 0 then
        camp.PULL_ARC_LEFT = 360-((pull_arc*.5)-camp.HEADING)
    else
        camp.PULL_ARC_LEFT = camp.HEADING-(pull_arc*.5)
    end
    if camp.HEADING + (pull_arc*.5) > 360 then
        camp.PULL_ARC_RIGHT = (pull_arc*.5)+camp.HEADING-360
    else
        camp.PULL_ARC_RIGHT = (pull_arc*.5)+camp.HEADING
    end
    return camp
end

---Set, update or clear the CAMP values depending on whether currently in a camp mode or not.
---@param reset boolean @If true, then reset the camp to pickup the latest options.
common.set_camp = function(reset)
    if (config.get_mode():is_camp_mode() and not state.get_camp()) or reset then
        mq.cmd('/squelch /maploc remove')
        local camp = {
            ['X']=mq.TLO.Me.X(),
            ['Y']=mq.TLO.Me.Y(),
            ['Z']=mq.TLO.Me.Z(),
            ['HEADING']=mq.TLO.Me.Heading.Degrees(),
            ['ZoneID']=mq.TLO.Zone.ID()
        }
        logger.printf('Camp set to X: %s Y: %s Z: %s R: %s H: %s', camp.X, camp.Y, camp.Z, config.get_camp_radius(), camp.HEADING)
        mq.cmdf('/squelch /maploc size 10 width 1 color 255 0 0 radius %s rcolor 255 0 0 %s %s', config.get_camp_radius(), camp.Y+1, camp.X+1)
        if config.get_mode():is_pull_mode() then
            if config.get_pull_arc() > 0 and config.get_pull_arc() < 360 then
                camp = set_pull_angles()
                draw_maploc(camp.PULL_ARC_LEFT, '0 0 255')
                draw_maploc(camp.PULL_ARC_RIGHT, '0 0 255')
                draw_maploc(camp.HEADING, '255 0 0')
            end
            mq.cmdf('/squelch /maploc size 10 width 1 color 0 0 255 radius %s rcolor 0 0 255 %s %s', config.get_pull_radius(), camp.Y, camp.X)
        end
        state.set_camp(camp)
    elseif not config.get_mode():is_camp_mode() and state.get_camp() then
        state.set_camp(nil)
        mq.cmd('/squelch /mapf campradius 0')
        mq.cmd('/squelch /mapf pullradius 0')
        mq.cmd('/squelch /maploc remove')
    end
end

---Navigate to the current target if if isn't in LOS and should be.
common.check_los = function()
    if config.get_mode():get_name() ~= 'manual' and (common.is_fighting() or common.should_assist()) then
        if not mq.TLO.Target.LineOfSight() and not mq.TLO.Navigation.Active() then
            mq.cmd('/nav target log=off')
        end
    end
end

-- Camp Mob Control Functions

common.ASSIST_TARGET_ID = 0
common.TARGETS = {}
common.MOB_COUNT = 0

local xtar_corpse_count = 'xtarhater npccorpse radius %d zradius 50'
local xtar_count = 'xtarhater radius %d zradius 50'
local xtar_spawn = '%d, xtarhater radius %d zradius 50'
---Determine the number of mobs within the camp radius.
---Sets common.MOB_COUNT to the total number of mobs on xtarget within the camp radius.
---Adds the mob ID of each mob found to the common.TARGETS table.
common.mob_radar = function()
    local num_corpses = 0
    num_corpses = mq.TLO.SpawnCount(xtar_corpse_count:format(config.get_camp_radius()))()
    common.MOB_COUNT = mq.TLO.SpawnCount(xtar_count:format(config.get_camp_radius()))() - num_corpses
    if common.MOB_COUNT > 0 then
        for i=1,common.MOB_COUNT do
            if i > 13 then break end
            local mob = mq.TLO.NearestSpawn(xtar_spawn:format(i, config.get_camp_radius()))
            local mob_id = mob.ID()
            if mob_id and mob_id > 0 then
                if not mob() or mob.Type() == 'Corpse' then
                    common.TARGETS[mob_id] = nil
                    num_corpses = num_corpses+1
                elseif not common.TARGETS[mob_id] then
                    logger.debug(state.get_debug(), 'Adding mob_id %d', mob_id)
                    common.TARGETS[mob_id] = {meztimer=0}
                end
            end
        end
        common.MOB_COUNT = common.MOB_COUNT - num_corpses
    end
end

---Checks for any mobs in common.TARGETS which are no longer valid and removes them from the table.
common.clean_targets = function()
    for mobid,_ in pairs(common.TARGETS) do
        local spawn = mq.TLO.Spawn(string.format('id %s', mobid))
        if not spawn() or spawn.Type() == 'Corpse' then
            common.TARGETS[mobid] = nil
        end
    end
end

-- Pull Functions

local PULL_IN_PROGRESS = false
common.TANK_MOB_ID = 0
common.PULL_MOB_ID = 0
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
    local direction_to_mob = pull_spawn.HeadingTo(camp.Y, camp.X).Degrees()
    if not direction_to_mob then return false end
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

--loc ${s_WorkSpawn.X} ${s_WorkSpawn.Y}
local pull_count = 'npc radius %d'-- zradius 50'
local pull_spawn = '%d, npc radius %d'-- zradius 50'
local pull_count_camp = 'npc loc %d %d radius %d'-- zradius 50'
local pull_spawn_camp = '%d, npc loc %d %d radius %d'-- zradius 50'
local pc_near = 'pc radius 30 loc %d %d'
---Search for pullable mobs within the configured pull radius.
---Sets common.PULL_MOB_ID to the mob ID of the first matching spawn.
common.pull_radar = function()
    local pull_radius_count
    local pull_radius = config.get_pull_radius()
    local camp = state.get_camp()
    if camp then
        pull_radius_count = mq.TLO.SpawnCount(pull_count_camp:format(camp.X, camp.Y, pull_radius))()
    else
        pull_radius_count = mq.TLO.SpawnCount(pull_count:format(common.OPTS.PULLRADIUS))()
    end
    if pull_radius_count > 0 then
        for i=1,pull_radius_count do
            local mob
            if camp then
                mob = mq.TLO.NearestSpawn(pull_spawn_camp:format(i, camp.X, camp.Y, pull_radius))
            else
                mob = mq.TLO.NearestSpawn(pull_spawn:format(i, pull_radius))
            end 
            local mob_id = mob.ID()
            local pathlen = mq.TLO.Navigation.PathLength('id '..mob_id)()
            if mob_id > 0 and not PULL_TARGET_SKIP[mob_id] and mob.Type() ~= 'Corpse' and pathlen > 0 and pathlen < pull_radius and check_mob_angle(mob) and check_z_rad(mob) and check_level(mob) then
                -- TODO: check for people nearby, check level, check z radius if high/low differ
                --local pc_near_count = mq.TLO.SpawnCount(pc_near:format(mob.X(), mob.Y()))
                --if pc_near_count == 0 then
                common.PULL_MOB_ID = mob_id
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
        common.PULL_MOB_ID = 0
        return false
    end
    if common.check_distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), mob_x, mob_y) > 10 then
        logger.debug(state.get_debug(), 'Moving to pull target (%s)', common.PULL_MOB_ID)
        if not mq.TLO.Navigation.Active() then
            mq.cmdf('/nav spawn id %d | log=off', common.PULL_MOB_ID)
            mq.delay(100, function() return mq.TLO.Navigation.Active() end)
        end
        -- TODO: disrupt if mob aggro otw to pull
        mq.delay('15s', function()
            if not pull_spawn then
                return false
            end
            local dist3d = pull_spawn.Distance3D()
            -- return right away if we can't read distance, as pull spawn is probably no longer valid
            if not dist3d then return true end
            -- return true once target is in range and in LOS, or if something appears on xtarget
            return (pull_spawn.LineOfSight() and dist3d < 200) or dist3d < 15 or mq.TLO.Me.XTarget() > 0
        end)
    end
    return true
end

---Reset common mob ID variables to 0 to reset pull status.
local function clear_pull_vars()
    common.TANK_MOB_ID = 0
    common.PULL_MOB_ID = 0
    PULL_IN_PROGRESS = false
end

---Aggro the specified target to be pulled. Attempts to use bow and moves closer to melee pull if necessary.
---@param pull_spawn Spawn @The MQ Spawn to be pulled.
local function pull_engage(pull_spawn)
    -- pull  mob
    local dist3d = pull_spawn.Distance3D()
    if not dist3d or not pull_spawn.LineOfSight() or dist3d > 200 then
        logger.printf('Pull target no longer valid (%s)', common.PULL_MOB_ID)
        clear_pull_vars()
        return
    end
    pull_spawn.DoTarget()
    mq.delay(50, function() return mq.TLO.Target.ID() == pull_spawn.ID() end)
    if not mq.TLO.Target() then
        logger.printf('Pull target no longer valid (%s)', common.PULL_MOB_ID)
        clear_pull_vars()
        return
    end
    local tot_id = mq.TLO.Me.TargetOfTarget.ID()
    if (tot_id > 0 and tot_id ~= mq.TLO.Me.ID()) then --or mq.TLO.Target.PctHPs() < 100 then
        logger.printf('Pull target already engaged, skipping (%s)', common.PULL_MOB_ID)
        -- TODO: clear skip targets
        PULL_TARGET_SKIP[common.PULL_MOB_ID] = 1
        clear_pull_vars()
        return
    end
    logger.printf('Pulling %s (%s)', mq.TLO.Target.CleanName(), mq.TLO.Target.ID())
    --logger.printf('facing mob')
    if mq.TLO.Navigation.Active() then
        mq.cmd('/squelch /nav stop')
        mq.delay(100, function() return not mq.TLO.Navigation.Active() end)
    end
    mq.cmd('/face fast')
    --logger.printf('agroing mob')
    -- TODO: class pull abilities
    local get_closer = false
    if mq.TLO.Target.Distance3D() < 35 then
        -- use class close range pull ability
        mq.cmd('/squelch /stick front loose moveback 10')
        -- /stick mod 0
        mq.cmd('/attack on')
        mq.delay('1s', function() return mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID() end)
    else
        if mq.TLO.Me.Combat() then
            mq.cmd('/attack off')
            mq.delay(100)
        end
        mq.cmd('/autofire on')
        --mq.delay(50, function() return mq.TLO.Me.AutoFire() end)
        mq.delay(100)
        if not mq.TLO.Me.AutoFire() then
            mq.cmd('/autofire on')
        end
        -- use class long range pull ability
        -- tag with range
        get_closer = true
        mq.delay('3s', function() return mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID() end)
    end
    --logger.printf('mob agrod or timed out')
    mq.cmd('/multiline ; /attack off; /autofire off; /stick off;')

    if mq.TLO.Me.XTarget() == 0 and get_closer then
        if not mq.TLO.Navigation.Active() then
            mq.cmdf('/nav spawn id %d | log=off', common.PULL_MOB_ID)
            mq.delay(100, function() return mq.TLO.Navigation.Active() end)
        end
        -- TODO: disrupt if mob aggro otw to pull
        mq.delay('15s', function()
            if not pull_spawn then
                return false
            end
            local dist3d = pull_spawn.Distance3D()
            -- return right away if we can't read distance, as pull spawn is probably no longer valid
            if not dist3d then return true end
            -- return true once target is in range and in LOS, or if something appears on xtarget
            return pull_spawn.LineOfSight() and dist3d < 20 or mq.TLO.Me.XTarget() > 0
        end)

        if mq.TLO.Navigation.Active() then
            mq.cmd('/squelch /nav stop')
            mq.delay(100, function() return not mq.TLO.Navigation.Active() end)
        end

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
    logger.debug(state.get_debug(), 'Waiting for pull target to reach camp (%s)', common.PULL_MOB_ID)
    mq.cmd('/face fast')
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
common.pull_mob = function()
    if common.PULL_MOB_ID == 0 then return end
    if common.am_i_dead() then return end
    local pull_spawn = mq.TLO.Spawn(common.PULL_MOB_ID)
    if not pull_spawn then
        common.PULL_MOB_ID = 0
        return
    end

    PULL_IN_PROGRESS = true
    -- move to pull target
    if not pull_nav_to(pull_spawn) then return end
    if mq.TLO.Me.XTarget() == 0 then
        pull_engage(pull_spawn)
    else
        logger.printf('Mobs on xtarget, canceling pull and returning to camp')
        clear_pull_vars()
        pull_return()
        return
    end
    -- return to camp
    if state.get_camp() and not mq.TLO.Navigation.Active() then
        pull_return()
    end
    --common.TANK_MOB_ID = common.PULL_MOB_ID -- pull mob reached camp, mark it as tank mob
    common.PULL_MOB_ID = 0 -- pull done, clear pull mob id
    PULL_IN_PROGRESS = false
end

--- Tank Functions

---Iterate through mobs in the common.TARGETS table and find a mob in camp to begin tanking.
---Sets common.TANK_MOB_ID to the ID of the mob to tank.
common.find_mob_to_tank = function()
    if common.MOB_COUNT == 0 then return end
    if common.am_i_dead() then return end
    if common.TANK_MOB_ID > 0 and mq.TLO.Target() and mq.TLO.Target.Type() ~= 'Corpse' then
        return
    else
        common.TANK_MOB_ID = 0
    end
    logger.debug(state.get_debug(), 'Find mob to tank')
    local highestlvl = 0
    local highestlvlid = 0
    local lowesthp = 100
    local lowesthpid = 0
    local firstid = 0
    for id,_ in pairs(common.TARGETS) do
        -- loop through for named, highest level, unmezzed, lowest hp
        local mob = mq.TLO.Spawn(id)
        if mob() then
            if firstid == 0 then firstid = mob.ID() end
            if mob.Named() then
                logger.debug(state.get_debug(), 'Selecting Named mob to tank next (%s)', mob.ID())
                common.TANK_MOB_ID = mob.ID()
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
        common.TANK_MOB_ID = lowesthpid
        return
    elseif highestlvlid ~= 0 then
        logger.debug(state.get_debug(), 'Selecting highest level mob to tank next (%s)', highestlvlid)
        common.TANK_MOB_ID = highestlvlid
        return
    end
    -- no named or unmezzed mobs, break a mez
    if firstid ~= 0 then
        logger.debug(state.get_debug(), 'Selecting first available mob to tank next (%s)', firstid)
        common.TANK_MOB_ID = firstid
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
common.tank_mob = function()
    if common.TANK_MOB_ID == 0 then return end
    if common.am_i_dead() then return end
    local tank_spawn = mq.TLO.Spawn(common.TANK_MOB_ID)
    if not tank_spawn() or tank_spawn.Type() == 'Corpse' then
        common.TANK_MOB_ID = 0
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
        common.TANK_MOB_ID = 0
        return
    end
    if mq.TLO.Navigation.Active() then
        mq.cmd('/squelch /nav stop')
    end
    mq.cmd('/face fast')
    if not mq.TLO.Me.Combat() then
        logger.printf('Tanking %s (%s)', mq.TLO.Target.CleanName(), common.TANK_MOB_ID)
        mq.cmd('/squelch /stick front loose moveback 10')
        -- /stick snaproll front moveback
        -- /stick mod -2
        mq.cmd('/attack on')
    end
end

--- Assist Functions

---Get the spawn ID of the configured main assist, NOT the assists target.
---@return integer @Returns the spawn ID of the main assist, NOT the assists target.
common.get_assist_id = function()
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
common.get_assist_spawn = function()
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
common.should_assist = function(assist_target)
    if not assist_target then assist_target = common.get_assist_spawn() end
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
        if common.CAMP and common.check_distance(camp.X, camp.Y, mob_x, mob_y) <= camp_radius then
            return true
        elseif not common.CAMP and common.check_distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), mob_x, mob_y) <= camp_radius then
            return true
        end
    else
        return false
    end
end

local send_pet_timer = 0
local stick_timer = 0

---Reset common combat timers to 0.
local function reset_combat_timers()
    stick_timer = 0
    send_pet_timer = 0
end

---Acquire the correct target when running in an assist mode. Clears target if the main assist targets themself.
---Targets the main assists target if assist conditions are met.
---If currently engaged, remains on the current target unless the switch with MA option is enabled.
---Sets common.ASSIST_TARGET_ID to 0 or the ID of the mob to assist on.
---@param reset_timers function @An optional function to be called to reset combat timers specific to the class calling this function.
common.check_target = function(reset_timers)
    if common.am_i_dead() then return end
    if config.get_mode():get_name() ~= 'manual' then
        local assist_target = common.get_assist_spawn()
        if not assist_target() then return end
        if mq.TLO.Target() and mq.TLO.Target.Type() == 'NPC' and assist_target.ID() == common.get_assist_id() then
            -- if we are targeting a mob, but the MA is targeting themself, then stop what we're doing
            mq.cmd('/multiline ; /target clear; /pet back; /autoattack off; /autofire off;')
            common.ASSIST_TARGET_ID = 0
            return
        end
        if common.is_fighting() then
            -- already fighting
            if mq.TLO.Target.ID() == assist_target.ID() then
                -- already fighting the MAs target
                common.ASSIST_TARGET_ID = assist_target.ID()
                return
            elseif not config.get_switch_with_ma() then
                -- not fighting the MAs target, and switch with MA is disabled, so stay on current target
                return
            end
        end
        if common.ASSIST_TARGET_ID == assist_target.ID() and assist_target.Type() ~= 'Corpse' then
            -- MAs target didn't change but we aren't currently fighting it for some reason, so reacquire target
            assist_target.DoTarget()
            return
        end
        if mq.TLO.Target.ID() ~= assist_target.ID() and common.should_assist(assist_target) then
            -- this is a brand new assist target
            common.ASSIST_TARGET_ID = assist_target.ID()
            assist_target.DoTarget()
            if mq.TLO.Me.Sitting() then mq.cmd('/stand') end
            reset_combat_timers()
            if reset_timers then reset_timers() end
            logger.printf('Assisting on >>> \ay%s\ax <<<', mq.TLO.Target.CleanName())
        end
    end
end

---Navigate to the current target if the target is within the camp radius.
common.get_combat_position = function()
    local target_id = mq.TLO.Target.ID()
    local target_distance = mq.TLO.Target.Distance3D()
    if not target_id or target_id == 0 or (target_distance and target_distance > config.get_camp_radius()) or state.get_paused() then
        return
    end
    mq.cmdf('/nav id %d log=off', target_id)
    local begin_time = common.current_time()
    while true do
        if mq.TLO.Target.LineOfSight() then
            mq.cmd('/squelch /nav stop')
            break
        end
        if os.difftime(begin_time, common.current_time()) > 5 then
            break
        end
        mq.delay(1)
    end
    if mq.TLO.Navigation.Active() then mq.cmd('/squelch /nav stop') end
end

---Begin attacking the assist target if not already attacking.
common.attack = function()
    if common.ASSIST_TARGET_ID == 0 or mq.TLO.Target.ID() ~= common.ASSIST_TARGET_ID or not common.should_assist() then
        if mq.TLO.Me.Combat() then mq.cmd('/attack off') end
        return
    end
    if not mq.TLO.Target.LineOfSight() then common.get_combat_position() end
    if mq.TLO.Navigation.Active() then
        mq.cmd('/squelch /nav stop')
    end
    if not mq.TLO.Stick.Active() and common.timer_expired(stick_timer, 3) then
        mq.cmd('/squelch /stick loose moveback 10 uw')
        stick_timer = common.current_time()
    end
    if not mq.TLO.Me.Combat() and mq.TLO.Target() then
        mq.cmd('/attack on')
    end
end

---Send pet and swarm pets against the assist target if assist conditions are met.
common.send_pet = function()
    if common.timer_expired(send_pet_timer, 5) and (common.is_fighting() or common.should_assist()) then
        if mq.TLO.Pet.ID() > 0 and mq.TLO.Pet.Target.ID() ~= mq.TLO.Target.ID() then
            mq.cmd('/multiline ; /pet attack ; /pet swarm')
        else
            mq.cmd('/pet swarm')
        end
        send_pet_timer = common.current_time()
    end
end

-- Casting Functions

---Cast the spell specified by spell_name.
---@param spell_name string @The name of the spell to be cast.
---@param requires_target boolean @Indicate whether the spell requires a target.
---@param requires_los boolean @Indicate whether the spell requires line of sight to the target.
common.cast = function(spell_name, requires_target, requires_los)
    if not common.in_control() or (requires_los and not mq.TLO.Target.LineOfSight()) or mq.TLO.Me.Moving() then return end
    logger.printf('Casting \ar%s\ax', spell_name)
    mq.cmdf('/cast "%s"', spell_name)
    mq.delay(10)
    if not mq.TLO.Me.Casting() then mq.cmdf('/cast %s', spell_name) end
    mq.delay(10)
    if not mq.TLO.Me.Casting() then mq.cmdf('/cast %s', spell_name) end
    mq.delay(10)
    while mq.TLO.Me.Casting() do
        if requires_target and not mq.TLO.Target() then
            mq.cmd('/stopcast')
            break
        end
        mq.delay(10)
    end
end

---Use the ability specified by name. These are basic abilities like taunt or kick.
---@param name string @The name of the ability to use.
common.use_ability = function(name)
    if mq.TLO.Me.AbilityReady(name)() and mq.TLO.Target() then
        mq.cmdf('/doability %s', name)
        mq.delay(300, function() return not mq.TLO.Me.AbilityReady(name)() end)
    end
end

---Use the item specified by item.
---@param item Item @The MQ Item userdata object.
common.use_item = function(item)
    if not common.in_control() then return end
    if item.Timer() == '0' then
        if item.Clicky.Spell.TargetType() == 'Single' and not mq.TLO.Target() then return end
        if common.can_cast_weave() then
            logger.printf('Use Item: \ax\ar%s\ax', item)
            mq.cmdf('/useitem "%s"', item)
            mq.delay(50)
            mq.delay(250+item.CastTime()) -- wait for cast time + some buffer so we don't skip over stuff
        end
    end
end

---Use the AA specified in the passed in table aa.
---@param aa table @A table containing the AA name and ID.
---@return boolean @Returns true if the ability was fired, otherwise false.
common.use_aa = function(aa)
    if not common.in_control() then return end
    if mq.TLO.Me.AltAbility(aa['name']).Spell.EnduranceCost() > 0 and mq.TLO.Me.PctEndurance() < state.get_min_end() then return end
    if mq.TLO.Me.AltAbility(aa['name']).Spell.TargetType() == 'Single' then
        if mq.TLO.Target() and not mq.TLO.Target.MyBuff(aa['name'])() and mq.TLO.Me.AltAbilityReady(aa['name'])() and common.can_cast_weave() and mq.TLO.Me.AltAbility(aa['name']).Spell.EnduranceCost() < mq.TLO.Me.CurrentEndurance() then
            logger.printf('Use AA: \ax\ar%s\ax', aa['name'])
            mq.cmdf('/alt activate %d', aa['id'])
            mq.delay(50)
            mq.delay(250+mq.TLO.Me.AltAbility(aa['name']).Spell.CastTime()) -- wait for cast time + some buffer so we don't skip over stuff
            return true
        end
    elseif not mq.TLO.Me.Song(aa['name'])() and not mq.TLO.Me.Buff(aa['name'])() and mq.TLO.Me.AltAbilityReady(aa['name'])() and common.can_cast_weave() then
        logger.printf('Use AA: \ax\ar%s\ax', aa['name'])
        mq.cmdf('/alt activate %d', aa['id'])
        mq.delay(50)
        mq.delay(250+mq.TLO.Me.AltAbility(aa['name']).Spell.CastTime()) -- wait for cast time + some buffer so we don't skip over stuff
        return true
    end
    return false
end

---Use the disc specified in the passed in table disc.
---@param disc table @A table containing the disc name and ID.
---@param overwrite boolean @The name of a disc which should be stopped in order to run this disc.
---@param skip_duration_check boolean @Indivate whether to skip checking the disc duration and current active disc, primarily for Breather line of discs.
common.use_disc = function(disc, overwrite, skip_duration_check)
    if not common.in_control() then return end
    if mq.TLO.Me.CombatAbility(disc['name'])() and mq.TLO.Me.CombatAbilityTimer(disc['name'])() == '0' and mq.TLO.Me.CombatAbilityReady(disc['name'])() and mq.TLO.Spell(disc['name']).EnduranceCost() < mq.TLO.Me.CurrentEndurance() then
        if skip_duration_check or not mq.TLO.Me.ActiveDisc.ID() or (tonumber(mq.TLO.Spell(disc['name']).Duration()) and tonumber(mq.TLO.Spell(disc['name']).Duration()) < 6) then
            logger.printf('Use Disc: \ax\ar%s\ax', disc['name'])
            if disc['name']:find('Composite') then
                mq.cmdf('/disc %s', disc['id'])
                mq.delay(50)
                mq.delay(250, function() return not mq.TLO.Me.CombatAbilityReady(disc['name'])() end)
            else
                mq.cmdf('/disc %s', disc['name'])
                mq.delay(50)
                mq.delay(250, function() return not mq.TLO.Me.CombatAbilityReady(disc['name'])() end)
            end
        elseif overwrite == mq.TLO.Me.ActiveDisc.Name() then
            mq.cmd('/stopdisc')
            mq.delay(50)
            logger.printf('Use Disc: \ax\ar%s\ax', disc['name'])
            mq.cmdf('/disc %s', disc['name'])
            mq.delay(50)
            mq.delay(250, function() return not mq.TLO.Me.CombatAbilityReady(disc['name'])() end)
        end
    end
end

-- Burn Helper Functions

---Determine whether the conditions are met to engage burn routines.
---@param always_condition function @An extra function which can be provided to determine if the always burn condition should fire.
---@return boolean @Returns true if any burn condition is satisfied, otherwise false.
common.is_burn_condition_met = function(always_condition)
    -- activating a burn condition is good for 60 seconds, don't do check again if 60 seconds hasn't passed yet and burn is active.
    if common.time_remaining(state.get_burn_active_timer(), 30) and state.get_burn_active() then
        return true
    else
        state.set_burn_active(false)
    end
    if state.get_burn_now() then
        logger.printf('\arActivating Burns (on demand)\ax')
        state.set_burn_active_timer(common.current_time())
        state.set_burn_active(true)
        state.set_burn_now(false)
        return true
    elseif common.is_fighting() then
        if config.get_burn_always() then
            if always_condition and not always_condition() then
                return false
            end
            return true
        elseif config.get_burn_all_named() and mq.TLO.Target.Named() then
            logger.printf('\arActivating Burns (named)\ax')
            state.set_burn_active_timer(common.current_time())
            state.set_burn_active(true)
            return true
        elseif mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.get_camp_radius()))() >= config.get_burn_count() then
            logger.printf('\arActivating Burns (mob count > %d)\ax', config.get_burn_count())
            state.set_burn_active_timer(common.current_time())
            state.set_burn_active(true)
            return true
        elseif config.get_burn_percent() ~= 0 and mq.TLO.Target.PctHPs() < config.get_burn_percent() then
            logger.printf('\arActivating Burns (percent HP)\ax')
            state.set_burn_active_timer(common.current_time())
            state.set_burn_active(true)
            return true
        end
    end
    state.set_burn_active_timer(0)
    state.set_burn_active(false)
    return false
end

-- Spell Helper Functions

---Determine whether the specified spell is memorized in the gem.
---@param spell_name string @The spell name to check is memorized.
---@param gem number @The spell gem index the spell should be memorized in.
---@return boolean @Returns true if the spell is memorized in the specified gem, otherwise false.
common.swap_gem_ready = function(spell_name, gem)
    return mq.TLO.Me.Gem(gem)() and mq.TLO.Me.Gem(gem).Name() == spell_name
end

---Swap the specified spell into the specified gem slot.
---@param spell_name string @The name of the spell to memorize.
---@param gem number @The gem index to memorize the spell into.
common.swap_spell = function(spell_name, gem)
    if not gem or common.am_i_dead() then return end
    mq.cmdf('/memspell %d "%s"', gem, spell_name)
    mq.delay('3s', common.swap_gem_ready(spell_name, gem))
    mq.TLO.Window('SpellBookWnd').DoClose()
end

---Check Geomantra buff and click charm item if missing and item is ready.
common.check_combat_buffs = function()
    if not mq.TLO.Me.Buff('Geomantra')() then
        common.use_item(mq.TLO.InvSlot('Charm').Item)
    end
end

---Check and cast any missing familiar, illusion or mount buffs. Removes illusion and dismounts after casting.
common.check_item_buffs = function()
    if familiar and familiar > 0 and not mq.TLO.Me.Buff('Familiar:')() then
        common.use_item(mq.TLO.FindItem(familiar))
    end
    if illusion and illusion > 0 and not mq.TLO.Me.Buff('Illusion Benefit')() then
        common.use_item(mq.TLO.FindItem(illusion))
        mq.delay(50)
        mq.cmd('/removebuff illusion:')
    end
    if mount and mount > 0 and not mq.TLO.Me.Buff('Mount Blessing')() and mq.TLO.Me.CanMount() then
        common.use_item(mq.TLO.FindItem(mount))
        mq.delay(50)
        mq.cmdf('/removebuff %s', mq.TLO.FindItem(mount).Clicky())
    end
end

---Attempt to click mod rods if mana is below 75%.
common.check_mana = function()
    -- modrods
    local pct_mana = mq.TLO.Me.PctMana()
    local pct_end = mq.TLO.Me.PctEndurance()
    if pct_mana < 75 then
        -- Find ModRods in check_mana since they poof when out of charges, can't just find once at startup.
        local item_aa_modrod = mq.TLO.FindItem('Summoned: Dazzling Modulation Shard')
        common.use_item(item_aa_modrod)
        local item_wand_modrod = mq.TLO.FindItem('Sickle of Umbral Modulation')
        common.use_item(item_wand_modrod)
        local item_wand_old = mq.TLO.FindItem('Wand of Restless Modulation')
        common.use_item(item_wand_old)
    end
    -- unified phoenix feather
end

local sit_timer = 0
---Sit down to med if the conditions for resting are met.
common.rest = function()
    -- try to avoid just constant stand/sit, mainly for dumb bard sitting between every song
    if common.timer_expired(sit_timer, 10) then
        if not common.is_fighting() and not mq.TLO.Me.Sitting() and not mq.TLO.Me.Moving() and ((mq.TLO.Me.Class.CanCast() and mq.TLO.Me.PctMana() < 60) or mq.TLO.Me.PctEndurance() < 60) and not mq.TLO.Me.Casting() and mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.get_camp_radius()))() == 0 then
            mq.cmd('/sit')
            sit_timer = common.current_time()
        end
    end
end

-- keep cursor clear for spell swaps and such
local autoinv_timer = 0
---Autoinventory an item if it has been on the cursor for 15 seconds.
common.check_cursor = function()
    if mq.TLO.Cursor() then
        if autoinv_timer == 0 then
            autoinv_timer = common.current_time()
            logger.printf('Dropping cursor item into inventory in 15 seconds')
        elseif os.difftime(common.current_time(), autoinv_timer) > 15 then
            mq.cmd('/autoinventory')
            autoinv_timer = 0
        end
    elseif autoinv_timer > 0 then
        logger.debug(state.get_debug(), 'Cursor is empty, resetting autoinv_timer')
        autoinv_timer = 0
    end
end

---Set common.I_AM_DEAD flag to true in the event of death.
local function event_dead()
    logger.printf('HP hit 0. what do!')
    state.set_i_am_dead(true)
end

---Initialize the player death event triggers.
common.setup_events = function()
    mq.event('event_dead_released', '#*#Returning to Bind Location#*#', event_dead)
    mq.event('event_dead', 'You died.', event_dead)
    mq.event('event_dead_slain', 'You have been slain by#*#', event_dead)
end

return common