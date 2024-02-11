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
    self:addAA('Twisted Shank') -- Use on CD, dot, reduce healing effectiveness
    self:addAA('Envenomed Blades') -- Use on CD, poison proc
    self:addAA('Absorbing Agent') -- Use on CD, inc incoming spell dmg

    common.getBestDisc({'Blitzstrike'}) -- hit + inc dmg dealt
    common.getBestDisc({'Chelicerae Discipline'}) -- inc proc rate + inc poison dmg
    common.getBestDisc({'Vexatious Puncture'}) -- backstab, hate reduction
    common.getBestDisc({'Poisonous Alliance Effect'}) -- inc poison dmg taken

    self:addAA('Rake\'s Rampage') -- ae attack
    
    -- Main Burn
    self:addAA('Rogue\'s Fury') -- inc all skills dmg modifiers, min dmg, chance to hit
    common.getBestDisc({'Frenzied Stabbing Discipline'}) -- more backstabs
    self:addAA('Focused Rake\'s Rampage') -- single target rampage
    common.getBestDisc({'Ecliptic Weapons', 'Composite Weapons', 'Dissident Weapons', 'Dichotomic Weapons'}) -- inc dmg
    self:addAA('Spire of the Rake') -- inc crit dmg, chance, dmg bonus
    self:addAA('Shadow\'s Flanking') -- inc melee dmg from behind

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
    self:initBase('ROG')

    self:initClassOptions()
    self:loadSettings()
    self:initAbilities()
    self:addCommonAbilities()

    self.useCommonListProcessor = true
end

function Rogue:initClassOptions()
    self:addOption('USEEVADE', 'Evade', true, nil, 'Hide and backstab on engage', 'checkbox', nil, 'UseEvade', 'bool')
end

Rogue.Abilities = {
    {
        Type='Skill',
        Name='Kick',
        Options={dps=true, condition=conditions.withinMeleeDistance}
    },
    {
        Type='Skill',
        Name='Backstab',
        Options={dps=true, condition=conditions.withinMeleeDistance}
    },
    {
        Type='AA',
        Name='Twisted Shank',
        Options={dps=true, condition=conditions.withinMeleeDistance}
    },
    {
        Type='Disc',
        Group='assault',
        Names={'Assault'},
        Options={dps=true, condition=conditions.withinMeleeDistance}
    },
    {
        Type='AA',
        Name='Ligament Slice',
        Options={dps=true, condition=conditions.withinMeleeDistance}
    },

    {
        Type='AA',
        Name='Rogue\'s Fury',
        Options={first=true}
    },
    {
        Type='Disc',
        Group='duelist',
        Names={'Duelist Discipline'},
        Options={first=true}
    },
    {
        Type='Disc',
        Group='precision',
        Names={'Deadly Precision Discipline'},
        Options={first=true}
    },
    {
        Type='Disc',
        Group='stabbing',
        Names={'Frenzied Stabbing Discipline'},
        Options={first=true}
    },
    {
        Type='Disc',
        Group='twisted',
        Names={'Twisted Chance Discipline'},
        Options={first=true}
    },
    {
        Type='AA',
        Name='Fundament: Third Spire of the Rake',
        Options={first=true}
    },
    {
        Type='AA',
        Name='Dirty Fighting',
        Options={first=true}
    },

    {
        Type='AA',
        Name='Envenomed Blades',
        Options={combatbuff=true}
    },
    {
        Type='Disc',
        Group='eyes',
        Names={'Brigand\'s Gaze', 'Thief\'s Eyes'},
        Options={combatbuff=true}
    },
    {
        Type='Item',
        Name='Fatestealer',
        Options={CheckFor='Assassin\'s Taint', combatbuff=true}
    },
    {
        Type='AA',
        Name='Sleight of Hand',
        Options={selfbuff=true}
    },
    {
        Type='Item',
        Name='Faded Gloves of the Shadows',
        Options={CheckFor='Strike Poison', selfbuff=true}
    },
}

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