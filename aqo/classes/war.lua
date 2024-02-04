--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local common = require('common')
local config = require('interface.configuration')
local conditions = require('routines.conditions')
local sharedabilities = require('utils.sharedabilities')
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
    self:initAbilities()
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

Warrior.Abilities = {
    {
        Type='Skill',
        Name='Taunt',
        Options={tanking=true, aggro=true, condition=conditions.lowAggroInMelee}
    },
    {
        Type='Disc',
        Group='defense',
        Names={'Vigorous Defense', 'Primal Defense'},
        Options={tanking=true}
    },
    {
        Type='Disc',
        Group='provoke1',
        Names={'Mortimus\' Roar', 'Namdrows\' Roar', 'Bazu Bellow', 'Bellow of the Mastruq', 'Bellow'},
        Options={tanking=true, condition=conditions.withinMeleeDistance}
    },
    {
        Type='Disc',
        Group='provoke2',
        Names={'Infuriate', 'Bristle', 'Mock', 'Incite'},
        Options={tanking=true, condition=conditions.withinMeleeDistance}
    },
    {
        Type='Disc',
        Group='provoke3',
        Names={'Distressing Shout', 'Twilight Shout', 'Ancient: Chaos Cry', 'Berate'},
        Options={tanking=true, condition=conditions.withinMeleeDistance}
    },
    {
        Type='Disc',
        Group='composite',
        Names={'Ecliptic Shield', 'Composite Shield', 'Dissident Shield', 'Dichotomic Shield'},
        Options={tanking=true}
    },
    {
        Type='Disc',
        Group='dmgabsorb',
        Names={'End of the Line', 'Finish the Fight'},
        Options={tanking=true}
    },
    {
        Type='Disc',
        Group='phantom',
        Names={'Phantom Aggressor'},
        Options={tanking=true, opt='USEPHANTOM'}
    },
    {
        Type='Disc',
        Group='precision',
        Names={'Confluent Precision'},
        Options={tanking=true, opt='USEPRECISION'}
    },
    {
        Type='AA',
        Name='Blast of Anger',
        Options={tanking=true, maxdistance=100, condition=conditions.withinMaxDistance}
    },
    {
        Type='AA',
        Name='Blade Guardian',
        Options={tanking=true}
    },
    {
        Type='AA',
        Name='Brace for Impact',
        Options={tanking=true}
    },
    {
        Type='AA',
        Name='Call of Challenge',
        Options={tanking=true, opt='USESNARE'}
    },
    {
        Type='AA',
        Name='Grappling Strike',
        Options={tanking=true, opt='USEGRAPPLE'}
    },
    {
        Type='AA',
        Name='Warlord\'s Grasp',
        Options={tanking=true, opt='USEGRASP'}
    },

    -- ae tank
    {
        Type='Disc',
        Group='roar',
        Names={'Roar of Challenge'},
        Options={aetank=true, threshold=2, condition=conditions.aboveMobThreshold}
    },
    {
        Type='Disc',
        Group='expanse',
        Names={'Confluent Expanse'},
        Options={aetank=true, opt='USEEXPANSE', threshold=2, condition=conditions.aboveMobThreshold}
    },
    {
        Type='Disc',
        Group='aewade',
        Names={'Wade into Battle'},
        Options={aetank=true, threshold=4, condition=conditions.aboveMobThreshold}
    },
    {
        Type='AA',
        Name='Extended Area Taunt',
        Options={aetank=true, threshold=3, condition=conditions.aboveMobThreshold}
    },
    {
        Type='AA',
        Name='Area Taunt',
        Options={aetank=true, threshold=3, condition=conditions.aboveMobThreshold}
    },
    -- 'Razor Tongue Discipline' -- proc on taunt

    -- tank burn
    {
        Type='Disc',
        Group='attention',
        Names={'Unconditional Attention', 'Unrelenting Attention', 'Unyielding Attention', 'Undivided Attention'},
        Options={tankburn=true, condition=conditions.withinMeleeDistance}
    },
    --table.insert(self.tankBurnAbilities, common.getBestDisc({'Climactic Stand', 'Resolute Stand', 'Stonewall Discipline', 'Defensive Discipline'}, {overwritedisc=mash_defensive and mash_defensive.Name or nil}))
    {
        Type='Disc',
        Group='armorrunes',
        Names={'Armor of Rallosian Runes', 'Armor of Akhevan Runes'},
        Options={tankburn=true, overwritedisc=Warrior.defense and Warrior.defense.Name or nil}
    },
    {
        Type='Disc',
        Group='defenseburn',
        Names={'Levincrash Defense Discipline'},
        Options={tankburn=true, overwritedisc=Warrior.defense and Warrior.defense.Name or nil}
    },
    { -- big taunt
        Type='AA',
        Name='Ageless Enmity',
        Options={tankburn=true, aggro=true, condition=conditions.aggroBelow}
    },
    {
        Type='AA',
        Name='Projection of Fury',
        Options={tankburn=true, opt='USEPROJECTION'}
    },
    { -- more big aggro
        Type='AA',
        Name='Warlord\'s Fury',
        Options={tankburn=true, }
    },
    { -- 25% spell dmg absorb
        Type='AA',
        Name='Mark of the Mage Hunter',
        Options={tankburn=true, }
    },
    { -- increase incoming heals
        Type='AA',
        Name='Resplendent Glory',
        Options={tankburn=true, }
    },
    { -- reduce incoming melee dmg
        Type='AA',
        Name='Warlord\'s Bravery',
        Options={tankburn=true, }
    },
    { -- big heal and temp HP
        Type='AA',
        Name='Warlord\'s Tenacity',
        Options={tankburn=true, }
    },
    {
        Type='AA',
        Name='Spire of the Warlord',
        Options={tankburn=true}
    },
    {
        Type='AA',
        Name='Fundament: Third Spire of the Warlord',
        Options={tankburn=true}
    },
    {
        Type='Disc',
        Group='resolve',
        Names={'Warrior\'s Resolve', 'Warrior\'s Aegis'},
        Options={tankburn=true}
    },

    {
        Type='Disc',
        Group='attraction',
        Names={'Forceful Attraction'},
        Options={opt='USEATTRACTION'}
    },
    {
        Type='Disc',
        Group='fortitude',
        Names={'Fortitude Discipline'},
        Options={opt='USEFORTITUDE', overwritesdisc=Warrior.defense and Warrior.defense.name or nil}
    },
    {
        Type='Disc',
        Group='flash',
        Names={'Flash of Anger'},
        Options={}
    },
    { -- 10min cd, 60k heal
        Type='AA',
        Name='Warlord\'s Resurgence',
        Options={key='resurgence'}
    },

    -- DPS
    {
        Type='Disc',
        Group='vortex',
        Names={'Spiraling Blades', 'Vortex Blade', 'Cyclone Blade'},
        Options={aedps=true, threshold=3, condition=conditions.aboveMobThreshold}
    },
    {
        Type='AA',
        Name='Rampage',
        Options={aedps=true, threshold=5, condition=conditions.aboveMobThreshold}
    },
    {
        Type='Skill',
        Name='Kick',
        Options={dps=true, condition=conditions.withinMeleeDistance}
    },
    {
        Type='Disc',
        Group='shieldbreak',
        Names={'Shield Splinter'},
        Options={dps=true, condition=conditions.withinMeleeDistance}
    },
    {
        Type='Disc',
        Group='throatjab',
        Names={'Throat Jab'},
        Options={dps=true, condition=conditions.withinMeleeDistance}
    },
    {
        Type='Disc',
        Group='knucklebreak',
        Names={'Knuckle Break'},
        Options={dps=true, condition=conditions.withinMeleeDistance}
    },
    {
        Type='AA',
        Name='Gut Punch',
        Options={dps=true, condition=conditions.withinMeleeDistance}
    },
    {
        Type='AA',
        Name='Knee Strike',
        Options={dps=true, condition=conditions.withinMeleeDistance}
    },
    { -- 35s cd, timer 9, 2H attack, Mob HP 20% or below only
        Type='Disc',
        Group='strike',
        Names={'Decisive Strike', 'Exploitive Strike'},
        Options={dps=true, usebelowpct=20, condition=function(ability) return conditions.targetHPBelow(ability) and conditions.withinMeleeDistance(ability) end}
    },
    --table.insert(self.burnAbilities, common.getBestDisc({'Brightfield\'s Onslaught Discipline', 'Brutal Onslaught Discipline', 'Savage Onslaught Discipline'})) -- 15min cd, timer 6, 270% crit chance, 160% crit dmg, crippling blows, increase min dmg
    { -- 4min cd, timer 2, increased offensive capabilities
        Type='Disc',
        Group='offensive',
        Names={'Offensive Discipline'},
        Options={first=true}
    },
    { -- 15min cd, 3 2HS attacks, crit % and dmg buff for 1 min
        Type='AA',
        Name='War Sheol\'s Heroic Blade',
        Options={first=true}
    },

    -- Buffs
    {
        Type='Disc',
        Group='endregen',
        Names={'Breather'},
        Options={recover=true, combat=false, endurance=true, threshold=20, condition=function(ability) return mq.TLO.Me.PctEndurance() <= config.get('RECOVERPCT') and (ability.combat or mq.TLO.Me.CombatState() ~= 'COMBAT') end}
    },
    {
        Type='AA',
        Name='Battle Leap',
        Options={key='leap', combatbuff=true, opt='USEBATTLELEAP', maxdistance=30, delay=500, combat=false, condition=function(ability) return false end}
    },
    {
        Type='Disc',
        Group='aura',
        Names={'Champion\'s Aura', 'Myrmidon\'s Aura'},
        Options={aurabuff=true}
    },
    {
        Type='Disc',
        Group='fieldbuff',
        Names={'Field Bulwark', 'Full Moon\'s Champion', 'Field Armorer'},
        Options={condition=conditions.missingBuff, combatbuff=true}
    },
    {
        Type='AA',
        Name='Imperator\'s Command',
        Options={combatbuff=true}
    },
    {
        Type='AA',
        Name='Infused by Rage',
        Options={selfbuff=true}
    },
    {
        Type='Item',
        Name='Huntsman\'s Ethereal Quiver',
        Options={summonMinimum=101, condition=conditions.summonMinimum, selfbuff=true}
    },
    {
        Type='Disc',
        Group='voice',
        Names={'Commanding Voice'},
        Options={combatbuff=not state.emu and true or false}
    },
}

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
