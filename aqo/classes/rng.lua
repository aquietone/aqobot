--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local assist = require('routines.assist')
local camp = require('routines.camp')
local movement = require('routines.movement')
local logger = require('utils.logger')
local timer = require('utils.timer')
local common = require('common')
local config = require('configuration')
local state = require('state')

mq.cmd('/squelch /stick mod 0')

class.class = 'rng'
class.classOrder = {'assist', 'cast', 'mash', 'burn', 'heal', 'aggro', 'recover', 'buff', 'rest'}

class.SPELLSETS = {standard=1}

class.addCommonOptions()
class.addCommonAbilities()
class.addOption('USEUNITYAZIA', 'Use Unity (Azia)', true, nil, 'Use Azia Unity Buff', 'checkbox', 'USEUNITYBEZA')
class.addOption('USEUNITYBEZA', 'Use Unity (Beza)', false, nil, 'Use Beza Unity Buff', 'checkbox', 'USEUNITYAZIA')
class.addOption('USERANGE', 'Use Ranged', true, nil, 'Ranged DPS if possible', 'checkbox')
class.addOption('USEMELEE', 'Use Melee', true, nil, 'Melee DPS if ranged is disabled or not enough room', 'checkbox')
class.addOption('USEDOT', 'Use DoTs', false, nil, 'Cast expensive DoT on all mobs', 'checkbox')
class.addOption('USEPOISONARROW', 'Use Poison Arrow', true, nil, 'Use Poison Arrows AA', 'checkbox', 'USEFIREARROW')
class.addOption('USEFIREARROW', 'Use Fire Arrow', false, nil, 'Use Fire Arrows AA', 'checkbox', 'USEPOISONARROW')
class.addOption('BUFFGROUP', 'Buff Group', false, nil, 'Buff group members', 'checkbox')
class.addOption('DSTANK', 'DS Tank', false, nil, 'DS Tank', 'checkbox')
class.addOption('USENUKES', 'Use Nukes', false, nil, 'Cast nukes on all mobs', 'checkbox')
class.addOption('USEDISPEL', 'Use Dispel', true, nil, 'Dispel mobs with Entropy AA', 'checkbox')
class.addOption('USEREGEN', 'Use Regen', false, nil, 'Buff regen on self', 'checkbox')
class.addOption('USECOMPOSITE', 'Use Composite', true, nil, 'Cast composite as its available', 'checkbox')
class.addOption('USESNARE', 'Use Snare', true, nil, 'Cast snare on mobs', 'checkbox')

class.addSpell('shots', {'Claimed Shots'}) -- 4x archery attacks + dmg buff to archery attacks for 18s, Marked Shots
class.addSpell('focused', {'Focused Whirlwind of Arrows', 'Focused Hail of Arrows'})--, 'Hail of Arrows'}) -- 4x archery attacks, Focused Blizzard of Arrows
class.addSpell('composite', {'Composite Fusillade'}) -- double bow shot and fire+ice nuke
class.addSpell('heart', {'Heartruin', 'Heartslit', 'Heartshot'}) -- consume class 3 wood silver tip arrow, strong vs animal/humanoid, magic bow shot, Heartruin
class.addSpell('opener', {'Stealthy Shot'}) -- consume class 3 wood silver tip arrow, strong bow shot opener, OOC only
class.addSpell('summer', {'Summer\'s Torrent', 'Scorched Earth', 'Hearth Embers', 'Sylvan Burn', 'Icewind'}) -- fire + ice nuke, Summer's Sleet
class.addSpell('boon', {'Lunarflare boon', 'Ancient: North Wind'}) -- 
class.addSpell('healtot', {'Desperate Geyser'}) -- heal ToT, Desperate Meltwater, fast cast, long cd
class.addSpell('healtot2', {'Darkflow Spring'}) -- heal ToT, Meltwater Spring, slow cast
class.addSpell('dot', {'Bloodbeetle Swarm', 'Locust Swarm', 'Flame Lick'}) -- main DoT
class.addSpell('dotds', {'Swarm of Bloodflies'}) -- DoT + reverse DS, Swarm of Hyperboreads
class.addSpell('dmgbuff', {'Arbor Stalker\'s Enrichment'}) -- inc base dmg of skill attacks, Arbor Stalker's Enrichment
class.addSpell('alliance', {'Arbor Stalker\'s Coalition'})
class.addSpell('buffs', {'Shout of the Dusksage Stalker'}) -- cloak of rimespurs, frostroar of the predator, strength of the arbor stalker, Shout of the Arbor Stalker
-- Shout of the X Stalker Buffs
class.addSpell('cloak', {'Cloak of Bloodbarbs'}) -- Cloak of Rimespurs
class.addSpell('predator', {'Bay of the Predator', 'Howl of the Predator', 'Spirit of the Predator'}) -- Frostroar of the Predator
class.addSpell('strength', {'Strength of the Dusksage Stalker', 'Strength of the Hunter', 'Strength of Tunare'}) -- Strength of the Arbor Stalker
-- Unity AA Buffs
class.addSpell('protection', {'Protection of the Valley', 'Ward of the Hunter', 'Protection of the Wild'}) -- Protection of the Wakening Land
class.addSpell('eyes', {'Eyes of the Senshali', 'Eyes of the Hawk', 'Eyes of the Owl'}) -- Eyes of the Visionary
class.addSpell('hunt', {'Steeled by the Hunt'}) -- Provoked by the Hunt
class.addSpell('coat', {'Moonthorn Coat'}) -- Rimespur Coat
-- Unity Azia only
class.addSpell('barrage', {'Devastating Barrage'}) -- Devastating Velium
-- Unity Beza only
class.addSpell('blades', {'Vociferous Blades', 'Call of Lightning', 'Sylvan Call'}) -- Howling Blades
class.addSpell('ds', {'Shield of Shadethorns'}) -- DS
class.addSpell('rune', {'Luclin\'s Darkfire Cloak'}) -- self rune + debuff proc
class.addSpell('regen', {'Dusksage Stalker\'s Vigor'}) -- regen
class.addSpell('snare', {'Ensnare', 'Snare'})
class.addSpell('dispel', {'Nature\'s Balance'})

