---@type Mq
local mq = require 'mq'
local lists = require('data.lists')
local assist = require('routines.assist')
local buffing = require('routines.buff')
local camp = require('routines.camp')
local healing = require('routines.heal')
local mez = require('routines.mez')
local movement = require('routines.movement')
local tank = require('routines.tank')
local logger = require('utils.logger')
local persistence = require('utils.persistence')
local timer = require('utils.timer')
local Abilities = require('ability')
local common = require('common')
local config = require('configuration')
local state = require('state')

local aqo
---@class base
---@field classOrder table #All possible class routine methods
---@field OPTS table #Collection of options for the class which appear in the Skills tab
---@field DEFAULT_SPELLSET? string #The spell set selected by default
---@field spells table #Collection of all spell id/name pairs that may be used for the class
---@field spellRotations table #Ordered spell rotations which may be loaded for the class and used in the cast routine
---@field DPSAbilities table #Abilities used in mash in any modes
---@field tankAbilities table #Abilities used in mash in tank modes
---@field burnAbilities table #Abilities used in burn in any modes
---@field tankBurnAbilities table #Abilities used in burn in tank modes
---@field healAbilities table #Abilities used in heal
---@field AEDPSAbilities table #Abilities used in ae in any mode
---@field AETankAbilities table #Abilities used in ae in tank modes
---@field defensiveAbilities table #Abilities used in aggro in non-tank modes
---@field fadeAbilities table #Abilities used in aggro in non-tank modes
---@field aggroAbilities table #Abilities used in aggro in non-tank modes
---@field recoverAbilities table #Abilities used in recover
---@field combatBuffs table #Abilities used to buff during combat
---@field auras table #Class aura abilities
---@field selfBuffs table #Abilities used to buff yourself
---@field groupBuffs table #Abilities used to buff the group
---@field singleBuffs table #Abilities used to buff individuals by class
---@field petBuffs table #Abilities used for pet buffing
---@field cures table #Abilities used in the cure routine
---@field requests table #Stores pending requests received from other characters
---@field requestAliases table #Aliases which can be used for requesting buffs
---@field clickies table #Combined list of user added clickies of all types
---@field castClickies table #User added items used in the cast routine
---@field pullClickies table #User added items used to pull mobs
---@field debuffs table #Abilities used in the debuff routine
---@field beforeEngage? function #Function to execute before engaging target (rogue stuff)
---@field resetClassTimers? function #Function to execute to reset class specific timers
---@field doneSinging? function #Function to check whether currently singing a song or if the cast time has already completed (bard stuff)
---@field mashClass? function #Function to perform class specific mash logic
---@field aeClass? function #Function to perform class specific AE logic
---@field burnClass? function #Function to perform class specific burn logic
---@field ohShitClass? function #Function to perform class specific ohshit logic
---@field aggroClass? function #Function to perform class specific aggro logic
---@field recoverClass? function #Function to perform class specific recover logic
---@field checkSpellSet? function #Function to load class spell sets
---@field swapSpells? function #Function to perform class specific checks for spell swapping in combat (necro stuff)
---@field rezAbility? Ability #
---@field useCommonListProcessor? boolean #
local base = {
    -- All possible class routine methods
    OPTS = {},
    spells = {},
    spellRotations = {},
    DPSAbilities = {},
    tankAbilities = {},
    burnAbilities = {},
    tankBurnAbilities = {},
    healAbilities = {},
    AEDPSAbilities = {},
    AETankAbilities = {},
    defensiveAbilities = {},
    fadeAbilities = {},
    aggroReducers = {},
    recoverAbilities = {},
    combatBuffs = {},
    auras = {},
    selfBuffs = {},
    groupBuffs = {},
    singleBuffs = {},
    petBuffs = {},
    cures = {},
    requests = {},
    requestAliases = {},
    clickies = {},
    castClickies = {},
    pullClickies = {},
    debuffs = {},
    --nuketimer
    --drop_aggro
    --pet
}

function base.initBase(_aqo, class)
    aqo = _aqo
    base.class = class
    base.addCommonOptions()
    base.addCommonAbilities()
end

-- Options added by key/value as well as by index/key so that settings can be displayed
-- in the skills tab in the order in which they are defined.
--- @param key string # The configuration key
--- @param label string # The text label that appears in the UI
--- @param value string|boolean|number # The default value for the setting
--- @param options table|nil # List of available options for combobox settings
--- @param tip string|nil # Hover  help message for the setting
--- @param type string # The UI element type (combobox, checkbox, inputint)
--- @param exclusive string|nil # The key of another option which is mutually exclusive with this option
function base.addOption(key, label, value, options, tip, type, exclusive)
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

