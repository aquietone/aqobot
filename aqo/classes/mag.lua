local mq = require('mq')
local class = require('classes.classbase')
local helpers = require('utils.helpers')
local logger = require('utils.logger')
local movement = require('utils.movement')
local timer = require('libaqo.timer')
local abilities = require('ability')
local castUtils = require('cast')
local common = require('common')
local state = require('state')

local Magician = class:new()

--[[
    https://docs.google.com/document/d/1NHtWfaS6WJFurbzzWbzBOZdJ3cKn3F34m1TL5ZO3Vg0/edit#heading=h.5l4x9nc7jc3n
    http://forums.eqfreelance.net/index.php?topic=16654.0

    Sustained:
    1. self:addSpell('servant', {'Ravening Servant', 'Roiling Servant', 'Riotous Servant', 'Reckless Servant', 'Remorseless Servant'})
    2. self:addSpell('many', {'Fusillade of Many', 'Barrage of Many', 'Shockwave of Many', 'Volley of Many', 'Storm of Many'})
    3. self:addSpell('chaotic', {'Chaotic Magma', 'Chaotic Calamity', 'Chaotic Pyroclasm', 'Chaotic Inferno', 'Chaotic Fire'})
    4. self:addSpell('spear', {'Spear of Molten Dacite', 'Spear of Molten Luclinite', 'Spear of Molten Komatiite', 'Spear of Molten Arcronite', 'Spear of Molten Shieldstone'})

    Imp Twincast Burn:
    1. Riotous Servant
    2. Shockwave of Many
    3. Spear of Molten Komatiite
    4. Spear of Molten Arcronite
    (5. Chaotic Pyroclasm)

    Spell Twincast:
    1. Chaotic Pyroclasm
    2. Riotous Servant
    3. Shockwave of Many
    4. Spear of Molten Komatiite

    Sustained additional
    table.insert(self.DPSAbilities, self:addAA('Force of Elements'))
    table.insert(self.DPSAbilities, common.getItem('Molten Komatiite Orb'))
    self:addSpell('twincast', {'Twincast'})
    self:addSpell('alliance', {'Firebound Conjunction', 'Firebound Coalition', 'Firebound Covenant', 'Firebound Alliance'})
    self:addSpell('composite', {'Ecliptic Companion', 'Composite Companion', 'Dichotomic Companion'})

    self:addSpell('malo', {'Malosinera', 'Malosinetra', 'Malosinara', 'Malosinata', 'Malosinete'})

    Burns
    table.insert(self.burnAbilities, self:addAA('Heart of Skyfire')) --Glyph of Destruction
    table.insert(self.burnAbilities, self:addAA('Focus of Arcanum'))
    
    table.insert(self.burnAbilities, self:addAA('Host of the Elements'))
    table.insert(self.burnAbilities, self:addAA('Servant of Ro'))

    Host of the Elements, Servant of Ro -- cast after RS
    Imperative Minion, Imperative Servant -- clicky pets
    self:addSpell('servantclicky', {'Summon Valorous Servant', 'Summon Forbearing Servant', 'Summon Imperative Servant', 'Summon Insurgent Servant', 'Summon Mutinous Servant'})

    table.insert(self.burnAbilities, self:addAA('Spire of the Elements')) -- if no crit buff
    Thaumaturge\'s Focus -- if casting any magic spells'

    Burn AE
    Silent casting

    Firebound Coalition or Chaotic Pyroclasm -> RS -> Host of Elements -> Twincast -> Of Many
    Imp Twincast after spell Twincast
    Forceful Rejuv during ITC

    Pet
    table.insert(self.burnAbilities, self:addAA('Frenzied Burnout'))
    Zeal of the Elements
    Thaumaturgist\'s Infusion after burnout fades

    Buffs
    Elemental Form
    Burnout, Iceflame Rampart, Thaumaturge\'s Unity

    ModRods
    Radiant Modulation Shard, Wand of Freezing Modulation, Elemental Conversion
    Monster Summoning + Reclaim Energy

    Survival
    Shield of Destiny, Shield of Elements, Shared Health, Heart of Frostone

    Fade
    Drape of Shadows, Arcane Whisper

    Pets
    'air', {'Recruitment of Air', 'Conscription of Air', 'Manifestation of Air', 'Embodiment of Air', 'Convocation of Air'}
    'earth', {'Recruitment of Earth', 'Conscription of Earth', 'Manifestation of Earth', 'Embodiment of Earth', 'Convocation of Earth'}
    'fire', {'Recruitment of Fire', 'Conscription of Fire', 'Manifestation of Fire', 'Embodiment of Fire', 'Convocation of Fire'}
    'water', {'Recruitment of Water', 'Conscription of Water', 'Manifestation of Water', 'Embodiment of Water', 'Convocation of Water'}
    'monster', {'Monster Summoning XV', 'Monster Summoning XIV', 'Monster Summoning XIII', 'Monster Summoning XII', 'Monster Summoning XI'}
]]
function Magician:init()
    self.classOrder = {'assist', 'mash', 'debuff', 'cast', 'burn', 'heal', 'recover', 'managepet', 'buff', 'rest', 'rez'}
    self.spellRotations = {standard={},custom={}}
    self:initBase('MAG')

    self:initClassOptions()
    self:loadSettings()
    self:initSpellLines()
    self:initSpellRotations()
    self:initAbilities()
    self:addCommonAbilities()
end

Magician.PetTypes = {Water='waterpet',Earth='earthpet',Air='airpet',Fire='firepet',Monster='monsterpet'}
function Magician:initClassOptions()
    self:addOption('PETTYPE', 'Pet Type', 'Water', self.PetTypes, 'The type of pet to be summoned', 'combobox', nil, 'PetType', 'string')
    self:addOption('EARTHFORM', 'Elemental Form: Earth', false, nil, 'Toggle use of Elemental Form: Earth', 'checkbox', 'FIREFORM', 'EarthForm', 'bool')
    self:addOption('FIREFORM', 'Elemental Form: Fire', true, nil, 'Toggle use of Elemental Form: Fire', 'checkbox', 'EARTHFORM', 'FireForm', 'bool')
    self:addOption('USEFIRENUKES', 'Use Fire Nukes', true, nil, 'Toggle use of fire nuke line', 'checkbox', nil, 'UseFireNukes', 'bool')
    self:addOption('USEMAGICNUKES', 'Use Magic Nukes', false, nil, 'Toggle use of magic nuke line', 'checkbox', nil, 'UseMagicNukes', 'bool')
    self:addOption('USEDEBUFF', 'Use Malo', false, nil, 'Toggle use of Malo', 'checkbox', nil, 'UseDebuff', 'bool')
    self:addOption('SUMMONMODROD', 'Summon Mod Rods', false, nil, 'Toggle summoning of mod rods', 'checkbox', nil, 'SummonModRod', 'bool')
    self:addOption('USEDS', 'Use Group DS', true, nil, 'Toggle casting of group damage shield', 'checkbox', nil, 'UseDS', 'bool')
    self:addOption('USETEMPDS', 'Use Temp DS', true, nil, 'Toggle casting of temporary damage shield', 'checkbox', nil, 'UseTempDS', 'bool')
    self:addOption('USESERVANT', 'Use Servant', true, nil, 'Toggle use of Servant line of spells', 'checkbox', nil, 'UseServant', 'bool')
    self:addOption('USEVEILDS', 'Use Veil DS', false, nil, 'Toggle use of veil DS line of spells', 'checkbox', nil, 'UseVeilDS', 'bool')
    self:addOption('USESKINDS', 'Use Skin DS', false, nil, 'Toggle use of skin DS line of spells', 'checkbox', nil, 'UseSkinDS', 'bool')
    self:addOption('USEPARADOX', 'Use Paradox', true, nil, 'Toggle summoning and use of Paradox item to use in combat', 'checkbox', nil, 'UseParadox', 'bool')
    self:addOption('USEMINION', 'Use Minion', false, nil, 'Toggle summoning and use of minion item to use in combat', 'checkbox', nil, 'UseMinion', 'bool')
    self:addOption('USEGATHER', 'Use Gather', false, nil, 'Toggle use of gather line of spells in combat', 'checkbox', nil, 'UseGather', 'bool')
    self:addOption('USEMODRODS', 'Use Mod Rods', false, nil, 'Toggle summoning of mod rods', 'checkbox', nil, 'UseModRods', 'bool')
    self:addOption('USEDISPEL', 'Use Dispel', true, nil, 'Dispel mobs with Eradicate Magic AA', 'checkbox', nil, 'UseDispel', 'bool')
