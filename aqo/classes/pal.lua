local baseclass = require(AQO..'.classes.classbase')
local common = require(AQO..'.common')

local pal = baseclass

pal.class = 'pal'
pal.classOrder = {'assist', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest'}

pal.SPELLSETS = {standard=1}

pal.addOption('SPELLSET', 'Spell Set', 'standard', pal.SPELLSETS, nil, 'combobox')

local standard = {}

pal.spellRotations = {
    standard=standard
}

table.insert(pal.DPSAbilities, common.getSkill('Kick'))

return pal