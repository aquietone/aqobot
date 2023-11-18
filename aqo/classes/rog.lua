---@type Mq
local mq = require('mq')
local class = require('classes.classbase')
local conditions = require('routines.conditions')
local common = require('common')
local state = require('state')

local Rogue = class:new()

--[[
    http://forums.eqfreelance.net/index.php?topic=27744.0;prev_next=prev#new

    common.getBestDisc({'Slash'}) -- Use on CD, dot, hate reduction
    common.getBestDisc({'Cloaked Blade'}) -- Use on CD, adds extra strikes to attacks
    common.getBestDisc({'Drachnid Blade'}) -- use on CD, chance for extra melee attack dmg
    common.getBestDisc({'Jugular Cut'}) -- Use on CD, dot, hate reduction
    common.getBestDisc({'Naive Mark'}) -- Use on CD, inc incoming piercing dmg
    common.getBestDisc({'Thief\'s Vision'}) -- Use on CD, inc accuracy
    common.getBestDisc({'Pinpoint Shortcomings'}) -- Use on CD, inc dmg taken from backstabs
    common.getAA('Twisted Shank') -- Use on CD, dot, reduce healing effectiveness
    common.getAA('Envenomed Blades') -- Use on CD, poison proc
    common.getAA('Absorbing Agent') -- Use on CD, inc incoming spell dmg

    common.getBestDisc({'Blitzstrike'}) -- hit + inc dmg dealt
    common.getBestDisc({'Chelicerae Discipline'}) -- inc proc rate + inc poison dmg
    common.getBestDisc({'Vexatious Puncture'}) -- backstab, hate reduction
    common.getBestDisc({'Poisonous Alliance Effect'}) -- inc poison dmg taken

    common.getAA('Rake\'s Rampage') -- ae attack
    
    -- Main Burn
    common.getAA('Rogue\'s Fury') -- inc all skills dmg modifiers, min dmg, chance to hit
    common.getBestDisc({'Frenzied Stabbing Discipline'}) -- more backstabs
    common.getAA('Focused Rake\'s Rampage') -- single target rampage
    common.getBestDisc({'Dissident Weapons'}) -- inc dmg
    common.getAA('Spire of the Rake') -- inc crit dmg, chance, dmg bonus
    common.getAA('Shadow\'s Flanking') -- inc melee dmg from behind

    -- Second Burn
    common.getBestDisc({'Twisted Chance Discipline'}) -- inc chance to hit + crit
    -- common.getBestDisc({'Cloaking Speed Discipline'}) -- inc attack speed, long CD

    -- Third Burn
    common.getBestDisc({'Ragged Edge Discipline'}) -- inc accuracy
    common.getBestDisc({'Knifeplay Discipline'}) -- inc chance to hit
    -- common.getBestDisc({'Executioner Discipline'}) -- inc dmg of all melee attacks

    -- Poisons
    -- Etherbrewed Toxin
    -- Mana Poison
    -- Draconic Poison

    
]]
function Rogue:init()
    self.classOrder = {'assist', 'aggro', 'mash', 'burn', 'recover', 'buff', 'rest', 'rez'}
    self:initBase('rog')

    self:initClassOptions()
    self:loadSettings()
    self:initDPSAbilities()
    self:initBurns()
    self:initBuffs()

    self.useCommonListProcessor = true
end

function Rogue:initClassOptions()
    self:addOption('USEEVADE', 'Evade', true, nil, 'Hide and backstab on engage', 'checkbox', nil, 'UseEvade', 'bool')
end

function Rogue:initDPSAbilities()
    table.insert(self.DPSAbilities, common.getSkill('Kick', {conditions=conditions.withinMeleeDistance}))
    table.insert(self.DPSAbilities, common.getSkill('Backstab', {conditions=conditions.withinMeleeDistance}))
    table.insert(self.DPSAbilities, common.getAA('Twisted Shank', {conditions=conditions.withinMeleeDistance}))
    table.insert(self.DPSAbilities, common.getBestDisc({'Assault', {conditions=conditions.withinMeleeDistance}}))
    table.insert(self.DPSAbilities, common.getAA('Ligament Slice', {conditions=conditions.withinMeleeDistance}))
end

function Rogue:initBurns()
    table.insert(self.burnAbilities, common.getAA('Rogue\'s Fury'))
    --table.insert(self.burnAbilities, common.getBestDisc({'Poison Spikes Trap'}))
    table.insert(self.burnAbilities, common.getBestDisc({'Duelist Discipline'}))
    table.insert(self.burnAbilities, common.getBestDisc({'Deadly Precision Discipline'}))
    table.insert(self.burnAbilities, common.getBestDisc({'Frenzied Stabbing Discipline'}))
    table.insert(self.burnAbilities, common.getBestDisc({'Twisted Chance Discipline'}))
    table.insert(self.burnAbilities, common.getAA('Fundament: Third Spire of the Rake'))
    table.insert(self.burnAbilities, common.getAA('Dirty Fighting'))
end

function Rogue:initBuffs()
    table.insert(self.combatBuffs, common.getAA('Envenomed Blades'))
    table.insert(self.combatBuffs, common.getBestDisc({'Brigand\'s Gaze', 'Thief\'s Eyes'}))
    table.insert(self.combatBuffs, common.getItem('Fatestealer', {CheckFor='Assassin\'s Taint'}))
    table.insert(self.selfBuffs, common.getAA('Sleight of Hand'))
    table.insert(self.selfBuffs, common.getItem('Faded Gloves of the Shadows', {CheckFor='Strike Poison'}))
end

function Rogue:beforeEngage()
    if self:isEnabled('USEEVADE') and not mq.TLO.Me.Combat() and mq.TLO.Target.ID() == state.assistMobID then
        mq.cmd('/doability Hide')
        mq.delay(100)
        mq.cmd('/doability Backstab')
    end
end

function Rogue:aggroClass()
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

return Rogue