end
--[[
-- Utility
self:addAA('Call of the Hero')
self:addAA('Perfected Invisibility')
self:addAA('Perfected Invisibility to Undead')
self:addAA('Perfected Levitation')
self:addAA('Group Perfected Invisibility')
self:addAA('Group Perfected Invisibility to Undead')
self:addAA('Mass Group Buff')
self:addAA('Tranquil Blessings')
self:addAA('Summon Companion')
self:addAA('Diminutive Companion')
self:addAA('Summon Modulation Shard') -- MGB mod rods

-- Burns
self:addAA('Heart of Skyfire') -- inc spell / crit dmg, reduce agro, 15 min cd, timer 9
self:addAA('Thaumaturge\'s Focus') -- inc dmg and crit dmg for magic spells, 15 min cd, timer 78
self:addAA('Host of the Elements') -- swarm pets, 10 min cd, timer 7
self:addAA('Servant of Ro') -- summons strong temp pet to nuke, 9 min cd, timer 6
self:addAA('Spire of Elements') -- inc crit chance + melee proc for group, 7:30 cd, timer 40
self:addAA('Silent Casting')
self:addAA('Improved Twincast') -- 15 min cd, timer 76
self:addAA('Focus of Arcanum')
self:addAA('Forceful Rejuvenation')

-- Defensives
self:addAA('Companion\'s Shielding') -- large pet heal + 72 seconds of 50% dmg absorb for self, 15 min cd, timer 8
self:addAA('Heart of Froststone') -- absorb 70% inc spell/melee, 15 min cd, timer 16
self:addAA('Shield of the Elements') -- 40k heal + hot, absorbs 100% of dmg up to 125k, 15 min cd, timer 11
self:addAA('Host in the Shell') -- pet rune, 25% dmg absorb, 4 min cd, timer 10
self:addAA('Dimensional Shield') -- absorb 50% melee dmg, 20 min, timer 17

-- Heals
self:addAA('Mend Companion')
self:addAA('Second Wind Ward') -- DI for pet, procs big heal below 20% hp, 20 min cd, timer 43

-- Pet Buffs
self:addAA('Velocity') -- pet sow

-- Buffs
self:addAA('Elemental Form') -- self buff, adds some procs, mana, hp
self:addAA('Thaumaturge\'s Unity') -- self buffs, chaotic largesse, ophiolite bodyguard, shield of shadow, relentless guardian

-- Leap
self:addAA('Summoner\'s Step')

-- Fades
self:addAA('Companion of Necessity') -- Fade pet, 10 min cd, timer 3
self:addAA('Drape of Shadows') -- fade
self:addAA('Arcane Whisper') -- large agro reducer, 10 min cd, timer 35

-- Rest
self:addAA('Elemental Conversion') -- 148k pet hp for 35k mana, 15 min cd, timer 42

-- Mash
self:addAA('Force of Elements') -- 40k nuke, 20 sec cd, timer 73
self:addAA('Turn Summoned') -- large summoned nuke, 5 min cd, timer 5

self:addAA('Companion\'s Aegis')
self:addAA('Companion\'s Discipline')
self:addAA('Companion\'s Fortification')
self:addAA('Companion\'s Fury')
self:addAA('Companion\'s Intervening Divine Aura')
self:addAA('Companion\'s Suspension')

-- Debuff spell replacers
self:addAA('Malaise') -- aa malo
self:addAA('Wind of Malaise') -- aa aoe malo
self:addAA('Eradicate Magic') -- dispel
]]
Magician.SpellLines = {
    {-- Main fire nuke. Slot 1/2
        Group='spear',
        NumToPick=2,
        Spells={'Spear of Molten Dacite', 'Spear of Molten Luclinite', 'Spear of Molten Komatiite', 'Spear of Molten Arcronite', 'Spear of Molten Shieldstone', --[[emu cutoff]] 'Spear of Ro', 'Sun Vortex', 'Seeking Flame of Seukor', 'Char', 'Cinder Bolt', 'Blaze', 'Bolt of Flame', 'Shock of Flame', 'Flame Bolt', 'Burn', 'Burst of Flame'},
        Options={opt='USEFIRENUKES', Gems={function() return not Magician:isEnabled('USEAOE') and 1 or nil end,2}}
    },
    {-- Main AE nuke. Slot 1
        Group='beam',
        Spells={'Beam of Molten Dacite', 'Beam of Molten Olivine', 'Beam of Molten Komatiite', 'Beam of Molten Rhyolite', 'Beam of Molten Shieldstone', --[[emu cutoff]] 'Column of Fire', 'Fire Flux'},
        Options={opt='USEAOE', Gem=1}
    },
    {-- Strong elemental temporary pet summon. Slot 3
        Group='servant',
        Spells={'Ravening Servant', 'Roiling Servant', 'Riotous Servant', 'Reckless Servant', 'Remorseless Servant', --[[emu cutoff]] 'Raging Servant', 'Rampaging Servant'},
        Options={opt='USESERVANT', Gem=3}
    },
    {-- Large nuke, triggers beneficial buff chance. Slot 4
        Group='chaotic',
        Spells={'Chaotic Magma', 'Chaotic Calamity', 'Chaotic Pyroclasm', 'Chaotic Inferno', 'Chaotic Fire', --[[emu cutoff]] 'Burning Earth'},
        Options={Gem=4}
    },
    {-- Large nuke based on # of summoned pets. Slot 5
        Group='ofmany',
        Spells={'Fusillade of Many', 'Barrage of Many', 'Shockwave of Many', 'Volley of Many', 'Storm of Many', --[[emu cutoff]] },
        Options={Gem=5}
    },
    {-- Main magic nuke. Slot 6
        Group='shock',
        Spells={'Shock of Memorial Steel', 'Shock of Carbide Steel', 'Shock of Burning Steel', 'Shock of Arcronite Steel', 'Shock of Darksteel', --[[emu cutoff]] 'Blade Strike', 'Rock of Taelosia', 'Shock of Steel', 'Shock of Swords', 'Shock of Spikes', 'Shock of Blades'},
        Options={opt='USEMAGICNUKES', Gem=6}
    },
    {-- Summons clicky nuke orb with 10 charges. Slot 7
        Group='orb',
        Spells={'Summon Molten Komatiite Orb', 'Summon Firebound Orb', --[[emu cutoff]] 'Summon: Molten Orb', 'Summon: Lava Orb'},
        Options={Gem=7, summonMinimum=1, nodmz=true, pause=true, alias='NUKEORB', selfbuff=true}
    },
    {-- Large DS 10 minutes. Slot 8
        Group='veilds',
        Spells={'Igneous Veil', 'Volcanic Veil', 'Exothermic Veil', 'Skyfire Veil', --[[emu cutoff]]},
        Options={opt='USEVEILDS', Gem=8}
    },
    {-- Regular group DS. Slot 9
        Group='groupds',
        Spells={'Circle of Forgefire Coat', 'Circle of Emberweave Coat', 'Circle of Igneous Skin', 'Circle of the Inferno', 'Circle of Flameweaving', --[[emu cutoff]] 'Circle of Brimstoneskin', 'Circle of Fireskin'},
        Options={opt='USEDS', Gem=function() return not Magician:isEnabled('USESKINDS') and 9 or nil end, alias='DS'}
    },
    {-- 30 seconds, 4 charges large DS. Slot 9
        Group='skinds',
        Spells={'Boiling Skin', 'Scorching Skin', 'Burning Skin', 'Blistering Skin', 'Corona Skin', --[[emu cutoff]]},
        Options={opt='USESKINDS', Gem=9}
    },
    {-- Twincast next spell. Slot 10
        Group='twincast',
        Spells={'Twincast'},
        Options={Gem=10}
    },
    {-- Recover mana, long cast time. Slot 11
        Group='gather',
        Spells={'Gather Zeal', 'Gather Vigor', 'Gather Potency', 'Gather Capability'},
        Options={Gem=11}
    },
    {-- Strong pet buff. Slot 12
        Group='composite',
        Spells={'Ecliptic Companion', 'Composite Companion', 'Dissident Companion', 'Dichotomic Companion'},
        Options={Gem=12}
    },
    {-- Another clicky nuke. Slot 13
        Group='paradox',
        Spells={'Grant Voidfrost Paradox', 'Grant Frostbound Paradox'},
        Options={opt='USEPARADOX', Gem=function() return not Magician:isEnabled('USEALLIANCE') and 13 or nil end, summonMinimum=1, nodmz=true, pause=true}
    },
    {-- Slot 13
        Group='alliance',
        Spells={'Firebound Conjunction', 'Firebound Coalition', 'Firebound Covenant', 'Firebound Alliance'},
        Options={opt='USEALLIANCE', Gem=13}
    },
    --if state.emu and not mq.TLO.FindItem('Glyphwielder\'s Sleeves of the Summoner')() then
    {
        Group='shield',
        Spells={'Shield of Inescapability', 'Shield of Inevitability', 'Shield of Destiny', 'Shield of Order', 'Shield of Consequence', --[[emu cutoff]] 'Elemental Aura'},
        Options={selfbuff=true}
    },
    {
        Group='minion',
        Spells={'Summon Valorous Servant', 'Summon Forbearing Servant', 'Summon Imperative Servant', 'Summon Insurgent Servant', 'Summon Mutinous Servant'},
        Options={opt='USEMINION', summonMinimum=1, nodmz=true, pause=true}
    },
    {
        Group='waterpet',
        Spells={'Recruitment of Water', 'Conscription of Water', 'Manifestation of Water', 'Embodiment of Water', 'Convocation of Water', --[[emu cutoff]]
                'Child of Water', 'Servant of Marr', 'Greater Vocaration: Water', 'Vocarate: Water', 'Conjuration: Water',
                'Lesser Conjuration: Water', 'Minor Conjuration: Water', 'Greater Summoning: Water',
                'Summoning: Water', 'Lesser Summoning: Water', 'Minor Summoning: Water', 'Elemental: Water', 'Elementaling: Water', 'Elementalkin: Water'},
        Options={}
    },
    {
        Group='airpet',
        Spells={'Recruitment of Air', 'Conscription of Air', 'Manifestation of Air', 'Embodiment of Air', 'Convocation of Air', --[[emu cutoff]] 'Minor Conjuration: Air', 'Greater Summoning: Air', 'Summoning: Air', 'Lesser Summoning: Air', 'Minor Summoning: Air', 'Elemental: Air', 'Elementaling: Air', 'Elementalkin: Air'},
        Options={}
    },
    {
        Group='earthpet',
        Spells={'Recruitment of Earth', 'Conscription of Earth', 'Manifestation of Earth', 'Embodiment of Earth', 'Convocation of Earth', --[[emu cutoff]] 'Minor Conjuration: Earth', 'Greater Summoning: Earth', 'Summoning: Earth', 'Lesser Summoning: Earth', 'Minor Summoning: Earth', 'Elemental: Earth', 'Elementaling: Earth', 'Elementalkin: Earth'},
        Options={}
    },
    {
        Group='firepet',
        Spells={'Recruitment of Fire', 'Conscription of Fire', 'Manifestation of Fire', 'Embodiment of Fire', 'Convocation of Fire', --[[emu cutoff]] 'Minor Conjuration: Fire', 'Greater Summoning: Fire', 'Summoning: Fire', 'Lesser Summoning: Fire', 'Minor Summoning: Fire', 'Elemental: Fire', 'Elementaling: Fire', 'Elementalkin: Fire'},
        Options={}
    },
    {
        Group='monsterpet',
        Spells={'Monster Summoning XV', 'Monster Summoning XIV', 'Monster Summoning XIII', 'Monster Summoning XII', 'Monster Summoning XI', --[[emu cutoff]]},
        Options={}
    },
    {
        Group='petbuff',
        Spells={'Burnout XVI', 'Burnout XV', 'Burnout XIV', 'Burnout XIII', 'Burnout XII', --[[emu cutoff]] 'Elemental Fury', 'Burnout V', 'Burnout IV', 'Burnout III', 'Burnout II', 'Burnout'},
        Options={petbuff=true}
    },
    {
        Group='petds',
        Spells={'Iceflame Pallisade', 'Iceflame Barricade', 'Iceflame Rampart', 'Iceflame Keep', 'Iceflame Armaments', --[[emu cutoff]] 'Iceflame Guard'},
        Options={petbuff=true}
    },
    {
        Group='petheal',
        Spells={'Renewal of Shoru', 'Renewal of Iilivina', 'Renewal of Evreth', 'Renewal of Ioulin', 'Renewal of Calix', --[[emu cutoff]] 'Planar Renewal', 'Refresh Summoning', 'Renew Summoning', 'Renew Elements'},
        Options={opt='HEALPET', pet=50, heal=true}
    },
    {-- aborb 9 smaller hits, spellslot 1
        Group='petshield',
        Spells={'Aegis of Valorforged', 'Aegis of Rumblecrush', 'Aegis of Orfur', 'Aegis of Zeklor', 'Aegis of Japac'},
        Options={}
    },
    {--absorb 5 larger hits, spellslot 2
        Group='auspice',
        Spells={'Auspice of Valia', 'Auspice of Kildrukaun', 'Auspice of Esianti', 'Auspice of Eternity'},
        Options={}
    },
    {-- large absorb but also large snare
        Group='petbigshield',
        Spells={'Kanoite Stance', 'Pyroxene Stance', 'Rhyolite Stance', 'Shieldstone Stance'},
        Options={}
    },

    -- self hp buff, blocks shm
    {Group='hpbuff', Spells={'Shield of Memories', 'Shield of Shadow', 'Shield of Restless Ice', 'Shield of Scales', 'Shield of the Pellarus', --[[emu cutoff]] 'Greater Shielding', 'Major Shielding', 'Shielding', 'Lesser Shielding', 'Minor Shielding'}, Options={}},
    {Group='acregen', Spells={'Courageous Guardian', 'Relentless Guardian', 'Restless Guardian', 'Burning Guardian', 'Praetorian Guardian', --[[emu cutoff]] 'Phantom Shield', 'Xegony\'s Phantasmal Guard'}, Options={selfbuff=true}}, -- self regen/ac buff
    {Group='manaregen', Spells={'Valiant Symbiosis', 'Relentless Symbiosis', 'Restless Symbiosis', 'Burning Symbiosis', 'Dark Symbiosis', --[[emu cutoff]] 'Elemental Simulacrum', 'Elemental Siphon'}}, -- self mana regen
    {Group='bodyguard', Spells={'Valorforged Bodyguard', 'Ophiolite Bodyguard', 'Pyroxenite Bodyguard', 'Rhylitic Bodyguard', 'Shieldstone Bodyguard'}, Options={}}, -- proc pet when hit

    -- old emu stuff
    {Group='petstrbuff', Spells={'Rathe\'s Strength', 'Earthen Strength'}, Options={skipifbuff='Champion', petbuff=true}},
    {Group='bigds', Spells={'Frantic Flames', 'Pyrilen Skin', 'Burning Aura'}, Options={opt='USETEMPDS', singlebuff=true, classes={WAR=true,SHD=true,PAL=true}}},
    -- Chance to increase spell power of next nuke
    {Group='prenuke', Spells={'Fickle Conflagration', --[[emu cutoff]] 'Fickle Fire'}, Options={opt='USEFIRENUKES'}},

    {Group='modrod', Spells={'Rod of Courageous Modulation', 'Sickle of Umbral Modulation', 'Wand of Frozen Modulation', 'Wand of Burning Modulation', 'Wand of Dark Modulation'}, Options={opt='USEMODRODS', summonMinimum=1, nodmz=true, pause=true}},
    {Group='massmodrod', Spells={'Mass Dark Transvergence'}, Options={opt='USEMODRODS', summonMinimum=1, nodmz=true, pause=true}},
    {Group='armor', Spells={'Grant Alloy\'s Plate', 'Grant the Centien\'s Plate', 'Grant Ocoenydd\'s Plate', 'Grant Wirn\'s Plate', 'Grant Thassis\' Plate', --[[emu cutoff]] 'Grant Spectral Plate'}, Options={alias='ARMOR'}}, -- targeted, Summon Folded Pack of Spectral Plate
    {Group='weapons', Spells={'Grant Goliath\'s Armaments', 'Grant Shak Dathor\'s Armaments', 'Grant Yalrek\'s Armaments', 'Grant Wirn\'s Armaments', 'Grant Thassis\' Armaments', --[[emu cutoff]] 'Grant Spectral Armaments'}, Options={alias='ARM'}}, -- targeted, Summons Folded Pack of Spectral Armaments
    {Group='jewelry', Spells={'Grant Ankexfen\'s Heirlooms', 'Grant the Diabo\'s Heirlooms', 'Grant Crystasia\'s Heirlooms', 'Grant Ioulin\'s Heirlooms', 'Grant Calix\'s Heirlooms', --[[emu cutoff]] 'Grant Enibik\'s Heirlooms'}, Options={alias='JEWELRY'}}, -- targeted, Summons Folded Pack of Enibik's Heirlooms, includes muzzle
    {Group='belt', Spells={'Summon Crystal Belt'}}, -- Summoned: Crystal Belt
    {Group='mask', Spells={'Grant Visor of Shoen'}, Options={}},
    {Group='bundle', Spells={'Grant Bristlebane\'s Festivity Bundle'}, Options={}},
    -- Cauldron of Endless Abundance

    -- Other BYOS spells
    {Group='ofsand', Spells={'Ruination of Sand', 'Destruction of Sand', 'Crash of Sand', 'Volley of Sand'}, Options={opt='USEFIRENUKES'}}, -- some one-off nuke??
    {Group='firebolt', Spells={'Bolt of Molten Dacite', 'Bolt of Molten Olivine', 'Bolt of Molten Komatiite', 'Bolt of Skyfire', 'Bolt of Molten Shieldstone'}, Options={'USEFIRENUKES'}},
    -- random fire nuke
    {Group='sands', Spells={'Cremating Sands', 'Ravaging Sands', 'Incinerating Sands', 'Blistering Sands', 'Searing Sands'}, Options={opt='USEFIRENUKES'}},
    -- summoned mob nuke
    {Group='summonednuke', Spells={'Dismantle the Unnatural', 'Unmend the Unnatural', 'Obliterate the Unnatural', 'Repudiate the Unnatural', 'Eradicate the Unnatural', 'Expel Summoned', 'Dismiss Summoned', 'Expulse Summoned', 'Ward Summoned'}, Options={opt='USEMAGICNUKES'}},
    -- bolt magic nuke
    {Group='magicbolt', Spells={'Luclinite Bolt', 'Komatiite Bolt', 'Korascian Bolt', 'Meteoric Bolt'}, Options={opt='USEMAGICNUKES'}},
    -- magic nuke + malo
    {Group='magicmalonuke', Spells={'Memorial Steel Malosinera', 'Carbide Malosinetra', 'Burning Malosinara', 'Arcronite Malosinata', 'Darksteel Malosenete'}, Options={opt='USEMAGICNUKES'}},
    -- targeted AE fire rain
    {Group='firerain', Spells={'Rain of Molten Dacite', 'Rain of Molten Olivine', 'Rain of Molten Komatiite', 'Rain of Molten Rhyolite', 'Coronal Rain', 'Rain of Lava', 'Rain of Fire'}, Options={opt='USEAOE', Gem=function(lvl) return lvl <= 60 and 4 or nil end}},
    -- targeted AE magic rain
    {Group='magicrain', Spells={'Rain of Kukris', 'Rain of Falchions', 'Rain of Scimitars', 'Rain of Knives', 'Rain of Cutlasses', 'Rain of Spikes', 'Rain of Blades'}, Options={opt='USEAOE', Gem=function(lvl) return lvl <= 60 and 5 or nil end}},
    {Group='pbaefire', Spells={'Fiery Blast', 'Flaming Blast', 'Burning Blast', 'Searing Blast', 'Flame Flux'}, Options={opt='USEAOE'}},
    {Group='frontalmagic', Spells={'Beam of Kukris', 'Beam of Falchions', 'Beam of Scimitars', 'Beam of Knives'}, Options={opt='USEAOE'}},
    -- pet promised heal
    {Group='pethealpromise', Spells={'Promised Reconstitution', 'Promised Relief', 'Promised Healing', 'Promised Alleviation', 'Promised Invigoration'}, Options={opt='HEALPET'}},
    -- random chance to heal all pets in area 
    {Group='chaoticheal', Spells={'Chaotic Magnanimity', 'Chaotic Largesse', 'Chaotic Bestowal', 'Chaotic Munificence', 'Chaotic Benefaction'}, Options={opt='HEALPET'}},
    -- minion summon clicky 2
    {Group='minion2', Spells={'Summon Valorous Minion', 'Summon Forbearing Minion', 'Summon Imperative Minion', 'Summon Insurgent Minion', 'Summon Mutinous Minion'}, Options={opt='USEMINION'}},
    {Group='dispel', Spells={'Nullify Magic', 'Cancel Magic'}, Options={debuff=true, dispel=true, opt='USEDISPEL'}},
    {Group='mala', Spells={'Malaise'}, Options={debuff=true, opt='USEDEBUFF', Gem=function(lvl) return lvl <= 60 and 6 or nil end}}
}

