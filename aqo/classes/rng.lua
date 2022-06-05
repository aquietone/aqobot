--- @type mq
local mq = require 'mq'
local assist = require('aqo.routines.assist')
local camp = require('aqo.routines.camp')
local common = require('aqo.common')
local config = require('aqo.configuration')
local logger = require('aqo.utils.logger')
local mode = require('aqo.mode')
local persistence = require('aqo.utils.persistence')
local state = require('aqo.state')
local ui = require('aqo.ui')

local rng = {}

local SPELLSETS = {standard=1}
local OPTS = {
    USEUNITYAZIA=true,
    USEUNITYBEZA=false,
    USERANGE=true,
    USEMELEE=true,
    USEDOT=false,
    USEPOISONARROW=true,
    USEFIREARROW=false,
    BUFFGROUP=false,
    DSTANK=false,
    NUKE=false,
    USEDISPEL=true,
}
config.set_spell_set('standard')
mq.cmd('/squelch /stick mod 0')

-- All spells ID + Rank name
local spells = {
    ['shots']=common.get_spellid_and_rank('Claimed Shots'), -- 4x archery attacks + dmg buff to archery attacks for 18s, Marked Shots
    ['focused']=common.get_spellid_and_rank('Focused Whirlwind of Arrows'), -- 4x archery attacks, Focused Blizzard of Arrows
    ['composite']=common.get_spellid_and_rank('Composite Fusillade'), -- double bow shot and fire+ice nuke
    ['heart']=common.get_spellid_and_rank('Heartruin'), -- consume class 3 wood silver tip arrow, strong vs animal/humanoid, magic bow shot, Heartruin
    ['opener']=common.get_spellid_and_rank('Stealthy Shot'), -- consume class 3 wood silver tip arrow, strong bow shot opener, OOC only
    ['summer']=common.get_spellid_and_rank('Summer\'s Torrent'), -- fire + ice nuke, Summer's Sleet
    ['boon']=common.get_spellid_and_rank('Lunarflare boon'), -- 
    ['healtot']=common.get_spellid_and_rank('Desperate Geyser'), -- heal ToT, Desperate Meltwater, fast cast, long cd
    ['healtot2']=common.get_spellid_and_rank('Darkflow Spring'), -- heal ToT, Meltwater Spring, slow cast
    ['dot']=common.get_spellid_and_rank('Bloodbeetle Swarm'), -- main DoT
    ['dotds']=common.get_spellid_and_rank('Swarm of Bloodflies'), -- DoT + reverse DS, Swarm of Hyperboreads
    ['dmgbuff']=common.get_spellid_and_rank('Arbor Stalker\'s Enrichment'), -- inc base dmg of skill attacks, Arbor Stalker's Enrichment
    ['alliance']=common.get_spellid_and_rank('Arbor Stalker\'s Coalition'),
    ['buffs']=common.get_spellid_and_rank('Shout of the Dusksage Stalker'), -- cloak of rimespurs, frostroar of the predator, strength of the arbor stalker, Shout of the Arbor Stalker
    -- Shout of the X Stalker Buffs
    ['cloak']=common.get_spellid_and_rank('Cloak of Bloodbarbs'), -- Cloak of Rimespurs
    ['predator']=common.get_spellid_and_rank('Bay of the Predator'), -- Frostroar of the Predator
    ['strength']=common.get_spellid_and_rank('Strength of the Dusksage Stalker'), -- Strength of the Arbor Stalker
    -- Unity AA Buffs
    ['protection']=common.get_spellid_and_rank('Protection of the Valley'), -- Protection of the Wakening Land
    ['eyes']=common.get_spellid_and_rank('Eyes of the Senshali'), -- Eyes of the Visionary
    ['hunt']=common.get_spellid_and_rank('Steeled by the Hunt'), -- Provoked by the Hunt
    ['coat']=common.get_spellid_and_rank('Moonthorn Coat'), -- Rimespur Coat
    -- Unity Azia only
    ['barrage']=common.get_spellid_and_rank('Devastating Barrage'), -- Devastating Velium
    -- Unity Beza only
    ['blades']=common.get_spellid_and_rank('Vociferous Blades'), -- Howling Blades
    ['ds']=common.get_spellid_and_rank('Shield of Shadethorns'), -- DS
    ['rune']=common.get_spellid_and_rank('Luclin\'s Darkfire Cloak'), -- self rune + debuff proc
}
-- Pyroclastic Boon, 
for name,spell in pairs(spells) do
    if spell['name'] then
        common.printf('[%s] Found spell: %s (%s)', name, spell['name'], spell['id'])
    else
        common.printf('[%s] Could not find spell!', name)
    end
