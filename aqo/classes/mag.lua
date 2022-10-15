---@type Mq
local mq = require('mq')
local class = require(AQO..'.classes.classbase')
local assist = require(AQO..'.routines.assist')
local common = require(AQO..'.common')

class.class = 'mag'
class.classOrder = {'assist', 'mash', 'cast', 'burn', 'heal', 'recover', 'buff', 'rest', 'managepet'}

class.SPELLSETS = {standard=1}

class.addCommonOptions()
class.addOption('USEFIRENUKES', 'Use Fire Nukes', true, nil, 'Toggle use of fire nuke line', 'checkbox')
class.addOption('USEMAGICNUKES', 'Use Magic Nukes', false, nil, 'Toggle use of magic nuke line', 'checkbox')

class.addSpell('firenuke', {'Sun Vortex', 'Seeking Flame of Seukor', 'Char', 'Bolt of Flame'}, {opt='USEFIRENUKES'})
class.addSpell('magicnuke', {'Rock of Taelosia'}, {opt='USEMAGICNUKES'})
class.addSpell('pet', {'Greater Vocaration: Water', 'Vocarate: Water', 'Conjuration: Water', 
                    'Lesser Conjuration: Water', 'Minor Conjuration: Water', 'Greater Summoning: Water', 
                    'Summoning: Water', 'Lesser Summoning: Water', 'Minor Summoning: Water', 'Elementalkin: Water'})
class.addSpell('petbuff', {'Burnout V', 'Burnout IV', 'Burnout III', 'Burnout II', 'Burnout'})
class.addSpell('petstrbuff', {'Earthen Strength'})

class.addSpell('manaregen', {'Elemental Siphon'}) -- self mana regen
class.addSpell('acregen', {'Xegony\'s Phantasmal Guard'}) -- self regen/ac buff
class.addSpell('petheal', {'Planar Renewal'}, {opt='HEALPET', pet=50}) -- pet heal

table.insert(class.DPSAbilities, common.getItem('Aged Sarnak Channeler Staff'))
table.insert(class.DPSAbilities, common.getAA('Force of Elements'))
table.insert(class.burnAbilities, common.getAA('Fundament: First Spire of the Elements'))
table.insert(class.burnAbilities, common.getAA('Host of the Elements', {delay=1500}))
table.insert(class.burnAbilities, common.getAA('Servant of Ro', {delay=500}))

table.insert(class.petBuffs, class.spells.petbuff)
table.insert(class.petBuffs, class.spells.petstrbuff)

table.insert(class.selfBuffs, class.spells.manaregen)
table.insert(class.selfBuffs, class.spells.acregen)

local standard = {}
table.insert(standard, class.spells.firenuke)
table.insert(standard, class.spells.magicnuke)

class.spellRotations = {
    standard=standard
}

class.pull_func = function()
    if mq.TLO.Navigation.Active() then mq.cmd('/nav stop') end
    mq.cmd('/multiline ; /pet attack ; /pet swarm')
    mq.delay(1000)
end

return class