--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local common = require('common')
local config = require('interface.configuration')
local conditions = require('routines.conditions')
local mode = require('mode')
local state = require('state')

local Warrior = class:new()

--[[
    https://forums.eqfreelance.net/index.php?topic=2973.0

    
]]
function Warrior:init()
    self.classOrder = {'assist', 'mash', 'ae', 'burn', 'ohshit', 'recover', 'buff', 'rest'}
    self:initBase('WAR')

    -- What were these again?
    mq.cmd('/squelch /stick mod -2')
    mq.cmd('/squelch /stick set delaystrafe on')

    self:initClassOptions()
    self:loadSettings()
    self:initTankAbilities()
    self:initDPSAbilities()
    self:initBuffs()
    self:addCommonAbilities()

    self.useCommonListProcessor = true
end

function Warrior:initClassOptions()
    self:addOption('USEBATTLELEAP', 'Use Battle Leap', true, nil, 'Keep the Battle Leap AA Buff up', 'checkbox', nil, 'UseBattleLeap', 'bool')
    self:addOption('USEFORTITUDE', 'Use Fortitude', false, nil, 'Use Fortitude Discipline on burn', 'checkbox', nil, 'UseFortitude', 'bool')
    self:addOption('USEGRAPPLE', 'Use Grapple', true, nil, 'Use Grappling Strike AA', 'checkbox', nil, 'UseGrapple', 'bool')
    self:addOption('USEGRASP', 'Use Grasp', true, nil, 'Use Warlord\'s Grasp AA', 'checkbox', nil, 'UseGrasp', 'bool')
    self:addOption('USEPHANTOM', 'Use Phantom', false, nil, 'Use Phantom Aggressor pet discipline', 'checkbox', nil, 'UsePhantom', 'bool')
    self:addOption('USEPROJECTION', 'Use Projection', true, nil, 'Use Projection of Fury pet AA', 'checkbox', nil, 'UseProjection', 'bool')
    self:addOption('USEEXPANSE', 'Use Expanse', false, nil, 'Use Concordant Expanse for AE aggro', 'checkbox', 'USEPRECISION', 'UseExpanse', 'bool')
    self:addOption('USEPRECISION', 'Use Precision', false, nil, 'Use Concordant Precision for single target aggro', 'checkbox', 'USEEXPANSE', 'UsePrecision', 'bool')
    self:addOption('USESNARE', 'Use Snare', false, nil, 'Use Call of Challenge AA, which includes a snare', 'checkbox', nil, 'UseSnare', 'bool')
end

