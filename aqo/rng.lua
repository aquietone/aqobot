--- @type mq
local mq = require 'mq'
local common = require('aqo.common')
local ui = require('aqo.ui')
local persistence = require('aqo.persistence')

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
}
common.OPTS.SPELLSET = 'standard'

-- All spells ID + Rank name
local spells = {
    ['shots']=common.get_spellid_and_rank('Marked Shots'), -- 4x archery attacks + dmg buff to archery attacks for 18s, Claimed Shots
    ['focused']=common.get_spellid_and_rank('Focused Blizzard of Arrows'), -- 4x archery attacks, Focused Whirlwind of Arrows
    ['composite']=common.get_spellid_and_rank('Dissident Fusillade'), -- double bow shot and fire+ice nuke
    ['heart']=common.get_spellid_and_rank('Heartsunder'), -- consume class 3 wood silver tip arrow, strong vs animal/humanoid, magic bow shot, Heartruin
    ['opener']=common.get_spellid_and_rank('Silent Shot'), -- consume class 3 wood silver tip arrow, strong bow shot opener, OOC only
    ['summer']=common.get_spellid_and_rank('Summer\'s Sleet'), -- fire + ice nuke, Summer's Torrent
    ['boon']=common.get_spellid_and_rank('Pyroclastic Boon'), -- 
    ['healtot']=common.get_spellid_and_rank('Desperate Meltwater'), -- heal ToT, Desperate Geyser
    ['healtot2']=common.get_spellid_and_rank('Meltwater Spring'), -- heal ToT, Darkwater Spring
    ['dot']=common.get_spellid_and_rank('Bloodbeetle Swarm'), -- main DoT
    ['dotds']=common.get_spellid_and_rank('Swarm of Hyperboreads'), -- DoT + reverse DS, Swarm of Bloodflies
    ['dmgbuff']=common.get_spellid_and_rank('Wildstalker\'s Enrichment'), -- inc base dmg of skill attacks, Arbor Stalker's Enrichment
    ['alliance']=common.get_spellid_and_rank('Arbor Stalker\'s Coalition'),
    ['buffs']=common.get_spellid_and_rank('Shout of the Arbor Stalker'), -- cloak of rimespurs, frostroar of the predator, strength of the arbor stalker, Shout of the Dusksage Stalker
    -- Shout of the X Stalker Buffs
    ['cloak']=common.get_spellid_and_rank('Cloak of Rimespurs'), -- Cloak of Bloodbarbs
    ['predator']=common.get_spellid_and_rank('Frostroar of the Predator'), -- Bay of the Predator
    ['strength']=common.get_spellid_and_rank('Strength of the Arbor Stalker'), -- Strength of the Dusksage Stalker
    -- Unity AA Buffs
    ['protection']=common.get_spellid_and_rank('Protection of the Wakening Land'), -- Protection of the Valley
    ['eyes']=common.get_spellid_and_rank('Eyes of the Visionary'), -- Eyes of the Senshali
    ['hunt']=common.get_spellid_and_rank('Provoked by the Hunt'), -- Steeled by the Hunt
    ['coat']=common.get_spellid_and_rank('Rimespur Coat'), -- Moonthorn Coat
    -- Unity Azia only
    ['barrage']=common.get_spellid_and_rank('Devastating Velium'), -- Devastating Barrage
    -- Unity Beza only
    ['blades']=common.get_spellid_and_rank('Howling Blades'), -- Vociferous Blades
}
-- Pyroclastic Boon, Lunarflare boon
for name,spell in pairs(spells) do
    if spell['name'] then
        common.printf('[%s] Found spell: %s (%s)', name, spell['name'], spell['id'])
    else
        common.printf('[%s] Could not find spell!', name)
    end
end

-- entries in the dd_spells table are pairs of {spell id, spell name} in priority order
local dd_spells = {}
table.insert(dd_spells, spells['shots'])
table.insert(dd_spells, spells['focused'])
table.insert(dd_spells, spells['composite'])
table.insert(dd_spells, spells['heart'])
table.insert(dd_spells, spells['summer'])

-- entries in the dot_spells table are pairs of {spell id, spell name} in priority order
local dot_spells = {}
table.insert(dot_spells, spells['dot'])
table.insert(dot_spells, spells['dotds'])

-- entries in the combat_heal_spells table are pairs of {spell id, spell name} in priority order
local combat_heal_spells = {}
table.insert(combat_heal_spells, spells['healtot'])
table.insert(combat_heal_spells, spells['healtot2'])

