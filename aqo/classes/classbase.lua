local mq = require 'mq'

local config    = require('interface.configuration')

local assist    = require('routines.assist')
local buffing   = require('routines.buff')
local camp      = require('routines.camp')
local curing    = require('routines.cure')
local debuff    = require('routines.debuff')
local healing   = require('routines.heal')
local mez       = require('routines.mez')
local pull      = require('routines.pull')
local tank      = require('routines.tank')

local helpers   = require('utils.helpers')
local logger    = require('utils.logger')
local movement  = require('utils.movement')
local timer     = require('libaqo.timer')

local abilities = require('ability')
local common    = require('common')
local constants = require('constants')
local mode      = require('mode')
local state     = require('state')

---Each EQ class' implementation extends from and overrides this base class.
---Base provides the main class routine loop and common implementations to iterate over ability lists
---and to call into each configured class routine.
---@class base
---@field classOrder                table   #Ordered list of routines to run such as tank,assist,pull
---@field options                   table   #Collection of class specific configuration options
---Spells
---@field defaultSpellset?          string  #The name of the default spell set for the class, typically 'standard' except for bards
---@field SpellLines?               table   #Collection of all spells to be searched for at startup and any hardcoded options for each
---@field compositeNames?           table   #Base names of each composite spell since progressive spells work funny
---@field spells                    table   #Collection of all known spells that may be used by the class
---@field spellRotations?           table   #Ordered spell rotations used in the cast routine, specifically for DPS spells
---@field BYOSRotation?             table   #Ordered DPS spell rotation used in BYOS mode based on currently mem'd spells
---@field customRotation?           table   #Ordered user defined DPS spell rotation when in BYOS mode
---@field allDPSSpellGroups         table   #Spell group names of all DPS spells allowed for selection in custom spell rotation
---Ability lists
---@field useCommonListProcessor?   boolean #
---@field Abilities?                table   # All AA, Disc, Skill, Item definitions which will be searched for on startup and loaded into below lists
---@field DPSAbilities              table   #Abilities used in mash in any modes
---@field tankAbilities             table   #Abilities used in mash in tank modes
---@field burnAbilities             table   #Abilities used in burn in any modes
---@field rangedBurnAbilities       table   #Abilities used in burn when ranged (just ranger atm)
---@field tankBurnAbilities         table   #Abilities used in burn in tank modes
---@field healAbilities             table   #Abilities used in heal routine
---@field AEDPSAbilities            table   #Abilities used in ae in any mode
---@field AETankAbilities           table   #Abilities used in ae in tank modes
---@field defensiveAbilities        table   #Abilities used in aggro in non-tank modes
---@field fadeAbilities             table   #Abilities used in aggro in non-tank modes
---@field aggroReducers             table   #Abilities used in aggro in non-tank modes
---@field recoverAbilities          table   #Abilities used in recover
---@field combatBuffs               table   #Abilities used to buff during combat
---@field auras                     table   #Class aura abilities
---@field selfBuffs                 table   #Abilities used to buff yourself
---@field singleBuffs               table   #Abilities used to buff individuals by class
---@field petBuffs                  table   #Abilities used for pet buffing
---@field cures                     table   #Abilities used in the cure routine
---@field debuffs                   table   #Abilities used in the debuff routine
---@field rezAbility?               Ability #
---@field epic?                     string  # name of epic
---Request handling
---@field requests                  table   #Stores pending requests received from other characters
---@field requestAliases            table   #Aliases which can be used for requesting buffs
---Clicky management
---@field clickies                  table   #Combined list of user added clickies of all types
---@field castClickies              table   #User added items used in the cast routine
---@field pullClickies              table   #User added items used to pull mobs
---Class functions
---@field beforeEngage?             function #Function to execute before engaging target (rogue stuff)
---@field resetClassTimers?         function #Function to execute to reset class specific timers
---@field doneSinging?              function #Function to check whether currently singing a song or if the cast time has already completed (bard stuff)
---@field mashClass?                function #Function to perform class specific mash logic
---@field aeClass?                  function #Function to perform class specific AE logic
---@field burnClass?                function #Function to perform class specific burn logic
---@field ohShitClass?              function #Function to perform class specific ohshit logic
---@field aggroClass?               function #Function to perform class specific aggro logic
---@field recoverClass?             function #Function to perform class specific recover logic
---@field checkSpellSet?            function #Function to load class spell sets
---@field swapSpells?               function #Function to perform class specific checks for spell swapping in combat (necro stuff)
local base = {
    -- All possible class routine methods
    options = {},
    spells = {},
    DPSAbilities = {},
    tankAbilities = {},
    burnAbilities = {},
    rangedBurnAbilities = {},
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
    singleBuffs = {},
    petBuffs = {},
    cures = {},
    debuffs = {},
    requests = {},
    requestAliases = {},
    clickies = {},
    castClickies = {},
    pullClickies = {},
}

function base:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function base:initBase(class)
    self.class = class
    self:addCommonOptions()
end

---Adds a new class configuration option which will be exposed via the UI, CLI and TLO. 
---Options added by key/value as well as by index/key so that settings can be displayed
---in the skills tab in the order in which they are defined.
--- @param key string # The configuration key
--- @param label string # The text label that appears in the UI
--- @param value string|boolean|number # The default value for the setting
--- @param options table|nil # List of available options for combobox settings
--- @param tip string|nil # Hover  help message for the setting
--- @param type string # The UI element type (combobox, checkbox, inputint)
--- @param exclusive string|nil # The key of another option which is mutually exclusive with this option
function base:addOption(key, label, value, options, tip, type, exclusive, tlo, tlotype)
    if not self.options[key] then
        table.insert(self.options, key)
    end
    self.options[key] = {
        label=label,
        value=value,
        options=options,
        tip=tip,
        type=type,
        exclusive=exclusive,
        tlo=tlo,
        tlotype=tlotype,
    }
end

