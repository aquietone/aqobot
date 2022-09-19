--- @type Mq
local mq = require 'mq'
local assist = require('aqo.routines.assist')
local camp = require('aqo.routines.camp')
local logger = require('aqo.utils.logger')
local persistence = require('aqo.utils.persistence')
local timer = require('aqo.utils.timer')
local common = require('aqo.common')
local config = require('aqo.configuration')
local mode = require('aqo.mode')
local state = require('aqo.state')
local ui = require('aqo.ui')

local nec = {}

local SPELLSETS = {standard=1,short=1}
local OPTS = {
    STOPPCT=0,
    DEBUFF=true, -- enable use of debuffs
    USEBUFFSHIELD=false,
    SUMMONPET=false,
    BUFFPET=true,
    USEMANATAP=false,
    USEREZ=true,
    USEFD=true,
    USEINSPIRE=true,
    USEDISPEL=true,
    BYOS=false,
    USEWOUNDS=true,
    MULTIDOT=false,
    MULTICOUNT=3,
    USEGLYPH=false,
    USEINTENSITY=false,
}
config.SPELLSET = 'standard'

-- All spells ID + Rank name
local spells = {
    composite=common.get_best_spell({'Composite Paroxysm', 'Dissident Paroxysm'}),
    wounds=common.get_best_spell({'Infected Wounds', 'Septic Wounds'}),
    fireshadow=common.get_best_spell({'Scalding Shadow', 'Broiling Shadow'}),
    pyreshort=common.get_best_spell({'Pyre of Va Xakra', 'Pyre of Klraggek'}),
    pyrelong=common.get_best_spell({'Pyre of the Neglected', 'Pyre of the Wretched'}),
    venom=common.get_best_spell({'Hemorrhagic Venom', 'Crystal Crawler Venom'}),
    magic=common.get_best_spell({'Extinction', 'Oblivion'}),
    decay=common.get_best_spell({'Fleshrot\'s Decay', 'Danvid\'s Decay'}),
    grip=common.get_best_spell({'Grip of Quietus', 'Grip of Zorglim'}),
    haze=common.get_best_spell({'Zelnithak\'s Pallid Haze', 'Drachnia\'s Pallid Haze'}),
    grasp=common.get_best_spell({'The Protector\'s Grasp', 'Tserrina\'s Grasp'}),
    leech=common.get_best_spell({'Twilight Leech', 'Frozen Leech'}),
    ignite=common.get_best_spell({'Ignite Cognition', 'Ignite Intellect'}),
    scourge=common.get_best_spell({'Scourge of Destiny'}),
    corruption=common.get_best_spell({'Decomposition', 'Miasma'}),
    -- Wounds proc
    proliferation=common.get_best_spell({'Infected Proliferation', 'Septic Proliferation'}),
    -- combo dot, outdated
    --combodis=common.get_best_spell({'Danvid\'s Grip of Decay'}),
    -- Alliance
    alliance=common.get_best_spell({'Malevolent Coalition', 'Malevolent Covenant'}),
    -- Nukes
    synergy=common.get_best_spell({'Proclamation for Blood', 'Assert for Blood'}),
    venin=common.get_best_spell({'Embalming Venin', 'Searing Venin'}),
    -- Debuffs
    scentterris=common.get_best_spell({'Scent of Terris'}),
    scentmortality=common.get_best_spell({'Scent of The Grave', 'Scent of Mortality'}),
    -- Mana Drain
    manatap=common.get_best_spell({'Mind Atrophy', 'Mind Erosion'}),
    -- Buffs
    lich=common.get_best_spell({'Lunaside', 'Gloomside'}),
    flesh=common.get_best_spell({'Flesh to Venom'}),
    shield=common.get_best_spell({'Shield of Inevitability', 'Shield of Destiny'}),
    -- Pet spells
    pet=common.get_best_spell({'Unrelenting Assassin', 'Restless Assassin'}),
    pethaste=common.get_best_spell({'Sigil of Undeath', 'Sigil of Decay'}),
    petillusion=common.get_best_spell({'Form of Mottled Bone'}),
    inspire=common.get_best_spell({'Inspire Ally', 'Incite Ally'}),
    swarm=common.get_best_spell({'Call Skeleton Mass', 'Call Skeleton Horde'}),
}
for name,spell in pairs(spells) do
    if spell.name then
        logger.printf('[%s] Found spell: %s (%s)', name, spell.name, spell.id)
    else
        logger.printf('[%s] Could not find spell!', name)
    end
end

-- entries in the dots table are pairs of {spell id, spell name} in priority order
local standard = {}
table.insert(standard, spells.wounds)
table.insert(standard, spells.composite)
table.insert(standard, spells.pyreshort)
table.insert(standard, spells.venom)
table.insert(standard, spells.magic)
table.insert(standard, spells.decay)
table.insert(standard, spells.haze)
table.insert(standard, spells.grasp)
table.insert(standard, spells.fireshadow)
table.insert(standard, spells.leech)
table.insert(standard, spells.grip)
table.insert(standard, spells.pyrelong)
table.insert(standard, spells.ignite)
table.insert(standard, spells.scourge)
table.insert(standard, spells.corruption)