end

-- entries in the dd_spells table are pairs of {spell id, spell name} in priority order
local arrow_spells = {}
table.insert(arrow_spells, spells['shots'])
table.insert(arrow_spells, spells['focused'])
table.insert(arrow_spells, spells['composite'])
table.insert(arrow_spells, spells['heart'])
local dd_spells = {}
table.insert(dd_spells, spells['boon'])
table.insert(dd_spells, spells['summer'])

-- entries in the dot_spells table are pairs of {spell id, spell name} in priority order
local dot_spells = {}
table.insert(dot_spells, spells['dot'])
table.insert(dot_spells, spells['dotds'])

-- entries in the combat_heal_spells table are pairs of {spell id, spell name} in priority order
local combat_heal_spells = {}
table.insert(combat_heal_spells, spells['healtot'])
--table.insert(combat_heal_spells, spells['healtot2']) -- replacing in main spell lineup with self rune buff

-- entries in the items table are MQ item datatypes
local burn_items = {}
table.insert(burn_items, mq.TLO.FindItem('Rage of Rolfron').ID())

local mash_items = {}
table.insert(mash_items, mq.TLO.InvSlot('Chest').Item.ID())

-- entries in the AAs table are pairs of {aa name, aa id}
local burnAAs = {}
table.insert(burnAAs, common.get_aaid_and_name('Spire of the Pathfinders')) -- 7.5min CD
table.insert(burnAAs, common.get_aaid_and_name('Auspice of the Hunter')) -- crit buff, 9min CD
table.insert(burnAAs, common.get_aaid_and_name('Pack Hunt')) -- swarm pets, 15min CD
table.insert(burnAAs, common.get_aaid_and_name('Empowered Blades')) -- melee dmg burn, 10min CD
table.insert(burnAAs, common.get_aaid_and_name('Guardian of the Forest')) -- base dmg, atk, overhaste, 6min CD
table.insert(burnAAs, common.get_aaid_and_name('Group Guardian of the Forest')) -- base dmg, atk, overhaste, 10min CD
table.insert(burnAAs, common.get_aaid_and_name('Outrider\'s Accuracy')) -- base dmg, accuracy, atk, crit dmg, 5min CD
table.insert(burnAAs, common.get_aaid_and_name('Imbued Ferocity')) -- 100% wep proc chance, 8min CD
table.insert(burnAAs, common.get_aaid_and_name('Silent Strikes')) -- silent casting
table.insert(burnAAs, common.get_aaid_and_name('Scarlet Cheetah\'s Fang')) -- does what?, 20min CD

local meleeBurnDiscs = {}
table.insert(meleeBurnDiscs, common.get_aaid_and_name('Dusksage Stalker\'s Discipline')) -- melee dmg buff, 19.5min CD, timer 2, Arbor Stalker's Discipline
local rangedBurnDiscs = {}
table.insert(rangedBurnDiscs, common.get_aaid_and_name('Pureshot Discipline')) -- bow dmg buff, 1hr7min CD, timer 2

local mashAAs = {}
table.insert(mashAAs, common.get_aaid_and_name('Elemental Arrow')) -- inc dmg from fire+ice nukes, 1min CD

local mashDiscs = {}
table.insert(mashDiscs, common.get_discid_and_name('Jolting Roundhouse Kicks')) -- agro reducer kick, timer 9, procs synergy, Jolting Roundhouse Kicks
table.insert(mashDiscs, common.get_discid_and_name('Focused Blizzard of Blades')) -- 4x arrows, 12s CD, timer 6
table.insert(mashDiscs, common.get_discid_and_name('Reflexive Rimespurs')) -- 4x melee attacks + group HoT, 10min CD, timer 19
-- table.insert(mashDiscs, common.get_aaid_and_name('Tempest of Blades')) -- frontal cone melee flurry, 12s CD

local mashAbilities = {}
table.insert(mashAbilities, 'Kick')

local dispel = common.get_aaid_and_name('Entropy of Nature') -- dispel 9 slots
local snare = common.get_aaid_and_name('Entrap')
local fade = common.get_aaid_and_name('Cover Tracks')
local unity_azia = common.get_aaid_and_name('Wildstalker\'s Unity (Azia)')
--Slot 1: 	Devastating Barrage
--Slot 2: 	Steeled by the Hunt
--Slot 3: 	Protection of the Valley
--Slot 4: 	Eyes of the Senshali
--Slot 5: 	Moonthorn Coat
local unity_beza = common.get_aaid_and_name('Wildstalker\'s Unity (Beza)')
--Slot 1: 	Vociferous Blades
--Slot 2: 	Steeled by the Hunt
--Slot 3: 	Protection of the Valley
--Slot 4: 	Eyes of the Senshali
--Slot 5: 	Moonthorn Coat
local poison = common.get_aaid_and_name('Poison Arrows')
local fire = common.get_aaid_and_name('Flaming Arrows')

