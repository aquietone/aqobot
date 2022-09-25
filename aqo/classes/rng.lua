--- @type Mq
local mq = require 'mq'
local baseclass = require('aqo.classes.base')
local assist = require('aqo.routines.assist')
local camp = require('aqo.routines.camp')
local logger = require('aqo.utils.logger')
local timer = require('aqo.utils.timer')
local common = require('aqo.common')
local config = require('aqo.configuration')
local state = require('aqo.state')

mq.cmd('/squelch /stick mod 0')

local rng = baseclass

rng.class = 'rng'
rng.classOrder = {'assist', 'cast', 'mash', 'burn', 'aggro', 'recover', 'buff', 'rest'}

rng.SPELLSETS = {standard=1}

--    if OPTS.USEUNITYAZIA then OPTS.USEUNITYBEZA = false end
--    if OPTS.USEUNITYBEZA then OPTS.USEUNITYAZIA = false end
--    if OPTS.USEPOISONARROW then OPTS.USEFIREARROW = false end
--    if OPTS.USEFIREARROW then OPTS.USEPOISONARROW = false end

rng.addOption('SPELLSET', 'Spell Set', 'standard', rng.SPELLSETS, nil, 'combobox')
rng.addOption('USEUNITYAZIA', 'Use Unity (Azia)', true, nil, 'Use Azia Unity Buff', 'checkbox')
rng.addOption('USEUNITYBEZA', 'Use Unity (Beza)', false, nil, 'Use Beza Unity Buff', 'checkbox')
rng.addOption('USERANGE', 'Use Melee', true, nil, 'Ranged DPS if possible', 'checkbox')
rng.addOption('USEMELEE', 'Use Ranged', true, nil, 'Melee DPS if ranged is disabled or not enough room', 'checkbox')
rng.addOption('USEDOT', 'Use Nukes', false, nil, 'Cast expensive DoT on all mobs', 'checkbox')
rng.addOption('USEPOISONARROW', 'Use DoT', true, nil, 'Use Poison Arrows AA', 'checkbox')
rng.addOption('USEFIREARROW', 'Use Composite', false, nil, 'Use Fire Arrows AA', 'checkbox')
rng.addOption('BUFFGROUP', 'Use Poison Arrow', false, nil, 'Buff group members', 'checkbox')
rng.addOption('DSTANK', 'Use Fire Arrow', false, nil, 'DS Tank', 'checkbox')
rng.addOption('NUKE', 'Buff Group', false, nil, 'Cast nukes on all mobs', 'checkbox')
rng.addOption('USEDISPEL', 'DS Tank', true, nil, 'Dispel mobs with Entropy AA', 'checkbox')
rng.addOption('USEREGEN', 'Use Dispel', false, nil, 'Buff regen on self', 'checkbox')
rng.addOption('USECOMPOSITE', 'Use Regen', true, nil, 'Cast composite as its available', 'checkbox')

rng.addSpell('shots', {'Claimed Shots'}) -- 4x archery attacks + dmg buff to archery attacks for 18s, Marked Shots
rng.addSpell('focused', {'Focused Whirlwind of Arrows'}) -- 4x archery attacks, Focused Blizzard of Arrows
rng.addSpell('composite', {'Composite Fusillade'}) -- double bow shot and fire+ice nuke
rng.addSpell('heart', {'Heartruin'}) -- consume class 3 wood silver tip arrow, strong vs animal/humanoid, magic bow shot, Heartruin
rng.addSpell('opener', {'Stealthy Shot'}) -- consume class 3 wood silver tip arrow, strong bow shot opener, OOC only
rng.addSpell('summer', {'Summer\'s Torrent'}) -- fire + ice nuke, Summer's Sleet
rng.addSpell('boon', {'Lunarflare boon'}) -- 
rng.addSpell('healtot', {'Desperate Geyser'}) -- heal ToT, Desperate Meltwater, fast cast, long cd
rng.addSpell('healtot2', {'Darkflow Spring'}) -- heal ToT, Meltwater Spring, slow cast
rng.addSpell('dot', {'Bloodbeetle Swarm'}) -- main DoT
rng.addSpell('dotds', {'Swarm of Bloodflies'}) -- DoT + reverse DS, Swarm of Hyperboreads
rng.addSpell('dmgbuff', {'Arbor Stalker\'s Enrichment'}) -- inc base dmg of skill attacks, Arbor Stalker's Enrichment
rng.addSpell('alliance', {'Arbor Stalker\'s Coalition'})
rng.addSpell('buffs', {'Shout of the Dusksage Stalker'}) -- cloak of rimespurs, frostroar of the predator, strength of the arbor stalker, Shout of the Arbor Stalker
-- Shout of the X Stalker Buffs
rng.addSpell('cloak', {'Cloak of Bloodbarbs'}) -- Cloak of Rimespurs
rng.addSpell('predator', {'Bay of the Predator'}) -- Frostroar of the Predator
rng.addSpell('strength', {'Strength of the Dusksage Stalker'}) -- Strength of the Arbor Stalker
-- Unity AA Buffs
rng.addSpell('protection', {'Protection of the Valley'}) -- Protection of the Wakening Land
rng.addSpell('eyes', {'Eyes of the Senshali'}) -- Eyes of the Visionary
rng.addSpell('hunt', {'Steeled by the Hunt'}) -- Provoked by the Hunt
rng.addSpell('coat', {'Moonthorn Coat'}) -- Rimespur Coat
-- Unity Azia only
rng.addSpell('barrage', {'Devastating Barrage'}) -- Devastating Velium
-- Unity Beza only
rng.addSpell('blades', {'Vociferous Blades'}) -- Howling Blades
rng.addSpell('ds', {'Shield of Shadethorns'}) -- DS
rng.addSpell('rune', {'Luclin\'s Darkfire Cloak'}) -- self rune + debuff proc
rng.addSpell('regen', {'Dusksage Stalker\'s Vigor'}) -- regen

