--- @type mq
local mq = require 'mq'
local assist = require('aqo.routines.assist')
local camp = require('aqo.routines.camp')
local pull = require('aqo.routines.pull')
local tank = require('aqo.routines.tank')
local logger = require('aqo.utils.logger')
local persistence = require('aqo.utils.persistence')
local common = require('aqo.common')
local config = require('aqo.configuration')
local mode = require('aqo.mode')
local state = require('aqo.state')
local ui = require('aqo.ui')

local war = {}

local OPTS = {
    USEBATTLELEAP=true,
    USEFORTITUDE=false,
    USEGRAPPLE=true,
    USEGRASP=true,
    USEPHANTOM=false,
    USEPROJECTION=true,
    USEEXPANSE=false,
    USEPRECISION=false,
    USESNARE=false,
}
mq.cmd('/squelch /stick mod -2')
mq.cmd('/squelch /stick set delaystrafe on')

-- dps burn brightfield's onslaught, offensive discipline, war sheol's heroic blade, exploitive strike, warlord's resurgence, gut punch, knee strike, throat jab, shield splinter, knuckle break, kick, brace for impact

-- TANK
local mashAggroAbilities = {}
table.insert(mashAggroAbilities, 'Taunt')

local mashAggroDiscs = {}
--table.insert(mashAggroDiscs, common.get_disc('Shield Splinter'))
table.insert(mashAggroDiscs, common.get_disc('Primal Defense'))
table.insert(mashAggroDiscs, common.get_disc('Namdrows\' Roar'))
table.insert(mashAggroDiscs, common.get_disc('Bristle'))
--table.insert(mashAggroDiscs, common.get_disc('Throat Jab'))
--table.insert(mashAggroDiscs, common.get_disc('Knuckle Break'))
table.insert(mashAggroDiscs, common.get_disc('Twilight Shout'))
table.insert(mashAggroDiscs, common.get_disc('Composite Shield'))
table.insert(mashAggroDiscs, common.get_disc('Finish the Fight'))
table.insert(mashAggroDiscs, common.get_disc('Phantom Aggressor', 'USEPHANTOM'))
table.insert(mashAggroDiscs, common.get_disc('Confluent Precision', 'USEPRECISION'))

local mashAggroAAs = {}
--table.insert(mashAggroAAs, common.get_aa('Gut Punch'))
--table.insert(mashAggroAAs, common.get_aa('Knee Strike'))
table.insert(mashAggroAAs, common.get_aa('Blast of Anger'))
table.insert(mashAggroAAs, common.get_aa('Blade Guardian'))
table.insert(mashAggroAAs, common.get_aa('Brace for Impact'))
table.insert(mashAggroAAs, common.get_aa('Call of Challenge', 'USESNARE'))
table.insert(mashAggroAAs, common.get_aa('Grappling Strike', 'USEGRAPPLE'))
table.insert(mashAggroAAs, common.get_aa('Projection of Fury', 'USEPROJECTION'))
table.insert(mashAggroAAs, common.get_aa('Warlord\'s Grasp', 'USEGRASP'))

-- mash AE aggro
local mashAEDiscs2 = {}
table.insert(mashAEDiscs2, common.get_disc('Roar of Challenge'))
table.insert(mashAEDiscs2, common.get_disc('Confluent Expanse', 'USEEXPANSE'))
local mashAEDiscs4 = {}
table.insert(mashAEDiscs4, common.get_disc('Wade into Battle'))
local mashAEAAs = {}
table.insert(mashAEAAs, common.get_aa('Area Taunt'))

local burnAggroDiscs = {}
table.insert(burnAggroDiscs, common.get_disc('Unrelenting Attention'))
local burnAggroAAs = {}
table.insert(burnAggroAAs, common.get_aa('Ageless Enmity')) -- big taunt
table.insert(burnAggroAAs, common.get_aa('Warlord\'s Fury')) -- more big aggro
table.insert(burnAggroAAs, common.get_aa('Mark of the Mage Hunter')) -- 25% spell dmg absorb
table.insert(burnAggroAAs, common.get_aa('Resplendent Glory')) -- increase incoming heals
table.insert(burnAggroAAs, common.get_aa('Warlord\'s Bravery')) -- reduce incoming melee dmg
table.insert(burnAggroAAs, common.get_aa('Warlord\'s Tenacity')) -- big heal and temp HP

