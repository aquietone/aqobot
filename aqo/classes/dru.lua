---@type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local timer = require('libaqo.timer')
local common = require('common')
local state = require('state')

local Druid = class:new()

--[[
    https://rexaraven.com/everquest/druid/druid-general-guide/

    -- Tank AAs
    self:addSpell('', {'Fervent Growth'}) -- temp max hp boost
    self:addAA('Swarm of Fireflies') -- instant heal + regen below 40% hp
    self:addAA('Bear Spirit') -- short duration max hp, ac, dodge buff

]]
--[[
    wasp swarm
    ancient: chlorobon
    hand of ro
    vengeance of the sun
    sunburst blessing
    incarnate anew
    word of restoration
    moonshadow
    blank
    remove greater curse
    circle of knowledge
    skin of the reptile
]]
function Druid:init()
    self.classOrder = {'heal', 'assist', 'debuff', 'cast', 'mash', 'burn', 'recover', 'rez', 'buff', 'rest', 'managepet'}
    self.spellRotations = {standard={},custom={}}
    self:initBase('DRU')

    self:initClassOptions()
    self:loadSettings()
    self:initSpellLines()
    self:initSpellRotations()
    self:initAbilities()
    self:initHeals()
    self:addCommonAbilities()

    state.nuketimer = timer:new(500)
end

function Druid:initClassOptions()
    self:addOption('USENUKES', 'Use Nukes', false, nil, 'Toggle use of nuke spells', 'checkbox', nil, 'UseNukes', 'bool')
    self:addOption('USEDOTS', 'Use DoTs', false, nil, 'Toggle use of DoT spells', 'checkbox', nil, 'UseDoTs', 'bool')
    self:addOption('USESNARE', 'Use Snare', true, nil, 'Cast snare on mobs', 'checkbox', nil, 'UseSnare', 'bool')
    self:addOption('USEDEBUFF', 'Use Ro Debuff', false, nil, 'Use Blessing of Ro AA', 'checkbox', nil, 'UseDebuff', 'bool')
end

