---@type Mq
local mq = require 'mq'
local assist = require('routines.assist')
local buffing = require('routines.buff')
local camp = require('routines.camp')
local healing = require('routines.heal')
local mez = require('routines.mez')
local movement = require('routines.movement')
local pull = require('routines.pull')
local tank = require('routines.tank')
local logger = require('utils.logger')
local persistence = require('utils.persistence')
local timer = require('utils.timer')
local Abilities = require('ability')
local common = require('common')
local config = require('configuration')
local state = require('state')
local base = {}
pull.set_class_funcs(base)

-- All possible class routine methods
base.ROUTINES = {heal=1,assist=1,mash=1,burn=1,cast=1,cure=1,buff=1,rest=1,ae=1,mez=1,aggro=1,ohshit=1,rez=1,recover=1,managepet=1}

-- collection of options for the class which appear in the Skills tab
base.OPTS = {}

-- collection of all spell id/name pairs that may be used for the class
base.spells = {}
-- collection of ordered spell rotations which may be loaded for the class and used in base.cast
base.spellRotations = {}
-- collection of Spell/AA/Disc/Ability/Item used in base.mash in any modes
-- Options: opt=string, delay=number
base.DPSAbilities = {}
-- collection of Spell/AA/Disc/Ability/Item used in base.mash in tank modes
-- Options: opt=string, delay=number
base.tankAbilities = {}
-- collection of Spell/AA/Disc/Ability/Item used in base.burn in any modes
-- Options: opt=string, delay=number
base.burnAbilities = {}
-- collection of Spell/AA/Disc/Ability/Item used in base.burn in tank modes
-- Options: opt=string, delay=number
base.tankBurnAbilities = {}
-- collection of Spell/AA/Disc/Ability/Item used in base.heal
-- Options: me=number, mt=number, other=number
base.healAbilities = {}
-- collection of Spell/AA/Disc/Ability/Item used in base.ae in any mode
-- Options: opt=string, delay=number, threshold=number
base.AEDPSAbilities = {}
-- collection of Spell/AA/Disc/Ability/Item used in base.ae in tank modes
-- Options: opt=string, delay=number, threshold=number
base.AETankAbilities = {}
-- collection of Spell/AA/Disc/Ability/Item used in base.aggro in non-tank modes
-- Options: opt=string, delay=number, threshold=number
base.defensiveAbilities = {}
-- collection of Spell/AA/Disc/Ability/Item used in base.recover
-- Options: mana=boolean, endurance=boolean, combat=boolean, ooc=boolean, threshold=number, minhp=number
base.recoverAbilities = {}

-- collection of Spell/AA/Disc/Ability/Item used in base.
-- Options: target=self|group|classlist
base.combatBuffs = {}
base.auras = {}
base.selfBuffs = {}
base.groupBuffs = {}
base.singleBuffs = {}
base.tankBuffs = {}
base.petBuffs = {}
base.cures = {}
base.requests = {}
base.requestAliases = {}

base.clickies = {}
base.castClickies = {}

base.pullClickies = {}

--base.slow
--base.aeslow
--base.snare
--base.debuff
--base.dispel
--base.nuketimer
--base.drop_aggro
--base.pet
--

-- Options added by key/value as well as by index/key so that settings can be displayed
-- in the skills tab in the order in which they are defined.
--- @param key string # The configuration key
--- @param label string # The text label that appears in the UI
--- @param value string|boolean|number # The default value for the setting
--- @param options table|nil # List of available options for combobox settings
--- @param tip string|nil # Hover  help message for the setting
--- @param type string # The UI element type (combobox, checkbox, inputint)
--- @param exclusive string|nil # The key of another option which is mutually exclusive with this option
base.addOption = function(key, label, value, options, tip, type, exclusive)
    base.OPTS[key] = {
        label=label,
        value=value,
        options=options,
        tip=tip,
        type=type,
        exclusive=exclusive,
    }
    table.insert(base.OPTS, key)
end