Magician.compositeNames = {['Ecliptic Companion']=true, ['Composite Companion']=true, ['Dissident Companion']=true, ['Dichotomic Companion']=true}
Magician.allDPSSpellGroups = {'servant', 'ofmany', 'chaotic', 'shock', 'spear1', 'spear2', 'prenuke', 'ofsand', 'firebolt', 'sands', 'summonednuke', 'magicbolt', 'magicmalonuke', 'beam', 'firerain', 'magicrain', 'pbaefire', 'frontalmagic'}

Magician.Abilities = {
    {
        Type='AA',
        Name='Summon Companion',
        Options={key='summoncompanion'}
    },

    {
        Type='AA',
        Name='Force of Elements',
        Options={dps=true}
    },

    -- Burns
    {
        Type='AA',
        Name='Fundament: First Spire of the Elements',
        Options={first=true}
    },
    {
        Type='AA',
        Name='Host of the Elements',
        Options={first=true, delay=1500}
    },
    {
        Type='AA',
        Name='Servant of Ro',
        Options={first=true, delay=500}
    },
    {
        Type='AA',
        Name='Frenzied Burnout',
        Options={first=true}
    },
    {
        Type='AA',
        Name='Improved Twincast',
        Options={first=true}
    },

    -- Buffs
    {
        Type='AA',
        Name='Elemental Form: Earth',
        Options={selfbuff=true, opt='EARTHFORM'}
    },
    {
        Type='AA',
        Name='Elemental Form: Fire',
        Options={opt='FIREFORM', selfbuff=true}
    },
    {
        Type='AA',
        Name='Large Modulation Shard',
        Options={selfbuff=true, opt='SUMMONMODROD', summonMinimum=1, nodmz=true,}
    },
    {
        Type='AA',
        Name='Fire Core',
        Options={combatbuff=true}
    },
    {
        Type='Item',
        Name='Focus of Primal Elements',
        Options={petbuff=true, CheckFor='Elemental Conjunction'}
    },
    {
        Type='Item',
        Name='Staff of Elemental Essence',
        Options={petbuff=true, CheckFor='Elemental Conjunction'}
    },
    {
        Type='AA',
        Name='Aegis of Kildrukaun',
        Options={petbuff=true}
    },
    {
        Type='AA',
        Name='Fortify Companion',
        Options={petbuff=true}
    },

    -- Debuffs
    {
        Type='AA',
        Name='Malosinete',
        Options={debuff=true, opt='USEDEBUFF'}
    },

    -- Defensives
    {
        Type='AA',
        Name='Companion of Necessity',
        Options={fade=true}
    }
}