function base.addCommonOptions()
    if base.spellRotations then
        base.addOption('SPELLSET', 'Spell Set', base.DEFAULT_SPELLSET or 'standard' , base.spellRotations, 'The spell set to be used', 'combobox')
        base.addOption('BYOS', 'BYOS', true, nil, 'Bring your own spells', 'checkbox')
    end
    base.addOption('USEAOE', 'Use AOE', true, nil, 'Toggle use of AOE abilities', 'checkbox')
    base.addOption('USEALLIANCE', 'Use Alliance', true, nil, 'Use alliance spell', 'checkbox')
    if lists.manaClasses[base.class] then
        base.addOption('USEMELEE', 'Use Melee', false, nil, 'Toggle attacking mobs with melee', 'checkbox')
    end
    if lists.petClasses[base.class] then
        base.addOption('SUMMONPET', 'Summon Pet', true, nil, 'Summon a pet', 'checkbox')
        base.addOption('BUFFPET', 'Buff Pet', true, nil, 'Use pet buffs', 'checkbox')
        base.addOption('HEALPET', 'Heal Pets', true, nil, 'Toggle healing of pets', 'checkbox')
    end
    if base.class == 'clr' then
        base.addOption('HEALPET', 'Heal Pets', true, nil, 'Toggle healing of pets', 'checkbox')
    end
    base.addOption('USEGLYPH', 'Use DPS Glyph', false, nil, 'Use glyph of destruction during burns', 'checkbox')
    base.addOption('USEINTENSITY', 'Use Intensity', false, nil, 'Use intensity of the resolute during burns', 'checkbox')
    if lists.buffClasses[base.class] then
        base.addOption('SERVEBUFFREQUESTS', 'Serve Buff Requests', true, nil, 'Toggle serving buff requests', 'checkbox')
    end
    if lists.healClasses[base.class] then
        base.addOption('USEHOTTANK', 'Use HoT (Tank)', false, nil, 'Toggle use of heal over time on tank', 'checkbox')
        base.addOption('USEHOTDPS', 'Use HoT (All)', false, nil, 'Toggle use of heal over time on everyone', 'checkbox')
        base.addOption('XTARGETHEAL', 'Heal XTarget', false, nil, 'Toggle healing of PCs on XTarget', 'checkbox')
        base.addOption('XTARGETBUFF', 'Buff XTarget', false, nil, 'Toggle buffing of PCs on XTarget', 'checkbox')
    end
end

function base.addCommonAbilities()
    base.tranquil = common.getAA('Tranquil Blessings')
    base.radiant = common.getAA('Radiant Cure', {all=true})
    base.silent = common.getAA('Silent Casting')
    base.mgb = common.getAA('Mass Group Buff')
end

-- Return true only if the option is both defined and true
-- For cases where something should only be done by a class who has the option
-- Ex. USEMEZ logic should only ever be entered for classes who can mez.
function base.isEnabled(key)
    return base.OPTS[key] and base.OPTS[key].value
end

-- Return true if the option is nil or the option is true
-- Ex. Kick has no option to toggle it, so should always be true. Intimidate has a toggle
-- so should evaluate the option.
function base.isAbilityEnabled(key)
    return not key or not base.OPTS[key] or base.OPTS[key].value
end

function base.addSpell(spellGroup, spellList, options)
    local foundSpell = common.getBestSpell(spellList, options)
    base.spells[spellGroup] = foundSpell
    if foundSpell then
        print(logger.logLine('[%s] Found spell: %s (%s)', spellGroup, foundSpell.name, foundSpell.id))
    else
        print(logger.logLine('[%s] Could not find spell!', spellGroup))
    end
end

function base.addClicky(clicky)
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
        elseif clicky.clickyType == 'combatbuff' then
            table.insert(base.combatBuffs, common.getItem(clicky.name, {checkfor=item.Clicky.Spell()}))
        elseif clicky.clickyType == 'buff' then
            table.insert(base.selfBuffs, common.getItem(clicky.name, {checkfor=item.Clicky.Spell()}))
        elseif clicky.clickyType == 'pull' then
            table.insert(base.pullClickies, common.getItem(clicky.name))
        else
            print(logger.logLine('Unknown clicky type: %s', clicky.clickyType))
            return
        end
        table.insert(base.clickies, clicky)
        print(logger.logLine('Added \ay%s\ax clicky: \ag%s\ax', clicky.clickyType, clicky.name))
    end
