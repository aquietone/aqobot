local mq = require('mq')
local class = require(AQO..'.classes.classbase')
local common = require(AQO..'.common')

class.class = 'wiz'
class.classOrder = {'assist', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest'}

class.SPELLSETS = {standard=1}

class.addCommonOptions()
class.addCommonAbilities()

class.addSpell('nuke1', {'Draught of Ro', 'Pillar of Fire'})
--class.addSpell('nuke2', {'Fire Spiral of Al\'Kabor'})

table.insert(class.DPSAbilities, common.getAA('Force of Will'))
local standard = {}
table.insert(standard, class.spells.nuke1)
--table.insert(standard, class.spells.nuke2)

class.spellRotations = {
    standard=standard
}

return class