function Magician:initSpellRotations()
    self:initBYOSCustom()
    self.spellRotations.standard = {}
    table.insert(self.spellRotations.standard, self.spells.servant)
    table.insert(self.spellRotations.standard, self.spells.ofmany)
    table.insert(self.spellRotations.standard, self.spells.chaotic)
    table.insert(self.spellRotations.standard, self.spells.shock)
    table.insert(self.spellRotations.standard, self.spells.spear1)
    table.insert(self.spellRotations.standard, self.spells.spear2)
    table.insert(self.spellRotations.standard, self.spells.beam)
end

function Magician:getPetSpell()
    return self.spells[self.PetTypes[self:get('PETTYPE')]]
end

function Magician:pullCustom()
    movement.stop()
    mq.cmd('/pet attack')
    mq.cmd('/pet swarm')
    mq.delay(1000)
end

-- Below pet arming code shamelessly stolen from Rekka and E3Next
local petToys = {
    weapons = {
        ['Grant Goliath\'s Armaments'] = {
            foldedBag = 'Folded Pack of Goliath\'s Armaments',
            fire = '',
            water = '',
            magic = '',
            aggro = '',
            deaggro = '',
        },
        ['Grant Shak Dathor\'s Armaments'] = {
            foldedBag = 'Folded Pack of Shak Dathor\'s Armaments',
            fire = 'Summoned: Shadewrought Fireblade',
            water = 'Summoned: Shadewrought Ice Spear',
            magic = 'Summoned: Shadewrought Staff',
            aggro = 'Summoned: Shadewrought Rageaxe',
            deaggro = 'Summoned: Shadewrought Mindmace',
        },
        ['Grant Yalrek\'s Armaments'] = {
            foldedBag = 'Folded Pack of Yalrek\'s Armaments',
            fire = 'Summoned: Silver Fireblade',
            water = 'Summoned: Silver Iceblade',
            magic = 'Summoned: Silver Shortsword',
            aggro = 'Summoned: Silver Ragesword',
            deaggro = 'Summoned: Silver Mindblade',
        },
        ['Grant Wirn\'s Armaments'] = {
            foldedBag = 'Folded Pack of Wirn\'s Armaments',
            fire = 'Summoned: Gorstruck Fireblade',
            water = 'Summoned: Gorstruck Iceblade',
            magic = 'Summoned: Gorstruck Shortsword',
            aggro = 'Summoned: Gorstruck Ragesword',
            deaggro = 'Summoned: Gorstruck Mindblade',
        },
        ['Grant Thassis\'s Armaments'] = {
            foldedBag = 'Folded Pack of Thalassic Armaments',
            fire = 'Summoned: Thalassic Fireblade',
            water = 'Summoned: Thalassic Iceblade',
            magic = 'Summoned: Thalassic Shortsword',
            aggro = 'Summoned: Thalassic Ragesword',
            deaggro = 'Summoned: Thalassic Mindblade',
        },
        ['Grant Spectral Armaments'] = {
            foldedBag = 'Folded Pack of Spectral Armaments',
            fire = 'Summoned: Fist of Flame',
            water = 'Summoned: Orb of Chilling Water',
            shield = 'Summoned: Buckler of Draining Defense',
            aggro = 'Summoned: Short Sword of Warding',
            slow = 'Summoned: Mace of Temporal Distortion',
            malo = 'Summoned: Spear of Maliciousness',
            dispel = 'Summoned: Wand of Dismissal',
            snare = 'Summoned: Tendon Carve,'
        }
    },
    armor = {
        ['Grant Alloy\'s Plate'] = {
            foldedBag = 'Folded Pack of Alloy\'s Plate'
        },
        ['Grant the Centien\'s Plate'] = {
            foldedBag = 'Folded Pack of the Centien\'s Plate'
        },
        ['Grant Ocoenydd\'s Plate'] = {
            foldedBag = 'Folded Pack of Ocoenydd\'s Plate'
        },
        ['Grant Wirn\'s Plate'] = {
            foldedBag = 'Folded Pack of Wirn\'s Plate'
        },
        ['Grant Thassis\' Plate'] = {
            foldedBag = 'Folded Pack of Thalassic Plate'
        },
        ['Grant Spectral Plate'] = {
            foldedBag = 'Folded Pack of Spectral Plate'
        }
    },
    jewelry = {
        ['Grant Ankexfen\'s Heirlooms'] = {
            foldedBag = 'Folded Pack of Ankexfen\'s Heirlooms'
        },
        ['Grant the Diabo\'s Heirlooms'] = {
            foldedBag = 'Folded Pack of Diabo\'s Heirlooms'
        },
        ['Grant Crystasia\'s Heirlooms'] = {
            foldedBag = 'Folded Pack of Crystasia\'s Heirlooms'
        },
        ['Grant Ioulin\'s Heirlooms'] = {
            foldedBag = 'Folded Pack of Ioulin\'s Heirlooms'
        },
        ['Grant Calix\'s Heirlooms'] = {
            foldedBag = 'Folded Pack of Calix\'s Heirlooms'
        },
        ['Grant Enibik\'s Heirlooms'] = {
            foldedBag = 'Folded Pack of Enibik\'s Heirlooms'
        }
    },
    belts = {

    },
    masks = {

    }
}
local weaponBag = 'Pouch of Quellious'
local disenchantedBag = 'Huge Disenchanted Backpack'
local summonedItemMap = {
    ['Grant Shak Dathor\'s Armaments'] = 'Folded Pack of Shak Dathor\'s Armaments',
    ['Grant Spectral Armaments'] = 'Folded Pack of Spectral Armaments',
    ['Grant Spectral Plate'] = 'Folded Pack of Spectral Plate',
    ['Grant Enibik\'s Heirlooms'] = 'Folded Pack of Enibik\'s Heirlooms',
}
local EnchanterPetPrimaryWeaponId = 10702