function base:addCommonOptions()
    if self.spellRotations then
        self:addOption('SPELLSET', 'Spell Set', self.defaultSpellset or 'standard' , self.spellRotations, 'The spell set to be used', 'combobox', nil, 'SpellSet', 'string')
        self:addOption('BYOS', 'BYOS', true, nil, 'Bring your own spells', 'checkbox', nil, 'BYOS', 'bool')
        self:addOption('FORCEROTATE', 'Rotate Spells', false, nil, 'Force iterating through the spell rotation even if earlier spells are ready', 'checkbox', nil, 'ForceRotate', 'bool')
    end
    self:addOption('USEAOE', 'Use AOE', true, nil, 'Toggle use of AOE abilities', 'checkbox', nil, 'UseAOE', 'bool')
    if not state.emu then self:addOption('USEALLIANCE', 'Use Alliance', true, nil, 'Use alliance spell', 'checkbox', nil, 'UseAlliance', 'bool') end
    if constants.manaClasses[self.class] then
        self:addOption('USEMELEE', 'Use Melee', false, nil, 'Toggle attacking mobs with melee', 'checkbox', nil, 'UseMelee', 'bool')
    end
    if constants.petClasses[self.class] then
        self:addOption('SUMMONPET', 'Summon Pet', true, nil, 'Summon a pet', 'checkbox', nil, 'SummonPet', 'bool')
        self:addOption('BUFFPET', 'Buff Pet', true, nil, 'Use pet buffs', 'checkbox', nil, 'BuffPet', 'bool')
        self:addOption('HEALPET', 'Heal Pets', true, nil, 'Toggle healing of pets', 'checkbox', nil, 'HealPet', 'bool')
    end
    if self.class == 'CLR' then
        self:addOption('HEALPET', 'Heal Pets', true, nil, 'Toggle healing of pets', 'checkbox', nil, 'HealPet', 'bool')
    end
    if constants.buffClasses[self.class] then
        self:addOption('SERVEBUFFREQUESTS', 'Serve Buff Requests', true, nil, 'Toggle serving buff requests', 'checkbox', nil, 'ServeBuffRequests', 'bool')
    end
    if constants.healClasses[self.class] then
        self:addOption('USEHOTTANK', 'Use HoT (Tank)', false, nil, 'Toggle use of heal over time on tank', 'checkbox', nil, 'UseHoTTank', 'bool')
        self:addOption('USEHOTDPS', 'Use HoT (All)', false, nil, 'Toggle use of heal over time on everyone', 'checkbox', nil, 'UseHoTDPS', 'bool')
        self:addOption('XTARGETBUFF', 'Buff XTarget', false, nil, 'Toggle buffing of PCs on XTarget', 'checkbox', nil, 'XTargetBuff', 'bool')
    end
end

function base:addCommonAbilities()
    self.tranquil = self:addAA('Tranquil Blessings')
    self.radiant = self:addAA('Radiant Cure', {all=true, alias='RC', cure=true})
    table.insert(self.cures, self.radiant)
    self.silent = self:addAA('Silent Casting', {first=true})
    table.insert(self.burnAbilities, self.silent)
    self.mgb = self:addAA('Mass Group Buff')
    if not self.rezAbility then self.rezAbility = common.getItem('Token of Resurrection') end
    if not state.emu then
        self.glyph = self:addAA('Mythic Glyph of Ultimate Power V')
        self.intensity = self:addAA('Intensity of the Resolute')
    else
        self.glyph = self:addAA('Glyph of Courage')
    end
    table.insert(self.burnAbilities, self:addAA('Focus of Arcanum'))
    table.insert(self.burnAbilities, self:addAA('Empowered Focus of Arcanum'))
    table.insert(self.combatBuffs, self:addAA('Acute Focus of Arcanum', {skipifbuff='Enlightened Focus of Arcanum', combatbuff=true}))
    table.insert(self.combatBuffs, self:addAA('Enlightened Focus of Arcanum', {skipifbuff='Acute Focus of Arcanum', combatbuff=true}))
end

-- Return true only if the option is both defined and true
-- For cases where something should only be done by a class who has the option
-- Ex. USEMEZ logic should only ever be entered for classes who can mez.
function base:isEnabled(key)
    return self.options[key] and self.options[key].value == true
end

-- Return true if the option is nil or the option is true
-- Ex. Kick has no option to toggle it, so should always be true. Intimidate has a toggle
-- so should evaluate the option.
function base:isAbilityEnabled(key)
    return not key or not self.options[key] or self.options[key].value == true
end

function base:get(key)
    return self.options[key] and self.options[key].value
end

function base:set(key, value)
    self.options[key].value = value
end

---Add the best N spells from the list of spells to the class spell list
---@param spellGroup string # Name of the spell category
---@param numToAdd number # Number of spells from the category to be added
---@param spellList table # Table of spell names to search in order
---@param options table # Table of options to be applied to the spell
function base:addNSpells(spellGroup, numToAdd, spellList, options)
    for i=1,numToAdd do
        if options.Gems then options.Gem = options.Gems[i] end
        local foundSpell = common.getBestSpell(spellList, options, spellGroup)
        if not foundSpell then
            logger.info('Could not find spell: \ag%s\ax', spellGroup..i)
            return
        end
        if not self.spells[spellGroup..i] then
            self.spells[spellGroup..i] = foundSpell
            self:addAbilityToLists(self.spells[spellGroup..i])
        else
            for k,v in pairs(foundSpell) do
                self.spells[spellGroup..i][k] = v
            end
        end
        local j = 1
        while spellList[1] ~= foundSpell.BaseName or j > 25 do
            j = j + 1 -- prevent infinite loop in case of some strange edge case maybe
            table.remove(spellList, 1)
        end
        table.remove(spellList, 1)
    end
end

function base:initSpellLines()
    for _,line in ipairs(self.SpellLines) do
        if line.NumToPick then
            self:addNSpells(line.Group, line.NumToPick, line.Spells, line.Options)
        else
            self:addSpell(line.Group, line.Spells, line.Options)
        end
    end