Druid.SpellLines = {
    -- Main spell set
    {Group='twincast', Spells={'Twincast'}},
    {
        Group='heal1',
        Spells={'Resuscitation', 'Soothseance', 'Rejuvenescence', 'Revitalization', 'Resurgence', 'Ancient: Chlorobon', 'Sylvan Infusion', 'Nature\'s Infusion', 'Chloroblast', 'Superior Healing', 'Nature\'s Renewal', 'Light Healing', 'Minor Healing'},
        Options={Gem=1, panic=true, regular=true, tank=true, pet=60}
    },
    {
        Group='heal2',
        Spells={'Adrenaline Fury', 'Adrenaline Spate', 'Adrenaline Deluge', 'Adrenaline Barrage', 'Adrenaline Torrent'},
        Options={Gem=2, panic=true, regular=true, tank=true, pet=60}
    }, -- healing spam on cd
    {
        Group='groupheal1',
        Spells={'Lunacea', 'Lunarush', 'Lunalesce', 'Lunasalve', 'Lunasoothe', 'Word of Reconstitution', 'Word of Restoration', 'Moonshadow'},
        Options={Gem=3, group=true}
    },
    {
        Group='groupheal2',
        Spells={'Survival of the Heroic', 'Survival of the Unrelenting', 'Survival of the Favored', 'Survival of the Auspicious', 'Survival of the Serendipitous'},
        Options={Gem=4, group=true}
    }, -- group heal
    {
        Group='dot1',
        Spells={'Nature\'s Boiling Wrath', 'Nature\'s Sweltering Wrath', 'Nature\'s Fervid Wrath', 'Nature\'s Blistering Wrath', 'Nature\'s Fiery Wrath', --[[emu cutoff]] 'Flame Lick'},
        Options={Gem=5, opt='USEDOTS'}
    },
    {
        Group='dot2',
        Spells={'Horde of Hotaria', 'Horde of Duskwigs', 'Horde of Hyperboreads', 'Horde of Polybiads', 'Horde of Aculeids', 'Wasp Swarm', 'Swarming Death', 'Winged Death', 'Stinging Swarm'},
        Options={Gem=6, opt='USEDOTS'}
    },
    {Group='dot3', Spells={'Sunscald', 'Sunpyre', 'Sunshock', 'Sunflame', 'Sunflash', 'Vengeance of the Sun'}, Options={opt='USEDOTS'}},
    {Group='dot5', Spells={'Searing Sunray', 'Tenebrous Sunray', 'Erupting Sunray', 'Overwhelming Sunray', 'Consuming Sunray'}, Options={opt='USEDOTS'}}, -- inc spell dmg taken, dot, dec fire resist, dec AC
    --{Group='', Spells={'Mythical Moonbeam', 'Onyx Moonbeam', 'Opaline Moonbeam', 'Pearlescent Moonbeam', 'Argent Moonbeam'}}, -- sunray but cold resist
    {
        Group='nuke1',
        Spells={'Remote Sunscorch', 'Remote Sunbolt', 'Remote Sunshock', 'Remote Sunblaze', 'Remote Sunflash', --[[emu cutoff]] 'Ignite', 'Burst of Fire', 'Burst of Flame'},
        Options={Gem=7, opt='USENUKES'}
    }, -- nuke + heal tot
    {Group='nuke2', Spells={'Winter\'s Wildgale', 'Winter\'s Wildbrume', 'Winter\'s Wildshock', 'Winter\'s Wildblaze', 'Winter\'s Wildflame', 'Ancient: Glacier Frost'}, Options={opt='USENUKES'}},
    {Group='nuke3', Spells={'Summer Sunscald', 'Summer Sunpyre', 'Summer Sunshock', 'Summer Sunflame', 'Summer Sunfire', 'Dawnstrike', 'Sylvan Fire', 'Wildfire', 'Scoriae', 'Firestrike'}, Options={opt='USENUKES'}},
    {Group='nuke4', Spells={'Tempest Roar', 'Bloody Roar', 'Typhonic Roar', 'Cyclonic Roar', 'Anabatic Roar'}, Options={opt='USENUKES'}},

    {Group='composite', Spells={'Ecliptic Winds', 'Composite Winds', 'Dichotomic Winds'}},
    {Group='alliance', Spells={'Arbor Tender\'s Coalition', 'Bosquetender\'s Alliance'}},
    {Group='unity', Spells={'Wildtender\'s Unity', 'Copsetender\'s Unity'}},

    -- Other spells
    {Group='dot4', Spells={'Chill of the Ferntender', 'Chill of the Dusksage Tender', 'Chill of the Arbor Tender', 'Chill of the Wildtender', 'Chill of the Copsetender'}, Options={opt='USEDOTS'}},
    {Group='heal3', Spells={'Vivavida', 'Clotavida', 'Viridavida', 'Curavida', 'Panavida'}, Options={panic=true, regular=true, tank=true, pet=60}}, -- healing spam if other heals on cd
    {Group='growth', Spells={'Overwhelming Growth', 'Fervent Growth', 'Frenzied Growth', 'Savage Growth', 'Ferocious Growth'}},
    {Group='snare', Spells={'Ensnare', 'Snare'}, Options={opt='USESNARE', debuff=true}},

    {Group='healtot', Spells={'Mythic Frost', 'Primal Frost', 'Restless Frost', 'Glistening Frost', 'Moonbright Frost'}}, -- Heal tot, dec atk, dec AC
    {Group='tcnuke', Spells={'Sunbliss Blessing', 'Sunwarmth Blessing', 'Sunrake Blessing', 'Sunflash Blessing', 'Sunfire Blessing', 'Sunburst Blessing'}, Options={opt='USENUKES'}},
    {Group='harvest', Spells={'Emboldened Growth', 'Bolstered Growth', 'Sustaining Growth', 'Nourishing Growth'}}, -- self return 10k mana
    {Group='cure', Spells={'Sanctified Blood'}, Options={cure=true, all=true}}, -- cure dis/poi/cor/cur
    {Group='curedisease', Spells={'Counteract Disease', 'Cure Disease'}, Options={cure=true, disease=true}},
    {Group='curepoison', Spells={'Counteract Poison', 'Cure Poison'}, Options={cure=true, poison=true}},
    {Group='rgc', Spells={'Remove Greater Curse', 'Remove Minor Curse'}, Options={cure=true, curse=true}},
    {Group='pet', Spells={'Nature Wanderer\'s Behest'}, Options={opt='USEPET'}},

    -- Buffs
    {Group='skin', Spells={'Emberquartz Blessing', 'Luclinite Blessing', 'Opaline Blessing', 'Arcronite Blessing', 'Shieldstone Blessing', --[[emu cutoff]] 'Protection of Wood'}, Options={alias='SKIN', selfbuff=true}},
    {Group='regen', Spells={'Talisman of the Unforgettable', 'Talisman of the Tenacious', 'Talisman of the Enduring', 'Talisman of the Unwavering', 'Talisman of the Faithful'}, Options={selfbuff=true}},
    {Group='mask', Spells={'Mask of the Ferntender', 'Mask of the Dusksage Tender', 'Mask of the Arbor Tender', 'Mask of the Wildtender', 'Mask of the Copsetender'}, Options={selfbuff=true}}, -- self mana regen, part of unity AA
    {Group='singleskin', Spells={'Emberquartz Skin', 'Luclinite Skin', 'Opaline Skin', 'Arcronite Skin', 'Shieldstone Skin', --[[emu cutoff]] 'Skin like Rock', 'Skin like Wood'}},
    {Group='reptile', Spells={'Chitin of the Reptile', 'Bulwark of the Reptile', 'Defense of the Reptile', 'Guard of the Reptile', 'Pellicle of the Reptile', 'Skin of the Reptile'}, Options={selfbuff=true, alias='REPTILE', singlebuff=true, classes={MNK=true,WAR=true,PAL=true,SHD=true}}}, -- debuff on hit, lowers atk++AC
    {Group='coat', Spells={'Thistlecoat'}, Options={selfbuff=true}},
    {Group='ds', Spells={'Shield of Thistles'}, Options={singlebuff=true, classes={}}},
    {Group='sow', Spells={'Spirit of Wolf'}, Options={singlebuff=true, classes={}}},
    -- Aura
    {Group='aura', Spells={'Coldburst Aura', 'Nightchill Aura', 'Icerend Aura', 'Frostreave Aura', 'Frostweave Aura', 'Aura of Life', 'Aura of the Grove'}, Options={aurabuff=true}}, -- adds cold dmg proc to spells

    {Group='summonednuke', Spells={'Expulse Summoned', 'Ward Summoned'}, Options={opt='USENUKES', condition=function() return false end}}, -- summoned mobs only
    {Group='outdoornuke', Spells={'Whirling Wind'}, Options={opt='USENUKES', condition=function() return false end}}, -- outdoor only
    {Group='rainnuke', Spells={'Cascade of Hail', 'Invoke Lightning'}, Options={opt='USEAOE'}},
}

