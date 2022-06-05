--- @type mq
local mq = require 'mq'
local assist = require('aqo.routines.assist')
local camp = require('aqo.routines.camp')
local logger = require('aqo.utils.logger')
local persistence = require('aqo.utils.persistence')
local timer = require('aqo.utils.timer')
local common = require('aqo.common')
local config = require('aqo.configuration')
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
    USEREGEN=false,
}
config.set_spell_set('standard')
mq.cmd('/squelch /stick mod 0')

-- All spells ID + Rank name
local spells = {
    ['shots']=common.get_spell('Claimed Shots') or {name=nil,id=nil}, -- 4x archery attacks + dmg buff to archery attacks for 18s, Marked Shots
    ['focused']=common.get_spell('Focused Whirlwind of Arrows') or {name=nil,id=nil}, -- 4x archery attacks, Focused Blizzard of Arrows
    ['composite']=common.get_spell('Composite Fusillade') or {name=nil,id=nil}, -- double bow shot and fire+ice nuke
    ['heart']=common.get_spell('Heartruin') or {name=nil,id=nil}, -- consume class 3 wood silver tip arrow, strong vs animal/humanoid, magic bow shot, Heartruin
    ['opener']=common.get_spell('Stealthy Shot') or {name=nil,id=nil}, -- consume class 3 wood silver tip arrow, strong bow shot opener, OOC only
    ['summer']=common.get_spell('Summer\'s Torrent') or {name=nil,id=nil}, -- fire + ice nuke, Summer's Sleet
    ['boon']=common.get_spell('Lunarflare boon') or {name=nil,id=nil}, -- 
    ['healtot']=common.get_spell('Desperate Geyser') or {name=nil,id=nil}, -- heal ToT, Desperate Meltwater, fast cast, long cd
    ['healtot2']=common.get_spell('Darkflow Spring') or {name=nil,id=nil}, -- heal ToT, Meltwater Spring, slow cast
    ['dot']=common.get_spell('Bloodbeetle Swarm') or {name=nil,id=nil}, -- main DoT
    ['dotds']=common.get_spell('Swarm of Bloodflies') or {name=nil,id=nil}, -- DoT + reverse DS, Swarm of Hyperboreads
    ['dmgbuff']=common.get_spell('Arbor Stalker\'s Enrichment') or {name=nil,id=nil}, -- inc base dmg of skill attacks, Arbor Stalker's Enrichment
    ['alliance']=common.get_spell('Arbor Stalker\'s Coalition') or {name=nil,id=nil},
    ['buffs']=common.get_spell('Shout of the Dusksage Stalker') or {name=nil,id=nil}, -- cloak of rimespurs, frostroar of the predator, strength of the arbor stalker, Shout of the Arbor Stalker
    -- Shout of the X Stalker Buffs
    ['cloak']=common.get_spell('Cloak of Bloodbarbs') or {name=nil,id=nil}, -- Cloak of Rimespurs
    ['predator']=common.get_spell('Bay of the Predator') or {name=nil,id=nil}, -- Frostroar of the Predator
    ['strength']=common.get_spell('Strength of the Dusksage Stalker') or {name=nil,id=nil}, -- Strength of the Arbor Stalker
    -- Unity AA Buffs
    ['protection']=common.get_spell('Protection of the Valley') or {name=nil,id=nil}, -- Protection of the Wakening Land
    ['eyes']=common.get_spell('Eyes of the Senshali') or {name=nil,id=nil}, -- Eyes of the Visionary
    ['hunt']=common.get_spell('Steeled by the Hunt') or {name=nil,id=nil}, -- Provoked by the Hunt
    ['coat']=common.get_spell('Moonthorn Coat') or {name=nil,id=nil}, -- Rimespur Coat
    -- Unity Azia only
    ['barrage']=common.get_spell('Devastating Barrage') or {name=nil,id=nil}, -- Devastating Velium
    -- Unity Beza only
    ['blades']=common.get_spell('Vociferous Blades') or {name=nil,id=nil}, -- Howling Blades
    ['ds']=common.get_spell('Shield of Shadethorns') or {name=nil,id=nil}, -- DS
    ['rune']=common.get_spell('Luclin\'s Darkfire Cloak') or {name=nil,id=nil}, -- self rune + debuff proc
    ['regen']=common.get_spell('Dusksage Stalker\'s Vigor') or {name=nil,id=nil}, -- regen
}
-- Pyroclastic Boon, 
for name,spell in pairs(spells) do
    if spell['name'] then
        logger.printf('[%s] Found spell: %s (%s)', name, spell['name'], spell['id'])
    else
        logger.printf('[%s] Could not find spell!', name)
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
table.insert(burnAAs, common.get_aa('Spire of the Pathfinders')) -- 7.5min CD
table.insert(burnAAs, common.get_aa('Auspice of the Hunter')) -- crit buff, 9min CD
table.insert(burnAAs, common.get_aa('Pack Hunt')) -- swarm pets, 15min CD
table.insert(burnAAs, common.get_aa('Empowered Blades')) -- melee dmg burn, 10min CD
table.insert(burnAAs, common.get_aa('Guardian of the Forest')) -- base dmg, atk, overhaste, 6min CD
table.insert(burnAAs, common.get_aa('Group Guardian of the Forest')) -- base dmg, atk, overhaste, 10min CD
table.insert(burnAAs, common.get_aa('Outrider\'s Accuracy')) -- base dmg, accuracy, atk, crit dmg, 5min CD
table.insert(burnAAs, common.get_aa('Imbued Ferocity')) -- 100% wep proc chance, 8min CD
table.insert(burnAAs, common.get_aa('Silent Strikes')) -- silent casting
table.insert(burnAAs, common.get_aa('Scarlet Cheetah\'s Fang')) -- does what?, 20min CD

