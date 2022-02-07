--- @type mq
local mq = require 'mq'
local logger = require('aqo.utils.logger')
local timer = require('aqo.utils.timer')
local config = require('aqo.configuration')
local state = require('aqo.state')

local common = {}

common.ASSISTS = {group=1,raid1=1,raid2=1,raid3=1}
common.FD_CLASSES = {mnk=1,bst=1,shd=1,nec=1}
common.BOOL = {
    ['TRUE']={
        ['1']=1, ['true']=1,['on']=1,['TRUE']=1,['ON']=1,
    },
    ['FALSE']={
        ['0']=1, ['false']=1,['off']=1,['FALSE']=1,['OFF']=1,
    },
}
common.DMZ = {
    [344] = 1,
    [345] = 1,
    [202] = 1,
    [203] = 1,
    [279] = 1,
    [151] = 1,
    [33506] = 1,
}

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
    if not mq.TLO.Me.Book(spell_rank)() then return nil end
    return {['id']=mq.TLO.Spell(spell_rank).ID(), ['name']=spell_rank, ['opt']=option_name}
end
---Lookup the ID for a given AA.
---@param aa_name string @The name of the AA.
---@param option_name string @The name of the option which controls whether this AA should be used.
---@return table @Returns a table containing the AA name, AA ID and the provided option name.
common.get_aaid_and_name = function(aa_name, option_name)
    if not mq.TLO.Me.AltAbility(aa_name)() then return nil end
    return {['id']=mq.TLO.Me.AltAbility(aa_name).ID(), ['name']=aa_name, ['opt']=option_name}
end
---Lookup the ID for a given disc.
---@param disc_name string @The name of the disc.
---@param option_name string @The name of the option which controls whether this disc should be used.
---@return table @Returns a table containing the disc name with rank, disc ID and the provided option name.
common.get_discid_and_name = function(disc_name, option_name)
    local disc_rank = mq.TLO.Spell(disc_name).RankName()
    if not disc_rank then return nil end
    return {['id']=mq.TLO.Spell(disc_rank).ID(), ['name']=disc_rank, ['opt']=option_name}
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
    -- mq.TLO.Me.CombatState() ~= "ACTIVE" and mq.TLO.Me.CombatState() ~= "RESTING" and mq.TLO.Target.Type() ~= "Corpse" and not mq.TLO.Me.Feigning()
    return mq.TLO.Target.ID() and mq.TLO.Me.CombatState() == 'COMBAT' and mq.TLO.Me.Standing() and mq.TLO.Target.Type() == "NPC"
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
        state.set_assist_mob_id(0)
        state.set_tank_mob_id(0)
        state.set_pull_mob_id(0)
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
    if not common.in_control() or mq.TLO.Me.Moving() then return end
    if not mq.TLO.Me.SpellReady(spell_name)() then return end
    if mq.TLO.Spell(spell_name).Mana() > mq.TLO.Me.CurrentMana() then return end
    if requires_target then
        if requires_los and not mq.TLO.Target.LineOfSight() then return end
        local dist3d = mq.TLO.Target.Distance3D()
        if not dist3d or dist3d > mq.TLO.Spell(spell_name).MyRange() then return end
        if mq.TLO.Spell(name).TargetType() == 'Single' and mq.TLO.Me.XTarget() == 0 then return end
    end
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
    if mq.TLO.Me.AbilityReady(name)() and mq.TLO.Target() and mq.TLO.Me.XTarget() > 0 then
        mq.cmdf('/doability %s', name)
        mq.delay(500, function() return not mq.TLO.Me.AbilityReady(name)() end)
    end
end

---Use the item specified by item.
---@param item Item @The MQ Item userdata object.
common.use_item = function(item)
    if not common.in_control() or mq.TLO.Me.Casting() then return end
    if item.Timer() == '0' then
        if item.Clicky.Spell.TargetType() == 'Single' then
            if not mq.TLO.Target() then return end
            local dist3d = mq.TLO.Target.Distance3D()
            if not dist3d or dist3d > item.Clicky.Spell.Range() then return end
        end
        if item.Clicky.Spell.TargetType() == 'Self' and not item.Clicky.Spell.SpellGroup() == 17000 and not item.Clicky.Spell.Stacks() then return end
        if not mq.TLO.Me.Casting() then
            logger.printf('Use Item: \ax\ar%s\ax', item)
            mq.cmdf('/useitem "%s"', item)
            mq.delay(500+item.CastTime()) -- wait for cast time + some buffer so we don't skip over stuff
        end
    end
end

