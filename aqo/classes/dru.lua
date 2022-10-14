---@type Mq
local mq = require 'mq'
local baseclass = require(AQO..'.classes.classbase')
local timer = require(AQO..'.utils.timer')
local common = require(AQO..'.common')

local dru = baseclass

dru.class = 'dru'
dru.classOrder = {'heal', 'assist', 'cast', 'burn', 'recover', 'buff', 'rest'}

dru.SPELLSETS = {standard=1}

dru.addOption('SPELLSET', 'Spell Set', 'standard', dru.SPELLSETS, nil, 'combobox')
dru.addOption('USEMELEE', 'Use Melee', false, nil, 'Toggle attacking mobs with melee', 'checkbox')
dru.addOption('USENUKES', 'Use Nukes', false, nil, 'Toggle use of nuke spells', 'checkbox')
dru.addOption('USESNARE', 'Use Snare', true, nil, 'Cast snare on mobs', 'checkbox')

dru.addSpell('heal', {'Nature\'s Infusion', 'Chloroblast', 'Superior Healing', 'Nature\'s Renewal', 'Light Healing', 'Minor Healing'}, {me=75, mt=75, other=75})
dru.addSpell('groupheal', {'Word of Restoration'})
dru.addSpell('firenuke', {'Sylvan Fire', 'Wildfire', 'Scoriae', 'Firestrike'}, {opt='USENUKES'})
dru.addSpell('dot', {'Winged Death'})
dru.addSpell('snare', {'Ensnare', 'Snare'})
dru.addSpell('aura', {'Aura of Life', 'Aura of the Grove'}, {aura=true})

dru.snare = dru.spells.snare

-- Aura of the Grove, Aura of the Grove Effect

local standard = {}
table.insert(standard, dru.spells.firenuke)

dru.spellRotations = {
    standard=standard
}

table.insert(dru.healAbilities, dru.spells.heal)

table.insert(dru.auras, dru.spells.aura)

dru.nuketimer = timer:new(5)

return dru