local meleeBurnDiscs = {}
table.insert(meleeBurnDiscs, common.get_disc('Dusksage Stalker\'s Discipline')) -- melee dmg buff, 19.5min CD, timer 2, Arbor Stalker's Discipline
local rangedBurnDiscs = {}
table.insert(rangedBurnDiscs, common.get_disc('Pureshot Discipline')) -- bow dmg buff, 1hr7min CD, timer 2

local mashAAs = {}
table.insert(mashAAs, common.get_aa('Elemental Arrow')) -- inc dmg from fire+ice nukes, 1min CD

local mashDiscs = {}
table.insert(mashDiscs, common.get_disc('Jolting Roundhouse Kicks')) -- agro reducer kick, timer 9, procs synergy, Jolting Roundhouse Kicks
table.insert(mashDiscs, common.get_disc('Focused Blizzard of Blades')) -- 4x arrows, 12s CD, timer 6
table.insert(mashDiscs, common.get_disc('Reflexive Rimespurs')) -- 4x melee attacks + group HoT, 10min CD, timer 19
-- table.insert(mashDiscs, common.get_aa('Tempest of Blades')) -- frontal cone melee flurry, 12s CD

local mashAbilities = {}
table.insert(mashAbilities, 'Kick')

local dispel = common.get_aa('Entropy of Nature') -- dispel 9 slots
local snare = common.get_aa('Entrap')
local fade = common.get_aa('Cover Tracks')
local evasion = common.get_aa('Outrider\'s Evasion') -- 7min cd, 85% avoidance, 10% absorb
local brownies = common.get_aa('Bulwark of the Brownies') -- 10m cd, 4min buff procs 100% parry below 50% HP
local chameleon = common.get_aa('Chameleon\'s Gift') -- 5min cd, 3min buff procs hate reduction below 50% HP
local protection = common.get_aa('Protection of the Spirit Wolf') -- 20min cd, large rune
local unity_azia = common.get_aa('Wildstalker\'s Unity (Azia)')
--Slot 1: 	Devastating Barrage
--Slot 2: 	Steeled by the Hunt
--Slot 3: 	Protection of the Valley
--Slot 4: 	Eyes of the Senshali
--Slot 5: 	Moonthorn Coat
local unity_beza = common.get_aa('Wildstalker\'s Unity (Beza)')
--Slot 1: 	Vociferous Blades
--Slot 2: 	Steeled by the Hunt
--Slot 3: 	Protection of the Valley
--Slot 4: 	Eyes of the Senshali
--Slot 5: 	Moonthorn Coat
local poison = common.get_aa('Poison Arrows')
local fire = common.get_aa('Flaming Arrows')

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
    if settings.rng.USEREGEN ~= nil then OPTS.USEREGEN = settings.rng.USEREGEN end