-- entries in the dd_spells table are pairs of {spell id, spell name} in priority order
local arrow_spells = {}
table.insert(arrow_spells, rng.spells.shots)
table.insert(arrow_spells, rng.spells.focused)
table.insert(arrow_spells, rng.spells.composite)
table.insert(arrow_spells, rng.spells.heart)
local dd_spells = {}
table.insert(dd_spells, rng.spells.boon)
table.insert(dd_spells, rng.spells.summer)

-- entries in the dot_spells table are pairs of {spell id, spell name} in priority order
local dot_spells = {}
table.insert(dot_spells, rng.spells.dot)
table.insert(dot_spells, rng.spells.dotds)

-- entries in the combat_heal_spells table are pairs of {spell id, spell name} in priority order
local combat_heal_spells = {}
table.insert(combat_heal_spells, rng.spells.healtot)
--table.insert(combat_heal_spells, spells.healtot2) -- replacing in main spell lineup with self rune buff

-- entries in the items table are MQ item datatypes
table.insert(rng.burnAbilities, {id=mq.TLO.FindItem('Rage of Rolfron').ID(), type='item'})
table.insert(rng.burnAbilities, {id=mq.TLO.FindItem('Miniature Horn of Unity').ID(), type='item'})

table.insert(rng.dpsAbilities, {id=mq.TLO.InvSlot('Chest').Item.ID(), type='item'})

-- entries in the AAs table are pairs of {aa name, aa id}
table.insert(rng.burnAbilities, common.get_aa('Spire of the Pathfinders')) -- 7.5min CD
table.insert(rng.burnAbilities, common.get_aa('Auspice of the Hunter')) -- crit buff, 9min CD
table.insert(rng.burnAbilities, common.get_aa('Pack Hunt')) -- swarm pets, 15min CD
table.insert(rng.burnAbilities, common.get_aa('Empowered Blades')) -- melee dmg burn, 10min CD
table.insert(rng.burnAbilities, common.get_aa('Guardian of the Forest')) -- base dmg, atk, overhaste, 6min CD
table.insert(rng.burnAbilities, common.get_aa('Group Guardian of the Forest')) -- base dmg, atk, overhaste, 10min CD
table.insert(rng.burnAbilities, common.get_aa('Outrider\'s Accuracy')) -- base dmg, accuracy, atk, crit dmg, 5min CD
table.insert(rng.burnAbilities, common.get_aa('Imbued Ferocity')) -- 100% wep proc chance, 8min CD
table.insert(rng.burnAbilities, common.get_aa('Silent Strikes')) -- silent casting
table.insert(rng.burnAbilities, common.get_aa('Scarlet Cheetah\'s Fang')) -- does what?, 20min CD

local meleeBurnDiscs = {}
table.insert(meleeBurnDiscs, common.get_disc('Dusksage Stalker\'s Discipline')) -- melee dmg buff, 19.5min CD, timer 2, Arbor Stalker's Discipline
local rangedBurnDiscs = {}
table.insert(rangedBurnDiscs, common.get_disc('Pureshot Discipline')) -- bow dmg buff, 1hr7min CD, timer 2

local mashAAs = {}
table.insert(rng.dpsAbilities, common.get_aa('Elemental Arrow')) -- inc dmg from fire+ice nukes, 1min CD