local mash_defensive = common.get_disc('Primal Defense')
local defensive = common.get_disc('Resolute Stand')
local runes = common.get_disc('Armor of Akhevan Runes')
local stundefense = common.get_disc('Levincrash Defense Discipline')

-- what to do with this one..
local attraction = common.get_disc('Forceful Attraction')

-- mash use together
local aegis = common.get_disc('Warrior\'s Aegis')
local spire = common.get_aa('Spire of the Warlord')

local fortitude = common.get_disc('Fortitude Discipline', 'USEFORTITUDE')
local flash = common.get_disc('Flash of Anger')
local resurgence = common.get_aa('Warlord\'s Resurgence') -- 10min cd, 60k heal

for _,disc in ipairs(mashAggroDiscs) do
    logger.printf('Found disc %s (%s)', disc.name, disc.id)
end
for _,disc in ipairs(burnAggroDiscs) do
    logger.printf('Found disc %s (%s)', disc.name, disc.id)
end

-- DPS

local mashDPSAbilities = {}
table.insert(mashDPSAbilities, 'Kick')

local mashDPSDiscs = {}
table.insert(mashDPSDiscs, common.get_disc('Shield Splinter'))
table.insert(mashDPSDiscs, common.get_disc('Throat Jab'))
table.insert(mashDPSDiscs, common.get_disc('Knuckle Break'))

local mashDPSAAs = {}
table.insert(mashDPSAAs, common.get_aa('Gut Punch'))
table.insert(mashDPSAAs, common.get_aa('Knee Strike'))

local burnDPSDiscs = {}
table.insert(burnDPSDiscs, common.get_disc('Brightfield\'s Onslaught Discipline')) -- 15min cd, timer 6, 270% crit chance, 160% crit dmg, crippling blows, increase min dmg
table.insert(burnDPSDiscs, common.get_disc('Offensive Discipline')) -- 4min cd, timer 2, increased offensive capabilities
local burnDPSAAs = {}
table.insert(burnDPSAAs, common.get_aa('War Sheol\'s Heroic Blade')) -- 15min cd, 3 2HS attacks, crit % and dmg buff for 1 min

local exploitive = common.get_disc('Exploitive Strike') -- 35s cd, timer 9, 2H attack, Mob HP 20% or below only

for _,disc in ipairs(mashDPSDiscs) do
    logger.printf('Found disc %s (%s)', disc.name, disc.id)
end
for _,disc in ipairs(burnDPSDiscs) do
    logger.printf('Found disc %s (%s)', disc.name, disc.id)
end

-- Buffs and Other

local regen = common.get_disc('Breather')

local leap = common.get_aa('Battle Leap')
local aura = common.get_disc('Champion\'s Aura')
local champion = common.get_disc('Full Moon\'s Champion')
local voice = common.get_disc('Commanding Voice')
local command = common.get_aa('Imperator\'s Command')

-- entries in the items table are MQ item datatypes
local items = {}
table.insert(items, mq.TLO.InvSlot('Chest').Item.ID())
table.insert(items, mq.TLO.FindItem('Rage of Rolfron').ID())
table.insert(items, mq.TLO.FindItem('Blood Drinker\'s Coating').ID())

local buff_items = {}
table.insert(buff_items, mq.TLO.FindItem('Chestplate of the Dark Flame').ID())
table.insert(buff_items, mq.TLO.FindItem('Violet Conch of the Tempest').ID())
table.insert(buff_items, mq.TLO.FindItem('Mask of the Lost Guktan').ID())

local summon_items = {}
table.insert(summon_items, mq.TLO.FindItem('Huntsman\'s Ethereal Quiver').ID())

