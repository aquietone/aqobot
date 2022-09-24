--- @type Mq
local mq = require 'mq'
local named = require('aqo.data.named')
local logger = require('aqo.utils.logger')
local timer = require('aqo.utils.timer')
local config = require('aqo.configuration')
local state = require('aqo.state')

local common = {}

common.ASSISTS = {group=1,raid1=1,raid2=1,raid3=1}
common.GROUP_WATCH_OPTS = {healer=1,self=1,none=1}
common.FD_CLASSES = {nec=true}--{mnk=true,bst=true,shd=true,nec=true}
common.PULL_STATES = {NOT=1,SCAN=2,APPROACHING=3,ENGAGING=4,RETURNING=5,WAITING=6}
common.BOOL = {
    TRUE={
        ['1']=1, ['true']=1,['on']=1,['TRUE']=1,['ON']=1,
    },
    FALSE={
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

local familiar = mq.TLO.Familiar and mq.TLO.Familiar.Stat.Item.ID() or mq.TLO.FindItem('Personal Hemic Source').ID()
-- Familiar: Personal Hemic Source
local illusion = mq.TLO.Illusion and mq.TLO.Illusion.Stat.Item.ID() or mq.TLO.FindItem('Jann\'s Veil').ID()
-- Illusion Benefit Greater Jann
local mount = mq.TLO.Mount and mq.TLO.Mount.Stat.Item.ID() or mq.TLO.FindItem('Golden Owlbear Saddle').ID()
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

common.is_named = function(zone_short_name, mob_name)
    return named[zone_short_name:lower()] and named[zone_short_name:lower()][mob_name]
end

-- MQ Helper Functions

---Lookup the ID for a given spell.
---@param spell_name string @The name of the spell.
---@return table|nil @Returns a table containing the spell name with rank, spell ID and the provided option name.
common.get_spell = function(spell_name)
    local spell_rank = mq.TLO.Spell(spell_name).RankName()
    if not mq.TLO.Me.Book(spell_rank)() then return nil end
    return {id=mq.TLO.Spell(spell_rank).ID(), name=spell_rank, type='spell'}
end

common.get_best_spell = function(spells)
    local spell = nil
    for _, spell_name in ipairs(spells) do
        spell = common.get_spell(spell_name)
        if spell then break end
    end
    return spell or {}
end

---Lookup the ID for a given AA.
---@param aa_name string @The name of the AA.
---@param option_name string|nil @The name of the option which controls whether this AA should be used.
---@return table|nil @Returns a table containing the AA name, AA ID and the provided option name.
common.get_aa = function(aa_name, option_name)
    if not mq.TLO.Me.AltAbility(aa_name)() then return nil end
    return {id=mq.TLO.Me.AltAbility(aa_name).ID(), name=aa_name, opt=option_name, type='aa'}
end

---Lookup the ID for a given disc.
---@param disc_name string @The name of the disc.
---@param option_name string|nil @The name of the option which controls whether this disc should be used.
---@return table|nil @Returns a table containing the disc name with rank, disc ID and the provided option name.
common.get_disc = function(disc_name, option_name)
    local disc_rank = mq.TLO.Spell(disc_name).RankName()
    if not disc_rank then return nil end
    return {id=mq.TLO.Spell(disc_rank).ID(), name=disc_rank, opt=option_name, type='disc'}
end

---Check whether the specified dot is applied to the target.
---@param spell_id number @The ID of the spell to check.
---@param spell_name string @The name of the spell to check.
---@return boolean @Returns true if the spell is applied to the target, false otherwise.
common.is_target_dotted_with = function(spell_id, spell_name)
    return mq.TLO.Target.MyBuff(spell_name)() ~= nil
    --if not mq.TLO.Target.MyBuff(spell_name)() then return false end
    --return spell_id == mq.TLO.Target.MyBuff(spell_name).ID()
end

---Determine whether currently fighting a target.
---@return boolean @True if standing with an NPC targeted, and not in a resting state, false otherwise.
common.is_fighting = function()
    --if mq.TLO.Target.CleanName() == 'Combat Dummy Beza' then return true end -- Dev hook for target dummy
    -- mq.TLO.Me.CombatState() ~= "ACTIVE" and mq.TLO.Me.CombatState() ~= "RESTING" and mq.TLO.Target.Type() ~= "Corpse" and not mq.TLO.Me.Feigning()
    return mq.TLO.Me.CombatState() == 'COMBAT'--mq.TLO.Target.ID() and mq.TLO.Me.CombatState() == 'COMBAT' and mq.TLO.Target.Type() == "NPC"-- and mq.TLO.Me.Standing()
end

---Determine if there are any hostile targets on XTarget.
---@return boolean @Returns true if at least 1 hostile auto hater spawn on XTarget, otherwise false.
common.hostile_xtargets = function()
    if mq.TLO.Me.XTarget() == 0 then return false end
    for i=1,20 do
        if mq.TLO.Me.XTarget(i).TargetType() == 'Auto Hater' and mq.TLO.Me.XTarget(i).Type() == 'NPC' then
            return true
        end
    end
    return false
end

common.clear_to_buff = function()
    return mq.TLO.Me.CombatState() ~= 'COMBAT' and not common.hostile_xtargets()
end

common.is_fighting_modebased = function()
    local mode = config.MODE
    if mode:is_tank_mode() then

    elseif mode:is_assist_mode() then

    elseif mode:get_name() == 'manual' then
        if mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then

        else

        end
    end
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
    if state.i_am_dead and (mq.TLO.Me.Buff('Resurrection Sickness').ID() or mq.TLO.SpawnCount('pccorpse '..mq.TLO.Me.CleanName())() == 0) then
        state.assist_mob_id = 0
        state.tank_mob_id = 0
        state.pull_mob_id = 0
        state.i_am_dead = false
    end
    return state.i_am_dead
end

---Determine whether currently in control of the character, i.e. not CC'd, stunned, mezzed, etc.
---@return boolean @Returns true if not under any loss of control effects, false otherwise.
common.in_control = function()
    return not (mq.TLO.Me.Dead() or mq.TLO.Me.Ducking() or mq.TLO.Me.Charmed() or
            mq.TLO.Me.Stunned() or mq.TLO.Me.Silenced() or mq.TLO.Me.Feigning() or
            mq.TLO.Me.Mezzed() or mq.TLO.Me.Invulnerable() or mq.TLO.Me.Hovering())
end

common.blocking_window_open = function()
    -- check blocking windows -- BigBankWnd, MerchantWnd, GiveWnd, TradeWnd
    return mq.TLO.Window('BigBankWnd').Open() or mq.TLO.Window('MerchantWnd').Open() or mq.TLO.Window('GiveWnd').Open() or mq.TLO.Window('TradeWnd').Open()
end

-- Movement Functions

---Chase after the assigned chase target if alive and in chase mode and the chase distance is exceeded.
common.check_chase = function()
    if config.MODE:get_name() ~= 'chase' then return end
    if common.am_i_dead() or mq.TLO.Stick.Active() or mq.TLO.Me.AutoFire() or (mq.TLO.Me.Class.ShortName() ~= 'BRD' and mq.TLO.Me.Casting()) then return end
    local chase_spawn = mq.TLO.Spawn('pc ='..config.CHASETARGET)
    local me_x = mq.TLO.Me.X()
    local me_y = mq.TLO.Me.Y()
    local chase_x = chase_spawn.X()
    local chase_y = chase_spawn.Y()
    if not chase_x or not chase_y then return end
    if common.check_distance(me_x, me_y, chase_x, chase_y) > config.CHASEDISTANCE then
        if not mq.TLO.Navigation.Active() and mq.TLO.Navigation.PathExists(string.format('spawn pc =%s', config.CHASETARGET))() then
            mq.cmdf('/nav spawn pc =%s | log=off', config.CHASETARGET)
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

common.is_dot_ready = function(spell)
    if not common.is_spell_ready(spell) then return false end

    local buff_duration = 0
    local remaining_cast_time = 0
    buff_duration = mq.TLO.Target.MyBuffDuration(spell.name)()
    if not common.is_target_dotted_with(spell.id, spell.name) then
        -- target does not have the dot, we are ready
        return true
    else
        if not buff_duration then
            return true
        end
        remaining_cast_time = mq.TLO.Spell(spell.name).MyCastTime()
        return buff_duration < remaining_cast_time + 3000
    end
end

common.is_spell_ready = function(spell)
    if not spell or not spell['name'] then return false end

    if not mq.TLO.Me.SpellReady(spell.name)() then return false end
    if mq.TLO.Spell(spell.name).Mana() > mq.TLO.Me.CurrentMana() or (mq.TLO.Spell(spell.name).Mana() > 1000 and mq.TLO.Me.PctMana() < state.min_mana) then
        return false
    end
    if mq.TLO.Spell(spell.name).EnduranceCost() > mq.TLO.Me.CurrentEndurance() or (mq.TLO.Spell(spell.name).EnduranceCost() > 1000 and mq.TLO.Me.PctEndurance() < state.min_end) then
        return false
    end
    if mq.TLO.Spell(spell.name).TargetType() == 'Single' then
        if not mq.TLO.Target() or mq.TLO.Target.Type() == 'Corpse' then return false end
    end

    return true
end

--- Stacking check stuff
common.should_use_spell = function(spell, skipselfstack)
    local result = false
    local dist = mq.TLO.Target.Distance3D()
    if spell.Beneficial() then
        -- duration is number of ticks, so it tostring'd
        if spell.Duration() ~= '0' then
            if spell.TargetType() == 'Self' then
                -- skipselfstack == true when its a disc, so that a defensive disc can still replace a always up sort of disc
                -- like war resolute stand should be able to replace primal defense
                result = ((skipselfstack or spell.Stacks()) and not mq.TLO.Me.Buff(spell.Name())() and not mq.TLO.Me.Song(spell.Name())()) == true
            elseif spell.TargetType() == 'Single' then
                result = (dist and dist <= spell.MyRange() and spell.StacksTarget() and not mq.TLO.Target.Buff(spell.Name())()) == true
            else
                -- no one to check stacking on, sure
                result = true
            end
        else
            if spell.TargetType() == 'Single' then
                result = (dist and dist <= spell.MyRange()) == true
            else
                -- instant beneficial spell, sure
                result = true
            end
        end
    else
        -- duration is number of ticks, so it tostring'd
        if spell.Duration() ~= '0' then
            if spell.TargetType() == 'Single' or spell.TargetType() == 'Targeted AE' then
                result = (dist and dist <= spell.MyRange() and mq.TLO.Target.LineOfSight() and spell.StacksTarget() and not mq.TLO.Target.MyBuff(spell.Name())()) == true
            else
                -- no one to check stacking on, sure
                result = true
            end
        else
            if spell.TargetType() == 'Single' or spell.TargetType() == 'LifeTap' then
                result = (dist and dist <= spell.MyRange() and mq.TLO.Target.LineOfSight()) == true
            else
                -- instant detrimental spell that requires no target, sure
                result = true
            end
        end
    end
    logger.debug(state.debug, 'Should use spell: \ay%s\ax=%s', spell.Name(), result)
    return result
end

--- Spell requirements, i.e. enough mana, enough reagents, have a target, target in range, not casting, in control
common.can_use_spell = function(spell, type)
    if not spell() then return false end
    local result = true
    if type == 'spell' and not mq.TLO.Me.SpellReady(spell.Name())() then result = false end
    if not common.in_control() or (mq.TLO.Me.Class.ShortName() ~= 'BRD' and (mq.TLO.Me.Casting() or mq.TLO.Me.Moving())) then result = false end
    if spell.Mana() > mq.TLO.Me.CurrentMana() or spell.EnduranceCost() > mq.TLO.Me.CurrentEndurance() then result = false end
    for i=1,3 do
        local reagentid = spell.ReagentID(i)()
        if reagentid ~= -1 then
            local reagent_count = spell.ReagentCount(i)()
            if mq.TLO.FindItemCount(reagentid)() < reagent_count then
                --logger.debug(state.get_debug(), 'Missing Reagent (%s)', reagentid)
                result = false
            end
        else
            break
        end
    end
    logger.debug(state.debug, 'Can use spell: \ay%s\ax=%s', spell.Name(), result)
    return result
end

---Cast the spell specified by spell_name.
---@param spell_name string @The name of the spell to be cast.
---@param requires_target boolean|nil @Indicate whether the spell requires a target.
common.cast = function(spell_name, requires_target)
    if type(spell_name) == 'table' then spell_name = spell_name.name end
    local spell = mq.TLO.Spell(spell_name)
    if not spell_name or not common.can_use_spell(spell, 'spell') or not common.should_use_spell(spell) then return false end
    local class = mq.TLO.Me.Class.ShortName()
    if class == 'BRD' then mq.cmd('/stopsong') end
    logger.printf('Casting \ar%s\ax', spell_name)
    mq.cmdf('/cast "%s"', spell_name)
    mq.delay(10)
    if not mq.TLO.Me.Casting() then mq.cmdf('/cast %s', spell_name) end
    mq.delay(10)
    if not mq.TLO.Me.Casting() then mq.cmdf('/cast %s', spell_name) end
    mq.delay(10)
    if class ~= 'BRD' then
        while mq.TLO.Me.Casting() do
            if requires_target and not mq.TLO.Target() then
                mq.cmd('/stopcast')
                break
            end
            mq.delay(10)
        end
    end
    return true
end

---Use the ability specified by name. These are basic abilities like taunt or kick.
---@param name string @The name of the ability to use.
common.use_ability = function(name)
    if type(name) == 'table' then name = name.name end
    if mq.TLO.Me.AbilityReady(name)() and mq.TLO.Me.Skill(name)() > 0 and mq.TLO.Target() then
        mq.cmdf('/doability %s', name)
        mq.delay(500, function() return not mq.TLO.Me.AbilityReady(name)() end)
    end
end

local function item_ready(item)
    if state.subscription ~= 'GOLD' and item.Prestige() then return false end
    if item() and item.Clicky.Spell() and item.Timer() == '0' then
        local spell = item.Clicky.Spell
        return common.can_use_spell(spell, 'item') and common.should_use_spell(spell)
    else
        return false
    end
end

---Use the item specified by item.
---@param item item @The MQ Item userdata object.
---@return boolean @Returns true if the item was fired, otherwise false.
common.use_item = function(item)
    if type(item) == 'table' then item = mq.TLO.FindItem(item.id) end
    if item_ready(item) then
        logger.printf('Use Item: \ax\ar%s\ax', item)
        mq.cmdf('/useitem "%s"', item)
        mq.delay(500+item.CastTime()) -- wait for cast time + some buffer so we don't skip over stuff
        return true
    end
    return false
end

---Determine whether an AA is ready, including checking whether the character is currently capable.
---@param name string @The name of the AA to be used.
---@return boolean @Returns true if the AA is ready to be used, otherwise false.
local function aa_ready(name)
    if mq.TLO.Me.AltAbilityReady(name)() then
        local spell = mq.TLO.Me.AltAbility(name).Spell
        return common.can_use_spell(spell, 'aa') and common.should_use_spell(spell)
    else
        return false
    end
end

---Use the AA specified in the passed in table aa.
---@param aa table|nil @A table containing the AA name and ID.
---@return boolean @Returns true if the ability was fired, otherwise false.
common.use_aa = function(aa)
    if aa and aa_ready(aa.name) then
        logger.printf('Use AA: \ax\ar%s\ax', aa.name)
        mq.cmdf('/alt activate %d', aa.id)
        mq.delay(250+mq.TLO.Me.AltAbility(aa.name).Spell.CastTime()) -- wait for cast time + some buffer so we don't skip over stuff
        mq.delay(250, function() return not mq.TLO.Me.AltAbilityReady(aa.name)() end)
        return true
    end
    return false
end

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

---Determine whether an disc is ready, including checking whether the character is currently capable.
---@param name string @The name of the disc to be used.
---@return boolean @Returns true if the disc is ready to be used, otherwise false.
local function disc_ready(name)
    if mq.TLO.Me.CombatAbility(name)() and mq.TLO.Me.CombatAbilityTimer(name)() == '0' and mq.TLO.Me.CombatAbilityReady(name)() then
        local spell = mq.TLO.Spell(name)
        return common.can_use_spell(spell, 'disc') and common.should_use_spell(spell, true)
    else
        return false
    end
end

---Use the disc specified in the passed in table disc.
---@param disc table|nil @A table containing the disc name and ID.
---@param overwrite string|nil @The name of a disc which should be stopped in order to run this disc.
common.use_disc = function(disc, overwrite)
    if disc and disc_ready(disc.name) then
        if not is_disc(disc.name) or not mq.TLO.Me.ActiveDisc.ID() then
            logger.printf('Use Disc: \ax\ar%s\ax', disc.name)
            if disc.name:find('Composite') then
                mq.cmdf('/disc %s', disc.id)
            else
                mq.cmdf('/disc %s', disc.name)
            end
            mq.delay(250+mq.TLO.Spell(disc.name).CastTime())
            mq.delay(250, function() return not mq.TLO.Me.CombatAbilityReady(disc.name)() end)
            return true
        elseif overwrite == mq.TLO.Me.ActiveDisc.Name() then
            mq.cmd('/stopdisc')
            mq.delay(50)
            logger.printf('Use Disc: \ax\ar%s\ax', disc.name)
            mq.cmdf('/disc %s', disc.name)
            mq.delay(250+mq.TLO.Spell(disc.name).CastTime())
            mq.delay(250, function() return not mq.TLO.Me.CombatAbilityReady(disc.name)() end)
            return true
        end
    end
    return false
end

common.use = {
    spell=common.cast,
    aa=common.use_ability,
    disc=common.use_disc,
    ability=common.use_ability,
    item=common.use_item,
}

-- Burn Helper Functions

---Determine whether the conditions are met to engage burn routines.
---@param always_condition function|nil @An extra function which can be provided to determine if the always burn condition should fire.
---@return boolean @Returns true if any burn condition is satisfied, otherwise false.
common.is_burn_condition_met = function(always_condition)
    -- activating a burn condition is good for 60 seconds, don't do check again if 60 seconds hasn't passed yet and burn is active.
    if not state.burn_active_timer:timer_expired() and state.burn_active then
        return true
    else
        state.burn_active = false
    end
    if state.burn_now then
        logger.printf('\arActivating Burns (on demand)\ax')
        state.burn_active_timer:reset()
        state.burn_active = true
        state.burn_now = false
        return true
    --elseif common.is_fighting() then
    elseif mq.TLO.Me.CombatState() == 'COMBAT' or common.hostile_xtargets() then
        local zone_sn = mq.TLO.Zone.ShortName():lower()
        if config.BURNALWAYS then
            if always_condition and not always_condition() then
                return false
            end
            return true
        elseif config.BURNALLNAMED and named[zone_sn] and named[zone_sn][mq.TLO.Target.CleanName()] then
            logger.printf('\arActivating Burns (named)\ax')
            state.burn_active_timer:reset()
            state.burn_active = true
            return true
        elseif mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.CAMPRADIUS))() >= config.BURNCOUNT then
            logger.printf('\arActivating Burns (mob count > %d)\ax', config.BURNCOUNT)
            state.burn_active_timer:reset()
            state.burn_active = true
            return true
        elseif config.BURNPCT ~= 0 and mq.TLO.Target.PctHPs() < config.BURNPCT then
            logger.printf('\arActivating Burns (percent HP)\ax')
            state.burn_active_timer:reset()
            state.burn_active = true
            return true
        end
    end
    state.burn_active_timer:reset(0)
    state.burn_active = false
    return false
