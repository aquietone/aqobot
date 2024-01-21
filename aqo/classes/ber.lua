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
    self:initRecoverAbilities()
    self:initCureAbilities()
    self:addCommonAbilities()

    self.epic = 'Raging Taelosian Alloy Axe'
end

function Berserker:initClassOptions()
    if state.emu then
        self:addOption('USEDECAP', 'Use Decap', true, nil, 'Toggle use of decap AA', 'checkbox', nil, 'UseDecap', 'bool')
    end
end

function Berserker:initDPSAbilities()
    table.insert(self.DPSAbilities, common.getAA('Braxi\'s Howl')) -- ae inc dmg taken, still useful for single target too, 1 min cd, timer 63
    table.insert(self.DPSAbilities, common.getBestDisc({'Eviscerating Frenzy', 'Oppressing Frenzy', 'Vindicating Frenzy', 'Mangling Frenzy', 'Demolishing Frenzy', 'Overpowering Frenzy'})) -- Frenzy Attack for 196 with 10000% Accuracy Mod (3), Cast: Overpowering Frenzy Effect (Increase Frenzy Damage Taken by 25%, Increase Throwing Damage Taken by 25%)
    table.insert(self.DPSAbilities, common.getBestDisc({'Rending Axe Throw', 'Maiming Axe Throw', 'Vindicating Axe Throw', 'Mangling Axe Throw', 'Demolishing Axe Throw'})) -- Throwing Attack for 592 with 10000% Accuracy Mod
    table.insert(self.DPSAbilities, common.getBestDisc({'Axe of Orrak', 'Axe of Xin Diabo', 'Axe of Derakor', 'Axe of Empyr', 'Axe of the Aeons'})) -- 2H Slash Attack for 669 with 1000% Accuracy Mod, 2H Slash Attack for 920 with 1000% Accuracy Mod, 2H Slash Attack for 1171 with 1000% Accuracy Mod
    table.insert(self.DPSAbilities, common.getBestDisc({'Eviscerating Volley', 'Pulverizing Volley', 'Vindicating Volley', 'Mangling Volley', 'Demolishing Volley', 'Destroyer\'s Volley', 'Rage Volley'})) -- Throwing Attack for 218 with 10000% Accuracy Mod (4)
    table.insert(self.DPSAbilities, common.getAA('Binding Axe')) -- Throwing Attack for 500 with 10000% Accuracy Mod
    table.insert(self.DPSAbilities, common.getBestDisc({'Ecliptic Rage', 'Composite Rage', 'Dissident Rage', 'Dichotomic Rage'}))
    table.insert(self.DPSAbilities, common.getBestDisc({'Conqueror\'s Conjunction', 'Vindicator\'s Coalition', 'Mangler\'s Covenant', 'Demolisher\'s Alliance'}))
    table.insert(self.DPSAbilities, common.getBestDisc({'Phantom Assailant'})) -- temp pet
    table.insert(self.DPSAbilities, common.getBestDisc({'Jarring Impact', 'Jarring Shock', 'Jarring Jolt', 'Confusing Strike'})) -- aggro reducer, timer 2

    table.insert(self.AEDPSAbilities, common.getAA('Rampage', {threshold=3})) -- AE Attack, 3 min cd, timer 1
    table.insert(self.AEDPSAbilities, common.getBestDisc({'Arcshear', 'Arcslash', 'Arcsteel', 'Arcslice'}, {threshold=3})) -- Frontal AE Attack (4 Targets) 2H Slash Attack for 250 with 1000% Accuracy Mod (2)
    table.insert(self.AEDPSAbilities, common.getBestDisc({'Vicious Vortex', 'Vicious Whirl', 'Vicious Revolution', 'Vicious Cycle', 'Vicious Cyclone'}, {threshold=3})) -- AE Attack (12 Targets) Decrease Current HP by 4083 (Shares timer with Arcslice)
    table.insert(self.AEDPSAbilities, common.getAA('Devastating Assault', {threshold=3})) -- 2min of melee aoe dmg, 5 min cd, timer 30

    -- emu leftovers
    if state.emu then
        table.insert(self.DPSAbilities, common.getSkill('Frenzy'))
        table.insert(self.DPSAbilities, common.getItem('Raging Taelosian Alloy Axe')) -- only click outside burns
        table.insert(self.DPSAbilities, common.getBestDisc({'Bewildering Scream'}))
    end
end

