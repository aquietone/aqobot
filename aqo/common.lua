--- @type Mq
local mq = require 'mq'
local named = require('data.named')
local movement = require('routines.movement')
local logger = require('utils.logger')
local timer = require('utils.timer')
local ability = require('ability')
local config = require('configuration')
local state = require('state')

local common = {}

common.ASSISTS = {group=1,raid1=1,raid2=1,raid3=1,manual=1}
common.GROUP_WATCH_OPTS = {healer=1,self=1,none=1}
common.TANK_CLASSES = {war=true,shd=true,pal=true}
common.MELEE_CLASSES = {ber=true,mnk=true,rog=true}
common.CASTER_CLASSES = {clr=true,dru=true,shm=true,enc=true,mag=true,nec=true,wiz=true}
common.PET_CLASSES = {nec=true,enc=true,mag=true,bst=true,shm=true,dru=true,shd=true}
common.BUFF_CLASSES = {clr=true,dru=true,shm=true,enc=true,mag=true,nec=true,rng=true,bst=true,pal=true}
common.HEALER_CLASSES = {clr=true,dru=true,shm=true}
common.FD_CLASSES = {mnk=true,bst=true,shd=true,nec=true}
common.PULL_STATES = {NOT=1,SCAN=2,APPROACHING=3,ENGAGING=4,WAIT_FOR_AGGRO=5,RETURNING=6,WAITING=7}
common.DMZ = {
    [344] = 1, -- Guild Lobby
    [345] = 1, -- Guild Hall
    [202] = 1, -- Plane of Knowledge
    [203] = 1, -- Plane of Tranquility
    [279] = 1, -- Abysmal Sea
    [151] = 1, -- Bazaar
    [220] = 1, -- Temple of Marr
    [33506] = 1, -- Small Guild Hall
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
---@param spellName string @The name of the spell.
---@return table|nil @Returns a table containing the spell name with rank, spell ID and the provided option name.
local function getSpell(spellName)
    local spell = mq.TLO.Spell(spellName)
    local rankname = spell.RankName()
    if not mq.TLO.Me.Book(rankname)() then return nil end
    if spell.Level() > mq.TLO.Me.Level() then return nil end
    if spell.HasSPA(32)() then
        local summonID = spell.Base(1)()
    end
    return {id=spell.ID(), name=rankname, targettype=spell.TargetType()}
end

common.getBestSpell = function(spells, options)
    for i,spellName in ipairs(spells) do
        local bestSpell = getSpell(spellName)
        if bestSpell then
            if options and type(options.summons) == 'table' then
                options.summons = options.summons[i]
            end
            local spell = ability.Spell:new(bestSpell.id, bestSpell.name, bestSpell.targettype, options)
            return spell
        end
    end
    return nil
end

---Lookup the ID for a given AA.
---@param aaName string @The name of the AA.
---@param options table|nil @A table of options relating to the AA, such as the setting name controlling use of the AA
---@return table|nil @Returns a table containing the AA name, AA ID and the provided option name.
common.getAA = function(aaName, options)
    local aaData = mq.TLO.Me.AltAbility(aaName)
    if aaData() then
        if not options then options = {} end
        if not options.checkfor then
            if aaData.Spell.HasSPA(470)() then
                options.checkfor = aaData.Spell.Trigger(1)()
            else
                options.checkfor = aaData.Spell()
            end
        end
        if not options.summons then
            if aaData.Spell.HasSPA(32)() then
                options.summons = aaData.Spell.Base(1)()
                options.summonMinimum = 1
            end
        end
        local aa = ability.AA:new(aaData.ID(), aaData.Name(), aaData.Spell.TargetType(), options)
        return aa
    end
    return nil
end

local function getDisc(discName)
    local disc = mq.TLO.Spell(discName)
    local rankName = disc.RankName()
    if not rankName or not mq.TLO.Me.CombatAbility(rankName)() then return nil end
    if disc.Level() > mq.TLO.Me.Level() then return nil end
    return {name=rankName, id=disc.ID()}
end

---Lookup the ID for a given disc.
---@param discs table @An ordered list of discs from best to worst
---@param options table|nil @A table of options relating to the disc, such as the setting name controlling use of the disc
---@return table|nil @Returns a table containing the disc name with rank, disc ID and the provided option name.
common.getBestDisc = function(discs, options)
    for _,discName in ipairs(discs) do
        local bestDisc = getDisc(discName)
        if bestDisc then
            printf(logger.logLine('Found Disc: %s (%s)', bestDisc.name, bestDisc.id))
            local disc = ability.Disc:new(bestDisc.id, bestDisc.name, options)
            return disc
        end
    end
    printf(logger.logLine('[%s] Could not find disc!', discs[1]))
    return nil
end

common.getItem = function(itemName, options)
    if not itemName then return nil end
    local itemRef = mq.TLO.FindItem('='..itemName)
    if itemRef() and itemRef.Clicky() then
        if not options then options = {} end
        options.checkfor = itemRef.Clicky.Spell()
        if itemRef.Clicky.Spell.HasSPA(374)() then
            for i=1,5 do
                if itemRef.Clicky.Spell.Attrib(i)() == 374 then
                    -- mount blessing buff
                    if not itemRef.Clicky.Spell.Trigger(i).Name():find('Illusion') then
                        options.checkfor = itemRef.Clicky.Spell.Trigger(i).Name()
                        options.removesong = itemRef.Clicky.Spell()
                    else
                        options.removesong = itemRef.Clicky.Spell.Trigger(i).Name()
                    end
                elseif itemRef.Clicky.Spell.Attrib(i)() == 113 then
                    -- summon mount SPA
                end
            end
        end
        local item = ability.Item:new(itemRef.ID(), itemRef.Name(), itemRef.Clicky.Spell.TargetType(), options)
        return item
    end
    return nil
end

common.getSkill = function(name, options)
    if not mq.TLO.Me.Ability(name) or not mq.TLO.Me.Skill(name)() or mq.TLO.Me.Skill(name)() == 0 then return nil end
    local skill = ability.Skill:new(name, options)
    return skill
end

common.set_swap_gem = function()
    if not mq.TLO.Me.Class.CanCast() then return end
    state.swapGem = mq.TLO.Me.NumGems()
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
        if mq.TLO.Group.MainTank.ID() == state.loop.ID then

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
    return mq.TLO.Window('BigBankWnd').Open() or mq.TLO.Window('MerchantWnd').Open() or mq.TLO.Window('GiveWnd').Open() or mq.TLO.Window('TradeWnd').Open() or mq.TLO.Window('LootWnd').Open()
end

-- Movement Functions

---Chase after the assigned chase target if alive and in chase mode and the chase distance is exceeded.
common.check_chase = function()
    if config.MODE:get_name() ~= 'chase' then return end
    if mq.TLO.Stick.Active() or mq.TLO.Me.AutoFire() or (state.class ~= 'brd' and mq.TLO.Me.Casting()) then return end
    local chase_spawn = mq.TLO.Spawn('pc ='..config.CHASETARGET)
    local me_x = mq.TLO.Me.X()
    local me_y = mq.TLO.Me.Y()
    local chase_x = chase_spawn.X()
    local chase_y = chase_spawn.Y()
    if not chase_x or not chase_y then return end
    if common.check_distance(me_x, me_y, chase_x, chase_y) > config.CHASEDISTANCE then
        if mq.TLO.Me.Sitting() then mq.cmd('/stand') end
        movement.navToSpawn('pc ='..config.CHASETARGET)
        --[[
        local chaseSpawn = mq.TLO.Spawn('pc '..config.CHASETARGET)
        if chaseSpawn.LineOfSight() then
            mq.cmdf('/moveto id %s', chaseSpawn.ID())
        end
        ]]
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

common.is_spell_ready = function(spell, skipCheckTarget)
    if not spell then return false end

    if not mq.TLO.Me.SpellReady(spell.name)() then return false end
    local spellData = mq.TLO.Spell(spell.name)
    if spellData.Mana() > mq.TLO.Me.CurrentMana() or (spellData.Mana() > 1000 and state.loop.PctMana < state.min_mana) then
        return false
    end
    if spellData.EnduranceCost() > mq.TLO.Me.CurrentEndurance() or (spellData.EnduranceCost() > 1000 and state.loop.PctEndurance < state.min_end) then
        return false
    end
    if not skipCheckTarget and spellData.TargetType() == 'Single' then
        if not mq.TLO.Target() or mq.TLO.Target.Type() == 'Corpse' then return false end
    end

    if spellData.Duration.Ticks() > 0 then
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
            remaining_cast_time = spellData.MyCastTime()
            return buff_duration < remaining_cast_time + 3000
        end
    else
        return true
    end
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
    logger.debug(logger.log_flags.common.cast, 'Should use spell: \ag%s\ax=%s', spell.Name(), result)
    return result
end

--- Spell requirements, i.e. enough mana, enough reagents, have a target, target in range, not casting, in control
common.can_use_spell = function(spell, type)
    if not spell() then return false end
    local result = true
    if type == 'spell' and not mq.TLO.Me.SpellReady(spell.Name())() then result = false end
    if state.class ~= 'brd' and (mq.TLO.Me.Casting() or mq.TLO.Me.Moving()) then result = false end
    if spell.Mana() > mq.TLO.Me.CurrentMana() or spell.EnduranceCost() > mq.TLO.Me.CurrentEndurance() then result = false end
    -- emu hack for bard for the time being, songs requiring an instrument are triggering reagent logic?
    if state.class ~= 'brd' then
        for i=1,3 do
            local reagentid = spell.ReagentID(i)()
            if reagentid ~= -1 then
                local reagent_count = spell.ReagentCount(i)()
                if mq.TLO.FindItemCount(reagentid)() < reagent_count then
                    logger.debug(logger.log_flags.common.cast, 'Missing Reagent (%s)', reagentid)
                    result = false
                end
            else
                break
            end
        end
    end
    logger.debug(logger.log_flags.common.cast, 'Can use spell: \ag%s\ax=%s', spell.Name(), result)
    return result
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
---@param item MQItem @The MQ Item userdata object.
---@return boolean @Returns true if the item was fired, otherwise false.
common.use_item = function(item)
    if type(item) == 'table' then item = mq.TLO.FindItem(item.id) end
    if item_ready(item) then
        state.casting = common.getItem(item.Name())
        printf(logger.logLine('Use Item: \ag%s\ax', item))
        if state.class == 'brd' and mq.TLO.Me.Casting() then mq.cmd('/stopsong') mq.delay(1) end
        mq.cmdf('/useitem "%s"', item)
        state.actionTaken = true
        return true
        --mq.delay(500+item.CastTime()) -- wait for cast time + some buffer so we don't skip over stuff
        --return true
    end
    return false
end

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
        printf(logger.logLine('\arActivating Burns (on demand%s)\ax', state.burn_type and ' - '..state.burn_type or ''))
        state.burn_active_timer:reset()
        state.burn_active = true
        state.burn_now = false
        return true
    elseif mq.TLO.Me.CombatState() == 'COMBAT' or common.hostile_xtargets() then
        local zone_sn = mq.TLO.Zone.ShortName():lower()
        if config.BURNALWAYS then
            if always_condition and not always_condition() then
                return false
            end
            state.burn_type = nil
            return true
        elseif config.BURNALLNAMED and named[zone_sn] and named[zone_sn][mq.TLO.Target.CleanName()] then
            printf(logger.logLine('\arActivating Burns (named)\ax'))
            state.burn_active_timer:reset()
            state.burn_active = true
            state.burn_type = nil
            return true
        elseif mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.CAMPRADIUS))() >= config.BURNCOUNT then
            printf(logger.logLine('\arActivating Burns (mob count > %d)\ax', config.BURNCOUNT))
            state.burn_active_timer:reset()
            state.burn_active = true
            state.burn_type = nil
            return true
        elseif config.BURNPCT ~= 0 and mq.TLO.Target.PctHPs() < config.BURNPCT then
            printf(logger.logLine('\arActivating Burns (percent HP)\ax'))
            state.burn_active_timer:reset()
            state.burn_active = true
            state.burn_type = nil
            return true
        end
    end
    state.burn_active_timer:reset(0)
    state.burn_active = false
    state.burn_type = nil
    return false