-- entries in the items table are MQ item datatypes
local items = {}
table.insert(items, mq.TLO.InvSlot('Chest').Item.ID())
table.insert(items, mq.TLO.FindItem('Rage of Rolfron').ID())

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
table.insert(meleeBurnDiscs, common.get_aaid_and_name('Arbor Stalker\'s Discipline')) -- melee dmg buff, 19.5min CD, timer 2, Dusksage Stalker's Discipline
local rangedBurnDiscs = {}
table.insert(rangedBurnDiscs, common.get_aaid_and_name('Pureshot Discipline')) -- bow dmg buff, 1hr7min CD, timer 2

local mashAAs = {}
table.insert(mashAAs, common.get_aaid_and_name('Elemental Arrow')) -- inc dmg from fire+ice nukes, 1min CD

local mashDiscs = {}
table.insert(mashDiscs, common.get_aaid_and_name('Jolting Axe Kicks')) -- agro reducer kick, timer 9, procs synergy, Jolting Roundhouse Kicks
table.insert(mashDiscs, common.get_aaid_and_name('Focused Gale of Blades')) -- 4x arrows, 12s CD, timer 6
table.insert(mashDiscs, common.get_aaid_and_name('Reflexive Nettlespears')) -- 4x melee attacks + group HoT, 10min CD, timer 19
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
    local settings = common.load_settings(SETTINGS_FILE)
    if not settings or not settings.rng then return end
    if settings.rng.USEUNITYAZIA ~= nil then OPTS.USEUNITYAZIA = settings.rng.USEUNITYAZIA end
    if settings.rng.USEUNITYBEZA ~= nil then OPTS.USEUNITYBEZA = settings.rng.USEUNITYBEZA end
    if settings.rng.USEMELEE ~= nil then OPTS.USEMELEE = settings.rng.USEMELEE end
    if settings.rng.USERANGE ~= nil then OPTS.USERANGE = settings.rng.USERANGE end
    if settings.rng.USEDOT ~= nil then OPTS.USEDOT = settings.rng.USEDOT end
    if settings.rng.USEPOISONARROW ~= nil then OPTS.USEPOISONARROW = settings.rng.USEPOISONARROW end
    if settings.rng.USEFIREARROW ~= nil then OPTS.USEFIREARROW = settings.rng.USEFIREARROW end
    if settings.rng.BUFFGROUP ~= nil then OPTS.USEFIREARROW = settings.rng.BUFFGROUP end
end

rng.save_settings = function()
    persistence.store(SETTINGS_FILE, {common=common.OPTS, rng=OPTS})
end

rng.reset_class_timers = function()
    -- no-op
end

local function get_ranged_combat_position(radius)
    local mob_x = mq.TLO.Spawn('id '..common.ASSIST_TARGET_ID).X()
    local mob_y = mq.TLO.Spawn('id '..common.ASSIST_TARGET_ID).Y()
    local mob_z = mq.TLO.Spawn('id '..common.ASSIST_TARGET_ID).Z()
    local degrees = mq.TLO.Spawn('id '..common.ASSIST_TARGET_ID).Heading.Degrees()
    if not mob_x or not mob_y or not mob_z or not degrees then return false end
    local my_heading = degrees - 10
    local base_radian = 10
    for i=1,36 do
        local x_move = math.cos(base_radian * i + my_heading)
        local y_move = math.sin(base_radian * i + my_heading)
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
    if common.ASSIST_TARGET_ID == 0 or mq.TLO.Target.ID() ~= common.ASSIST_TARGET_ID or not common.should_assist() then
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
    if not common.is_fighting() and common.ASSIST_TARGET_ID > 0 and common.should_assist() and mq.TLO.Me.SpellReady(spells['opener']['name'])() then
        common.cast(spells['opener']['name'], true, true)
    end
end