-- Checks pets for items and re-equips if necessary.
local armPetTimer = timer:new(60000)
function Magician:autoArmPets()
    if common.hostileXTargets() then return end
    if not self:isEnabled('ARMPETS') or not self.spells.weapons then return end
    if not armPetTimer:expired() then return end
    armPetTimer:reset()

    self:armPets()
end

function Magician:clearCursor()
    while mq.TLO.Cursor() do
        mq.cmd('/autoinv')
        mq.delay(100)
    end
end

function Magician:armPets()
    if mq.TLO.Cursor() then self:clearCursor() end
    if mq.TLO.Cursor() then
        logger.info('Unable to clear cursor, not summoning pet toys.')
        return
    end
    if not self.petWeapons then return end
    logger.info('Begin arming pets')
    state.paused = true
    local restoreGem1 = {Name=mq.TLO.Me.Gem(12)()}
    local restoreGem2 = {Name=mq.TLO.Me.Gem(11)()}
    local restoreGem3 = {Name=mq.TLO.Me.Gem(10)()}
    local restoreGem4 = {Name=mq.TLO.Me.Gem(9)()}

    local petPrimary = mq.TLO.Pet.Primary()
    local petID = mq.TLO.Pet.ID()
    if petID > 0 and petPrimary == 0 then
        state.armPet = petID
        state.armPetOwner = mq.TLO.Me.CleanName()
        local weapons = self.petWeapons.Self
        if weapons then
            self:armPet(petID, weapons, 'Me')
        end
    end

    for owner,weapons in pairs(self.petWeapons) do
        if owner ~= mq.TLO.Me.CleanName() then
            local ownerSpawn = mq.TLO.Spawn('pc ='..owner)
            if ownerSpawn() then
                local ownerPetID = ownerSpawn.Pet.ID()
                local ownerPetDistance = ownerSpawn.Pet.Distance3D() or 300
                local ownerPetLevel = ownerSpawn.Pet.Level() or 0
                local ownerPetPrimary = ownerSpawn.Pet.Primary() or -1
                if ownerPetID > 0 and ownerPetDistance < 50 and ownerPetLevel > 0 and (ownerPetPrimary == 0 or ownerPetPrimary == EnchanterPetPrimaryWeaponId) then
                    state.armPet = ownerPetID
                    state.armPetOwner = owner
                    mq.delay(2000, function() return self.spells.weapons:isReady() == abilities.IsReady.SHOULD_CAST end)
                    self:armPet(ownerPetID, weapons, owner)
                end
            end
        end
    end
    if mq.TLO.Me.Gem(12)() ~= restoreGem1.Name then abilities.swapSpell(restoreGem1, 12) end
    if mq.TLO.Me.Gem(11)() ~= restoreGem2.Name then abilities.swapSpell(restoreGem2, 11) end
    if mq.TLO.Me.Gem(10)() ~= restoreGem3.Name then abilities.swapSpell(restoreGem3, 10) end
    if mq.TLO.Me.Gem(9)() ~= restoreGem4.Name then abilities.swapSpell(restoreGem4, 9) end
    state.paused = false