end

function base.removeClicky(itemName)
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
            elseif clicky.clickyType == 'combatbuff' then
                t = base.combatBuffs
            elseif clicky.clickyType == 'pull' then
                t = base.pullClickies
            else
                print(logger.logLine('Unknown clicky type: %s', clicky.clickyType))
                return
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

function base.addRequestAlias(ability, alias)
    base.requestAliases[alias] = ability
end

function base.getAbilityForAlias(alias)
    return base.requestAliases[alias]
end

function base.loadSettings()
    local settings = config.loadSettings()
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

function base.saveSettings()
    local optValues = {}
    for name,options in pairs(base.OPTS) do optValues[name] = options.value end
    persistence.store(config.SETTINGS_FILE, {common=config.getAll(), [base.class]=optValues, clickies=base.clickies})
end

function base.assist()
    if lists.DMZ[mq.TLO.Zone.ID()] or mq.TLO.Navigation.Active() then return end
    --if lists.healClasses[base.class] and config.ASSIST.value == 'manual' then return end
    if config.MODE.value:isAssistMode() then
        assist.checkTarget(base.resetClassTimers)
        logger.debug(logger.flags.class.assist, "after check target "..tostring(state.assistMobID))
        -- Get assist target still even if medding, incase we need to do debuffs or anything more important
        if not state.medding or not config.MEDCOMBAT.value then
            if base.isAbilityEnabled('USEMELEE') then
                if state.assistMobID and not mq.TLO.Me.Combat() and base.beforeEngage then
                    base.beforeEngage()
                end
                assist.attack()
            else
                assist.checkLOS()
            end
        end
        assist.sendPet()
    end
end

function base.tank()
    if lists.DMZ[mq.TLO.Zone.ID()] then return end
    if config.MODE.value:getName() == 'pullertank' and common.checkDistance(mq.TLO.Me.X(), mq.TLO.Me.Y(), camp.X, camp.Y) > (config.CAMPRADIUS.value-5) then
        movement.navToLoc(camp.X, camp.Y, camp.Z)
    else
        tank.findMobToTank()
        tank.tankMob()
        assist.sendPet()
    end
end

function base.heal()
    if lists.healClasses[base.class] then
        healing.heal(base.healAbilities, base.OPTS)
    elseif lists.petClasses[base.class] then
        healing.healPetOrSelf(base.healAbilities, base.OPTS)
    else
        healing.healSelf(base.healAbilities, base.OPTS)
    end
end

function base.cure()
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
                (ability.threshold == nil or ability.threshold <= state.mobCountNoPets) and
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
local function doMashClickies()
    for _,clicky in ipairs(lists.ddClickies) do
        local clickyItem = mq.TLO.FindItem('='..clicky)
        if clickyItem() and clickyItem.Timer() == '0' then
            if mq.TLO.Cursor.Name() == clickyItem.Name() then
                mq.cmd('/autoinv')
                mq.delay(50)
                clickyItem = mq.TLO.FindItem('='..clicky)
            end
            if base.class == 'brd' and mq.TLO.Me.Casting() then mq.cmd('/stopsong') mq.delay(1) end
            mq.cmdf('/useitem "%s"', clickyItem.Name())
            mq.delay(50)
            mq.delay(250, function() return not mq.TLO.Me.Casting() end)
        end
    end
end

function base.mash()
    if mq.TLO.Target.ID() == state.loop.ID then return end
    if state.medding and config.MEDCOMBAT.value then return end
    local cur_mode = config.MODE.value
    if (cur_mode:isTankMode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:isAssistMode() and assist.shouldAssist()) or (cur_mode:isManualMode() and mq.TLO.Me.Combat()) then
        if base.mashClass then base.mashClass() end
        if config.MODE.value:isTankMode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() or config.MAINTANK.value then
            if base.useCommonListProcessor then
                common.processList(base.tankAbilities, false)
            else
                doCombatLoop(base.tankAbilities)
            end
        end
        if base.useCommonListProcessor then
            common.processList(base.DPSAbilities, false)
        else
            doCombatLoop(base.DPSAbilities)
        end
        if base.class ~= 'brd' then doMashClickies() end
    end
end