end

-- Spell Helper Functions

---Determine whether the specified spell is memorized in the gem.
---@param spell_name string @The spell name to check is memorized.
---@param gem number @The spell gem index the spell should be memorized in.
---@return boolean|nil @Returns true if the spell is memorized in the specified gem, otherwise false.
common.swap_gem_ready = function(spell_name, gem)
    return mq.TLO.Me.Gem(gem).Name() == spell_name
end

---Swap the specified spell into the specified gem slot.
---@param spell table @The MQ Spell to memorize.
---@param gem number @The gem index to memorize the spell into.
---@param other_names table|nil @List of spell names to compare against, because of dissident,dichotomic,composite
common.swap_spell = function(spell, gem, other_names)
    if not spell or not gem or mq.TLO.Me.Casting() or mq.TLO.Cursor() then return end
    if mq.TLO.Me.Gem(gem)() == spell.name then return end
    if other_names and other_names[mq.TLO.Me.Gem(gem)()] then return end
    mq.cmdf('/memspell %d "%s"', gem, spell.name)
    state.actionTaken = true
    state.memSpell = spell
    state.memSpellTimer:reset()
    return true
end

common.swap_and_cast = function(spell, gem)
    if not spell then return false end
    if not mq.TLO.Me.Gem(spell.name)() then
        state.restore_gem = {name=mq.TLO.Me.Gem(gem)(),gem=gem}
        if not common.swap_spell(spell, gem) then
            -- failed to mem?
            return
        end
        state.queuedAction = function()
            spell:use()
            if state.restore_gem then
                return function()
                    common.swap_spell(state.restore_gem, gem)
                end
            end
        end
        return true
    end
