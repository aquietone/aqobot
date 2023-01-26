---@type Mq
local mq = require('mq')
local class = require('classes.classbase')
local common = require('common')
local state = require('state')

function class.init(_aqo)
    class.classOrder = {'assist', 'aggro', 'mash', 'burn', 'recover', 'buff', 'rest'}
    class.initBase(_aqo, 'rog')

    class.addOption('USEEVADE', 'Evade', true, nil, 'Hide and backstab on engage', 'checkbox')

    table.insert(class.DPSAbilities, common.getSkill('Kick'))
    table.insert(class.DPSAbilities, common.getSkill('Backstab'))
    table.insert(class.DPSAbilities, common.getAA('Twisted Shank'))
    table.insert(class.DPSAbilities, common.getBestDisc({'Assault'}))
    table.insert(class.DPSAbilities, common.getAA('Ligament Slice'))

    table.insert(class.combatBuffs, common.getAA('Envenomed Blades'))
    table.insert(class.combatBuffs, common.getBestDisc({'Brigand\'s Gaze', 'Thief\'s Eyes'}))
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
end

class.beforeEngage = function()
    if class.isEnabled('USEEVADE') and not mq.TLO.Me.Combat() and mq.TLO.Target.ID() == state.assistMobID then
        mq.cmd('/doability Hide')
        mq.delay(100)
        mq.cmd('/doability Backstab')
    end
end

class.aggroClass = function()
    if mq.TLO.Me.AbilityReady('hide') then
        if mq.TLO.Me.Combat() then
            mq.cmd('/attack off')
            mq.delay(1000, function() return not mq.TLO.Me.Combat() end)
        end
        mq.cmd('/doability hide')
        mq.delay(500, function() return mq.TLO.Me.Invis() end)
        mq.cmd('/attack on')
    end
end

return class