function base.ae()
    if mq.TLO.Target.ID() == state.loop.ID then return end
    if state.medding and config.MEDCOMBAT.value then return end
    if not base.isEnabled('USEAOE') then return end
    local cur_mode = config.MODE.value
    if (cur_mode:isTankMode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:isAssistMode() and assist.shouldAssist()) or (cur_mode:isManualMode() and mq.TLO.Me.Combat()) then
        if config.MODE.value:isTankMode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() or config.MAINTANK.value then
            if base.aeClass then base.aeClass() end
            if base.useCommonListProcessor then
                common.processList(base.AETankAbilities, false)
            else
                doCombatLoop(base.AETankAbilities)
            end
        end
        if base.useCommonListProcessor then
            common.processList(base.AEDPSAbilities, false)
        else
            doCombatLoop(base.AEDPSAbilities)
        end
    end
end

function base.burn()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag.
    -- Test them both for each item, and see which one(s) actually work.
    if mq.TLO.Target.ID() == state.loop.ID then return end
    if state.medding and config.MEDCOMBAT.value then return end
    if base.doneSinging and not base.doneSinging() then return end
    if common.isBurnConditionMet() then
        if base.burnClass then base.burnClass() end

        if config.MODE.value:isTankMode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() or config.MAINTANK.value then
            if base.useCommonListProcessor then
                common.processList(base.tankBurnAbilities, false)
            else
                doCombatLoop(base.tankBurnAbilities, state.burn_type)
            end
        end
        if base.useCommonListProcessor then
            common.processList(base.burnAbilities, false)
        else
            doCombatLoop(base.burnAbilities, state.burn_type)
        end
    end
end

function base.findNextSpell()
    -- alliance
    -- synergy
    for _,spell in ipairs(base.spellRotations[base.OPTS.SPELLSET.value]) do
        local resistCount = state.resists[spell.name] or 0
        if common.isSpellReady(spell) and base.isAbilityEnabled(spell.opt)
                and (config.RESISTSTOPCOUNT.value == 0 or resistCount < config.RESISTSTOPCOUNT.value)
                and (not spell.condition or spell.condition()) then
            return spell
        end
    end
end

function base.debuff()
    aqo.debuff.castDebuffs()
end

base.nuketimer = timer:new(0)
function base.cast()
    if mq.TLO.Me.SpellInCooldown() or base.isEnabled('DONTCAST') then return end
    if state.medding and config.MEDCOMBAT.value then return end
    if assist.isFighting() then
        if base.nuketimer:timerExpired() then
            for _,clicky in ipairs(base.castClickies) do
                if (clicky.duration == 0 or not mq.TLO.Target.Buff(clicky.checkfor)()) and not mq.TLO.Me.Moving() then
                    if clicky:use() then return end
                end
            end
            local spell = base.findNextSpell()
            if spell then -- if a dot was found
                if spell.precast then spell.precast() end
                if spell:use() then state.actionTaken = true end -- then cast the dot
                base.nuketimer:reset()
                mq.doevents()--'eventResist')
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
                    if xtar_id ~= original_target_id and assist.shouldAssist(xtar_spawn) then
                        xtar_spawn.DoTarget()
                        mq.delay(2000, function() return mq.TLO.Target.ID() == xtar_id and not mq.TLO.Me.SpellInCooldown() end)
                        local spell = base.findNextSpell() -- find the first available dot to cast that is missing from the target
                        if spell and not mq.TLO.Target.Mezzed() then -- if a dot was found
                            spell:use()
                            state.actionTaken = true
                            dotted_count = dotted_count + 1
                            if dotted_count >= base.OPTS.MULTICOUNT.value then break end
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

function base.buff()
    if base.doneSinging and not base.doneSinging() then return end
    if state.medding and config.MEDCOMBAT.value then return end
    if buffing.buff(base) then state.actionTaken = true end
end

function base.rest()
    common.rest()
end

function base.mez()
    -- don't try to mez in manual mode
    if config.MODE.value:isManualMode() or config.MODE.value:isTankMode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() or config.MAINTANK.value then return end
    if base.OPTS.MEZAE.value and base.spells.mezae then
        if mez.doAE(base.spells.mezae, base.OPTS.MEZAECOUNT.value) then state.actionTaken = true end
    end
    if base.OPTS.MEZST.value and base.spells.mezst then
        if mez.doSingle(base.spells.mezst) then state.actionTaken = true end
    end