end

---Add the best spell from the list of spells to the class spell list
---@param spellGroup string # Name of the spell category
---@param spellList table # Table of spell names to search in order
---@param options table # Table of options to be applied to the spell
function base:addSpell(spellGroup, spellList, options)
    local foundSpell = common.getBestSpell(spellList, options, spellGroup)
    if not foundSpell then
        logger.info('Could not find spell: \ag%s\ax', spellGroup)
        return
    end
    if not self.spells[spellGroup] then
        self.spells[spellGroup] = foundSpell
        self:addAbilityToLists(self.spells[spellGroup])
    else
        for k,v in pairs(foundSpell) do
            self.spells[spellGroup][k] = v
        end
    end
end

local flagToTableMap = {
    dps = 'DPSAbilities',
    aedps = 'AEDPSAbilities',
    first = 'burnAbilities',
    second = 'burnAbilities',
    third = 'burnAbilities',
    burn = 'burnAbilities',
    rangeburn = 'rangedBurnAbilities',
    tanking = 'tankAbilities',
    aetank = 'AETankAbilities',
    tankburn = 'tankBurnAbilities',
    heal = 'healAbilities',
    combatbuff = 'combatBuffs',
    selfbuff = 'selfBuffs',
    aurabuff = 'auras',
    petbuff = 'petBuffs',
    singlebuff = 'singleBuffs',
    fade = 'fadeAbilities',
    defensive = 'defensiveAbilities',
    recover = 'recoverAbilities',
    cure = 'cures',
    debuff = 'debuffs',
    aggroreducer = 'aggroReducers',
    preburn = 'preburn',
}

function base:addAbilityToLists(ability)
    if ability.key and not self[ability.key] then self[ability.key] = ability end
    if ability.alias and not self.requestAliases[ability.alias] then self.requestAliases[ability.alias] = ability end
    for flag,abilityTableName in pairs(flagToTableMap) do
        if type(ability[flag]) == 'function' then ability[flag] = ability[flag]() end
        if ability[flag] == true then
            table.insert(self[abilityTableName], ability)
        end
    end
    if ability.rez then self.rezAbility = ability end
end

function base:addAA(name, options)
    local aa = common.getAA(name, options)
    --if aa and aa.alias then self.requestAliases[options.alias] = aa end
    return aa
end

function base:initAbilities()
    for _,ability in ipairs(self.Abilities) do
        if (ability.Options and ability.Options.emu and state.emu) or (not ability.Options or not ability.Options.emu) then
            local foundAbility = nil
            if ability.Type == 'AA' then
                foundAbility = self:addAA(ability.Name, ability.Options)
            elseif ability.Type == 'Disc' then
                foundAbility = common.getBestDisc(ability.Names, ability.Options)
            elseif ability.Type == 'Item' then
                foundAbility = common.getItem(ability.Name, ability.Options)
            elseif ability.Type == 'Skill' then
                foundAbility = common.getSkill(ability.Name, ability.Options)
            end
            if foundAbility then
                if foundAbility.Group and foundAbility.Group ~= '' then
                    if not self[foundAbility.Group] then
                        self[foundAbility.Group] = foundAbility
                        self:addAbilityToLists(foundAbility)
                    else
                        for k,v in pairs(foundAbility) do
                            self.spells[foundAbility.Group][k] = v
                        end
                    end
                else
                    self:addAbilityToLists(foundAbility)
                end
            end
        end
    end
end

function base:getTableForClicky(clickyType)
    if clickyType == 'burn' then
        return self.burnAbilities
    elseif clickyType == 'mash' then
        return self.DPSAbilities
    elseif clickyType == 'cast' then
        return self.castClickies
    elseif clickyType == 'heal' then
        return self.healAbilities
    elseif clickyType == 'mana' then
    elseif clickyType == 'dispel' then
    elseif clickyType == 'cure' then
    elseif clickyType == 'combatbuff' then
        return self.combatBuffs
    elseif clickyType == 'buff' then
        return self.selfBuffs
    elseif clickyType == 'petbuff' then
        return self.petBuffs
    elseif clickyType == 'pull' then
        return self.pullClickies
    else
        logger.info('Unknown clicky type: %s', clickyType)
        return nil
    end
end

function base:addClicky(clicky)
    self.clickies[clicky.name] = {clickyType=clicky.clickyType, summonMinimum=clicky.summonMinimum, opt=clicky.opt, enabled=clicky.enabled}
    local item = mq.TLO.FindItem('='..clicky.name)
    if item.Clicky() then
        local t = self:getTableForClicky(clicky.clickyType)
        if t then
            table.insert(t, common.getItem(clicky.name, {summonMinimum=clicky.summonMinimum, opt=clicky.opt, enabled=clicky.enabled}))
        end
        logger.info('Added \ay%s\ax clicky: \ag%s\ax', clicky.clickyType, clicky.name)
    end
end

function base:removeClicky(itemName)
    local clicky = self.clickies[itemName]
    if not clicky then
        -- clicky not found
        logger.info('Clicky \ag%s\ax not found', itemName)
        return
    end
    if type(clicky) ~= 'table' then
        clicky = {clickyType=clicky}
    end
    local t = self:getTableForClicky(clicky.clickyType)
    if not t then return end
    for i,entry in ipairs(t) do
        if entry.CastName == itemName then
            table.remove(t, i)
            self.clickies[itemName] = nil
            logger.info('Removed \ay%s\ax clicky: \ag%s\ax', clicky.clickyType, itemName)
            return
        end
    end
end

function base:enableClicky(itemName)
    local clicky = self.clickies[itemName]
    if not clicky then
        return
    end
    local t = self:getTableForClicky(clicky.clickyType)
    if not t then return end
    for i,entry in ipairs(t) do
        if entry.CastName == itemName then
            entry.enabled = true
            self.clickies[itemName].enabled = true
            logger.info('\agENABLED\ax \ay%s\ax clicky: \ag%s\ax', clicky.clickyType, itemName)
        end
    end