local casterpriests = {clr=true,shm=true,dru=true,mag=true,nec=true,enc=true,wiz=true}
local petclasses = {nec=true,enc=true,mag=true,bst=true,shm=true,dru=true,shd=true}
local buffclasses = {clr=true,dru=true,enc=true,shm=true,mag=true,rng=true,bst=true,nec=true}
local healers = {clr=true,dru=true,shm=true}
base.addCommonOptions = function()
    if base.SPELLSETS then
        base.addOption('SPELLSET', 'Spell Set', base.DEFAULT_SPELLSET or 'standard' , base.SPELLSETS, 'The spell set to be used', 'combobox')
        base.addOption('BYOS', 'BYOS', true, nil, 'Bring your own spells', 'checkbox')
    end
    base.addOption('USEAOE', 'Use AOE', true, nil, 'Toggle use of AOE abilities', 'checkbox')
    base.addOption('USEALLIANCE', 'Use Alliance', true, nil, 'Use alliance spell', 'checkbox')
    if casterpriests[base.class] then
        base.addOption('USEMELEE', 'Use Melee', false, nil, 'Toggle attacking mobs with melee', 'checkbox')
    end
    if petclasses[base.class] then
        base.addOption('SUMMONPET', 'Summon Pet', true, nil, 'Summon a pet', 'checkbox')
        base.addOption('BUFFPET', 'Buff Pet', true, nil, 'Use pet buffs', 'checkbox')
        base.addOption('HEALPET', 'Heal Pets', true, nil, 'Toggle healing of pets', 'checkbox')
    end
    if base.class == 'clr' then
        base.addOption('HEALPET', 'Heal Pets', true, nil, 'Toggle healing of pets', 'checkbox')
    end
    base.addOption('USEGLYPH', 'Use DPS Glyph', false, nil, 'Use glyph of destruction during burns', 'checkbox')
    base.addOption('USEINTENSITY', 'Use Intensity', false, nil, 'Use intensity of the resolute during burns', 'checkbox')
    if buffclasses[base.class] then
        base.addOption('SERVEBUFFREQUESTS', 'Serve Buff Requests', true, nil, 'Toggle serving buff requests', 'checkbox')
    end
    if healers[base.class] then
        base.addOption('USEHOTTANK', 'Use HoT (Tank)', false, nil, 'Toggle use of heal over time on tank', 'checkbox')
        base.addOption('USEHOTDPS', 'Use HoT (All)', false, nil, 'Toggle use of heal over time on everyone', 'checkbox')
        base.addOption('XTARGETHEAL', 'Heal XTarget', false, nil, 'Toggle healing of PCs on XTarget', 'checkbox')
        base.addOption('XTARGETBUFF', 'Buff XTarget', false, nil, 'Toggle buffing of PCs on XTarget', 'checkbox')
    end
end

base.addCommonAbilities = function()
    base.tranquil = common.getAA('Tranquil Blessings')
    base.radiant = common.getAA('Radiant Cure', {all=true})
    base.silent = common.getAA('Silent Casting')
    base.mgb = common.getAA('Mass Group Buff')
end

-- Return true only if the option is both defined and true
-- For cases where something should only be done by a class who has the option
-- Ex. USEMEZ logic should only ever be entered for classes who can mez.
base.isEnabled = function(key)
    return base.OPTS[key] and base.OPTS[key].value
end

-- Return true if the option is nil or the option is true
-- Ex. Kick has no option to toggle it, so should always be true. Intimidate has a toggle
-- so should evaluate the option.
base.isAbilityEnabled = function(key)
    return not key or not base.OPTS[key] or base.OPTS[key].value
end

base.addSpell = function(spellGroup, spellList, options)
    local foundSpell = common.getBestSpell(spellList, options)
    base.spells[spellGroup] = foundSpell
    if foundSpell then
        print(logger.logLine('[%s] Found spell: %s (%s)', spellGroup, foundSpell.name, foundSpell.id))
    else
        print(logger.logLine('[%s] Could not find spell!', spellGroup))
    end
end

base.addClicky = function(clicky)
    local item = mq.TLO.FindItem('='..clicky.name)
    if item.Clicky() then
        if clicky.clickyType == 'burn' then
            table.insert(base.burnAbilities, common.getItem(clicky.name))
        elseif clicky.clickyType == 'mash' then
            table.insert(base.DPSAbilities, common.getItem(clicky.name))
        elseif clicky.clickyType == 'cast' then
            table.insert(base.castClickies, common.getItem(clicky.name))
        elseif clicky.clickyType == 'heal' then
            table.insert(base.healAbilities, common.getItem(clicky.name))
        elseif clicky.clickyType == 'mana' then
        elseif clicky.clickyType == 'dispel' then
        elseif clicky.clickyType == 'cure' then
        elseif clicky.clickyType == 'buff' then
            table.insert(base.selfBuffs, common.getItem(clicky.name, {checkfor=item.Clicky.Spell()}))
        elseif clicky.clickyType == 'pull' then
            table.insert(base.pullClickies, common.getItem(clicky.name))
        end
        table.insert(base.clickies, clicky)
        print(logger.logLine('Added \ay%s\ax clicky: \ag%s\ax', clicky.clickyType, clicky.name))
    end
end