local short = {}
table.insert(short, spells.swarm)
table.insert(short, spells.composite)
table.insert(short, spells.pyreshort)
table.insert(short, spells.venom)
table.insert(short, spells.magic)
table.insert(short, spells.decay)
table.insert(short, spells.haze)
table.insert(short, spells.grasp)
table.insert(short, spells.fireshadow)
table.insert(short, spells.leech)
table.insert(short, spells.grip)
table.insert(short, spells.pyrelong)
table.insert(short, spells.ignite)

local dots = {
    standard=standard,
    short=short,
}

local swap_gem = nil
local swap_gem_dis = nil

-- entries in the items table are MQ item datatypes
local items = {}
table.insert(items, mq.TLO.FindItem('Blightbringer\'s Tunic of the Grave').ID()) -- buff, 5 minute CD
table.insert(items, mq.TLO.InvSlot('Chest').Item.ID()) -- buff, Consuming Magic, 10 minute CD
table.insert(items, mq.TLO.FindItem('Rage of Rolfron').ID()) -- song, 30 minute CD
--table.insert(items, mq.TLO.FindItem('Vicious Rabbit').ID()) -- 5 minute CD
--table.insert(items, mq.TLO.FindItem('Necromantic Fingerbone').ID()) -- 3 minute CD
--table.insert(items, mq.TLO.FindItem('Amulet of the Drowned Mariner').ID()) -- 5 minute CD

local pre_burn_items = {}
table.insert(pre_burn_items, mq.TLO.FindItem('Blightbringer\'s Tunic of the Grave').ID()) -- buff
table.insert(pre_burn_items, mq.TLO.InvSlot('Chest').Item.ID()) -- buff, Consuming Magic

-- entries in the AAs table are pairs of {aa name, aa id}
local AAs = {}
table.insert(AAs, common.get_aa('Silent Casting')) -- song, 12 minute CD
table.insert(AAs, common.get_aa('Focus of Arcanum')) -- buff, 10 minute CD
table.insert(AAs, common.get_aa('Mercurial Torment')) -- buff, 24 minute CD
table.insert(AAs, common.get_aa('Heretic\'s Twincast')) -- buff, 15 minute CD
table.insert(AAs, common.get_aa('Spire of Necromancy')) -- buff, 7:30 minute CD
table.insert(AAs, common.get_aa('Hand of Death')) -- song, 8:30 minute CD
table.insert(AAs, common.get_aa('Funeral Pyre')) -- song, 20 minute CD
table.insert(AAs, common.get_aa('Gathering Dusk')) -- song, Duskfall Empowerment, 10 minute CD
table.insert(AAs, common.get_aa('Companion\'s Fury')) -- 10 minute CD
table.insert(AAs, common.get_aa('Companion\'s Fortification')) -- 15 minute CD
table.insert(AAs, common.get_aa('Rise of Bones')) -- 10 minute CD
table.insert(AAs, common.get_aa('Wake the Dead')) -- 3 minute CD
table.insert(AAs, common.get_aa('Swarm of Decay')) -- 9 minute CD

local glyph = common.get_aa('Mythic Glyph of Ultimate Power V')
local intensity = common.get_aa('Intensity of the Resolute')

local pre_burn_AAs = {}
table.insert(pre_burn_AAs, common.get_aa('Focus of Arcanum')) -- buff
table.insert(pre_burn_AAs, common.get_aa('Mercurial Torment')) -- buff
table.insert(pre_burn_AAs, common.get_aa('Heretic\'s Twincast')) -- buff
table.insert(pre_burn_AAs, common.get_aa('Spire of Necromancy')) -- buff

local tcclick = mq.TLO.FindItem('Bifold Focus of the Evil Eye').ID()

-- lifeburn/dying grasp combo
local lifeburn = common.get_aa('Life Burn')
local dyinggrasp = common.get_aa('Dying Grasp')
-- Buffs
local unity = common.get_aa('Mortifier\'s Unity')
-- Mana Recovery AAs
local deathbloom = common.get_aa('Death Bloom')
local bloodmagic = common.get_aa('Blood Magic')
-- Mana Recovery items
--local item_feather = mq.TLO.FindItem('Unified Phoenix Feather')
--local item_horn = mq.TLO.FindItem('Miniature Horn of Unity') -- 10 minute CD
-- Agro
local deathpeace = common.get_aa('Death Peace')
local deathseffigy = common.get_aa('Death\'s Effigy')

local convergence = common.get_aa('Convergence')
local dispel = common.get_aa('Eradicate Magic')

local buffs={
    self={},
    pet={
        spells.pethaste,
        spells.petillusion,
    },
}
--[[
    track data about our targets, for one-time or long-term affects.
    for example: we do not need to continually poll when to debuff a mob if the debuff will last 17+ minutes
    if the mob aint dead by then, you should re-roll a wizard.
]]--
local targets = {}

local neccount = 1

local SETTINGS_FILE = ('%s/necrobot_%s_%s.lua'):format(mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me.CleanName())
nec.load_settings = function()
    local settings = config.load_settings(SETTINGS_FILE)
    if not settings or not settings.nec then return end
    for setting,value in pairs(settings.nec) do
        OPTS[setting] = value
    end
end

nec.save_settings = function()
    persistence.store(SETTINGS_FILE, {common=config.get_all(), nec=OPTS})
end