end

function base.aggro()
    if config.MODE.value:isTankMode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() or config.MAINTANK.value then return end
    local pctAggro = mq.TLO.Me.PctAggro() or 0
    -- 1. Am i on aggro? Use fades or defensives immediately
    if mq.TLO.Target() and mq.TLO.Me.TargetOfTarget.ID() == state.loop.ID and mq.TLO.Target.Named() then
        local useDefensives = true
        for _,ability in ipairs(base.fadeAbilities) do
            if base.isAbilityEnabled(ability.opt) then
                if ability.precast then ability.precast() end
                ability:use()
                if ability.postcast then ability.postcast() end
                if mq.TLO.Me.TargetOfTarget.ID() ~= state.loop.ID then
                    -- No longer on aggro, skip popping defensives
                    useDefensives = false
                    break
                end
            end
        end
        if useDefensives then
            -- Didn't lose aggro from fade abilities, hit defensives
            for _,ability in ipairs(base.defensiveAbilities) do
                if base.isAbilityEnabled(ability.opt) then
                    if ability.precast then ability.precast() end
                    ability:use()
                    if ability.postcast then ability.postcast() end
                end
            end
        end
    end
    -- 2. Is my aggro above some threshold? Use aggro reduction abilities
    if mq.TLO.Target() and pctAggro >= 70 and mq.TLO.Target.Named() then
        for _,ability in ipairs(base.aggroReducers) do
            if base.isAbilityEnabled(ability.opt) then
                if ability.precast then ability.precast() end
                ability:use()
                if ability.postcast then ability.postcast() end
            end
        end
        if base.aggroClass then base.aggroClass() end
    end
end

function base.ohshit()
    if base.ohShitClass then base.ohShitClass() end
end

function base.recover()
    if lists.DMZ[mq.TLO.Zone.ID()] or (mq.TLO.Me.Level() == 70 and mq.TLO.Me.MaxHPs() < 6000) or mq.TLO.Me.Buff('Resurrection Sickness')() then return end
    if base.recoverClass then base.recoverClass() end
    -- modrods
    common.checkMana()
    local pct_hp = state.loop.PctHPs
    local pct_mana = state.loop.PctMana
    local pct_end = state.loop.PctEndurance
    local combat_state = mq.TLO.Me.CombatState()
    local useAbility = nil
    for _,ability in ipairs(base.recoverAbilities) do
        if base.isAbilityEnabled(ability.opt) and (not ability.nodmz or not lists.DMZ[mq.TLO.Zone.ID()]) then
            if ability.mana and pct_mana < (ability.threshold or config.RECOVERPCT.value) and (ability.combat or combat_state ~= 'COMBAT') and (not ability.minhp or state.loop.PctHPs > ability.minhp) and (ability.ooc or mq.TLO.Me.CombatState() == 'COMBAT') then
                useAbility = ability
                break
            elseif ability.endurance and pct_end < (ability.threshold or config.RECOVERPCT.value) and (ability.combat or combat_state ~= 'COMBAT') then
                useAbility = ability
                break
            end
        end
    end
    if useAbility and useAbility:isReady() then
        if mq.TLO.Me.MaxHPs() < 6000 then return end
        local originalTargetID = 0
        if useAbility.targettype == 'Single' and mq.TLO.Target.ID() ~= state.loop.ID then
            originalTargetID = mq.TLO.Target.ID()
            mq.TLO.Me.DoTarget()
        end
        if useAbility:use() then state.actionTaken = true end
        if originalTargetID > 0 then mq.cmdf('/mqtar id %s', originalTargetID) else mq.cmd('/squelch /mqtar clear') end
    end
end

function base.rez()
    if healing.rez(base.rezAbility) then state.actionTaken = true end
end

function base.managepet()
    if not base.isEnabled('SUMMONPET') or not base.spells.pet then return end
    if not common.clearToBuff() or mq.TLO.Pet.ID() > 0 or mq.TLO.Me.Moving() then return end
    if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.CAMPRADIUS.value))() > 0 then return end
    local petSpell = mq.TLO.Spell(base.spells.pet.name)
    if (petSpell.Mana() or 0) > mq.TLO.Me.CurrentMana() then return end
    local reagentID = petSpell.ReagentID(1)()
    if reagentID > 0 and not mq.TLO.FindItem(reagentID)() then return end
    common.swapAndCast(base.spells.pet, state.swapGem)
    mq.cmd('/multiline ; /pet ghold on')
    state.actionTaken = true