local mashDiscs = {}
table.insert(rng.dpsAbilities, common.get_disc('Jolting Roundhouse Kicks')) -- agro reducer kick, timer 9, procs synergy, Jolting Roundhouse Kicks
table.insert(rng.dpsAbilities, common.get_disc('Focused Blizzard of Blades')) -- 4x arrows, 12s CD, timer 6
table.insert(rng.dpsAbilities, common.get_disc('Reflexive Rimespurs')) -- 4x melee attacks + group HoT, 10min CD, timer 19
-- table.insert(mashDiscs, common.get_aa('Tempest of Blades')) -- frontal cone melee flurry, 12s CD

table.insert(rng.dpsAbilities, {name='Kick', type='ability'})

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

local ranged_timer = timer:new(5)
rng.reset_class_timers = function()
    ranged_timer:reset(0)
end

local function get_ranged_combat_position(radius)
    if not ranged_timer:timer_expired() then return false end
    ranged_timer:reset()
    local assist_mob_id = state.assist_mob_id
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
                        mq.delay(1000, function() return mq.TLO.Navigation.Active() end)
                        mq.delay(5000, function() return not mq.TLO.Navigation.Active() end)
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
    if state.assist_mob_id == 0 or mq.TLO.Target.ID() ~= state.assist_mob_id or not assist.should_assist() then
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
    if assist.should_assist() and state.assist_mob_id > 0 and rng.spells.opener.name and mq.TLO.Me.SpellReady(rng.spells.opener.name)() then
        common.cast(rng.spells.opener.name, true)
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
        if spell.name ~= rng.spells.dot.name or rng.OPTS.USEDOT or (state.burn_active and common.is_named(mq.TLO.Zone.ShortName(), mq.TLO.Target.CleanName())) or (config.BURNALWAYS and common.is_named(mq.TLO.Zone.ShortName(), mq.TLO.Target.CleanName())) then
            if common.is_dot_ready(spell) then
                return spell
            end
        end
    end
    for _,spell in ipairs(arrow_spells) do
        if not rng.spells.composite.name or spell.name ~= rng.spells.composite.name or rng.OPTS.USECOMPOSITE then
            if common.is_spell_ready(spell) then
                return spell
            end
        end
    end
    if rng.OPTS.NUKE then
        for _,spell in ipairs(dd_spells) do
            if common.is_spell_ready(spell) then
                return spell
            end
        end
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

rng.cast = function()
    if not mq.TLO.Me.Invis() and mq.TLO.Me.CombatState() == 'COMBAT' then
        local cur_mode = config.MODE
        if (cur_mode:is_tank_mode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:is_assist_mode() and assist.should_assist()) or (cur_mode:is_manual_mode() and mq.TLO.Me.CombatState() == 'COMBAT') then
            local spell = find_next_spell()
            if spell then
                if mq.TLO.Spell(spell.name).TargetType() == 'Single' then
                    common.cast(spell.name, true)
                else
                    common.cast(spell.name)
                end
                return true
            end
        end
    end
end

rng.mash_class = function()
    if rng.OPTS.USEDISPEL and dispel and mq.TLO.Target.Beneficial() then
        common.use_aa(dispel)
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
rng.burn_class = function()
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