-- Determine swap gem based on wherever wounds, broiling shadow or pyre of the wretched is currently mem'd
local function set_swap_gems()
    swap_gem = mq.TLO.Me.Gem(spells.wounds and spells.wounds.name or 'unknown')() or
            mq.TLO.Me.Gem(spells.fireshadow and spells.fireshadow.name or 'unknown')() or
            mq.TLO.Me.Gem(spells.pyrelong and spells.pyrelong.name or 'unknown')() or 10
    swap_gem_dis = mq.TLO.Me.Gem(spells.decay and spells.decay.name or 'unknown')() or mq.TLO.Me.Gem(spells.grip and spells.grip.name or 'unknown')() or 11
end

--[[
Count the number of necros in group or raid to determine whether alliance should be used.
This is currently only called once up front when the script starts.
]]--
local function get_necro_count()
    neccount = 1
    if mq.TLO.Raid.Members() > 0 then
        neccount = mq.TLO.SpawnCount('pc necromancer raid')()
    elseif mq.TLO.Group.Members() then
        neccount = mq.TLO.SpawnCount('pc necromancer group')()
    end
end

nec.reset_class_timers = function()
    -- no-op
end

-- Casts alliance if we are fighting, alliance is enabled, the spell is ready, alliance isn't already on the mob, there is > 1 necro in group or raid, and we have at least a few dots on the mob.
local function try_alliance()
    if config.USEALLIANCE then
        if mq.TLO.Spell(spells.alliance.name).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        if mq.TLO.Me.SpellReady(spells.alliance.name)() and neccount > 1 and not mq.TLO.Target.Buff(spells.alliance.name)() and mq.TLO.Spell(spells.alliance.name).StacksTarget() then
            -- pick the first 3 dots in the rotation as they will hopefully always be up given their priority
            if mq.TLO.Target.MyBuff(spells.pyreshort.name)() and mq.TLO.Target.MyBuff(spells.venom.name)() and mq.TLO.Target.MyBuff(spells.magic.name)() then
                common.cast(spells.alliance.name, true)
                return true
            end
        end
    end
    return false
end

local function cast_synergy()
    if not mq.TLO.Me.Song('Defiler\'s Synergy')() and mq.TLO.Me.SpellReady(spells.synergy.name)() then
        if mq.TLO.Spell(spells.synergy.name).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        -- don't bother with proc'ing synergy until we've got most dots applied
        if mq.TLO.Target.MyBuff(spells.pyreshort.name)() and mq.TLO.Target.MyBuff(spells.venom.name)() and mq.TLO.Target.MyBuff(spells.magic.name)() then
            common.cast(spells.synergy.name, true)
            return true
        end
    end
    return false
end

local function find_next_dot_to_cast()
    if try_alliance() then return nil end
    if cast_synergy() then return nil end
    -- Just cast composite as part of the normal dot rotation, no special handling
    --if common.is_dot_ready(spells.composite.id, spells.composite.name) then
    --    return spells.composite.id, spells.composite.name
    --end
    if mq.TLO.Me.PctMana() < 40 and mq.TLO.Me.SpellReady(spells.manatap.name)() and mq.TLO.Spell(spells.manatap.name).Mana() < mq.TLO.Me.CurrentMana() then
        return spells.manatap
    end
    if config.SPELLSET == 'short' and mq.TLO.Me.SpellReady(spells.swarm.name)() and mq.TLO.Spell(spells.swarm.name).Mana() < mq.TLO.Me.CurrentMana() then
        return spells.swarm
    end
    local pct_hp = mq.TLO.Target.PctHPs()
    if pct_hp and pct_hp > OPTS.STOPPCT then
        for _,dot in ipairs(dots[config.SPELLSET]) do -- iterates over the dots array. ipairs(dots) returns 2 values, an index and its value in the array. we don't care about the index, we just want the dot
            -- ToL has no combo disease dot spell, so the 2 disease dots are just in the normal rotation now.
            -- if spell_id == spells.combodis.id then
            --     if (not is_target_dotted_with(spells.decay.id, spells.decay.name) or not is_target_dotted_with(spells.grip.id, spells.grip.name)) and mq.TLO.Me.SpellReady(spells.combodis.name)() then
            --         return dot
            --     end
            -- else
            if (OPTS.USEWOUNDS or dot.id ~= spells.wounds.id) and common.is_dot_ready(dot) then
                return dot -- if is_dot_ready returned true then return this dot as the dot we should cast
            end
        end
    end
    if mq.TLO.Me.SpellReady(spells.manatap.name)() and mq.TLO.Spell(spells.manatap.name).Mana() < mq.TLO.Me.CurrentMana() then
        return spells.manatap
    end
    if config.SPELLSET == 'short' and mq.TLO.Me.SpellReady(spells.venin.name)() and mq.TLO.Spell(spells.venin.name).Mana() < mq.TLO.Me.CurrentMana() then
        return spells.venin
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