-- entries in the dd_spells table are pairs of {spell id, spell name} in priority order
local arrow_spells = {}
table.insert(arrow_spells, class.spells.shots)
table.insert(arrow_spells, class.spells.focused)
table.insert(arrow_spells, class.spells.composite)
table.insert(arrow_spells, class.spells.heart)
local dd_spells = {}
table.insert(dd_spells, class.spells.boon)
table.insert(dd_spells, class.spells.summer)

-- entries in the dot_spells table are pairs of {spell id, spell name} in priority order
local dot_spells = {}
table.insert(dot_spells, class.spells.dot)
table.insert(dot_spells, class.spells.dotds)

-- entries in the combat_heal_spells table are pairs of {spell id, spell name} in priority order
local combat_heal_spells = {}
table.insert(combat_heal_spells, class.spells.healtot)
--table.insert(combat_heal_spells, spells.healtot2) -- replacing in main spell lineup with self rune buff

-- entries in the items table are MQ item datatypes
table.insert(class.DPSAbilities, common.getItem(mq.TLO.InvSlot('Chest').Item.Name()))
table.insert(class.burnAbilities, common.getItem('Rage of Rolfron'))
table.insert(class.burnAbilities, common.getItem('Blood Drinker\'s Coating'))

-- entries in the AAs table are pairs of {aa name, aa id}
if state.emu then
    table.insert(class.burnAbilities, common.getAA('Fundament: Third Spire of the Pathfinders'))
else
    table.insert(class.burnAbilities, common.getAA('Spire of the Pathfinders')) -- 7.5min CD
end
table.insert(class.burnAbilities, common.getAA('Auspice of the Hunter')) -- crit buff, 9min CD
table.insert(class.burnAbilities, common.getAA('Pack Hunt')) -- swarm pets, 15min CD
table.insert(class.burnAbilities, common.getAA('Empowered Blades')) -- melee dmg burn, 10min CD
table.insert(class.burnAbilities, common.getAA('Guardian of the Forest')) -- base dmg, atk, overhaste, 6min CD
table.insert(class.burnAbilities, common.getAA('Group Guardian of the Forest')) -- base dmg, atk, overhaste, 10min CD
table.insert(class.burnAbilities, common.getAA('Outrider\'s Accuracy')) -- base dmg, accuracy, atk, crit dmg, 5min CD
table.insert(class.burnAbilities, common.getAA('Imbued Ferocity')) -- 100% wep proc chance, 8min CD
table.insert(class.burnAbilities, common.getAA('Silent Strikes')) -- silent casting
table.insert(class.burnAbilities, common.getAA('Scarlet Cheetah\'s Fang')) -- does what?, 20min CD