---Determine whether conditions are met to use the AA specified by name.
---@param name string @The AA to use.
---@return boolean @Returns true if the AA can be used, otherwise false.
local function can_use_aa(name)
    if not common.in_control() or mq.TLO.Me.Casting() then return false end
    local spell = mq.TLO.Me.AltAbility(name).Spell
    if spell.EnduranceCost() > 0 and mq.TLO.Me.PctEndurance() < state.get_min_end() then return false end
    if spell.Mana() > mq.TLO.Me.CurrentMana() or spell.EnduranceCost() > mq.TLO.Me.CurrentEndurance() then return false end
    if spell.TargetType() == 'Single' then
        if not mq.TLO.Target() then return false end
        local dist3d = mq.TLO.Target.Distance3D()
        if not dist3d or dist3d > spell.Range() then return false end
        if mq.TLO.Target.MyBuff(name)() then return false end
        if mq.TLO.Me.XTarget() == 0 then return false end
    elseif spell.TargetType() == 'Self' then
        if mq.TLO.Me.Song(name)() or mq.TLO.Me.Buff(name)() then return false end
        if not mq.TLO.Spell(spell.Name()).Stacks() then return false end
    end
    return true
end

---Determine whether an AA is ready, including checking whether the character is currently capable.
---@param name string @The name of the AA to be used.
---@return boolean @Returns true if the AA is ready to be used, otherwise false.
local function aa_ready(name)
    if mq.TLO.Me.AltAbilityReady(name)() then
        return can_use_aa(name)
    else
        return false
    end
end

---Use the AA specified in the passed in table aa.
---@param aa table @A table containing the AA name and ID.
---@return boolean @Returns true if the ability was fired, otherwise false.
common.use_aa = function(aa)
    if aa_ready(aa['name']) then
        logger.printf('Use AA: \ax\ar%s\ax', aa['name'])
        mq.cmdf('/alt activate %d', aa['id'])
        mq.delay(250+mq.TLO.Me.AltAbility(aa['name']).Spell.CastTime()) -- wait for cast time + some buffer so we don't skip over stuff
        mq.delay(250, function() return not mq.TLO.Me.AltAbilityReady(aa['name'])() end)
        return true
    end
    return false
end

--[[
bool IsActiveDisc(EQ_Spell* pSpell) {
    if (!InGame())
        return false;

    if ((pSpell->DurationType == 11 || pSpell->DurationType == 15) &&
        pSpell->SpellType == ST_Beneficial &&
        pSpell->TargetType == TT_Self &&
        (pSpell->Skill == 33 || pSpell->Skill == 15) &&
        pSpell->spaindex == 51 &&
        pSpell->SpellAnim != 0 &&
        pSpell->Subcategory != 155)
        return true;

    return false;
}
]]--
---Determine whether the disc specified by name is an "active" disc that appears in ${Me.ActiveDisc}.
---@param name string @The name of the disc to check.
---@return boolean @Returns true if the disc is an active disc, otherwise false.
local function is_disc(name)
    if mq.TLO.Spell(name).IsSkill() and (tonumber(mq.TLO.Spell(name).Duration()) and tonumber(mq.TLO.Spell(name).Duration()) > 0) and mq.TLO.Spell(name).TargetType() == 'Self' and not mq.TLO.Spell(name).StacksWithDiscs() then
        return true
    else
        return false
    end
end

---Determine whether conditions are met to use the disc specified by name.
---@param name string @The disc to use.
---@return boolean @Returns true if the disc can be used, otherwise false.
local function can_use_disc(name)
    if not common.in_control() or mq.TLO.Me.Casting() then return false end
    if mq.TLO.Spell(name).EnduranceCost() > mq.TLO.Me.CurrentEndurance() then
        return false
    end
    if mq.TLO.Spell(name).Mana() > mq.TLO.Me.CurrentMana() then
        return false
    end
    if mq.TLO.Spell(name).TargetType() == 'Single' then
        if not mq.TLO.Target() then return false end
        local dist3d = mq.TLO.Target.Distance3D()
        if not dist3d or dist3d > mq.TLO.Spell(name).Range() then return false end
        if mq.TLO.Me.XTarget() == 0 then return false end
    end
    return true
end

---Determine whether an disc is ready, including checking whether the character is currently capable.
---@param name string @The name of the disc to be used.
---@return boolean @Returns true if the disc is ready to be used, otherwise false.
local function disc_ready(name)
    if mq.TLO.Me.CombatAbility(name)() and mq.TLO.Me.CombatAbilityTimer(name)() == '0' and mq.TLO.Me.CombatAbilityReady(name)() then
        return can_use_disc(name)
    else
        return false
    end
end