local SETTINGS_FILE = ('%s/warbot_%s_%s.lua'):format(mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me.CleanName())
war.load_settings = function()
    local settings = config.load_settings(SETTINGS_FILE)
    if not settings or not settings.war then return end
    if settings.war.USEBATTLELEAP ~= nil then OPTS.USEBATTLELEAP = settings.war.USEBATTLELEAP end
    if settings.war.USEFORTITUDE ~= nil then OPTS.USEFORTITUDE = settings.war.USEFORTITUDE end
    if settings.war.USEGRAPPLE ~= nil then OPTS.USEGRAPPLE = settings.war.USEGRAPPLE end
    if settings.war.USEGRASP ~= nil then OPTS.USEGRASP = settings.war.USEGRASP end
    if settings.war.USEPHANTOM ~= nil then OPTS.USEPHANTOM = settings.war.USEPHANTOM end
    if settings.war.USEPROJECTION ~= nil then OPTS.USEPROJECTION = settings.war.USEPROJECTION end
    if settings.war.USEEXPANSE ~= nil then OPTS.USEEXPANSE = settings.war.USEEXPANSE end
    if settings.war.USEPRECISION ~= nil then OPTS.USEPRECISION = settings.war.USEPRECISION end
    if settings.war.USESNARE ~= nil then OPTS.USESNARE = settings.war.USESNARE end
end

war.save_settings = function()
    persistence.store(SETTINGS_FILE, {common=config.get_all(), war=OPTS})
end

war.reset_class_timers = function()
    -- no-op
end

local aggro_nopet_count = 'xtarhater radius %d zradius 50 nopet'
local function check_ae()
    if common.am_i_dead() then return end
    local mobs_on_aggro = mq.TLO.SpawnCount(aggro_nopet_count:format(config.get_camp_radius()))()
    if mobs_on_aggro >= 2 then
        -- Use Spire and Aegis when 2 or more mobs on aggro
        if mq.TLO.Me.AltAbilityReady(spire['name'])() and mq.TLO.Me.CombatAbilityReady(aegis['name'])() then
            common.use_aa(spire)
            common.use_disc(aegis)
        end
        -- Discs to use when 2 or more mobs on aggro
        for _,disc in ipairs(mashAEDiscs2) do
            if not disc['opt'] or OPTS[disc['opt']] then
                common.use_disc(disc)
            end
        end
        if mobs_on_aggro >= 3 then
            -- AA's to use when 3 or more mobs on aggro
            for _,aa in ipairs(mashAEAAs) do
                common.use_aa(aa)
            end

            if mobs_on_aggro >= 4 then
                -- Discs to use when 4 or more mobs on aggro
                for _,disc in ipairs(mashAEDiscs4) do
                    if not disc['opt'] or OPTS[disc['opt']] then
                        common.use_disc(disc)
                    end
                end
            end
        end
    end
end

local function check_end()
    if common.am_i_dead() then return end
    if mq.TLO.Me.PctEndurance() > 20 then return end
    if mq.TLO.Me.CombatState() == "COMBAT" then return end
    if regen then common.use_disc(regen) end
end

local function mash()
    local cur_mode = config.get_mode()
    if (cur_mode:is_tank_mode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:is_assist_mode() and assist.should_assist()) or (cur_mode:is_manual_mode() and mq.TLO.Me.CombatState() == 'COMBAT') then
        local target = mq.TLO.Target
        local dist = target.Distance3D()
        local maxdist = target.MaxRangeTo()
        local targethp = target.PctHPs()
        if OPTS.USEBATTLELEAP and leap and not mq.TLO.Me.Song(leap['name'])() and dist and dist < 30 then
            common.use_aa(leap)
            mq.delay(30)
        end
        if config.get_mode():is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
            for _,aa in ipairs(mashAggroAAs) do
                if not aa['opt'] or OPTS[aa['opt']] then
                    common.use_aa(aa)
                end
            end
            for _,disc in ipairs(mashAggroDiscs) do
                if not disc['opt'] or OPTS[disc['opt']] then
                    common.use_disc(disc)
                end
            end
            if dist and maxdist and dist < maxdist then
                for _,ability in ipairs(mashAggroAbilities) do
                    common.use_ability(ability)
                end
            end
        end
        for _,aa in ipairs(mashDPSAAs) do
            if not aa['opt'] or OPTS[aa['opt']] then
                common.use_aa(aa)
            end
        end
        for _,disc in ipairs(mashDPSDiscs) do
            if not disc['opt'] or OPTS[disc['opt']] then
                common.use_disc(disc)
            end
        end
        if dist and maxdist and dist < maxdist then
            for _,ability in ipairs(mashDPSAbilities) do
                common.use_ability(ability)
            end
        end
        if targethp and targethp <= 20 then
            common.use_disc(exploitive)
        end
    end