base.removeClicky = function(itemName)
    for i,clicky in ipairs(base.clickies) do
        if clicky.name == itemName then
            table.remove(base.clickies, i)
            local t
            if clicky.clickyType == 'burn' then
                t = base.burnAbilities
            elseif clicky.clickyType == 'mash' then
                t = base.DPSAbilities
            elseif clicky.clickyType == 'cast' then
                t = base.castClickies
            elseif clicky.clickyType == 'mana' then
            elseif clicky.clickyType == 'dispel' then
            elseif clicky.clickyType == 'cure' then
            elseif clicky.clickyType == 'heal' then
                t = base.healAbilities
            elseif clicky.clickyType == 'buff' then
                t = base.selfBuffs
            elseif clicky.clickyType == 'pull' then
                t = base.pullClickies
            end
            for j,entry in ipairs(t) do
                if entry.name == itemName then
                    table.remove(t, j)
                    print(logger.logLine('Removed \ay%s\ax clicky: \ag%s\ax', clicky.clickyType, clicky.name))
                    return
                end
            end
        end
    end
end

base.addRequestAlias = function(ability, alias)
    base.requestAliases[alias] = ability
end

base.getAbilityForAlias = function(alias)
    return base.requestAliases[alias]
end

local SETTINGS_FILE = ('%s/aqobot_%s_%s.lua'):format(mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me.CleanName())
base.load_settings = function()
    local settings = config.load_settings(SETTINGS_FILE)
    if not settings or not settings[base.class] then return end
    for setting,value in pairs(settings[base.class]) do
        if base.OPTS[setting] == nil then
            print(logger.logLine('Unrecognized setting: %s=%s', setting, value))
        else
            base.OPTS[setting].value = value
        end
    end
    if settings.clickies then
        for _,clicky in ipairs(settings.clickies) do
            base.addClicky(clicky)
        end
    end
end

base.save_settings = function()
    local optValues = {}
    for name,options in pairs(base.OPTS) do optValues[name] = options.value end
    persistence.store(SETTINGS_FILE, {common=config.get_all(), [base.class]=optValues, clickies=base.clickies})
end

-- attempt to avoid trying to slow mobs that are slow immune. currently this table is never cleaned up unless restarted
base.SLOW_IMMUNES = {}
base.event_slowimmune = function(line)
    local target_name = mq.TLO.Target.CleanName()
    if target_name and not base.SLOW_IMMUNES[target_name] then
        base.SLOW_IMMUNES[target_name] = 1
    end
end

-- attempt to avoid trying to snare mobs that are snare immune. currently this table is never cleaned up unless restarted
base.SNARE_IMMUNES = {}
base.event_snareimmune = function()
    local target_name = mq.TLO.Target.CleanName()
    if target_name and not base.SNARE_IMMUNES[target_name] then
        base.SNARE_IMMUNES[target_name] = 1
    end
end

local function validateRequester(requester)
    return mq.TLO.Group.Member(requester)() or mq.TLO.Raid.Member(requester)() or mq.TLO.Spawn('='..requester).Guild() == mq.TLO.Me.Guild()
end

base.event_gear = function(line, requester, requested)
    requested = requested:lower()
    local slot = requested:gsub('gear ', '')
    if slot == 'listslots' then
        mq.cmd('/gu earrings, rings, leftear, rightear, leftfinger, rightfinger, face, head, neck, shoulder, chest, feet, arms, leftwrist, rightwrist, wrists, charm, powersource, mainhand, offhand, ranged, ammo, legs, waist, hands')
    elseif slot == 'earrings' then
        local leftear = mq.TLO.Me.Inventory('leftear')
        local rightear = mq.TLO.Me.Inventory('rightear')
        mq.cmdf('/gu leftear: %s, rightear: %s', leftear.ItemLink('CLICKABLE')(), rightear.ItemLink('CLICKABLE')())
    elseif slot == 'rings' then
        local leftfinger = mq.TLO.Me.Inventory('leftfinger')
        local rightfinger = mq.TLO.Me.Inventory('rightfinger')
        mq.cmdf('/gu leftfinger: %s, rightfinger: %s', leftfinger.ItemLink('CLICKABLE')(), rightfinger.ItemLink('CLICKABLE')())
    elseif slot == 'wrists' then
        local leftwrist = mq.TLO.Me.Inventory('leftwrist')
        local rightwrist = mq.TLO.Me.Inventory('rightwrist')
        mq.cmdf('/gu leftwrist: %s, rightwrist: %s', leftwrist.ItemLink('CLICKABLE')(), rightwrist.ItemLink('CLICKABLE')())
    else
        if mq.TLO.Me.Inventory(slot)() then
            mq.cmdf('/gu %s: %s', slot, mq.TLO.Me.Inventory(slot).ItemLink('CLICKABLE')())
        end
    end
end