local function cycle_dots()
    if mq.TLO.Me.SpellInCooldown() then return false end
    local cur_mode = config.MODE
    if (cur_mode:is_tank_mode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:is_assist_mode() and assist.should_assist()) or (cur_mode:is_manual_mode() and mq.TLO.Me.CombatState() == 'COMBAT') then
        if OPTS.USEDISPEL and mq.TLO.Target.Beneficial() then
            common.use_aa(dispel)
        end
        local spell = find_next_dot_to_cast() -- find the first available dot to cast that is missing from the target
        if spell then -- if a dot was found
            if spell.name == spells.pyreshort.name and not mq.TLO.Me.Buff('Heretic\'s Twincast')() then
                local tc_item = mq.TLO.FindItem(tcclick)
                common.use_item(tc_item)
            end
            common.cast(spell.name, true) -- then cast the dot
        end

        if OPTS.MULTIDOT then
            local original_target_id = 0
            if mq.TLO.Target.Type() == 'NPC' then original_target_id = mq.TLO.Target.ID() end
            local dotted_count = 1
            for i=1,20 do
                if mq.TLO.Me.XTarget(i).TargetType() == 'Auto Hater' and mq.TLO.Me.XTarget(i).Type() == 'NPC' then
                    local xtar_id = mq.TLO.Me.XTarget(i).ID()
                    local xtar_spawn = mq.TLO.Spawn(xtar_id)
                    if xtar_id ~= original_target_id and assist.should_assist(xtar_spawn) then
                        xtar_spawn.DoTarget()
                        mq.delay(2000, function() return mq.TLO.Target.ID() == xtar_id and not mq.TLO.Me.SpellInCooldown() end)
                        local spell = find_next_dot_to_cast() -- find the first available dot to cast that is missing from the target
                        if spell and not mq.TLO.Target.Mezzed() then -- if a dot was found
                            --if not mq.TLO.Me.SpellReady(spell.name)() then break end
                            common.cast(spell.name, true)
                            dotted_count = dotted_count + 1
                            if dotted_count >= OPTS.MULTICOUNT then break end
                        end
                    end
                end
            end
            if original_target_id ~= 0 and mq.TLO.Target.ID() ~= original_target_id then
                mq.cmdf('/mqtar id %s', original_target_id)
            end
        end
        return true
    end
    return false
end

local function try_debuff_target()
    local cur_mode = config.MODE
    if (cur_mode:is_tank_mode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:is_assist_mode() and assist.should_assist()) or (cur_mode:is_manual_mode() and mq.TLO.Me.CombatState() == 'COMBAT') and OPTS.DEBUFF then
    --if (common.is_fighting() or assist.should_assist()) and OPTS.DEBUFF then
        local targetID = mq.TLO.Target.ID()
        if targetID and targetID > 0 and (not targets[targetID] or not targets[targetID][2]) then
            local isScentAAReady = mq.TLO.Me.AltAbilityReady('Scent of Thule')()

            local isDebuffedAlready = common.is_target_dotted_with(spells.scentterris.id, spells.scentterris.name)
            if isDebuffedAlready then
                isDebuffedAlready = common.is_target_dotted_with(spells.scentmortality.id, spells.scentmortality.name)
            end
            if not mq.TLO.Spell(spells.scentterris.name).StacksTarget() then
                isDebuffedAlready = true
            end
            if not mq.TLO.Spell(spells.scentmortality.name).StacksTarget() then
                isDebuffedAlready = true
            end

            if isScentAAReady and not isDebuffedAlready then
                logger.printf('Use AA: \ax\arScent of Thule\ax')
                mq.cmd('/alt activate 751')
                mq.delay(10)
            end

            if isDebuffedAlready then
                table.insert(targets, mq.TLO.Target.ID(), {"debuffed", true})
            end
            mq.delay(300+mq.TLO.Me.AltAbility(751).Spell.CastTime()) -- wait for cast time + some buffer so we don't skip over stuff
        end
    end
end

-- Check whether a dot is applied to the target
local function target_has_proliferation()
    if not mq.TLO.Target.MyBuff(spells.proliferation.name)() then return false else return true end
end

local function is_nec_burn_condition_met()
    if OPTS.BURNPROC and target_has_proliferation() then
        logger.printf('\arActivating Burns (proliferation proc)\ax')
        state.burn_active_timer:reset()
        state.burn_active = true
        return true
    end
end

nec.always_condition = function()
    if mq.TLO.Me.AltAbilityReady('Heretic\'s Twincast')() and not mq.TLO.Me.AltAbilityReady('Hand of Death')() then
        return false
    elseif not mq.TLO.Me.AltAbilityReady('Heretic\'s Twincast')() and mq.TLO.Me.AltAbilityReady('Hand of Death')() then
        return false
    else
        return true
    end
end

--[[
Base crit - 62%

Auspice - 33% crit
IOG - 13% crit
Bard Epic (12) + Fierce Eye (15) - 27% crit

Spire - 25% crit
OOW robe - 40% crit
Intensity - 50% crit
Glyph - 15% crit
]]--
local function try_burn()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag.
    -- Test them both for each item, and see which one(s) actually work.
    if common.is_burn_condition_met(nec.always_condition) or is_nec_burn_condition_met() then
        local base_crit = 62
        local auspice = mq.TLO.Me.Song('Auspice of the Hunter')()
        if auspice then base_crit = base_crit + 33 end
        local iog = mq.TLO.Me.Song('Illusions of Grandeur')()
        if iog then base_crit = base_crit + 13 end
        local brd_epic = mq.TLO.Me.Song('Spirit of Vesagran')()
        if brd_epic then base_crit = base_crit + 12 end
        local fierce_eye = mq.TLO.Me.Song('Fierce Eye')()
        if fierce_eye then base_crit = base_crit + 15 end

        --[[
        |===========================================================================================
        |Item Burn
        |===========================================================================================
        ]]--

        for _,item_id in ipairs(items) do
            local item = mq.TLO.FindItem(item_id)
            if item.Name() ~= 'Blightbringer\'s Tunic of the Grave' or base_crit < 100 then
                common.use_item(item)
            end
        end

        --[[
        |===========================================================================================
        |Spell Burn
        |===========================================================================================
        ]]--

        for _,aa in ipairs(AAs) do
            -- don't go making twincast dots sad by cutting them in half
            if aa.name:lower() == 'funeral pyre' then
                if not mq.TLO.Me.AltAbilityReady('heretic\'s twincast')() and not mq.TLO.Me.Buff('heretic\'s twincast')() then
                    common.use_aa(aa)
                end
            elseif aa.name:lower() == 'wake the dead' then
                if mq.TLO.SpawnCount('corpse radius 150')() > 0 then
                    common.use_aa(aa)
                end
            else
                common.use_aa(aa)
            end
        end

        if OPTS.USEGLYPH then
            if not mq.TLO.Me.Song(intensity.name)() and mq.TLO.Me.Buff('heretic\'s twincast')() then
                common.use_aa(glyph)
            end
        end
        if OPTS.USEINTENSITY then
            if not mq.TLO.Me.Buff(glyph.name)() and mq.TLO.Me.Buff('heretic\'s twincast')() then
                common.use_aa(intensity)
            end
        end

        if mq.TLO.Me.PctHPs() > 90 and mq.TLO.Me.AltAbilityReady('Life Burn')() and mq.TLO.Me.AltAbilityReady('Dying Grasp')() then
            common.use_aa(lifeburn)
            mq.delay(5)
            common.use_aa(dyinggrasp)
        end
    end