end

function base:disableClicky(itemName)
    local clicky = self.clickies[itemName]
    if not clicky then
        return
    end
    local t = self:getTableForClicky(clicky.clickyType)
    if not t then return end
    for i,entry in ipairs(t) do
        if entry.CastName == itemName then
            entry.enabled = false
            self.clickies[itemName].enabled = false
            logger.info('\arDISABLED\ax \ay%s\ax clicky: \ag%s\ax', clicky.clickyType, itemName)
        end
    end
end

function base:getRequestAliases()
    local aliases = {}
    for name,ability in pairs(self.requestAliases) do
        aliases[name] = ability.CastName
    end
    return aliases
end

function base:getAbilityForAlias(alias)
    return self.requestAliases[alias]
end

function base:loadSettings()
    local settings = config.loadSettings()
    if not settings or not settings[self.class] then return end
    for setting,value in pairs(settings[self.class]) do
        if self.options[setting] == nil then
            logger.info('Unrecognized setting: %s=%s', setting, value)
        else
            self.options[setting].value = value
        end
    end
    if settings.clickies then
        for clickyName,clicky in pairs(settings.clickies) do
            if type(clicky) == 'string' then
                clicky = {clickyType=clicky}
            end
            base:addClicky({name=clickyName, clickyType=clicky.clickyType, summonMinimum=clicky.summonMinimum, opt=clicky.opt, enabled=clicky.enabled})
        end
    end
    self.petWeapons = settings.petWeapons or nil
    if settings.BYOSCustom then
        self.customRotationTemp = {}
        for i,spellGroup in ipairs(settings.BYOSCustom) do
            self.customRotationTemp[i] = spellGroup
        end
    end
    self.customAbilities = settings.customAbilities or {}
    self.customOptions = settings.customOptions or {}
end

function base:saveSettings()
    local optValues = {}
    for name,options in pairs(self.options) do optValues[name] = options.value end
    local byos = {}
    if self.customRotation then for i,spell in ipairs(self.customRotation) do byos[i] = spell.SpellGroup end end
    mq.pickle(config.SETTINGS_FILE, {common=config.getAll(), [self.class]=optValues, clickies=self.clickies, petWeapons=self.petWeapons, BYOSCustom=byos, customAbilities=self.customAbilities, customOptions=self.customOptions})
end

function base:initBYOSCustom()
    if self.customRotationTemp then
        self.customRotation = {}
        for i,spellGroup in ipairs(self.customRotationTemp) do
            self.customRotation[i] = self.spells[spellGroup]
        end
        self.customRotationTemp = nil
    end
end

function base:assist()
    if common.amIDead() then return end
    if constants.DMZ[mq.TLO.Zone.ID()] or mq.TLO.Navigation.Active() then return end
    if mode.currentMode:isAssistMode() then
        assist.doAssist(self.resetClassTimers)
        --[[assist.fsm(state.resetCombatTimers)
        logger.debug(logger.flags.class.assist, "after check target "..tostring(state.assistMobID))
        -- Get assist target still even if medding, incase we need to do debuffs or anything more important
        if not state.medding or not config.get('MEDCOMBAT') then
            if self:isAbilityEnabled('USEMELEE') then
                if state.assistMobID and state.assistMobID > 0 and not mq.TLO.Me.Combat() and self.beforeEngage then
                    self.beforeEngage()
                end
                assist.attack()
            else
                assist.checkLOS()
            end
        end
        assist.sendPet()]]
    end
    if state.forceEngage then assist.sendPet() end
end

function base:tank()
    if constants.DMZ[mq.TLO.Zone.ID()] then return end
    if mode.currentMode:getName() == 'pullertank' and helpers.distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), camp.X, camp.Y) > (config.get('CAMPRADIUS')-5)^2 then
        state.pullStatus = constants.pullStates.RETURNING
        state.actionTaken = true
    else
        if not tank.findMobToTank() then assist.sendPet() return end
        if not tank.approachMob() then return end
        if not tank.acquireTarget() then return end
        if not tank.tankMob() then return end
        tank.stickToMob()
        assist.sendPet()
    end
end

function base:heal()
    if constants.healClasses[self.class] then
        healing.heal(self.healAbilities, self.options)
    elseif constants.petClasses[self.class] then
        healing.healPetOrSelf(self.healAbilities, self.options)
    else
        healing.healSelf(self.healAbilities, self.options)
    end
end

function base:cure()
    if mq.TLO.Me.SPA(15)() < 0 then
        if mq.TLO.Me.CountersCurse() > 0 then
            for _,cure in self.cures do
                if cure.curse or cure.all and cure:isReady() == abilities.IsReady.SHOULD_CAST then
                    if mq.TLO.Target.ID() ~= mq.TLO.Me.ID() then
                        mq.cmd('/squelch /mqtar')
                    end
                    cure:use()
                end
            end
        end
    end
    curing.doCures(self)
end

function base:doCombatLoop(list, burn_type)
    local target = mq.TLO.Target
    local dist = target.Distance3D() or 0
    local maxdist = target.MaxRangeTo() or 0
    local mobhp = target.PctHPs() or 100
    local aggropct = target.PctAggro() or 100
    for _,ability in ipairs(list) do
        if (ability.Name or ability.ID) and (self:isAbilityEnabled(ability.opt)) and
                (ability.threshold == nil or ability.threshold <= state.mobCountNoPets) and
                (ability.type ~= abilities.Types.Skill or dist < maxdist) and
                (ability.maxdistance == nil or dist <= ability.maxdistance) and
                (ability.usebelowpct == nil or mobhp <= ability.usebelowpct) and
                (burn_type == nil or ability[burn_type]) and
                (ability.aggro == nil or aggropct < 100) then
            if ability:use() then
                mq.delay(ability.delay or 200)
            end
        end
    end
end