local SETTINGS_FILE = ('%s/rangerbot_%s_%s.lua'):format(mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me.CleanName())
rng.load_settings = function()
    local settings = config.load_settings(SETTINGS_FILE)
    if not settings or not settings.rng then return end
    if settings.rng.USEUNITYAZIA ~= nil then OPTS.USEUNITYAZIA = settings.rng.USEUNITYAZIA end
    if settings.rng.USEUNITYBEZA ~= nil then OPTS.USEUNITYBEZA = settings.rng.USEUNITYBEZA end
    if settings.rng.USEMELEE ~= nil then OPTS.USEMELEE = settings.rng.USEMELEE end
    if settings.rng.USERANGE ~= nil then OPTS.USERANGE = settings.rng.USERANGE end
    if settings.rng.USEDOT ~= nil then OPTS.USEDOT = settings.rng.USEDOT end
    if settings.rng.USEPOISONARROW ~= nil then OPTS.USEPOISONARROW = settings.rng.USEPOISONARROW end
    if settings.rng.USEFIREARROW ~= nil then OPTS.USEFIREARROW = settings.rng.USEFIREARROW end
    if settings.rng.BUFFGROUP ~= nil then OPTS.USEFIREARROW = settings.rng.BUFFGROUP end
    if settings.rng.DSTANK ~= nil then OPTS.DSTANK = settings.rng.DSTANK end
    if settings.rng.NUKE ~= nil then OPTS.NUKE = settings.rng.NUKE end
    if settings.rng.USEDISPEL ~= nil then OPTS.USEDISPEL = settings.rng.USEDISPEL end
end

rng.save_settings = function()
    persistence.store(SETTINGS_FILE, {common=config.get_all(), rng=OPTS})
end

rng.reset_class_timers = function()
    -- no-op
end

local function get_ranged_combat_position(radius)
    local assist_mob_id = state.get_assist_mob_id()
    local mob_x = mq.TLO.Spawn('id '..assist_mob_id).X()
    local mob_y = mq.TLO.Spawn('id '..assist_mob_id).Y()
    local mob_z = mq.TLO.Spawn('id '..assist_mob_id).Z()
    local degrees = mq.TLO.Spawn('id '..assist_mob_id).Heading.Degrees()
    if not mob_x or not mob_y or not mob_z or not degrees then return false end
    local my_heading = degrees
    local base_radian = 10
    for i=1,36 do
        local x_move = math.cos(math.rad(common.convert_heading(base_radian * i + my_heading)))
        local y_move = math.sin(math.rad(common.convert_heading(base_radian * i + my_heading)))
        local x_off = mob_x + radius * x_move
        local y_off = mob_y + radius * y_move
        local z_off = mob_z
        if mq.TLO.Navigation.PathExists(string.format('locyxz %d %d %d', y_off, x_off, z_off))() then
            if mq.TLO.LineOfSight(string.format('%d,%d,%d:%d,%d,%d', y_off, x_off, z_off, mob_y, mob_x, mob_z))() then
                if mq.TLO.EverQuest.ValidLoc(string.format('%d %d %d', x_off, y_off, z_off))() then
                    common.printf('Found a valid location at %d %d %d', y_off, x_off, z_off)
                    mq.cmdf('/squelch /nav locyxz %d %d %d', y_off, x_off, z_off)
                    mq.delay('1s', function() return mq.TLO.Navigation.Active() end)
                    mq.delay('5s', function() return not mq.TLO.Navigation.Active() end)
                    return true
                end
            end
        end
    end
    return false
end

--local stick_timer = 0
local function attack_range()
    if state.get_assist_mob_id() == 0 or mq.TLO.Target.ID() ~= state.get_assist_mob_id() or not assist.should_assist() then
        if mq.TLO.Me.AutoFire() then mq.cmd('/autofire off') end
        return
    end
    if not mq.TLO.Target.LineOfSight() or mq.TLO.Target.Distance3D() < 35 then
        if not get_ranged_combat_position(40) then
            return false
        end
    end
    if mq.TLO.Navigation.Active() then
        mq.cmd('/squelch /nav stop')
    end
    --[[if not mq.TLO.Stick.Active() and common.timer_expired(stick_timer, 3) then
        mq.cmd('/squelch /stick moveback 35 uw')
        stick_timer = common.current_time()
    end]]--
    if not mq.TLO.Me.AutoFire() and mq.TLO.Target() then
        mq.cmd('/face fast')
        mq.cmd('/autofire on')
    end
    return true
