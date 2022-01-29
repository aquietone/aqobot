--- @type mq
local mq = require 'mq'
local config = require('aqo.configuration')
local logger = require('aqo.utils.logger')
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
    if common.am_i_dead() or mq.TLO.Stick.Active() or mq.TLO.Me.AutoFire() or mq.TLO.Me.Casting() then return end
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

-- Casting Functions

---Cast the spell specified by spell_name.
---@param spell_name string @The name of the spell to be cast.
---@param requires_target boolean @Indicate whether the spell requires a target.
---@param requires_los boolean @Indicate whether the spell requires line of sight to the target.
common.cast = function(spell_name, requires_target, requires_los)
    if not common.in_control() or (requires_los and not mq.TLO.Target.LineOfSight()) or mq.TLO.Me.Moving() then return end
    if not mq.TLO.Me.SpellReady(spell_name)() then return end
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