-- Consumable clickies that are likely not present when AQO starts so don't add as item lookups, plus used for all classes
function base:doMashClickies()
    for _,clicky in ipairs(constants.ddClickies) do
        local clickyItem = mq.TLO.FindItem('='..clicky)
        if clickyItem() and clickyItem.Timer.TotalSeconds() == 0 and not mq.TLO.Me.Casting() then
            if mq.TLO.Cursor.Name() == clickyItem.Name() then
                mq.cmd('/autoinv')
                mq.delay(50)
                clickyItem = mq.TLO.FindItem('='..clicky)
            end
            if self.class == 'BRD' and mq.TLO.Me.Casting() then mq.cmd('/stopsong') mq.delay(1) end
            mq.cmdf('/useitem "%s"', clickyItem.Name())
            mq.delay(50)
            mq.delay(250, function() return not mq.TLO.Me.Casting() end)
        end
    end
end

function base:mash()
    if mq.TLO.Target.ID() == mq.TLO.Me.ID() then return end
    if state.medding and config.get('MEDCOMBAT') then return end
    if assist.isFighting() then
        if self.mashClass then self:mashClass() end
        if mode.currentMode:isTankMode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() or config.get('MAINTANK') then
            if self.useCommonListProcessor then
                common.processList(self.tankAbilities, self, false)--true)
            else
                self:doCombatLoop(self.tankAbilities)
            end
        end
        if self.useCommonListProcessor then
            common.processList(self.DPSAbilities, self, false)--true)
        else
            self:doCombatLoop(self.DPSAbilities)
        end
        if self.class ~= 'BRD' then self:doMashClickies() end
    end
end

function base:ae()
    if mq.TLO.Target.ID() == mq.TLO.Me.ID() then return end
    if state.medding and config.get('MEDCOMBAT') then return end
    if not self:isEnabled('USEAOE') then return end
    if assist.isFighting() then
        if mode.currentMode:isTankMode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() or config.get('MAINTANK') then
            if self.aeClass then self.aeClass() end
            if self.useCommonListProcessor then
                common.processList(self.AETankAbilities, self, false)--true)
            else
                self:doCombatLoop(self.AETankAbilities)
            end
        end
        if self.useCommonListProcessor then
            common.processList(self.AEDPSAbilities, self, false)--true)
        else
            self:doCombatLoop(self.AEDPSAbilities)
        end
    end
end

function base:burn()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag.
    -- Test them both for each item, and see which one(s) actually work.
    if mq.TLO.Target.ID() == mq.TLO.Me.ID() then return end
    if state.medding and config.get('MEDCOMBAT') then return end
    if self.doneSinging and not self:doneSinging() then return end
    if common.isBurnConditionMet() then
        if self.burnClass then self:burnClass() end

        if mode.currentMode:isTankMode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() or config.get('MAINTANK') then
            if self.useCommonListProcessor then
                common.processList(self.tankBurnAbilities, self, true)
            else
                self:doCombatLoop(self.tankBurnAbilities, state.burn_type)
            end
        end
        if self.useCommonListProcessor then
            common.processList(self.burnAbilities, self, true)
        else
            self:doCombatLoop(self.burnAbilities, state.burn_type)
        end
        if config.get('USEGLYPH') and self.intensity and self.glyph then
            if not mq.TLO.Me.Song(self.intensity.Name)() and mq.TLO.Me.Buff('heretic\'s twincast')() then
                self.glyph:use()
            end
        end
        if config.get('USEINTENSITY') and self.glyph and self.intensity then
            if not mq.TLO.Me.Buff(self.glyph.Name)() and mq.TLO.Me.Buff('heretic\'s twincast')() then
                self.intensity:use()
            end
        end
    end
end

function base:findNextSpell()
    -- alliance
    -- synergy
    local spellRotation = self:getSpellRotation()
    if not spellRotation then return nil end
    local startIndex = state.rotationIndex and state.rotationIndex < #spellRotation and state.rotationIndex + 1 or 1
    for i=startIndex,#spellRotation do
        local spell = spellRotation[i]
        local resistCount = state.resists[spell.Name] or 0
        local resistStopCount = config.get('RESISTSTOPCOUNT')
        if self:isAbilityEnabled(spell.opt) and spell:isReady() == abilities.IsReady.SHOULD_CAST
                and (resistStopCount == 0 or resistCount < resistStopCount)
                and (not spell.condition or spell.condition()) then
            return spell, i
        end
    end
    -- didn't find a next spell to cast, reset rotation
    state.rotationIndex = nil
end

function base:debuff()
    debuff.castDebuffs()
end

function base:cast()
    if mq.TLO.Me.SpellInCooldown() or self:isEnabled('DONTCAST') or mq.TLO.Me.Invis() then return end
    if state.medding and config.get('MEDCOMBAT') then return end
    if assist.isFighting() and mq.TLO.Target.ID() ~= mq.TLO.Me.ID() then
        if state.nuketimer:expired() then
            for _,clicky in ipairs(self.castClickies) do
                if clicky.enabled and self:isAbilityEnabled(clicky.opt) and (clicky.DurationTotalSeconds == 0 or not mq.TLO.Target.Buff(clicky.CheckFor)()) and not mq.TLO.Me.Moving() then
                    if clicky:use() then return end
                end
            end
            local spell, index = self:findNextSpell()
            if spell then -- if a dot was found
                if spell.precast then spell.precast() end
                if spell:use(true) then
                    state.rotationIndex = index
                    state.actionTaken = true
                else
                    state.rotationIndex = nil
                end -- then cast the dot
                state.nuketimer:reset()
                mq.doevents()--'eventResist')
                if spell.postcast then spell.postcast() end
            end
        end
        -- nec multi dot stuff
        if self:isEnabled('MULTIDOT') then
            local original_target_id = 0
            if mq.TLO.Target.Type() == 'NPC' then original_target_id = mq.TLO.Target.ID() end
            local dotted_count = 1
            for i=1,20 do
                if mq.TLO.Me.XTarget(i).TargetType() == 'Auto Hater' and mq.TLO.Me.XTarget(i).Type() == 'NPC' then
                    local xtar_id = mq.TLO.Me.XTarget(i).ID()
                    local xtar_spawn = mq.TLO.Spawn(xtar_id)
                    if xtar_id ~= original_target_id and assist.shouldAssist(xtar_spawn) then
                        xtar_spawn.DoTarget()
                        -- TODO: multidotting needs rework for OnPulse style...
                        mq.delay(2000, function() return mq.TLO.Target.ID() == xtar_id and not mq.TLO.Me.SpellInCooldown() end)
                        local spell = self:findNextSpell() -- find the first available dot to cast that is missing from the target
                        if spell and not mq.TLO.Target.Mezzed() then -- if a dot was found
                            spell:use(true)
                            state.actionTaken = true
                            dotted_count = dotted_count + 1
                            if dotted_count >= self:get('MULTICOUNT') then break end
                        end
                    end
                end
            end
            if original_target_id ~= 0 and mq.TLO.Target.ID() ~= original_target_id then
                mq.cmdf('/squelch /mqtar id %s', original_target_id)
            end
        end
    end