end

function Magician:armPetRequest(requester)
    if not self.petWeapons then return end
    local weapons = self.petWeapons[requester]
    if not weapons then return end
    local ownerSpawn = mq.TLO.Spawn('pc ='..requester)
    if ownerSpawn() then
        local ownerPetID = ownerSpawn.Pet.ID()
        local ownerPetDistance = ownerSpawn.Pet.Distance3D() or 300
        local ownerPetLevel = ownerSpawn.Pet.Level() or 0
        local ownerPetPrimary = ownerSpawn.Pet.Primary() or -1
        if ownerPetID > 0 and ownerPetDistance < 50 and ownerPetLevel > 0 and (ownerPetPrimary == 0 or ownerPetPrimary == EnchanterPetPrimaryWeaponId) then
            state.paused = true
            local restoreGem1 = {Name=mq.TLO.Me.Gem(12)()}
            local restoreGem2 = {Name=mq.TLO.Me.Gem(11)()}
            local restoreGem3 = {Name=mq.TLO.Me.Gem(10)()}
            local restoreGem4 = {Name=mq.TLO.Me.Gem(9)()}
            state.armPet = ownerPetID
            state.armPetOwner = requester
            mq.delay(2000, function() return self.spells.weapons:isReady() == abilities.IsReady.SHOULD_CAST end)
            self:armPet(ownerPetID, weapons, requester)
            if mq.TLO.Me.Gem(12)() ~= restoreGem1.Name then abilities.swapSpell(restoreGem1, 12) end
            if mq.TLO.Me.Gem(11)() ~= restoreGem2.Name then abilities.swapSpell(restoreGem2, 12) end
            if mq.TLO.Me.Gem(10)() ~= restoreGem3.Name then abilities.swapSpell(restoreGem3, 12) end
            if mq.TLO.Me.Gem(9)() ~= restoreGem4.Name then abilities.swapSpell(restoreGem4, 12) end
            state.paused = false
        end
    end
