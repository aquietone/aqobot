local baseclass = require('aqo.classes.base')
local assist = require('aqo.routines.assist')

local mag = baseclass

mag.class = 'mag'
mag.classOrder = {'assist', 'cast', 'burn', 'recover', 'buff', 'rest', 'managepet'}

mag.SPELLSETS = {standard=1}

mag.addOption('SPELLSET', 'Spell Set', 'standard', mag.SPELLSETS, nil, 'combobox')
mag.addOption('USEMELEE', 'Use Melee', false, nil, 'Toggle attacking mobs with melee', 'checkbox')
mag.addOption('SUMMONPET', 'Summon Pet', true, nil, 'Toggle summoning of pet', 'checkbox')
mag.addOption('BUFFPET', 'Buff Pet', true, nil, 'Toggle buffing of pet', 'checkbox')

mag.addSpell('bolt', {'Char', 'Bolt of Flame'})
mag.addSpell('pet', {'Vocarate: Water', 'Conjuration: Water', 'Lesser Conjuration: Water', 'Minor Conjuration: Water', 'Greater Summoning: Water', 'Summoning: Water', 'Lesser Summoning: Water', 'Minor Summoning: Water', 'Elementalkin: Water'})
mag.addSpell('petbuff', {'Burnout IV', 'Burnout III', 'Burnout II', 'Burnout'})
mag.addSpell('petstrbuff', {'Earthen Strength'})

table.insert(mag.petBuffs, mag.spells.petbuff)
table.insert(mag.petBuffs, mag.spells.petstrbuff)

local standard = {}
table.insert(standard, mag.spells.bolt)

mag.spellRotations = {
    standard=standard
}

mag.pull_func = function()
    assist.send_pet()
end

return mag