end

local function pre_pop_burns()
    logger.printf('Pre-burn')
    --[[
    |===========================================================================================
    |Item Burn
    |===========================================================================================
    ]]--

    for _,item_id in ipairs(pre_burn_items) do
        local item = mq.TLO.FindItem(item_id)
        common.use_item(item)
    end

    --[[
    |===========================================================================================
    |Spell Burn
    |===========================================================================================
    ]]--

    for _,aa in ipairs(pre_burn_AAs) do
        common.use_aa(aa)
    end

    if OPTS.USEGLYPH then
        if not mq.TLO.Me.Song(intensity.name)() and mq.TLO.Me.Buff('heretic\'s twincast')() then
            common.use_aa(glyph)
        end
    end
end

local function check_mana()
    -- modrods
    common.check_mana()
    local pct_mana = mq.TLO.Me.PctMana()
    if pct_mana < 65 then
        -- death bloom at some %
        common.use_aa(deathbloom)
    end
    --if common.is_fighting() then
    if mq.TLO.Me.CombatState() == 'COMBAT' then
        if pct_mana < 40 then
            -- blood magic at some %
            common.use_aa(bloodmagic)
        end
    end
end

local function safe_to_stand()
    if mq.TLO.Raid.Members() > 0 and mq.TLO.SpawnCount('pc raid tank radius 300')() > 2 then
        return true
    end
    if mq.TLO.Group.MainTank() then
        if not mq.TLO.Group.MainTank.Dead() then
            return true
        elseif mq.TLO.SpawnCount('npc radius 100')() == 0 then
            return true
        else
            return false
        end
    elseif mq.TLO.SpawnCount('npc radius 100')() == 0 then
        return true
    else
        return false
    end
end

local check_aggro_timer = timer:new(10)
local function check_aggro()
    if config.MODE:is_manual_mode() then return end
    --if OPTS.USEFD and common.is_fighting() and mq.TLO.Target() then
    if OPTS.USEFD and mq.TLO.Me.CombatState() == 'COMBAT' and mq.TLO.Target() then
        if mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID() or check_aggro_timer:timer_expired() then
            if mq.TLO.Me.PctAggro() >= 90 then
                if mq.TLO.Me.PctHPs() < 40 and mq.TLO.Me.AltAbilityReady('Dying Grasp')() then
                    common.use_aa(dyinggrasp)
                end
                common.use_aa(deathseffigy)
                if mq.TLO.Me.Feigning() then
                    check_aggro_timer:reset()
                    mq.delay(500)
                    if safe_to_stand() then
                        mq.TLO.Me.Sit() -- Use a sit TLO to stand up, what wizardry is this?
                        mq.cmd('/makemevis')
                    end
                end
            elseif mq.TLO.Me.PctAggro() >= 70 then
                common.use_aa(deathpeace)
                if mq.TLO.Me.Feigning() then
                    check_aggro_timer:reset()
                    mq.delay(500)
                    if safe_to_stand() then
                        mq.TLO.Me.Sit() -- Use a sit TLO to stand up, what wizardry is this?
                        mq.cmd('/makemevis')
                    end
                end
            end
        end
    end
end