end

rng.save_settings = function()
    persistence.store(SETTINGS_FILE, {common=config.get_all(), rng=OPTS})
end

local ranged_timer = timer:new(5)
rng.reset_class_timers = function()
    ranged_timer:reset(0)
end

local function get_ranged_combat_position(radius)
    if not ranged_timer:timer_expired() then return false end
    ranged_timer:reset()
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
        if mq.TLO.Navigation.PathLength(string.format('loc yxz %d %d %d', y_off, x_off, z_off))() < 150 then
            if mq.TLO.LineOfSight(string.format('%d,%d,%d:%d,%d,%d', y_off, x_off, z_off, mob_y, mob_x, mob_z))() then
                if mq.TLO.EverQuest.ValidLoc(string.format('%d %d %d', x_off, y_off, z_off))() then
                    local xtars = mq.TLO.SpawnCount(string.format('npc xtarhater loc %d %d %d radius 75', y_off, x_off, z_off))()
                    local allmobs = mq.TLO.SpawnCount(string.format('npc loc %d %d %d radius 75', y_off, x_off, z_off))()
                    if allmobs - xtars == 0 then
                        logger.printf('Found a valid location at %d %d %d', y_off, x_off, z_off)
                        mq.cmdf('/squelch /nav locyxz %d %d %d log=off', y_off, x_off, z_off)
                        mq.delay('1s', function() return mq.TLO.Navigation.Active() end)
                        mq.delay('5s', function() return not mq.TLO.Navigation.Active() end)
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- false invalid, true valid
---Determine whether the target is in front.
---@return boolean @Returns true if the spawn is in front, otherwise false.
local function check_mob_angle()
    local left = mq.TLO.Me.Heading.Degrees() - 45
    local right = mq.TLO.Me.Heading.Degrees() + 45
    local mob_heading = mq.TLO.Target.HeadingTo
    local direction_to_mob = nil
    if mob_heading then direction_to_mob = mob_heading.Degrees() end
    if not direction_to_mob then return false end
    -- switching from non-puller mode to puller mode, the camp may not be updated yet
    if left >= right then
        if direction_to_mob < left and direction_to_mob > right then return false end
    else
        if direction_to_mob < left or direction_to_mob > right then return false end
    end
    return true
end

local function attack_range()
    if state.get_assist_mob_id() == 0 or mq.TLO.Target.ID() ~= state.get_assist_mob_id() or not assist.should_assist() then
        if mq.TLO.Me.AutoFire() then mq.cmd('/autofire off') end
        return
    end
    local dist3d = mq.TLO.Target.Distance3D()
    if not mq.TLO.Target.LineOfSight() or (dist3d and dist3d < 35) then
        if not get_ranged_combat_position(40) then
            return false
        end
    end
    if mq.TLO.Navigation.Active() then
        mq.cmd('/squelch /nav stop')
    end
    if mq.TLO.Target() then
        if not check_mob_angle() then
            mq.cmd('/squelch /face fast')
        end
        if not mq.TLO.Me.AutoFire() then
            mq.cmd('/autofire on')
        end
    end
    return true
end

local function use_opener()
    if mq.TLO.Me.CombatState() == 'COMBAT' then return end
    if assist.should_assist() and state.get_assist_mob_id() > 0 and spells['opener']['name'] and mq.TLO.Me.SpellReady(spells['opener']['name'])() then
        common.cast(spells['opener']['name'], true)
    end
end

--[[
    1. marked shot -- apply debuff
    2. focused shot -- strongest arrow spell
    3. dicho -- strong arrow spell
    4. wildfire spam
]]--
local function find_next_spell()
    local tothp = mq.TLO.Me.TargetOfTarget.PctHPs()
    if tothp and mq.TLO.Target() and mq.TLO.Target.Type() == 'NPC' and mq.TLO.Me.TargetOfTarget() and tothp < 65 then
        for _,spell in ipairs(combat_heal_spells) do
            if common.is_spell_ready(spell) then
                return spell
            end
        end
    end
    for _,spell in ipairs(dot_spells) do
        if spell['name'] ~= spells['dot']['name'] or OPTS.USEDOT or (state.get_burn_active() and common.is_named(mq.TLO.Zone.ShortName(), mq.TLO.Target.CleanName())) or (config.get_burn_always() and common.is_named(mq.TLO.Zone.ShortName(), mq.TLO.Target.CleanName())) then
            if common.is_dot_ready(spell['id'], spell['name']) then
                return spell
            end
        end
    end
    for _,spell in ipairs(arrow_spells) do
        if common.is_spell_ready(spell) then
            return spell
        end
    end
    if OPTS.NUKE then
        for _,spell in ipairs(dd_spells) do
            if common.is_spell_ready(spell) then
                return spell
            end
        end
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

