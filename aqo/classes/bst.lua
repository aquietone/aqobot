---@type Mq
local mq = require('mq')
local class = require('classes.classbase')
local config = require('interface.configuration')
local conditions = require('routines.conditions')
local constants = require('constants')
local common = require('common')
local state = require('state')

local BeastLord = class:new()

--[[
    https://forums.daybreakgames.com/eq/index.php?threads/dear-beastlord-mains.281024/
    https://forums.daybreakgames.com/eq/index.php?threads/beastlord-raiding-guide.246364/
    http://forums.eqfreelance.net/index.php?topic=9390.0
    
    Fade - 
    Falsified Death (aa)

    Pet Buffs
    'Magna\'s Aggression', 'Panthea\'s Aggression', 'Horasug's Aggression', 'Virzak\'s Aggression', 'Sekmoset\'s Aggression'
    'Cohort\'s Unity', 'Comrade\'s Unity', 'Ally's Unity', 'Companion\'s Unity'
    Spiritcaller Totem (epic)
    Hobble of Spirits (snare aa buff)
    Companion's Aegis (aa)
    Taste of Blood (aa)
    Companion's Intervening Divine Aura (aa)
    Sympathetic Warder

    Buffs
    'Wildfang\'s Unity', 'Chieftain\'s Unity', 'Reclaimer\'s Unity', 'Feralist\'s Unity', 'Stormblood\'s Unity'
]]
--[[
    spirit of rashara
    ancient: savage ice
    growl of the beast
    muada's mending
    chimera blood
    ferocity of irionu
    spiritual rejuvination
    glacier spear
    sha's legacy
    reptilian venom
    growl of the panther
    spirit of oroshar
]]
function BeastLord:init()
    self.classOrder = {'assist', 'aggro', 'cast', 'mash', 'burn', 'heal', 'recover', 'buff', 'rest', 'managepet', 'rez'}
    self.spellRotations = {standard={}}
    self:initBase('bst')

    self:initClassOptions()
    self:loadSettings()
    self:initSpellLines()
    self:initSpellRotations()
    self:initDPSAbilities()
    self:initBurns()
    self:initHeals()
    self:initBuffs()
    self:initDefensiveAbilities()
    self:initRecoverAbilities()
    self:addCommonAbilities()

    self.useCommonListProcessor = true
end

function BeastLord:initClassOptions()
    self:addOption('USENUKES', 'Use Nukes', true, nil, 'Toggle use of nukes', 'checkbox', nil, 'UseNukes', 'bool')
    self:addOption('USEFOCUSEDPARAGON', 'Use Focused Paragon (Self)', true, nil, 'Toggle use of Focused Paragon of Spirits', 'checkbox', nil, 'UseFocusedParagon', 'bool')
    self:addOption('PARAGONOTHERS', 'Use Focused Paragon (Group)', true, nil, 'Toggle use of Focused Paragon of Spirits on others', 'checkbox', nil, 'ParagonOthers', 'bool')
    self:addOption('USEPARAGON', 'Use Group Paragon', false, nil, 'Toggle use of Paragon of Spirit', 'checkbox', nil, 'UseParagon', 'bool')
    self:addOption('USEDOTS', 'Use DoTs', false, nil, 'Toggle use of DoTs', 'checkbox', nil, 'UseDoTs', 'bool')
    self:addOption('USEFD', 'Feign Death', true, nil, 'Use FD AA\'s to reduce aggro', 'checkbox', nil, 'UseFD', 'bool')
    self:addOption('USESLOW', 'Use Slow', false, nil, 'Toggle casting slow on mobs', 'checkbox', nil, 'UseSlow', 'bool')
end