local rez_timer = timer:new(5)
local function check_rez()
    if not OPTS.USEREZ or not convergence or common.am_i_dead() then return end
    if not rez_timer:timer_expired() then return end
    if not mq.TLO.Me.AltAbilityReady(convergence.name)() then return end
    if mq.TLO.FindItemCount('=Essence Emerald')() == 0 then return end
    if mq.TLO.SpawnCount('pccorpse group healer radius 100')() > 0 then
        mq.TLO.Spawn('pccorpse group healer radius 100').DoTarget()
        mq.cmd('/corpse')
        common.use_aa(convergence)
        rez_timer:reset()
        return
    end
    if mq.TLO.SpawnCount('pccorpse raid healer radius 100')() > 0 then
        mq.TLO.Spawn('pccorpse raid healer radius 100').DoTarget()
        mq.cmd('/corpse')
        common.use_aa(convergence)
        rez_timer:reset()
        return
    end
    if mq.TLO.Group.MainTank() and mq.TLO.Group.MainTank.Dead() then
        mq.TLO.Group.MainTank.DoTarget()
        local corpse_x = mq.TLO.Target.X()
        local corpse_y = mq.TLO.Target.Y()
        if corpse_x and corpse_y and common.check_distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), corpse_x, corpse_y) > 100 then return end
        mq.cmd('/corpse')
        common.use_aa(convergence)
        rez_timer:reset()
        return
    end
    for i=1,5 do
        if mq.TLO.Group.Member(i)() and mq.TLO.Group.Member(i).Dead() then
            mq.TLO.Group.Member(i).DoTarget()
            local corpse_x = mq.TLO.Target.X()
            local corpse_y = mq.TLO.Target.Y()
            if corpse_x and corpse_y and common.check_distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), corpse_x, corpse_y) < 100 then
                mq.cmd('/corpse')
                common.use_aa(convergence)
                rez_timer:reset()
                return
            end
        end
    end
end

local function check_buffs()
    if common.am_i_dead() or mq.TLO.Me.Moving() then return end
    if OPTS.USEBUFFSHIELD then
        if not mq.TLO.Me.Buff(spells.shield.name)() then
            common.cast(spells.shield.name)
        end
    end
    if OPTS.USEINSPIRE then
        if not mq.TLO.Pet.Buff(spells.inspire.name)() then
            common.cast(spells.inspire.name)
        end
    end
    common.check_combat_buffs()
    --if common.is_fighting() then return end
    if not common.clear_to_buff() then return end
    --if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.get_camp_radius()))() > 0 then return end
    if not mq.TLO.Me.Buff(spells.lich.name)() or not mq.TLO.Me.Buff(spells.flesh.name)() then
        common.use_aa(unity)
    end

    common.check_item_buffs()

    if OPTS.BUFFPET and mq.TLO.Pet.ID() > 0 then
        for _,buff in ipairs(buffs.pet) do
            if not mq.TLO.Pet.Buff(buff.name)() and mq.TLO.Spell(buff.name).StacksPet() and mq.TLO.Spell(buff.name).Mana() < mq.TLO.Me.CurrentMana() then
                common.swap_and_cast(buff, 13)
            end
        end
    end
end

local function check_pet()
    --if common.is_fighting() or mq.TLO.Pet.ID() > 0 or mq.TLO.Me.Moving() then return end
    if not common.clear_to_buff() or mq.TLO.Pet.ID() > 0 or mq.TLO.Me.Moving() then return end
    if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.CAMPRADIUS))() > 0 then return end
    if mq.TLO.Spell(spells.pet.name).Mana() or 0 > mq.TLO.Me.CurrentMana() then return end
    common.swap_and_cast(spells.pet, 13)
end

local function should_swap_dots()
    -- Only swap spells in standard spell set
    if state.spellset_loaded ~= 'standard' or mq.TLO.Me.Moving() then return end

    local woundsDuration = mq.TLO.Target.MyBuffDuration(spells.wounds.name)()
    local pyrelongDuration = mq.TLO.Target.MyBuffDuration(spells.pyrelong.name)()
    local fireshadowDuration = mq.TLO.Target.MyBuffDuration(spells.fireshadow.name)()
    if mq.TLO.Me.Gem(spells.wounds.name)() then
        if not OPTS.USEWOUNDS or (woundsDuration and woundsDuration > 20000) then
            if not pyrelongDuration or pyrelongDuration < 20000 then
                common.swap_spell(spells.pyrelong, swap_gem or 10)
            elseif not fireshadowDuration or fireshadowDuration < 20000 then
                common.swap_spell(spells.fireshadow, swap_gem or 10)
            end
        end
    elseif mq.TLO.Me.Gem(spells.pyrelong.name)() then
        if pyrelongDuration and pyrelongDuration > 20000 then
            if OPTS.USEWOUNDS and (not woundsDuration or woundsDuration < 20000) then
                common.swap_spell(spells.wounds, swap_gem or 10)
            elseif not fireshadowDuration or fireshadowDuration < 20000 then
                common.swap_spell(spells.fireshadow, swap_gem or 10)
            end
        end
    elseif mq.TLO.Me.Gem(spells.fireshadow.name)() then
        if fireshadowDuration and fireshadowDuration > 20000 then
            if OPTS.USEWOUNDS and (not woundsDuration or woundsDuration < 20000) then
                common.swap_spell(spells.wounds, swap_gem or 10)
            elseif not pyrelongDuration or pyrelongDuration < 20000 then
                common.swap_spell(spells.pyrelong, swap_gem or 10)
            end
        end
    else
        -- maybe we got interrupted or something and none of these are mem'd anymore? just memorize wounds again
        common.swap_spell(spells.wounds, swap_gem or 10)
    end

    local decayDuration = mq.TLO.Target.MyBuffDuration(spells.decay.name)()
    local gripDuration = mq.TLO.Target.MyBuffDuration(spells.grip.name)()
    if mq.TLO.Me.Gem(spells.decay.name)() then
        if decayDuration and decayDuration > 20000 then
            if not gripDuration or gripDuration < 20000 then
                common.swap_spell(spells.grip, swap_gem_dis or 11)
            end
        end
    elseif mq.TLO.Me.Gem(spells.grip.name)() then
        if gripDuration and gripDuration > 20000 then
            if not decayDuration or decayDuration < 20000 then
                common.swap_spell(spells.decay, swap_gem_dis or 11)
            end
        end
    else
        -- maybe we got interrupted or something and none of these are mem'd anymore? just memorize decay again
        common.swap_spell(spells.decay, swap_gem_dis or 11)
    end
