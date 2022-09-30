local baseclass = require('aqo.classes.base')

local bst = baseclass

bst.class = 'bst'
bst.classOrder = {'assist', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest', 'managepet'}

bst.SPELLSETS = {standard=1}

bst.addOption('SPELLSET', 'Spell Set', 'standard', bst.SPELLSETS, nil, 'combobox')

local standard = {}

bst.spellRotations = {
    standard=standard
}

table.insert(bst.DPSAbilities, {name='Kick',            type='ability'})

return bst