local meleeBurnDiscs = {}
table.insert(meleeBurnDiscs, common.getBestDisc({'Dusksage Stalker\'s Discipline'})) -- melee dmg buff, 19.5min CD, timer 2, Arbor Stalker's Discipline
local rangedBurnDiscs = {}
table.insert(rangedBurnDiscs, common.getBestDisc({'Pureshot Discipline'})) -- bow dmg buff, 1hr7min CD, timer 2

local mashAAs = {}
table.insert(class.DPSAbilities, common.getAA({'Elemental Arrow'})) -- inc dmg from fire+ice nukes, 1min CD

local mashDiscs = {}
table.insert(class.DPSAbilities, common.getBestDisc({'Jolting Roundhouse Kicks'})) -- agro reducer kick, timer 9, procs synergy, Jolting Roundhouse Kicks
table.insert(class.DPSAbilities, common.getBestDisc({'Focused Blizzard of Blades'})) -- 4x arrows, 12s CD, timer 6
table.insert(class.DPSAbilities, common.getBestDisc({'Reflexive Rimespurs'})) -- 4x melee attacks + group HoT, 10min CD, timer 19
-- table.insert(mashDiscs, common.getAA('Tempest of Blades')) -- frontal cone melee flurry, 12s CD

table.insert(class.DPSAbilities, common.getSkill('Kick'))

local dispel = common.getAA('Entropy of Nature') or class.spells.dispel -- dispel 9 slots
local snare = common.getAA('Entrap')
local fade = common.getAA('Cover Tracks')
local evasion = common.getAA('Outrider\'s Evasion') -- 7min cd, 85% avoidance, 10% absorb
table.insert(class.selfBuffs, common.getAA('Outrider\'s Evasion'))
local brownies = common.getAA('Bulwark of the Brownies') -- 10m cd, 4min buff procs 100% parry below 50% HP
table.insert(class.selfBuffs, common.getAA('Bulwark of the Brownies'))
local chameleon = common.getAA('Chameleon\'s Gift') -- 5min cd, 3min buff procs hate reduction below 50% HP
table.insert(class.selfBuffs, common.getAA('Chameleon\'s Gift'))
local protection = common.getAA('Protection of the Spirit Wolf') -- 20min cd, large rune
local unity_azia = common.getAA('Wildstalker\'s Unity (Azia)')
--Slot 1: 	Devastating Barrage
--Slot 2: 	Steeled by the Hunt
--Slot 3: 	Protection of the Valley
--Slot 4: 	Eyes of the Senshali
--Slot 5: 	Moonthorn Coat
if state.emu then
    class.addSpell('heal', {'Sylvan Water', 'Sylvan Light'})
    table.insert(class.selfBuffs, class.spells.eyes)
    table.insert(class.selfBuffs, class.spells.protection)
    table.insert(class.selfBuffs, class.spells.blades)
    table.insert(class.selfBuffs, class.spells.predator)
    --table.insert(class.selfBuffs, class.spells.strength)
    table.insert(class.combatBuffs, common.getBestDisc({'Trueshot Discipline'}))
    table.insert(class.healAbilities, class.spells.heal)
    table.insert(class.selfBuffs, class.spells.buffs)
else
    table.insert(class.selfBuffs, common.getAA('Wildstalker\'s Unity (Azia)', {opt='USEUNITYAZIA', checkfor='Devastating Barrage'}))
    table.insert(class.selfBuffs, common.getAA('Wildstalker\'s Unity (Beza)', {opt='USEUNITYBEZA', checkfor='Vociferous Blades'}))
    table.insert(class.selfBuffs, class.spells.rune)
end
local unity_beza = common.getAA('Wildstalker\'s Unity (Beza)')
--Slot 1: 	Vociferous Blades
--Slot 2: 	Steeled by the Hunt
--Slot 3: 	Protection of the Valley
--Slot 4: 	Eyes of the Senshali
--Slot 5: 	Moonthorn Coat
local poison = common.getAA('Poison Arrows')
table.insert(class.selfBuffs, common.getAA('Poison Arrows', {opt='USEPOISONARROW'}))
local fire = common.getAA('Flaming Arrows')
table.insert(class.selfBuffs, common.getAA('Flaming Arrows', {opt='USEFIREARROW'}))

table.insert(class.selfBuffs, class.spells.dmgbuff)

class.addRequestAlias(class.spells.predator, 'predator')
class.addRequestAlias(class.spells.strength, 'strength')