base.event_request = function(line, requester, requested)
    requested = requested:lower()
    if requested:find('^gear .+') then
        return base.event_gear(line, requester, requested)
    end
    if base.isEnabled('SERVEBUFFREQUESTS') and validateRequester(requester) then
        local tranquil = false
        local mgb = false
        if requested:find('^tranquil') then
            requested = requested:gsub('tranquil','')
            tranquil = true
        end
        if requested:find('^mgb') then
            requested = requested:gsub('mgb','')
            mgb = true
        end
        if requested:find(' '..mq.TLO.Me.CleanName():lower()..'$') then
            requested = requested:gsub(' '..mq.TLO.Me.CleanName():lower(),'')
        end
        if requested:find(' pet$') then
            requested = requested:gsub(' pet', '')
            requester = mq.TLO.Spawn('pc '..requester).Pet.CleanName()
            print('Pet Name for request: ', requester)
        end
        if requested == 'list buffs' then
            local buffList = ''
            for alias,ability in pairs(base.requestAliases) do
                buffList = ('%s | %s : %s'):format(buffList, alias, ability.name)
            end
            mq.cmdf('/t %s %s', requester, buffList)
            return
        end
        local requestedAbility = base.getAbilityForAlias(requested)
        if requestedAbility then
            local expiration = timer:new(15)
            expiration:reset()
            table.insert(base.requests, {requester=requester, requested=requestedAbility, expiration=expiration, tranquil=tranquil, mgb=mgb})
        end
    end
end

base.event_tranquil = function()
    if mq.TLO.Me.CombatState() ~= 'COMBAT' and mq.TLO.Raid.Members() > 0 then
        mq.delay(5000, function() return not mq.TLO.Me.Casting() end)
        if base.tranquil:use() then mq.cmd('/rs Tranquil Blessings used') end
    end
end

base.setup_events = function()
    -- setup events based on whether certain options are defined, not whether they are enabled.
    if base.OPTS.USESLOW or base.OPTS.USESLOWAOE then
        mq.event('event_slowimmune', 'Your target is immune to changes in its attack speed#*#', base.event_slowimmune)
    end
    if base.OPTS.MEZST or base.OPTS.MEZAE then
        mez.setup_events()
    end
    if base.OPTS.USESNARE then
        mq.event('event_runspeedimmune', 'Your target is immune to changes in its run speed#*#', base.event_snareimmune)
        mq.event('event_snareimmune', 'Your target is immune to snare spells#*#', base.event_snareimmune)
    end
    if base.tranquil then
        mq.event('event_tranquil', '#*# tells the #*#, \'tranquil\'', base.event_tranquil)
    end
    if base.OPTS.SERVEBUFFREQUESTS then
        mq.event('event_requests', '#1# tells #*#, \'#2#\'', base.event_request)
    else
        mq.event('event_gearrequest', '#1# tells #*#, \'gear #2#\'', base.event_gear)
    end
end

base.assist = function()
    if common.DMZ[mq.TLO.Zone.ID()] or mq.TLO.Navigation.Active() then return end
    if healers[base.class] and config.ASSIST == 'manual' then return end
    if config.MODE:is_assist_mode() then
        assist.check_target(base.reset_class_timers)
        logger.debug(logger.log_flags.class.assist, "after check target "..tostring(state.assist_mob_id))
        if base.isAbilityEnabled('USEMELEE') then
            if state.assist_mob_id and not mq.TLO.Me.Combat() and base.beforeEngage then
                base.beforeEngage()
            end
            assist.attack()
        else
            assist.check_los()
        end
        assist.send_pet()
    end
end

base.tank = function()
    if common.DMZ[mq.TLO.Zone.ID()] then return end
    tank.find_mob_to_tank()
    tank.tank_mob()
    assist.send_pet()
end

base.heal = function()
    if healers[base.class] then
        healing.heal(base.healAbilities, base.OPTS)
    elseif petclasses[base.class] then
        healing.healPetOrSelf(base.healAbilities, base.OPTS)
    else
        healing.healSelf(base.healAbilities, base.OPTS)
    end
end

base.cure = function()
    if mq.TLO.Me.SPA(15)() < 0 then
        if mq.TLO.Me.CountersCurse() > 0 then
            for _,cure in base.cures do
                if cure.curse or cure.all and cure:isReady() then
                    if mq.TLO.Target.ID() ~= state.loop.ID then
                        mq.cmd('/mqtar')
                        mq.delay(100, function() return mq.TLO.Target.ID() == state.loop.ID end)
                    end
                    cure:use()
                end
            end
        end
    end
end

