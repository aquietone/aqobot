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

-- dps burn brightfield's onslaught, offensive discipline, war sheol's heroic blade, exploitive strike, warlord's resurgence, gut punch, knee strike, throat jab, shield splinter, knuckle break, kick, brace for impact
-- always on abilities
local mashAbilities = {}
table.insert(mashAbilities, 'Taunt')
table.insert(mashAbilities, 'Kick')

-- always on mash discs
local mashDiscs = {}
table.insert(mashDiscs, common.get_discid_and_name('Shield Splinter'))
table.insert(mashDiscs, common.get_discid_and_name('Primal Defense'))
table.insert(mashDiscs, common.get_discid_and_name('Namdrows\' Roar'))
table.insert(mashDiscs, common.get_discid_and_name('Bristle'))
table.insert(mashDiscs, common.get_discid_and_name('Throat Jab'))
table.insert(mashDiscs, common.get_discid_and_name('Knuckle Break'))
table.insert(mashDiscs, common.get_discid_and_name('Twilight Shout'))
table.insert(mashDiscs, common.get_discid_and_name('Composite Shield'))
table.insert(mashDiscs, common.get_discid_and_name('Finish the Fight'))
table.insert(mashDiscs, common.get_discid_and_name('Phantom Aggressor', 'USEPHANTOM'))
table.insert(mashDiscs, common.get_discid_and_name('Confluent Precision', 'USEPRECISION'))
table.insert(mashDiscs, common.get_discid_and_name('Phantom Aggressor', 'USEPHANTOM'))
for _,disc in ipairs(mashDiscs) do
    logger.printf('Found disc %s (%s)', disc.name, disc.id)
end

-- what to do with this one..
local attraction = common.get_discid_and_name('Forceful Attraction')

-- always on mash AAs
local mashAAs = {}
table.insert(mashAAs, common.get_aaid_and_name('Gut Punch'))
table.insert(mashAAs, common.get_aaid_and_name('Knee Strike'))
table.insert(mashAAs, common.get_aaid_and_name('Blast of Anger'))
table.insert(mashAAs, common.get_aaid_and_name('Blade Guardian'))
table.insert(mashAAs, common.get_aaid_and_name('Brace for Impact'))
table.insert(mashAAs, common.get_aaid_and_name('Call of Challenge', 'USESNARE'))
table.insert(mashAAs, common.get_aaid_and_name('Grappling Strike', 'USEGRAPPLE'))
table.insert(mashAAs, common.get_aaid_and_name('Projection of Fury', 'USEPROJECTION'))
table.insert(mashAAs, common.get_aaid_and_name('Warlord\'s Grasp', 'USEGRASP'))

-- mash use together
local aegis = common.get_discid_and_name('Warrior\'s Aegis')
local spire = common.get_aaid_and_name('Spire of the Warlord')

-- mash AE aggro
local mashAEDiscs2 = {}
table.insert(mashAEDiscs2, common.get_discid_and_name('Roar of Challenge'))
table.insert(mashAEDiscs2, common.get_discid_and_name('Concordant Expanse', 'USEEXPANSE'))

local mashAEDiscs4 = {}
table.insert(mashAEDiscs4, common.get_discid_and_name('Wade into Battle'))

local mashAEAAs = {}
table.insert(mashAEAAs, common.get_aaid_and_name('Area Taunt'))

local burnAgroDiscs = {}
table.insert(burnAgroDiscs, common.get_discid_and_name('Unrelenting Attention'))
local burnAgroAAs = {}
table.insert(burnAgroAAs, common.get_aaid_and_name('Ageless Enmity'))

local regen = common.get_discid_and_name('Breather')
print(regen['id'])
print(regen['name'])

local leap = common.get_aaid_and_name('Battle Leap')
local aura = common.get_discid_and_name('Champion\'s Aura')
local champion = common.get_discid_and_name('Full Moon\'s Champion')
local voice = common.get_discid_and_name('Commanding Voice')
local command = common.get_aaid_and_name('Imperator\'s Command')

