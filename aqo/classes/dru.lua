---@type Mq
local mq = require 'mq'
local class = require(AQO..'.classes.classbase')
local timer = require(AQO..'.utils.timer')
local common = require(AQO..'.common')

class.class = 'dru'
class.classOrder = {'heal', 'assist', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest', 'managepet'}

class.SPELLSETS = {standard=1}
class.addCommonOptions()
class.addOption('USENUKES', 'Use Nukes', false, nil, 'Toggle use of nuke spells', 'checkbox')
class.addOption('USESNARE', 'Use Snare', true, nil, 'Cast snare on mobs', 'checkbox')

class.addSpell('heal', {'Nature\'s Infusion', 'Chloroblast', 'Superior Healing', 'Nature\'s Renewal', 'Light Healing', 'Minor Healing'}, {panic=true, regular=true, pet=60})
class.addSpell('groupheal', {'Moonshadow', 'Word of Restoration'}, {group=true})
class.addSpell('firenuke', {'Dawnstrike', 'Sylvan Fire', 'Wildfire', 'Scoriae', 'Firestrike'}, {opt='USENUKES'})
class.addSpell('dot', {'Winged Death'})
class.addSpell('snare', {'Ensnare', 'Snare'})
class.addSpell('aura', {'Aura of Life', 'Aura of the Grove'})
class.addSpell('pet', {'Nature Wanderer\'s Behest'})
class.addSpell('reptile', {'Skin of the Reptile'}, {classes={MNK=true,WAR=true,PAL=true,SHD=true}})

class.snare = class.spells.snare

-- Aura of the Grove, Aura of the Grove Effect

local standard = {}
table.insert(standard, class.spells.firenuke)

class.spellRotations = {
    standard=standard
}

table.insert(class.healAbilities, class.spells.heal)
table.insert(class.healAbilities, class.spells.groupheal)

table.insert(class.auras, class.spells.aura)

table.insert(class.singleBuffs, class.spells.reptile)

table.insert(class.DPSAbilities, common.getItem('Nature Walker\'s Scimitar'))

class.nuketimer = timer:new(5)

return class