end

local function use_opener()
    if not common.is_fighting() and state.get_assist_mob_id() > 0 and assist.should_assist() and mq.TLO.Me.SpellReady(spells['opener']['name'])() then
        common.cast(spells['opener']['name'], true, true)
    end
end

local function is_dot_ready(spellId, spellName)
    if mq.TLO.Spell(spellName).Mana() > mq.TLO.Me.CurrentMana() or (mq.TLO.Spell(spellName).Mana() > 1000 and mq.TLO.Me.PctMana() < state.get_min_mana()) then
        return false
    end
    if mq.TLO.Spell(spellName).EnduranceCost() > mq.TLO.Me.CurrentEndurance() or (mq.TLO.Spell(spellName).EnduranceCost() > 1000 and mq.TLO.Me.PctEndurance() < state.get_min_end()) then
        return false
    end
    if not mq.TLO.Target() or mq.TLO.Target.ID() ~= state.get_assist_mob_id() or mq.TLO.Target.Type() == 'Corpse' then return false end

    if not mq.TLO.Me.SpellReady(spellName)() then
        return false
    end

    local buffDuration = mq.TLO.Target.MyBuffDuration(spellName)()
    if not common.is_target_dotted_with(spellId, spellName) then
        -- target does not have the dot, we are ready
        return true
    else
        if not buffDuration then
            return true
        end
        local remainingCastTime = mq.TLO.Spell(spellName).MyCastTime()
        return buffDuration < remainingCastTime + 3000
    end

    return false
end

local function is_spell_ready(spellId, spellName)
    if mq.TLO.Spell(spellName).Mana() > mq.TLO.Me.CurrentMana() or (mq.TLO.Spell(spellName).Mana() > 1000 and mq.TLO.Me.PctMana() < state.get_min_mana()) then
        return false
    end
    if mq.TLO.Spell(spellName).EnduranceCost() > mq.TLO.Me.CurrentEndurance() or (mq.TLO.Spell(spellName).EnduranceCost() > 1000 and mq.TLO.Me.PctEndurance() < state.get_min_end()) then
        return false
    end
    if mq.TLO.Spell(spellName).TargetType() == 'Single' then
        if not mq.TLO.Target() or mq.TLO.Target.ID() ~= state.get_assist_mob_id() or mq.TLO.Target.Type() == 'Corpse' then return false end
    end

    if not mq.TLO.Me.SpellReady(spellName)() then
        return false
    end

    return true
end

--[[
    1. marked shot -- apply debuff
    2. focused shot -- strongest arrow spell
    3. dicho -- strong arrow spell
    4. wildfire spam
]]--
local function find_next_spell()
    local tothp = mq.TLO.Me.TargetOfTarget.PctHPs()
    if tothp and mq.TLO.Target() and mq.TLO.Target.Type() == 'NPC' and mq.TLO.Me.TargetOfTarget() and tothp < 40 then
        for _,spell in ipairs(combat_heal_spells) do
            if is_spell_ready(spell['id'], spell['name']) then
                return spell
            end
        end
    end
    for _,spell in ipairs(dot_spells) do
        if spell['name'] ~= spells['dot']['name'] or OPTS.USEDOT then
            if is_dot_ready(spell['id'], spell['name']) then
                return spell
            end
        end
    end
    for _,spell in ipairs(arrow_spells) do
        if is_spell_ready(spell['id'], spell['name']) then
            return spell
        end
    end
    if OPTS.NUKE then
        for _,spell in ipairs(dd_spells) do
            if is_spell_ready(spell['id'], spell['name']) then
                return spell
            end
        end
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

local function cycle_spells()
    if not mq.TLO.Me.Invis() then
        local spell = find_next_spell()
        if spell then
            if mq.TLO.Spell(spell['name']).TargetType() == 'Single' then
                common.cast(spell['name'], true, true)
            else
                common.cast(spell['name'])
            end
            return true
        end
    end
end

