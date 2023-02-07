---@type Mq
local mq = require('mq')
local class = require('classes.classbase')
local movement = require('routines.movement')
local common = require('common')

function class.init(_aqo)
    class.classOrder = {'assist', 'mash', 'debuff', 'cast', 'burn', 'heal', 'recover', 'buff', 'rest', 'managepet', 'rez'}
    class.spellRotations = {standard={}}
    class.initBase(_aqo, 'mag')

    class.initClassOptions()
    class.loadSettings()
    class.initSpellLines(_aqo)
    class.initSpellRotations(_aqo)
    class.initHeals(_aqo)
    class.initBuffs(_aqo)
    class.initBurns(_aqo)
    class.initDPSAbilities(_aqo)
    class.initDebuffs(_aqo)
    class.initDefensiveAbilities(_aqo)
end

function class.initClassOptions()
    class.addOption('EARTHFORM', 'Elemental Form: Earth', false, nil, 'Toggle use of Elemental Form: Earth', 'checkbox', 'FIREFORM')
    class.addOption('FIREFORM', 'Elemental Form: Fire', true, nil, 'Toggle use of Elemental Form: Fire', 'checkbox', 'EARTHFORM')
    class.addOption('USEFIRENUKES', 'Use Fire Nukes', true, nil, 'Toggle use of fire nuke line', 'checkbox')
    class.addOption('USEMAGICNUKES', 'Use Magic Nukes', false, nil, 'Toggle use of magic nuke line', 'checkbox')
    class.addOption('USEDEBUFF', 'Use Malo', false, nil, '', 'checkbox')
    class.addOption('SUMMONMODROD', 'Summon Mod Rods', false, nil, '', 'checkbox')
    class.addOption('USEDS', 'Use Group DS', true, nil, '', 'checkbox')
    class.addOption('USETEMPDS', 'Use Temp DS', true, nil, '', 'checkbox')
end

function class.initSpellLines(_aqo)
    class.addSpell('prenuke', {'Fickle Fire'}, {opt='USEFIRENUKES'})
    class.addSpell('firenuke', {'Spear of Ro', 'Sun Vortex', 'Seeking Flame of Seukor', 'Char', 'Bolt of Flame'}, {opt='USEFIRENUKES'})
    class.addSpell('fastfire', {'Burning Earth'}, {opt='USEFIRENUKES'})
    class.addSpell('magicnuke', {'Rock of Taelosia'}, {opt='USEMAGICNUKES'})
    class.addSpell('pet', {'Child of Water', 'Servant of Marr', 'Greater Vocaration: Water', 'Vocarate: Water', 'Conjuration: Water',
                        'Lesser Conjuration: Water', 'Minor Conjuration: Water', 'Greater Summoning: Water',
                        'Summoning: Water', 'Lesser Summoning: Water', 'Minor Summoning: Water', 'Elementalkin: Water'})
    class.addSpell('petbuff', {'Burnout V', 'Burnout IV', 'Burnout III', 'Burnout II', 'Burnout'})
    class.addSpell('petstrbuff', {'Rathe\'s Strength', 'Earthen Strength'}, {skipifbuff='Champion'})
    class.addSpell('orb', {'Summon: Molten Orb', 'Summon: Lava Orb'}, {summons={'Molten Orb','Lava Orb'}, summonMinimum=1, nodmz=true})
    class.addSpell('petds', {'Iceflame Guard'})
    class.addSpell('servant', {'Rampaging Servant'})
    class.addSpell('ds', {'Circle of Fireskin'}, {opt='USEDS'})
    class.addSpell('bigds', {'Frantic Flames', 'Pyrilen Skin', 'Burning Aura'}, {opt='USETEMPDS', classes={WAR=true,SHD=true,PAL=true}})

    class.addSpell('manaregen', {'Elemental Simulacrum', 'Elemental Siphon'}) -- self mana regen
    class.addSpell('acregen', {'Phantom Shield', 'Xegony\'s Phantasmal Guard'}) -- self regen/ac buff
    class.addSpell('petheal', {'Planar Renewal'}, {opt='HEALPET', pet=50}) -- pet heal

    class.addSpell('armor', {'Grant Spectral Plate'}) -- targeted, Summon Folded Pack of Spectral Plate
    class.addSpell('weapons', {'Grant Spectral Armaments'}) -- targeted, Summons Folded Pack of Spectral Armaments
    class.addSpell('jewelry', {'Grant Enibik\'s Heirlooms'}) -- targeted, Summons Folded Pack of Enibik's Heirlooms, includes muzzle
    class.addSpell('belt', {'Summon Crystal Belt'}) -- Summoned: Crystal Belt
