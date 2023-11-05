---@type Mq
local mq = require('mq')
local class = require('classes.classbase')
local common = require('common')
local state = require('state')

function class.init(_aqo)
    class.classOrder = {'assist', 'ae', 'mash', 'burn', 'recover', 'buff', 'rest', 'rez'}
    class.initBase(_aqo, 'ber')

    class.initClassOptions()
    class.loadSettings()
    class.initDPSAbilities(_aqo)
    class.initBurns(_aqo)
    class.initBuffs(_aqo)
    class.initDefensiveAbilities(_aqo)

    class.epic = 'Raging Taelosian Alloy Axe'
end

function class.initClassOptions()
    if state.emu then
        class.addOption('USEDECAP', 'Use Decap', true, nil, 'Toggle use of decap AA', 'checkbox', nil, 'UseDecap', 'bool')
    end
end

-- http://forums.eqfreelance.net/index.php?topic=10213.0
function class.initDPSAbilities(_aq0)
    table.insert(class.DPSAbilities, common.getBestDisc({'Heightened Frenzy', 'Buttressed Frenzy', 'Magnified Frenzy', 'Bolstered Frenzy', 'Amplified Frenzy'})) -- Decrease Frenzy Timer by 3s, Add Skill Proc: Amplified Frenzy Strike II (4.6k)
    table.insert(class.DPSAbilities, common.getBestDisc({'Shriveling Strikes', 'Sapping Strikes'})) -- Add Melee Proc: Sapping Strike II (4 Procs), Decrease Current HP by 9027, Returns 40% of Damage as Endurance, Max Per Hit: 4333
    table.insert(class.DPSAbilities, common.getAA('War Cry of the Braxi')) -- Increase Hit Damage Taken by 13% (30 Hits) (Always hit before Dichotomic)
    table.insert(class.DPSAbilities, common.getBestDisc({'Ecliptic Rage', 'Composite Rage', 'Dichotomic Rage'}))
    table.insert(class.DPSAbilities, common.getBestDisc({'Roiling Rage', 'Frothing Rage', 'Seething Rage', 'Smoldering Rage', 'Bubbling Rage'})) -- Add Melee Proc: Bubbling Rage Strike II, 2H Slash Attack for 254 with 53% Accuracy Mod (2 Strikes)
    table.insert(class.DPSAbilities, common.getAA('Binding Axe')) -- Throwing Attack for 500 with 10000% Accuracy Mod
    table.insert(class.DPSAbilities, common.getBestDisc({'Shared Barbarism', 'Shared Violence', 'Shared Atavism', 'Shared Cruelty'})) -- Increase all weapon skills Damage Bonus by 457
    table.insert(class.DPSAbilities, common.getBestDisc({'Eviscerating Frenzy', 'Oppressing Frenzy', 'Vindicating Frenzy', 'Mangling Frenzy', 'Demolishing Frenzy'})) -- Frenzy Attack for 196 with 10000% Accuracy Mod (3), Cast: Overpowering Frenzy Effect (Increase Frenzy Damage Taken by 25%, Increase Throwing Damage Taken by 25%)
    table.insert(class.DPSAbilities, common.getBestDisc({'Eviscerating Volley', 'Pulverizing Volley', 'Vindicating Volley', 'Mangling Volley', 'Demolishing Volley', 'Destroyer\'s Volley', 'Rage Volley'})) -- Throwing Attack for 218 with 10000% Accuracy Mod (4)
    table.insert(class.DPSAbilities, common.getBestDisc({'Rending Axe Throw', 'Maiming Axe Throw', 'Vindicating Axe Throw', 'Mangling Axe Throw', 'Demolishing Axe Throw'})) -- Throwing Attack for 592 with 10000% Accuracy Mod
    table.insert(class.DPSAbilities, common.getBestDisc({'Axe of Orrak', 'Axe of Xin Diabo', 'Axe of Derakor', 'Axe of Empyr', 'Axe of the Aeons'})) -- 2H Slash Attack for 669 with 1000% Accuracy Mod, 2H Slash Attack for 920 with 1000% Accuracy Mod, 2H Slash Attack for 1171 with 1000% Accuracy Mod

    table.insert(class.AEDPSAbilities, common.getAA('Rampage', {threshold=3})) -- AE Attack (4 Rounds)
    table.insert(class.AEDPSAbilities, common.getBestDisc({'Arcshear', 'Arcslash', 'Arcsteel', 'Arcslice'}, {threshold=3})) -- Frontal AE Attack (4 Targets) 2H Slash Attack for 250 with 1000% Accuracy Mod (2)
    table.insert(class.AEDPSAbilities, common.getBestDisc({'Vicious Vortex', 'Vicious Whirl', 'Vicious Revolution', 'Vicious Cycle', 'Vicious Cyclone'}, {threshold=3})) -- AE Attack (12 Targets) Decrease Current HP by 4083 (Shares timer with Arcslice)
    table.insert(class.DPSAbilities, common.getAA('Distraction Attack')) -- Add Melee Proc: Distraction Attack Strike XVIII (Decrease Hate by 2500, Decrease Current Hate by 1%) (Can hit with burns if you want, honestly doesn't help too much)

    --table.insert(class.DPSAbilities, common.getBestDisc({'Desperate Frenzy', 'Blinding Frenzy', 'Restless Frenzy', 'Torrid Frenzy', 'Stormwild Frenzy'}))
    --table.insert(class.DPSAbilities, common.getBestDisc({'Conqueror\'s Conjunction', 'Vindicator\'s Coalition', 'Demolisher\'s Alliance'}))
    --table.insert(class.DPSAbilities, common.getBestDisc({'Unthinking Retaliation', 'Instintive Retaliation', 'Reflexive Retaliation'}))

    -- emu leftovers
    if state.emu then
        table.insert(class.DPSAbilities, common.getItem('Raging Taelosian Alloy Axe')) -- only click outside burns
        --table.insert(class.DPSAbilities, common.getBestDisc({'Overpowering Frenzy'}))
        table.insert(class.DPSAbilities, common.getSkill('Frenzy'))
        table.insert(class.DPSAbilities, common.getBestDisc({'Confusing Strike'}))
        table.insert(class.DPSAbilities, common.getBestDisc({'Bewildering Scream'}))
    end
end

-- Specials
-- Bloodfury - Decrease Current HP by 29000, Decrease Current HP by 3000 per tick, Cast: Bloodshield II on Fade (35k Rune) (Used to drop health for Amplified Frenzy and Frenzied Resolve)
-- Communion of Blood - Decrease Current HP by 30000, Increase Current Endurance by 15017 (10 minute CD, use wisely)
-- Phantom Assailant - Swarm Pet (Minimal DPS, sometimes detrimental to use swarm pets)

-- War Cry: (Called for by the Raid Leader or Zerker Lead for raid adps, Cry of Battle AA used to MGB):

-- Battle Cry of the Mastruq - Decrease Weapon Delay by 9%, Increase ATK by 50 (Bought off Merchant)
-- Ancient: Cry of Chaos - Decrease Weapon Delay by 11.3%, Increase ATK by 60 (Quested, GoD)
function class.initBurns(_aqo)
    if not state.emu then
        -- Main Burn - Amplified Frenzy, Savage Spirit, Brutal Discipline, Second Spire, Blinding Fury, Untamed Rage, Epic 2.0, Silent Strikes, Furious Rampage (If allowed, Focused Furious Rampage if mezzed adds).
        table.insert(class.burnAbilities, common.getAA('Savage Spirit', {main=true})) -- 1: Increase Critical All Weapon Skills damage by 280% of Base Damage, Increase Critical Frenzy Damage by 280% of Base Damage
        table.insert(class.burnAbilities, common.getBestDisc({'Mangling Discipline'}, {main=true})) -- Increase Chance to Critical Hit by 221%, Increase Base Hit Damage by 54%, Use before brutal
        table.insert(class.burnAbilities, common.getBestDisc({'Brutal Discipline'}, {main=true})) -- Increase Hit Damage by 120%, Increase Min Hit Damage by 610%
        table.insert(class.burnAbilities, common.getAA('Spire of Savagery', {main=true})) -- Increase Chance to Hit with Throwing by 50%, Increase Min Throwing Damage by 60%, Increase Throwing Damage Bonus by 120
        table.insert(class.burnAbilities, common.getAA('Blinding Fury', {main=true})) -- Increase ATK by 510, Add Melee Proc: Blinded by Fury X (Increase Chance of Additional 2H Attack by 100%, Increase Chance to Double Attack by 10000%, Decrease Weapon Delay by 15%, Blind
        table.insert(class.burnAbilities, common.getAA('Untamed Rage', {main=true})) -- Increase Chance to Double Attack by 50%, Decrease Current HP by 3000 per tick, Add Melee Proc: Untamed Rage XV (Azia) (Untamed Rage refresh), Increase Melee Haste v3 by 25%, Decrease Current HP by 2% up to 10000, Increase ATK by 310, Increase Chance to Hit by 40%
        table.insert(class.burnAbilities, common.getItem('Raging Taelosian Alloy Axe', {tertiary=true, main=true, secondary=true})) -- only click outside burns
        table.insert(class.burnAbilities, common.getAA('Silent Strikes', {main=true}))
        table.insert(class.burnAbilities, common.getAA('Focused Furious Rampage', {main=true})) -- Increase Chance to AE Attack by 100% with 15% Damage, Increase Chance to Repeat Primary Hand Round by 100%
        -- Inbetween - Disconcerting Discipline, Glyph of the Cataclysm
        table.insert(class.burnAbilities, common.getBestDisc({'Disconcerting Discipline'}, {quick=true})) -- Increase Chance to Critical Hit with all weapon skills by 53%, Increase Chance to Critical Hit with Frenzy by 53%, Increase Base Hit Damage by 11%
        -- Secondary Burn - Cleaving Acrimony, Reckless Abandon, Shaman Epic, Epic 2.0
        table.insert(class.burnAbilities, common.getBestDisc({'Cleaving Acrimony Discipline', 'Cleaving Anger Discipline'}, {secondary=true})) -- Increase Chance to Critical Hit by 275%, Increase Chance to Crippling Blow by 230%
        table.insert(class.burnAbilities, common.getAA('Reckless Abandon', {secondary=true})) -- Increase Hit Damage by 66%
        -- Inbetween - Frenzied Resolve, Juggernaut Surge
        table.insert(class.burnAbilities, common.getBestDisc({'Frenzied Resolve Discipline'}, {quick=true})) -- Increase Chance of Additional 2H Attack by 105%, Increase Min Hit Damage by 315%, Increase Chance to Hit by 32%, Self Root
        table.insert(class.burnAbilities, common.getAA('Juggernaut Surge', {quick=true})) -- Increase Hit Damage Bonus by 225, Increase Critical Hit Damage by 60% of Base Damage
        -- Tertiary Burn - Avenging Flurry, Vehement Rage, Shaman Epic, Epic 2.0
        table.insert(class.burnAbilities, common.getBestDisc({'Avenging Flurry Discipline'}, {tertiary=true})) -- Increase Chance of Additional 2H Attack by 125%, Increase Chance to Double Attack by 10000%, Decrease Weapon Delay by 20.3%, Increase Chance to Flurry by 16%
        table.insert(class.burnAbilities, common.getAA('Vehement Rage', {tertiary=true})) -- Increase Hit Damage by 15%, Increase Min Hit Damage by 45% (Next to worthless, honestly doesn't do much at all, hit when nothing else is up)
    else
        --quick burns
        table.insert(class.burnAbilities, common.getBestDisc({'Cleaving Anger Discipline'}, {quick=true}))
        table.insert(class.burnAbilities, common.getItem('Rage Bound Chestguard', {quick=true}))
        table.insert(class.burnAbilities, common.getAA('Fundament: Third Spire of Savagery', {quick=true}))
        table.insert(class.burnAbilities, common.getAA('Vehement Rage', {quick=true}))
        table.insert(class.burnAbilities, common.getAA('Juggernaut Surge', {quick=true}))
        table.insert(class.burnAbilities, common.getAA('Blood Pact', {quick=true}))
        table.insert(class.burnAbilities, common.getBestDisc({'Blind Rage Discipline'}, {quick=true}))
        table.insert(class.burnAbilities, common.getBestDisc({'Cleaving Rage Discipline'}, {quick=true, long=true}))
        table.insert(class.burnAbilities, common.getAA('Cry of Battle', {quick=true}))
        table.insert(class.burnAbilities, common.getAA('Uncanny Resilience'))
    
        -- long burns
        table.insert(class.burnAbilities, common.getAA('Savage Spirit', {long=true}))
        table.insert(class.burnAbilities, common.getAA('Untamed Rage', {long=true}))
        table.insert(class.burnAbilities, common.getBestDisc({'Cleaving Rage Discipline'}, {long=true}))
        table.insert(class.burnAbilities, common.getBestDisc({'Ancient: Cry of Chaos'}, {long=true}))
        table.insert(class.burnAbilities, common.getBestDisc({'Vengeful Flurry Discipline'}, {long=true}))
        table.insert(class.burnAbilities, common.getAA('Fundament: Second Spire of Savagery', {long=true}))
        table.insert(class.burnAbilities, common.getBestDisc({'War Cry'}, {long=true}))
        table.insert(class.burnAbilities, common.getAA('Reckless Abandon', {long=true}))
        table.insert(class.burnAbilities, common.getAA('Cascading Rage', {long=true}))
        table.insert(class.burnAbilities, common.getAA('Blinding Fury', {long=true}))
    end
end

function class.initBuffs(_aqo)
    table.insert(class.combatBuffs, common.getAA('Desperation', {combat=true})) -- Increase Melee Haste v3 by 25% (Just regular haste, already will be max on raid)
    table.insert(class.combatBuffs, common.getAA('Blood Pact', {combat=true})) -- Add Melee Proc: Blood Pact Strike XXII (2750)
    table.insert(class.combatBuffs, common.getBestDisc({'Cry Carnage', 'Cry Havoc'}, {combat=true, ooc=false})) -- Increase Chance to Critical Hit by 100%, Increase Accuracy by 21 (Lasts 10 mins now)
    if state.emu then table.insert(class.combatBuffs, common.getAA('Decapitation', {opt='USEDECAP', combat=true})) end
    table.insert(class.combatBuffs, common.getAA('Battle Leap')) -- Increase Hit Damage by 45% (Only need to hit this once per zone, unless you've died)

    table.insert(class.auras, common.getBestDisc({'Bloodlust Aura', 'Aura of Rage'}, {combat=false}))

    table.insert(class.selfBuffs, common.getBestDisc({'Axe of the Eviscerator', 'Axe of the Conqueror', 'Axe of the Vindicator', 'Axe of the Mangler', 'Axe of the Demolisher', 'Bonesplicer Axe'}, {summonMinimum=101}))
end

function class.initDefensiveAbilities(_aqo)
    table.insert(class.fadeAbilities, common.getAA('Self Preservation'))
end

-- end regen table.insert(, common.getBestDisc({'Convalesce', 'Night\'s Calming', 'Relax', 'Breather'}))
return class