-- fade -- cover tracks
-- evasion -- 7min cd, 30sec buff, avoidance
--local check_aggro_timer = timer:new(10)
rng.aggro = function()
    if mq.TLO.Me.PctHPs() < 50 then
        common.use_aa(evasion)
        if config.MODE:return_to_camp() then
            mq.cmdf('/nav locyxz %d %d %d log=off', camp.Y, camp.X, camp.Z)
        end
    end
    --[[
    if OPTS.USEFADE and common.is_fighting() and mq.TLO.Target() then
        if mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID() or check_aggro_timer:timer_expired() then
            if mq.TLO.Me.PctAggro() >= 70 then
                common.use_aa(fade)
                check_aggro_timer:reset()
                mq.delay(1000)
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
rng.buffs = function()
    if common.am_i_dead() then return end
    common.check_combat_buffs()
    if brownies and not mq.TLO.Me.Buff(brownies.name)() then
        common.use_aa(brownies)
    end
    if chameleon and not mq.TLO.Me.Song(chameleon.name)() and mq.TLO.Me.AltAbilityReady(chameleon.name)() then
        mq.cmd('/mqtar myself')
        mq.delay(100, function() return mq.TLO.Target.ID() == mq.TLO.Me.ID() end)
        common.use_aa(chameleon)
    end
    if not common.clear_to_buff() or mq.TLO.Me.AutoFire() then return end
    --if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.get_camp_radius()))() > 0 then return end

    if rng.OPTS.USEPOISONARROW then
        if poison and not mq.TLO.Me.Buff('Poison Arrows')() then
            if common.use_aa(poison) then return end
        end
    elseif rng.OPTS.USEFIREARROW then
        if fire and not mq.TLO.Me.Buff('Fire Arrows')() then
            if common.use_aa(fire) then return end
        end
    end

    common.check_item_buffs()

    -- ranger unity aa
    if unity_azia and rng.OPTS.USEUNITYAZIA then
        if missing_unity_buffs(unity_azia.name) then
            if common.use_aa(unity_azia) then return end
        end
    elseif unity_beza and rng.OPTS.USEUNITYBEZA then
        if missing_unity_buffs(unity_beza.name) then
            if common.use_aa(unity_beza) then return end
        end
    end

    if rng.spells.dmgbuff.name and not mq.TLO.Me.Buff(rng.spells.dmgbuff.name)() then
        if common.cast(rng.spells.dmgbuff.name) then return end
    end

    if rng.spells.rune.name and not mq.TLO.Me.Buff(rng.spells.rune.name)() then
        if common.cast(rng.spells.rune.name) then return end
    end

    if rng.OPTS.USEREGEN and rng.spells.regen.name and not mq.TLO.Me.Buff(rng.spells.regen.name)() then
        mq.cmdf('/mqtarget %s', mq.TLO.Me.CleanName())
        mq.delay(500)
        if common.swap_and_cast(rng.spells.regen, 13) then return end
    end

    if rng.OPTS.DSTANK then
        if mq.TLO.Group.MainTank() then
            local tank_spawn = mq.TLO.Group.MainTank.Spawn
            if tank_spawn() then
                if spawn_missing_cachedbuff(tank_spawn, rng.spells.ds.name) then
                    tank_spawn.DoTarget()
                    mq.delay(1000) -- time to target and for buffs to be populated
                    if target_missing_buff(rng.spells.ds.name) then
                        if common.swap_and_cast(rng.spells.ds, 13) then return end
                    end
                end
            end
        end
    end
    if rng.OPTS.BUFFGROUP and group_buff_timer:timer_expired() then
        if mq.TLO.Group.Members() then
            for i=1,mq.TLO.Group.Members() do
                local group_member = mq.TLO.Group.Member(i).Spawn
                if group_member() and group_member.Class.ShortName() ~= 'RNG' then
                    if rng.spells.buffs.name and spawn_missing_cachedbuff(group_member, rng.spells.buffs.name) and not group_member.CachedBuff('Spiritual Vigor')() then
                        group_member.DoTarget()
                        mq.delay(1000) -- time to target and for buffs to be populated
                        if target_missing_buff(rng.spells.buffs.name) and not mq.TLO.Target.Buff('Spiritual Vigor')() then
                            -- extra dumb check for spiritual vigor since it seems to be checking stacking against lower level spell
                            if common.cast(rng.spells.buffs.name) then return end
                        end
                    end
                    if rng.spells.dmgbuff.name and spawn_missing_cachedbuff(group_member, rng.spells.dmgbuff.name) then
                        group_member.DoTarget()
                        mq.delay(1000) -- time to target and for buffs to be populated
                        if target_missing_buff(rng.spells.dmgbuff.name) then
                            if common.cast(rng.spells.dmgbuff.name) then return end
                        end
                    end
                end
            end
        end
        group_buff_timer:reset()
    end
end

local composite_names = {['Composite Fusillade']=true, ['Dissident Fusillade']=true, ['Dichotomic Fusillade']=true}
local check_spell_timer = timer:new(30)
rng.check_spell_set = function()
    if not common.clear_to_buff() or mq.TLO.Me.Moving() or common.am_i_dead() or rng.OPTS.BYOS then return end
    if state.spellset_loaded ~= config.SPELLSET or check_spell_timer:timer_expired() then
        if config.SPELLSET == 'standard' then
            common.swap_spell(rng.spells.shots, 1)
            common.swap_spell(rng.spells.focused, 2)
            common.swap_spell(rng.spells.composite, 3, composite_names)
            common.swap_spell(rng.spells.heart, 4)
            common.swap_spell(rng.spells.opener, 5)
            common.swap_spell(rng.spells.summer, 6)
            common.swap_spell(rng.spells.healtot, 7)
            common.swap_spell(rng.spells.rune, 8)
            common.swap_spell(rng.spells.dot, 9)
            common.swap_spell(rng.spells.dotds, 10)
            common.swap_spell(rng.spells.dmgbuff, 12)
            common.swap_spell(rng.spells.buffs, 13)
            state.spellset_loaded = config.SPELLSET
        end
        check_spell_timer:reset()
    end
end

rng.assist = function()
    assist.check_target(rng.reset_class_timers)
    use_opener()
    -- if we should be assisting but aren't in los, try to be?
    -- try to deal with ranger noobishness running out to ranged and dying
    if mq.TLO.Me.PctHPs() > 40 then
        if not rng.OPTS.USERANGE or not attack_range() then
            if rng.OPTS.USEMELEE then assist.attack() end
        end
    end
    assist.send_pet()
end

return rng