end

function base:buff()
    if common.amIDead() then return end
    if self.doneSinging and not self:doneSinging() then return end
    if state.medding and config.get('MEDCOMBAT') then return end
    if buffing.buff(self) then state.actionTaken = true end
end

function base:wantBuffs()
    local wanted = constants.buffs[mq.TLO.Me.Class.ShortName()]
    local request = {}
    for _,buff in ipairs(wanted) do
        for name, charState in pairs(state.actors) do
            local availableBuffs = charState.availableBuffs
            if availableBuffs then
                if availableBuffs[buff] then
                    if (not mq.TLO.Me.Buff(availableBuffs[buff])() or (mq.TLO.Me.Buff(availableBuffs[buff]).Duration() or 0) < 60000)
                            and (mq.TLO.Spell(availableBuffs[buff]).WillLand() or 0) > 0 then
                        table.insert(request, buff)
                    end
                end
            end
        end
    end
    return request
end

function base:rest()
    common.rest()
end

function base:mez()
    -- don't try to mez in manual mode
    if mode.currentMode:isManualMode() or mode.currentMode:isTankMode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() or config.get('MAINTANK') then return end
    if self:isEnabled('MEZAE') and self.spells.mezae then
        if mez.doAE(self.spells.mezae, self:get('MEZAECOUNT')) then state.actionTaken = true end
    end
    if self:isEnabled('MEZST') and self.spells.mezst then
        if mez.doSingle(self.spells.mezst) then state.actionTaken = true end
    end
end

function base:aggro()
    if mode.currentMode:isTankMode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() or config.get('MAINTANK') or mode.currentMode:isManualMode() then return end
    local pctAggro = mq.TLO.Me.PctAggro() or 0
    -- 1. Am i on aggro? Use fades or defensives immediately
    if mq.TLO.Target() and mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID() and mq.TLO.Target.Named() then
        local useDefensives = true
        if self.useCommonListProcessor then
            if common.processList(self.fadeAbilities, self, true) then return
                -- if mq.TLO.Me.TargetOfTarget.ID() ~= mq.TLO.Me.ID() then
                --     useDefensives = false
                -- end
            end
            if useDefensives then
                if common.processList(self.defensiveAbilities, self, true) then return end
            end
        else
            for _,ability in ipairs(self.fadeAbilities) do
                if self:isAbilityEnabled(ability.opt) then
                    if ability.precast then ability.precast() end
                    ability:use()
                    if ability.postcast then ability.postcast() end
                    if mq.TLO.Me.TargetOfTarget.ID() ~= mq.TLO.Me.ID() then
                        -- No longer on aggro, skip popping defensives
                        useDefensives = false
                        break
                    end
                end
            end
            if useDefensives then
                -- Didn't lose aggro from fade abilities, hit defensives
                for _,ability in ipairs(self.defensiveAbilities) do
                    if self:isAbilityEnabled(ability.opt) then
                        if ability.precast then ability.precast() end
                        ability:use()
                        if ability.postcast then ability.postcast() end
                    end
                end
            end
        end
    end
    -- 2. Is my aggro above some threshold? Use aggro reduction abilities
    if mq.TLO.Target() and pctAggro >= 70 and mq.TLO.Target.Named() then
        if self.useCommonListProcessor then
            if common.processList(self.aggroReducers, self, true) then return end
        else
            for _,ability in ipairs(self.aggroReducers) do
                if self:isAbilityEnabled(ability.opt) then
                    if ability.precast then ability.precast() end
                    ability:use()
                    if ability.postcast then ability.postcast() end
                end
            end
        end
        if self.aggroClass then self:aggroClass() end
    end
end

function base:ohshit()
    if self.ohShitClass then self:ohShitClass() end
end