Druid.compositeNames = {['Ecliptic Winds']=true,['Composite Winds']=true,['Dissident Winds']=true,['Dichotomic Winds']=true,}
Druid.allDPSSpellGroups = {'dot1', 'dot2', 'dot3', 'dot4', 'dot5', 'tcnuke', 'nuke1', 'nuke2', 'nuke3', 'nuke4', 'snare'}

Druid.Abilities = {
    -- Heals
    { -- instant heal + hot
        Type='AA',
        Name='Convergence of Spirits',
        Options={heal=true, panic=true}
    },
    {
        Type='AA',
        Name='Peaceful Convergence of Spirits',
        Options={heal=true, panic=true}
    },
    { -- targeted AE splash heal if lunarush down
        Type='AA',
        Name='Blessing of Tunare',
        Options={heal=true, regular=true}
    },
    { -- casts highest survival spell. group heal
        Type='AA',
        Name='Wildtender\'s Survival',
        Options={heal=true, group=true}
    },
    { -- stationary healing ward
        Type='AA',
        Name='Nature\'s Boon',
        Options={heal=true, --[[todo: new category for wards]]}
    },
    { -- group hot, MGB'able
        Type='AA',
        Name='Spirit of the Wood',
        Options={alias='WOOD'}
    },

    -- Burns
    {
        Type='AA',
        Name='Spirits of Nature',
        Options={first=true, delay=1500}
    },
    { -- on emu, maybe live renamed this to great wolf?
        Type='AA',
        Name='Group Spirit of the Black Wolf',
        Options={first=true}
    },
    { -- reduce mana cost, inc crit, mana regen
        Type='AA',
        Name='Group Spirit of the Great Wolf',
        Options={first=true}
    },
    {
        Type='AA',
        Name='Nature\'s Guardian',
        Options={first=true}
    },
    {
        Type='AA',
        Name='Nature\'s Fury',
        Options={first=true}
    },
    {
        Type='AA',
        Name='Nature\'s Boon',
        Options={first=true}
    },
    {
        Type='AA',
        Name='Nature\'s Blessing',
        Options={first=true}
    },
    -- Second burn
    { -- self only
        Type='AA',
        Name='Spirit of the Great Wolf',
        Options={second=true}
    },
    {
        Type='AA',
        Name='Fundament: Second Spire of Nature',
        Options={second=true}
    },
    {
        Type='AA',
        Name='Spire of Nature',
        Options={second=true}
    },

    -- DPS
    {
        Type='Item',
        Name='Nature Walker\'s Scimitar',
        Options={dps=true, emu=true}
    },
    {
        Type='AA',
        Name='Storm Strike',
        Options={dps=true, emu=true}
    },
    {
        Type='AA',
        Name='Nature\'s Fire',
        Options={dps=true}
    },
    {
        Type='AA',
        Name='Nature\'s Bolt',
        Options={dps=true}
    },
    {
        Type='AA',
        Name='Nature\'s Frost',
        Options={dps=true}
    },

    -- Buffs
    {
        Type='AA',
        Name='Wrath of the Wild',
        Options={singlebuff=true, classes={DRU=true,CLR=true,SHM=true,ENC=true,MAG=true,WIZ=true,RNG=true,MNK=true}}
    },
    {
        Type='AA',
        Name='Spirit of the Black Wolf',
        Options={selfbuff=true}
    },
    {
        Type='AA',
        Name='Spirit of the Bear',
        Options={alias='GROWTH'}
    },
    { -- invuln instead of death AA
        Type='AA',
        Name='Preincarnation',
        Options={selfbuff=true}
    },

    -- Defensives
    {
        Type='AA',
        Name='Protection of Direwood',
        Options={defensive=true}
    },
    {
        Type='AA',
        Name='Veil of the Underbrush',
        Options={fade=true}
    },

    -- Debuffs
    {
        Type='AA',
        Name='Blessing of Ro',
        Options={debuff=true, opt='USEDEBUFF'}
    },
    {
        Type='AA',
        Name='Season\'s Wrath',
        Options={debuff=true, opt='USEDEBUFF'}
    },

    {
        Type='AA',
        Name='Call of the Wild',
        Options={rez=state.emu and true or false}
    },
    {
        Type='AA',
        Name='Rejuvenation of Spirits',
        Optionss={rez=not state.emu and true or false}
    },
    {
        Type='Item',
        Name='Staff of Forbidden Rites',
        Options={key='rezStick'}
    },
    {
        Type='AA',
        Name='Summon Companion',
        Options={key='summoncompanion'}
    }
}

