--- @type Mq
local mq = require('mq')
local class = require('classes.classbase')
local common = require('common')

function class.init(_aqo)
    class.classOrder = {'assist', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest', 'rez'}
    class.spellRotations = {standard={}, ae={}}
    class.initBase(_aqo, 'wiz')

    class.loadSettings()
    class.initSpellLines(_aqo)
    class.initSpellRotations(_aqo)
    class.initDPSAbilities(_aqo)
    class.initBurns(_aqo)
    class.initBuffs(_aqo)
    table.insert(class.recoverAbilities, common.getAA('Harvest of Druzzil'))
end

function class.initSpellLines(_aqo)
    class.addSpell('nuke1', {'Ether Flame', 'Draught of Ro', 'Pillar of Fire'})
    class.addSpell('nuke2', {'Ancient: Spear of Gelaqua', 'Fire Spiral of Al\'Kabor'})
    class.addSpell('Swarm', {'Solist\'s Frozen Sword'})
    class.addSpell('rain', {'Gelid Rains'})
    class.addSpell('aeTrap', {'Fire Rune'})
    class.addSpell('ae1', {'Circle of Thunder'})
    class.addSpell('ae2', {'Jyll\'s Static Pulse'})
    class.addSpell('ae3', {'Jyll\'s Zephyr of Ice'})
    class.addSpell('ae4', {'Jyll\'s Wave of Heat'})
end

function class.initSpellRotations(_aqo)
    table.insert(class.spellRotations.standard, class.spells.swarm)
    table.insert(class.spellRotations.standard, class.spells.nuke1)
    table.insert(class.spellRotations.standard, class.spells.nuke2)
    table.insert(class.spellRotations.ae, class.spells.aeTrap)
    table.insert(class.spellRotations.ae, class.spells.ae1)
    table.insert(class.spellRotations.ae, class.spells.ae2)
    table.insert(class.spellRotations.ae, class.spells.ae3)
    table.insert(class.spellRotations.ae, class.spells.ae4)
end

function class.initDPSAbilities(_aqo)
    table.insert(class.DPSAbilities, common.getAA('Force of Will'))
end

function class.initBurns(_aqo)
    table.insert(class.burnAbilities, common.getAA('Fury of Ro'))
    table.insert(class.burnAbilities, common.getAA('Prolonged Destruction'))
    table.insert(class.burnAbilities, common.getAA('Fundament: Second Spire of Arcanum'))
    table.insert(class.burnAbilities, common.getAA('Mana Blaze'))
end

function class.initBuffs(_aqo)
    table.insert(class.selfBuffs, common.getAA('Pyromancy'))
    table.insert(class.selfBuffs, common.getAA('Kerafyrm\'s Prismatic Familiar'))
end

return class