local function doCombatLoop(list, burn_type)
    local target = mq.TLO.Target
    local dist = target.Distance3D() or 0
    local maxdist = target.MaxRangeTo() or 0
    local mobhp = target.PctHPs() or 100
    local aggropct = target.PctAggro() or 100
    for _,ability in ipairs(list) do
        if (ability.name or ability.id) and (base.isAbilityEnabled(ability.opt)) and
                (ability.threshold == nil or ability.threshold <= state.mob_count_nopet) and
                (ability.type ~= Abilities.Types.Skill or dist < maxdist) and
                (ability.maxdistance == nil or dist <= ability.maxdistance) and
                (ability.usebelowpct == nil or mobhp <= ability.usebelowpct) and
                (burn_type == nil or ability[burn_type]) and
                (ability.aggro == nil or aggropct < 100) then
            if ability:use() and ability.delay then mq.delay(ability.delay) end
        end
    end
end

-- Consumable clickies that are likely not present when AQO starts so don't add as item lookups, plus used for all classes
base.mashClickies = {'Molten Orb', 'Lava Orb'}
local function doMashClickies()
    for _,clicky in ipairs(base.mashClickies) do
        local clickyItem = mq.TLO.FindItem('='..clicky)
        if clickyItem() and clickyItem.Timer() == '0' and (not base.item_timer or base.item_timer:timer_expired()) then
            if mq.TLO.Cursor.Name() == clickyItem.Name() then
                mq.cmd('/autoinv')
                mq.delay(50)
                clickyItem = mq.TLO.FindItem('='..clicky)
            end
            if base.class == 'brd' and mq.TLO.Me.Casting() then mq.cmd('/stopsong') mq.delay(1) end
            mq.cmdf('/useitem "%s"', clickyItem.Name())
            if base.item_timer then base.item_timer:reset() end
            mq.delay(50)
            mq.delay(250, function() return not mq.TLO.Me.Casting() end)
        end
    end
end

base.mash = function()
    if mq.TLO.Target.ID() == state.loop.ID then return end
    local cur_mode = config.MODE
    if (cur_mode:is_tank_mode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:is_assist_mode() and assist.should_assist()) or (cur_mode:is_manual_mode() and mq.TLO.Me.Combat()) then
        if base.mash_class then base.mash_class() end
        if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() or config.MAINTANK then
            doCombatLoop(base.tankAbilities)
        end
        doCombatLoop(base.DPSAbilities)
        if base.class ~= 'brd' then doMashClickies() end
    end
end

base.ae = function()
    if mq.TLO.Target.ID() == state.loop.ID then return end
    if not base.isEnabled('USEAOE') then return end
    local cur_mode = config.MODE
    if (cur_mode:is_tank_mode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:is_assist_mode() and assist.should_assist()) or (cur_mode:is_manual_mode() and mq.TLO.Me.Combat()) then
        if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() or config.MAINTANK then
            if base.ae_class then base.ae_class() end
            doCombatLoop(base.AETankAbilities)
        end
        doCombatLoop(base.AEDPSAbilities)
    end
end

base.burn = function()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag.
    -- Test them both for each item, and see which one(s) actually work.
    if mq.TLO.Target.ID() == state.loop.ID then return end
    if base.can_i_sing and not base.can_i_sing() then return end
    if common.is_burn_condition_met() then
        if base.burn_class then base.burn_class() end

        if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() or config.MAINTANK then
            doCombatLoop(base.tankBurnAbilities, state.burn_type)
        end
        doCombatLoop(base.burnAbilities, state.burn_type)
    end
end

base.find_next_spell = function()
    -- alliance
    -- synergy
    for _,spell in ipairs(base.spellRotations[base.OPTS.SPELLSET.value]) do
        if common.is_spell_ready(spell) and (base.isAbilityEnabled(spell.opt)) then return spell end
    end
end

local function castDebuffs()
    if mq.TLO.Target.ID() == state.loop.ID then return end
    if base.isEnabled('USEDISPEL') and mq.TLO.Target.Beneficial() and base.dispel then
        base.dispel:use()
        if base.dispel.type == Abilities.Types.Spell then return true end
    end
    -- debuff too generic to be checking Tashed TLO...
    --if base.isEnabled('USEDEBUFFAOE') and (base.class ~= 'enc' or not mq.TLO.Target.Tashed()) and (base.class ~= 'shm' or not mq.TLO.Target.Maloed()) and base.debuff then
    if base.isEnabled('USEDEBUFF') and 
            (base.class ~= 'enc' or not mq.TLO.Target.Tashed()) and
            (base.class ~= 'shm' or not mq.TLO.Target.Maloed()) and
            (base.class ~= 'mag' or not mq.TLO.Target.Maloed()) and
            (base.class ~= 'dru' or not mq.TLO.Target.Buff('Blessing of Ro')()) and
            base.debuff then
        base.debuff:use()
        if base.debuff.type == Abilities.Types.Spell then return true end
    end
    if base.isEnabled('USESNARE') and base.snare and not mq.TLO.Target.Snared() and not base.SNARE_IMMUNES[mq.TLO.Target.CleanName()] and (mq.TLO.Target.PctHPs() or 100) < 40 then
        base.snare:use()
        mq.doevents('event_snareimmune')
        if base.snare.type == Abilities.Types.Spell then return true end
    end
    if base.isEnabled('USESLOW') or base.isEnabled('USESLOWAOE') then
        local target = mq.TLO.Target
        if not target.Slowed() and not base.SLOW_IMMUNES[target.CleanName()] then
        --if target.Named() and not target.Slowed() and not base.SLOW_IMMUNES[target.CleanName()] then
            local abilityType
            if base.isEnabled('USESLOWAOE') and base.aeslow then
                base.aeslow:use()
                abilityType = base.aeslow.type
            elseif base.slow then
                base.slow:use()
                abilityType = base.slow.type
            end
            mq.doevents('event_slowimmune')
            if abilityType == Abilities.Types.Spell then return true end
        end
    end