local function mash()
    if common.is_fighting() or assist.should_assist() then
        if OPTS.USEDISPEL then
            local target_hp = mq.TLO.Target.PctHPs()
            if target_hp and target_hp > 90 then
                common.use_aa(dispel)
            end
        end
        for _,item_id in ipairs(mash_items) do
            local item = mq.TLO.FindItem(item_id)
            common.use_item(item)
        end
        for _,aa in ipairs(mashAAs) do
            common.use_aa(aa)
        end
        for _,disc in ipairs(mashDiscs) do
            common.use_disc(disc)
        end
        local dist = mq.TLO.Target.Distance3D()
        if dist and dist < 15 then
            for _,ability in ipairs(mashAbilities) do
                common.use_ability(ability)
            end
        end
    end
end

--[[
    1. pureshot
    2. reflexive
    3. spire
    4. auspice
    5. pack hunt
    6. guardian of the forest (self)
    7. guardian of the forest (group) (after self fades)
    8. outrider's attack
    9. outrider's accuracy
    10. imbued ferocity
    11. chest clicky
    12. scout's mastery of the elements
    13. silent strikes
    14. bulwark of the brownies
    15. scarlet cheetah fang
]]--
local function try_burn()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag.
    -- Test them both for each item, and see which one(s) actually work.
    if common.is_burn_condition_met() then

        --[[
        |===========================================================================================
        |Spell Burn
        |===========================================================================================
        ]]--

        for _,aa in ipairs(burnAAs) do
            if aa['name'] ~= 'Group Guardian of the Forest' or (not mq.TLO.Me.Song('Guardian of the Forest')() and not mq.TLO.Me.Buff('Guardian of the Forest')()) then
                common.use_aa(aa)
            end
        end

        --[[
        |===========================================================================================
        |Item Burn
        |===========================================================================================
        ]]--

        for _,item_id in ipairs(burn_items) do
            local item = mq.TLO.FindItem(item_id)
            common.use_item(item)
        end

        --[[
        |===========================================================================================
        |Disc Burn
        |===========================================================================================
        ]]--
        if mq.TLO.Me.Combat() then
            for _,disc in ipairs(meleeBurnDiscs) do
                common.use_disc(disc)
            end
        elseif mq.TLO.Me.AutoFire() then
            for _,disc in ipairs(rangedBurnDiscs) do
                common.use_disc(disc)
            end
        end
    end
end

local check_aggro_timer = 0
local function check_aggro()
    --[[
    if OPTS.USEFADE and common.is_fighting() and mq.TLO.Target() then
        if mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID() or common.timer_expired(check_aggro_timer, 10) then
            if mq.TLO.Me.PctAggro() >= 70 then
                common.use_aa(fade)
                check_aggro_timer = common.current_time()
                mq.delay('1s')
                mq.cmd('/makemevis')
            end
        end
    end
    ]]--
end

