local baseclass = require('aqo.classes.base')

local wiz = baseclass

wiz.class = 'wiz'
wiz.classOrder = {'assist', 'cast', 'burn', 'recover', 'buff', 'rest'}

wiz.SPELLSETS = {standard=1}

wiz.addOption('SPELLSET', 'Spell Set', 'standard', wiz.SPELLSETS, nil, 'combobox')
wiz.addOption('USEMELEE', 'Use Melee', false, nil, 'Toggle attacking mobs with melee', 'checkbox')

local standard = {}

wiz.spellRotations = {
    standard=standard
}

return wiz