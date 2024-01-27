---@type Mq
local mq = require('mq')
local class = require('classes.classbase')
local config = require('interface.configuration')
local conditions = require('routines.conditions')
local sharedabilities = require('utils.sharedabilities')
local timer = require('libaqo.timer')
local abilities = require('ability')
local constants = require('constants')
local common = require('common')
local state = require('state')

local BeastLord = class:new()

--[[
    https://forums.daybreakgames.com/eq/index.php?threads/dear-beastlord-mains.281024/
    https://forums.daybreakgames.com/eq/index.php?threads/beastlord-raiding-guide.246364/
    http://forums.eqfreelance.net/index.php?topic=9390.0
    
    Fade - Falsified Death (aa)

    Pet Buffs
    Spiritcaller Totem (epic)
    Hobble of Spirits (snare aa buff)
    Companion's Aegis (aa)
    Taste of Blood (aa)
    Companion's Intervening Divine Aura (aa)
    Sympathetic Warder
]]
function BeastLord:init()
    self.classOrder = {'assist', 'aggro', 'cast', 'recover', 'mash', 'burn', 'heal', 'buff', 'rest', 'managepet', 'rez'}
    self.spellRotations = {standard={},custom={}}
    self:initBase('BST')

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

    self.summonCompanion = common.getAA('Summon Companion')

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
    self:addOption('USESWARMPETS', 'Use Swarm Pets', true, nil, 'Toggle use of swarm pets', 'checkbox', nil, 'UseSwarmPets', 'bool')
    self:addOption('USEMENDING', 'Use Mending', false, nil, 'Toggle use of Mending line of heal spells', 'checkbox', nil, 'UseMending', 'bool')
    -- swarm pet, sow, snare, roar of thunder, mending, haste, focus
end
--[[
-- burn
common.getAA('Attack of the Warder') -- swarm pet 10 min cd, timer 41
common.getAA('Bestial Alignment') -- melee dmg burn 12 min cd, timer 7
common.getAA('Bloodlust') -- 42 seconds of 100% proc chance. 12 min cd, timer 76
common.getAA('Ferociousness') -- inc accuracy and melee dmg burn, 15 min cd, timer 80
common.getAA('Frenzied Swipes') -- reduced round kick cd for 1 min, 20 min cd, timer 11
common.getAA('Frenzy of Spirit') -- 1 min inc atk speed, reduced wep delay, inc atk power, 12 min cd, timer 4
common.getAA('Group Bestial Alignment') -- group melee dmg burn 12 min cd, timer 66
common.getAA('Spire of the Savage Lord') -- buffs self + pet dmg, buff group dmg + atk power, 7:30 cd, timer 40

-- mash
common.getAA('Chameleon Strike') -- mash ability aggro reducer, 20 second cd, timer 10
common.getAA('Roaring Strike') -- mash ability aggro increase, 20 second cd, timer 10
common.getAA('Enduring Frenzy') -- chance to proc +4k end on people attacking target, 5 min cd, timer 13
common.getAA('Roar of Thunder') -- 40k dd, reduce aggro, debuff target, 4:30 cd, timer 8

-- pet buffs
common.getAA('Taste of Blood') -- pet buff, proc blood frenzy on killing blows, inc flurry
common.getAA('Feralist\'s Unity') -- pet buff, casts symbiotic alliance, dmg absorb + hot on fade
common.getAA('Hobble of Spirits') -- pet buff proc snares

-- buffs
common.getAA('Pact of the Wurine') -- perma self buff, inc accuracy, movement speed, max mana, max hp and mana regen

-- defensive
common.getAA('Companion\'s Shielding') -- large pet heal + 72 seconds of 50% dmg absorb for self, 14 min cd, timer 73
common.getAA('Protection of the Warder') -- 35% melee dmg absorb, 15 min cd, timer 63

-- rest
common.getAA('Consumption of Spirit') -- 60k hp for 35k mana, 3 min cd, timer 52
common.getAA('Focused Paragon of Spirits') -- targeted mana/end regen
common.getAA('Paragon of Spirit') -- group mana/end regen

-- cures
common.getAA('Nature\'s Salve') -- cure self + pet, 1 min cd, timer 54

-- heals
common.getAA('Warder\'s Gift') -- 15% pet hp for 70k self heal, 2:30 cd, timer 74

-- spell replacements
common.getAA('Sha\'s Reprisal') -- aa slow

-- leap
common.getAA('Cheetah\'s Pounce') -- 20 sec cd, timer 68

common.getAA('Combat Subtlety')
common.getAA('Companion\'s Aegis')
common.getAA('Companion\'s Discipline')
common.getAA('Companion\'s Fortification')
common.getAA('Companion\'s Fury')
common.getAA('Companion\'s Intervening Divine Aura')
common.getAA('Companion\'s Suspension')
common.getAA('Diminutive Companion')
common.getAA('Falsified Death')
common.getAA('Forceful Rejuvenation')
common.getAA('Group Shrink')
common.getAA('Improved Natural Invisibility')
common.getAA('Mass Group Buff')
common.getAA('Mend Companion')
common.getAA('Natural Invisibility')
common.getAA('Perfected Levitation')
common.getAA('Playing Possum')
common.getAA('Shrink')
common.getAA('Summon Companion')
common.getAA('Tranquil Blessings')]]