local function is_dot_ready(spellId, spellName)
    if mq.TLO.Spell(spellName).Mana() > mq.TLO.Me.CurrentMana() or (mq.TLO.Spell(spellName).Mana() > 1000 and mq.TLO.Me.PctMana() < common.MIN_MANA) then
        return false
    end
    if mq.TLO.Spell(spellName).EnduranceCost() > mq.TLO.Me.CurrentEndurance() or (mq.TLO.Spell(spellName).EnduranceCost() > 1000 and mq.TLO.Me.PctEndurance() < common.MIN_END) then
        return false
    end
    if not mq.TLO.Target() or mq.TLO.Target.ID() ~= common.ASSIST_TARGET_ID or mq.TLO.Target.Type() == 'Corpse' then return false end

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
    if mq.TLO.Spell(spellName).Mana() > mq.TLO.Me.CurrentMana() or (mq.TLO.Spell(spellName).Mana() > 1000 and mq.TLO.Me.PctMana() < common.MIN_MANA) then
        return false
    end
    if mq.TLO.Spell(spellName).EnduranceCost() > mq.TLO.Me.CurrentEndurance() or (mq.TLO.Spell(spellName).EnduranceCost() > 1000 and mq.TLO.Me.PctEndurance() < common.MIN_END) then
        return false
    end
    if mq.TLO.Spell(spellName).TargetType() == 'Single' then
        if not mq.TLO.Target() or mq.TLO.Target.ID() ~= common.ASSIST_TARGET_ID or mq.TLO.Target.Type() == 'Corpse' then return false end
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
    for _,spell in ipairs(dot_spells) do
        if spell['name'] ~= spells['dot']['name'] or OPTS.USEDOT then
            if is_dot_ready(spell['id'], spell['name']) then
                return spell
            end
        end
    end
    for _,spell in ipairs(dd_spells) do
        if is_spell_ready(spell['id'], spell['name']) then
            return spell
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
    if common.is_fighting() or common.should_assist() then
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

        for _,item_id in ipairs(items) do
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
    if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', common.OPTS.CAMPRADIUS))() > 0 then return end

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
    if OPTS.BUFFGROUP and common.timer_expired(group_buff_timer, 60) then
        if mq.TLO.Group.Members() then
            for i=1,mq.TLO.Group.Members() do
                local group_member = mq.TLO.Group.Member(i).Spawn
                if group_member() then
                    if (not group_member.CachedBuff(spells['cloak']['name'])() and mq.TLO.Spell(spells['cloak']['name']).StacksSpawn(group_member.ID())) or
                            (not group_member.CachedBuff(spells['predator']['name'])() and mq.TLO.Spell(spells['predator']['name']).StacksSpawn(group_member.ID())) or
                            (not group_member.CachedBuff(spells['strength']['name'])() and mq.TLO.Spell(spells['strength']['name']).StacksSpawn(group_member.ID()) and not group_member.CachedBuff('Spiritual Vigor')()) then
                        group_member.DoTarget()
                        mq.delay(50) -- think target needs time to swap before trying to check buffspopulated so its not a stale true?
                        mq.delay('1s')
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
                        mq.delay(50) -- think target needs time to swap before trying to check buffspopulated so its not a stale true?
                        mq.delay('1s')
                        if (not mq.TLO.Target.Buff(spells['dmgbuff']['name'])() and mq.TLO.Spell(spells['dmgbuff']['name']).StacksTarget()) then
                            common.cast(spells['dmgbuff']['name'])
                            -- wait for GCD incase we move on to cast another right away
                            mq.delay('1.5s', function() return mq.TLO.Me.SpellReady(spells['buffs']['name'])() end)
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
    if common.SPELLSET_LOADED ~= common.OPTS.SPELLSET or common.timer_expired(check_spell_timer, 30) then
        if common.OPTS.SPELLSET == 'standard' then
            if mq.TLO.Me.Gem(1)() ~= spells['shots']['name'] then common.swap_spell(spells['shots']['name'], 1) end
            if mq.TLO.Me.Gem(2)() ~= spells['focused']['name'] then common.swap_spell(spells['focused']['name'], 2) end
            if mq.TLO.Me.Gem(3)() ~= 'Dissident Fusillade' then common.swap_spell(spells['composite']['name'], 3) end
            if mq.TLO.Me.Gem(4)() ~= spells['heart']['name'] then common.swap_spell(spells['heart']['name'], 4) end
            if mq.TLO.Me.Gem(5)() ~= spells['opener']['name'] then common.swap_spell(spells['opener']['name'], 5) end
            if mq.TLO.Me.Gem(6)() ~= spells['summer']['name'] then common.swap_spell(spells['summer']['name'], 6) end
            if mq.TLO.Me.Gem(7)() ~= spells['healtot']['name'] then common.swap_spell(spells['healtot']['name'], 7) end
            if mq.TLO.Me.Gem(8)() ~= spells['healtot2']['name'] then common.swap_spell(spells['healtot2']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['dot']['name'] then common.swap_spell(spells['dot']['name'], 9) end
            if mq.TLO.Me.Gem(10)() ~= spells['dotds']['name'] then common.swap_spell(spells['dotds']['name'], 10) end
            if mq.TLO.Me.Gem(12)() ~= spells['dmgbuff']['name'] then common.swap_spell(spells['dmgbuff']['name'], 12) end
            if mq.TLO.Me.Gem(13)() ~= spells['buffs']['name'] then common.swap_spell(spells['buffs']['name'], 13) end
            common.SPELLSET_LOADED = common.OPTS.SPELLSET
        end
        check_spell_timer = common.current_time()
    end
end

rng.setup_events = function()
    -- no-op
end

rng.process_cmd = function(opt, new_value)
    if new_value then
        if opt == 'SPELLSET' then
            if SPELLSETS[new_value] then
                common.printf('Setting %s to: %s', opt, new_value)
                common.OPTS[opt] = new_value
            end
        elseif opt == 'ASSIST' then
            if common.ASSISTS[new_value] then
                common.printf('Setting %s to: %s', opt, new_value)
                common.OPTS[opt] = new_value
            end
        elseif type(OPTS[opt]) == 'boolean' or type(common.OPTS[opt]) == 'boolean' then
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
            end
        else
            common.printf('Unsupported command line option: %s %s', opt, new_value)
        end
    else
        if OPTS[opt] ~= nil then
            common.printf('%s: %s', opt, OPTS[opt])
        elseif common.OPTS[opt] ~= nil then
            common.printf('%s: %s', opt, common.OPTS[opt])
        else
            common.printf('Unrecognized option: %s', opt)
        end
    end
end

rng.main_loop = function()
    -- ensure correct spells are loaded based on selected spell set
    check_spell_set()
    -- check whether we need to return to camp
    common.check_camp()
    -- check whether we need to go chasing after the chase target
    common.check_chase()
    common.check_target(rng.reset_class_timers)
    use_opener()
    -- if we should be assisting but aren't in los, try to be?
    if not OPTS.USERANGE or not attack_range() then
        if OPTS.USEMELEE then common.attack() end
    end
    -- begin actual combat stuff
    common.send_pet()
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
    common.OPTS.MODE = ui.draw_combo_box('Mode', common.OPTS.MODE, common.MODES)
    common.set_camp()
    common.OPTS.ASSIST = ui.draw_combo_box('Assist', common.OPTS.ASSIST, common.ASSISTS, true)
    common.OPTS.AUTOASSISTAT = ui.draw_input_int('Assist %', '##assistat', common.OPTS.AUTOASSISTAT, 'Percent HP to assist at')
    common.OPTS.CAMPRADIUS = ui.draw_input_int('Camp Radius', '##campradius', common.OPTS.CAMPRADIUS, 'Camp radius to assist within')
    common.OPTS.CHASETARGET = ui.draw_input_text('Chase Target', '##chasetarget',common. OPTS.CHASETARGET, 'Chase Target')
    common.OPTS.CHASEDISTANCE = ui.draw_input_int('Chase Distance', '##chasedist', common.OPTS.CHASEDISTANCE, 'Distance to follow chase target')
    common.OPTS.BURNPCT = ui.draw_input_int('Burn Percent', '##burnpct', common.OPTS.BURNPCT, 'Percent health to begin burns')
    common.OPTS.BURNCOUNT = ui.draw_input_int('Burn Count', '##burncnt', common.OPTS.BURNCOUNT, 'Trigger burns if this many mobs are on aggro')
end

rng.draw_right_panel = function()
    common.OPTS.BURNALWAYS = ui.draw_check_box('Burn Always', '##burnalways', common.OPTS.BURNALWAYS, 'Always be burning')
    ui.get_next_item_loc()
    common.OPTS.BURNALLNAMED = ui.draw_check_box('Burn Named', '##burnnamed', common.OPTS.BURNALLNAMED, 'Burn all named')
    ui.get_next_item_loc()
    --common.OPTS.USEALLIANCE = ui.draw_check_box('Alliance', '##alliance', common.OPTS.USEALLIANCE, 'Use alliance spell')
    common.OPTS.SWITCHWITHMA = ui.draw_check_box('Switch With MA', '##switchwithma', common.OPTS.SWITCHWITHMA, 'Switch targets with MA')
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
    OPTS.USEDOT = ui.draw_check_box('Use DoT', '##usedot', OPTS.USEDOT, 'Cast expensive DoT on all mobs')
    ui.get_next_item_loc()
    OPTS.USEPOISONARROW = ui.draw_check_box('Use Poison Arrow', '##usepoison', OPTS.USEPOISONARROW, 'Use Poison Arrows AA')
    if OPTS.USEPOISONARROW then OPTS.USEFIREARROW = false end
    ui.get_next_item_loc()
    OPTS.USEFIREARROW = ui.draw_check_box('Use Fire Arrow', '##usefire', OPTS.USEFIREARROW, 'Use Fire Arrows AA')
    if OPTS.USEFIREARROW then OPTS.USEPOISONARROW = false end
    OPTS.BUFFGROUP = ui.draw_check_box('Buff Group', '##buffgroup', OPTS.BUFFGROUP, 'Buff group members')
    ui.get_next_item_loc()
end

return rng