end

local function try_burn()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag.
    -- Test them both for each item, and see which one(s) actually work.
    if common.is_burn_condition_met() then
        if config.get_mode():is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
            common.use_disc(defensive, mash_defensive['name'])
            common.use_disc(runes, mash_defensive['name'])
            common.use_disc(stundefense, mash_defensive['name'])

            -- Use Spire and Aegis when burning as tank
            if spire and aegis and mq.TLO.Me.AltAbilityReady(spire['name'])() and mq.TLO.Me.CombatAbilityReady(aegis['name'])() then
                common.use_aa(spire)
                common.use_disc(aegis)
            end

            for _,aa in ipairs(burnAggroAAs) do
                common.use_aa(aa)
            end
        else
            for _,disc in ipairs(burnDPSDiscs) do
                common.use_disc(disc)
            end
        end
        -- use DPS burn AAs in either mode
        for _,aa in ipairs(burnDPSAAs) do
            common.use_aa(aa)
        end

        --Item Burn
        for _,item_id in ipairs(items) do
            local item = mq.TLO.FindItem(item_id)
            common.use_item(item)
        end
    end
end

local function oh_shit()
    if mq.TLO.Me.PctHPs() < 35 and mq.TLO.Me.CombatState() == 'COMBAT' then
        common.use_aa(resurgence)
        if config.get_mode():is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
            if flash and mq.TLO.Me.CombatAbilityReady(flash['name'])() then
                common.use_disc(flash)
            elseif OPTS.USEFORTITUDE then
                common.use_disc(fortitude, mash_defensive['name'])
            end
        end
    end
end

local function check_buffs()
    if common.am_i_dead() then return end
    common.check_combat_buffs()
    if champion and not mq.TLO.Me.Song(champion['name'])() then
        common.use_disc(champion)
    end
    if voice and not mq.TLO.Me.Song(voice['name'])() then
        common.use_disc(voice)
    end
    if command and not mq.TLO.Me.Song(command['name'])() then
        common.use_aa(command)
    end
    if mq.TLO.FindItemCount('Ethereal Arrow')() < 30 and not mq.TLO.Me.Moving() then
        local item = mq.TLO.FindItem(summon_items[1])
        common.use_item(item)
        mq.delay(50)
        mq.cmd('/autoinv')
    end

    if not common.clear_to_buff() then return end
    --if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.get_camp_radius()))() > 0 then return end

    if aura and not mq.TLO.Me.Aura(aura['name'])() and not mq.TLO.Me.Moving() then
        common.use_disc(aura)
        mq.delay(3000)
    end

    common.check_item_buffs()
    for _,itemid in ipairs(buff_items) do
        local item = mq.TLO.FindItem(itemid)
        if not mq.TLO.Me.Buff(item.Clicky())() then
            common.use_item(item)
        end
    end
end


war.setup_events = function()
    -- no-op
end

war.process_cmd = function(opt, new_value)
    if new_value then
        if type(OPTS[opt]) == 'boolean' then
            if common.BOOL.FALSE[new_value] then
                logger.printf('Setting %s to: false', opt)
                if OPTS[opt] ~= nil then OPTS[opt] = false end
            elseif common.BOOL.TRUE[new_value] then
                logger.printf('Setting %s to: true', opt)
                if OPTS[opt] ~= nil then OPTS[opt] = true end
            end
        elseif type(OPTS[opt]) == 'number' then
            if tonumber(new_value) then
                logger.printf('Setting %s to: %s', opt, tonumber(new_value))
                if OPTS[opt] ~= nil then OPTS[opt] = tonumber(new_value) end
            end
        else
            logger.printf('Unsupported command line option: %s %s', opt, new_value)
        end
    else
        if OPTS[opt] ~= nil then
            logger.printf('%s: %s', opt:lower(), OPTS[opt])
        else
            logger.printf('Unrecognized option: %s', opt)
        end
    end