local group_buff_timer = 0
local function check_buffs()
    if common.am_i_dead() then return end
    common.check_combat_buffs()
    if common.is_fighting() then return end
    if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.get_camp_radius()))() > 0 then return end

    -- ranger unity aa
    if OPTS.USEUNITYAZIA then
        if not mq.TLO.Me.Buff(spells['barrage']['name'])() or not mq.TLO.Me.Buff(spells['hunt']['name'])() or not mq.TLO.Me.Buff(spells['protection']['name'])() or not mq.TLO.Me.Buff(spells['eyes']['name'])() or not mq.TLO.Me.Buff(spells['coat']['name'])() then
            common.use_aa(unity_azia)
        end
    elseif OPTS.USEUNITYBEZA then
        if not mq.TLO.Me.Buff(spells['blades']['name'])() or not mq.TLO.Me.Buff(spells['hunt']['name'])() or not mq.TLO.Me.Buff(spells['protection']['name'])() or not mq.TLO.Me.Buff(spells['eyes']['name'])() or not mq.TLO.Me.Buff(spells['coat']['name'])() then
            common.use_aa(unity_beza)
        end
    end
    -- ranger group buffs
    if not mq.TLO.Me.Buff(spells['dmgbuff']['name'])() then
        common.cast(spells['dmgbuff']['name'])
        -- wait for GCD incase we move on to cast another right away
        mq.delay('1.5s', function() return mq.TLO.Me.SpellReady(spells['buffs']['name']) end)
    end
    if not mq.TLO.Me.Buff(spells['rune']['name'])() then
        local restore_gem = nil
        if not mq.TLO.Me.Gem(spells['rune']['name'])() then
            restore_gem = mq.TLO.Me.Gem(13)()
            common.swap_spell(spells['rune']['name'], 13)
        end
        mq.delay('3s', function() return mq.TLO.Me.SpellReady(spells['rune']['name'])() end)
        common.cast(spells['rune']['name'])
        if restore_gem then
            common.swap_spell(restore_gem, 13)
        end
        mq.delay('1.5s', function() return mq.TLO.Me.SpellReady(spells['rune']['name']) end)
    end
    if OPTS.BUFFGROUP and common.timer_expired(group_buff_timer, 60) then
        if mq.TLO.Group.Members() then
            for i=1,mq.TLO.Group.Members() do
                local group_member = mq.TLO.Group.Member(i).Spawn
                if group_member() then
                    if (not group_member.CachedBuff(spells['cloak']['name'])() and mq.TLO.Spell(spells['cloak']['name']).StacksSpawn(group_member.ID())) or
                            (not group_member.CachedBuff(spells['predator']['name'])() and mq.TLO.Spell(spells['predator']['name']).StacksSpawn(group_member.ID())) or
                            (not group_member.CachedBuff(spells['strength']['name'])() and mq.TLO.Spell(spells['strength']['name']).StacksSpawn(group_member.ID()) and not group_member.CachedBuff('Spiritual Vigor')()) then
                        group_member.DoTarget()
                        mq.delay(100, function() return mq.TLO.Target.ID() == group_member.ID() end)
                        mq.delay(200, function() return mq.TLO.Target.BuffsPopulated() end)
                        if (not mq.TLO.Target.Buff(spells['cloak']['name'])() and mq.TLO.Spell(spells['cloak']['name']).StacksTarget()) or
                                (not mq.TLO.Target.Buff(spells['predator']['name'])() and mq.TLO.Spell(spells['predator']['name']).StacksTarget()) or
                                (not mq.TLO.Target.Buff(spells['strength']['name'])() and mq.TLO.Spell(spells['strength']['name']).StacksTarget() and not mq.TLO.Target.Buff('Spiritual Vigor')()) then
                                    -- extra dumb check for spiritual vigor since it seems to be checking stacking against lower level spell
                            common.cast(spells['buffs']['name'])
                            -- wait for GCD incase we move on to cast another right away
                            mq.delay('1.5s', function() return mq.TLO.Me.SpellReady(spells['buffs']['name'])() end)
                        end
                    end
                    if not group_member.CachedBuff(spells['dmgbuff']['name'])() and mq.TLO.Spell(spells['dmgbuff']['name']).StacksSpawn(group_member.ID()) then
                        group_member.DoTarget()
                        mq.delay(100, function() return mq.TLO.Target.ID() == group_member.ID() end)
                        mq.delay(200, function() return mq.TLO.Target.BuffsPopulated() end)
                        if (not mq.TLO.Target.Buff(spells['dmgbuff']['name'])() and mq.TLO.Spell(spells['dmgbuff']['name']).StacksTarget()) then
                            common.cast(spells['dmgbuff']['name'])
                            -- wait for GCD incase we move on to cast another right away
                            mq.delay('1.5s', function() return mq.TLO.Me.SpellReady(spells['buffs']['name'])() end)
                        end
                    end
                end
            end
        end
        if OPTS.DSTANK then
            if mq.TLO.Group.MainTank() then
                local tank_spawn = mq.TLO.Group.MainTank.Spawn
                if tank_spawn() then
                    if not tank_spawn.CachedBuff(spells['ds']['name'])() and mq.TLO.Spell(spells['ds']['name']).StacksSpawn(tank_spawn.ID()) then
                        tank_spawn.DoTarget()
                        mq.delay(100, function() return mq.TLO.Target.ID() == tank_spawn.ID() end)
                        mq.delay(200, function() return mq.TLO.Target.BuffsPopulated() end)
                        if not mq.TLO.Target.Buff(spells['ds']['name'])() and mq.TLO.Spell(spells['ds']['name']).StacksTarget() then
                            common.cast(spells['ds']['name'])
                            -- wait for GCD incase we move on to cast another right away
                            mq.delay('1.5s', function() return mq.TLO.Me.SpellReady(spells['ds']['name'])() end)
                        end
                    end
                end
            end
        end
        group_buff_timer = common.current_time()
    end
    if OPTS.USEPOISONARROW then
        if not mq.TLO.Me.Buff('Poison Arrows')() then
            common.use_aa(poison)
        end
    elseif OPTS.USEFIREARROW then
        if not mq.TLO.Me.Buff('Fire Arrows')() then
            common.use_aa(fire)
        end
    end

    common.check_item_buffs()
end

