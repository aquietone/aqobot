--- @type Mq
local mq = require('mq')
local class = require('classes.classbase')
local common = require('common')

function class.init(_aqo)
    class.classOrder = {'assist', 'aggro', 'heal', 'mash', 'burn', 'recover', 'buff', 'rest'}
    class.initBase(_aqo, 'mnk')

    class.addOption('USEFADE', 'Use Feign Death', true, nil, 'Toggle use of Feign Death in combat', 'checkbox')

    table.insert(class.DPSAbilities, common.getItem('Fistwraps of Celestial Discipline', {delay=1000}))
    table.insert(class.DPSAbilities, common.getSkill('Flying Kick'))
    table.insert(class.DPSAbilities, common.getSkill('Tiger Claw'))
    table.insert(class.DPSAbilities, common.getBestDisc({'Dragon Fang', 'Clawstriker\'s Flurry', 'Leopard Claw'}))
    table.insert(class.DPSAbilities, common.getAA('Five Point Palm'))
    --table.insert(class.DPSAbilities, common.getAA('Stunning Kick'))
    table.insert(class.DPSAbilities, common.getAA('Eye Gouge'))

    table.insert(class.burnAbilities, common.getAA('Fundament: Second Spire of the Sensei'))
    table.insert(class.burnAbilities, common.getBestDisc({'Speed Focus Discipline'}))
    table.insert(class.burnAbilities, common.getBestDisc({'Crystalpalm Discipline', 'Innerflame Discipline'}))
    table.insert(class.burnAbilities, common.getBestDisc({'Heel of Kai', 'Heel of Kanji'}))
    table.insert(class.burnAbilities, common.getAA('Destructive Force', {opt='USEAOE'}))

    table.insert(class.auras, common.getBestDisc({'Master\'s Aura', 'Disciple\'s Aura'}, {checkfor='Disciples Aura'}))
    table.insert(class.combatBuffs, common.getBestDisc({'Fists of Wu'}))
    table.insert(class.combatBuffs, common.getAA('Zan Fi\'s Whistle'))
    table.insert(class.combatBuffs, common.getAA('Infusion of Thunder'))

    table.insert(class.healAbilities, common.getSkill('Mend', {me=60, self=true}))

    local postFD = function()
        mq.delay(1000)
        mq.cmdf('/multiline ; /stand ; /makemevis')
    end
    table.insert(class.fadeAbilities, common.getAA('Imitate Death', {opt='USEFD', postcast=postFD}))
    table.insert(class.aggroReducers, common.getSkill('Feign Death', {opt='USEFD', postcast=postFD}))
end

return class