end

---Check Geomantra buff and click charm item if missing and item is ready.
common.check_combat_buffs = function()
    if state.emu then return end
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

local modrods = {['Summoned: Dazzling Modulation Shard']=true,['Sickle of Umbral Modulation']=true,['Wand of Restless Modulation']=true,
                ['Summoned: Large Modulation Shard']=true, ['Summoned: Medium Modulation Shard']=true, ['Summoned: Small Modulation Shard']=true, ['Azure Mind Crystal']=true}
---Attempt to click mod rods if mana is below 75%.
common.check_mana = function()
    -- modrods
    local pct_mana = state.loop.PctMana
    local pct_end = state.loop.PctEndurance
    local group_mana = mq.TLO.Group.LowMana(70)()
    local feather = mq.TLO.FindItem('=Unified Phoenix Feather') or mq.TLO.FindItem('=Miniature Horn of Unity')
    if pct_mana < 75 then
        local cursor = mq.TLO.Cursor.Name()
        if cursor and modrods[cursor] then
            mq.cmd('/autoinv')
            return
        end
        -- Find ModRods in check_mana since they poof when out of charges, can't just find once at startup.
        for item,_ in pairs(modrods) do
            local modrod = mq.TLO.FindItem(item)
            if mq.TLO.Me.PctHPs() > 70 then
                common.use_item(modrod)
            end
        end
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
                ((mq.TLO.Me.Class.CanCast() and state.loop.PctMana < 60) or state.loop.PctEndurance < 60) and
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
            printf(logger.logLine('Dropping cursor item into inventory in 15 seconds'))
        elseif autoinv_timer:timer_expired() then
            mq.cmd('/autoinventory')
            autoinv_timer:reset(0)
        end
    elseif autoinv_timer.start_time ~= 0 then
        logger.debug(logger.log_flags.common.misc, 'Cursor is empty, resetting autoinv_timer')
        autoinv_timer:reset(0)
    end
end

common.toggleTribute = function()
    logger.debug(logger.log_flags.common.misc, 'Toggle tribute')
    mq.cmd('/keypress TOGGLE_TRIBUTEBENEFITWIN')
    mq.cmd('/notify TBW_PersonalPage TBWP_ActivateButton leftmouseup')
    mq.cmd('/keypress TOGGLE_TRIBUTEBENEFITWIN')
end

---Event callback for handling spell resists from mobs
---@param line any
---@param target_name any
---@param spell_name any
local function event_resist(line, target_name, spell_name)

end

---Set common.I_AM_DEAD flag to true in the event of death.
local function event_dead()
    printf(logger.logLine('HP hit 0. what do!'))
    state.i_am_dead = true
    state.reset_combat_state()
    movement.stop()
end

---Initialize the player death event triggers.
common.setup_events = function()
    mq.event('event_dead_released', '#*#Returning to Bind Location#*#', event_dead)
    mq.event('event_dead', 'You died.', event_dead)
    mq.event('event_dead_slain', 'You have been slain by#*#', event_dead)
    mq.event('event_resist', '#1# resisted your #2#!', event_resist)
end

return common