end

base.nuketimer = timer:new(0)
base.cast = function()
    if mq.TLO.Me.SpellInCooldown() then return end
    if assist.is_fighting() then
        if castDebuffs() then state.actionTaken = true return end
        if base.nuketimer:timer_expired() then
            for _,clicky in ipairs(base.castClickies) do
                if (clicky.duration > 0 and mq.TLO.Target.Buff(clicky.checkfor)()) or
                        (clicky.casttime >= 0 and mq.TLO.Me.Moving()) then
                    movement.stop()
                    if clicky:use() then return end
                end
            end
            local spell = base.find_next_spell()
            if spell then -- if a dot was found
                if spell.precast then spell.precast() end
                if spell:use() then state.actionTaken = true end -- then cast the dot
                base.nuketimer:reset()
                if spell.postcast then spell.postcast() end
            end
        end
        -- nec multi dot stuff
        if base.isEnabled('MULTIDOT') then
            local original_target_id = 0
            if mq.TLO.Target.Type() == 'NPC' then original_target_id = mq.TLO.Target.ID() end
            local dotted_count = 1
            for i=1,20 do
                if mq.TLO.Me.XTarget(i).TargetType() == 'Auto Hater' and mq.TLO.Me.XTarget(i).Type() == 'NPC' then
                    local xtar_id = mq.TLO.Me.XTarget(i).ID()
                    local xtar_spawn = mq.TLO.Spawn(xtar_id)
                    if xtar_id ~= original_target_id and assist.should_assist(xtar_spawn) then
                        xtar_spawn.DoTarget()
                        mq.delay(2000, function() return mq.TLO.Target.ID() == xtar_id and not mq.TLO.Me.SpellInCooldown() end)
                        local spell = base.find_next_spell() -- find the first available dot to cast that is missing from the target
                        if spell and not mq.TLO.Target.Mezzed() then -- if a dot was found
                            spell:use()
                            dotted_count = dotted_count + 1
                            if dotted_count >= class.OPTS.MULTICOUNT.value then break end
                        end
                    end
                end
            end
            if original_target_id ~= 0 and mq.TLO.Target.ID() ~= original_target_id then
                mq.cmdf('/mqtar id %s', original_target_id)
            end
        end
    end
end

base.buff = function()
    if base.can_i_sing and not base.can_i_sing() then return end
    if buffing.buff(base) then state.actionTaken = true end
end

base.rest = function()
    common.rest()
end

base.mez = function()
    -- don't try to mez in manual mode
    if config.MODE:is_manual_mode() or config.MODE:is_tank_mode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() or config.MAINTANK then return end
    if base.OPTS.MEZAE.value and base.spells.mezae then
        if mez.do_ae(base.spells.mezae, base.OPTS.MEZAECOUNT.value) then state.actionTaken = true end
    end
    if base.OPTS.MEZST.value and base.spells.mezst then
        if mez.do_single(base.spells.mezst) then state.actionTaken = true end
    end
end

local check_aggro_timer = timer:new(5)
base.aggro = function()
    if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() or config.MAINTANK then return end
    if mq.TLO.Me.CombatState() == 'COMBAT' and state.loop.PctHPs < 50 then
        for _,ability in ipairs(base.defensiveAbilities) do
            if ability:use() and ability.stand then print('FD used, standing') mq.delay(50) mq.cmd('/stand') end
        end
    end
    if base.drop_aggro and config.MODE:get_name() ~= 'manual' and base.OPTS.USEFADE.value and state.mob_count > 0 and check_aggro_timer:timer_expired() then
        if ((mq.TLO.Target() and mq.TLO.Me.PctAggro() >= 70) or mq.TLO.Me.TargetOfTarget.ID() == state.loop.ID) and state.loop.PctHPs < 75 then
            base.drop_aggro:use()
            check_aggro_timer:reset()
            mq.delay(1000)
            mq.cmd('/multiline ; /makemevis ; /stand')
        end
    end
    if base.class == 'rog' and mq.TLO.Target() and mq.TLO.Me.PctAggro() >= 70 then
        if mq.TLO.Me.Combat() then mq.cmd('/attack off') mq.delay(1) end
        mq.cmd('/doability hide')
        mq.delay(1)
        mq.cmd('/attack on')
    end
