---@type Mq
local mq = require('mq')
local class = require('classes.classbase')
local common = require('common')
local state = require('state')

local Berserker = class:new()

--[[
    http://forums.eqfreelance.net/index.php?topic=10213.0
]]
function Berserker:init()
    self.classOrder = {'assist', 'ae', 'mash', 'burn', 'recover', 'buff', 'rest', 'rez'}
    self:initBase('BER')

    self:initClassOptions()
    self:loadSettings()
    self:initDPSAbilities()
    self:initBurns()
    self:initBuffs()
    self:initDefensiveAbilities()
    self:addCommonAbilities()

    self.epic = 'Raging Taelosian Alloy Axe'
end

function Berserker:initClassOptions()
    if state.emu then
        self:addOption('USEDECAP', 'Use Decap', true, nil, 'Toggle use of decap AA', 'checkbox', nil, 'UseDecap', 'bool')
    end
end

--[[

-- burns
common.getAA('Reckless Abandon') -- consume hp for inc dmg+accuracy, 10 min cd, timer 18
common.getAA('Savage Spirit') -- large crit dmg inc, consume 25% hp on fade, 10 min cd, timer 9
common.getAA('Spire of the Juggernaut') -- inc accuracy and dmg, 7:30 cd, timer 40
common.getAA('Blinding Fury') -- inc atk power, reduce weapon delay, inc double atk, extra hits, 10 min cd, timer 7
common.getAA('Focused Furious Rampage') -- 48 seconds of additional melee hits per round, 20 min cd, timer 11
common.getAA('Juggernaut Surge') -- inc dmg and crit dmg, 6 min cd, timer 41
common.getAA('Untamed Rage') -- consume 1% hp/tick, inc dbl atk, overhaste, atk power, accuracy, 15 min cd, timer 2
common.getAA('Desperation') -- overhaste + extra hits, 20 min cd, timer 5
common.getAA('Vehement Rage') -- reduced healing for inc base+minimum melee dmg, 5 min cd, timer 61
common.getAA('Blood Pact') -- 1:30 proc buff, consume 1% hp for 9k DD, 10 min cd, timer 4

-- aoe burn
common.getAA('Furious Rampage') -- 48 seconds of additional melee hits to all surrounding mobs, 20 min cd, timer 11

-- defensives
common.getAA('Blood Sustenance') -- absorb 50% of dmg done to target to heal self, 15 min cd, timer 16
common.getAA('Juggernaut\'s Resolve') -- consume 5% end for 20% dmg reduction, drains end, 10 min cd, timer 14
common.getAA('Uncanny Resilience') -- 50% dmg absorb, 3min cd, timer 8

-- cures
common.getAA('Agony of Absolution') -- remove detrimental effects, 14 min cd, timer 71

-- rest
common.getAA('Communion of Blood') -- consume 75k hp for 22k end then inc end regen, attacking breaks regen, 10 min cd, timer 64

common.getAA('Drawn to Blood') -- gravitates you towards target if under blinding fury or frenzied resolve
common.getAA('Bloodfury') -- consumes hp to use abilities that require reduced health, then gives dmg absorb buff
common.getAA('Tireless Sprint') -- short runspeed buff, 5 min cd
common.getAA('Battle Leap') -- leap to target, perma aura 45% base dmg inc
common.getAA('Furious Leap') -- leap
common.getAA('Mass Group Buff') -- 
common.getAA('Self Preservation') -- fade
]]