BeastLord.SpellLines = {
    {-- DD. Slot 1
        Group='nuke1',
        Spells={'Rimeclaw\'s Maelstrom', 'Va Xakra\'s Maelstrom', 'Vkjen\'s Maelstrom', 'Beramos\' Maelstrom', 'Visoracius\' Maelstrom', --[[emu cutoff]] 'Ancient: Savage Ice', 'Glacier Spear', 'Trushar\'s Frost'},
        Options={opt='USENUKES', Gem=1}
    },
    {-- DD. Slot 2
        Group='nuke2',
        Spells={'Mortimus\' Bite', 'Zelniak\'s Bite', 'Bloodmaw\'s Bite', 'Mawmun\'s Bite', 'Kreig\'s Bite', --[[emu cutoff]] },
        Options={opt='USENUKES', Gem=2}
    },
    {-- DD. Slot 3
        Group='nuke3',
        Spells={'Frozen Creep', 'Frozen Blight', 'Frozen Malignance', 'Frozen Toxin', 'Frozen Miasma', --[[emu cutoff]] },
        Options={opt='USENUKES', Gem=3}
    },
    {-- DD. Slot 4,5
        Group='lance',
        NumToPick=2,
        Spells={'Ankexfen Lance', 'Crystalline Lance', 'Restless Lance', 'Frostbite Lance', 'Kromtus Lance', 'Glacier Spear', --[[emu cutoff]] },
        Options={opt='USENUKES', Gems={4,5}}
    },
    {-- AOE DD
        Group='roar',
        Spells={'Hoarfrost Roar', 'Polar Roar', 'Restless Roar', 'Frostbite Roar', 'Kromtus Roar', --[[emu cutoff]] },
        Options={opt='USEAOE', Gem=5}
    },
    {-- DD DoT. Slot 6
        Group='dddot1',
        Spells={'Lazam\'s Chill', 'Sylra Fris\' Chill', 'Endaroky\'s Chill', 'Ekron\'s Chill', 'Kirchen\'s Chill', --[[emu cutoff]] },
        Options={opt='USEDOTS', Gem=6}
    },
    {-- DoT. Slot 7
        Group='dot1',
        Spells={'Fevered Endemic', 'Vampyric Endemic', 'Neemzaq\'s Endemic', 'Elkikatar\'s Endemic', 'Hemocoraxius\' Endemic', --[[emu cutoff]] 'Chimera Blood'},
        Options={opt='USEDOTS', Gem=function() return (not BeastLord:isEnabled('USEMENDING') and 7) or (not BeastLord:isEnabled('USEALLIANCE') and 7) or nil end, condition=function() return state.burnActive end}
    },
    {-- DD DoT. Slot 8
        Group='dddot2',
        Spells={'Forgebound Blood', 'Akhevan Blood', 'Ikatiar\'s Blood', 'Polybiad Blood', 'Glistenwing Blood', --[[emu cutoff]] },
        Options={opt='USEDOTS', Gem=8}
    },
    {-- self buff. Slot 9
        Group='combatbuff',
        Spells={'Growl of Yasil', 'Growl of the Clouded Leopard', 'Growl of the Lioness', 'Growl of the Sabertooth', 'Growl of the Leopard', --[[emu cutoff]] 'Growl of the Panther'},
        Options={Gem=9, skipifbuff='Wild Spirit Infusion'}
    },
    {-- Swarm pets. Slot 9
        Group='swarmpet',
        Spells={'SingleMalt\'s Feralgia', 'Ander\'s Feralgia', 'Griklor\'s Feralgia', 'Akalit\'s Feralgia', 'Krenk\'s Feralgia', --[[emu cutoff]] 'Reptilian Venom'},
        Options={opt='USESWARMPETS', Gem=9, delay=1500}
    },
    {-- inc pet flurry, ds miti, self flurry, hp/mana/end regen, dec weapon delay. Slot 10
        Group='composite',
        Spells={'Ecliptic Fury', 'Composite Fury', 'Dissident Fury', 'Dichotomic Fury'},
        Options={Gem=10}
    },
    {-- Pet proc heal target of target. Slot 11
        Group='pettothealproc',
        Spells={'Vitalizing Warder', 'Protective Warder', 'Sympathetic Warder', 'Convivial Warder', 'Mending Warder', --[[emu cutoff]] },
        Options={Gem=11}
    },
    {-- lvl 100+. group avatar. Slot 12
        Group='groupfero',
        Spells={'Shared Merciless Ferocity'},
        Options={Gem=12}
    },
    {-- combined pet buffs, Unsurpassed Velocity, Spirit of Siver. Slot 13
        Group='petunity',
        Spells={'Cohort\'s Unity', 'Comrade\'s Unity', 'Ally\'s Unity', 'Companion\'s Unity'},
        Options={Gem=13, swap=true}
    },
    {-- Player heal / Salve of Artikla (Pet heal) Slot 13. Slot 7 if use alliance
        Group='heal',
        Spells={'Thornhost\'s Mending', 'Korah\'s Mending', 'Bethun\'s Mending', 'Deltro\'s Mending', 'Sabhattin\'s Mending', --[[emu cutoff]] 'Trushar\'s Mending'},
        Options={opt='USEMENDING', Gem=function() return not BeastLord:isEnabled('USEALLIANCE') and 13 or 7 end, me=75, self=true}
    },
    {-- adds extra damage to bst dots + fulmination. Slot 13
        Group='alliance',
        Spells={'Venomous Conjunction', 'Venomous Coalition', 'Venomous Covenant', 'Venomous Alliance'},
        Options={opt='USEALLIANCE', Gem=13}
    },

    {Group='slow', Spells={'Sha\'s Legacy'}, Options={opt='USESLOW'}},

    {Group='pet', Spells={'Spirit of Shae', 'Spirit of Panthea', 'Spirit of Blizzent', 'Spirit of Akalit', 'Spirit of Avalit', --[[emu cutoff]] 'Spirit of Rashara', 'Spirit of Alladnu', 'Spirit of Sorsha'}, Options={opt='SUMMONPET'}},
    {Group='petrune', Spells={'Auspice of Valia', 'Auspice of Kildrukaun', 'Auspice of Esianti', 'Auspice of Eternity', --[[emu cutoff]] }}, -- (pet rune) / Sympathetic Warder (pet healproc)
    {Group='petheal', Spells={'Salve of Homer', 'Salve of Jaegir', 'Salve of Tobart', 'Salve of Artikla', 'Salve of Clorith', --[[emu cutoff]] 'Healing of Mikkity', 'Healing of Sorsha'}, Options={opt='HEALPET', pet=50}}, -- (Pet heal)
    {Group='pethaste',Spells={'Insatiable Voracity', 'Unsurpassed Velocity', 'Astounding Velocity', 'Tremendous Velocity', --[[emu cutoff]] 'Growl of the Beast', 'Arag\'s Celerity'}, Options={swap=true}}, -- pet haste
    {Group='petbuff', Spells={'Spirit of Shoru', 'Spirit of Siver', 'Spirit of Mandrikai', 'Spirit of Beramos', 'Spirit of Visoracius', --[[emu cutoff]] 'Spirit of Oroshar', 'Spirit of Rellic'}, Options={swap=true}}, -- pet buff
    {Group='petaggression', Spells={'Magna\'s Aggression', 'Panthea\'s Aggression', 'Horasug\'s Aggression', 'Virzak\'s Aggression', 'Sekmoset\'s Aggression', --[[emu cutoff]] }, Options={swap=true}},

    {Group='regen', Spells={'Feral Vigor'}, Options={classes={WAR=true,SHD=true,PAL=true}}}, -- single regen
    {Group='groupregen', Spells={'Spiritual Enduement', 'Spiritual Erudition', 'Spiritual Elaboration', 'Spiritual Empowerment', 'Spiritual Insight', --[[emu cutoff]] 'Spiritual Edification', 'Spiritual Epiphany', 'Spiritual Enlightenment', 'Spiritual Ascendance', 'Spiritual Dominion', 'Spiritual Purity', 'Spiritual Radiance', 'Spiritual Light'}, Options={swap=true}}, -- group buff
    {Group='grouphp', Spells={'Spiritual Valiancy', 'Spiritual Vigor', 'Spiritual Vehemence', 'Spiritual Vibrancy', 'Spiritual Vivification', --[[emu cutoff]] 'Spiritual Vitality', 'Spiritual Vivacity', 'Spiritual Vim', 'Spiritual Vitality', 'Spiritual Vigor'}, Options={swap=true}},
    {Group='groupunity', Spells={'Wildfang\'s Unity', 'Chieftain\'s Unity', 'Reclaimer\'s Unity', 'Feralist\'s Unity', 'Stormblood\'s Unity'}, Options={swap=true}},
    -- below lvl 100
    {Group='fero', Spells={'Ferocity of Irionu', 'Ferocity'}, Options={classes={WAR=true,MNK=true,BER=true,ROG=true}}}, -- like shm avatar
    --     --Spells(Group)
    --     self:addSpell('pet', {'Spirit of Shae', 'Spirit of Panthea', 'Spirit of Blizzent', 'Spirit of Akalit', 'Spirit of Avalit'})
    --     self:addSpell('nuke1', {'Rimeclaw\'s Maelstrom', 'Va Xakra\'s Maelstrom', 'Vkjen\'s Maelstrom', 'Beramos\' Maelstrom', 'Visoracius\' Maelstrom'}) -- (DD)
    --     self:addSpell('nuke2', {'Mortimus\' Bite', 'Zelniak\'s Bite', 'Bloodmaw\'s Bite', 'Mawmun\'s Bite', 'Kreig\'s Bite'}) -- (DD)
    --     self:addSpell('nuke3', {'Frozen Creep', 'Frozen Blight', 'Frozen Malignance', 'Frozen Toxin', 'Frozen Miasma'}) -- (DD)
    --     self:addSpell('nuke4', {'Ankexfen Lance', 'Crystalline Lance', 'Restless Lance', 'Frostbite Lance', 'Kromtus Lance'}) -- (DD) / Restless Roar (AE DD)
    --     self:addSpell('nuke5', {'Crystalline Lance', 'Restless Lance', 'Frostbite Lance', 'Kromtus Lance'}) -- (DD)
    --     self:addSpell('dddot1', {'Lazam\'s Chill', 'Sylra Fris\' Chill', 'Endaroky\'s Chill', 'Ekron\'s Chill', 'Kirchen\'s Chill'}) -- (DD DoT)
    --     self:addSpell('dot1', {'Fevered Endemic', 'Vampyric Endemic', 'Neemzaq\'s Endemic', 'Elkikatar\'s Endemic', 'Hemocoraxius\' Endemic'}) -- (DoT)
    --     self:addSpell('dddot2', {'Forgebound Blood', 'Akhevan Blood', 'Ikatiar\'s Blood', 'Polybiad Blood', 'Glistenwing Blood'}) -- (DD DoT)
    --     self:addSpell('combatbuff', {'Growl of Yasil', 'Growl of the Clouded Leopard', 'Growl of the Lioness', 'Growl of the Sabertooth', 'Growl of the Leopard'}) -- (self buff) / Griklor's Feralgia (self buff/swarm pet)
    --     self:addSpell('composite', {'Ecliptic Fury', 'Composite Fury', 'Dissident Fury'}) --
    --     self:addSpell('petrune', {'Auspice of Valia', 'Auspice of Kildrukaun', 'Auspice of Esianti', 'Auspice of Eternity'}) -- (pet rune) / Sympathetic Warder (pet healproc)
    --     self:addSpell('petheal', {'Salve of Homer', 'Salve of Jaegir', 'Salve of Tobart', 'Salve of Artikla', 'Salve of Clorith'}) -- (Pet heal)
    --     self:addSpell('heal', {'Thornhost\'s Mending', 'Korah\'s Mending', 'Bethun\'s Mending', 'Deltro\'s Mending', 'Sabhattin\'s Mending'}) -- (Player heal) / Salve of Artikla (Pet heal)

    --     --Spells(Raid)
    --     self:addSpell('nuke1', {'Rimeclaw\'s Maelstrom', 'Va Xakra\'s Maelstrom', 'Vkjen\'s Maelstrom', 'Beramos\' Maelstrom', 'Visoracius\' Maelstrom'}) -- (DD)
    --     self:addSpell('nuke2', {'Mortimus\' Bite', 'Zelniak\'s Bite', 'Bloodmaw\'s Bite', 'Mawmun\'s Bite', 'Kreig\'s Bite'}) -- (DD)
    --     self:addSpell('nuke3', {'Frozen Creep', 'Frozen Blight', 'Frozen Malignance', 'Frozen Toxin', 'Frozen Miasma'}) -- (DD)
    --     self:addSpell('nuke4', {'Ankexfen Lance', 'Crystalline Lance', 'Restless Lance', 'Frostbite Lance', 'Kromtus Lance'}) -- (DD) / Restless Roar (AE DD)
    --     self:addSpell('nuke5', {'Crystalline Lance', 'Restless Lance', 'Frostbite Lance', 'Kromtus Lance'}) -- (DD)
    --     self:addSpell('dddot1', {'Lazam\'s Chill', 'Sylra Fris\' Chill', 'Endaroky\'s Chill', 'Ekron\'s Chill', 'Kirchen\'s Chill'}) -- (DD DoT)
    --     self:addSpell('dot1', {'Fevered Endemic', 'Vampyric Endemic', 'Neemzaq\'s Endemic', 'Elkikatar\'s Endemic', 'Hemocoraxius\' Endemic'}) -- (DoT)
    --     self:addSpell('dddot2', {'Forgebound Blood', 'Akhevan Blood', 'Ikatiar\'s Blood', 'Polybiad Blood', 'Glistenwing Blood'}) -- (DD DoT)
    --     self:addSpell('combatbuff', {'Growl of Yasil', 'Growl of the Clouded Leopard', 'Growl of the Lioness', 'Growl of the Sabertooth', 'Growl of the Leopard'}) -- (self buff) / Griklor's Feralgia (self buff/swarm pet)
    --     self:addSpell('composite', {'Ecliptic Fury', 'Composite Fury', 'Dissident Fury'}) --
    --     self:addSpell('alliance', {'Venpmous Conjunction', 'Venomous Coalition', 'Venomous Covenant', 'Venomous Alliance'}) --
    --     self:addSpell('petheal', {'Salve of Homer', 'Salve of Jaegir', 'Salve of Tobart', 'Salve of Artikla', 'Salve of Clorith'}) -- (Pet heal)
    --     self:addSpell('heal', {'Thornhost\'s Mending', 'Korah\'s Mending', 'Bethun\'s Mending', 'Deltro\'s Mending', 'Sabhattin\'s Mending'}) -- (Player heal) / Salve of Artikla (Pet heal)
}