end

function Magician:armPet(petID, weapons, owner)
    logger.info('Attempting to arm pet %s for %s', mq.TLO.Spawn('id '..petID).CleanName(), owner)

    local myX, myY, myZ = mq.TLO.Me.X(), mq.TLO.Me.Y(), mq.TLO.Me.Z()
    if not self:giveWeapons(petID, weapons or 'water|fire') then
        movement.navToLoc(myX, myY, myZ, nil, 2000)
        if state.isExternalRequest then
            logger.info('tell %s There was an error arming your pet', state.requester)
        else
            logger.info('there was an issue with arming a pet')
        end
        return
    end
    if state.emu then
        if self.spells.armor then
            mq.delay(3000, function() return self.spells.armor:isReady() == abilities.IsReady.SHOULD_CAST end)
            if not self:giveOther(petID, self.spells.armor, 'armor') then return end
        end
        if self.spells.jewelry then
            mq.delay(3000, function() return self.spells.jewelry:isReady() == abilities.IsReady.SHOULD_CAST end)
            if not self:giveOther(petID, self.spells.jewelry, 'jewelry') then return end
        end
        if mq.TLO.FindItemCount('=Gold')() >= 1 then
            logger.info('have gold to give!')
            mq.cmdf('/mqt id %s', petID)
            self:pickupWeapon('Gold')
            if mq.TLO.Cursor() == 'Gold' then
                self:giveCursorItemToTarget()
            else
                self:clearCursor()
            end
        end
    end

    local petSpawn = mq.TLO.Spawn('id '..petID)
    if petSpawn() then
        logger.info('Finished arming %s', petSpawn.CleanName())
    end

    movement.navToLoc(myX, myY, myZ, nil, 2000)
end

function Magician:giveWeapons(petID, weaponString)
    local weapons = helpers.split(weaponString, '|')
    local primary = petToys.weapons[self.spells.weapons.BaseName][weapons[1]]
    local secondary = petToys.weapons[self.spells.weapons.BaseName][weapons[2]]
    logger.info('weapons: %s %s', primary, secondary)

    mq.cmdf('/mqt 0')
    if not self:checkForWeapons(primary, secondary) then
        return false
    end

    mq.cmdf('/mqt id %s', petID)
    if mq.TLO.Target.ID() == petID then
        logger.info('Give primary weapon %s to pet %s', primary, petID)
        self:pickupWeapon(primary)
        if mq.TLO.Cursor() == primary then
            self:giveCursorItemToTarget()
        else
            self:clearCursor()
        end
        if not self:checkForWeapons(primary, secondary) then
            return false
        end
        logger.info('Give secondary weapon %s to pet %s', secondary, petID)
        self:pickupWeapon(secondary)
        mq.cmdf('/mqt id %s', petID)
        if mq.TLO.Cursor() == secondary then
            self:giveCursorItemToTarget()
        else
            self:clearCursor()
        end
        self:giveCursorItemToTarget()
    else
        return false
    end
    return true
end

-- If specifying 2 different weapons where only 1 of each is in the bag, this
-- will end up summoning two bags
function Magician:checkForWeapons(primary, secondary)
    local foundPrimary = mq.TLO.FindItem('='..primary)
    local foundSecondary = mq.TLO.FindItem('='..secondary)
    logger.info('Check inventory for weapons %s %s', primary, secondary)
    if not foundPrimary() or not foundSecondary() then
        local foundWeaponBag = mq.TLO.FindItem('='..weaponBag)
        if foundWeaponBag() then
            if not self:safeToDestroy(foundWeaponBag) then return false end
            mq.cmdf('/nomodkey /itemnotify "%s" leftmouseup', weaponBag)
            mq.delay(1000, function() return mq.TLO.Cursor() end)
            if mq.TLO.Cursor.ID() == foundWeaponBag.ID() then
                mq.cmd('/destroy')
            else
                logger.info('Unexpected item on cursor when trying to destroy %s', weaponBag)
                return false
            end
        else
            if not self:checkInventory() then
                if state.isExternalRequest then
                    logger.info('tell %s i was unable to free up inventory space', state.requester)
                else
                    logger.info('Unable to free up inventory space')
                end
                return false
            end
        end
        local summonResult = self:summonItem(self.spells.weapons, mq.TLO.Me.ID(), petToys.weapons[self.spells.weapons.BaseName].foldedBag, true)
        if not summonResult then
            logger.info('Error occurred summoning items')
            return false
        end
    end
    return true
end

function Magician:pickupWeapon(weaponName)
    local item = mq.TLO.FindItem('='..weaponName)
    local itemSlot = item.ItemSlot()
    local itemSlot2 = item.ItemSlot2()
    local packSlot = itemSlot - 22
    local inPackSlot = itemSlot2 + 1
    mq.cmdf('/nomodkey /ctrlkey /itemnotify in pack%s %s leftmouseup', packSlot, inPackSlot)
    mq.delay(100, function() return mq.TLO.Cursor.ID() == item.ID() end)
end

function Magician:giveOther(petID, spell, toyType)
    local itemName = petToys[toyType][spell.BaseName]
    local item = mq.TLO.FindItem('='..itemName)
    --if not item() then
        mq.cmdf('/mqt id %s', petID)
        local summonResult = self:summonItem(spell, petID, false, false)
        if not summonResult then
            logger.info('Error occurred summoning items')
            return false
        end
    --else
    --    mq.cmdf('/nomodkey /itemnotify "%s" rightmouseup')
    --    mq.delay(3000, function() return mq.TLO.Cursor() end)
    --end

    --mq.cmdf('/mqt id %s', petID)
    --self.giveCursorItemToTarget()
    return true