local mash_defensive = common.get_discid_and_name('Primal Defense')
local defensive = common.get_discid_and_name('Resolute Stand')
local runes = common.get_discid_and_name('Armor of Akhevan Runes')
--local burnDiscs = {}
--table.insert(burnDiscs, common.get_aaid_and_name('Resolute Stand')) -- 
--table.insert(burnDiscs, common.get_aaid_and_name('Armor of Akhevan Runes')) -- 
local burnAAs = {}
table.insert(burnAAs, common.get_aaid_and_name('Mark of the Mage Hunter'))

local fortitude = common.get_discid_and_name('Fortitude Discipline', 'USEFORTITUDE')
local flash = common.get_discid_and_name('Flash of Anger')

-- entries in the items table are MQ item datatypes
local items = {}
table.insert(items, mq.TLO.InvSlot('Chest').Item.ID())
table.insert(items, mq.TLO.FindItem('Rage of Rolfron').ID())

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

local agro_nopet_count = 'xtarhater radius %d zradius 50 nopet'
war.check_ae = function()
    if common.am_i_dead() then return end
    local mobs_on_agro = mq.TLO.SpawnCount(agro_nopet_count:format(config.get_camp_radius()))()
    if mobs_on_agro >= 2 then
        for _,disc in ipairs(mashAEDiscs2) do
            if not disc['opt'] or OPTS[disc['opt']] then
                common.use_disc(disc)
            end
        end
        if mobs_on_agro >= 3 then
            for _,aa in ipairs(mashAEAAs) do
                common.use_aa(aa)
            end

            if mobs_on_agro >= 4 then
                for _,disc in ipairs(mashAEDiscs4) do
                    if not disc['opt'] or OPTS[disc['opt']] then
                        common.use_disc(disc)
                    end
                end
            end
        end
    end
end

--[[
bool IsActiveDisc(EQ_Spell* pSpell) {
    if (!InGame())
        return false;

    if ((pSpell->DurationType == 11 || pSpell->DurationType == 15) &&
        pSpell->SpellType == ST_Beneficial &&
        pSpell->TargetType == TT_Self &&
        (pSpell->Skill == 33 || pSpell->Skill == 15) &&
        pSpell->spaindex == 51 &&
        pSpell->SpellAnim != 0 &&
        pSpell->Subcategory != 155)
        return true;

    return false;
}
Sub IsDisc(string name) 
/if (${Spell[${name}].IsSkill} && ${Spell[${name}].Duration} && !${Spell[${name}].StacksWithDiscs}) /return TRUE
/return FALSE

Sub IsDisc(string name) 
    /if (${Spell[${name}].IsSkill} && ${Spell[${name}].Duration} && ${Spell[${name}].TargetType.Equal[SELF]}  && !${Spell[${name}].StacksWithDiscs}) /return TRUE
/return FALSE
]]--
war.check_end = function()
    if common.am_i_dead() then return end
    if mq.TLO.Me.PctEndurance() > 20 then return end
    if mq.TLO.Me.CombatState() == "COMBAT" then return end
    common.use_disc(regen, nil, true) -- skip duration check
end

local function mash()
    if common.is_fighting() or assist.should_assist() then
        local dist = mq.TLO.Target.Distance3D()
        if dist and dist < 15 then
            if not mq.TLO.Me.Song(leap['name'])() then
                common.use_aa(leap)
            end
            for _,aa in ipairs(mashAAs) do
                if not aa['opt'] or OPTS[aa['opt']] then
                    common.use_aa(aa)
                end
            end
            for _,disc in ipairs(mashDiscs) do
                if not disc['opt'] or OPTS[disc['opt']] then
                    common.use_disc(disc)
                end
            end
            for _,ability in ipairs(mashAbilities) do
                common.use_ability(ability)
            end
        end
        if mq.TLO.Me.AltAbilityReady(spire['name']) and mq.TLO.Me.CombatAbilityReady(aegis['name']) then
            common.use_aa(spire)
            common.use_disc(aegis)
        end
    end
end

