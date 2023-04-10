--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local common = require('common')
local config = require('configuration')
local state = require('state')

function class.init(_aqo)
    class.classOrder = {'assist', 'mash', 'ae', 'burn', 'ohshit', 'recover', 'buff', 'rest'}
    class.initBase(_aqo, 'war')

    -- What were these again?
    mq.cmd('/squelch /stick mod -2')
    mq.cmd('/squelch /stick set delaystrafe on')

    class.initClassOptions()
    class.loadSettings()
    class.initTankAbilities(_aqo)
    class.initDPSAbilities(_aqo)
    class.initBuffs(_aqo)

    class.useCommonListProcessor = true
end

function class.initClassOptions(_aqo)
    class.addOption('USEBATTLELEAP', 'Use Battle Leap', true, nil, 'Keep the Battle Leap AA Buff up', 'checkbox')
    class.addOption('USEFORTITUDE', 'Use Fortitude', false, nil, 'Use Fortitude Discipline on burn', 'checkbox')
    class.addOption('USEGRAPPLE', 'Use Grapple', true, nil, 'Use Grappling Strike AA', 'checkbox')
    class.addOption('USEGRASP', 'Use Grasp', true, nil, 'Use Warlord\'s Grasp AA', 'checkbox')
    class.addOption('USEPHANTOM', 'Use Phantom', false, nil, 'Use Phantom Aggressor pet discipline', 'checkbox')
    class.addOption('USEPROJECTION', 'Use Projection', true, nil, 'Use Projection of Fury pet AA', 'checkbox')
    class.addOption('USEEXPANSE', 'Use Expanse', false, nil, 'Use Concordant Expanse for AE aggro', 'checkbox', 'USEPRECISION')
    class.addOption('USEPRECISION', 'Use Precision', false, nil, 'Use Concordant Precision for single target aggro', 'checkbox', 'USEEXPANSE')
    class.addOption('USESNARE', 'Use Snare', false, nil, 'Use Call of Challenge AA, which includes a snare', 'checkbox')
end