-- bazu bellow 69
-- mock 65
-- bellow of the mastruq 65
-- ancient: chaos cry 65
-- incite 63
-- berate 56
-- bellow 52
function Warrior:initTankAbilities()
    local lowAggroInMelee = function(ability)
        local aggropct = mq.TLO.Target.PctAggro() or 100
        local targetDistance = mq.TLO.Target.Distance3D() or 300
        local targetMaxRange  = mq.TLO.Target.MaxRangeTo() or 0
        return (ability.aggro == nil or aggropct < 100) and targetDistance <= targetMaxRange
    end
    table.insert(self.tankAbilities, common.getSkill('Taunt', {aggro=true, condition=lowAggroInMelee}))

    self.mash_defensive = common.getBestDisc({'Vigorous Defense', 'Primal Defense'})
    table.insert(self.tankAbilities, self.mash_defensive)
    table.insert(self.tankAbilities, common.getBestDisc({'Mortimus\' Roar', 'Namdrows\' Roar', 'Bazu Bellow', 'Bellow of the Mastruq', 'Bellow'}, {condition=conditions.withinMeleeDistance}))
    table.insert(self.tankAbilities, common.getBestDisc({'Infuriate', 'Bristle', 'Mock', 'Incite'}, {condition=conditions.withinMeleeDistance}))
    table.insert(self.tankAbilities, common.getBestDisc({'Distressing Shout', 'Twilight Shout', 'Ancient: Chaos Cry', 'Berate'}, {condition=conditions.withinMeleeDistance}))
    table.insert(self.tankAbilities, common.getBestDisc({'Composite Shield'}))
    table.insert(self.tankAbilities, common.getBestDisc({'End of the Line', 'Finish the Fight'}))
    table.insert(self.tankAbilities, common.getBestDisc({'Phantom Aggressor'}, {opt='USEPHANTOM'}))
    table.insert(self.tankAbilities, common.getBestDisc({'Confluent Precision'}, {opt='USEPRECISION'}))

    table.insert(self.tankAbilities, common.getAA('Blast of Anger', {maxdistance=100, condition=conditions.withinMaxDistance}))
    table.insert(self.tankAbilities, common.getAA('Blade Guardian'))
    table.insert(self.tankAbilities, common.getAA('Brace for Impact'))
    table.insert(self.tankAbilities, common.getAA('Call of Challenge', {opt='USESNARE'}))
    table.insert(self.tankAbilities, common.getAA('Grappling Strike', {opt='USEGRAPPLE'}))
    table.insert(self.tankAbilities, common.getAA('Warlord\'s Grasp', {opt='USEGRASP'}))

    table.insert(self.AETankAbilities, common.getBestDisc({'Roar of Challenge'}, {threshold=2, condition=conditions.aboveMobThreshold}))
    table.insert(self.AETankAbilities, common.getBestDisc({'Confluent Expanse'}, {opt='USEEXPANSE', threshold=2, condition=conditions.aboveMobThreshold}))
    table.insert(self.AETankAbilities, common.getBestDisc({'Wade into Battle'}, {threshold=4, condition=conditions.aboveMobThreshold}))
    local aeTauntOpts = {threshold=3, condition=conditions.aboveMobThreshold}
    table.insert(self.AETankAbilities, common.getAA('Extended Area Taunt', aeTauntOpts) or common.getAA('Area Taunt', aeTauntOpts))
    -- 'Razor Tongue Discipline' -- proc on taunt

    table.insert(self.tankBurnAbilities, common.getBestDisc({'Unconditional Attention', 'Unrelenting Attention', 'Unyielding Attention', 'Undivided Attention'}, {condition=conditions.withinMeleeDistance}))
    --table.insert(self.tankBurnAbilities, common.getBestDisc({'Climactic Stand', 'Resolute Stand', 'Stonewall Discipline', 'Defensive Discipline'}, {overwritedisc=mash_defensive and mash_defensive.Name or nil}))
    table.insert(self.tankBurnAbilities, common.getBestDisc({'Armor of Rallosian Runes', 'Armor of Akhevan Runes'}, {overwritedisc=self.mash_defensive and self.mash_defensive.Name or nil}))
    table.insert(self.tankBurnAbilities, common.getBestDisc({'Levincrash Defense Discipline'}, {overwritedisc=self.mash_defensive and self.mash_defensive.Name or nil}))
    table.insert(self.tankBurnAbilities, common.getAA('Ageless Enmity', {aggro=true, condition=conditions.aggroBelow})) -- big taunt
    table.insert(self.tankBurnAbilities, common.getAA('Projection of Fury', {opt='USEPROJECTION'}))
    table.insert(self.tankBurnAbilities, common.getAA('Warlord\'s Fury')) -- more big aggro
    table.insert(self.tankBurnAbilities, common.getAA('Mark of the Mage Hunter')) -- 25% spell dmg absorb
    table.insert(self.tankBurnAbilities, common.getAA('Resplendent Glory')) -- increase incoming heals
    table.insert(self.tankBurnAbilities, common.getAA('Warlord\'s Bravery')) -- reduce incoming melee dmg
    table.insert(self.tankBurnAbilities, common.getAA('Warlord\'s Tenacity')) -- big heal and temp HP
    if state.emu then
        table.insert(self.tankBurnAbilities, common.getAA('Fundament: Third Spire of the Warlord'))
    else
        -- live mashed these two together in ae, not just burns..
        table.insert(self.tankBurnAbilities, common.getAA('Spire of the Warlord'))
        table.insert(self.tankBurnAbilities, common.getBestDisc({'Warrior\'s Resolve', 'Warrior\'s Aegis'}))
    end

    -- what to do with this one..
    self.attraction = common.getBestDisc({'Forceful Attraction'})

    self.fortitude = common.getBestDisc({'Fortitude Discipline'}, {opt='USEFORTITUDE', overwritesdisc=self.mash_defensive and self.mash_defensive.name or nil})
    self.flash = common.getBestDisc({'Flash of Anger'})
    self.resurgence = common.getAA('Warlord\'s Resurgence') -- 10min cd, 60k heal
