--- @type Mq
local mq = require('mq')
local class = require('classes.classbase')
local common = require('common')

function class.init(_aqo)
    class.classOrder = {'assist', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest', 'rez'}
    class.spellRotations = {standard={}}
    class.initBase(_aqo, 'wiz')

    class.loadSettings()
    class.initSpellLines(_aqo)
    class.initSpellRotations(_aqo)
    class.initDPSAbilities(_aqo)
end

function class.initSpellLines(_aqo)
    class.addSpell('nuke1', {'Draught of Ro', 'Pillar of Fire'})
    --class.addSpell('nuke2', {'Fire Spiral of Al\'Kabor'})
end

function class.initSpellRotations(_aqo)
    table.insert(class.spellRotations.standard, class.spells.nuke1)
    --table.insert(class.spellRotations.standard, class.spells.nuke2)
end

function class.initDPSAbilities(_aqo)
    table.insert(class.DPSAbilities, common.getAA('Force of Will'))
end

return class