function BeastLord:initSpellLines()
    if state.emu then
        self:addSpell('pet', {'Spirit of Rashara', 'Spirit of Alladnu', 'Spirit of Sorsha'}, {opt='SUMMONPET'}) -- pet
        self:addSpell('pethaste',{'Growl of the Beast', 'Arag\'s Celerity'}, {swap=true}) -- pet haste
        self:addSpell('petbuff', {'Spirit of Oroshar', 'Spirit of Rellic'}, {swap=true}) -- pet buff
        self:addSpell('petheal', {'Healing of Mikkity', 'Healing of Sorsha'}, {opt='HEALPET', pet=50}) -- pet heal
        self:addSpell('nuke', {'Ancient: Savage Ice', 'Glacier Spear', 'Trushar\'s Frost'}, {opt='USENUKES'})
        self:addSpell('nuke2', {'Glacier Spear'}, {opt='USENUKES'})
        self:addSpell('heal', {'Trushar\'s Mending'}, {me=75, self=true}) -- heal
        self:addSpell('fero', {'Ferocity of Irionu', 'Ferocity'}, {classes={WAR=true,MNK=true,BER=true,ROG=true}}) -- like shm avatar
        self:addSpell('feralvigor', {'Feral Vigor'}, {classes={WAR=true,SHD=true,PAL=true}}) -- like shm avatar
        self:addSpell('panther', {'Growl of the Panther'}, {skipifbuff='Wild Spirit Infusion'})
        self:addSpell('groupregen', {'Spiritual Rejuvenation', 'Spiritual Ascendance', 'Feral Vigor', 'Spiritual Vigor'}, {swap=true}) -- group buff
        self:addSpell('grouphp', {'Spiritual Vitality'}, {swap=true})
        self:addSpell('dot', {'Chimera Blood'}, {opt='USEDOTS'})
        if self.spells.dot then self.spells.dot.condition = function() return state.burnActive end end
        self:addSpell('swarmpet', {'Reptilian Venom'}, {delay=1500})
        self:addSpell('slow', {'Sha\'s Legacy'}, {opt='USESLOW'})
    else
        --Spells(Group)
        self:addSpell('pet', {'Spirit of Shae', 'Spirit of Panthea', 'Spirit of Blizzent', 'Spirit of Akalit', 'Spirit of Avalit'})
        self:addSpell('nuke1', {'Rimeclaw\'s Maelstrom', 'Va Xakra\'s Maelstrom', 'Vkjen\'s Maelstrom', 'Beramos\' Maelstrom', 'Visoracius\' Maelstrom'}) -- (DD)
        self:addSpell('nuke2', {'Mortimus\' Bite', 'Zelniak\'s Bite', 'Bloodmaw\'s Bite', 'Mawmun\'s Bite', 'Kreig\'s Bite'}) -- (DD)
        self:addSpell('nuke3', {'Frozen Creep', 'Frozen Blight', 'Frozen Malignance', 'Frozen Toxin', 'Frozen Miasma'}) -- (DD)
        self:addSpell('nuke4', {'Ankexfen Lance', 'Crystalline Lance', 'Restless Lance', 'Frostbite Lance', 'Kromtus Lance'}) -- (DD) / Restless Roar (AE DD)
        self:addSpell('nuke5', {'Crystalline Lance', 'Restless Lance', 'Frostbite Lance', 'Kromtus Lance'}) -- (DD)
        self:addSpell('dddot1', {'Lazam\'s Chill', 'Sylra Fris\' Chill', 'Endaroky\'s Chill', 'Ekron\'s Chill', 'Kirchen\'s Chill'}) -- (DD DoT)
        self:addSpell('dot1', {'Fevered Endemic', 'Vampyric Endemic', 'Neemzaq\'s Endemic', 'Elkikatar\'s Endemic', 'Hemocoraxius\' Endemic'}) -- (DoT)
        self:addSpell('dddot2', {'Forgebound Blood', 'Akhevan Blood', 'Ikatiar\'s Blood', 'Polybiad Blood', 'Glistenwing Blood'}) -- (DD DoT)
        self:addSpell('combatbuff', {'Growl of Yasil', 'Growl of the Clouded Leopard', 'Growl of the Lioness', 'Growl of the Sabertooth', 'Growl of the Leopard'}) -- (self buff) / Griklor's Feralgia (self buff/swarm pet)
        self:addSpell('composite', {'Ecliptic Fury', 'Composite Fury', 'Dissident Fury'}) --
        self:addSpell('petrune', {'Auspice of Valia', 'Auspice of Kildrukaun', 'Auspice of Esianti', 'Auspice of Eternity'}) -- (pet rune) / Sympathetic Warder (pet healproc)
        self:addSpell('petheal', {'Salve of Homer', 'Salve of Jaegir', 'Salve of Tobart', 'Salve of Artikla', 'Salve of Clorith'}) -- (Pet heal)
        self:addSpell('heal', {'Thornhost\'s Mending', 'Korah\'s Mending', 'Bethun\'s Mending', 'Deltro\'s Mending', 'Sabhattin\'s Mending'}) -- (Player heal) / Salve of Artikla (Pet heal)

        --Spells(Raid)
        -- self:addSpell('nuke1', {'Rimeclaw\'s Maelstrom', 'Va Xakra\'s Maelstrom', 'Vkjen\'s Maelstrom', 'Beramos\' Maelstrom', 'Visoracius\' Maelstrom'}) -- (DD)
        -- self:addSpell('nuke2', {'Mortimus\' Bite', 'Zelniak\'s Bite', 'Bloodmaw\'s Bite', 'Mawmun\'s Bite', 'Kreig\'s Bite'}) -- (DD)
        -- self:addSpell('nuke3', {'Frozen Creep', 'Frozen Blight', 'Frozen Malignance', 'Frozen Toxin', 'Frozen Miasma'}) -- (DD)
        -- self:addSpell('nuke4', {'Ankexfen Lance', 'Crystalline Lance', 'Restless Lance', 'Frostbite Lance', 'Kromtus Lance'}) -- (DD) / Restless Roar (AE DD)
        -- self:addSpell('nuke5', {'Crystalline Lance', 'Restless Lance', 'Frostbite Lance', 'Kromtus Lance'}) -- (DD)
        -- self:addSpell('dddot1', {'Lazam\'s Chill', 'Sylra Fris\' Chill', 'Endaroky\'s Chill', 'Ekron\'s Chill', 'Kirchen\'s Chill'}) -- (DD DoT)
        -- self:addSpell('dot1', {'Fevered Endemic', 'Vampyric Endemic', 'Neemzaq\'s Endemic', 'Elkikatar\'s Endemic', 'Hemocoraxius\' Endemic'}) -- (DoT)
        -- self:addSpell('dddot2', {'Forgebound Blood', 'Akhevan Blood', 'Ikatiar\'s Blood', 'Polybiad Blood', 'Glistenwing Blood'}) -- (DD DoT)
        -- self:addSpell('combatbuff', {'Growl of Yasil', 'Growl of the Clouded Leopard', 'Growl of the Lioness', 'Growl of the Sabertooth', 'Growl of the Leopard'}) -- (self buff) / Griklor's Feralgia (self buff/swarm pet)
        -- self:addSpell('composite', {'Ecliptic Fury', 'Composite Fury', 'Dissident Fury'}) --
        self:addSpell('alliance', {'Venpmous Conjunction', 'Venomous Coalition', 'Venomous Covenant', 'Venomous Alliance'}) --
        -- self:addSpell('petheal', {'Salve of Homer', 'Salve of Jaegir', 'Salve of Tobart', 'Salve of Artikla', 'Salve of Clorith'}) -- (Pet heal)
        -- self:addSpell('heal', {'Thornhost\'s Mending', 'Korah\'s Mending', 'Bethun\'s Mending', 'Deltro\'s Mending', 'Sabhattin\'s Mending'}) -- (Player heal) / Salve of Artikla (Pet heal)
    end
