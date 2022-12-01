---@type Mq
local mq = require('mq')
local class = require(AQO..'.classes.classbase')
local common = require(AQO..'.common')

class.class = 'mag'
class.classOrder = {'assist', 'mash', 'cast', 'burn', 'heal', 'recover', 'buff', 'rest', 'managepet'}

class.SPELLSETS = {standard=1}

class.addCommonOptions()
class.addCommonAbilities()
class.addOption('EARTHFORM', 'Elemental Form: Earth', false, nil, 'Toggle use of Elemental Form: Earth', 'checkbox', 'FIREFORM')
class.addOption('FIREFORM', 'Elemental Form: Fire', true, nil, 'Toggle use of Elemental Form: Fire', 'checkbox', 'EARTHFORM')
class.addOption('USEFIRENUKES', 'Use Fire Nukes', true, nil, 'Toggle use of fire nuke line', 'checkbox')
class.addOption('USEMAGICNUKES', 'Use Magic Nukes', false, nil, 'Toggle use of magic nuke line', 'checkbox')
class.addOption('USEDEBUFF', 'Use Malo', false, nil, '', 'checkbox')
class.addOption('SUMMONMODROD', 'Summon Mod Rods', false, nil, '', 'checkbox')
class.addOption('USEDS', 'Use Group DS', true, nil, '', 'checkbox')
class.addOption('USETEMPDS', 'Use Temp DS', true, nil, '', 'checkbox')

class.addSpell('prenuke', {'Fickle Fire'}, {opt='USEFIRENUKES'})
class.addSpell('firenuke', {'Spear of Ro', 'Sun Vortex', 'Seeking Flame of Seukor', 'Char', 'Bolt of Flame'}, {opt='USEFIRENUKES'})
class.addSpell('fastfire', {'Burning Earth'}, {opt='USEFIRENUKES'})
class.addSpell('magicnuke', {'Rock of Taelosia'}, {opt='USEMAGICNUKES'})
class.addSpell('pet', {'Child of Water', 'Servant of Marr', 'Greater Vocaration: Water', 'Vocarate: Water', 'Conjuration: Water',
                    'Lesser Conjuration: Water', 'Minor Conjuration: Water', 'Greater Summoning: Water',
                    'Summoning: Water', 'Lesser Summoning: Water', 'Minor Summoning: Water', 'Elementalkin: Water'})
class.addSpell('petbuff', {'Burnout V', 'Burnout IV', 'Burnout III', 'Burnout II', 'Burnout'})
class.addSpell('petstrbuff', {'Rathe\'s Strength', 'Earthen Strength'}, {skipifbuff='Champion'})
class.addSpell('orb', {'Summon: Molten Orb', 'Summon: Lava Orb'}, {summons={'Molten Orb','Lava Orb'}, summonMinimum=1})
class.addSpell('petds', {'Iceflame Guard'})
class.addSpell('servant', {'Rampaging Servant'})
class.addSpell('ds', {'Circle of Fireskin'}, {opt='USEDS'})
class.addSpell('bigds', {'Frantic Flames', 'Pyrilen Skin', 'Burning Aura'}, {opt='USETEMPDS', classes={WAR=true,SHD=true,PAL=true}})

class.addSpell('manaregen', {'Elemental Simulacrum', 'Elemental Siphon'}) -- self mana regen
class.addSpell('acregen', {'Phantom Shield', 'Xegony\'s Phantasmal Guard'}) -- self regen/ac buff
class.addSpell('petheal', {'Planar Renewal'}, {opt='HEALPET', pet=50}) -- pet heal

table.insert(class.DPSAbilities, common.getItem('Aged Sarnak Channeler Staff'))
table.insert(class.DPSAbilities, common.getAA('Force of Elements'))
table.insert(class.burnAbilities, common.getAA('Fundament: First Spire of the Elements'))
table.insert(class.burnAbilities, common.getAA('Host of the Elements', {delay=1500}))
table.insert(class.burnAbilities, common.getAA('Servant of Ro', {delay=500}))
table.insert(class.burnAbilities, common.getAA('Frenzied Burnout'))

table.insert(class.petBuffs, class.spells.petbuff)
table.insert(class.petBuffs, class.spells.petstrbuff)
table.insert(class.petBuffs, class.spells.petds)

table.insert(class.healAbilities, class.spells.petheal)

table.insert(class.selfBuffs, common.getAA('Elemental Form: Earth', {opt='EARTHFORM'}))
table.insert(class.selfBuffs, common.getAA('Elemental Form: Fire', {opt='FIREFORM'}))
table.insert(class.selfBuffs, class.spells.manaregen)
table.insert(class.selfBuffs, class.spells.acregen)
table.insert(class.selfBuffs, class.spells.orb)
table.insert(class.selfBuffs, class.spells.ds)
table.insert(class.selfBuffs, common.getAA('Large Modulation Shard', {opt='SUMMONMODROD', summons='Summoned: Large Modulation Shard', summonMinimum=1}))
table.insert(class.combatBuffs, common.getAA('Fire Core'))
--table.insert(class.singleBuffs, class.spells.bigds)

class.debuff = common.getAA('Malosinete')

local standard = {}
table.insert(standard, class.spells.servant)
--table.insert(standard, class.spells.prenuke)
table.insert(standard, class.spells.fastfire)
table.insert(standard, class.spells.firenuke)
table.insert(standard, class.spells.magicnuke)

class.spellRotations = {
    standard=standard
}

class.orb = class.spells.orb
class.requestAliases.orb = 'orb'
class.ds = class.spells.ds
class.requestAliases.ds = 'ds'

class.pull_func = function()
    if mq.TLO.Navigation.Active() then mq.cmd('/nav stop') end
    mq.cmd('/multiline ; /pet attack ; /pet swarm')
    mq.delay(1000)
end

return class