end

local composite_names = {['Composite Paroxysm']=true, ['Dissident Paroxysm']=true, ['Dichotomic Paroxysm']=true}
local check_spell_timer = timer:new(30)
local function check_spell_set()
    --if common.is_fighting() or mq.TLO.Me.Moving() or common.am_i_dead() then return end
    if not common.clear_to_buff() or mq.TLO.Me.Moving() or common.am_i_dead() then return end
    if state.spellset_loaded ~= config.SPELLSET or check_spell_timer:timer_expired() then
        if config.SPELLSET == 'standard' then
            common.swap_spell(spells.composite, 1, composite_names)
            common.swap_spell(spells.pyreshort, 2)
            common.swap_spell(spells.venom, 3)
            common.swap_spell(spells.magic, 4)
            common.swap_spell(spells.haze, 5)
            common.swap_spell(spells.grasp, 6)
            common.swap_spell(spells.leech, 7)
            --common.swap_spell(spells.wounds, 10)
            common.swap_spell(spells.decay, 11)
            common.swap_spell(spells.synergy, 13)
            state.spellset_loaded = config.SPELLSET
        elseif config.SPELLSET == 'short' then
            common.swap_spell(spells.composite, 1, composite_names)
            common.swap_spell(spells.pyreshort, 2)
            common.swap_spell(spells.venom, 3)
            common.swap_spell(spells.magic, 4)
            common.swap_spell(spells.haze, 5)
            common.swap_spell(spells.grasp, 6)
            common.swap_spell(spells.leech, 7)
            common.swap_spell(spells.swarm, 10)
            common.swap_spell(spells.decay, 11)
            common.swap_spell(spells.synergy, 13)
            state.spellset_loaded = config.SPELLSET
        end
        check_spell_timer:reset()
        set_swap_gems()
    end
    if config.SPELLSET == 'standard' then
        if OPTS.USEMANATAP and config.USEALLIANCE and OPTS.USEBUFFSHIELD then
            common.swap_spell(spells.manatap, 8)
            common.swap_spell(spells.alliance, 9)
            common.swap_spell(spells.shield, 12)
        elseif OPTS.USEMANATAP and config.USEALLIANCE and not OPTS.USEBUFFSHIELD then
            common.swap_spell(spells.manatap, 8)
            common.swap_spell(spells.alliance, 9)
            common.swap_spell(spells.ignite, 12)
        elseif OPTS.USEMANATAP and not config.USEALLIANCE and not OPTS.USEBUFFSHIELD then
            common.swap_spell(spells.manatap, 8)
            common.swap_spell(spells.scourge, 9)
            common.swap_spell(spells.ignite, 12)
        elseif OPTS.USEMANATAP and not config.USEALLIANCE and OPTS.USEBUFFSHIELD then
            common.swap_spell(spells.manatap, 8)
            common.swap_spell(spells.ignite, 9)
            common.swap_spell(spells.shield, 12)
        elseif not OPTS.USEMANATAP and not config.USEALLIANCE and not OPTS.USEBUFFSHIELD then
            common.swap_spell(spells.ignite, 8)
            common.swap_spell(spells.scourge, 9)
            common.swap_spell(spells.corruption, 12)
        elseif not OPTS.USEMANATAP and not config.USEALLIANCE and OPTS.USEBUFFSHIELD then
            common.swap_spell(spells.ignite, 8)
            common.swap_spell(spells.scourge, 9)
            common.swap_spell(spells.shield, 12)
        elseif not OPTS.USEMANATAP and config.USEALLIANCE and OPTS.USEBUFFSHIELD then
            common.swap_spell(spells.ignite, 8)
            common.swap_spell(spells.alliance, 9)
            common.swap_spell(spells.shield, 12)
        elseif not OPTS.USEMANATAP and config.USEALLIANCE and not OPTS.USEBUFFSHIELD then
            common.swap_spell(spells.ignite, 8)
            common.swap_spell(spells.alliance, 9)
            common.swap_spell(spells.scourge, 12)
        end
        if not OPTS.USEWOUNDS then
            common.swap_spell(spells.pyrelong, 10)
        else
            common.swap_spell(spells.wounds, 10)
        end
    elseif config.SPELLSET == 'short' then
        if OPTS.USEMANATAP and config.USEALLIANCE and OPTS.USEINSPIRE then
            common.swap_spell(spells.manatap, 8)
            common.swap_spell(spells.alliance, 9)
            common.swap_spell(spells.inspire, 12)
        elseif OPTS.USEMANATAP and config.USEALLIANCE and not OPTS.USEINSPIRE then
            common.swap_spell(spells.manatap, 8)
            common.swap_spell(spells.alliance, 9)
            common.swap_spell(spells.venin, 12)
        elseif OPTS.USEMANATAP and not config.USEALLIANCE and not OPTS.USEINSPIRE then
            common.swap_spell(spells.manatap, 8)
            common.swap_spell(spells.ignite, 9)
            common.swap_spell(spells.venin, 12)
        elseif OPTS.USEMANATAP and not config.USEALLIANCE and OPTS.USEINSPIRE then
            common.swap_spell(spells.manatap, 8)
            common.swap_spell(spells.ignite, 9)
            common.swap_spell(spells.inspire, 12)
        elseif not OPTS.USEMANATAP and not config.USEALLIANCE and not OPTS.USEINSPIRE then
            common.swap_spell(spells.ignite, 8)
            common.swap_spell(spells.scourge, 9)
            common.swap_spell(spells.venin, 12)
        elseif not OPTS.USEMANATAP and not config.USEALLIANCE and OPTS.USEINSPIRE then
            common.swap_spell(spells.ignite, 8)
            common.swap_spell(spells.scourge, 9)
            common.swap_spell(spells.inspire, 12)
        elseif not OPTS.USEMANATAP and config.USEALLIANCE and OPTS.USEINSPIRE then
            common.swap_spell(spells.ignite, 8)
            common.swap_spell(spells.alliance, 9)
            common.swap_spell(spells.inspire, 12)
        elseif not OPTS.USEMANATAP and config.USEALLIANCE and not OPTS.USEINSPIRE then
            common.swap_spell(spells.ignite, 8)
            common.swap_spell(spells.alliance, 9)
            common.swap_spell(spells.venin, 12)
        end
    end