end

function BeastLord:initSpellRotations()
    if state.emu then
        table.insert(self.spellRotations.standard, self.spells.swarmpet)
        table.insert(self.spellRotations.standard, self.spells.dot)
        table.insert(self.spellRotations.standard, self.spells.nuke)
        table.insert(self.spellRotations.standard, self.spells.nuke2)
    else
        --Spell Spam Lineup
        table.insert(self.spellRotations.standard, self.spells.nuke1)
        table.insert(self.spellRotations.standard, self.spells.nuke2)
        table.insert(self.spellRotations.standard, self.spells.nuke3)
        table.insert(self.spellRotations.standard, self.spells.nuke4)
        table.insert(self.spellRotations.standard, self.spells.nuke5)
        table.insert(self.spellRotations.standard, self.spells.dddot1) -- or dddot2
    end
end

function BeastLord:initDPSAbilities()
    if state.emu then
        table.insert(self.DPSAbilities, common.getSkill('Kick', {conditions=conditions.withinMeleeDistance}))
        table.insert(self.DPSAbilities, common.getBestDisc({'Rake', {conditions=conditions.withinMeleeDistance}}))
        table.insert(self.DPSAbilities, common.getAA('Feral Swipe', {conditions=conditions.withinMeleeDistance}))
        table.insert(self.DPSAbilities, common.getAA('Chameleon Strike', {conditions=conditions.withinMeleeDistance}))
        table.insert(self.DPSAbilities, common.getAA('Bite of the Asp', {conditions=conditions.withinMeleeDistance}))
        table.insert(self.DPSAbilities, common.getAA('Roar of Thunder', {conditions=conditions.withinMeleeDistance}))
        table.insert(self.DPSAbilities, common.getAA('Gorilla Smash', {conditions=conditions.withinMeleeDistance}))
        table.insert(self.DPSAbilities, common.getAA('Raven Claw', {conditions=conditions.withinMeleeDistance}))
    else
        --Melee Spam
        table.insert(self.DPSAbilities, common.getAA('Chameleon Strike')) -- (aggro reducer)
        table.insert(self.DPSAbilities, common.getBestDisc({'Focused Clamor of Claws'}))
        table.insert(self.AEDPSAbilities, common.getBestDisc({'Maelstrom of Claws'})) -- (AE)
        table.insert(self.DPSAbilities, common.getBestDisc({'Clobber', 'Batter'})) -- (synergy proc ability)
        table.insert(self.combatBuffs, common.getBestDisc({'Bestial Savagery'})) -- (self buff)
        table.insert(self.DPSAbilities, common.getSkill('Eagle\'s Strike')) -- (procs bite of the asp, /autoskill with round kick)
        table.insert(self.DPSAbilities, common.getSkill('Round Kick'))

        --Raid
        --Swap Eagle's Strike for Dragon Punch - procs gorilla  smash
        table.insert(self.DPSAbilities, common.getSkill('Dragon Punch'))
    end
    self.summonCompanion = common.getAA('Summon Companion')