-- mash - vindicating frenzy, vindicating axe throw, axe of derakor, vindicating volley, binding axe, dissident rage, mangler's covenant, phantom assailant
-- mash ae - braxi's howl, rampage
-- aoe
-- common.getAA('Braxi\'s Howl') -- ae inc dmg taken, 1 min cd, timer 63
-- common.getAA('Rampage') -- 5 hits to nearby mobs, 3 min cd, timer 1
-- common.getAA('Devastating Assault') -- 2min of melee aoe dmg, 5 min cd, timer 30
function Berserker:initDPSAbilities()
    table.insert(self.DPSAbilities, common.getAA('Braxi\'s Howl', {threshold=3})) -- ae inc dmg taken, 1 min cd, timer 63
    table.insert(self.DPSAbilities, common.getBestDisc({'Ecliptic Rage', 'Composite Rage', 'Dissident Rage', 'Dichotomic Rage'}))
    table.insert(self.DPSAbilities, common.getAA('Binding Axe')) -- Throwing Attack for 500 with 10000% Accuracy Mod
    table.insert(self.DPSAbilities, common.getBestDisc({'Eviscerating Frenzy', 'Oppressing Frenzy', 'Vindicating Frenzy', 'Mangling Frenzy', 'Demolishing Frenzy'})) -- Frenzy Attack for 196 with 10000% Accuracy Mod (3), Cast: Overpowering Frenzy Effect (Increase Frenzy Damage Taken by 25%, Increase Throwing Damage Taken by 25%)
    table.insert(self.DPSAbilities, common.getBestDisc({'Eviscerating Volley', 'Pulverizing Volley', 'Vindicating Volley', 'Mangling Volley', 'Demolishing Volley', 'Destroyer\'s Volley', 'Rage Volley'})) -- Throwing Attack for 218 with 10000% Accuracy Mod (4)
    table.insert(self.DPSAbilities, common.getBestDisc({'Rending Axe Throw', 'Maiming Axe Throw', 'Vindicating Axe Throw', 'Mangling Axe Throw', 'Demolishing Axe Throw'})) -- Throwing Attack for 592 with 10000% Accuracy Mod
    table.insert(self.DPSAbilities, common.getBestDisc({'Axe of Orrak', 'Axe of Xin Diabo', 'Axe of Derakor', 'Axe of Empyr', 'Axe of the Aeons'})) -- 2H Slash Attack for 669 with 1000% Accuracy Mod, 2H Slash Attack for 920 with 1000% Accuracy Mod, 2H Slash Attack for 1171 with 1000% Accuracy Mod
    table.insert(self.DPSAbilities, common.getAA('Distraction Attack')) -- Add Melee Proc: Distraction Attack Strike XVIII (Decrease Hate by 2500, Decrease Current Hate by 1%) (Can hit with burns if you want, honestly doesn't help too much)
    table.insert(self.DPSAbilities, common.getBestDisc({'Conqueror\'s Conjunction', 'Vindicator\'s Coalition', 'Mangler\'s Covenant', 'Demolisher\'s Alliance'}))

    table.insert(self.AEDPSAbilities, common.getAA('Rampage', {threshold=3})) -- AE Attack (4 Rounds)
    table.insert(self.AEDPSAbilities, common.getBestDisc({'Arcshear', 'Arcslash', 'Arcsteel', 'Arcslice'}, {threshold=3})) -- Frontal AE Attack (4 Targets) 2H Slash Attack for 250 with 1000% Accuracy Mod (2)
    table.insert(self.AEDPSAbilities, common.getBestDisc({'Vicious Vortex', 'Vicious Whirl', 'Vicious Revolution', 'Vicious Cycle', 'Vicious Cyclone'}, {threshold=3})) -- AE Attack (12 Targets) Decrease Current HP by 4083 (Shares timer with Arcslice)

    --table.insert(self.DPSAbilities, common.getBestDisc({'Desperate Frenzy', 'Blinding Frenzy', 'Restless Frenzy', 'Torrid Frenzy', 'Stormwild Frenzy'}))

    -- emu leftovers
    if state.emu then
        table.insert(self.DPSAbilities, common.getItem('Raging Taelosian Alloy Axe')) -- only click outside burns
        --table.insert(self.DPSAbilities, common.getBestDisc({'Overpowering Frenzy'}))
        table.insert(self.DPSAbilities, common.getSkill('Frenzy'))
        table.insert(self.DPSAbilities, common.getBestDisc({'Confusing Strike'}))
        table.insert(self.DPSAbilities, common.getBestDisc({'Bewildering Scream'}))
    end
end

--[[
-- more burns - brutal discipline, juggernaut surge, savage spirit, spire of the juggernaut

-- burn 1 - 465(savage spirit), 961(juggernaut surge), 387(blood pact), 610(blinding fury), 1500(spire)
-- burn 1b - 373 (Desperation), 379 (focused furious rampage)
-- burn 2 - reckless abandon, cleaving acrimony, vehement rage
--[[
common.getBestDisc({'Cleaving Acrimony'}) -- 
common.getBestDisc({'Blinding Frenzy'}) -- proc additional dmg, requires below 90% hp, 10 min cd, timer 11
common.getBestDisc({'Jarring Impact'}) -- aggro reducer, timer 2
common.getBestDisc({'Temple Shatter'}) -- stun, timer 10
common.getBestDisc({'Swift Punch'}) -- h2h only ooc punch, use to enter combat maybe? 2min cd, timer 9
common.getBestDisc({'Stinging Incision'}) -- reduce hp to 89%
common.getBestDisc({'Primed Retaliation'}) -- at or below 90% hp, 3 strikes + 300% dodge buff for 1 min, 10 min cd, timer 15
common.getBestDisc({'Tendon Shred'}) -- snare/dot, timer 10
]]
-- Specials
-- Bloodfury - Decrease Current HP by 29000, Decrease Current HP by 3000 per tick, Cast: Bloodshield II on Fade (35k Rune) (Used to drop health for Amplified Frenzy and Frenzied Resolve)
-- Communion of Blood - Decrease Current HP by 30000, Increase Current Endurance by 15017 (10 minute CD, use wisely)
-- Phantom Assailant - Swarm Pet (Minimal DPS, sometimes detrimental to use swarm pets)

-- War Cry: (Called for by the Raid Leader or Zerker Lead for raid adps, Cry of Battle AA used to MGB):

-- Battle Cry of the Mastruq - Decrease Weapon Delay by 9%, Increase ATK by 50 (Bought off Merchant)
-- Ancient: Cry of Chaos - Decrease Weapon Delay by 11.3%, Increase ATK by 60 (Quested, GoD)
-- burn ae - furious rampage
function Berserker:initBurns()
    if not state.emu then
        -- Main Burn - Amplified Frenzy, Savage Spirit, Brutal Discipline, Second Spire, Blinding Fury, Untamed Rage, Epic 2.0, Silent Strikes, Furious Rampage (If allowed, Focused Furious Rampage if mezzed adds).
        table.insert(self.burnAbilities, common.getAA('Savage Spirit', {first=true})) -- 1: Increase Critical All Weapon Skills damage by 280% of Base Damage, Increase Critical Frenzy Damage by 280% of Base Damage
        table.insert(self.burnAbilities, common.getBestDisc({'Mangling Discipline'}, {first=true})) -- Increase Chance to Critical Hit by 221%, Increase Base Hit Damage by 54%, Use before brutal
        table.insert(self.burnAbilities, common.getBestDisc({'Brutal Discipline'}, {first=true})) -- Increase Hit Damage by 120%, Increase Min Hit Damage by 610%
        table.insert(self.burnAbilities, common.getAA('Spire of Savagery', {first=true})) -- Increase Chance to Hit with Throwing by 50%, Increase Min Throwing Damage by 60%, Increase Throwing Damage Bonus by 120
        table.insert(self.burnAbilities, common.getAA('Blinding Fury', {first=true})) -- Increase ATK by 510, Add Melee Proc: Blinded by Fury X (Increase Chance of Additional 2H Attack by 100%, Increase Chance to Double Attack by 10000%, Decrease Weapon Delay by 15%, Blind
        table.insert(self.burnAbilities, common.getAA('Untamed Rage', {first=true})) -- Increase Chance to Double Attack by 50%, Decrease Current HP by 3000 per tick, Add Melee Proc: Untamed Rage XV (Azia) (Untamed Rage refresh), Increase Melee Haste v3 by 25%, Decrease Current HP by 2% up to 10000, Increase ATK by 310, Increase Chance to Hit by 40%
        table.insert(self.burnAbilities, common.getItem('Raging Taelosian Alloy Axe', {third=true, first=true, second=true})) -- only click outside burns
        table.insert(self.burnAbilities, common.getAA('Silent Strikes', {first=true}))
        table.insert(self.burnAbilities, common.getAA('Focused Furious Rampage', {first=true})) -- Increase Chance to AE Attack by 100% with 15% Damage, Increase Chance to Repeat Primary Hand Round by 100%
        -- Inbetween - Disconcerting Discipline, Glyph of the Cataclysm
        table.insert(self.burnAbilities, common.getBestDisc({'Disconcerting Discipline'}, {quick=true})) -- Increase Chance to Critical Hit with all weapon skills by 53%, Increase Chance to Critical Hit with Frenzy by 53%, Increase Base Hit Damage by 11%
        -- Secondary Burn - Cleaving Acrimony, Reckless Abandon, Shaman Epic, Epic 2.0
        table.insert(self.burnAbilities, common.getBestDisc({'Cleaving Acrimony Discipline', 'Cleaving Anger Discipline'}, {second=true})) -- Increase Chance to Critical Hit by 275%, Increase Chance to Crippling Blow by 230%
        table.insert(self.burnAbilities, common.getAA('Reckless Abandon', {second=true})) -- Increase Hit Damage by 66%
        -- Inbetween - Frenzied Resolve, Juggernaut Surge
        table.insert(self.burnAbilities, common.getBestDisc({'Frenzied Resolve Discipline'}, {quick=true})) -- Increase Chance of Additional 2H Attack by 105%, Increase Min Hit Damage by 315%, Increase Chance to Hit by 32%, Self Root
        table.insert(self.burnAbilities, common.getAA('Juggernaut Surge', {quick=true})) -- Increase Hit Damage Bonus by 225, Increase Critical Hit Damage by 60% of Base Damage
        -- Tertiary Burn - Avenging Flurry, Vehement Rage, Shaman Epic, Epic 2.0
        table.insert(self.burnAbilities, common.getBestDisc({'Avenging Flurry Discipline'}, {third=true})) -- Increase Chance of Additional 2H Attack by 125%, Increase Chance to Double Attack by 10000%, Decrease Weapon Delay by 20.3%, Increase Chance to Flurry by 16%
        table.insert(self.burnAbilities, common.getAA('Vehement Rage', {third=true})) -- Increase Hit Damage by 15%, Increase Min Hit Damage by 45% (Next to worthless, honestly doesn't do much at all, hit when nothing else is up)
    else
        --quick burns
        table.insert(self.burnAbilities, common.getBestDisc({'Cleaving Anger Discipline'}, {quick=true}))
        table.insert(self.burnAbilities, common.getItem('Rage Bound Chestguard', {quick=true}))
        table.insert(self.burnAbilities, common.getAA('Fundament: Third Spire of Savagery', {quick=true}))
        table.insert(self.burnAbilities, common.getAA('Vehement Rage', {quick=true}))
        table.insert(self.burnAbilities, common.getAA('Juggernaut Surge', {quick=true}))
        table.insert(self.burnAbilities, common.getAA('Blood Pact', {quick=true}))
        table.insert(self.burnAbilities, common.getBestDisc({'Blind Rage Discipline'}, {quick=true}))
        table.insert(self.burnAbilities, common.getBestDisc({'Cleaving Rage Discipline'}, {quick=true, long=true}))
        table.insert(self.burnAbilities, common.getAA('Cry of Battle', {quick=true}))
        table.insert(self.burnAbilities, common.getAA('Uncanny Resilience'))

        -- long burns
        table.insert(self.burnAbilities, common.getAA('Savage Spirit', {long=true}))
        table.insert(self.burnAbilities, common.getAA('Untamed Rage', {long=true}))
        table.insert(self.burnAbilities, common.getBestDisc({'Cleaving Rage Discipline'}, {long=true}))
        table.insert(self.burnAbilities, common.getBestDisc({'Ancient: Cry of Chaos'}, {long=true}))
        table.insert(self.burnAbilities, common.getBestDisc({'Vengeful Flurry Discipline'}, {long=true}))
        table.insert(self.burnAbilities, common.getAA('Fundament: Second Spire of Savagery', {long=true}))
        table.insert(self.burnAbilities, common.getBestDisc({'War Cry'}, {long=true}))
        table.insert(self.burnAbilities, common.getAA('Reckless Abandon', {long=true}))
        table.insert(self.burnAbilities, common.getAA('Cascading Rage', {long=true}))
        table.insert(self.burnAbilities, common.getAA('Blinding Fury', {long=true}))
    end
end

-- combat buff mash - shared atavism, seething rage, magnified frenzy, sapping strikes
-- buffs - bloodlust aura, battle leap
function Berserker:initBuffs()
    table.insert(self.combatBuffs, common.getBestDisc({'Roiling Rage', 'Frothing Rage', 'Seething Rage', 'Smoldering Rage', 'Bubbling Rage'})) -- Add Melee Proc: Bubbling Rage Strike II, 2H Slash Attack for 254 with 53% Accuracy Mod (2 Strikes)
    table.insert(self.combatBuffs, common.getBestDisc({'Heightened Frenzy', 'Buttressed Frenzy', 'Magnified Frenzy', 'Bolstered Frenzy', 'Amplified Frenzy'})) -- Decrease Frenzy Timer by 3s, Add Skill Proc: Amplified Frenzy Strike II (4.6k)
    table.insert(self.combatBuffs, common.getBestDisc({'Shriveling Strikes', 'Sapping Strikes'})) -- Add Melee Proc: Sapping Strike II (4 Procs), Decrease Current HP by 9027, Returns 40% of Damage as Endurance, Max Per Hit: 4333
    table.insert(self.combatBuffs, common.getBestDisc({'Shared Barbarism', 'Shared Violence', 'Shared Atavism', 'Shared Cruelty'})) -- Increase all weapon skills Damage Bonus by 457
    table.insert(self.combatBuffs, common.getBestDisc({'Unthinking Retaliation', 'Instintive Retaliation', 'Reflexive Retaliation'})) -- proc stun when hit over 18k, lasts 1 hr, timer 18

    --table.insert(self.combatBuffs, common.getAA('Desperation', {combat=true})) -- Increase Melee Haste v3 by 25% (Just regular haste, already will be max on raid) 20min cd, not combat buff
    --table.insert(self.combatBuffs, common.getAA('Blood Pact', {combat=true})) -- Add Melee Proc: Blood Pact Strike XXII (2750) 10 min cd, not combat buff
    table.insert(self.combatBuffs, common.getBestDisc({'Cry Carnage', 'Cry Havoc'}, {combat=true, ooc=false})) -- Increase Chance to Critical Hit by 100%, Increase Accuracy by 21 (Lasts 10 mins now)
    if state.emu then table.insert(self.combatBuffs, common.getAA('Decapitation', {opt='USEDECAP', combat=true})) end
    table.insert(self.combatBuffs, common.getAA('Battle Leap')) -- Increase Hit Damage by 45% (Only need to hit this once per zone, unless you've died)

    table.insert(self.auras, common.getBestDisc({'Bloodlust Aura', 'Aura of Rage'}, {combat=false}))

    table.insert(self.selfBuffs, common.getBestDisc({'Axe of the Eviscerator', 'Axe of the Conqueror', 'Axe of the Vindicator', 'Axe of the Mangler', 'Axe of the Demolisher', 'Bonesplicer Axe'}, {summonMinimum=101}))
end

function Berserker:initDefensiveAbilities()
    table.insert(self.fadeAbilities, common.getAA('Self Preservation'))
end

-- end regen table.insert(, common.getBestDisc({'Convalesce', 'Night\'s Calming', 'Relax', 'Breather'}))
return Berserker
