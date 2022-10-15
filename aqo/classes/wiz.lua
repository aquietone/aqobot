local class = require(AQO..'.classes.classbase')

class.class = 'wiz'
class.classOrder = {'assist', 'cast', 'burn', 'recover', 'buff', 'rest'}

class.SPELLSETS = {standard=1}

class.addCommonOptions()
class.addOption('USEAOE', 'Use AOE', true, nil, 'Toggle use of AOE abilities', 'checkbox')

class.addSpell('nuke1', {'Pillar of Fire'})
class.addSpell('nuke2', {'Fire Spiral of Al\'Kabor'})

local standard = {}
table.insert(standard, class.spells.nuke1)
table.insert(standard, class.spells.nuke2)

class.spellRotations = {
    standard=standard
}

return class