end

base.ohshit = function()
    if base.ohshitclass then base.ohshit_class() end
end

local healClickies = {'Orb of Shadows'}
base.recover = function()
    if common.DMZ[mq.TLO.Zone.ID()] or (mq.TLO.Me.Level() == 70 and mq.TLO.Me.MaxHPs() < 6000) or mq.TLO.Me.Buff('Resurrection Sickness')() then return end
    if base.recover_class then base.recover_class() end
    -- modrods
    common.check_mana()
    local pct_hp = state.loop.PctHPs
    local pct_mana = state.loop.PctMana
    local pct_end = state.loop.PctEndurance
    local combat_state = mq.TLO.Me.CombatState()
    local useAbility = nil
    for _,ability in ipairs(base.recoverAbilities) do
        if base.isAbilityEnabled(ability.opt) then
            if ability.mana and pct_mana < config.RECOVERPCT and (ability.combat or combat_state ~= 'COMBAT') and (not ability.minhp or state.loop.PctHPs > ability.minhp) and (ability.ooc or mq.TLO.Me.CombatState() ~= 'ACTIVE') then
                useAbility = ability
                break
            elseif ability.endurance and pct_end < config.RECOVERPCT and (ability.combat or combat_state ~= 'COMBAT') then
                useAbility = ability
                break
            end
        end
    end
    if useAbility and useAbility:isReady() then
        local spell = nil
        if useAbility.type == Abilities.Types.Spell then
            spell = mq.TLO.Spell(useAbility.name)
        elseif useAbility.type == Abilities.Types.AA then
            spell = mq.TLO.Me.AltAbility(useAbility.name).Spell
        end
        if mq.TLO.Me.MaxHPs() < 6000 then return end
        if spell and spell.TargetType() == 'Single' then
            mq.TLO.Me.DoTarget()
        end
        if useAbility:use() then state.actionTaken = true end
    end
end

base.rez = function()
    if healing.rez(base.rezAbility) then state.actionTaken = true end
end

base.managepet = function()
    if not base.isEnabled('SUMMONPET') or not base.spells.pet then return end
    if not common.clear_to_buff() or mq.TLO.Pet.ID() > 0 or mq.TLO.Me.Moving() then return end
    if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.CAMPRADIUS))() > 0 then return end
    if (mq.TLO.Spell(base.spells.pet.name).Mana() or 0) > mq.TLO.Me.CurrentMana() then return end
    common.swap_and_cast(base.spells.pet, state.swapGem)
    mq.cmd('/multiline ; /pet ghold on')
    state.actionTaken = true
end

base.hold = function()

end

base.process_cmd = function(opt, new_value)
    if new_value then
        if opt == 'SPELLSET' and base.OPTS.SPELLSET ~= nil then
            if base.SPELLSETS[new_value] then
                print(logger.logLine('Setting %s to: %s', opt, new_value))
                base.OPTS.SPELLSET.value = new_value
            end
        elseif opt == 'USEEPIC' and base.OPTS.USEEPIC ~= nil then
            if base.EPIC_OPTS[new_value] then
                print(logger.logLine('Setting %s to: %s', opt, new_value))
                base.OPTS.USEEPIC.value = new_value
            end
        elseif opt == 'AURA1' and base.OPTS.AURA1 ~= nil then
            if base.AURAS[new_value] then
                print(logger.logLine('Setting %s to: %s', opt, new_value))
                base.OPTS.AURA1.value = new_value
            end
        elseif opt == 'AURA2' and base.OPTS.AURA2 ~= nil then
            if base.AURAS[new_value] then
                print(logger.logLine('Setting %s to: %s', opt, new_value))
                base.OPTS.AURA2.value = new_value
            end
        elseif base.OPTS[opt] and type(base.OPTS[opt].value) == 'boolean' then
            if config.booleans[new_value] == nil then return end
            base.OPTS[opt].value = config.booleans[new_value]
            print(logger.logLine('Setting %s to: %s', opt, config.booleans[new_value]))
        elseif base.OPTS[opt] and type(base.OPTS[opt].value) == 'number' then
            if tonumber(new_value) then
                print(logger.logLine('Setting %s to: %s', opt, tonumber(new_value)))
                if base.OPTS[opt].value ~= nil then base.OPTS[opt].value = tonumber(new_value) end
            end
        else
            print(logger.logLine('Unsupported command line option: %s %s', opt, new_value))
        end
    else
        if base.OPTS[opt] ~= nil then
            print(logger.logLine('%s: %s', opt:lower(), base.OPTS[opt].value))
        else
            print(logger.logLine('Unrecognized option: %s', opt))
        end
    end