end

-- Spell Helper Functions

---Determine whether the specified spell is memorized in the gem.
---@param spell_name string @The spell name to check is memorized.
---@param gem number @The spell gem index the spell should be memorized in.
---@return boolean|nil @Returns true if the spell is memorized in the specified gem, otherwise false.
common.swap_gem_ready = function(spell_name, gem)
    return mq.TLO.Me.Gem(gem)() and mq.TLO.Me.Gem(gem).Name() == spell_name
end

---Swap the specified spell into the specified gem slot.
---@param spell table|nil @The MQ Spell to memorize.
---@param gem number @The gem index to memorize the spell into.
---@param other_names table|nil @List of spell names to compare against, because of dissident,dichotomic,composite
common.swap_spell = function(spell, gem, other_names)
    if not spell or not gem or common.am_i_dead() or mq.TLO.Me.Casting() or mq.TLO.Cursor() then return end
    if mq.TLO.Me.Gem(gem)() == spell.name then return end
    if other_names and other_names[mq.TLO.Me.Gem(gem)()] then return end
    mq.cmdf('/memspell %d "%s"', gem, spell.name)
    mq.delay(3000, function() return common.swap_gem_ready(spell.name, gem) end)
    mq.TLO.Window('SpellBookWnd').DoClose()
end