function Druid:initSpellRotations()
    self:initBYOSCustom()
    self.spellRotations.standard = {}
    table.insert(self.spellRotations.standard, self.spells.dot1)
    table.insert(self.spellRotations.standard, self.spells.dot2)
    table.insert(self.spellRotations.standard, self.spells.dot3)
    table.insert(self.spellRotations.standard, self.spells.dot4)
    table.insert(self.spellRotations.standard, self.spells.dot5)

    table.insert(self.spellRotations.standard, self.spells.tcnuke)
    table.insert(self.spellRotations.standard, self.spells.nuke1)
    table.insert(self.spellRotations.standard, self.spells.nuke2)
    table.insert(self.spellRotations.standard, self.spells.nuke3)
    table.insert(self.spellRotations.standard, self.spells.nuke4)
end

function Druid:initHeals()
    table.insert(self.healAbilities, self.spells.heal1)
    table.insert(self.healAbilities, self.spells.heal2)
    table.insert(self.healAbilities, self.spells.heal3)
    table.insert(self.healAbilities, self.spells.groupheal1)
    table.insert(self.healAbilities, self.spells.groupheal2)
end

-- Group Spirit of the Black Wolf
-- Group Spirit of the White Wolf

-- storm strike, nuke aa, 30 sec cd
-- spirits of nature, 10min cd, swarm pets

-- spirit of the wood, 15 min cd, regen+ds group
-- peaceful spirit of the wood, 15 min cd, regen+ds group

-- protection of direwood, 15min cd, what is direwood guard
-- spirit of the white wolf, buffs healing
-- spirit of the black wolf, buffs spell damage

-- spirit of the bear, 10min cd, temp hp buff

-- blessing of ro, combined hand+fixation of ro

-- convergence of spirits, 15min cd large heal
-- peaceful convergence of spirits, 15min cd large heal
-- Fundament: Second Spire of Nature -- improved healing (first spire=damage, third spire=group hp buff)
-- improved twincast
-- nature's blessing, 12 seconds all heals crit, 30min cd
-- nature's boon, 30min cd, healing ward
-- nature's fury, 45min cd, improved damage
-- nature's guardian, 22min  cd, temp pet

-- Pre Burn
-- Silent Casting, Distant Conflagration, BP click, Blessing of Ro, Season\'s Wrath

-- Burn Order
-- group wolf, ITC+DV+NF+FA, Nature\'s Sweltering Wrath, Horde of Duskwigs, Sunpyre, Chill of the Dusksage Tender, Tenebrous Sunray

-- Lesser Burn
-- Twincast, Spire of Nature

-- table.insert(self.burnAbilities, self:addAA('Improved Twincast', {first=true}))
-- table.insert(self.burnAbilities, self:addAA('Destructive Vortex', {first=true}))

Druid.Ports = {
    -- 'Ring of Surefall Glade'
    -- 'Ring of Karana'
}
return Druid