end

function class.initSpellRotations(_aqo)
    table.insert(class.spellRotations.standard, class.spells.servant)
    --table.insert(class.spellRotations.standard, class.spells.prenuke)
    table.insert(class.spellRotations.standard, class.spells.fastfire)
    table.insert(class.spellRotations.standard, class.spells.firenuke)
    table.insert(class.spellRotations.standard, class.spells.magicnuke)
end

function class.initDPSAbilities(_aqo)
    table.insert(class.DPSAbilities, common.getAA('Force of Elements'))
end

function class.initBurns(_aqo)
    table.insert(class.burnAbilities, common.getAA('Fundament: First Spire of the Elements'))
    table.insert(class.burnAbilities, common.getAA('Host of the Elements', {delay=1500}))
    table.insert(class.burnAbilities, common.getAA('Servant of Ro', {delay=500}))
    table.insert(class.burnAbilities, common.getAA('Frenzied Burnout'))
end

function class.initHeals(_aqo)
    table.insert(class.healAbilities, class.spells.petheal)
end

function class.initBuffs(_aqo)
    local arcanum1 = common.getAA('Focus of Arcanum')
    local arcanum2 = common.getAA('Acute Focus of Arcanum', {skipifbuff='Enlightened Focus of Arcanum'})
    local arcanum3 = common.getAA('Enlightened Focus of Arcanum', {skipifbuff='Acute Focus of Arcanum'})
    local arcanum4 = common.getAA('Empowered Focus of Arcanum')
    table.insert(class.combatBuffs, arcanum2)
    table.insert(class.combatBuffs, arcanum3)

    table.insert(class.selfBuffs, common.getAA('Elemental Form: Earth', {opt='EARTHFORM'}))
    table.insert(class.selfBuffs, common.getAA('Elemental Form: Fire', {opt='FIREFORM'}))
    table.insert(class.selfBuffs, class.spells.manaregen)
    table.insert(class.selfBuffs, class.spells.acregen)
    table.insert(class.selfBuffs, class.spells.orb)
    table.insert(class.selfBuffs, class.spells.ds)
    table.insert(class.selfBuffs, common.getAA('Large Modulation Shard', {opt='SUMMONMODROD', summons='Summoned: Large Modulation Shard', summonMinimum=1, nodmz=true}))
    table.insert(class.combatBuffs, common.getAA('Fire Core'))
    table.insert(class.singleBuffs, class.spells.bigds)

    table.insert(class.petBuffs, class.spells.petbuff)
    table.insert(class.petBuffs, class.spells.petstrbuff)
    table.insert(class.petBuffs, class.spells.petds)

    class.addRequestAlias(class.spells.orb, 'orb')
    class.addRequestAlias(class.spells.ds, 'ds')
    class.addRequestAlias(class.spells.weapons, 'arm')
    class.addRequestAlias(class.spells.jewelry, 'jewelry')
    class.addRequestAlias(class.spells.armor, 'armor')
end

function class.initDebuffs(_aqo)
    table.insert(class.debuffs, common.getAA('Malosinete', {opt='USEDEBUFF'}))
end

function class.initDefensiveAbilities(_aqo)
    table.insert(class.fadeAbilities, common.getAA('Companion of Necessity'))
end

--[[
    "Fire", "Summoned: Fist of Flame",
    "Water", "Summoned: Orb of Chilling Water",
    "Shield", "Summoned: Buckler of Draining Defense",
    "Taunt", "Summoned: Short Sword of Warding",
    "Slow", "Summoned: Mace of Temporal Distortion",
    "Malo", "Summoned: Spear of Maliciousness",
    "Dispel", "Summoned: Wand of Dismissal",
    "Snare", "Summoned: Tendon Carver",
]]

function class.pullCustom()
    movement.stop()
    mq.cmd('/multiline ; /pet attack ; /pet swarm')
    mq.delay(1000)
end

return class