end

function BeastLord:initBurns()
    if state.emu then
        table.insert(self.burnAbilities, common.getBestDisc({'Empathic Fury', 'Bestial Fury Discipline'}, {first=true})) -- burn disc
        table.insert(self.burnAbilities, common.getAA('Fundament: Third Spire of the Savage Lord', {first=true}))
        table.insert(self.burnAbilities, common.getAA('Frenzy of Spirit', {first=true}))
        table.insert(self.burnAbilities, common.getAA('Bestial Bloodrage', {first=true}))
        table.insert(self.burnAbilities, common.getAA('Group Bestial Alignment', {first=true}))
        table.insert(self.burnAbilities, common.getAA('Bestial Alignment', {first=true, skipifbuff='Group Bestial Alignment', condition=conditions.skipifbuff}))
        table.insert(self.burnAbilities, common.getAA('Attack of the Warders', {first=true, delay=1500}))
    else
        -- Main Burn
        table.insert(self.burnAbilities, common.getBestDisc({'Ikatiar\'s Vindication'}, {first=true})) -- (disc) - load dots and spam ikatiar's blood
        table.insert(self.burnAbilities, common.getAA('Frenzy of Spirit', {first=true})) -- (AA)
        table.insert(self.burnAbilities, common.getAA('Bloodlust', {first=true})) -- (AA)
        table.insert(self.burnAbilities, common.getAA('Bestial Alignment', {first=true})) -- (AA)
        table.insert(self.burnAbilities, common.getAA('Frenzied Swipes', {first=true})) -- (AA)
    
        -- Second Burn
        table.insert(self.burnAbilities, common.getBestDisc({'Savage Rancor'}, {second=true})) -- (disc)
        table.insert(self.burnAbilities, common.getAA('Spire of the Savage Lord', {second=true})) -- (AA)
        -- Fury of the Beast (chest click)
        table.insert(self.burnAbilities, common.getBestDisc({'Ruaabri\'s Fury'}, {second=true})) -- (disc)
    
        -- Third Burn
        --Bestial Bloodrage (Companion's Fury)
        table.insert(self.burnAbilities, common.getAA('Ferociousness', {third=true})) -- (AA)
        table.insert(self.burnAbilities, common.getAA('Group Bestial Alignment', {third=true})) -- (AA)
    
        -- Optional Burn
        --Dissident Fury
        --Forceful Rejuvination
        --Dissident Fury
    
        -- Other
        --Attack of the Warders
        --table.insert(self.burnAbilities, common.getBestDisc({'Reflexive Riving'})) -- (disc)
        --table.insert(self.burnAbilities, common.getAA('Enduring Frenzy')) -- (AA)
        --table.insert(self.burnAbilities, common.getAA('Roar of Thunder')) -- (AA)
    end
end

function BeastLord:initBuffs()
    local buffCondition = function(ability)
        return conditions.checkMana(ability) and conditions.missingBuff(ability)
    end
    if self.spells.groupregen then self.spells.groupregen.condition = buffCondition end
    if self.spells.grouphp then self.spells.grouphp.condition = buffCondition end
    --self.spells.fero.condition = buffCondition
    if self.spells.panther then self.spells.panther.condition = buffCondition end
    table.insert(self.selfBuffs, self.spells.groupregen)
    table.insert(self.selfBuffs, self.spells.grouphp)
    table.insert(self.selfBuffs, self.spells.fero)
    table.insert(self.selfBuffs, self.spells.panther)
    if state.emu then table.insert(self.selfBuffs, common.getAA('Gelid Rending')) end
    table.insert(self.selfBuffs, common.getAA('Pact of the Wurine'))
    table.insert(self.selfBuffs, common.getAA('Protection of the Warder'))

    if self.spells.fero then
        local singleBuffCondition = function(ability)
            return conditions.checkMana(ability)
        end
        self.spells.fero.condition = singleBuffCondition
    end
    table.insert(self.singleBuffs, self.spells.fero)
    table.insert(self.singleBuffs, self.spells.feralvigor)

    local petBuffCondition = function(ability)
        return conditions.checkMana(ability) and conditions.stacksPet(ability) and conditions.missingPetBuff(ability)
    end
    if self.spells.pethaste then self.spells.pethaste.condition = petBuffCondition end
    if self.spells.petbuff then self.spells.petbuff.condition = petBuffCondition end
    table.insert(self.petBuffs, self.spells.pethaste)
    table.insert(self.petBuffs, self.spells.petbuff)
    table.insert(self.petBuffs, common.getAA('Fortify Companion'))
    --local epicOpts = {CheckFor='Savage Wildcaller\'s Blessing', condition=conditions.missingPetCheckFor}
    local epicOpts = {CheckFor='Might of the Wild Spirits', condition=conditions.missingPetCheckFor}
    table.insert(self.petBuffs, common.getItem('Spiritcaller Totem of the Feral', epicOpts) or common.getItem('Savage Lord\'s Totem', epicOpts))
    table.insert(self.petBuffs, common.getAA('Taste of Blood', {CheckFor='Taste of Blood', condition=conditions.missingPetCheckFor}))

    self.paragon = common.getAA('Paragon of Spirit', {opt='USEPARAGON'})
    self.fParagon = common.getAA('Focused Paragon of Spirits', {opt='USEFOCUSEDPARAGON', mana=true, threshold=70, combat=true, endurance=false, minhp=20, ooc=true})
    self:addRequestAlias(self.fParagon, 'fparagon')
    self:addRequestAlias(self.paragon, 'paragon')
    self:addRequestAlias(self.spells.groupregen, 'rejuv')
end

function BeastLord:availableBuffs()
    self.spells.SV = self.spells.grouphp
    self.spells.SE = self.spells.groupregen
    return {SV=self.spells.grouphp and self.spells.grouphp.Name or nil, SE=self.spells.groupregen and self.spells.groupregen.Name or nil}
end

function BeastLord:initHeals()
    table.insert(self.healAbilities, self.spells.heal)
    table.insert(self.healAbilities, self.spells.petheal)
end

function BeastLord:initDefensiveAbilities()
    local postFD = function()
        mq.delay(1000)
        mq.cmd('/stand')
        mq.cmd('/makemevis')
    end
    table.insert(self.fadeAbilities, common.getAA('Playing Possum', {opt='USEFD', postcast=postFD}))
end

function BeastLord:initRecoverAbilities()
    if self.fParagon then
        self.fParagon.precast = function()
            mq.cmdf('/mqtar 0')
        end
        self.fParagon.condition = function(ability)
            return mq.TLO.Me.PctMana() <= config.get('RECOVERPCT')
        end
    end
    table.insert(self.recoverAbilities, self.fParagon)
end

function BeastLord:recoverClass()
    local lowmana = mq.TLO.Group.LowMana(50)() or 0
    local groupSize = mq.TLO.Group.Members() or 0
    local needEnd = 0
    if self:isEnabled('USEPARAGON') then
        for i=1,groupSize do
            if (mq.TLO.Group.Member(i).PctEndurance() or 100) < 50 then
                needEnd = needEnd + 1
            end
        end
        if (needEnd+lowmana) >= 3 and self.paragon:isReady() then
            self.paragon:use()
        end
    end
    local originalTargetID = mq.TLO.Target.ID()
    if self:isEnabled('PARAGONOTHERS') and self.fParagon then
        local groupSize = mq.TLO.Group.GroupSize()
        if groupSize then
            for i=1,groupSize do
                local member = mq.TLO.Group.Member(i)
                local memberPctMana = member.PctMana() or 100
                local memberDistance = member.Distance3D() or 300
                local memberClass = member.Class.ShortName() or 'WAR'
                if constants.manaClasses[memberClass:lower()] and memberPctMana < 70 and memberDistance < 100 and mq.TLO.Me.AltAbilityReady(self.fParagon.Name)() then
                    member.DoTarget()
                    self.fParagon:use()
                    if originalTargetID > 0 then mq.cmdf('/squelch /mqtar id %s', originalTargetID) else mq.cmd('/squelch /mqtar clear') end
                    return
                end
            end
        end
    end
end

return BeastLord
