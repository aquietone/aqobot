local baseclass = require('aqo.classes.base')

local pal = baseclass

pal.class = 'pal'
pal.classOrder = {'assist', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest'}

pal.SPELLSETS = {standard=1}

pal.addOption('SPELLSET', 'Spell Set', 'standard', pal.SPELLSETS, nil, 'combobox')

local standard = {}

pal.spellRotations = {
    standard=standard
}

table.insert(pal.DPSAbilities, {name='Kick',            type='ability'})

return pal