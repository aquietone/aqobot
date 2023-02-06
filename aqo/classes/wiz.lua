--- @type Mq
local mq = require('mq')
local class = require('classes.classbase')
local common = require('common')

function class.init(_aqo)
    class.classOrder = {'assist', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest', 'rez'}
    class.spellRotations = {standard={}}
    class.initBase(_aqo, 'wiz')
    class.loadSettings()

    class.addSpell('nuke1', {'Draught of Ro', 'Pillar of Fire'})
    --class.addSpell('nuke2', {'Fire Spiral of Al\'Kabor'})

    table.insert(class.DPSAbilities, common.getAA('Force of Will'))
    table.insert(class.spellRotations.standard, class.spells.nuke1)
    --table.insert(class.spellRotations.standard, class.spells.nuke2)
end

return class