local function cycle_spells()
    if not mq.TLO.Me.Invis() then
        local cur_mode = config.get_mode()
        if (cur_mode:is_tank_mode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:is_assist_mode() and assist.should_assist()) or (cur_mode:is_manual_mode() and mq.TLO.Me.CombatState() == 'COMBAT') then
            local spell = find_next_spell()
            if spell then
                if mq.TLO.Spell(spell['name']).TargetType() == 'Single' then
                    common.cast(spell['name'], true)
                else
                    common.cast(spell['name'])
                end
                return true
            end
        end
    end
end

local function mash()
    local cur_mode = config.get_mode()
    if (cur_mode:is_tank_mode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:is_assist_mode() and assist.should_assist()) or (cur_mode:is_manual_mode() and mq.TLO.Me.CombatState() == 'COMBAT') then
    --if common.is_fighting() or assist.should_assist() then
        if OPTS.USEDISPEL and dispel and mq.TLO.Target.Beneficial() then
            common.use_aa(dispel)
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
        local maxdist = mq.TLO.Target.MaxRangeTo()
        if dist and maxdist and dist < maxdist then
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

-- fade -- cover tracks
-- evasion -- 7min cd, 30sec buff, avoidance
--local check_aggro_timer = timer:new(10)
local function check_aggro()
    if mq.TLO.Me.PctHPs() < 50 then
        common.use_aa(evasion)
    end
    --[[
    if OPTS.USEFADE and common.is_fighting() and mq.TLO.Target() then
        if mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID() or check_aggro_timer:timer_expired() then
            if mq.TLO.Me.PctAggro() >= 70 then
                common.use_aa(fade)
                check_aggro_timer:reset()
                mq.delay('1s')
                mq.cmd('/makemevis')
            end
        end
    end
    ]]--
end

local function missing_unity_buffs(name)
    local spell = mq.TLO.Spell(name)
    for i=1,spell.NumEffects() do
        local trigger_spell = spell.Trigger(i)
        if not mq.TLO.Me.Buff(trigger_spell.Name())() then return true end
    end
    return false
end

local function spawn_missing_cachedbuff(spawn, name)
    local spell = mq.TLO.Spell(name)
    -- skip 470 for now
    if spell.HasSPA(374)() then
        for i=1,spell.NumEffects() do
            local trigger_spell = spell.Trigger(i)
            if not spawn.CachedBuff(trigger_spell.Name())() and spell.StacksSpawn(spawn.ID())() then return true end
        end
    else
        if not spawn.CachedBuff(name)() and spell.StacksSpawn(spawn.ID())() then return true end
    end
    return false
end

local function target_missing_buff(name)
    local spell = mq.TLO.Spell(name)
    if spell.HasSPA(374)() then
        for i=1,spell.NumEffects() do
            local trigger_spell = spell.Trigger(i)
            if not mq.TLO.Target.Buff(trigger_spell.Name())() and spell.StacksTarget() then return true end
        end
    else
        if not mq.TLO.Target.Buff(name)() and spell.StacksTarget() then return true end
    end
    return false
end

