--- @type Mq
local mq = require 'mq'
local baseclass = require('aqo.classes.base')
local common = require('aqo.common')
local config = require('aqo.configuration')
local state = require('aqo.state')

-- What were these again?
mq.cmd('/squelch /stick mod -2')
mq.cmd('/squelch /stick set delaystrafe on')

local war = baseclass

war.class = 'war'
war.classOrder = {'assist', 'mash', 'ae', 'burn', 'ohshit', 'recover', 'buff', 'rest'}

--if OPTS.USEEXPANSE then OPTS.USEPRECISION = false end
--if OPTS.USEPRECISION then OPTS.USEEXPANSE = false end
-- key label value options tip type
war.addOption('USEBATTLELEAP', 'Use Battle Leap', true, nil, 'Keep the Battle Leap AA Buff up', 'checkbox')
war.addOption('USEFORTITUDE', 'Use Fortitude', false, nil, 'Use Fortitude Discipline on burn', 'checkbox')
war.addOption('USEGRAPPLE', 'Use Grapple', true, nil, 'Use Grappling Strike AA', 'checkbox')
war.addOption('USEGRASP', 'Use Grasp', true, nil, 'Use Warlord\'s Grasp AA', 'checkbox')
war.addOption('USEPHANTOM', 'Use Phantom', false, nil, 'Use Phantom Aggressor pet discipline', 'checkbox')
war.addOption('USEPROJECTION', 'Use Projection', true, nil, 'Use Projection of Fury pet AA', 'checkbox')
war.addOption('USEEXPANSE', 'Use Expanse', false, nil, 'Use Concordant Expanse for AE aggro', 'checkbox')
war.addOption('USEPRECISION', 'Use Precision', false, nil, 'Use Concordant Precision for single target aggro', 'checkbox')
war.addOption('USESNARE', 'Use Snare', false, nil, 'Use Call of Challenge AA, which includes a snare', 'checkbox')

table.insert(war.tankAbilities, {name='Taunt', type='ability'})

table.insert(war.tankAbilities, common.get_disc('Primal Defense'))
table.insert(war.tankAbilities, common.get_disc('Namdrows\' Roar'))
table.insert(war.tankAbilities, common.get_disc('Bristle'))
table.insert(war.tankAbilities, common.get_disc('Twilight Shout'))
table.insert(war.tankAbilities, common.get_disc('Composite Shield'))
table.insert(war.tankAbilities, common.get_disc('Finish the Fight'))
table.insert(war.tankAbilities, common.get_disc('Phantom Aggressor', {opt='USEPHANTOM'}))
table.insert(war.tankAbilities, common.get_disc('Confluent Precision', {opt='USEPRECISION'}))

table.insert(war.tankAbilities, common.get_aa('Blast of Anger'))
table.insert(war.tankAbilities, common.get_aa('Blade Guardian'))
table.insert(war.tankAbilities, common.get_aa('Brace for Impact'))
table.insert(war.tankAbilities, common.get_aa('Call of Challenge', {opt='USESNARE'}))
table.insert(war.tankAbilities, common.get_aa('Grappling Strike', {opt='USEGRAPPLE'}))
table.insert(war.tankAbilities, common.get_aa('Projection of Fury', {opt='USEPROJECTION'}))
table.insert(war.tankAbilities, common.get_aa('Warlord\'s Grasp', {opt='USEGRASP'}))

table.insert(war.AETankAbilities, common.get_disc('Roar of Challenge', {threshold=2}))
table.insert(war.AETankAbilities, common.get_disc('Confluent Expanse', {opt='USEEXPANSE', threshold=2}))
table.insert(war.AETankAbilities, common.get_disc('Wade into Battle', {threshold=4}))
table.insert(war.AETankAbilities, common.get_aa('Area Taunt', {threshold=3}))

table.insert(war.tankBurnAbilities, common.get_disc('Unrelenting Attention'))
table.insert(war.tankBurnAbilities, common.get_aa('Ageless Enmity')) -- big taunt
table.insert(war.tankBurnAbilities, common.get_aa('Warlord\'s Fury')) -- more big aggro
table.insert(war.tankBurnAbilities, common.get_aa('Mark of the Mage Hunter')) -- 25% spell dmg absorb
table.insert(war.tankBurnAbilities, common.get_aa('Resplendent Glory')) -- increase incoming heals
table.insert(war.tankBurnAbilities, common.get_aa('Warlord\'s Bravery')) -- reduce incoming melee dmg
table.insert(war.tankBurnAbilities, common.get_aa('Warlord\'s Tenacity')) -- big heal and temp HP

local mash_defensive = common.get_disc('Primal Defense')
local defensive = common.get_disc('Resolute Stand')
local runes = common.get_disc('Armor of Akhevan Runes')
local stundefense = common.get_disc('Levincrash Defense Discipline')

-- what to do with this one..
local attraction = common.get_disc('Forceful Attraction')

-- mash use together
local aegis = common.get_disc('Warrior\'s Aegis')
local spire = common.get_aa('Spire of the Warlord')

local fortitude = common.get_disc('Fortitude Discipline', {opt='USEFORTITUDE'})
local flash = common.get_disc('Flash of Anger')
local resurgence = common.get_aa('Warlord\'s Resurgence') -- 10min cd, 60k heal

