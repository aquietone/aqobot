local baseclass = require(AQO..'.classes.base')
local common = require(AQO..'.common')

local bst = baseclass

bst.class = 'bst'
bst.classOrder = {'assist', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest', 'managepet'}

bst.SPELLSETS = {standard=1}

bst.addOption('SPELLSET', 'Spell Set', 'standard', bst.SPELLSETS, nil, 'combobox')

local standard = {}

bst.spellRotations = {
    standard=standard
}

table.insert(bst.DPSAbilities, common.getSkill('Kick'))

return bst