end

function Warrior:initDPSAbilities()
    table.insert(self.AEDPSAbilities, common.getBestDisc({'Spiraling Blades', 'Vortex Blade', 'Cyclone Blade'}, {threshold=3, condition=conditions.aboveMobThreshold}))
    table.insert(self.AEDPSAbilities, common.getAA('Rampage', {threshold=5, condition=conditions.aboveMobThreshold}))
    table.insert(self.DPSAbilities, common.getSkill('Kick', {condition=conditions.withinMeleeDistance}))

    table.insert(self.DPSAbilities, common.getBestDisc({'Shield Splinter'}, {condition=conditions.withinMeleeDistance}))
    table.insert(self.DPSAbilities, common.getBestDisc({'Throat Jab'}, {condition=conditions.withinMeleeDistance}))
    table.insert(self.DPSAbilities, common.getBestDisc({'Knuckle Break'}, {condition=conditions.withinMeleeDistance}))

    table.insert(self.DPSAbilities, common.getAA('Gut Punch', {condition=conditions.withinMeleeDistance}))
    table.insert(self.DPSAbilities, common.getAA('Knee Strike', {condition=conditions.withinMeleeDistance}))
    table.insert(self.DPSAbilities, common.getBestDisc({'Decisive Strike', 'Exploitive Strike'}, {usebelowpct=20, condition=function(ability) return conditions.targetHPBelow(ability) and conditions.withinMeleeDistance(ability) end})) -- 35s cd, timer 9, 2H attack, Mob HP 20% or below only

    --table.insert(self.burnAbilities, common.getBestDisc({'Brightfield\'s Onslaught Discipline', 'Brutal Onslaught Discipline', 'Savage Onslaught Discipline'})) -- 15min cd, timer 6, 270% crit chance, 160% crit dmg, crippling blows, increase min dmg
    table.insert(self.burnAbilities, common.getBestDisc({'Offensive Discipline'})) -- 4min cd, timer 2, increased offensive capabilities

    table.insert(self.burnAbilities, common.getAA('War Sheol\'s Heroic Blade')) -- 15min cd, 3 2HS attacks, crit % and dmg buff for 1 min
end

function Warrior:initBuffs()
    -- Buffs and Other
    local breatherCondition = function(ability)
        return mq.TLO.Me.PctEndurance() <= config.get('RECOVERPCT') and (ability.combat or mq.TLO.Me.CombatState() ~= 'COMBAT')
    end
    table.insert(self.recoverAbilities, common.getBestDisc({'Breather'}, {combat=false, endurance=true, threshold=20, condition=breatherCondition}))

    local leapCondition = function(ability)
        return false
    end
    self.leap = common.getAA('Battle Leap', {opt='USEBATTLELEAP', maxdistance=30, delay=500, combat=false, condition=leapCondition})
    table.insert(self.auras, common.getBestDisc({'Champion\'s Aura', 'Myrmidon\'s Aura'}))
    table.insert(self.combatBuffs, common.getBestDisc({'Field Bulwark', 'Full Moon\'s Champion', 'Field Armorer'}, {condition=conditions.missingBuff}))
    table.insert(self.combatBuffs, common.getAA('Imperator\'s Command'))

    table.insert(self.selfBuffs, common.getAA('Infused by Rage'))

    if not state.emu then
        table.insert(self.selfBuffs, common.getItem('Huntsman\'s Ethereal Quiver', {summonMinimum=101, condition=conditions.summonMinimum}))
        table.insert(self.combatBuffs, common.getBestDisc({'Commanding Voice'}))
    end
end

function Warrior:ohShitClass()
    if mq.TLO.Me.PctHPs() < 35 and mq.TLO.Me.CombatState() == 'COMBAT' then
        if self.resurgence then self.resurgence:use() end
        if mode.currentMode:isTankMode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
            if self.flash and mq.TLO.Me.CombatAbilityReady(self.flash.Name)() then
                self.flash:use()
            elseif self.fortitude and self:isEnabled(self.fortitude.opt) then
                self.fortitude:use(self.mash_defensive and self.mash_defensive.Name or nil)
            end
        end
    end
end

return Warrior