function base:recover()
    if common.amIDead() then return end
    if constants.DMZ[mq.TLO.Zone.ID()] or (mq.TLO.Me.Level() == 70 and mq.TLO.Me.MaxHPs() < 6000) or mq.TLO.Me.Buff('Resurrection Sickness')() then return end
    if self.recoverClass then self:recoverClass() end
    -- modrods
    common.checkMana()
    local pct_hp = mq.TLO.Me.PctHPs()
    local pct_mana = mq.TLO.Me.PctMana()
    local pct_end = mq.TLO.Me.PctEndurance()
    local combat_state = mq.TLO.Me.CombatState()
    local useAbility = nil
    if self.useCommonListProcessor then
        common.processList(self.recoverAbilities, self, true)
    else
        for _,ability in ipairs(self.recoverAbilities) do
            if self:isAbilityEnabled(ability.opt) and (not ability.nodmz or not constants.DMZ[mq.TLO.Zone.ID()]) then
                if ability.mana and pct_mana < (ability.threshold or config.get('RECOVERPCT')) and (ability.combat or combat_state ~= 'COMBAT') and (not ability.minhp or mq.TLO.Me.PctHPs() > ability.minhp) and (ability.ooc or mq.TLO.Me.CombatState() == 'COMBAT') then
                    useAbility = ability
                    break
                elseif ability.endurance and pct_end < (ability.threshold or config.get('RECOVERPCT')) and (ability.combat or combat_state ~= 'COMBAT') and (not ability.minhp or mq.TLO.Me.PctHPs() > ability.minhp) then
                    useAbility = ability
                    break
                end
            end
        end
        if useAbility and useAbility:isReady() == abilities.IsReady.SHOULD_CAST then
            if mq.TLO.Me.MaxHPs() < 6000 then return end
            local originalTargetID = 0
            if useAbility.TargetType == 'Single' and mq.TLO.Target.ID() ~= mq.TLO.Me.ID() then
                originalTargetID = mq.TLO.Target.ID()
                mq.TLO.Me.DoTarget()
            end
            if useAbility:use() then state.actionTaken = true end
            if originalTargetID > 0 then mq.cmdf('/squelch /mqtar id %s', originalTargetID) else mq.cmd('/squelch /mqtar clear') end
        end
    end
end

function base:rez()
    if healing.rez(self.rezAbility) then state.actionTaken = true end
end

function base:managepet()
    local petSpell = self.getPetSpell and self:getPetSpell() or self.spells.pet
    if not self:isEnabled('SUMMONPET') or not petSpell then return end
    if not common.clearToBuff() or mq.TLO.Pet.ID() > 0 or mq.TLO.Me.Moving() then return end
    if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.get('CAMPRADIUS')))() > 0 then return end
    if petSpell.Mana > mq.TLO.Me.CurrentMana() then return end
    if petSpell.ReagentID and mq.TLO.FindItemCount(petSpell.ReagentID)() < petSpell.ReagentCount then return end
    abilities.swapAndCast(petSpell, state.swapGem, self)
    state.queuedAction = function() mq.cmd('/pet ghold on') end
end

function base:hold()

end

function base:nowCast(args)
    if #args == 3 then
        local sendTo = args[1]:lower()
        local alias = args[2]:upper()
        local target = args[3]:lower()
        if sendTo == 'me' or sendTo == mq.TLO.Me.CleanName():lower() then
            local spellToCast = self.spells[base:getAbilityForAlias(alias)] or self[alias:lower()]
            table.insert(self.requests, {requester=target, requested=spellToCast, expiration=timer:new(15000), tranquil=false, mgb=false})
        else
            local sendToSpawn = mq.TLO.Spawn('pc ='..sendTo)
            if sendToSpawn() then
                -- sendToSpawn.Class.ShortName(),  why did i have this here
                mq.cmdf('/squelch /dex %s /nowcast "%s" %s', sendTo, alias, target)
            end
        end
    elseif #args == 2 then
        local alias = args[1]:upper()
        local target = args[2]:lower()
        local spellToCast = self.spells[base:getAbilityForAlias(alias)] or self[alias:lower()]
        if spellToCast then
            table.insert(self.requests, {requester=target, requested=spellToCast, expiration=timer:new(15000), tranquil=false, mgb=false})
        end
    end
end

function base:handleRequests()
    if #self.requests > 0 then
        local request = self.requests[1]
        if request.expiration:expired() then
            logger.info('Request timer expired for \ag%s\ax from \at%s\at', request.requested.Name, request.requester)
            table.remove(self.requests, 1)
        else
            local requesterSpawn = '='..request.requester
            if tonumber(request.requester) then
                requesterSpawn = 'id '..request.requester
            end
            local requesterSpawn = mq.TLO.Spawn(requesterSpawn)
            if (requesterSpawn.Distance3D() or 300) < 100 then
                if request.requested == 'ARMPET' and state.class == 'MAG' then
                    self:armPetRequest(request.requester)
                    table.remove(self.requests, 1)
                    return
                end
                local restoreGem
                if request.requested.CastType == abilities.Types.Spell and not mq.TLO.Me.Gem(request.requested.Name)() then
                    restoreGem = {Name=mq.TLO.Me.Gem(state.swapGem)()}
                    abilities.swapSpell(request.requested, state.swapGem, true)
                    mq.delay(30000, function() return mq.TLO.Me.SpellReady(request.requested.Name)() end)
                end
                if abilities.canUseSpell(mq.TLO.Spell(request.requested.SpellName), request.requested) == abilities.IsReady.CAN_CAST then
                    local tranquilUsed = '/dgt all Casting'
                    if request.tranquil then
                        if (not mq.TLO.Me.AltAbilityReady('Tranquil Blessings')() or mq.TLO.Me.CombatState() == 'COMBAT') then
                            return
                        elseif self.tranquil and mq.TLO.Me.AltAbilityReady('Tranquil Blessings')() then
                            --if self.tranquil:use() then tranquilUsed = '/rs MGB\'ing' end
                            mq.cmdf('/alt act %s', self.tranquil.ID)
                            tranquilUsed = '/rs MGB\'ing'
                        end
                    elseif request.mgb then
                        if not mq.TLO.Me.AltAbilityReady('Mass Group Buff')() then
                            return
                        elseif self.mgb then
                            if self.mgb:use() then tranquilUsed = '/rs MGB\'ing' end
                        end
                    end
                    movement.stop()
                    if request.requested.TargetType == 'Single' then
                        requesterSpawn.DoTarget()
                    end
                    mq.cmdf('%s %s for %s', tranquilUsed, request.requested.Name, request.requester)
                    request.requested:use(true)
                    table.remove(self.requests, 1)
                end
                if restoreGem then
                    abilities.swapSpell(restoreGem, state.swapGem)
                end
            end
        end
    end
end