local group_buff_timer = timer:new(60)
local function check_buffs()
    if common.am_i_dead() then return end
    common.check_combat_buffs()
    if brownies and not mq.TLO.Me.Buff(brownies['name'])() then
        common.use_aa(brownies)
    end
    if chameleon and not mq.TLO.Me.Song(chameleon['name'])() and mq.TLO.Me.AltAbilityReady(chameleon['name'])() then
        mq.cmd('/mqtar myself')
        mq.delay(100, function() return mq.TLO.Target.ID() == mq.TLO.Me.ID() end)
        common.use_aa(chameleon)
    end
    if not common.clear_to_buff() or mq.TLO.Me.AutoFire() then return end
    --if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.get_camp_radius()))() > 0 then return end

    if OPTS.USEPOISONARROW then
        if poison and not mq.TLO.Me.Buff('Poison Arrows')() then
            if common.use_aa(poison) then return end
        end
    elseif OPTS.USEFIREARROW then
        if fire and not mq.TLO.Me.Buff('Fire Arrows')() then
            if common.use_aa(fire) then return end
        end
    end

    common.check_item_buffs()

    -- ranger unity aa
    if unity_azia and OPTS.USEUNITYAZIA then
        if missing_unity_buffs(unity_azia['name']) then
            if common.use_aa(unity_azia) then return end
        end
    elseif unity_beza and OPTS.USEUNITYBEZA then
        if missing_unity_buffs(unity_beza['name']) then
            if common.use_aa(unity_beza) then return end
        end
    end

    if spells['dmgbuff']['name'] and not mq.TLO.Me.Buff(spells['dmgbuff']['name'])() then
        if common.cast(spells['dmgbuff']['name']) then return end
    end

    if spells['rune']['name'] and not mq.TLO.Me.Buff(spells['rune']['name'])() then
        if common.cast(spells['rune']['name']) then return end
    end

    if OPTS.USEREGEN and spells['regen']['name'] and not mq.TLO.Me.Buff(spells['regen']['name'])() then
        mq.cmdf('/mqtarget %s', mq.TLO.Me.CleanName())
        mq.delay(500)
        if common.swap_and_cast(spells['regen'], 13) then return end
    end

    if OPTS.DSTANK then
        if mq.TLO.Group.MainTank() then
            local tank_spawn = mq.TLO.Group.MainTank.Spawn
            if tank_spawn() then
                if spawn_missing_cachedbuff(tank_spawn, spells['ds']['name']) then
                    tank_spawn.DoTarget()
                    mq.delay('1s') -- time to target and for buffs to be populated
                    if target_missing_buff(spells['ds']['name']) then
                        if common.swap_and_cast(spells['ds'], 13) then return end
                    end
                end
            end
        end
    end
    if OPTS.BUFFGROUP and group_buff_timer:timer_expired() then
        if mq.TLO.Group.Members() then
            for i=1,mq.TLO.Group.Members() do
                local group_member = mq.TLO.Group.Member(i).Spawn
                if group_member() and group_member.Class.ShortName() ~= 'RNG' then
                    if spells['buffs']['name'] and spawn_missing_cachedbuff(group_member, spells['buffs']['name']) and not group_member.CachedBuff('Spiritual Vigor')() then
                        group_member.DoTarget()
                        mq.delay('1s') -- time to target and for buffs to be populated
                        if target_missing_buff(spells['buffs']['name']) and not mq.TLO.Target.Buff('Spiritual Vigor')() then
                            -- extra dumb check for spiritual vigor since it seems to be checking stacking against lower level spell
                            if common.cast(spells['buffs']['name']) then return end
                        end
                    end
                    if spells['dmgbuff']['name'] and spawn_missing_cachedbuff(group_member, spells['dmgbuff']['name']) then
                        group_member.DoTarget()
                        mq.delay('1s') -- time to target and for buffs to be populated
                        if target_missing_buff(spells['dmgbuff']['name']) then
                            if common.cast(spells['dmgbuff']['name']) then return end
                        end
                    end
                end
            end
        end
        group_buff_timer:reset()
    end
end

local composite_names = {['Composite Fusillade']=true,['Dissident Fusillade']=true,['Dichotomic Fusillade']=true}
local check_spell_timer = timer:new(30)
local function check_spell_set()
    if not common.clear_to_buff() or mq.TLO.Me.Moving() or common.am_i_dead() or OPTS.BYOS then return end
    if state.get_spellset_loaded() ~= config.get_spell_set() or check_spell_timer:timer_expired() then
        if config.get_spell_set() == 'standard' then
            common.swap_spell(spells['shots'], 1)
            common.swap_spell(spells['focused'], 2)
            common.swap_spell(spells['composite'], 3, composite_names)
            common.swap_spell(spells['heart'], 4)
            common.swap_spell(spells['opener'], 5)
            common.swap_spell(spells['summer'], 6)
            common.swap_spell(spells['healtot'], 7)
            common.swap_spell(spells['rune'], 8)
            common.swap_spell(spells['dot'], 9)
            common.swap_spell(spells['dotds'], 10)
            common.swap_spell(spells['dmgbuff'], 12)
            common.swap_spell(spells['buffs'], 13)
            state.set_spellset_loaded(config.get_spell_set())
        end
        check_spell_timer:reset()
    end
