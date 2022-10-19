--- @type Mq
local mq = require 'mq'
local class = require(AQO..'.classes.classbase')
local common = require(AQO..'.common')
local config = require(AQO..'.configuration')
local state = require(AQO..'.state')

-- What were these again?
mq.cmd('/squelch /stick mod -2')
mq.cmd('/squelch /stick set delaystrafe on')

class.class = 'war'
class.classOrder = {'assist', 'mash', 'ae', 'burn', 'ohshit', 'recover', 'buff', 'rest'}

--if OPTS.USEEXPANSE then OPTS.USEPRECISION = false end
--if OPTS.USEPRECISION then OPTS.USEEXPANSE = false end
-- key label value options tip type
class.addCommonOptions()
class.addOption('USEBATTLELEAP', 'Use Battle Leap', true, nil, 'Keep the Battle Leap AA Buff up', 'checkbox')
class.addOption('USEFORTITUDE', 'Use Fortitude', false, nil, 'Use Fortitude Discipline on burn', 'checkbox')
class.addOption('USEGRAPPLE', 'Use Grapple', true, nil, 'Use Grappling Strike AA', 'checkbox')
class.addOption('USEGRASP', 'Use Grasp', true, nil, 'Use Warlord\'s Grasp AA', 'checkbox')
class.addOption('USEPHANTOM', 'Use Phantom', false, nil, 'Use Phantom Aggressor pet discipline', 'checkbox')
class.addOption('USEPROJECTION', 'Use Projection', true, nil, 'Use Projection of Fury pet AA', 'checkbox')
class.addOption('USEEXPANSE', 'Use Expanse', false, nil, 'Use Concordant Expanse for AE aggro', 'checkbox')
class.addOption('USEPRECISION', 'Use Precision', false, nil, 'Use Concordant Precision for single target aggro', 'checkbox')
class.addOption('USESNARE', 'Use Snare', false, nil, 'Use Call of Challenge AA, which includes a snare', 'checkbox')

table.insert(class.tankAbilities, common.getSkill('Taunt'))

table.insert(class.tankAbilities, common.getBestDisc({'Primal Defense'}))
table.insert(class.tankAbilities, common.getBestDisc({'Namdrows\' Roar'}))
table.insert(class.tankAbilities, common.getBestDisc({'Bristle'}))
table.insert(class.tankAbilities, common.getBestDisc({'Twilight Shout'}))
table.insert(class.tankAbilities, common.getBestDisc({'Composite Shield'}))
table.insert(class.tankAbilities, common.getBestDisc({'Finish the Fight'}))
table.insert(class.tankAbilities, common.getBestDisc({'Phantom Aggressor'}, {opt='USEPHANTOM'}))
table.insert(class.tankAbilities, common.getBestDisc({'Confluent Precision'}, {opt='USEPRECISION'}))

table.insert(class.tankAbilities, common.getAA('Blast of Anger'))
table.insert(class.tankAbilities, common.getAA('Blade Guardian'))
table.insert(class.tankAbilities, common.getAA('Brace for Impact'))
table.insert(class.tankAbilities, common.getAA('Call of Challenge', {opt='USESNARE'}))
table.insert(class.tankAbilities, common.getAA('Grappling Strike', {opt='USEGRAPPLE'}))
table.insert(class.tankAbilities, common.getAA('Projection of Fury', {opt='USEPROJECTION'}))
table.insert(class.tankAbilities, common.getAA('Warlord\'s Grasp', {opt='USEGRASP'}))

table.insert(class.AETankAbilities, common.getBestDisc({'Roar of Challenge'}, {threshold=2}))
table.insert(class.AETankAbilities, common.getBestDisc({'Confluent Expanse'}, {opt='USEEXPANSE', threshold=2}))
table.insert(class.AETankAbilities, common.getBestDisc({'Wade into Battle'}, {threshold=4}))
table.insert(class.AETankAbilities, common.getAA('Area Taunt', {threshold=3}))

table.insert(class.tankBurnAbilities, common.getBestDisc({'Unrelenting Attention'}))
table.insert(class.tankBurnAbilities, common.getAA('Ageless Enmity')) -- big taunt
table.insert(class.tankBurnAbilities, common.getAA('Warlord\'s Fury')) -- more big aggro
table.insert(class.tankBurnAbilities, common.getAA('Mark of the Mage Hunter')) -- 25% spell dmg absorb
table.insert(class.tankBurnAbilities, common.getAA('Resplendent Glory')) -- increase incoming heals
table.insert(class.tankBurnAbilities, common.getAA('Warlord\'s Bravery')) -- reduce incoming melee dmg
table.insert(class.tankBurnAbilities, common.getAA('Warlord\'s Tenacity')) -- big heal and temp HP

local mash_defensive = common.getBestDisc({'Primal Defense'})
local defensive = common.getBestDisc({'Resolute Stand'})
local runes = common.getBestDisc({'Armor of Akhevan Runes'})
local stundefense = common.getBestDisc({'Levincrash Defense Discipline'})

-- what to do with this one..
local attraction = common.getBestDisc({'Forceful Attraction'})