-- bazu bellow 69
-- mock 65
-- bellow of the mastruq 65
-- ancient: chaos cry 65
-- incite 63
-- berate 56
-- bellow 52
function class.initTankAbilities(_aqo)
    table.insert(class.tankAbilities, common.getSkill('Taunt', {aggro=true, condition=_aqo.conditions.aggroBelow}))

    class.mash_defensive = common.getBestDisc({'Primal Defense'})
    table.insert(class.tankAbilities, class.mash_defensive)
    table.insert(class.tankAbilities, common.getBestDisc({'Namdrows\' Roar', 'Bazu Bellow', 'Bellow of the Mastruq', 'Bellow'}, {condition=_aqo.conditions.withinMeleeDistance}))
    table.insert(class.tankAbilities, common.getBestDisc({'Bristle', 'Mock', 'Incite'}, {condition=_aqo.conditions.withinMeleeDistance}))
    table.insert(class.tankAbilities, common.getBestDisc({'Twilight Shout', 'Ancient: Chaos Cry', 'Berate'}, {condition=_aqo.conditions.withinMeleeDistance}))
    table.insert(class.tankAbilities, common.getBestDisc({'Composite Shield'}))
    table.insert(class.tankAbilities, common.getBestDisc({'Finish the Fight'}))
    table.insert(class.tankAbilities, common.getBestDisc({'Phantom Aggressor'}, {opt='USEPHANTOM'}))
    table.insert(class.tankAbilities, common.getBestDisc({'Confluent Precision'}, {opt='USEPRECISION'}))

    table.insert(class.tankAbilities, common.getAA('Blast of Anger', {maxdistance=100, condition=_aqo.conditions.withinMaxDistance}))
    table.insert(class.tankAbilities, common.getAA('Blade Guardian'))
    table.insert(class.tankAbilities, common.getAA('Brace for Impact'))
    table.insert(class.tankAbilities, common.getAA('Call of Challenge', {opt='USESNARE'}))
    table.insert(class.tankAbilities, common.getAA('Grappling Strike', {opt='USEGRAPPLE'}))
    table.insert(class.tankAbilities, common.getAA('Warlord\'s Grasp', {opt='USEGRASP'}))

    table.insert(class.AETankAbilities, common.getBestDisc({'Roar of Challenge'}, {threshold=2, condition=_aqo.conditions.aboveMobThreshold}))
    table.insert(class.AETankAbilities, common.getBestDisc({'Confluent Expanse'}, {opt='USEEXPANSE', threshold=2, condition=_aqo.conditions.aboveMobThreshold}))
    table.insert(class.AETankAbilities, common.getBestDisc({'Wade into Battle'}, {threshold=4, condition=_aqo.conditions.aboveMobThreshold}))
    local aeTauntOpts = {threshold=3, condition=_aqo.conditions.aboveMobThreshold}
    table.insert(class.AETankAbilities, common.getAA('Extended Area Taunt', aeTauntOpts) or common.getAA('Area Taunt', aeTauntOpts))

    table.insert(class.tankBurnAbilities, common.getBestDisc({'Unrelenting Attention', 'Unyielding Attention', 'Undivided Attention'}, {condition=_aqo.conditions.withinMeleeDistance}))
    --table.insert(class.tankBurnAbilities, common.getBestDisc({'Resolute Stand', 'Stonewall Discipline', 'Defensive Discipline'}, {overwritedisc=mash_defensive and mash_defensive.Name or nil}))
    table.insert(class.tankBurnAbilities, common.getBestDisc({'Armor of Akhevan Runes'}, {overwritedisc=class.mash_defensive and class.mash_defensive.Name or nil}))
    table.insert(class.tankBurnAbilities, common.getBestDisc({'Levincrash Defense Discipline'}, {overwritedisc=class.mash_defensive and class.mash_defensive.Name or nil}))
    table.insert(class.tankBurnAbilities, common.getAA('Ageless Enmity', {aggro=true, condition=_aqo.conditions.aggroBelow})) -- big taunt
    table.insert(class.tankBurnAbilities, common.getAA('Projection of Fury', {opt='USEPROJECTION'}))
    table.insert(class.tankBurnAbilities, common.getAA('Warlord\'s Fury')) -- more big aggro
    table.insert(class.tankBurnAbilities, common.getAA('Mark of the Mage Hunter')) -- 25% spell dmg absorb
    table.insert(class.tankBurnAbilities, common.getAA('Resplendent Glory')) -- increase incoming heals
    table.insert(class.tankBurnAbilities, common.getAA('Warlord\'s Bravery')) -- reduce incoming melee dmg
    table.insert(class.tankBurnAbilities, common.getAA('Warlord\'s Tenacity')) -- big heal and temp HP
    if state.emu then
        table.insert(class.tankBurnAbilities, common.getAA('Fundament: Third Spire of the Warlord'))
    else
        -- live mashed these two together in ae, not just burns..
        table.insert(class.tankBurnAbilities, common.getAA('Spire of the Warlord'))
        table.insert(class.tankBurnAbilities, common.getBestDisc({'Warrior\'s Aegis'}))
    end

    -- what to do with this one..
    class.attraction = common.getBestDisc({'Forceful Attraction'})

    class.fortitude = common.getBestDisc({'Fortitude Discipline'}, {opt='USEFORTITUDE'})
    class.flash = common.getBestDisc({'Flash of Anger'})
    class.resurgence = common.getAA('Warlord\'s Resurgence') -- 10min cd, 60k heal
end