BeastLord.compositeNames = {['Ecliptic Fury']=true, ['Composite Fury']=true, ['Dissident Fury']=true, ['Dichotomic Fury']=true}
BeastLord.allDPSSpellGroups = {'nuke1', 'nuke2', 'nuke3', 'lance1', 'lance2', 'roar', 'dddot1', 'dot1', 'dddot2', 'swarmpet', 'alliance'}

function BeastLord:initSpellRotations()
    self:initBYOSCustom()
    -- composite, alliance
    if state.emu then
        table.insert(self.spellRotations.standard, self.spells.swarmpet)
    end
    table.insert(self.spellRotations.standard, self.spells.dot1)
    table.insert(self.spellRotations.standard, self.spells.nuke1)
    table.insert(self.spellRotations.standard, self.spells.nuke2)
    table.insert(self.spellRotations.standard, self.spells.nuke3)
    table.insert(self.spellRotations.standard, self.spells.lance1)
    table.insert(self.spellRotations.standard, self.spells.lance2)
    table.insert(self.spellRotations.standard, self.spells.dddot1)
    table.insert(self.spellRotations.standard, self.spells.dddot2)
end

function BeastLord:initDPSAbilities()
    if state.emu then
        -- Passive on live, activated on emu (at least on lazarus)
        table.insert(self.DPSAbilities, common.getAA('Feral Swipe', {conditions=conditions.withinMeleeDistance}))
        table.insert(self.DPSAbilities, common.getAA('Bite of the Asp', {conditions=conditions.withinMeleeDistance}))
        table.insert(self.DPSAbilities, common.getAA('Gorilla Smash', {conditions=conditions.withinMeleeDistance}))
        table.insert(self.DPSAbilities, common.getAA('Raven Claw', {conditions=conditions.withinMeleeDistance}))
    end
    --Melee Spam
    table.insert(self.DPSAbilities, common.getAA('Chameleon Strike', {conditions=conditions.withinMeleeDistance})) -- (aggro reducer)
    table.insert(self.DPSAbilities, common.getBestDisc({'Focused Clamor of Claws'}, {conditions=conditions.withinMeleeDistance}))
    table.insert(self.AEDPSAbilities, common.getBestDisc({'Maelstrom of Claws'}, {conditions=conditions.withinMeleeDistance})) -- (AE)
    table.insert(self.DPSAbilities, common.getAA('Roar of Thunder', {opt='USENUKES', conditions=conditions.withinMeleeDistance}))
    table.insert(self.DPSAbilities, common.getBestDisc({'Clobber', 'Batter', 'Rake'}, {conditions=conditions.withinMeleeDistance})) -- (synergy proc ability)
    table.insert(self.combatBuffs, common.getBestDisc({'Bestial Savagery'})) -- (self buff)
    table.insert(self.DPSAbilities, common.getSkill('Eagle\'s Strike', {conditions=conditions.withinMeleeDistance})) -- (procs bite of the asp, /autoskill with round kick)
    if mq.TLO.Me.Skill('Round Kick')() > 0 then
        table.insert(self.DPSAbilities, sharedabilities.getRoundKick())
    elseif mq.TLO.Me.Skill('Kick')() > 0 then
        table.insert(self.DPSAbilities, sharedabilities.getKick())
    end

    --Raid
    --Swap Eagle's Strike for Dragon Punch - procs gorilla  smash
    -- table.insert(self.DPSAbilities, common.getSkill('Dragon Punch', {conditions=conditions.withinMeleeDistance}))
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
        --Forceful Rejuvenation
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
    if self.spells.groupunity then
        self.spells.groupunity.condition = function() return not (mq.TLO.Me.Buff(self.spells.groupregen.name)() and mq.TLO.Me.Buff(self.spells.grouphp.name)()) end
        table.insert(self.selfBuffs, self.spells.groupunity)
    else
        if self.spells.groupregen then self.spells.groupregen.condition = buffCondition end
        if self.spells.grouphp then self.spells.grouphp.condition = buffCondition end
        table.insert(self.selfBuffs, self.spells.groupregen)
        table.insert(self.selfBuffs, self.spells.grouphp)
    end

    if self.spells.combatbuff then self.spells.combatbuff.condition = buffCondition end
    table.insert(self.selfBuffs, self.spells.combatbuff)

    if self.spells.groupfero then
        table.insert(self.selfBuffs, self.spells.groupfero)
    elseif self.spells.fero then
        self.spells.fero.condition = buffCondition
        table.insert(self.selfBuffs, self.spells.fero)
        local singleBuffCondition = function(ability)
            return conditions.checkMana(ability)
        end
        self.spells.fero.condition = singleBuffCondition
        table.insert(self.singleBuffs, self.spells.fero)
    end

    if state.emu then table.insert(self.selfBuffs, common.getAA('Gelid Rending')) end
    table.insert(self.selfBuffs, common.getAA('Pact of the Wurine'))
    table.insert(self.selfBuffs, common.getAA('Protection of the Warder'))

    local petBuffCondition = function(ability)
        return conditions.checkMana(ability) and conditions.stacksPet(ability) and conditions.missingPetBuff(ability)
    end
    if self.spells.petunity then
        self.spells.petunity.condition = function() return not (mq.TLO.Pet.Buff(self.spells.pethaste.CastName)() and mq.TLO.Pet.Buff(self.spells.petbuff.CastName)()) end
        table.insert(self.petBuffs, self.spells.petunity)
    else
        if self.spells.pethaste then self.spells.pethaste.condition = petBuffCondition end
        if self.spells.petbuff then self.spells.petbuff.condition = petBuffCondition end
        table.insert(self.petBuffs, self.spells.pethaste)
        table.insert(self.petBuffs, self.spells.petbuff)
    end

    table.insert(self.petBuffs, common.getAA('Fortify Companion'))
    --local epicOpts = {CheckFor='Savage Wildcaller\'s Blessing', condition=conditions.missingPetCheckFor}
    local epicOpts = {CheckFor='Might of the Wild Spirits', condition=conditions.missingPetCheckFor}
    table.insert(self.petBuffs, common.getItem('Spiritcaller Totem of the Feral', epicOpts) or common.getItem('Savage Lord\'s Totem', epicOpts))
    table.insert(self.petBuffs, common.getAA('Taste of Blood', {CheckFor='Taste of Blood', condition=conditions.missingPetCheckFor}))

    self.paragon = common.getAA('Paragon of Spirit', {opt='USEPARAGON'})
    self.fParagon = common.getAA('Focused Paragon of Spirits', {opt='USEFOCUSEDPARAGON', mana=true, threshold=70, combat=true, endurance=false, minhp=20, ooc=true, skipTargetCheck=true})
    self:addRequestAlias(self.fParagon, 'FPARAGON')
    self:addRequestAlias(self.paragon, 'PARAGON')
    self:addRequestAlias(self.spells.groupregen, 'SE')
    self:addRequestAlias(self.spells.grouphp, 'SV')
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
        if (needEnd+lowmana) >= 3 and self.paragon:isReady() == abilities.IsReady.SHOULD_CAST then
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
                if constants.manaClasses[memberClass] and memberPctMana < 70 and memberDistance < 100 and mq.TLO.Me.AltAbilityReady(self.fParagon.Name)() then
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
