---@type Mq
local mq = require('mq')
local class = require(AQO..'.classes.classbase')
local common = require(AQO..'.common')
local state = require(AQO..'.state')

class.class = 'rog'
class.classOrder = {'assist', 'mash', 'burn', 'recover', 'buff', 'rest'}

class.addCommonOptions()
class.addCommonAbilities()
class.addOption('USEEVADE', 'Evade', true, nil, 'Hide and backstab on engage', 'checkbox')

table.insert(class.DPSAbilities, common.getSkill('Kick'))
table.insert(class.DPSAbilities, common.getSkill('Backstab'))
table.insert(class.DPSAbilities, common.getAA('Twisted Shank'))
table.insert(class.DPSAbilities, common.getBestDisc({'Assault'}))
table.insert(class.DPSAbilities, common.getAA('Ligament Slice'))

table.insert(class.combatBuffs, common.getAA('Envenomed Blades'))
table.insert(class.combatBuffs, common.getBestDisc({'Thief\'s Eyes'}))
table.insert(class.combatBuffs, common.getItem('Fatestealer', {checkfor='Assassin\'s Taint'}))
table.insert(class.selfBuffs, common.getAA('Sleight of Hand'))
table.insert(class.selfBuffs, common.getItem('Faded Gloves of the Shadows', {checkfor='Strike Poison'}))

table.insert(class.burnAbilities, common.getAA('Rogue\'s Fury'))
--table.insert(class.burnAbilities, common.getBestDisc({'Poison Spikes Trap'}))
table.insert(class.burnAbilities, common.getBestDisc({'Duelist Discipline'}))
table.insert(class.burnAbilities, common.getBestDisc({'Deadly Precision Discipline'}))
table.insert(class.burnAbilities, common.getBestDisc({'Frenzied Stabbing Discipline'}))
table.insert(class.burnAbilities, common.getBestDisc({'Twisted Chance Discipline'}))
table.insert(class.burnAbilities, common.getAA('Fundament: Third Spire of the Rake'))
table.insert(class.burnAbilities, common.getAA('Dirty Fighting'))

class.beforeEngage = function()
    if class.isEnabled('USEEVADE') and not mq.TLO.Me.Combat() and mq.TLO.Target.ID() == state.assist_mob_id then
        mq.cmd('/doability Hide')
        mq.delay(100)
        mq.cmd('/doability Backstab')
    end
end

return class