---Use the disc specified in the passed in table disc.
---@param disc table @A table containing the disc name and ID.
---@param overwrite boolean @The name of a disc which should be stopped in order to run this disc.
common.use_disc = function(disc, overwrite)
    if disc_ready(disc['name']) then
        if not is_disc(disc['name']) or not mq.TLO.Me.ActiveDisc.ID() then
            logger.printf('Use Disc: \ax\ar%s\ax', disc['name'])
            if disc['name']:find('Composite') then
                mq.cmdf('/disc %s', disc['id'])
            else
                mq.cmdf('/disc %s', disc['name'])
            end
            mq.delay(250+mq.TLO.Spell(disc['name']).CastTime())
            mq.delay(250, function() return not mq.TLO.Me.CombatAbilityReady(disc['name'])() end)
        elseif overwrite == mq.TLO.Me.ActiveDisc.Name() then
            mq.cmd('/stopdisc')
            mq.delay(50)
            logger.printf('Use Disc: \ax\ar%s\ax', disc['name'])
            mq.cmdf('/disc %s', disc['name'])
            mq.delay(250+mq.TLO.Spell(disc['name']).CastTime())
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
    if not state.get_burn_active_timer():timer_expired() and state.get_burn_active() then
        return true
    else
        state.set_burn_active(false)
    end
    if state.get_burn_now() then
        logger.printf('\arActivating Burns (on demand)\ax')
        state.get_burn_active_timer():reset()
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
            state.get_burn_active_timer():reset()
            state.set_burn_active(true)
            return true
        elseif mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.get_camp_radius()))() >= config.get_burn_count() then
            logger.printf('\arActivating Burns (mob count > %d)\ax', config.get_burn_count())
            state.get_burn_active_timer():reset()
            state.set_burn_active(true)
            return true
        elseif config.get_burn_percent() ~= 0 and mq.TLO.Target.PctHPs() < config.get_burn_percent() then
            logger.printf('\arActivating Burns (percent HP)\ax')
            state.get_burn_active_timer():reset()
            state.set_burn_active(true)
            return true
        end
    end
    state.get_burn_active_timer():reset(0)
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
    if not gem or common.am_i_dead() or mq.TLO.Me.Casting() or mq.TLO.Cursor() then return end
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
        local cursor = mq.TLO.Cursor.Name()
        if cursor and (cursor == 'Summoned: Dazzling Modulation Shard' or cursor == 'Sickle of Umbral Modulation' or cursor == 'Wand of Restless Modulation') then
            mq.cmd('/autoinventory')
            mq.delay(50)
        end
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

local sit_timer = timer:new(10)
---Sit down to med if the conditions for resting are met.
common.rest = function()
    -- try to avoid just constant stand/sit, mainly for dumb bard sitting between every song
    if sit_timer:timer_expired() then
        if not common.is_fighting() and not mq.TLO.Me.Sitting() and not mq.TLO.Me.Moving() and ((mq.TLO.Me.Class.CanCast() and mq.TLO.Me.PctMana() < 60) or mq.TLO.Me.PctEndurance() < 60) and not mq.TLO.Me.Casting() and not mq.TLO.Me.Combat() and not mq.TLO.Me.AutoFire() and mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.get_camp_radius()))() == 0 then
            mq.cmd('/sit')
            sit_timer:reset()
        end
    end
end

-- keep cursor clear for spell swaps and such
local autoinv_timer = timer:new(15)
---Autoinventory an item if it has been on the cursor for 15 seconds.
common.check_cursor = function()
    if mq.TLO.Cursor() then
        if autoinv_timer.start_time == 0 then
            autoinv_timer:reset()
            logger.printf('Dropping cursor item into inventory in 15 seconds')
        elseif autoinv_timer:timer_expired() then
            mq.cmd('/autoinventory')
            autoinv_timer:reset(0)
        end
    elseif autoinv_timer.start_time ~= 0 then
        logger.debug(state.get_debug(), 'Cursor is empty, resetting autoinv_timer')
        autoinv_timer:reset(0)
    end
end

---Event callback for handling spell resists from mobs
---@param line any
---@param target_name any
---@param spell_name any
local function event_resist(line, target_name, spell_name)

end

---Set common.I_AM_DEAD flag to true in the event of death.
local function event_dead()
    logger.printf('HP hit 0. what do!')
    state.set_i_am_dead(true)
    state.reset_combat_state()
    mq.cmd('/multiline ; /nav stop; /stick off;')
end

---Initialize the player death event triggers.
common.setup_events = function()
    mq.event('event_dead_released', '#*#Returning to Bind Location#*#', event_dead)
    mq.event('event_dead', 'You died.', event_dead)
    mq.event('event_dead_slain', 'You have been slain by#*#', event_dead)
    mq.event('event_resist', '#1# resisted your #2#!', event_resist)
end

return common