local function lifesupport()
    if mq.TLO.Me.CombatState() == 'COMBAT' and not mq.TLO.Me.Invis() and not mq.TLO.Me.Casting() and mq.TLO.Me.Standing() and mq.TLO.Me.PctHPs() < 60 then
        for _,healclicky in ipairs(constants.instantHealClickies) do
            local item = mq.TLO.FindItem(healclicky)
            local spell = item.Clicky.Spell
            if item() and mq.TLO.Me.ItemReady(healclicky)() and (spell.Duration.TotalSeconds() == 0 or (not mq.TLO.Me.Song(spell.Name())()) and mq.TLO.Spell(spell.Name()).Stacks()) then
                logger.info('Use Item: \ag%s\ax', healclicky)
                local castTime = item.CastTime()
                mq.cmdf('/useitem "%s"', healclicky)
                mq.delay(250+(castTime or 0), function() return not mq.TLO.Me.ItemReady(healclicky)() end)
                if mq.TLO.Me.PctHPs() > 75 then return end
            end
        end
    end
end

local function findSpellForSlot(slot)
    local spell = nil
    local spellFallback = nil
    for _, spellInfo in pairs(base.spells) do
        local gem = spellInfo.Gem
        if type(gem) == 'function' then gem = gem() end
        if gem == slot then
            if not spellInfo.opt and not spell then
                -- spell assigned to this gem with no related option, default spell for the gem
                spell = spellInfo
            elseif spellInfo.opt and base:isEnabled(spellInfo.opt) then
                if spell ~= nil then
                    -- spell assigned to this gem with an option, but we've already found one matching spell for this gem
                    if spell.opt then
                        -- the spell that was already found for this gem also has an associated option enabled, prioritize options or its a conflict
                        -- do nothing for now, keep the first spell we found
                    else
                        -- the spell that was already found for this gem was the default with no option, override it with this spell based on enabled option
                        spell = spellInfo
                    end
                else
                    -- spell assigned to this gem with an option, haven't found another spell for the gem yet
                    spell = spellInfo
                end
            else
                -- in case options were disabled and we had no default spell for the gem, mem whatever option based spell we find anyways
                spellFallback = spellInfo
            end
        end
    end
    return spell or spellFallback
end

function base:getSpellRotation()
    local spellSet = self:get('SPELLSET')
    if not self:isEnabled('BYOS') then
        if spellSet == 'custom' then spellSet = self.defaultSpellset or 'standard' end
        return self.spellRotations[spellSet]
    end
    if spellSet == 'custom' and self.customRotation and #self.customRotation > 1 then return self.customRotation end
    if self.allDPSSpellGroups and not state.rotationUpdated or state.rotationRefreshTimer:expired() then
        self.BYOSRotation = {}
        -- rebuild rotation based on mem'd spells and all available DPS spells in no particular order
        for _,spellGroup in ipairs(self.allDPSSpellGroups) do
            if self.spells[spellGroup] and mq.TLO.Me.Gem(self.spells[spellGroup].Name)() then table.insert(self.BYOSRotation, self.spells[spellGroup]) end
        end
        state.rotationUpdated = true
        state.rotationRefreshTimer:reset()
    end
    return self.BYOSRotation
end

base.checkSpellTimer = timer:new(30000)
function base:checkMemmedSpells()
    if not mq.TLO.Me.Class.CanCast() or not self.spells or not common.clearToBuff() or mq.TLO.Me.Moving() or self:isEnabled('BYOS') or state.memSpell or state.restore_gem then return end
    local spellSet = self:get('SPELLSET')
    if state.spellSetLoaded ~= spellSet or self.checkSpellTimer:expired() then
        local numGems = mq.TLO.Me.NumGems() or 8
        for i=1,numGems do
            local spellToMem = findSpellForSlot(i)
            if spellToMem and mq.TLO.Me.Gem(i).BaseName() ~= spellToMem.BaseName then
                if self.compositeNames[spellToMem.BaseName] then
                    if abilities.swapSpell(spellToMem, i, false, self.compositeNames) then return end
                else
                    if abilities.swapSpell(spellToMem, i) then return end
                end
            end
        end
        state.spellSetLoaded = spellSet
        self.checkSpellTimer:reset()
    end
end

function base:useEpic()
    mq.delay(5000, function() return not mq.TLO.Me.Casting() end)
    if self.epic and mq.TLO.Me.ItemReady(self.epic)() then
        mq.cmdf('/useitem "%s"', self.epic)
    end
end

function base:mainLoop()
    if config.get('LOOTMOBS') and state.assistMobID > 0 and not state.lootBeforePull then
        -- some attempt at forcing a round of looting before beginning another pull,
        -- otherwise, depending where we are in the loop when a mob dies, we might go
        -- directly into another pull before trying to loot what we just killed.
        state.lootBeforePull = true
    end
    if not state.pullStatus or state.pullStatus == constants.pullStates.PULLED then
        if state.pullStatus == constants.pullStates.PULLED then pull.clearPullVars('classloop') end
        lifesupport()
        self:handleRequests()
        -- get mobs in camp
        camp.mobRadar()
        if mode.currentMode:isTankMode() then
            self:tank()
            -- tank check may determine pull return interrupted / ended early for some reason, and put us back
            -- into pull return to try to get back to camp
            if state.pullStatus then return end
        end
        if self.checkSpellSet then self:checkSpellSet() else self:checkMemmedSpells() end
        if not self:hold() then
            for _,routine in ipairs(self.classOrder) do
                if not state.actionTaken then self[routine](self) end
                -- handling for primarily necro in combat spell swaps
                if routine == 'cast' and not state.actionTaken and self.swapSpells then
                    self:swapSpells()
                end
            end
        end
        -- check whether we need to return to camp, only while not assisting
        if not state.assistMobID or state.assistMobID == 0 then camp.checkCamp() end
        -- check whether we need to go chasing after the chase target, may happen while fighting
        common.checkChase()
    end
    if not state.actionTaken and not state.medding and mode.currentMode:isPullMode() and not self:hold() and not state.lootBeforePull then
        pull.pullMob()
    end
end

return base