end

function base.hold()

end

function base.nowCast(args)
    if #args == 3 then
        local sendTo = args[1]:lower()
        local alias = args[2]:lower()
        local target = args[3]:lower()
        if sendTo == 'me' or sendTo == mq.TLO.Me.CleanName():lower() then
            local spellToCast = base.spells[alias] or base[alias]
            table.insert(base.requests, {requester=target, requested=spellToCast, expiration=timer:new(15, true), tranquil=false, mgb=false})
        else
            local sendToSpawn = mq.TLO.Spawn('pc ='..sendTo)
            if sendToSpawn() then
                -- sendToSpawn.Class.ShortName(),  why did i have this here
                mq.cmdf('/squelch /dex %s /nowcast "%s" %s', sendTo, alias, target)
            end
        end
    elseif #args == 2 then
        local alias = args[1]:lower()
        local target = args[2]:lower()
        local spellToCast = base.spells[alias] or base[alias]
        if spellToCast then
            table.insert(base.requests, {requester=target, requested=spellToCast, expiration=timer:new(15, true), tranquil=false, mgb=false})
        end
    end
end

local function handleRequests()
    if #base.requests > 0 then
        local request = base.requests[1]
        if request.expiration:timerExpired() then
            print(logger.logLine('Request timer expired for \ag%s\ax from \at%s\at', request.requested.name, request.requester))
            table.remove(base.requests, 1)
        else
            local requesterSpawn = '='..request.requester
            if tonumber(request.requester) then
                requesterSpawn = 'id '..request.requester
            end
            local requesterSpawn = mq.TLO.Spawn(requesterSpawn)
            if (requesterSpawn.Distance3D() or 300) < 100 then
                local restoreGem
                if request.requested.type == Abilities.Types.Spell and not mq.TLO.Me.Gem(request.requested.name)() then
                    restoreGem = {name=mq.TLO.Me.Gem(state.swapGem)()}
                    common.swapSpell(request.requested, state.swapGem)
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
                    common.swapSpell(restoreGem, state.swapGem)
                end
            end
        end
    end
end

local function lifesupport()
    if mq.TLO.Me.CombatState() == 'COMBAT' and not state.loop.Invis and not mq.TLO.Me.Casting() and mq.TLO.Me.Standing() and state.loop.PctHPs < 60 then
        for _,healclicky in ipairs(lists.instantHealClickies) do
            local item = mq.TLO.FindItem(healclicky)
            local spell = item.Clicky.Spell
            if item() and mq.TLO.Me.ItemReady(healclicky)() and (spell.Duration.TotalSeconds() == 0 or (not mq.TLO.Me.Song(spell.Name())()) and mq.TLO.Spell(spell.Name()).Stacks()) then
                print(logger.logLine('Use Item: \ag%s\ax', healclicky))
                local castTime = item.CastTime()
                mq.cmdf('/useitem "%s"', healclicky)
                mq.delay(250+(castTime or 0), function() return not mq.TLO.Me.ItemReady(healclicky)() end)
                state.loop.PctHPs = mq.TLO.Me.PctHPs()
                if state.loop.PctHPs > 75 then return end
            end
        end
    end
end

function base.mainLoop()
    if config.LOOTMOBS.value and state.assistMobID > 0 and not state.lootBeforePull then
        -- some attempt at forcing a round of looting before beginning another pull,
        -- otherwise, depending where we are in the loop when a mob dies, we might go
        -- directly into another pull before trying to loot what we just killed.
        state.lootBeforePull = true
    end
    if not state.pullStatus then
        lifesupport()
        handleRequests()
        -- get mobs in camp
        camp.mobRadar()
        if config.MODE.value:isTankMode() then
            base.tank()
        end
        -- check whether we need to return to camp
        if not state.assistMobID or state.assistMobID == 0 then camp.checkCamp() end
        -- check whether we need to go chasing after the chase target
        common.checkChase()
        if base.checkSpellSet then base.checkSpellSet() end
        if not base.hold() then
            for _,routine in ipairs(base.classOrder) do
                if not state.actionTaken then base[routine]() end
                if routine == 'cast' and not state.actionTaken and base.swapSpells then
                    base.swapSpells()
                end
            end
        end
    end
    if config.MODE.value:isPullMode() and not base.hold() and not state.lootBeforePull then
        aqo.pull.pullMob()
    end
end

return base