common.swap_and_cast = function(spell, gem)
    if not spell then return false end
    local restore_gem = nil
    if not mq.TLO.Me.Gem(spell.name)() then
        restore_gem = {name=mq.TLO.Me.Gem(gem)()}
        common.swap_spell(spell, gem)
    end
    mq.delay(3500, function() return mq.TLO.Me.SpellReady(spell.name)() end)
    local did_cast = common.cast(spell.name)
    if restore_gem then
        common.swap_spell(restore_gem, gem)
    end
    return did_cast
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
    local group_mana = mq.TLO.Group.LowMana(70)
    local feather = mq.TLO.FindItem('=Unified Phoenix Feather') or mq.TLO.FindItem('=Miniature Horn of Unity')
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
        -- use feather for self if not grouped (group.LowMana is null if not grouped)
        if feather() and not group_mana and not mq.TLO.Me.Song(feather.Spell.Name())() then
            common.use_item(feather)
        end
    end
    -- use feather for group if > 2 members are below 70% mana
    if feather() and group_mana and group_mana > 2 and not mq.TLO.Me.Song(feather.Spell.Name())() then
        common.use_item(feather)
    end
end

local sit_timer = timer:new(10)
---Sit down to med if the conditions for resting are met.
common.rest = function()
    -- try to avoid just constant stand/sit, mainly for dumb bard sitting between every song
    if sit_timer:timer_expired() then
        if mq.TLO.Me.CombatState() ~= 'COMBAT' and not mq.TLO.Me.Sitting() and not mq.TLO.Me.Moving() and
                ((mq.TLO.Me.Class.CanCast() and mq.TLO.Me.PctMana() < 60) or mq.TLO.Me.PctEndurance() < 60) and
                not mq.TLO.Me.Casting() and not mq.TLO.Me.Combat() and not mq.TLO.Me.AutoFire() and
                mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.CAMPRADIUS))() == 0 then
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
        logger.debug(state.debug, 'Cursor is empty, resetting autoinv_timer')
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
    state.i_am_dead = true
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