--for _,disc in ipairs(mashAggroDiscs) do
--    logger.printf('Found disc %s (%s)', disc.name, disc.id)
--end
--for _,disc in ipairs(burnAggroDiscs) do
--    logger.printf('Found disc %s (%s)', disc.name, disc.id)
--end

-- DPS

table.insert(war.DPSAbilities, {name='Kick', type='ability'})

table.insert(war.DPSAbilities, common.get_disc('Shield Splinter'))
table.insert(war.DPSAbilities, common.get_disc('Throat Jab'))
table.insert(war.DPSAbilities, common.get_disc('Knuckle Break'))

table.insert(war.DPSAbilities, common.get_aa('Gut Punch'))
table.insert(war.DPSAbilities, common.get_aa('Knee Strike'))

table.insert(war.burnAbilities, common.get_disc('Brightfield\'s Onslaught Discipline')) -- 15min cd, timer 6, 270% crit chance, 160% crit dmg, crippling blows, increase min dmg
table.insert(war.burnAbilities, common.get_disc('Offensive Discipline')) -- 4min cd, timer 2, increased offensive capabilities

table.insert(war.burnAbilities, common.get_aa('War Sheol\'s Heroic Blade')) -- 15min cd, 3 2HS attacks, crit % and dmg buff for 1 min

table.insert(war.burnAbilities, {id=mq.TLO.InvSlot('Chest').Item.ID(), type='item'})
table.insert(war.burnAbilities, {id=mq.TLO.FindItem('Rage of Rolfron').ID(), type='item'})
table.insert(war.burnAbilities, {id=mq.TLO.FindItem('Blood Drinker\'s Coating').ID(), type='item'})

local exploitive = common.get_disc('Exploitive Strike') -- 35s cd, timer 9, 2H attack, Mob HP 20% or below only

--for _,disc in ipairs(mashDPSDiscs) do
--    logger.printf('Found disc %s (%s)', disc.name, disc.id)
--end
--for _,disc in ipairs(burnDPSDiscs) do
--    logger.printf('Found disc %s (%s)', disc.name, disc.id)
--end

-- Buffs and Other

table.insert(war.recoverAbilities, common.get_disc('Breather', {combat=false, endurance=true, threshold=20}))

local leap = common.get_aa('Battle Leap', {opt='USEBATTLELEAP'})
local aura = common.get_disc('Champion\'s Aura')
aura.type = 'discaura'
table.insert(war.buffs, aura)
table.insert(war.buffs, common.get_disc('Full Moon\'s Champion'))
table.insert(war.buffs, common.get_disc('Commanding Voice'))
table.insert(war.buffs, common.get_aa('Imperator\'s Command'))

table.insert(war.buffs, {id=mq.TLO.FindItem('Chestplate of the Dark Flame').ID(), type='item'})
table.insert(war.buffs, {id=mq.TLO.FindItem('Violet Conch of the Tempest').ID(), type='item'})
table.insert(war.buffs, {id=mq.TLO.FindItem('Mask of the Lost Guktan').ID(), type='item'})

table.insert(war.buffs, {id=mq.TLO.FindItem('Huntsman\'s Ethereal Quiver').ID(), type='summonitem', summons='Ethereal Arrow'})

war.ae_class = function()
    if state.mob_count_nopet < 2 then return end
    -- Use Spire and Aegis when 2 or more mobs on aggro
    if spire and aegis and mq.TLO.Me.AltAbilityReady(spire.name)() and mq.TLO.Me.CombatAbilityReady(aegis.name)() then
        common.use_aa(spire)
        common.use_disc(aegis)
    end
end

war.mash_class = function()
    local dist = mq.TLO.Target.Distance3D() or 100
    if war.OPTS.USEBATTLELEAP.value and leap and not mq.TLO.Me.Song(leap.name)() and dist < 30 then
        common.use_aa(leap)
        mq.delay(30)
    end

    local targethp = mq.TLO.Target.PctHPs() or 100
    if targethp <= 20 then
        common.use_disc(exploitive)
    end
end

war.burn_class = function()
    if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
        local replace_disc = mash_defensive and mash_defensive.name or nil
        common.use_disc(defensive, replace_disc)
        common.use_disc(runes, replace_disc)
        common.use_disc(stundefense, replace_disc)

        -- Use Spire and Aegis when burning as tank
        if spire and aegis and mq.TLO.Me.AltAbilityReady(spire['name'])() and mq.TLO.Me.CombatAbilityReady(aegis['name'])() then
            common.use_aa(spire)
            common.use_disc(aegis)
        end
    end
end

war.ohshit_class = function()
    if mq.TLO.Me.PctHPs() < 35 and mq.TLO.Me.CombatState() == 'COMBAT' then
        common.use_aa(resurgence)
        if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
            if flash and mq.TLO.Me.CombatAbilityReady(flash.name)() then
                common.use_disc(flash)
            elseif war.OPTS.USEFORTITUDE.value then
                common.use_disc(fortitude, mash_defensive and mash_defensive.name or nil)
            end
        end
    end
end

return war