-- mash use together
local aegis = common.getBestDisc({'Warrior\'s Aegis'})
local spire = common.getAA('Spire of the Warlord')

local fortitude = common.getBestDisc({'Fortitude Discipline'}, {opt='USEFORTITUDE'})
local flash = common.getBestDisc({'Flash of Anger'})
local resurgence = common.getAA('Warlord\'s Resurgence') -- 10min cd, 60k heal

--for _,disc in ipairs(mashAggroDiscs) do
--    logger.printf('Found disc %s (%s)', disc.name, disc.id)
--end
--for _,disc in ipairs(burnAggroDiscs) do
--    logger.printf('Found disc %s (%s)', disc.name, disc.id)
--end

-- DPS

table.insert(class.DPSAbilities, common.getSkill('Kick'))

table.insert(class.DPSAbilities, common.getBestDisc({'Shield Splinter'}))
table.insert(class.DPSAbilities, common.getBestDisc({'Throat Jab'}))
table.insert(class.DPSAbilities, common.getBestDisc({'Knuckle Break'}))

table.insert(class.DPSAbilities, common.getAA('Gut Punch'))
table.insert(class.DPSAbilities, common.getAA('Knee Strike'))

table.insert(class.burnAbilities, common.getBestDisc({'Brightfield\'s Onslaught Discipline'})) -- 15min cd, timer 6, 270% crit chance, 160% crit dmg, crippling blows, increase min dmg
table.insert(class.burnAbilities, common.getBestDisc({'Offensive Discipline'})) -- 4min cd, timer 2, increased offensive capabilities

table.insert(class.burnAbilities, common.getAA('War Sheol\'s Heroic Blade')) -- 15min cd, 3 2HS attacks, crit % and dmg buff for 1 min

table.insert(class.burnAbilities, common.getItem(mq.TLO.InvSlot('Chest').Item.Name()))
table.insert(class.burnAbilities, common.getItem('Rage of Rolfron'))
table.insert(class.burnAbilities, common.getItem('Blood Drinker\'s Coating'))

local exploitive = common.getBestDisc({'Exploitive Strike'}) -- 35s cd, timer 9, 2H attack, Mob HP 20% or below only

--for _,disc in ipairs(mashDPSDiscs) do
--    logger.printf('Found disc %s (%s)', disc.name, disc.id)
--end
--for _,disc in ipairs(burnDPSDiscs) do
--    logger.printf('Found disc %s (%s)', disc.name, disc.id)
--end

-- Buffs and Other

table.insert(class.recoverAbilities, common.getBestDisc({'Breather'}, {combat=false, endurance=true, threshold=20}))

local leap = common.getAA('Battle Leap', {opt='USEBATTLELEAP'}, {combat=false})
table.insert(class.auras, common.getBestDisc({'Champion\'s Aura'}))
table.insert(class.combatBuffs, common.getBestDisc({'Full Moon\'s Champion'}))
table.insert(class.combatBuffs, common.getBestDisc({'Commanding Voice'}))
table.insert(class.combatBuffs, common.getAA('Imperator\'s Command'))

table.insert(class.selfBuffs, common.getItem('Chestplate of the Dark Flame'))
table.insert(class.selfBuffs, common.getItem('Violet Conch of the Tempest'))
table.insert(class.selfBuffs, common.getItem('Mask of the Lost Guktan'))

table.insert(class.combatBuffs, common.getItem('Huntsman\'s Ethereal Quiver', {summons='Ethereal Arrow'}))

class.ae_class = function()
    if state.mob_count_nopet < 2 then return end
    -- Use Spire and Aegis when 2 or more mobs on aggro
    if spire and aegis and mq.TLO.Me.AltAbilityReady(spire.name)() and mq.TLO.Me.CombatAbilityReady(aegis.name)() then
        spire:use()
        aegis:use()
    end
end

class.mash_class = function()
    local dist = mq.TLO.Target.Distance3D() or 100
    if class.OPTS.USEBATTLELEAP.value and leap and not mq.TLO.Me.Song(leap.name)() and dist < 30 then
        leap:use()
        mq.delay(30)
    end

    local targethp = mq.TLO.Target.PctHPs() or 100
    if targethp <= 20 and exploitive then
        exploitive:use()
    end
end

class.burn_class = function()
    if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
        local replace_disc = mash_defensive and mash_defensive.name or nil
        if defensive then defensive:use(replace_disc) end
        if runes then runes:use(replace_disc) end
        if stundefense then stundefense:use(replace_disc) end

        -- Use Spire and Aegis when burning as tank
        if spire and aegis and mq.TLO.Me.AltAbilityReady(spire['name'])() and mq.TLO.Me.CombatAbilityReady(aegis['name'])() then
            spire:use()
            aegis:use()
        end
    end
end

class.ohshit_class = function()
    if mq.TLO.Me.PctHPs() < 35 and mq.TLO.Me.CombatState() == 'COMBAT' then
        resurgence:use()
        if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
            if flash and mq.TLO.Me.CombatAbilityReady(flash.name)() then
                flash:use()
            elseif class.OPTS.USEFORTITUDE.value then
                fortitude:use(mash_defensive and mash_defensive.name or nil)
            end
        end
    end
end

return class