end

nec.setup_events = function()
    -- no-op
end

nec.process_cmd = function(opt, new_value)
    if new_value then
        if opt == 'SPELLSET' then
            if SPELLSETS[new_value] then
                logger.printf('Setting %s to: %s', opt, new_value)
                config.SPELLSET = new_value
            end
        elseif type(OPTS[opt]) == 'boolean' then
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
        if opt == 'PREP' then
            pre_pop_burns()
        elseif OPTS[opt] ~= nil then
            logger.printf('%s: %s', opt:lower(), OPTS[opt])
        else
            logger.printf('Unrecognized option: %s', opt)
        end
    end
end

local nec_count_timer = timer:new(60)
nec.main_loop = function()
    -- keep cursor clear for spell swaps and such
    if config.USEALLIANCE and nec_count_timer:timer_expired() then
        get_necro_count()
        nec_count_timer:reset()
    end
    -- ensure correct spells are loaded based on selected spell set
    -- currently only checks at startup or when selection changes
    check_spell_set()
    -- check whether we need to return to camp
    camp.check_camp()
    -- check whether we need to go chasing after the chase target
    common.check_chase()
    -- check we have the correct target to attack
    assist.check_target()
    -- if we should be assisting but aren't in los, try to be?
    assist.check_los()
    -- begin actual combat stuff
    assist.send_pet()
    try_debuff_target()
    if not cycle_dots() then
        -- if we found no DoT to cast this loop, check if we should swap
        should_swap_dots()
    end
    -- pop a bunch of burn stuff if burn conditions are met
    try_burn()
    -- try not to run OOM
    check_aggro()
    check_mana()
    check_buffs()
    check_pet()
    check_rez()
    common.rest()
end

nec.draw_skills_tab = function()
    config.SPELLSET = ui.draw_combo_box('Spell Set', config.SPELLSET, SPELLSETS, true)
    config.USEALLIANCE = ui.draw_check_box('Alliance', '##alliance', config.USEALLIANCE, 'Use alliance spell')
    OPTS.DEBUFF = ui.draw_check_box('Debuff', '##debuff', OPTS.DEBUFF, 'Debuff targets')
    OPTS.SUMMONPET = ui.draw_check_box('Summon Pet', '##summonpet', OPTS.SUMMONPET, 'Summon pet')
    OPTS.BUFFPET = ui.draw_check_box('Buff Pet', '##buffpet', OPTS.BUFFPET, 'Use pet buff')
    OPTS.USEINSPIRE = ui.draw_check_box('Inspire Ally', '##inspire', OPTS.USEINSPIRE, 'Use Inspire Ally pet buff')
    OPTS.USEBUFFSHIELD = ui.draw_check_box('Buff Shield', '##buffshield', OPTS.USEBUFFSHIELD, 'Keep shield buff up. Replaces corruption DoT.')
    OPTS.USEMANATAP = ui.draw_check_box('Mana Drain', '##manadrain', OPTS.USEMANATAP, 'Use group mana drain dot. Replaces Ignite DoT.')
    OPTS.USEFD = ui.draw_check_box('Feign Death', '##dofeign', OPTS.USEFD, 'Use FD AA\'s to reduce aggro')
    OPTS.USEREZ = ui.draw_check_box('Use Rez', '##userez', OPTS.USEREZ, 'Use Convergence AA to rez group members')
    OPTS.USEDISPEL = ui.draw_check_box('Use Dispel', '##dispel', OPTS.USEDISPEL, 'Dispel mobs with Eradicate Magic AA')
    OPTS.USEWOUNDS = ui.draw_check_box('Use Wounds', '##usewounds', OPTS.USEWOUNDS, 'Use wounds DoT')
    OPTS.MULTIDOT = ui.draw_check_box('Multi DoT', '##multidot', OPTS.MULTIDOT, 'DoT all mobs')
    OPTS.MULTICOUNT = ui.draw_input_int('Multi DoT #', '##multidotnum', OPTS.MULTICOUNT, 'Number of mobs to rotate through when multi-dot is enabled')
end

nec.draw_burn_tab = function()
    OPTS.BURNPROC = ui.draw_check_box('Burn On Proc', '##burnproc', OPTS.BURNPROC, 'Burn when proliferation procs')
end

return nec