function class.initDPSAbilities(_aqo)
    table.insert(class.AEDPSAbilities, common.getBestDisc({'Vortex Blade', 'Cyclone Blade'}, {threshold=3, condition=_aqo.conditions.aboveMobThreshold}))
    table.insert(class.AEDPSAbilities, common.getAA('Rampage', {threshold=5, condition=_aqo.conditions.aboveMobThreshold}))
    table.insert(class.DPSAbilities, common.getSkill('Kick', {condition=_aqo.conditions.withinMeleeDistance}))

    table.insert(class.DPSAbilities, common.getBestDisc({'Shield Splinter'}, {condition=_aqo.conditions.withinMeleeDistance}))
    table.insert(class.DPSAbilities, common.getBestDisc({'Throat Jab'}, {condition=_aqo.conditions.withinMeleeDistance}))
    table.insert(class.DPSAbilities, common.getBestDisc({'Knuckle Break'}, {condition=_aqo.conditions.withinMeleeDistance}))

    table.insert(class.DPSAbilities, common.getAA('Gut Punch', {condition=_aqo.conditions.withinMeleeDistance}))
    table.insert(class.DPSAbilities, common.getAA('Knee Strike', {condition=_aqo.conditions.withinMeleeDistance}))
    table.insert(class.DPSAbilities, common.getBestDisc({'Exploitive Strike'}, {usebelowpct=20, condition=function(ability) return _aqo.conditions.targetHPBelow(ability) and _aqo.conditions.withinMeleeDistance(ability) end})) -- 35s cd, timer 9, 2H attack, Mob HP 20% or below only

    --table.insert(class.burnAbilities, common.getBestDisc({'Brightfield\'s Onslaught Discipline', 'Brutal Onslaught Discipline', 'Savage Onslaught Discipline'})) -- 15min cd, timer 6, 270% crit chance, 160% crit dmg, crippling blows, increase min dmg
    table.insert(class.burnAbilities, common.getBestDisc({'Offensive Discipline'})) -- 4min cd, timer 2, increased offensive capabilities

    table.insert(class.burnAbilities, common.getAA('War Sheol\'s Heroic Blade')) -- 15min cd, 3 2HS attacks, crit % and dmg buff for 1 min
end

function class.initBuffs(_aqo)
    -- Buffs and Other
    local breatherCondition = function(ability)
        return mq.TLO.Me.PctEndurance() <= config.get('RECOVERPCT') and (ability.combat or mq.TLO.Me.CombatState() ~= 'COMBAT')
    end
    table.insert(class.recoverAbilities, common.getBestDisc({'Breather'}, {combat=false, endurance=true, threshold=20, condition=breatherCondition}))

    local leapCondition = function(ability)
        return false
    end
    class.leap = common.getAA('Battle Leap', {opt='USEBATTLELEAP', maxdistance=30, delay=500, combat=false, condition=leapCondition})
    table.insert(class.auras, common.getBestDisc({'Champion\'s Aura', 'Myrmidon\'s Aura'}))
    table.insert(class.combatBuffs, common.getBestDisc({'Full Moon\'s Champion', 'Field Armorer'}, {condition=_aqo.conditions.missingBuff}))
    table.insert(class.combatBuffs, common.getAA('Imperator\'s Command'))

    table.insert(class.selfBuffs, common.getAA('Infused by Rage'))

    if not state.emu then
        table.insert(class.selfBuffs, common.getItem('Huntsman\'s Ethereal Quiver', {summons='Ethereal Arrow', summonMinimum=101, condition=_aqo.conditions.summonMinimum}))
        table.insert(class.combatBuffs, common.getBestDisc({'Commanding Voice'}))
    end
end

function class.ohShitClass()
    if state.loop.PctHPs < 35 and mq.TLO.Me.CombatState() == 'COMBAT' then
        if class.resurgence then class.resurgence:use() end
        if config.get('MODE'):isTankMode() or mq.TLO.Group.MainTank.ID() == state.loop.ID then
            if class.flash and mq.TLO.Me.CombatAbilityReady(class.flash.Name)() then
                class.flash:use()
            elseif class.fortitude and class.isEnabled(class.fortitude.opt) then
                class.fortitude:use(class.mash_defensive and class.mash_defensive.Name or nil)
            end
        end
    end
end

return class
