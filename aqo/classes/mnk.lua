--- @type Mq
local mq = require('mq')
local class = require('classes.classbase')
local common = require('common')

function class.init(_aqo)
    class.classOrder = {'assist', 'aggro', 'heal', 'mash', 'burn', 'recover', 'buff', 'rest', 'rez'}
    class.initBase(_aqo, 'mnk')

    class.initClassOptions()
    class.loadSettings()
    class.initDPSAbilities(_aqo)
    class.initBurns(_aqo)
    class.initBuffs(_aqo)
    class.initDefensiveAbilities(_aqo)
    class.initHeals(_aqo)

    class.useCommonListProcessor = true
end

function class.initClassOptions()
    class.addOption('USEFADE', 'Use Feign Death', true, nil, 'Toggle use of Feign Death in combat', 'checkbox')
end

function class.initDPSAbilities(_aqo)
    table.insert(class.DPSAbilities, common.getSkill('Flying Kick', {condition=_aqo.conditions.withinMeleeDistance}))
    table.insert(class.DPSAbilities, common.getSkill('Tiger Claw', {condition=_aqo.conditions.withinMeleeDistance}))
    table.insert(class.DPSAbilities, common.getBestDisc({'Dragon Fang', 'Clawstriker\'s Flurry', 'Leopard Claw'}, {condition=_aqo.conditions.withinMeleeDistance}))
    table.insert(class.DPSAbilities, common.getAA('Five Point Palm', {condition=_aqo.conditions.withinMeleeDistance}))
    --table.insert(class.DPSAbilities, common.getAA('Stunning Kick'))
    table.insert(class.DPSAbilities, common.getAA('Eye Gouge', {condition=_aqo.conditions.withinMeleeDistance}))
end

function class.initBurns(_aqo)
    table.insert(class.burnAbilities, common.getAA('Fundament: Second Spire of the Sensei'))
    table.insert(class.burnAbilities, common.getBestDisc({'Speed Focus Discipline'}))
    table.insert(class.burnAbilities, common.getBestDisc({'Crystalpalm Discipline', 'Innerflame Discipline'}))
    table.insert(class.burnAbilities, common.getBestDisc({'Heel of Kai', 'Heel of Kanji'}))
    table.insert(class.burnAbilities, common.getAA('Destructive Force', {opt='USEAOE', condition=_aqo.conditions.isEnabled}))
end

function class.initBuffs(_aqo)
    table.insert(class.auras, common.getBestDisc({'Master\'s Aura', 'Disciple\'s Aura'}, {checkfor='Disciples Aura'}))
    table.insert(class.combatBuffs, common.getItem('Fistwraps of Celestial Discipline', {delay=1000}))
    table.insert(class.combatBuffs, common.getBestDisc({'Fists of Wu'}))
    table.insert(class.combatBuffs, common.getAA('Zan Fi\'s Whistle'))
    table.insert(class.combatBuffs, common.getAA('Infusion of Thunder'))
end

function class.initDefensiveAbilities(_aqo)
    local postFD = function()
        mq.delay(1000)
        mq.cmdf('/multiline ; /stand ; /makemevis')
    end
    table.insert(class.fadeAbilities, common.getAA('Imitate Death', {opt='USEFD', postcast=postFD}))
    table.insert(class.aggroReducers, common.getSkill('Feign Death', {opt='USEFD', postcast=postFD}))
end

function class.initHeals(_aqo)
    table.insert(class.healAbilities, common.getSkill('Mend', {me=60, self=true}))
end

return class