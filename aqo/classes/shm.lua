---@type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local timer = require('libaqo.timer')
local common = require('common')
local state = require('state')
local config = require('interface.configuration')

local Shaman = class:new()
--[[
    http://forums.eqfreelance.net/index.php?topic=9389.0
    
    -- Self buffs
    self:addSpell('selfprocheal', {'Watchful Spirit', 'Attentive Spirit', 'Responsive Spirit'}) -- self buff, proc heal when hit
    table.insert(self.selfBuffs, self:addAA('Pact of the Wolf'))
    table.insert(self.selfBuffs, self.spells.selfprocheal)
    table.insert(self.selfBuffs, self:addAA('Preincarnation'))

    -- Keep up on group
    self:addSpell('grouphot', {'Reverie of Renewal', 'Spirit of Renewal', 'Spectre of Renewal', 'Cloud of Renewal', 'Shear of Renewal'}) -- group HoT
    self:addSpell('composite', {'Ecliptic Roar', 'Composite Roar', 'Dissident Roar', 'Dichotomic Roar'}) -- stacks with HoT but overwrites regen, blocked by dots

    -- Use Often
    self:addSpell('splash', {'Spiritual Shower', 'Spiritual Squall', 'Spiritual Swell'}) -- splash, easiest to cast on self, requires los
    self:addSpell('recourse', {'Grayleaf\'s Recourse', 'Rowain\'s Recourse', 'Zrelik\'s Recourse', 'Eyrzekla\'s Recourse', 'Krasir\'s Recourse'})
    self:addSpell('intervention', {'Immortal Intervention', 'Antediluvian Intervention', 'Primordial Intervention', 'Prehistoric Intervention', 'Historian\'s' Intervention'})

    self:addSpell('tcnuke', {'Gelid Gift', 'Polar Gift', 'Wintry Gift', 'Frostbitten Gift', 'Glacial Gift'}) -- tot nuke, cast on MA/MT, next two heals twincast, use with spiritual shower

    self:addSpell('alliance', {'Ancient Coalition', 'Ancient Alliance'}) -- keep up on tank, proc ae heal from target

    self:addSpell('singlefocus', {'Heroic Focusing', 'Vampyre Focusing', 'Kromrif Focusing', 'Wulthan Focusing', 'Doomscale Focusing'})
    self:addSpell('singleunity', {'Unity of the Heroic', 'Unity of the Vampyre', 'Unity of the Kromrif', 'Unity of the Wulthan', 'Unity of the Doomscale'})
    self:addSpell('groupunity', {'Talisman of the Heroic', 'Talisman of the Usurper', 'Talisman of the Ry\'Gorr', 'Talisman of the Wulthan', 'Talisman of the Doomscale'})
    self:addSpell('growth', {'Overwhelming Growth', 'Fervent Growth', 'Frenzied Growth', 'Savage Growth', 'Ferocious Growth'})
    
    self:addSpell('malo', {'Malosinera', 'Malosinetra', 'Malosinara', 'Malosinata', 'Malosinete'})
    Call of the Ancients -- 5 minute duration ward AE healing

    self:addSpell('reckless1', {'Reckless Reinvigoration', 'Reckless Resurgence', 'Reckless Renewal', 'Reckless Rejuvenation', 'Reckless Regeneration'})
    self:addSpell('reckless2', {'Reckless Resurgence', 'Reckless Renewal', 'Reckless Rejuvenation', 'Reckless Regeneration'})
    self:addSpell('reckless3', {'Reckless Renewal', 'Reckless Rejuvenation', 'Reckless Regeneration'})
    -- Main healing: 2-4 Reckless spells
    table.insert(self.healAbilities, self.spells.reckless1) -- single target
    table.insert(self.healAbilities, self.spells.reckless2) -- single target
    table.insert(self.healAbilities, self.spells.reckless3) -- single target
    table.insert(self.healAbilities, self.spells.tcnuke) -- cast on MT
    -- Group Healing
    table.insert(self.healAbilities, self.spells.splash) -- cast on self
    table.insert(self.healAbilities, self.spells.recourse) -- group heal, several stages of healing
    table.insert(self.healAbilities, self.spells.intervention) -- longer refresh quick group heal
    table.insert(self.healAbilities, self.spells.grouphot)
    table.insert(self.healAbilities, self:addAA('Soothsayer\'s Intervention')) -- AA instant version of intervention spell
    table.insert(self.healAbilities, self:addAA('Ancestral Guard Spirit')) -- AA buff on target, big HoT below 50% HP, use on fragile melee
    
    self:addAA('Forceful Rejuvenation') -- use to refresh group heals
    Chest clicky -- clicky group heal
    Small Manisi Branch -- direct heal clicky
    Apothic Dragon Spine Hammer -- clicky heal like manisi branch

    self.callAbility = self:addAA('Call of the Wild')
    self.rezStick = common.getItem('Staff of Forbidden Rites')
    self.rezAbility = self:addAA('Rejuvenation of Spirit') -- 96% rez, ooc only

    -- Burns
    table.insert(self.burnAbilities, common.getItem('Blessed Spiritstaff of the Heyokah'), {first=true}) -- 2.0 click
    table.insert(self.burnAbilities, self:addAA('Spire of Ancestors'), {first=true}) -- inc total healing, dot crit
    table.insert(self.burnAbilities, self:addAA('Apex of Ancestors'), {first=true}) -- inc proc mod, accuracy, min dmg
    --table.insert(self.burnAbilities, self:addAA('Ancestral Aid'), {first=true}) -- large HoT, stacks, use with tranquil blessings
    table.insert(self.burnAbilities, self:addAA('Union of Spirits'), {first=true}) -- instant cast, use on monks/rogues
    table.insert(self.selfBuffs, self:addAA('Group Pact of the Wolf')) -- aura, cast before self wolf, they stack

    -- DPS
    Fleeting Spirit -- twin cast dots
    Obeah -- DoT
    Desperate Vampyre Blood -- DoT
    
    Rabid Bear -- inc melee stuff, procs heal group
    Pack of the Black Fang -- self buff, lags raids
    Languid Bite -- don't use on raids
    
]]
function Shaman:init()
    self.classOrder = {'heal', 'cure', 'assist', 'aggro', 'debuff', 'cast', 'burn', 'recover', 'rez', 'buff', 'rest', 'managepet'}
    self.spellRotations = {standard={},hybrid={},dps={},custom={}}
    self:initBase('SHM')

    self:initClassOptions()
    self:loadSettings()
    self:initSpellLines()
    self:initSpellRotations()
    self:initHeals()
    self:initCures()
    self:initBuffs()
    self:initBurns()
    self:initDPSAbilities()
    self:initDebuffs()
    self:initDefensiveAbilities()
    self:initRecoverAbilities()
    self:addCommonAbilities()

    self.rezAbility = self:addAA('Call of the Wild')
    self.summonCompanion = self:addAA('Summon Companion')
    state.nuketimer = timer:new(3000)
end

function Shaman:initClassOptions()
    self:addOption('USEDEBUFF', 'Use Malo', true, nil, 'Toggle casting malo on mobs', 'checkbox', nil, 'UseDebuff', 'bool')
    self:addOption('USEDISPEL', 'Use Dispel', true, nil, 'Toggle use of dispel', 'checkbox', nil, 'UseDispel', 'bool')
    self:addOption('USESLOW', 'Use Slow', true, nil, 'Toggle casting slow on mobs', 'checkbox', nil, 'UseSlow', 'bool')
    self:addOption('USESLOWAOE', 'Use Slow AOE', true, nil, 'Toggle casting AOE slow on mobs', 'checkbox', nil, 'UseSlowAOE', 'bool')
    self:addOption('USENUKES', 'Use Nukes', true, nil, 'Toggle use of nukes', 'checkbox', nil, 'UseNukes', 'bool')
    self:addOption('USEDOTS', 'Use DoTs', true, nil, 'Toggle use of DoTs', 'checkbox', nil, 'UseDoTs', 'bool')
    self:addOption('USEEPIC', 'Use Epic', true, nil, 'Use epic in burns', 'checkbox', nil, 'UseEpic', 'bool')
    self:addOption('USEGROWTH', 'Use Growth', true, nil, 'Use Growth line of spells', 'checkbox', nil, 'UseGrowth', 'bool')
    self:addOption('MEMCUREALL', 'Mem Cure All', false, nil, 'Memorize cure all line of spells', 'checkbox', nil, 'MemCureAll', 'bool')
    self:addOption('USESPLASH', 'Use Splash', true, nil, 'Memorize splash line of spells', 'checkbox', nil, 'UseSplash', 'bool')
    self:addOption('USEHOTGROUP', 'Use Group HoT', true, nil, 'Toggle use of group HoT', 'checkbox', nil, 'UseHoTGroup', 'bool')
end

Shaman.SpellLines = {
    {-- proc buff slow + heal, 240 charges. Slot 1
        Group='slowproc',
        Spells={'Moroseness', 'Melancholy', 'Ennui', 'Incapacity', 'Sluggishness', 'Lingering Sloth'},
        Options={Gem=function() return Shaman:get('SPELLSET') ~= 'dps' and 1 or nil end, singlebuff=true, classes={WAR=true,PAL=true,SHD=true}}
    },
    {-- DPS spellset. Disease DoT. Slot 1
        Group='maladydot',
        Spells={'Uncia\'s Malady', 'Cruor\'s Malady', 'Malvus\'s Malady', 'Hoshkar\'s Malady', 'Sephry\'s Malady'},
        Options={opt='USEDOTS', Gem=function() return Shaman:get('SPELLSET') == 'dps' and 1 or nil end}
    },
    {-- group HoT. Slot 2
        Group='grouphot',
        Spells={'Reverie of Renewal', 'Spirit of Renewal', 'Spectre of Renewal', 'Cloud of Renewal', 'Shear of Renewal', 'Ghost of Renewal'},
        Options={opt='USEHOTGROUP', Gem=2, grouphot=true}
    },
    {-- poison nuke. Slot 3
        Group='bitenuke',
        Spells={'Oka\'s Bite', 'Ander\'s Bite', 'Direfang\'s Bite', 'Mawmun\'s Bite', 'Reefmaw\'s Bite'},
        Options={opt='USENUKES', Gem=3}
    },
    {-- tot nuke, cast on MA/MT, next two heals twincast, use with spiritual shower. Slot 4
        Group='tcnuke',
        NumToPick=2,
        Spells={'Gelid Gift', 'Polar Gift', 'Wintry Gift', 'Frostbitten Gift', 'Glacial Gift', 'Frostfall Boon'},
        Options={
            opt='USENUKES',
            Gems={4,function() return Shaman:get('SPELLSET') ~= 'dps' and not Shaman:isEnabled('USEGROWTH') and 6 or nil end},
            precast = function() mq.cmdf('/mqtar id %s', mq.TLO.Group.MainTank.ID() or config.get('CHASETARGET')) end
        },
    },
    {-- group heal, lower hp == stronger heal. Slot 5
        Group='intervention',
        Spells={'Immortal Intervention', 'Antediluvian Intervention', 'Primordial Intervention', 'Prehistoric Intervention', 'Historian\'s Intervention'},
        Options={Gem=function() return Shaman:get('SPELLSET') ~= 'dps' and 5 or nil end, group=true}
    },
    {-- DPS spellset. Combo disease DoT. Slot 5
        Group='pandemiccombo',
        Spells={'Tegi Pandemic', 'Bledrek\'s Pandemic', 'Elkikatar\'s Pandemic', 'Hemocoraxius\' Pandemic'},
        Options={opt='USEDOTS', Gem=function() return Shaman:get('SPELLSET') == 'dps' and 5 or nil end}
    },
    {-- disease dot. Not used directly, only by combo spell. Combo spell comes in non-level increase expansions. (pendemiccombo)
        Group='breathdot',
        Spells={'Breath of the Hotariton', 'Breath of the Tegi', 'Breath of Bledrek', 'Breath of Elkikatar', 'Breath of Hemocoraxius', 'Breath of Wunshi'},
        Options={opt='USEDOTS', Gem=function() return not Shaman.spells.pandemiccombo and Shaman:get('SPELLSET') == 'dps' and 5 or nil end}
    },
    {-- temp hp buff. Slot 6
        Group='growth',
        Spells={'Overwhelming Growth', 'Fervent Growth', 'Frenzied Growth', 'Savage Growth', 'Ferocious Growth'},
        Options={opt='USEGROWTH', Gem=function() return Shaman:get('SPELLSET') ~= 'dps' and not Shaman:isEnabled('MEMCUREALL') and 6 or nil end}
    },
    {-- cure all. Slot 6
        Group='cureall',
        Spells={'Blood of Mayong', 'Blood of Tevik', 'Blood of Rivans'},
        Options={opt='MEMCUREALL', Gem=6}
    },
    {-- group heal. Slot 7
        Group='recourse',
        Spells={'Grayleaf\'s Recourse', 'Rowain\'s Recourse', 'Zrelik\'s Recourse', 'Eyrzekla\'s Recourse', 'Krasir\'s Recourse', 'Word of Reconstitution', 'Word of Restoration'},
        Options={Gem=function() return Shaman:get('SPELLSET') == 'standard' and 7 or nil end, group=true}
    },
    {-- DPS spellset. Slot 7
        Group='poisonnuke',
        Spells={'Red Eye\'s Spear of Venom', 'Fleshrot\'s Spear of Venom', 'Narandi\'s Spear of Venom', 'Nexona\'s Spear of Venom', 'Serisaria\'s Spear of Venom', 'Yoppa\'s Spear of Venom', 'Spear of Torment'},
        Options={opt='USENUKES', Gem=function() return Shaman:get('SPELLSET') ~= 'standard' and 7 or nil end}
    },
    {-- Lvl 100+ main heal. Slot 8, 9, 10
        Group='reckless',
        NumToPick=3,
        Spells={'Reckless Reinvigoration', 'Reckless Resurgence', 'Reckless Renewal', 'Reckless Rejuvenation', 'Reckless Regeneration'},
        Options={Gems={8,function() return Shaman:get('SPELLSET') ~= 'dps' and 9 or nil end,function() return Shaman:get('SPELLSET') == 'standard' and 10 or nil end}, panic=true, regular=true, tank=true}
    },
    {-- Below lvl 100 main heal. Slot 8
        Group='heal',
        Spells={'Krasir\'s Mending', 'Ancient: Wilslik\'s Mending', 'Yoppa\'s Mending', 'Daluda\'s Mending', 'Chloroblast', 'Kragg\'s Salve', 'Superior Healing', 'Spirit Salve', 'Light Healing', 'Minor Healing'},
        Options={Gem=function() return mq.TLO.Me.Level() < 105 and 8 or nil end, panic=true, regular=true, tank=true, pet=60}
    },
    {-- DPS spellset. combo malo + DoT. Slot 9
        Group='malodot',
        Spells={'Krizad\'s Malosinera', 'Txiki\'s Malosinara', 'Svartmane\'s Malosinara', 'Rirwech\'s Malosinata', 'Livio\'s Malosenia'},
        Options={opt='USEDOTS', Gem=function() return Shaman:get('SPELLSET') == 'dps' and 9 or nil end}
    },
    {-- lesser poison dot. Not used directly. only by combo spell. (chaotic)
        Group='nectardot',
        Spells={'Nectar of Obscurity', 'Nectar of Destitution', 'Nectar of Misery', 'Nectar of Suffering', 'Nectar of Woe', 'Nectar of Pain'},
        Options={opt='USEDOTS', Gem=function() return not Shaman.spells.malodot and Shaman:get('SPELLSET') == 'dps' and 9 or nil end}
    },
    {-- DPS spellset. curse DoT. Slot 10
        Group='cursedot',
        Spells={'Fandrel\'s Curse', 'Lenrel\'s Curse', 'Marlek\'s Curse', 'Erogo\'s Curse', 'Sraskus\' Curse', 'Curse of Sisslak'},
        Options={opt='USEDOTS', Gem=function() return Shaman:get('SPELLSET') ~= 'standard' and 10 or nil end}
    },
    {-- splash, easiest to cast on self, requires los. Slot 11
        Group='splash',
        Spells={'Spiritual Shower', 'Spiritual Squall', 'Spiritual Swell'},
        Options={opt='USESPLASH', Gem=11, group=true}
    },
    {-- single HoT. Slot 11
        Group='singlehot',
        Spells={'Halcyon Gale', 'Halcyon Squall', 'Halcyon Wind', 'Halcyon Billow', 'Halcyon Bluster', 'Transcendent Torpor', 'Spiritual Serenity', 'Breath of Trushar'},
        Options={opt='USEHOTTANK', Gem=11, hot=true}
    },
    {-- Hybrid spellset. Slot 11
        Group='icenuke',
        Spells={'Ice Barrage', 'Heavy Sleet', 'Ice Salvo', 'Ice Shards', 'Ice Squall'},
        Options={opt='USENUKES', Gem=function() return Shaman:get('SPELLSET') ~= 'standard' and not Shaman:isEnabled('USESPLASH') and 11 or nil end}
    },
    {-- stacks with HoT but overwrites regen, blocked by dots. Slot 12
        Group='composite',
        Spells={'Ecliptic Roar', 'Composite Roar', 'Dissident Roar', 'Roar of the Lion'},
        Options={Gem=12}
    },
    {-- Combo 2x DoTs + 1-2 nukes. Slot 13 (heal) or 6 (dps)
        Group='chaotic',
        Spells={'Chaotic Toxin', 'Chaotic Venin', 'Chaotic Poison', 'Chaotic Venom'},
        Options={Gem=function() return ((Shaman:get('SPELLSET') == 'standard' or not Shaman:isEnabled('USEALLIANCE')) and 13) or (Shaman:get('SPELLSET') == 'dps' and not Shaman:isEnabled('MEMCUREALL') and 6) or nil end}
    },
    {-- greater poison dot. Not used directly. only by combo spell. (chaotic)
        Group='blooddot',
        Spells={'Caustic Blood', 'Desperate Vampyre Blood', 'Restless Blood', 'Scorpikis Blood', 'Reef Crawler Blood', 'Blood of Yoppa'},
        Options={opt='USEDOTS', Gem=function() return (not Shaman.spells.chaotic and (Shaman:get('SPELLSET') == 'standard' or not Shaman:isEnabled('USEALLIANCE')) and 13) or (not Shaman.spells.chaotic and Shaman:get('SPELLSET') == 'dps' and not Shaman:isEnabled('MEMCUREALL') and 6) or nil end}
    },
    {-- keep up on tank, proc ae heal from target. Slot 13
        Group='alliance',
        Spells={'Ancient Conjunction', 'Ancient Coalition', 'Ancient Covenant', 'Ancient Alliance'},
        Options={opt='USEALLIANCE', Gem=13}
    },

    -- TODO: Need to work these spells into places they can be used
    -- self buff, proc heal when hit
    {Group='selfprocheal', Spells={'Watchful Spirit', 'Attentive Spirit', 'Responsive Spirit'}, Options={selfbuff=true}},
    -- Cures
    {Group='cure', Spells={'Blood of Nadox'}},
    {Group='rgc', Spells={'Remove Greater Curse'}, Options={curse=true}},

    -- TODO: cleanup Leftover EMU specific stuff
    {Group='torpor', Spells={'Transcendent Torpor'}, Options={alias='HOT'}},
    {Group='idol', Spells={'Idol of Malos'}, Options={opt='USEDEBUFF', condition=function() return mq.TLO.Spawn('Spirit Idol')() ~= nil end}},
    {Group='dispel', Spells={'Abashi\'s Disempowerment'}, Options={opt='USEDISPEL'}},
    {Group='debuff', Spells={'Crippling Spasm'}, Options={opt='USEDEBUFF'}},
    -- EMU special: Ice Age nuke has 25% chance to proc slow
    {Group='slownuke', Spells={'Ice Age'}, Options={opt='USENUKES'}},

    -- Debuffs
    {-- Malo spell line. AA malo is Malosinete
        Group='malo',
        Spells={'Malosinera', 'Malosinetra', 'Malosinara', 'Malosinata', 'Malosenete'},
        Options={opt='USEDEBUFF'}
    },
    {Group='slow', Spells={'Turgur\'s Insects', 'Togor\'s Insects'}, Options={opt='USESLOW'}},
    {Group='slowaoe', Spells={'Rimeclaw\'s Drowse', 'Aten Ha Ra\'s Drowse', 'Amontehepna\'s Drowse', 'Erogo\'s Drowse', 'Sraskus\' Drowse'}, Options={opt='USESLOWAOE'}},

    -- Extra DoTs just used by combo spells
    {-- disease dot. Not used directly, only by combo spell. (pendemiccombo)
        Group='pandemicdot',
        Spells={'Skraiw\'s Pandemic', 'Doomshade\'s Pandemic', 'Bolman\'s Pandemic', 'Vermistipus\'s Pandemic', 'Spirespine\'s Pandemic'},
        Options={opt='USEDOTS'}
    },
    {-- disease dot. Not used directly, only by combo spell. (malodot)
        Group='afflictiondot',
        Spells={'Krizad\'s Affliction', 'Brightfeld\'s Affliction', 'Svartmane\'s Affliction', 'Rirwech\'s Affliction', 'Livio\'s Affliction'},
        Options={opt='USEDOTS'}
    },

    -- Buffs
    {Group='proc', Spells={'Spirit of the Leopard', 'Spirit of the Jaguar'}, Options={classes={MNK=true,BER=true,ROG=true,BST=true,WAR=true,PAL=true,SHD=true}, singlebuff=true}},
    {Group='champion', Spells={'Champion', 'Ferine Avatar'}},
    {Group='panther', Spells={'Talisman of the Panther'}, Options={selfbuff=true}},
    -- {Group='talisman', Spells={'Talisman of Unification'}, Options={group=true, self=true, classes={WAR=true,SHD=true,PAL=true}})
    -- {Group='focus', Spells={'Talisman of Wunshi'}, Options={classes={WAR=true,SHD=true,PAL=true}})
    {Group='evasion', Spells={'Talisman of Unification'}, Options={self=true, classes={WAR=true,SHD=true,PAL=true}}},
    {Group='singlefocus', Spells={'Heroic Focusing', 'Vampyre Focusing', 'Kromrif Focusing', 'Wulthan Focusing', 'Doomscale Focusing'}},
    {Group='singleunity', Spells={'Unity of the Heroic', 'Unity of the Vampyre', 'Unity of the Kromrif', 'Unity of the Wulthan', 'Unity of the Doomscale'}, Options={alias='SINGLEFOCUS'}},
    {Group='groupunity', Spells={'Talisman of the Heroic', 'Talisman of the Usurper', 'Talisman of the Ry\'Gorr', 'Talisman of the Wulthan', 'Talisman of the Doomscale', 'Talisman of Wunshi'}, Options={classes={WAR=true,SHD=true,PAL=true}, singlebuff=true, alias='FOCUS'}},

    -- Utility
    {Group='canni', Spells={'Cannibalize IV', 'Cannibalize III', 'Cannibalize II'}, Options={mana=true, threshold=70, combat=false, endurance=false, minhp=50, ooc=false}},
    {Group='pet', Spells={'Commune with the Wild', 'True Spirit', 'Frenzied Spirit'}, Options={'SUMMONPET'}},

    --Call of the Ancients -- 5 minute duration ward AE healing
}

Shaman.compositeNames = {['Ecliptic Roar']=true,['Composite Roar']=true,['Dissident Roar']=true,['Roar of the Lion']=true}
Shaman.allDPSSpellGroups = {'maladydot', 'bitenuke', 'tcnuke', 'pandemiccombo', 'breathdot', 'poisonnuke', 'malodot', 'nectardot', 'cursedot',
    'icenuke', 'chaotic', 'blooddot', 'pandemicdot', 'afflictiondot'}

function Shaman:initSpellRotations()
    self:initBYOSCustom()
    if state.emu then
        table.insert(self.spellRotations.standard, self.spells.slownuke)
    end

    table.insert(self.spellRotations.standard, self.spells.chaotic)
    table.insert(self.spellRotations.standard, self.spells.tcnuke1)
    table.insert(self.spellRotations.standard, self.spells.bitenuke)
    table.insert(self.spellRotations.standard, self.spells.tcnuke2)
    table.insert(self.spellRotations.standard, self.spells.chaotic)

    table.insert(self.spellRotations.hybrid, self.spells.chaotic)
    table.insert(self.spellRotations.hybrid, self.spells.cursedot)
    table.insert(self.spellRotations.hybrid, self.spells.tcnuke1)
    table.insert(self.spellRotations.hybrid, self.spells.bitenuke)
    table.insert(self.spellRotations.hybrid, self.spells.tcnuke2)
    table.insert(self.spellRotations.hybrid, self.spells.poisonnuke)
    table.insert(self.spellRotations.hybrid, self.spells.icenuke)

    table.insert(self.spellRotations.dps, self.spells.chaotic)
    table.insert(self.spellRotations.dps, self.spells.maladydot)
    table.insert(self.spellRotations.dps, self.spells.pandemiccombo)
    table.insert(self.spellRotations.dps, self.spells.malodot)
    table.insert(self.spellRotations.dps, self.spells.cursedot)
    table.insert(self.spellRotations.dps, self.spells.tcnuke1)
    table.insert(self.spellRotations.dps, self.spells.bitenuke)
    table.insert(self.spellRotations.dps, self.spells.poisonnuke)
    table.insert(self.spellRotations.dps, self.spells.icenuke)
end

function Shaman:initDPSAbilities()

end

function Shaman:initBurns()
    local epic = common.getItem('Blessed Spiritstaff of the Heyokah', {opt='USEEPIC'}) or common.getItem('Crafted Talisman of Fates', {opt='USEEPIC'})

    table.insert(self.burnAbilities, self:addAA('Ancestral Aid'))
    table.insert(self.burnAbilities, epic)
    table.insert(self.burnAbilities, self:addAA('Rabid Bear'))
    table.insert(self.burnAbilities, self:addAA('Fundament: First spire of Ancestors'))
    -- table.insert(self.burnAbilities, common.getItem('Blessed Spiritstaff of the Heyokah'), {first=true}) -- 2.0 click
    -- table.insert(self.burnAbilities, self:addAA('Spire of Ancestors'), {first=true}) -- inc total healing, dot crit
    -- table.insert(self.burnAbilities, self:addAA('Apex of Ancestors'), {first=true}) -- inc proc mod, accuracy, min dmg
    -- --table.insert(self.burnAbilities, self:addAA('Ancestral Aid'), {first=true}) -- large HoT, stacks, use with tranquil blessings
    -- table.insert(self.burnAbilities, self:addAA('Union of Spirits'), {first=true}) -- instant cast, use on monks/rogues
    -- table.insert(self.selfBuffs, self:addAA('Group Pact of the Wolf')) -- aura, cast before self wolf, they stack
end

function Shaman:initHeals()
    if mq.TLO.Me.Level() >= 105 then
        table.insert(self.healAbilities, self.spells.reckless1) -- single target
        table.insert(self.healAbilities, self.spells.reckless2) -- single target
        table.insert(self.healAbilities, self.spells.reckless3) -- single target
    else
        table.insert(self.healAbilities, self.spells.heal)
    end
    -- Group Healing
    table.insert(self.healAbilities, self.spells.splash) -- cast on self
    table.insert(self.healAbilities, self.spells.recourse) -- group heal, several stages of healing
    table.insert(self.healAbilities, self.spells.intervention) -- longer refresh quick group heal
    table.insert(self.healAbilities, self.spells.grouphot)
    table.insert(self.healAbilities, self:addAA('Soothsayer\'s Intervention', {group=true, threshold=3})) -- AA instant version of intervention spell
    table.insert(self.healAbilities, self:addAA('Ancestral Guard Spirit')) -- AA buff on target, big HoT below 50% HP, use on fragile melee
    table.insert(self.healAbilities, self:addAA('Union of Spirits', {panic=true, tank=true, pet=30}))
    table.insert(self.healAbilities, self.spells.hottank)
    table.insert(self.healAbilities, self.spells.hotdps)
end

function Shaman:initCures()
    table.insert(self.cures, self.spells.cureall)
    table.insert(self.cures, self.spells.cure)
    table.insert(self.cures, self.radiant)
    table.insert(self.cures, self.spells.rgc)
end

function Shaman:initBuffs()
    -- Self buffs
    table.insert(self.selfBuffs, self:addAA('Pact of the Wolf', {selfbuff=true}))
    table.insert(self.selfBuffs, self.spells.selfprocheal)
    table.insert(self.selfBuffs, self:addAA('Preincarnation', {selfbuff=true}))
--
    --table.insert(self.combatBuffs, self.spells.champion)
    -- table.insert(self.selfBuffs, common.getItem('Earring of Pain Deliverance', {CheckFor='Reyfin\'s Random Musings'}))
    -- table.insert(self.selfBuffs, common.getItem('Xxeric\'s Matted-Fur Mask', {CheckFor='Reyfin\'s Racing Thoughts'}))
    local pantherTablet = mq.TLO.FindItem('Imbued Rune of the Panther')()
    if not pantherTablet then
        table.insert(self.selfBuffs, self.spells.panther)
    end
    table.insert(self.singleBuffs, self.spells.slowproc)
    table.insert(self.singleBuffs, self.spells.proc)
    table.insert(self.selfBuffs, self:addAA('Pact of the Wolf', {RemoveBuff='Pact of the Wolf Effect', selfbuff=true}))
    --table.insert(self.selfBuffs, self.spells.champion)
    table.insert(self.selfBuffs, self:addAA('Languid Bite', {selfbuff=true}))
    table.insert(self.singleBuffs, self.spells.groupunity)
    table.insert(self.singleBuffs, self:addAA('Group Pact of the Wolf', {classes={SHD=true,WAR=true}, singlebuff=true}))
    -- pact of the wolf, remove pact of the wolf effect
end

function Shaman:initDebuffs()
    table.insert(self.debuffs, self.spells.dispel)
    table.insert(self.debuffs, self.spells.idol)
    table.insert(self.debuffs, self:addAA('Malosinete', {opt='USEDEBUFF'}))
    table.insert(self.debuffs, self:addAA('Turgur\'s Swarm', {opt='USESLOW'}) or self.spells.slow)
    table.insert(self.debuffs, self.spells.debuff)
end

function Shaman:initDefensiveAbilities()
    table.insert(self.defensiveAbilities, self:addAA('Ancestral Guard'))
end

function Shaman:initRecoverAbilities()
    self.canni = self:addAA('Cannibalization', {mana=true, endurance=false, threshold=60, combat=true, minhp=80, ooc=false})
    table.insert(self.recoverAbilities, self.canni)
    table.insert(self.recoverAbilities, self.spells.canni)
end

return Shaman