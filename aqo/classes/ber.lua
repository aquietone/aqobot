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
    self:initAbilities()
    self:addCommonAbilities()

    self.epic = 'Raging Taelosian Alloy Axe'
end

function Berserker:initClassOptions()
    if state.emu then
        self:addOption('USEDECAP', 'Use Decap', true, nil, 'Toggle use of decap AA', 'checkbox', nil, 'UseDecap', 'bool')
        self:addOption('USEEPIC', 'Use Epic', true, nil, 'Toggle use of epic 2.0 click', 'checkbox', nil, 'UseEpic', 'bool')
    end
end

Berserker.Abilities = {
    { -- ae inc dmg taken, still useful for single target too, 1 min cd, timer 63
        Type='AA',
        Name='Braxi\'s Howl',
        Options={dps=true}
    },
    { -- Frenzy Attack for 196 with 10000% Accuracy Mod (3), Cast: Overpowering Frenzy Effect (Increase Frenzy Damage Taken by 25%, Increase Throwing Damage Taken by 25%)
        Type='Disc',
        Group='frenzy',
        Names={'Eviscerating Frenzy', 'Oppressing Frenzy', 'Vindicating Frenzy', 'Mangling Frenzy', 'Vanquishing Frenzy', 'Demolishing Frenzy', 'Conquering Frenzy', 'Overwhelming Frenzy', --[[emu begin]] 'Overpowering Frenzy'},
        Options={dps=true}
    },
    { -- Throwing Attack for 592 with 10000% Accuracy Mod
        Type='Disc',
        Group='axethrow',
        Names={'Rending Axe Throw', 'Maiming Axe Throw', 'Vindicating Axe Throw', 'Mangling Axe Throw', 'Demolishing Axe Throw', 'Brutal Axe Throw', 'Spirited Axe Throw', 'Energetic Axe Throw'},
        Options={dps=true}
    },
    { -- 2H Slash Attack for 669 with 1000% Accuracy Mod, 2H Slash Attack for 920 with 1000% Accuracy Mod, 2H Slash Attack for 1171 with 1000% Accuracy Mod
        Type='Disc',
        Group='axeof',
        Names={'Axe of Orrak', 'Axe of Xin Diabo', 'Axe of Derakor', 'Axe of Empyr', 'Axe of the Aeons', 'Axe of Zurel', 'Axe of Illdaera', 'Axe of Graster'},
        Options={dps=true}
    },
    { -- Throwing Attack for 218 with 10000% Accuracy Mod (4)
        Type='Disc',
        Group='volley',
        Names={'Eviscerating Volley', 'Pulverizing Volley', 'Vindicating Volley', 'Mangling Volley', 'Demolishing Volley', 'Brutal Volley', 'Sundering Volley', 'Savage Volley', --[[emu begin]] 'Destroyer\'s Volley', 'Rage Volley'},
        Options={dps=true}
    },
    { -- Throwing Attack for 500 with 10000% Accuracy Mod
        Type='AA',
        Name='Binding Axe',
        Options={dps=true}
    },
    {
        Type='Disc',
        Group='composite',
        Names={'Ecliptic Rage', 'Composite Rage', 'Dissident Rage', 'Dichotomic Rage'},
        Options={dps=true}
    },
    {
        Type='Disc',
        Group='alliance',
        Names={'Conqueror\'s Conjunction', 'Vindicator\'s Coalition', 'Mangler\'s Covenant', 'Demolisher\'s Alliance'},
        Options={dps=true}
    },
    { -- temp pet
        Type='Disc',
        Group='phantom',
        Names={'Phantom Assailant'},
        Options={dps=true}
    },
    { -- aggro reducer, timer 2
        Type='Disc',
        Group='jarring',
        Names={'Jarring Impact', 'Jarring Shock', 'Jarring Jolt', 'Jarring Crush', 'Jarring Blow', 'Jarring Slam', --[[emu begin]] 'Confusing Strike'},
        Options={dps=true}
    },
    {
        Type='Skill',
        Name='Frenzy',
        Options={emu=true, dps=true}
    },
    {
        Type='Disc',
        Group='scream',
        Names={'Bewildering Scream'},
        Options={emu=true, dps=true}
    },

    { -- AE Attack, 3 min cd, timer 1
        Type='AA',
        Name='Rampage',
        Options={aedps=true, threshold=3}
    },
    { -- Frontal AE Attack (4 Targets) 2H Slash Attack for 250 with 1000% Accuracy Mod (2)
        Type='Disc',
        Group='arc',
        Names={'Arcshear', 'Arcslash', 'Arcsteel', 'Arcslice', 'Arcblade'},
        Options={aedps=true, threshold=3}
    },
    { -- AE Attack (12 Targets) Decrease Current HP by 4083 (Shares timer with Arcslice)
        Type='Disc',
        Group='vicious',
        Names={'Vicious Vortex', 'Vicious Whirl', 'Vicious Revolution', 'Vicious Cycle', 'Vicious Cyclone', 'Vicious Spiral'},
        Options={aedps=true, threshold=3}
    },
    { -- 2min of melee aoe dmg, 5 min cd, timer 30
        Type='AA',
        Name='Devastating Assault',
        Options={aedps=true, threshold=3}
    },

    -- First Burn
    { -- 1: Increase Critical All Weapon Skills damage by 280% of Base Damage, Increase Critical Frenzy Damage by 280% of Base Damage, 10 min cd, timer 9
        Type='AA',
        Name='Savage Spirit',
        Options={first=true}
    },
    { -- Increase Chance to Critical Hit by 221%, Increase Base Hit Damage by 54%, Use before brutal
        Type='Disc',
        Group='mangling',
        Names={'Mangling Discipline'},
        Options={first=true}
    },
    { -- Increase Hit Damage by 120%, Increase Min Hit Damage by 610%
        Type='Disc',
        Group='brutal',
        Names={'Brutal Discipline', 'Blind Rage Discipline', 'Cleaving Rage Discipline'},
        Options={first=true}
    },
    { -- inc dmg and crit dmg, 6 min cd, timer 41
        Type='AA',
        Name='Juggernaut Surge',
        Options={first=true}
    },
    { -- 1:30 proc buff, consume 1% hp for 9k DD, 10 min cd, timer 4
        Type='AA',
        Name='Blood Pact',
        Options={first=true}
    },
    { -- Increase Chance to Hit with Throwing by 50%, Increase Min Throwing Damage by 60%, Increase Throwing Damage Bonus by 120, 7:30 cd, timer 40
        Type='AA',
        Name='Spire of Savagery',
        Options={first=true}
    },
    { -- emu only. enhance melee capabilities for group
        Type='AA',
        Name='Fundament: Third Spire of Savagery',
        Options={emu=true, first=true}
    },
    { -- Increase ATK by 510, Add Melee Proc: Blinded by Fury X (Increase Chance of Additional 2H Attack by 100%, Increase Chance to Double Attack by 10000%, Decrease Weapon Delay by 15%, Blind, 10 min cd, timer 7
        Type='AA',
        Name='Blinding Fury',
        Options={first=true}
    },
    { -- Increase Chance to Double Attack by 50%, Decrease Current HP by 3000 per tick, Add Melee Proc: Untamed Rage XV (Azia) (Untamed Rage refresh), Increase Melee Haste v3 by 25%, Decrease Current HP by 2% up to 10000, Increase ATK by 310, Increase Chance to Hit by 40%, 15 min cd, timer 2
        Type='AA',
        Name='Untamed Rage',
        Options={first=true}
    },
    { -- emu only, replaced by Untamed Rage
        Type='AA',
        Name='Cascading Rage',
        Options={first=true}
    },
    { -- overhaste + extra hits, 20 min cd, timer 5
        Type='AA',
        Name='Desperation',
        Options={first=true}
    },
    {
        Type='AA',
        Name='Silent Strikes',
        Options={first=true}
    },
    { -- 48 seconds of additional melee hits to all surrounding mobs, 20 min cd, timer 11
        Type='AA',
        Name='Furious Rampage',
        Options={first=true, opt='USEAOE'}
    },
    { -- Increase Chance to AE Attack by 100% with 15% Damage, Increase Chance to Repeat Primary Hand Round by 100%, 20 min cd, timer 11
        Type='AA',
        Name='Focused Furious Rampage',
        Options={first=true}
    },
    -- Secondary Burn - Cleaving Acrimony, Reckless Abandon, Shaman Epic, Epic 2.0
    { -- Increase Hit Damage by 66%, 10 min cd, timer 18
        Type='AA',
        Name='Reckless Abandon',
        Options={second=true}
    },
    { -- Increase Chance to Critical Hit by 275%, Increase Chance to Crippling Blow by 230%
        Type='Disc',
        Group='cleavingdisc',
        Names={'Cleaving Acrimony Discipline', 'Cleaving Anger Discipline'},
        Options={second=true}
    },
    { -- emu only??
        Type='AA',
        Name='Cry of Battle',
        Options={emu=true, second=true}
    },
    -- Tertiary Burn - Avenging Flurry, Vehement Rage, Shaman Epic, Epic 2.0
    { -- Increase Chance of Additional 2H Attack by 125%, Increase Chance to Double Attack by 10000%, Decrease Weapon Delay by 20.3%, Increase Chance to Flurry by 16%
        Type='Disc',
        Group='flurrydisc',
        Names={'Avenging Flurry Discipline', 'Vengeful Flurry Discipline'},
        Options={third=true}
    },
    { -- Increase Hit Damage by 15%, Increase Min Hit Damage by 45% (Next to worthless, honestly doesn't do much at all, hit when nothing else is up), 5 min cd, timer 61
        Type='AA',
        Name='Vehement Rage',
        Options={third=true}
    },
    { -- only click outside burns
        Type='Item',
        Name='Raging Taelosian Alloy Axe',
        Options={opt='USEEPIC', third=true, first=true, second=true}
    },
    -- extra burns
    { -- Timer 21 with Mangling, Increase Chance to Critical Hit with all weapon skills by 53%, Increase Chance to Critical Hit with Frenzy by 53%, Increase Base Hit Damage by 11%
        Type='Disc',
        Group='timer21',
        Names={'Disconcerting Discipline'},
        Options={burn=true}
    },
    { -- Timer 15, Increase Chance of Additional 2H Attack by 105%, Increase Min Hit Damage by 315%, Increase Chance to Hit by 32%, Self Root
        Type='Disc',
        Group='timer15',
        Names={'Frenzied Resolve Discipline'},
        Options={burn=true}
    },

    -- Buffs
    { -- Add Melee Proc: Bubbling Rage Strike II, 2H Slash Attack for 254 with 53% Accuracy Mod (2 Strikes)
        Type='Disc',
        Group='rage',
        Names={'Roiling Rage', 'Frothing Rage', 'Seething Rage', 'Smoldering Rage', 'Bubbling Rage', 'Festering Rage'},
        Options={combatbuff=true}
    },
    { -- Decrease Frenzy Timer by 3s, Add Skill Proc: Amplified Frenzy Strike II (4.6k)
        Type='Disc',
        Group='frenzybuff',
        Names={'Heightened Frenzy', 'Buttressed Frenzy', 'Magnified Frenzy', 'Bolstered Frenzy', 'Amplified Frenzy', 'Augmented Frenzy', 'Steel Frenzy', 'Fighting Frenzy'},
        Options={combatbuff=true}
    },
    { -- Add Melee Proc: Sapping Strike II (4 Procs), Decrease Current HP by 9027, Returns 40% of Damage as Endurance, Max Per Hit: 4333
        Type='Disc',
        Group='strikes',
        Names={'Shriveling Strikes', 'Sapping Strikes'},
        Options={combatbuff=true}
    },
    { -- Increase all weapon skills Damage Bonus by 457, requires target of target
        Type='Disc',
        Group='shareddmg',
        Names={'Shared Barbarism', 'Shared Violence', 'Shared Atavism', 'Shared Cruelty', 'Shared Bloodlust', 'Shared Viciousness', 'Shared Savagery', 'Shared Brutality'},
        Options={combatbuff=true}
    },
    { -- proc stun when hit over 18k, lasts 1 hr, timer 18
        Type='Disc',
        Group='retaliation',
        Names={'Unthinking Retaliation', 'Instintive Retaliation', 'Reflexive Retaliation', 'Conditioned Retaliation'},
        Options={combatbuff=true}
    },
    { -- Add Melee Proc: Distraction Attack Strike XVIII (Decrease Hate by 2500, Decrease Current Hate by 1%) (Can hit with burns if you want, honestly doesn't help too much)
        Type='AA',
        Name='Distraction Attack',
        Options={combatbuff=true}
    },
--table.insert(self.combatBuffs, self:addAA('Desperation', {combat=true, combatbuff=true})) -- Increase Melee Haste v3 by 25% (Just regular haste, already will be max on raid) 20min cd, not combat buff
--table.insert(self.combatBuffs, self:addAA('Blood Pact', {combat=true, combatbuff=true})) -- Add Melee Proc: Blood Pact Strike XXII (2750) 10 min cd, not combat buff
    { -- Increase Chance to Critical Hit by 100%, Increase Accuracy by 21 (Lasts 10 mins now)
        Type='Disc',
        Group='crybuff',
        Names={'Cry Carnage', 'Cry Havoc'},
        Options={combat=true, ooc=false, combatbuff=true}
    },
    {
        Type='AA',
        Name='Decapitation',
        Options={opt='USEDECAP', emu=true, combat=true, combatbuff=true}
    },
    { -- Increase Hit Damage by 45% (Only need to hit this once per zone, unless you've died)
        Type='AA',
        Name='Battle Leap',
        Options={combatbuff=true}
    },
    {
        Type='Disc',
        Group='aura',
        Names={'Bloodlust Aura', 'Aura of Rage'},
        Options={aurabuff=true, combat=false}
    },
    {
        Type='Disc',
        Group='summonaxe',
        Names={'Axe of the Eviscerator', 'Axe of the Conqueror', 'Axe of the Vindicator', 'Axe of the Mangler', 'Axe of the Demolisher', 'Axe of the Brute', 'Axe of the Sunderer', 'Axe of the Savage', --[[emu begin]] 'Bonesplicer Axe'},
        Options={summonMinimum=101, selfbuff=true}
    },

    { -- Fade
        Type='AA',
        Name='Self Preservation',
        Options={fade=true}
    },

    -- Defensives
    { -- absorb 50% of dmg done to target to heal self, 15 min cd, timer 16
        Type='AA',
        Name='Blood Sustenance',
        Options={defensive=true}
    },
    { -- consume 5% end for 20% dmg reduction, drains end, 10 min cd, timer 14
        Type='AA',
        Name='Juggernaut\'s Resolve',
        Options={defensive=true}
    },
    { -- 50% dmg absorb, 3min cd, timer 8
        Type='AA',
        Name='Uncanny Resilience',
        Options={defensive=true}
    },

    -- Recover abilities
    {
        Type='AA',
        Name='Communion of Blood',
        Options={recover=true, combat=true, minhp=true}
    },

    -- Cures
    { -- self remove detri buffs
        Type='AA',
        Name='Agony of Absolution',
        Options={cure=true, all=true}
    },
}

--[[
self:addAA('Drawn to Blood') -- gravitates you towards target if under blinding fury or frenzied resolve
self:addAA('Bloodfury') -- consumes hp to use abilities that require reduced health, then gives dmg absorb buff
self:addAA('Tireless Sprint') -- short runspeed buff, 5 min cd
self:addAA('Furious Leap') -- leap
common.getBestDisc({'Blinding Frenzy'}) -- proc additional dmg, requires below 90% hp, 10 min cd, timer 11
common.getBestDisc({'Temple Shatter'}) -- stun, timer 10
common.getBestDisc({'Swift Punch', 'Rabbit Punch', 'Sucker Punch', 'Punch in the Throat', 'Kick in the Teeth', 'Slap in the Face'}) -- h2h only ooc punch, use to enter combat maybe? 2min cd, timer 9
common.getBestDisc({'Stinging Incision'}) -- reduce hp to 89%
common.getBestDisc({'Primed Retaliation'}) -- at or below 90% hp, 3 strikes + 300% dodge buff for 1 min, 10 min cd, timer 15
]]
-- end regen table.insert(, common.getBestDisc({'Convalesce', 'Night\'s Calming', 'Relax', 'Breather'}))
return Berserker