local ranged_timer = timer:new(5)
class.reset_class_timers = function()
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
                        print(logger.logLine('Found a valid location at %d %d %d', y_off, x_off, z_off))
                        movement.navToLoc(x_off, y_off, z_off, nil, 5000)
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
    if mq.TLO.Navigation.Active() then mq.cmd('/squelch /nav stop') end
    if not state.emu then
        if not mq.TLO.Target.LineOfSight() or (dist3d and dist3d < 35) then
            if not get_ranged_combat_position(40) then
                return false
            end
        end
    else
        local maxRangeTo = mq.TLO.Target.MaxRangeTo() or 0
        --mq.cmdf('/squelch /stick hold moveback behind %s uw', math.min(maxRangeTo*.75, 25))
        mq.cmdf('/squelch /stick snaproll moveback behind %s uw', math.min(maxRangeTo*.75, 25))
    end
    --movement.stop()
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
    if mq.TLO.Me.CombatState() == 'COMBAT' or not class.spells.opener then return end
    if assist.should_assist() and state.assist_mob_id > 0 and class.spells.opener.name and mq.TLO.Me.SpellReady(class.spells.opener.name)() then
        class.spells.opener:use()
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
        if spell.name ~= class.spells.dot.name or class.OPTS.USEDOT.value or (state.burn_active and common.is_named(mq.TLO.Zone.ShortName(), mq.TLO.Target.CleanName())) or (config.BURNALWAYS and common.is_named(mq.TLO.Zone.ShortName(), mq.TLO.Target.CleanName())) then
            if common.is_spell_ready(spell) then
                return spell
            end
        end
    end
    for _,spell in ipairs(arrow_spells) do
        if not class.spells.composite or spell.name ~= class.spells.composite.name or class.OPTS.USECOMPOSITE.value then
            if common.is_spell_ready(spell) then
                return spell
            end
        end
    end
    if class.OPTS.USENUKES.value then
        for _,spell in ipairs(dd_spells) do
            if common.is_spell_ready(spell) then
                return spell
            end
        end
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

local snared_id = 0
class.cast = function()
    if not state.loop.Invis and mq.TLO.Me.CombatState() == 'COMBAT' then
        if assist.is_fighting() then
            if mq.TLO.Target.ID() ~= snared_id and not mq.TLO.Target.Snared() and class.OPTS.USESNARE.value then
                class.spells.snare:use()
                snared_id = mq.TLO.Target.ID()
                return true
            end
            for _,clicky in ipairs(class.castClickies) do
                if (clicky.duration > 0 and mq.TLO.Target.Buff(clicky.checkfor)()) or
                        (clicky.casttime >= 0 and mq.TLO.Me.Moving()) then
                    movement.stop()
                    if clicky:use() then return end
                end
            end
            local spell = find_next_spell()
            if spell then
                spell:use()
                return true
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
class.burn_class = function()
    if mq.TLO.Me.Combat() then
        for _,disc in ipairs(meleeBurnDiscs) do
            disc:use()
        end
    elseif mq.TLO.Me.AutoFire() then
        for _,disc in ipairs(rangedBurnDiscs) do
            disc:use()
        end
    end
end

