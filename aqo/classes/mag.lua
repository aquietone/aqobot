local baseclass = require('aqo.classes.base')
local assist = require('aqo.routines.assist')

local mag = baseclass

mag.class = 'mag'
mag.classOrder = {'assist', 'cast', 'burn', 'recover', 'buff', 'rest', 'managepet'}

mag.SPELLSETS = {standard=1}

mag.addOption('SPELLSET', 'Spell Set', 'standard', mag.SPELLSETS, nil, 'combobox')
mag.addOption('USEMELEE', 'Use Melee', false, nil, 'Toggle attacking mobs with melee', 'checkbox')

mag.addSpell('bolt', {'Bolt of Flame'})

local standard = {}
table.insert(standard, mag.spells.bolt)

mag.spellRotations = {
    standard=standard
}

mag.pull_func = function()
    assist.send_pet()
end

return mag