end

base.nowCast = function(args)
    if #args == 3 then
        local sendTo = args[1]
        local alias = args[2]
        local target = args[3]
        mq.cmdf('/dex %s /nowcast "%s" %s', name, alias, target)
    elseif #args == 2 then
        local alias = args[1]
        local target = args[2]
        mq.cmd('/stopcast')
        mq.cmdf('/mqtar id %s', target)
    end
end

local function handleRequests()
    if #base.requests > 0 then
        local request = base.requests[1]
        if request.expiration:timer_expired() then
            print(logger.logLine('Request timer expired for \ag%s\ax from \at%s\at', request.requested.name, request.requester))
            table.remove(base.requests, 1)
        else
            local requesterSpawn = mq.TLO.Spawn('='..request.requester)
            if (requesterSpawn.Distance3D() or 300) < 100 then
                local restoreGem
                if request.requested.type == Abilities.Types.Spell and not mq.TLO.Me.Gem(request.requested.name)() then
                    restoreGem = {name=mq.TLO.Me.Gem(state.swapGem)()}
                    common.swap_spell(request.requested, state.swapGem)
                    mq.delay(5000, function() return mq.TLO.Me.SpellReady(request.requested.name)() end)
                end
                if request.requested:isReady() then
                    local tranquilUsed = '/g Casting'
                    if request.tranquil then
                        if (not mq.TLO.Me.AltAbilityReady('Tranquil Blessings')() or mq.TLO.Me.CombatState() == 'COMBAT') then
                            return
                        elseif base.tranquil then
                            if base.tranquil:use() then tranquilUsed = '/rs MGB\'ing' end
                        end
                    elseif request.mgb then
                        if not mq.TLO.Me.AltAbilityReady('Mass Group Buff')() then
                            return
                        elseif base.mgb then
                            if base.mgb:use() then tranquilUsed = '/rs MGB\'ing' end
                        end
                    end
                    movement.stop()
                    if request.requested.targettype == 'Single' then
                        requesterSpawn.DoTarget()
                    end
                    mq.cmdf('%s %s for %s', tranquilUsed, request.requested.name, request.requester)
                    request.requested:use()
                    table.remove(base.requests, 1)
                end
                if restoreGem then
                    common.swap_spell(restoreGem, state.swapGem)
                end
            end
        end
    end
end

local healclickies = {'Sanguine Mind Crystal III', 'Distillate of Divine Healing X', 'Orb of Shadows'}
local hotclickies = {'Distillate of Celestial Healing X'}
local function lifesupport()
    if mq.TLO.Me.CombatState() == 'COMBAT' and not state.loop.Invis and not mq.TLO.Me.Casting() and mq.TLO.Me.Standing() and state.loop.PctHPs < 60 then
        for _,healclicky in ipairs(healclickies) do
            local item = mq.TLO.FindItem(healclicky)
            if item() and mq.TLO.Me.ItemReady(healclicky)() then
                print(logger.logline('Use Item: \ag%s\ax', healclicky))
                local castTime = item.CastTime()
                mq.cmdf('/useitem "%s"', healclicky)
                mq.delay(250+(castTime or 0), function() return not mq.TLO.Me.ItemReady(healclicky)() end)
                state.loop.PctHPs = mq.TLO.Me.PctHPs()
                if state.loop.PctHPs > 75 then return end
            end
        end
    end
end

base.main_loop = function()
    if config.LOOTMOBS and state.assist_mob_id > 0 and not state.lootBeforePull then
        state.lootBeforePull = true
    end
    if not state.pull_in_progress then
        lifesupport()
        -- get mobs in camp
        camp.mob_radar()
        if config.MODE:is_tank_mode() then
            base.tank()
        end
        -- check whether we need to return to camp
        camp.check_camp()
        -- check whether we need to go chasing after the chase target
        common.check_chase()
        if base.check_spell_set then base.check_spell_set() end
        if not base.hold() then
            for _,routine in ipairs(base.classOrder) do
                if not state.actionTaken then base[routine]() end
            end
        end
        handleRequests()
    end
    if config.MODE:is_pull_mode() and not base.hold() and not state.lootBeforePull then
        pull.pull_mob(base.pull_func)
    end
end

return base