-- fade -- cover tracks
-- evasion -- 7min cd, 30sec buff, avoidance
--local check_aggro_timer = timer:new(10)
class.aggro = function()
    if state.loop.PctHPs < 50 then
        if evasion then evasion:use() end
        if config.MODE:return_to_camp() then
            movement.navToLoc(camp.X, camp.Y, camp.Z)
        end
    end
    --[[
    if OPTS.USEFADE and common.is_fighting() and mq.TLO.Target() then
        if mq.TLO.Me.TargetOfTarget.ID() == state.loop.ID or check_aggro_timer:timer_expired() then
            if mq.TLO.Me.PctAggro() >= 70 then
                fade:use()
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
class.buff_classb = function()
    common.check_combat_buffs()
    if brownies and not mq.TLO.Me.Buff(brownies.name)() then
        brownies:use()
    end
    if chameleon and not mq.TLO.Me.Song(chameleon.name)() and mq.TLO.Me.AltAbilityReady(chameleon.name)() then
        mq.cmd('/mqtar myself')
        mq.delay(100, function() return mq.TLO.Target.ID() == state.loop.ID end)
        chameleon:use()
    end
    if not common.clear_to_buff() or mq.TLO.Me.AutoFire() then return end
    --if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.get_camp_radius()))() > 0 then return end

    if class.OPTS.USEPOISONARROW.value then
        if poison and not mq.TLO.Me.Buff('Poison Arrows')() then
            if poison:use() then return end
        end
    elseif class.OPTS.USEFIREARROW.value then
        if fire and not mq.TLO.Me.Buff('Fire Arrows')() then
            if fire:use() then return end
        end
    end

    common.check_item_buffs()

    -- ranger unity aa
    if unity_azia and class.OPTS.USEUNITYAZIA.value then
        if missing_unity_buffs(unity_azia.name) then
            if unity_azia:use() then return end
        end
    elseif unity_beza and class.OPTS.USEUNITYBEZA.value then
        if missing_unity_buffs(unity_beza.name) then
            if unity_beza:use() then return end
        end
    end

    if class.spells.dmgbuff and not mq.TLO.Me.Buff(class.spells.dmgbuff.name)() then
        if class.spells.dmgbuff:use() then return end
    end

    if class.spells.rune and not mq.TLO.Me.Buff(class.spells.rune.name)() then
        if class.spells.rune:use() then return end
    end

    if class.OPTS.USEREGEN.value and class.spells.regen and not mq.TLO.Me.Buff(class.spells.regen.name)() then
        mq.cmdf('/mqtarget %s', mq.TLO.Me.CleanName())
        mq.delay(500)
        if common.swap_and_cast(class.spells.regen, 13) then return end
    end

    if class.OPTS.DSTANK.value then
        if mq.TLO.Group.MainTank() then
            local tank_spawn = mq.TLO.Group.MainTank.Spawn
            if tank_spawn() then
                if class.spells.ds and spawn_missing_cachedbuff(tank_spawn, class.spells.ds.name) then
                    tank_spawn.DoTarget()
                    mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end) -- time to target and for buffs to be populated
                    if target_missing_buff(class.spells.ds.name) then
                        if common.swap_and_cast(class.spells.ds, 13) then return end
                    end
                end
            end
        end
    end
    if class.OPTS.BUFFGROUP.value and group_buff_timer:timer_expired() then
        if mq.TLO.Group.Members() then
            for i=1,mq.TLO.Group.Members() do
                local group_member = mq.TLO.Group.Member(i).Spawn
                if group_member() and group_member.Class.ShortName() ~= 'RNG' then
                    if class.spells.buffs and spawn_missing_cachedbuff(group_member, class.spells.buffs.name) and not group_member.CachedBuff('Spiritual Vigor')() then
                        group_member.DoTarget()
                        mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end) -- time to target and for buffs to be populated
                        if target_missing_buff(class.spells.buffs.name) and not mq.TLO.Target.Buff('Spiritual Vigor')() then
                            -- extra dumb check for spiritual vigor since it seems to be checking stacking against lower level spell
                            if class.spells.buffs:use() then return end
                        end
                    end
                    if class.spells.dmgbuff and spawn_missing_cachedbuff(group_member, class.spells.dmgbuff.name) then
                        group_member.DoTarget()
                        mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end) -- time to target and for buffs to be populated
                        if target_missing_buff(class.spells.dmgbuff.name) then
                            if class.spells.dmgbuff:use() then return end
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
class.check_spell_set = function()
    if not common.clear_to_buff() or mq.TLO.Me.Moving() or class.OPTS.BYOS.value then return end
    if state.spellset_loaded ~= class.OPTS.SPELLSET.value or check_spell_timer:timer_expired() then
        if class.OPTS.SPELLSET.value == 'standard' then
            common.swap_spell(class.spells.shots, 1)
            common.swap_spell(class.spells.focused, 2)
            common.swap_spell(class.spells.composite, 3, composite_names)
            common.swap_spell(class.spells.heart, 4)
            common.swap_spell(class.spells.opener, 5)
            common.swap_spell(class.spells.summer, 6)
            common.swap_spell(class.spells.healtot, 7)
            common.swap_spell(class.spells.rune, 8)
            common.swap_spell(class.spells.dot, 9)
            common.swap_spell(class.spells.dotds, 10)
            common.swap_spell(class.spells.dmgbuff, 12)
            common.swap_spell(class.spells.buffs, 13)
            state.spellset_loaded = class.OPTS.SPELLSET.value
        end
        check_spell_timer:reset()
    end
end

class.assist = function()
    if mq.TLO.Navigation.Active() then return end
    if config.MODE:is_assist_mode() then
        assist.check_target(class.reset_class_timers)
        use_opener()
        -- if we should be assisting but aren't in los, try to be?
        -- try to deal with ranger noobishness running out to ranged and dying
        if state.loop.PctHPs > 40 then
            if not class.OPTS.USERANGE.value or not attack_range() then
                if class.OPTS.USEMELEE.value then assist.attack() end
            end
        end
        assist.send_pet()
    end
end

return class