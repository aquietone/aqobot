---@type Mq
local mq = require 'mq'
local class = require(AQO..'.classes.classbase')
local timer = require(AQO..'.utils.timer')
local common = require(AQO..'.common')

class.class = 'dru'
class.classOrder = {'heal', 'assist', 'cast', 'burn', 'recover', 'buff', 'rest'}

class.SPELLSETS = {standard=1}
class.addCommonOptions()
class.addOption('USENUKES', 'Use Nukes', false, nil, 'Toggle use of nuke spells', 'checkbox')
class.addOption('USESNARE', 'Use Snare', true, nil, 'Cast snare on mobs', 'checkbox')

class.addSpell('heal', {'Nature\'s Infusion', 'Chloroblast', 'Superior Healing', 'Nature\'s Renewal', 'Light Healing', 'Minor Healing'}, {me=75, mt=75, other=75, pet=60})
class.addSpell('groupheal', {'Word of Restoration'})
class.addSpell('firenuke', {'Sylvan Fire', 'Wildfire', 'Scoriae', 'Firestrike'}, {opt='USENUKES'})
class.addSpell('dot', {'Winged Death'})
class.addSpell('snare', {'Ensnare', 'Snare'})
class.addSpell('aura', {'Aura of Life', 'Aura of the Grove'}, {aura=true})

class.snare = class.spells.snare

-- Aura of the Grove, Aura of the Grove Effect

local standard = {}
table.insert(standard, class.spells.firenuke)

class.spellRotations = {
    standard=standard
}

table.insert(class.healAbilities, class.spells.heal)

table.insert(class.auras, class.spells.aura)

class.nuketimer = timer:new(5)

return class