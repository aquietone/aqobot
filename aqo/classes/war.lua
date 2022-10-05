--- @type Mq
local mq = require 'mq'
local baseclass = require(AQO..'.classes.base')
local common = require(AQO..'.common')
local config = require(AQO..'.configuration')
local state = require(AQO..'.state')

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

table.insert(war.tankAbilities, common.getSkill('Taunt'))

table.insert(war.tankAbilities, common.getBestDisc({'Primal Defense'}))
table.insert(war.tankAbilities, common.getBestDisc({'Namdrows\' Roar'}))
table.insert(war.tankAbilities, common.getBestDisc({'Bristle'}))
table.insert(war.tankAbilities, common.getBestDisc({'Twilight Shout'}))
table.insert(war.tankAbilities, common.getBestDisc({'Composite Shield'}))
table.insert(war.tankAbilities, common.getBestDisc({'Finish the Fight'}))
table.insert(war.tankAbilities, common.getBestDisc({'Phantom Aggressor'}, {opt='USEPHANTOM'}))
table.insert(war.tankAbilities, common.getBestDisc({'Confluent Precision'}, {opt='USEPRECISION'}))

table.insert(war.tankAbilities, common.getAA('Blast of Anger'))
table.insert(war.tankAbilities, common.getAA('Blade Guardian'))
table.insert(war.tankAbilities, common.getAA('Brace for Impact'))
table.insert(war.tankAbilities, common.getAA('Call of Challenge', {opt='USESNARE'}))
table.insert(war.tankAbilities, common.getAA('Grappling Strike', {opt='USEGRAPPLE'}))
table.insert(war.tankAbilities, common.getAA('Projection of Fury', {opt='USEPROJECTION'}))
table.insert(war.tankAbilities, common.getAA('Warlord\'s Grasp', {opt='USEGRASP'}))

table.insert(war.AETankAbilities, common.getBestDisc({'Roar of Challenge'}, {threshold=2}))
table.insert(war.AETankAbilities, common.getBestDisc({'Confluent Expanse'}, {opt='USEEXPANSE', threshold=2}))
table.insert(war.AETankAbilities, common.getBestDisc({'Wade into Battle'}, {threshold=4}))
table.insert(war.AETankAbilities, common.getAA('Area Taunt', {threshold=3}))

table.insert(war.tankBurnAbilities, common.getBestDisc({'Unrelenting Attention'}))
table.insert(war.tankBurnAbilities, common.getAA('Ageless Enmity')) -- big taunt
table.insert(war.tankBurnAbilities, common.getAA('Warlord\'s Fury')) -- more big aggro
table.insert(war.tankBurnAbilities, common.getAA('Mark of the Mage Hunter')) -- 25% spell dmg absorb
table.insert(war.tankBurnAbilities, common.getAA('Resplendent Glory')) -- increase incoming heals
table.insert(war.tankBurnAbilities, common.getAA('Warlord\'s Bravery')) -- reduce incoming melee dmg
table.insert(war.tankBurnAbilities, common.getAA('Warlord\'s Tenacity')) -- big heal and temp HP

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

table.insert(war.DPSAbilities, common.getSkill('Kick'))

table.insert(war.DPSAbilities, common.getBestDisc({'Shield Splinter'}))
table.insert(war.DPSAbilities, common.getBestDisc({'Throat Jab'}))
table.insert(war.DPSAbilities, common.getBestDisc({'Knuckle Break'}))

table.insert(war.DPSAbilities, common.getAA('Gut Punch'))
table.insert(war.DPSAbilities, common.getAA('Knee Strike'))

table.insert(war.burnAbilities, common.getBestDisc({'Brightfield\'s Onslaught Discipline'})) -- 15min cd, timer 6, 270% crit chance, 160% crit dmg, crippling blows, increase min dmg
table.insert(war.burnAbilities, common.getBestDisc({'Offensive Discipline'})) -- 4min cd, timer 2, increased offensive capabilities

table.insert(war.burnAbilities, common.getAA('War Sheol\'s Heroic Blade')) -- 15min cd, 3 2HS attacks, crit % and dmg buff for 1 min

table.insert(war.burnAbilities, common.getItem(mq.TLO.InvSlot('Chest').Item.Name()))
table.insert(war.burnAbilities, common.getItem('Rage of Rolfron'))
table.insert(war.burnAbilities, common.getItem('Blood Drinker\'s Coating'))

local exploitive = common.getBestDisc({'Exploitive Strike'}) -- 35s cd, timer 9, 2H attack, Mob HP 20% or below only

--for _,disc in ipairs(mashDPSDiscs) do
--    logger.printf('Found disc %s (%s)', disc.name, disc.id)
--end
--for _,disc in ipairs(burnDPSDiscs) do
--    logger.printf('Found disc %s (%s)', disc.name, disc.id)
--end

-- Buffs and Other

table.insert(war.recoverAbilities, common.getBestDisc({'Breather'}, {combat=false, endurance=true, threshold=20}))

local leap = common.getAA('Battle Leap', {opt='USEBATTLELEAP'})
local aura = common.getBestDisc({'Champion\'s Aura'})
aura.type = 'discaura'
table.insert(war.buffs, aura)
table.insert(war.buffs, common.getBestDisc({'Full Moon\'s Champion'}))
table.insert(war.buffs, common.getBestDisc({'Commanding Voice'}))
table.insert(war.buffs, common.getAA('Imperator\'s Command'))

table.insert(war.buffs, common.getItem('Chestplate of the Dark Flame'))
table.insert(war.buffs, common.getItem('Violet Conch of the Tempest'))
table.insert(war.buffs, common.getItem('Mask of the Lost Guktan'))

table.insert(war.buffs, common.getItem('Huntsman\'s Ethereal Quiver', {summons='Ethereal Arrow'}))

war.ae_class = function()
    if state.mob_count_nopet < 2 then return end
    -- Use Spire and Aegis when 2 or more mobs on aggro
    if spire and aegis and mq.TLO.Me.AltAbilityReady(spire.name)() and mq.TLO.Me.CombatAbilityReady(aegis.name)() then
        spire:use()
        aegis:use()
    end
end

war.mash_class = function()
    local dist = mq.TLO.Target.Distance3D() or 100
    if war.OPTS.USEBATTLELEAP.value and leap and not mq.TLO.Me.Song(leap.name)() and dist < 30 then
        leap:use()
        mq.delay(30)
    end

    local targethp = mq.TLO.Target.PctHPs() or 100
    if targethp <= 20 then
        exploitive:use()
    end
end

war.burn_class = function()
    if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
        local replace_disc = mash_defensive and mash_defensive.name or nil
        defensive:use(replace_disc)
        runes:use(replace_disc)
        stundefense:use(replace_disc)

        -- Use Spire and Aegis when burning as tank
        if spire and aegis and mq.TLO.Me.AltAbilityReady(spire['name'])() and mq.TLO.Me.CombatAbilityReady(aegis['name'])() then
            spire:use()
            aegis:use()
        end
    end
end

war.ohshit_class = function()
    if mq.TLO.Me.PctHPs() < 35 and mq.TLO.Me.CombatState() == 'COMBAT' then
        resurgence:use()
        if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
            if flash and mq.TLO.Me.CombatAbilityReady(flash.name)() then
                flash:use()
            elseif war.OPTS.USEFORTITUDE.value then
                fortitude:use(mash_defensive and mash_defensive.name or nil)
            end
        end
    end
end

return war