end

function Magician:summonItem(spell, targetID, summonsItem, inventoryItem)
    logger.info('going to summon item %s', spell.Name)
    --mq.cmd('/mqt 0')
    if not mq.TLO.Me.Gem(spell.Name)() then
        abilities.swapSpell(spell, 12, true)
    end
    mq.delay(10000, function() return mq.TLO.Me.SpellReady(spell.Name)() end)
    if spell:isReady() ~= abilities.IsReady.SHOULD_CAST then logger.info('Spell %s was not ready', spell.Name) return false end
    castUtils.cast(spell, targetID)

    mq.delay(1000, function() return mq.TLO.Cursor() end)
    if summonsItem then
        if not mq.TLO.Cursor.ID() then
            logger.info('Cursor was empty after casting %s', spell.Name)
            return false
        end

        self:clearCursor()
        mq.cmdf('/nomodkey /itemnotify "%s" rightmouseup', summonsItem)
        mq.delay(3000, function() return mq.TLO.Cursor() end)
        mq.delay(1)
        if inventoryItem then self:clearCursor() end
    end
    return true
end

function Magician:giveCursorItemToTarget(moveback, clearTarget)
    local meX, meY, meZ = mq.TLO.Me.X(), mq.TLO.Me.Y(), mq.TLO.Me.Z()
    movement.navToTarget('dist=10', 2000)
    mq.cmd('/click left target')
    local targetType = mq.TLO.Target.Type()
    local windowType = 'TradeWnd'
    local buttonType = 'TRDW_Trade_Button'
    if targetType ~= 'PC' then windowType = 'GiveWnd' buttonType = 'GVW_Give_Button' end
    mq.delay(3000, function() return mq.TLO.Window(windowType).Open() end)
    if not mq.TLO.Window(windowType).Open() then
        mq.cmd('/autoinv')
        return
    end
    mq.cmdf('/squelch /nomodkey /notify %s %s leftmouseup', windowType, buttonType)
    mq.delay(3000, function() return not mq.TLO.Window(windowType).Open() end)
    if mq.TLO.Window(windowType).Open() then
        -- wait a bit?
        mq.delay(10000)
    end
    if clearTarget then
        mq.cmd('/squelch /nomodkey /keypress esc')
    end
    -- move back
    if moveback then
        movement.navToLoc(meX, meY, meZ, nil, 2000)
    end
end

function Magician:safeToDestroy(bag)
    for i = 1, bag.Container() do
        local bagSlot = bag.Item(i)
        if bagSlot() and not bagSlot.NoRent() then
            logger.info('DO NOT DESTROY: Found non-NoRent item: %s in summoned bag', bagSlot.Name())
            return false
        end
    end
    return true
end

function Magician:checkInventory()
    local pouch = 'Pouch of Quellious'
    local bag = mq.TLO.FindItem('='..pouch)
    local pouchID = bag.ID()
    local summonedItemCount = mq.TLO.FindItemCount('='..pouch)()
    logger.info('cleanup Pouch of Quellious')
    for i=1,summonedItemCount do
        if not self:safeToDestroy(bag) then return false end
        mq.cmdf('/nomodkey /itemnotify "%s" leftmouseup', pouch)
        mq.delay(1000, function() return mq.TLO.Cursor.ID() == pouchID end)
        if mq.TLO.Cursor.ID() ~= pouchID then
            return false
        end
        mq.cmd('/destroy')
    end

    logger.info('cleanup Disenchanted Bags')
    bag = mq.TLO.FindItem('='..disenchantedBag)
    local bagID = bag.ID()
    summonedItemCount = mq.TLO.FindItemCount('='..disenchantedBag)()
    for i=1,summonedItemCount do
        if not self:safeToDestroy(bag) then return false end
        mq.cmdf('/nomodkey /itemnotify "%s" leftmouseup', disenchantedBag)
        mq.delay(1000, function() return mq.TLO.Cursor.ID() == bagID end)
        if mq.TLO.Cursor.ID() ~= bagID then
            return false
        end
        mq.cmd('/destroy')
    end

    local containerWithOpenSpace = -1
    local slotToMoveFrom = -1
    local hasOpenInventorySlot = false

    -- if the first inventory slot is empty or an empty bag, this fails because it never sets containerWithOpenSpace
    logger.info('find bag slot')
    for i=1,10 do
        local currentSlot = i
        local containerSlots = mq.TLO.Me.Inventory('pack'..i).Container()
        -- slots empty
        if not containerSlots then
            logger.info('empty slot! %s', currentSlot)
            slotToMoveFrom = -1
            return true
        end
    end
    for i=1,10 do
        local currentSlot = i
        local containerSlots = mq.TLO.Me.Inventory('pack'..i).Container()
        local containerItemCount = mq.TLO.InvSlot('pack'..i).Item.Items() or 0

        -- slots empty
        if not containerSlots then
            logger.info('empty slot! %s', currentSlot)
            slotToMoveFrom = -1
            hasOpenInventorySlot = true
            break
        end

        -- empty bag
        if containerItemCount == 0 then
            logger.info('found empty bag %s', currentSlot)
            slotToMoveFrom = i
            break
        end

        if (containerSlots or 0) - containerItemCount > 0 then
            logger.info('found bag with room')
            containerWithOpenSpace = i
        end

        -- its not a container or its empty, may move it
        if containerSlots == 0 or (containerSlots > 0 and containerItemCount == 0) then
            logger.info('found a item or empty bag we can move')
            slotToMoveFrom = currentSlot
        end
    end

    local freeInventory = mq.TLO.Me.FreeInventory()
    if freeInventory > 0 and containerWithOpenSpace > 0 and slotToMoveFrom > 0 then
        mq.cmdf('/nomodkey /itemnotify pack%s leftmouseup', slotToMoveFrom)
        mq.delay(250)

        if mq.TLO.Window('QuantityWnd').Open() then
            mq.cmd('/nomodkey /notify QuantityWnd QTYW_Accept_Button leftmouseup')
        end
        mq.delay(1000, function() return mq.TLO.Cursor() end)
        mq.delay(1)
    end

    freeInventory = mq.TLO.Me.FreeInventory()
    if freeInventory > 0 then
        hasOpenInventorySlot = true
    end

    if mq.TLO.Cursor.ID() and containerWithOpenSpace > 0 then
        local invslot = mq.TLO.Me.Inventory('pack'..containerWithOpenSpace)
        local slots = invslot.Container()
        for i=1,slots do
            local item = invslot.Item(i)
            if not item() then
                logger.info('/nomodkey /itemnotify in pack%s %s leftmouseup', containerWithOpenSpace, i)
                mq.cmdf('/nomodkey /itemnotify in pack%s %s leftmouseup', containerWithOpenSpace, i)
                mq.delay(1000, function() return not mq.TLO.Cursor() end)
                mq.delay(1)
                hasOpenInventorySlot = true
                break
            end
        end

        if mq.TLO.Cursor() then self:clearCursor() end
    end
    return hasOpenInventorySlot
end

return Magician