end

rng.setup_events = function()
    -- no-op
end

rng.process_cmd = function(opt, new_value)
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

rng.main_loop = function()
    -- ensure correct spells are loaded based on selected spell set
    check_spell_set()
    -- check whether we need to return to camp
    camp.check_camp()
    -- check whether we need to go chasing after the chase target
    common.check_chase()
    camp.mob_radar()
    assist.check_target(rng.reset_class_timers)
    use_opener()
    -- if we should be assisting but aren't in los, try to be?
    if not OPTS.USERANGE or not attack_range() then
        if OPTS.USEMELEE then assist.attack() end
    end
    -- begin actual combat stuff
    assist.send_pet()
    --if mq.TLO.Me.CombatState() ~= 'ACTIVE' and mq.TLO.Me.CombatState() ~= 'RESTING' then
    if mq.TLO.Me.CombatState() == 'COMBAT' then
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
end

rng.draw_skills_tab = function()
    OPTS.USEUNITYAZIA = ui.draw_check_box('Use Unity (Azia)', '##useazia', OPTS.USEUNITYAZIA, 'Use Azia Unity Buff')
    if OPTS.USEUNITYAZIA then OPTS.USEUNITYBEZA = false end
    OPTS.USEUNITYBEZA = ui.draw_check_box('Use Unity (Beza)', '##usebeza', OPTS.USEUNITYBEZA, 'Use Beza Unity Buff')
    if OPTS.USEUNITYBEZA then OPTS.USEUNITYAZIA = false end
    OPTS.USEMELEE = ui.draw_check_box('Use Melee', '##usemelee', OPTS.USEMELEE, 'Melee DPS if ranged is disabled or not enough room')
    OPTS.USERANGE = ui.draw_check_box('Use Ranged', '##userange', OPTS.USERANGE, 'Ranged DPS if possible')
    OPTS.NUKE = ui.draw_check_box('Use Nukes', '##nuke', OPTS.NUKE, 'Cast nukes on all mobs')
    OPTS.USEDOT = ui.draw_check_box('Use DoT', '##usedot', OPTS.USEDOT, 'Cast expensive DoT on all mobs')
    OPTS.USEPOISONARROW = ui.draw_check_box('Use Poison Arrow', '##usepoison', OPTS.USEPOISONARROW, 'Use Poison Arrows AA')
    if OPTS.USEPOISONARROW then OPTS.USEFIREARROW = false end
    OPTS.USEFIREARROW = ui.draw_check_box('Use Fire Arrow', '##usefire', OPTS.USEFIREARROW, 'Use Fire Arrows AA')
    if OPTS.USEFIREARROW then OPTS.USEPOISONARROW = false end
    OPTS.BUFFGROUP = ui.draw_check_box('Buff Group', '##buffgroup', OPTS.BUFFGROUP, 'Buff group members')
    OPTS.DSTANK = ui.draw_check_box('DS Tank', '##dstank', OPTS.DSTANK, 'DS Tank')
    OPTS.USEDISPEL = ui.draw_check_box('Use Dispel', '##dispel', OPTS.USEDISPEL, 'Dispel mobs with Entropy AA')
    OPTS.USEREGEN = ui.draw_check_box('Use Regen', '##regen', OPTS.USEREGEN, 'Buff regen on self')
end

rng.draw_burn_tab = function()
    config.set_burn_always(ui.draw_check_box('Burn Always', '##burnalways', config.get_burn_always(), 'Always be burning'))
    config.set_burn_all_named(ui.draw_check_box('Burn Named', '##burnnamed', config.get_burn_all_named(), 'Burn all named'))
    config.set_burn_percent(ui.draw_input_int('Burn Percent', '##burnpct', config.get_burn_percent(), 'Percent health to begin burns'))
    config.set_burn_count(ui.draw_input_int('Burn Count', '##burncnt', config.get_burn_count(), 'Trigger burns if this many mobs are on aggro'))

end

return rng