--[[
common.getAA('Drawn to Blood') -- gravitates you towards target if under blinding fury or frenzied resolve
common.getAA('Bloodfury') -- consumes hp to use abilities that require reduced health, then gives dmg absorb buff
common.getAA('Tireless Sprint') -- short runspeed buff, 5 min cd
common.getAA('Furious Leap') -- leap
common.getBestDisc({'Blinding Frenzy'}) -- proc additional dmg, requires below 90% hp, 10 min cd, timer 11
common.getBestDisc({'Temple Shatter'}) -- stun, timer 10
common.getBestDisc({'Swift Punch', 'Rabbit Punch', 'Sucker Punch'}) -- h2h only ooc punch, use to enter combat maybe? 2min cd, timer 9
common.getBestDisc({'Stinging Incision'}) -- reduce hp to 89%
common.getBestDisc({'Primed Retaliation'}) -- at or below 90% hp, 3 strikes + 300% dodge buff for 1 min, 10 min cd, timer 15
]]
function Berserker:initBurns()
    -- MGB...
    --table.insert(self.burnAbilities, common.getBestDisc({'Battle Cry of the Mastruq', 'Ancient: Cry of Chaos', 'War Cry of Dravel', 'Battle Cry of Dravel', 'War Cry', 'Battle Cry'}, {long=true}))

    -- First Burn
    table.insert(self.burnAbilities, common.getAA('Savage Spirit', {first=true})) -- 1: Increase Critical All Weapon Skills damage by 280% of Base Damage, Increase Critical Frenzy Damage by 280% of Base Damage, 10 min cd, timer 9
    table.insert(self.burnAbilities, common.getBestDisc({'Mangling Discipline'}, {first=true})) -- Increase Chance to Critical Hit by 221%, Increase Base Hit Damage by 54%, Use before brutal
    table.insert(self.burnAbilities, common.getBestDisc({'Brutal Discipline', 'Blind Rage Discipline', 'Cleaving Rage Discipline'}, {first=true})) -- Increase Hit Damage by 120%, Increase Min Hit Damage by 610%
    table.insert(self.burnAbilities, common.getAA('Juggernaut Surge', {first=true})) -- inc dmg and crit dmg, 6 min cd, timer 41
    table.insert(self.burnAbilities, common.getAA('Blood Pact', {first=true})) -- 1:30 proc buff, consume 1% hp for 9k DD, 10 min cd, timer 4
    table.insert(self.burnAbilities, common.getAA('Spire of Savagery', {first=true})) -- Increase Chance to Hit with Throwing by 50%, Increase Min Throwing Damage by 60%, Increase Throwing Damage Bonus by 120, 7:30 cd, timer 40
    table.insert(self.burnAbilities, common.getAA('Fundament: Third Spire of Savagery', {quick=true})) -- emu only. enhance melee capabilities for group
    table.insert(self.burnAbilities, common.getAA('Blinding Fury', {first=true})) -- Increase ATK by 510, Add Melee Proc: Blinded by Fury X (Increase Chance of Additional 2H Attack by 100%, Increase Chance to Double Attack by 10000%, Decrease Weapon Delay by 15%, Blind, 10 min cd, timer 7
    table.insert(self.burnAbilities, common.getAA('Untamed Rage', {first=true})) -- Increase Chance to Double Attack by 50%, Decrease Current HP by 3000 per tick, Add Melee Proc: Untamed Rage XV (Azia) (Untamed Rage refresh), Increase Melee Haste v3 by 25%, Decrease Current HP by 2% up to 10000, Increase ATK by 310, Increase Chance to Hit by 40%, 15 min cd, timer 2
    table.insert(self.burnAbilities, common.getAA('Cascading Rage', {long=true})) -- emu only, replaced by Untamed Rage
    table.insert(self.burnAbilities, common.getAA('Desperation', {first=true})) -- overhaste + extra hits, 20 min cd, timer 5
    table.insert(self.burnAbilities, common.getAA('Silent Strikes', {first=true}))
    table.insert(self.burnAbilities, common.getAA('Furious Rampage', {first=true, opt='USEAOE'})) -- 48 seconds of additional melee hits to all surrounding mobs, 20 min cd, timer 11
    table.insert(self.burnAbilities, common.getAA('Focused Furious Rampage', {first=true})) -- Increase Chance to AE Attack by 100% with 15% Damage, Increase Chance to Repeat Primary Hand Round by 100%, 20 min cd, timer 11

    -- Secondary Burn - Cleaving Acrimony, Reckless Abandon, Shaman Epic, Epic 2.0
    table.insert(self.burnAbilities, common.getAA('Reckless Abandon', {second=true})) -- Increase Hit Damage by 66%, 10 min cd, timer 18
    table.insert(self.burnAbilities, common.getBestDisc({'Cleaving Acrimony Discipline', 'Cleaving Anger Discipline'}, {second=true})) -- Increase Chance to Critical Hit by 275%, Increase Chance to Crippling Blow by 230%
    table.insert(self.burnAbilities, common.getAA('Cry of Battle', {quick=true})) -- emu only??

    -- Tertiary Burn - Avenging Flurry, Vehement Rage, Shaman Epic, Epic 2.0
    table.insert(self.burnAbilities, common.getBestDisc({'Avenging Flurry Discipline', 'Vengeful Flurry Discipline'}, {third=true})) -- Increase Chance of Additional 2H Attack by 125%, Increase Chance to Double Attack by 10000%, Decrease Weapon Delay by 20.3%, Increase Chance to Flurry by 16%
    table.insert(self.burnAbilities, common.getAA('Vehement Rage', {third=true})) -- Increase Hit Damage by 15%, Increase Min Hit Damage by 45% (Next to worthless, honestly doesn't do much at all, hit when nothing else is up), 5 min cd, timer 61

    table.insert(self.burnAbilities, common.getItem('Raging Taelosian Alloy Axe', {opt='USEEPIC', third=true, first=true, second=true})) -- only click outside burns

    -- extra burns
    table.insert(self.burnAbilities, common.getBestDisc({'Disconcerting Discipline'})) -- Timer 21 with Mangling, Increase Chance to Critical Hit with all weapon skills by 53%, Increase Chance to Critical Hit with Frenzy by 53%, Increase Base Hit Damage by 11%
    table.insert(self.burnAbilities, common.getBestDisc({'Frenzied Resolve Discipline'})) -- Timer 15, Increase Chance of Additional 2H Attack by 105%, Increase Min Hit Damage by 315%, Increase Chance to Hit by 32%, Self Root
end

function Berserker:initBuffs()
    table.insert(self.combatBuffs, common.getBestDisc({'Roiling Rage', 'Frothing Rage', 'Seething Rage', 'Smoldering Rage', 'Bubbling Rage'})) -- Add Melee Proc: Bubbling Rage Strike II, 2H Slash Attack for 254 with 53% Accuracy Mod (2 Strikes)
    table.insert(self.combatBuffs, common.getBestDisc({'Heightened Frenzy', 'Buttressed Frenzy', 'Magnified Frenzy', 'Bolstered Frenzy', 'Amplified Frenzy'})) -- Decrease Frenzy Timer by 3s, Add Skill Proc: Amplified Frenzy Strike II (4.6k)
    table.insert(self.combatBuffs, common.getBestDisc({'Shriveling Strikes', 'Sapping Strikes'})) -- Add Melee Proc: Sapping Strike II (4 Procs), Decrease Current HP by 9027, Returns 40% of Damage as Endurance, Max Per Hit: 4333
    table.insert(self.combatBuffs, common.getBestDisc({'Shared Barbarism', 'Shared Violence', 'Shared Atavism', 'Shared Cruelty', 'Shared Bloodlust'})) -- Increase all weapon skills Damage Bonus by 457, requires target of target
    table.insert(self.combatBuffs, common.getBestDisc({'Unthinking Retaliation', 'Instintive Retaliation', 'Reflexive Retaliation'})) -- proc stun when hit over 18k, lasts 1 hr, timer 18
    table.insert(self.combatBuffs, common.getAA('Distraction Attack')) -- Add Melee Proc: Distraction Attack Strike XVIII (Decrease Hate by 2500, Decrease Current Hate by 1%) (Can hit with burns if you want, honestly doesn't help too much)

    --table.insert(self.combatBuffs, common.getAA('Desperation', {combat=true})) -- Increase Melee Haste v3 by 25% (Just regular haste, already will be max on raid) 20min cd, not combat buff
    --table.insert(self.combatBuffs, common.getAA('Blood Pact', {combat=true})) -- Add Melee Proc: Blood Pact Strike XXII (2750) 10 min cd, not combat buff
    table.insert(self.combatBuffs, common.getBestDisc({'Cry Carnage', 'Cry Havoc'}, {combat=true, ooc=false})) -- Increase Chance to Critical Hit by 100%, Increase Accuracy by 21 (Lasts 10 mins now)
    if state.emu then table.insert(self.combatBuffs, common.getAA('Decapitation', {opt='USEDECAP', combat=true})) end
    table.insert(self.combatBuffs, common.getAA('Battle Leap')) -- Increase Hit Damage by 45% (Only need to hit this once per zone, unless you've died)

    table.insert(self.auras, common.getBestDisc({'Bloodlust Aura', 'Aura of Rage'}, {combat=false}))

    table.insert(self.selfBuffs, common.getBestDisc({'Axe of the Eviscerator', 'Axe of the Conqueror', 'Axe of the Vindicator', 'Axe of the Mangler', 'Axe of the Demolisher', 'Bonesplicer Axe'}, {summonMinimum=101}))
end

function Berserker:initDefensiveAbilities()
    table.insert(self.fadeAbilities, common.getAA('Self Preservation')) -- fade
    table.insert(self.defensiveAbilities, common.getAA('Blood Sustenance')) -- absorb 50% of dmg done to target to heal self, 15 min cd, timer 16
    table.insert(self.defensiveAbilities, common.getAA('Juggernaut\'s Resolve')) -- consume 5% end for 20% dmg reduction, drains end, 10 min cd, timer 14
    table.insert(self.defensiveAbilities, common.getAA('Uncanny Resilience')) -- 50% dmg absorb, 3min cd, timer 8
end

function Berserker:initRecoverAbilities()
    table.insert(self.recoverAbilities, common.getAA('Communion of Blood', {combat=true, minhp=true})) -- consume 75k hp for 22k end then inc end regen, attacking breaks regen, 10 min cd, timer 64
end

function Berserker:initCureAbilities()
    table.insert(self.cures, common.getAA('Agony of Absolution', {poison=true,disease=true,corruption=true,curse=true})) -- remove detrimental effects, 14 min cd, timer 71
end

-- end regen table.insert(, common.getBestDisc({'Convalesce', 'Night\'s Calming', 'Relax', 'Breather'}))
return Berserker