local function try_burn()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag.
    -- Test them both for each item, and see which one(s) actually work.
    if common.is_burn_condition_met() then
        common.use_disc(defensive, mash_defensive['name'])
        common.use_disc(runes, mash_defensive['name'])

        --[[
        |===========================================================================================
        |Spell Burn
        |===========================================================================================
        ]]--

        for _,aa in ipairs(burnAAs) do
            common.use_aa(aa)
        end

        --[[
        |===========================================================================================
        |Item Burn
        |===========================================================================================
        ]]--

        for _,item_id in ipairs(items) do
            local item = mq.TLO.FindItem(item_id)
            common.use_item(item)
        end
    end
end

local function check_buffs()
    if common.am_i_dead() then return end
    common.check_combat_buffs()
    if not mq.TLO.Me.Song(champion['name'])() then
        common.use_disc(champion)
    end
    if not mq.TLO.Me.Song(voice['name'])() then
        common.use_disc(voice)
    end
    if not mq.TLO.Me.Song(command['name'])() then
        common.use_aa(command)
    end
    if mq.TLO.FindItemCount('Ethereal Arrow')() < 30 then
        local item = mq.TLO.FindItem(summon_items[1])
        common.use_item(item)
        mq.delay(50)
        mq.cmd('/autoinv')
    end

    if common.is_fighting() then return end
    if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.get_camp_radius()))() > 0 then return end

    if not mq.TLO.Me.Song(aura['name'])() then
        common.use_disc(aura)
        mq.delay('3s')
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
        if opt == 'ASSIST' then
            if common.ASSISTS[new_value] then
                logger.printf('Setting %s to: %s', opt, new_value)
                config.set_assist(new_value)
            end
        --[[
        elseif type(OPTS[opt]) == 'boolean' or type(common.OPTS[opt]) == 'boolean' then
            if new_value == '0' or new_value == 'off' then
                logger.printf('Setting %s to: false', opt)
                if common.OPTS[opt] ~= nil then common.OPTS[opt] = false end
                if OPTS[opt] ~= nil then OPTS[opt] = false end
            elseif new_value == '1' or new_value == 'on' then
                logger.printf('Setting %s to: true', opt)
                if common.OPTS[opt] ~= nil then common.OPTS[opt] = true end
                if OPTS[opt] ~= nil then OPTS[opt] = true end
            end
        elseif type(OPTS[opt]) == 'number' or type(common.OPTS[opt]) == 'number' then
            if tonumber(new_value) then
                logger.printf('Setting %s to: %s', opt, tonumber(new_value))
                OPTS[opt] = tonumber(new_value)
                if common.OPTS[opt] ~= nil then common.OPTS[opt] = tonumber(new_value) end
                if OPTS[opt] ~= nil then OPTS[opt] = tonumber(new_value) end
            end
        ]]--
        else
            logger.printf('Unsupported command line option: %s %s', opt, new_value)
        end
    else
        if OPTS[opt] ~= nil then
            logger.printf('%s: %s', opt, OPTS[opt])
        --elseif common.OPTS[opt] ~= nil then
        --    logger.printf('%s: %s', opt, common.OPTS[opt])
        else
            logger.printf('Unrecognized option: %s', opt)
        end
    end
end

war.main_loop = function()
    if not mq.TLO.Target() and not mq.TLO.Me.Combat() then
        state.set_tank_mob_id(0)
    end
    war.check_end()
    if config.get_mode():is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
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
    if config.get_mode():is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
        war.check_ae()
    end
    -- if in an assist mode
    if config.get_mode():is_assist_mode() then
        assist.check_target(war.reset_class_timers)
        assist.attack()
    end
    -- if in a pull mode and no mobs
    if config.get_mode():is_pull_mode() and state.get_assist_mob_id() == 0 and state.get_tank_mob_id() == 0 and state.get_pull_mob_id() == 0 and mq.TLO.Me.XTarget() == 0 then
        mq.cmd('/multiline ; /squelch /nav stop; /attack off; /autofire off;')
        mq.delay(50)
        war.check_end()
        pull.pull_radar()
        pull.pull_mob()
        -- TODO: not necessarily a tank just because pulling
        tank.find_mob_to_tank()
        tank.tank_mob()
    end
    -- begin actual combat stuff
    assist.send_pet()
    mash()
    -- pop a bunch of burn stuff if burn conditions are met
    try_burn()
    war.check_end()
    check_buffs()
    common.rest()
    mq.delay(1)