end

war.main_loop = function()
    if not mq.TLO.Target() and not mq.TLO.Me.Combat() then
        state.set_tank_mob_id(0)
    end
    if not state.get_pull_in_progress() then
        check_end()
        if config.get_mode():is_tank_mode() then
            -- get mobs in camp
            camp.mob_radar()
            -- pick mob to tank if not tanking
            tank.find_mob_to_tank()
            tank.tank_mob()
        end
        -- check whether we need to return to camp
        camp.check_camp()
        -- check whether we need to go chasing after the chase target
        common.check_chase()
        -- ae aggro if multiples in camp -- do after return to camp to try to be in range when using
        oh_shit()
        if config.get_mode():is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
            check_ae()
        end
        -- if in an assist mode
        if config.get_mode():is_assist_mode() then
            assist.check_target(war.reset_class_timers)
            assist.attack()
        end
        -- begin actual combat stuff
        assist.send_pet()
        mash()
        -- pop a bunch of burn stuff if burn conditions are met
        try_burn()
        check_end()
        check_buffs()
        common.rest()
    end
    if config.get_mode():is_pull_mode() then
        pull.pull_mob()
    end
end

war.draw_skills_tab = function()
    OPTS.USEBATTLELEAP = ui.draw_check_box('Use Battle Leap', '##useleap', OPTS.USEBATTLELEAP, 'Keep the Battle Leap AA Buff up')
    OPTS.USEFORTITUDE = ui.draw_check_box('Use Fortitude', '##usefort', OPTS.USEFORTITUDE, 'Use Fortitude Discipline on burn')
    OPTS.USEGRAPPLE = ui.draw_check_box('Use Grapple', '##usegrapple', OPTS.USEGRAPPLE, 'Use Grappling Strike AA')
    OPTS.USEGRASP = ui.draw_check_box('Use Grasp', '##usegrasp', OPTS.USEGRASP, 'Use Warlord\'s Grasp AA')
    OPTS.USEPHANTOM = ui.draw_check_box('Use Phantom', '##usephantom', OPTS.USEPHANTOM, 'Use Phantom Aggressor pet discipline')
    OPTS.USEPROJECTION = ui.draw_check_box('Use Projection', '##useproj', OPTS.USEPROJECTION, 'Use Projection of Fury pet AA')
    OPTS.USEEXPANSE = ui.draw_check_box('Use Expanse', '##useexpanse', OPTS.USEEXPANSE, 'Use Concordant Expanse for AE aggro')
    if OPTS.USEEXPANSE then OPTS.USEPRECISION = false end
    OPTS.USEPRECISION = ui.draw_check_box('Use Precision', '##useprecision', OPTS.USEPRECISION, 'Use Concordant Precision for single target aggro')
    if OPTS.USEPRECISION then OPTS.USEEXPANSE = false end
    OPTS.USESNARE = ui.draw_check_box('Use Snare', '##usesnare', OPTS.USESNARE, 'Use Call of Challenge AA, which includes a snare')
end

war.draw_burn_tab = function()
    config.set_burn_always(ui.draw_check_box('Burn Always', '##burnalways', config.get_burn_always(), 'Always be burning'))
    config.set_burn_all_named(ui.draw_check_box('Burn Named', '##burnnamed', config.get_burn_all_named(), 'Burn all named'))
    config.set_burn_count(ui.draw_input_int('Burn Count', '##burncnt', config.get_burn_count(), 'Trigger burns if this many mobs are on aggro'))
    config.set_burn_percent(ui.draw_input_int('Burn Percent', '##burnpct', config.get_burn_percent(), 'Percent health to begin burns'))
end

return war