local check_spell_timer = 0
local function check_spell_set()
    if common.is_fighting() or mq.TLO.Me.Moving() or common.am_i_dead() or OPTS.BYOS then return end
    if state.get_spellset_loaded() ~= config.get_spell_set() or common.timer_expired(check_spell_timer, 30) then
        if config.get_spell_set() == 'standard' then
            if mq.TLO.Me.Gem(1)() ~= spells['shots']['name'] then common.swap_spell(spells['shots']['name'], 1) end
            if mq.TLO.Me.Gem(2)() ~= spells['focused']['name'] then common.swap_spell(spells['focused']['name'], 2) end
            if mq.TLO.Me.Gem(3)() ~= 'Composite Fusillade' then common.swap_spell(spells['composite']['name'], 3) end
            if mq.TLO.Me.Gem(4)() ~= spells['heart']['name'] then common.swap_spell(spells['heart']['name'], 4) end
            if mq.TLO.Me.Gem(5)() ~= spells['opener']['name'] then common.swap_spell(spells['opener']['name'], 5) end
            if mq.TLO.Me.Gem(6)() ~= spells['summer']['name'] then common.swap_spell(spells['summer']['name'], 6) end
            if mq.TLO.Me.Gem(7)() ~= spells['healtot']['name'] then common.swap_spell(spells['healtot']['name'], 7) end
            --if mq.TLO.Me.Gem(8)() ~= spells['healtot2']['name'] then common.swap_spell(spells['healtot2']['name'], 8) end -- TODO: replace this one
            if mq.TLO.Me.Gem(8)() ~= spells['rune']['name'] then common.swap_spell(spells['rune']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['dot']['name'] then common.swap_spell(spells['dot']['name'], 9) end
            if mq.TLO.Me.Gem(10)() ~= spells['dotds']['name'] then common.swap_spell(spells['dotds']['name'], 10) end
            if mq.TLO.Me.Gem(12)() ~= spells['dmgbuff']['name'] then common.swap_spell(spells['dmgbuff']['name'], 12) end
            if mq.TLO.Me.Gem(13)() ~= spells['buffs']['name'] then common.swap_spell(spells['buffs']['name'], 13) end
            state.set_spellset_loaded(config.get_spell_set())
        end
        check_spell_timer = common.current_time()
    end
end

rng.setup_events = function()
    -- no-op
end

rng.process_cmd = function(opt, new_value)
    if new_value then
        if opt == 'ASSIST' then
            if common.ASSISTS[new_value] then
                logger.printf('Setting %s to: %s', opt, new_value)
                config.set_assist(new_value)
            end
        --[[elseif type(OPTS[opt]) == 'boolean' or type(common.OPTS[opt]) == 'boolean' then
            if new_value == '0' or new_value == 'off' then
                common.printf('Setting %s to: false', opt)
                if common.OPTS[opt] ~= nil then common.OPTS[opt] = false end
                if OPTS[opt] ~= nil then OPTS[opt] = false end
            elseif new_value == '1' or new_value == 'on' then
                common.printf('Setting %s to: true', opt)
                if common.OPTS[opt] ~= nil then common.OPTS[opt] = true end
                if OPTS[opt] ~= nil then OPTS[opt] = true end
            end
        elseif type(OPTS[opt]) == 'number' or type(common.OPTS[opt]) == 'number' then
            if tonumber(new_value) then
                common.printf('Setting %s to: %s', opt, tonumber(new_value))
                OPTS[opt] = tonumber(new_value)
                if common.OPTS[opt] ~= nil then common.OPTS[opt] = tonumber(new_value) end
                if OPTS[opt] ~= nil then OPTS[opt] = tonumber(new_value) end
            end]]--
        else
            common.printf('Unsupported command line option: %s %s', opt, new_value)
        end
    else
        if OPTS[opt] ~= nil then
            common.printf('%s: %s', opt, OPTS[opt])
        --elseif common.OPTS[opt] ~= nil then
        --    common.printf('%s: %s', opt, common.OPTS[opt])
        else
            common.printf('Unrecognized option: %s', opt)
        end
    end
end

rng.main_loop = function()
    -- ensure correct spells are loaded based on selected spell set
    check_spell_set()
    -- check whether we need to return to camp
    camp.check_camp()
    -- check whether we need to go chasing after the chase target
    common.check_chase()
    assist.check_target(rng.reset_class_timers)
    use_opener()
    -- if we should be assisting but aren't in los, try to be?
    if not OPTS.USERANGE or not attack_range() then
        if OPTS.USEMELEE then assist.attack() end
    end
    -- begin actual combat stuff
    assist.send_pet()
    if mq.TLO.Me.CombatState() ~= 'ACTIVE' and mq.TLO.Me.CombatState() ~= 'RESTING' then
        cycle_spells()
    end
    mash()
    -- pop a bunch of burn stuff if burn conditions are met
    try_burn()
    -- try not to run OOM
    check_aggro()
    common.check_mana()
    check_buffs()
    common.rest()
    mq.delay(1)
end

rng.draw_left_panel = function()
    local current_mode = config.get_mode():get_name()
    config.set_mode(mode.from_string(ui.draw_combo_box('Mode', config.get_mode():get_name(), mode.mode_names)))
    if current_mode ~= config.get_mode():get_name() then
        camp.set_camp(true)
    end
    config.set_assist(ui.draw_combo_box('Assist', config.get_assist(), common.ASSISTS, true))
    config.set_auto_assist_at(ui.draw_input_int('Assist %', '##assistat', config.get_auto_assist_at(), 'Percent HP to assist at'))
    config.set_camp_radius(ui.draw_input_int('Camp Radius', '##campradius', config.get_camp_radius(), 'Camp radius to assist within'))
    config.set_chase_target(ui.draw_input_text('Chase Target', '##chasetarget', config.get_chase_target(), 'Chase Target'))
    config.set_chase_distance(ui.draw_input_int('Chase Distance', '##chasedist', config.get_chase_distance(), 'Distance to follow chase target'))
    config.set_burn_percent(ui.draw_input_int('Burn Percent', '##burnpct', config.get_burn_percent(), 'Percent health to begin burns'))
    config.set_burn_count(ui.draw_input_int('Burn Count', '##burncnt', config.get_burn_count(), 'Trigger burns if this many mobs are on aggro'))
end

rng.draw_right_panel = function()
    config.set_burn_always(ui.draw_check_box('Burn Always', '##burnalways', config.get_burn_always(), 'Always be burning'))
    ui.get_next_item_loc()
    config.set_burn_all_named(ui.draw_check_box('Burn Named', '##burnnamed', config.get_burn_all_named(), 'Burn all named'))
    ui.get_next_item_loc()
    config.set_switch_with_ma(ui.draw_check_box('Switch With MA', '##switchwithma', config.get_switch_with_ma(), 'Switch targets with MA'))
    ui.get_next_item_loc()
    OPTS.USEUNITYAZIA = ui.draw_check_box('Use Unity (Azia)', '##useazia', OPTS.USEUNITYAZIA, 'Use Azia Unity Buff')
    if OPTS.USEUNITYAZIA then OPTS.USEUNITYBEZA = false end
    ui.get_next_item_loc()
    OPTS.USEUNITYBEZA = ui.draw_check_box('Use Unity (Beza)', '##usebeza', OPTS.USEUNITYBEZA, 'Use Beza Unity Buff')
    if OPTS.USEUNITYBEZA then OPTS.USEUNITYAZIA = false end
    ui.get_next_item_loc()
    OPTS.USEMELEE = ui.draw_check_box('Use Melee', '##usemelee', OPTS.USEMELEE, 'Melee DPS if ranged is disabled or not enough room')
    ui.get_next_item_loc()
    OPTS.USERANGE = ui.draw_check_box('Use Ranged', '##userange', OPTS.USERANGE, 'Ranged DPS if possible')
    ui.get_next_item_loc()
    OPTS.NUKE = ui.draw_check_box('Use Nukes', '##nuke', OPTS.NUKE, 'Cast nukes on all mobs')
    ui.get_next_item_loc()
    OPTS.USEDOT = ui.draw_check_box('Use DoT', '##usedot', OPTS.USEDOT, 'Cast expensive DoT on all mobs')
    ui.get_next_item_loc()
    OPTS.USEPOISONARROW = ui.draw_check_box('Use Poison Arrow', '##usepoison', OPTS.USEPOISONARROW, 'Use Poison Arrows AA')
    if OPTS.USEPOISONARROW then OPTS.USEFIREARROW = false end
    ui.get_next_item_loc()
    OPTS.USEFIREARROW = ui.draw_check_box('Use Fire Arrow', '##usefire', OPTS.USEFIREARROW, 'Use Fire Arrows AA')
    if OPTS.USEFIREARROW then OPTS.USEPOISONARROW = false end
    OPTS.BUFFGROUP = ui.draw_check_box('Buff Group', '##buffgroup', OPTS.BUFFGROUP, 'Buff group members')
    ui.get_next_item_loc()
    OPTS.DSTANK = ui.draw_check_box('DS Tank', '##dstank', OPTS.DSTANK, 'DS Tank')
    ui.get_next_item_loc()
    OPTS.USEDISPEL = ui.draw_check_box('Use Dispel', '##dispel', OPTS.USEDISPEL, 'Dispel mobs with Entropy AA')
end

return rng