end

war.draw_left_panel = function()
    local current_mode = config.get_mode():get_name()
    local current_camp_radius = config.get_camp_radius()
    config.set_mode(mode.from_string(ui.draw_combo_box('Mode', config.get_mode():get_name(), mode.mode_names)))
    config.set_assist(ui.draw_combo_box('Assist', config.get_assist(), common.ASSISTS, true))
    config.set_auto_assist_at(ui.draw_input_int('Assist %', '##assistat', config.get_auto_assist_at(), 'Percent HP to assist at'))
    config.set_camp_radius(ui.draw_input_int('Camp Radius', '##campradius', config.get_camp_radius(), 'Camp radius to assist within'))
    config.set_chase_target(ui.draw_input_text('Chase Target', '##chasetarget', config.get_chase_target(), 'Chase Target'))
    config.set_chase_distance(ui.draw_input_int('Chase Distance', '##chasedist', config.get_chase_distance(), 'Distance to follow chase target'))
    config.set_burn_percent(ui.draw_input_int('Burn Percent', '##burnpct', config.get_burn_percent(), 'Percent health to begin burns'))
    config.set_burn_count(ui.draw_input_int('Burn Count', '##burncnt', config.get_burn_count(), 'Trigger burns if this many mobs are on aggro'))
    if current_mode ~= config.get_mode():get_name() or current_camp_radius ~= config.get_camp_radius() then
        camp.set_camp()
    end
end

war.draw_right_panel = function()
    config.set_burn_always(ui.draw_check_box('Burn Always', '##burnalways', config.get_burn_always(), 'Always be burning'))
    ui.get_next_item_loc()
    config.set_burn_all_named(ui.draw_check_box('Burn Named', '##burnnamed', config.get_burn_all_named(), 'Burn all named'))
    ui.get_next_item_loc()
    config.set_switch_with_ma(ui.draw_check_box('Switch With MA', '##switchwithma', config.get_switch_with_ma(), 'Switch targets with MA'))
    ui.get_next_item_loc()
    OPTS.USEBATTLELEAP = ui.draw_check_box('Use Battle Leap', '##useleap', OPTS.USEBATTLELEAP, 'Keep the Battle Leap AA Buff up')
    ui.get_next_item_loc()
    OPTS.USEFORTITUDE = ui.draw_check_box('Use Fortitude', '##usefort', OPTS.USEFORTITUDE, 'Use Fortitude Discipline on burn')
    ui.get_next_item_loc()
    OPTS.USEGRAPPLE = ui.draw_check_box('Use Grapple', '##usegrapple', OPTS.USEGRAPPLE, 'Use Grappling Strike AA')
    ui.get_next_item_loc()
    OPTS.USEGRASP = ui.draw_check_box('Use Grasp', '##usegrasp', OPTS.USEGRASP, 'Use Warlord\'s Grasp AA')
    ui.get_next_item_loc()
    OPTS.USEPHANTOM = ui.draw_check_box('Use Phantom', '##usephantom', OPTS.USEPHANTOM, 'Use Phantom Aggressor pet discipline')
    ui.get_next_item_loc()
    OPTS.USEPROJECTION = ui.draw_check_box('Use Projection', '##useproj', OPTS.USEPROJECTION, 'Use Projection of Fury pet AA')
    ui.get_next_item_loc()
    OPTS.USEEXPANSE = ui.draw_check_box('Use Expanse', '##useexpanse', OPTS.USEEXPANSE, 'Use Concordant Expanse for AE aggro')
    if OPTS.USEEXPANSE then OPTS.USEPRECISION = false end
    ui.get_next_item_loc()
    OPTS.USEPRECISION = ui.draw_check_box('Use Precision', '##useprecision', OPTS.USEPRECISION, 'Use Concordant Precision for single target aggro')
    if OPTS.USEPRECISION then OPTS.USEEXPANSE = false end
    ui.get_next_item_loc()
    OPTS.USESNARE = ui.draw_check_box('Use Snare', '##usesnare', OPTS.USESNARE, 'Use Call of Challenge AA, which includes a snare')
end

return war