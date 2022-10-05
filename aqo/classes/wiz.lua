local baseclass = require(AQO..'.classes.base')

local wiz = baseclass

wiz.class = 'wiz'
wiz.classOrder = {'assist', 'cast', 'burn', 'recover', 'buff', 'rest'}

wiz.SPELLSETS = {standard=1}

wiz.addOption('SPELLSET', 'Spell Set', 'standard', wiz.SPELLSETS, nil, 'combobox')
wiz.addOption('USEMELEE', 'Use Melee', false, nil, 'Toggle attacking mobs with melee', 'checkbox')

wiz.addSpell('nuke1', {'Pillar of Fire'})
wiz.addSpell('nuke2', {'Fire Spiral of Al\'Kabor'})

local standard = {}
table.insert(standard, wiz.spells.nuke1)
table.insert(standard, wiz.spells.nuke2)

wiz.spellRotations = {
    standard=standard
}

return wiz