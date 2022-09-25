--- @type Mq
local mq = require 'mq'
local baseclass = require('aqo.classes.base')
local assist = require('aqo.routines.assist')
local logger = require('aqo.utils.logger')
local timer = require('aqo.utils.timer')
local common = require('aqo.common')
local config = require('aqo.configuration')
local state = require('aqo.state')
local ui = require('aqo.ui')

local nec = baseclass

nec.class = 'nec'
nec.classOrder = {'assist', 'cast', 'burn', 'aggro', 'recover', 'rez', 'buff', 'rest', 'managepet'}

nec.SPELLSETS = {standard=1,short=1}

nec.addOption('SPELLSET', 'Spell Set', 'standard', nec.SPELLSETS, nil, 'combobox')
nec.addOption('STOPPCT', 'DoT Stop Pct', 0, nil, 'Percent HP to stop refreshing DoTs on mobs', 'inputint')
nec.addOption('DEBUFF', 'Debuff', true, nil, 'Debuff targets', 'checkbox') -- enable use of debuffs
nec.addOption('USEBUFFSHIELD', 'Buff Shield', false, nil, 'Keep shield buff up. Replaces corruption DoT.', 'checkbox')
nec.addOption('SUMMONPET', 'Summon Pet', false, nil, 'Summon pet', 'checkbox')
nec.addOption('BUFFPET', 'Buff Pet', true, nil, 'Use pet buff', 'checkbox')
nec.addOption('USEALLIANCE', 'Use Alliance', false, nil, 'Use alliance if 2 or more necros present', 'checkbox')
nec.addOption('USEMANATAP', 'Mana Drain', false, nil, 'Use group mana drain dot. Replaces Ignite DoT.', 'checkbox')
nec.addOption('USEREZ', 'Use Rez', true, nil, 'Use Convergence AA to rez group members', 'checkbox')
nec.addOption('USEFD', 'Feign Death', true, nil, 'Use FD AA\'s to reduce aggro', 'checkbox')
nec.addOption('USEINSPIRE', 'Inspire Ally', true, nil, 'Use Inspire Ally pet buff', 'checkbox')
nec.addOption('USEDISPEL', 'Use Dispel', true, nil, 'Dispel mobs with Eradicate Magic AA', 'checkbox')
nec.addOption('BYOS', 'BYOS', false, nil, 'Bring your own spell set', 'checkbox')
nec.addOption('USEWOUNDS', 'Use Wounds', true, nil, 'Use wounds DoT', 'checkbox')
nec.addOption('MULTIDOT', 'Multi DoT', false, nil, 'DoT all mobs', 'checkbox')
nec.addOption('MULTICOUNT', 'Multi DoT #', 3, nil, 'Number of mobs to rotate through when multi-dot is enabled', 'inputint')
nec.addOption('USEGLYPH', 'Use DPS Glyph', false, nil, 'Use glyph of destruction during burns', 'checkbox')
nec.addOption('USEINTENSITY', 'Use Intensity', false, nil, 'Use intensity of the resolute during burns', 'checkbox')

nec.addSpell('composite', {'Composite Paroxysm', 'Dissident Paroxysm'})
nec.addSpell('wounds', {'Infected Wounds', 'Septic Wounds'})
nec.addSpell('fireshadow', {'Scalding Shadow', 'Broiling Shadow'})
nec.addSpell('pyreshort', {'Pyre of Va Xakra', 'Pyre of Klraggek'})
nec.addSpell('pyrelong', {'Pyre of the Neglected', 'Pyre of the Wretched'})
nec.addSpell('venom', {'Hemorrhagic Venom', 'Crystal Crawler Venom'})
nec.addSpell('magic', {'Extinction', 'Oblivion'})
nec.addSpell('decay', {'Fleshrot\'s Decay', 'Danvid\'s Decay'})
nec.addSpell('grip', {'Grip of Quietus', 'Grip of Zorglim'})
nec.addSpell('haze', {'Zelnithak\'s Pallid Haze', 'Drachnia\'s Pallid Haze'})
nec.addSpell('grasp', {'The Protector\'s Grasp', 'Tserrina\'s Grasp'})
nec.addSpell('leech', {'Twilight Leech', 'Frozen Leech'})
nec.addSpell('ignite', {'Ignite Cognition', 'Ignite Intellect'})
nec.addSpell('scourge', {'Scourge of Destiny'})
nec.addSpell('corruption', {'Decomposition', 'Miasma'})
-- Wounds proc
nec.addSpell('proliferation', {'Infected Proliferation', 'Septic Proliferation'})
-- combo dot, outdated
--combodis', {'Danvid\'s Grip of Decay'},
-- Alliance
nec.addSpell('alliance', {'Malevolent Coalition', 'Malevolent Covenant'})
-- Nukes
nec.addSpell('synergy', {'Proclamation for Blood', 'Assert for Blood'})
nec.addSpell('venin', {'Embalming Venin', 'Searing Venin'})
-- Debuffs
nec.addSpell('scentterris', {'Scent of Terris'})
nec.addSpell('scentmortality', {'Scent of The Grave', 'Scent of Mortality'})
-- Mana Drain
nec.addSpell('manatap', {'Mind Atrophy', 'Mind Erosion'})
-- Buffs
nec.addSpell('lich', {'Lunaside', 'Gloomside'})
nec.addSpell('flesh', {'Flesh to Venom'})
nec.addSpell('shield', {'Shield of Inevitability', 'Shield of Destiny'})
-- Pet spells
nec.addSpell('pet', {'Unrelenting Assassin', 'Restless Assassin'})
nec.addSpell('pethaste', {'Sigil of Undeath', 'Sigil of Decay'})
nec.addSpell('petillusion', {'Form of Mottled Bone'})
nec.addSpell('inspire', {'Inspire Ally', 'Incite Ally'})
nec.addSpell('swarm', {'Call Skeleton Mass', 'Call Skeleton Horde'})

-- entries in the dots table are pairs of {spell id, spell name} in priority order
local standard = {}
table.insert(standard, nec.spells.wounds)
table.insert(standard, nec.spells.composite)
table.insert(standard, nec.spells.pyreshort)
table.insert(standard, nec.spells.venom)
table.insert(standard, nec.spells.magic)
table.insert(standard, nec.spells.decay)
table.insert(standard, nec.spells.haze)
table.insert(standard, nec.spells.grasp)
table.insert(standard, nec.spells.fireshadow)
table.insert(standard, nec.spells.leech)
table.insert(standard, nec.spells.grip)
table.insert(standard, nec.spells.pyrelong)
table.insert(standard, nec.spells.ignite)
table.insert(standard, nec.spells.scourge)
table.insert(standard, nec.spells.corruption)

local short = {}
table.insert(short, nec.spells.swarm)
table.insert(short, nec.spells.composite)
table.insert(short, nec.spells.pyreshort)
table.insert(short, nec.spells.venom)
table.insert(short, nec.spells.magic)
table.insert(short, nec.spells.decay)
table.insert(short, nec.spells.haze)
table.insert(short, nec.spells.grasp)
table.insert(short, nec.spells.fireshadow)
table.insert(short, nec.spells.leech)
table.insert(short, nec.spells.grip)
table.insert(short, nec.spells.pyrelong)
table.insert(short, nec.spells.ignite)

local dots = {
    standard=standard,
    short=short,
}

local swap_gem = nil
local swap_gem_dis = nil

-- entries in the items table are MQ item datatypes
table.insert(nec.burnAbilities, mq.TLO.FindItem('Blightbringer\'s Tunic of the Grave').ID()) -- buff, 5 minute CD
table.insert(nec.burnAbilities, mq.TLO.InvSlot('Chest').Item.ID()) -- buff, Consuming Magic, 10 minute CD
table.insert(nec.burnAbilities, mq.TLO.FindItem('Rage of Rolfron').ID()) -- song, 30 minute CD
--table.insert(items, mq.TLO.FindItem('Vicious Rabbit').ID()) -- 5 minute CD
--table.insert(items, mq.TLO.FindItem('Necromantic Fingerbone').ID()) -- 3 minute CD
--table.insert(items, mq.TLO.FindItem('Amulet of the Drowned Mariner').ID()) -- 5 minute CD

local pre_burn_items = {}
table.insert(pre_burn_items, mq.TLO.FindItem('Blightbringer\'s Tunic of the Grave').ID()) -- buff
table.insert(pre_burn_items, mq.TLO.InvSlot('Chest').Item.ID()) -- buff, Consuming Magic

-- entries in the AAs table are pairs of {aa name, aa id}
table.insert(nec.burnAbilities, common.get_aa('Silent Casting')) -- song, 12 minute CD
table.insert(nec.burnAbilities, common.get_aa('Focus of Arcanum')) -- buff, 10 minute CD
table.insert(nec.burnAbilities, common.get_aa('Mercurial Torment')) -- buff, 24 minute CD
table.insert(nec.burnAbilities, common.get_aa('Heretic\'s Twincast')) -- buff, 15 minute CD
table.insert(nec.burnAbilities, common.get_aa('Spire of Necromancy')) -- buff, 7:30 minute CD
table.insert(nec.burnAbilities, common.get_aa('Hand of Death')) -- song, 8:30 minute CD
table.insert(nec.burnAbilities, common.get_aa('Gathering Dusk')) -- song, Duskfall Empowerment, 10 minute CD
table.insert(nec.burnAbilities, common.get_aa('Companion\'s Fury')) -- 10 minute CD
table.insert(nec.burnAbilities, common.get_aa('Companion\'s Fortification')) -- 15 minute CD
table.insert(nec.burnAbilities, common.get_aa('Rise of Bones', {delay=1500})) -- 10 minute CD
table.insert(nec.burnAbilities, common.get_aa('Swarm of Decay', {delay=1500})) -- 9 minute CD

local glyph = common.get_aa('Mythic Glyph of Ultimate Power V')
local intensity = common.get_aa('Intensity of the Resolute')

local wakethedead = common.get_aa('Wake the Dead') -- 3 minute CD

local funeralpyre = common.get_aa('Funeral Pyre') -- song, 20 minute CD

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

local scent = common.get_aa('Scent of Thule')
local debuff_timer = timer:new(30)

local buffs={
    self={},
    pet={
        nec.spells.pethaste,
        nec.spells.petillusion,
    },
}

local neccount = 1

-- Determine swap gem based on wherever wounds, broiling shadow or pyre of the wretched is currently mem'd
local function set_swap_gems()
    swap_gem = mq.TLO.Me.Gem(nec.spells.wounds and nec.spells.wounds.name or 'unknown')() or
            mq.TLO.Me.Gem(nec.spells.fireshadow and nec.spells.fireshadow.name or 'unknown')() or
            mq.TLO.Me.Gem(nec.spells.pyrelong and nec.spells.pyrelong.name or 'unknown')() or 10
    swap_gem_dis = mq.TLO.Me.Gem(nec.spells.decay and nec.spells.decay.name or 'unknown')() or mq.TLO.Me.Gem(nec.spells.grip and nec.spells.grip.name or 'unknown')() or 11
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
    debuff_timer:reset(0)
end

local function should_swap_dots()
    -- Only swap spells in standard spell set
    if state.spellset_loaded ~= 'standard' or mq.TLO.Me.Moving() then return end

    local woundsDuration = mq.TLO.Target.MyBuffDuration(nec.spells.wounds.name)()
    local pyrelongDuration = mq.TLO.Target.MyBuffDuration(nec.spells.pyrelong.name)()
    local fireshadowDuration = mq.TLO.Target.MyBuffDuration(nec.spells.fireshadow.name)()
    if mq.TLO.Me.Gem(nec.spells.wounds.name)() then
        if not nec.OPTS.USEWOUNDS or (woundsDuration and woundsDuration > 20000) then
            if not pyrelongDuration or pyrelongDuration < 20000 then
                common.swap_spell(nec.spells.pyrelong, swap_gem or 10)
            elseif not fireshadowDuration or fireshadowDuration < 20000 then
                common.swap_spell(nec.spells.fireshadow, swap_gem or 10)
            end
        end
    elseif mq.TLO.Me.Gem(nec.spells.pyrelong.name)() then
        if pyrelongDuration and pyrelongDuration > 20000 then
            if nec.OPTS.USEWOUNDS and (not woundsDuration or woundsDuration < 20000) then
                common.swap_spell(nec.spells.wounds, swap_gem or 10)
            elseif not fireshadowDuration or fireshadowDuration < 20000 then
                common.swap_spell(nec.spells.fireshadow, swap_gem or 10)
            end
        end
    elseif mq.TLO.Me.Gem(nec.spells.fireshadow.name)() then
        if fireshadowDuration and fireshadowDuration > 20000 then
            if nec.OPTS.USEWOUNDS and (not woundsDuration or woundsDuration < 20000) then
                common.swap_spell(nec.spells.wounds, swap_gem or 10)
            elseif not pyrelongDuration or pyrelongDuration < 20000 then
                common.swap_spell(nec.spells.pyrelong, swap_gem or 10)
            end
        end
    else
        -- maybe we got interrupted or something and none of these are mem'd anymore? just memorize wounds again
        common.swap_spell(nec.spells.wounds, swap_gem or 10)
    end

    local decayDuration = mq.TLO.Target.MyBuffDuration(nec.spells.decay.name)()
    local gripDuration = mq.TLO.Target.MyBuffDuration(nec.spells.grip.name)()
    if mq.TLO.Me.Gem(nec.spells.decay.name)() then
        if decayDuration and decayDuration > 20000 then
            if not gripDuration or gripDuration < 20000 then
                common.swap_spell(nec.spells.grip, swap_gem_dis or 11)
            end
        end
    elseif mq.TLO.Me.Gem(nec.spells.grip.name)() then
        if gripDuration and gripDuration > 20000 then
            if not decayDuration or decayDuration < 20000 then
                common.swap_spell(nec.spells.decay, swap_gem_dis or 11)
            end
        end
    else
        -- maybe we got interrupted or something and none of these are mem'd anymore? just memorize decay again
        common.swap_spell(nec.spells.decay, swap_gem_dis or 11)
    end
end

-- Casts alliance if we are fighting, alliance is enabled, the spell is ready, alliance isn't already on the mob, there is > 1 necro in group or raid, and we have at least a few dots on the mob.
local function try_alliance()
    if config.USEALLIANCE then
        if mq.TLO.Spell(nec.spells.alliance.name).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        if mq.TLO.Me.SpellReady(nec.spells.alliance.name)() and neccount > 1 and not mq.TLO.Target.Buff(nec.spells.alliance.name)() and mq.TLO.Spell(nec.spells.alliance.name).StacksTarget() then
            -- pick the first 3 dots in the rotation as they will hopefully always be up given their priority
            if mq.TLO.Target.MyBuff(nec.spells.pyreshort.name)() and mq.TLO.Target.MyBuff(nec.spells.venom.name)() and mq.TLO.Target.MyBuff(nec.spells.magic.name)() then
                common.cast(nec.spells.alliance.name, true)
                return true
            end
        end
    end
    return false
end

local function cast_synergy()
    if not mq.TLO.Me.Song('Defiler\'s Synergy')() and mq.TLO.Me.SpellReady(nec.spells.synergy.name)() then
        if mq.TLO.Spell(nec.spells.synergy.name).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        -- don't bother with proc'ing synergy until we've got most dots applied
        if mq.TLO.Target.MyBuff(nec.spells.pyreshort.name)() and mq.TLO.Target.MyBuff(nec.spells.venom.name)() and mq.TLO.Target.MyBuff(nec.spells.magic.name)() then
            common.cast(nec.spells.synergy.name, true)
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
    if mq.TLO.Me.PctMana() < 40 and mq.TLO.Me.SpellReady(nec.spells.manatap.name)() and mq.TLO.Spell(nec.spells.manatap.name).Mana() < mq.TLO.Me.CurrentMana() then
        return nec.spells.manatap
    end
    if config.SPELLSET == 'short' and mq.TLO.Me.SpellReady(nec.spells.swarm.name)() and mq.TLO.Spell(nec.spells.swarm.name).Mana() < mq.TLO.Me.CurrentMana() then
        return nec.spells.swarm
    end
    local pct_hp = mq.TLO.Target.PctHPs()
    if pct_hp and pct_hp > nec.OPTS.STOPPCT then
        for _,dot in ipairs(dots[config.SPELLSET]) do -- iterates over the dots array. ipairs(dots) returns 2 values, an index and its value in the array. we don't care about the index, we just want the dot
            -- ToL has no combo disease dot spell, so the 2 disease dots are just in the normal rotation now.
            -- if spell_id == spells.combodis.id then
            --     if (not is_target_dotted_with(spells.decay.id, spells.decay.name) or not is_target_dotted_with(spells.grip.id, spells.grip.name)) and mq.TLO.Me.SpellReady(spells.combodis.name)() then
            --         return dot
            --     end
            -- else
            if (nec.OPTS.USEWOUNDS or dot.id ~= nec.spells.wounds.id) and common.is_dot_ready(dot) then
                return dot -- if is_dot_ready returned true then return this dot as the dot we should cast
            end
        end
    end
    if mq.TLO.Me.SpellReady(nec.spells.manatap.name)() and mq.TLO.Spell(nec.spells.manatap.name).Mana() < mq.TLO.Me.CurrentMana() then
        return nec.spells.manatap
    end
    if config.SPELLSET == 'short' and mq.TLO.Me.SpellReady(nec.spells.venin.name)() and mq.TLO.Spell(nec.spells.venin.name).Mana() < mq.TLO.Me.CurrentMana() then
        return nec.spells.venin
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

nec.cast = function()
    if mq.TLO.Me.SpellInCooldown() then return false end
    local cur_mode = config.MODE
    if (cur_mode:is_tank_mode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:is_assist_mode() and assist.should_assist()) or (cur_mode:is_manual_mode() and mq.TLO.Me.CombatState() == 'COMBAT') then
        if nec.OPTS.USEDISPEL and mq.TLO.Target.Beneficial() then
            common.use_aa(dispel)
        end
        if nec.OPTS.DEBUFF and not mq.TLO.Target.Buff(nec.spells.scentterris.name)() and mq.TLO.Spell(nec.spells.scentterris.name).StacksTarget() then
            common.use_aa(scent)
            debuff_timer:reset()
        end
        local spell = find_next_dot_to_cast() -- find the first available dot to cast that is missing from the target
        if spell then -- if a dot was found
            if spell.name == nec.spells.pyreshort.name and not mq.TLO.Me.Buff('Heretic\'s Twincast')() then
                local tc_item = mq.TLO.FindItem(tcclick)
                common.use_item(tc_item)
            end
            common.cast(spell.name, true) -- then cast the dot
        end

        if nec.OPTS.MULTIDOT then
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
                            if dotted_count >= nec.OPTS.MULTICOUNT then break end
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
    return should_swap_dots()
end

-- Check whether a dot is applied to the target
local function target_has_proliferation()
    if not mq.TLO.Target.MyBuff(nec.spells.proliferation.name)() then return false else return true end
end

local function is_nec_burn_condition_met()
    if nec.OPTS.BURNPROC and target_has_proliferation() then
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
nec.burn_class = function()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag.
    -- Test them both for each item, and see which one(s) actually work.
    --if common.is_burn_condition_met(nec.always_condition) or is_nec_burn_condition_met() then
    local base_crit = 62
    local auspice = mq.TLO.Me.Song('Auspice of the Hunter')()
    if auspice then base_crit = base_crit + 33 end
    local iog = mq.TLO.Me.Song('Illusions of Grandeur')()
    if iog then base_crit = base_crit + 13 end
    local brd_epic = mq.TLO.Me.Song('Spirit of Vesagran')()
    if brd_epic then base_crit = base_crit + 12 end
    local fierce_eye = mq.TLO.Me.Song('Fierce Eye')()
    if fierce_eye then base_crit = base_crit + 15 end

    if mq.TLO.SpawnCount('corpse radius 150')() > 0 then
        common.use_aa(wakethedead)
        mq.delay(1500)
    end

    if nec.OPTS.USEGLYPH then
        if not mq.TLO.Me.Song(intensity.name)() and mq.TLO.Me.Buff('heretic\'s twincast')() then
            common.use_aa(glyph)
        end
    end
    if nec.OPTS.USEINTENSITY then
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

    if nec.OPTS.USEGLYPH then
        if not mq.TLO.Me.Song(intensity.name)() and mq.TLO.Me.Buff('heretic\'s twincast')() then
            common.use_aa(glyph)
        end
    end
end

nec.recover = function()
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
nec.aggro = function()
    if config.MODE:is_manual_mode() then return end
    --if OPTS.USEFD and common.is_fighting() and mq.TLO.Target() then
    if nec.OPTS.USEFD and mq.TLO.Me.CombatState() == 'COMBAT' and mq.TLO.Target() then
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
nec.rez = function()
    if not nec.OPTS.USEREZ or not convergence or common.am_i_dead() then return end
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

nec.buff = function()
    if common.am_i_dead() or mq.TLO.Me.Moving() then return end
    if nec.OPTS.USEBUFFSHIELD then
        local tempName = nec.spells.shield.name
        if state.subscription ~= 'GOLD' then tempName = tempName:gsub(' Rk%..*', '') end
        if not mq.TLO.Me.Buff(tempName)() then
            common.cast(nec.spells.shield.name)
        end
    end
    if nec.OPTS.USEINSPIRE then
        local tempName = nec.spells.inspire.name
        if state.subscription ~= 'GOLD' then tempName = tempName:gsub(' Rk%..*', '') end
        if not mq.TLO.Pet.Buff(tempName)() then
            common.cast(nec.spells.inspire.name)
        end
    end
    common.check_combat_buffs()
    --if common.is_fighting() then return end
    if not common.clear_to_buff() then return end
    --if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.get_camp_radius()))() > 0 then return end
    if not mq.TLO.Me.Buff(nec.spells.lich.name)() or not mq.TLO.Me.Buff(nec.spells.flesh.name)() then
        common.use_aa(unity)
    end

    common.check_item_buffs()

    if nec.OPTS.BUFFPET and mq.TLO.Pet.ID() > 0 then
        for _,buff in ipairs(buffs.pet) do
            local tempName = buff.name
            if state.subscription ~= 'GOLD' then tempName = tempName:gsub(' Rk%..*', '') end
            if not mq.TLO.Pet.Buff(tempName)() and mq.TLO.Spell(buff.name).StacksPet() and mq.TLO.Spell(buff.name).Mana() < mq.TLO.Me.CurrentMana() then
                common.swap_and_cast(buff, 13)
            end
        end
    end
end

nec.managepet = function()
    --if common.is_fighting() or mq.TLO.Pet.ID() > 0 or mq.TLO.Me.Moving() then return end
    if not common.clear_to_buff() or mq.TLO.Pet.ID() > 0 or mq.TLO.Me.Moving() then return end
    if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.CAMPRADIUS))() > 0 then return end
    if mq.TLO.Spell(nec.spells.pet.name).Mana() or 0 > mq.TLO.Me.CurrentMana() then return end
    common.swap_and_cast(nec.spells.pet, 13)
end

local composite_names = {['Composite Paroxysm']=true, ['Dissident Paroxysm']=true, ['Dichotomic Paroxysm']=true}
local check_spell_timer = timer:new(30)
nec.check_spell_set = function()
    --if common.is_fighting() or mq.TLO.Me.Moving() or common.am_i_dead() then return end
    if not common.clear_to_buff() or mq.TLO.Me.Moving() or common.am_i_dead() then return end
    if state.spellset_loaded ~= config.SPELLSET or check_spell_timer:timer_expired() then
        if config.SPELLSET == 'standard' then
            common.swap_spell(nec.spells.composite, 1, composite_names)
            common.swap_spell(nec.spells.pyreshort, 2)
            common.swap_spell(nec.spells.venom, 3)
            common.swap_spell(nec.spells.magic, 4)
            common.swap_spell(nec.spells.haze, 5)
            common.swap_spell(nec.spells.grasp, 6)
            common.swap_spell(nec.spells.leech, 7)
            --common.swap_spell(spells.wounds, 10)
            common.swap_spell(nec.spells.decay, 11)
            common.swap_spell(nec.spells.synergy, 13)
            state.spellset_loaded = config.SPELLSET
        elseif config.SPELLSET == 'short' then
            common.swap_spell(nec.spells.composite, 1, composite_names)
            common.swap_spell(nec.spells.pyreshort, 2)
            common.swap_spell(nec.spells.venom, 3)
            common.swap_spell(nec.spells.magic, 4)
            common.swap_spell(nec.spells.haze, 5)
            common.swap_spell(nec.spells.grasp, 6)
            common.swap_spell(nec.spells.leech, 7)
            common.swap_spell(nec.spells.swarm, 10)
            common.swap_spell(nec.spells.decay, 11)
            common.swap_spell(nec.spells.synergy, 13)
            state.spellset_loaded = config.SPELLSET
        end
        check_spell_timer:reset()
        set_swap_gems()
    end
    if config.SPELLSET == 'standard' then
        if nec.OPTS.USEMANATAP and config.USEALLIANCE and nec.OPTS.USEBUFFSHIELD then
            common.swap_spell(nec.spells.manatap, 8)
            common.swap_spell(nec.spells.alliance, 9)
            common.swap_spell(nec.spells.shield, 12)
        elseif nec.OPTS.USEMANATAP and config.USEALLIANCE and not nec.OPTS.USEBUFFSHIELD then
            common.swap_spell(nec.spells.manatap, 8)
            common.swap_spell(nec.spells.alliance, 9)
            common.swap_spell(nec.spells.ignite, 12)
        elseif nec.OPTS.USEMANATAP and not config.USEALLIANCE and not nec.OPTS.USEBUFFSHIELD then
            common.swap_spell(nec.spells.manatap, 8)
            common.swap_spell(nec.spells.scourge, 9)
            common.swap_spell(nec.spells.ignite, 12)
        elseif nec.OPTS.USEMANATAP and not config.USEALLIANCE and nec.OPTS.USEBUFFSHIELD then
            common.swap_spell(nec.spells.manatap, 8)
            common.swap_spell(nec.spells.ignite, 9)
            common.swap_spell(nec.spells.shield, 12)
        elseif not nec.OPTS.USEMANATAP and not config.USEALLIANCE and not nec.OPTS.USEBUFFSHIELD then
            common.swap_spell(nec.spells.ignite, 8)
            common.swap_spell(nec.spells.scourge, 9)
            common.swap_spell(nec.spells.corruption, 12)
        elseif not nec.OPTS.USEMANATAP and not config.USEALLIANCE and nec.OPTS.USEBUFFSHIELD then
            common.swap_spell(nec.spells.ignite, 8)
            common.swap_spell(nec.spells.scourge, 9)
            common.swap_spell(nec.spells.shield, 12)
        elseif not nec.OPTS.USEMANATAP and config.USEALLIANCE and nec.OPTS.USEBUFFSHIELD then
            common.swap_spell(nec.spells.ignite, 8)
            common.swap_spell(nec.spells.alliance, 9)
            common.swap_spell(nec.spells.shield, 12)
        elseif not nec.OPTS.USEMANATAP and config.USEALLIANCE and not nec.OPTS.USEBUFFSHIELD then
            common.swap_spell(nec.spells.ignite, 8)
            common.swap_spell(nec.spells.alliance, 9)
            common.swap_spell(nec.spells.scourge, 12)
        end
        if not nec.OPTS.USEWOUNDS then
            common.swap_spell(nec.spells.pyrelong, 10)
        else
            common.swap_spell(nec.spells.wounds, 10)
        end
    elseif config.SPELLSET == 'short' then
        if nec.OPTS.USEMANATAP and config.USEALLIANCE and nec.OPTS.USEINSPIRE then
            common.swap_spell(nec.spells.manatap, 8)
            common.swap_spell(nec.spells.alliance, 9)
            common.swap_spell(nec.spells.inspire, 12)
        elseif nec.OPTS.USEMANATAP and config.USEALLIANCE and not nec.OPTS.USEINSPIRE then
            common.swap_spell(nec.spells.manatap, 8)
            common.swap_spell(nec.spells.alliance, 9)
            common.swap_spell(nec.spells.venin, 12)
        elseif nec.OPTS.USEMANATAP and not config.USEALLIANCE and not nec.OPTS.USEINSPIRE then
            common.swap_spell(nec.spells.manatap, 8)
            common.swap_spell(nec.spells.ignite, 9)
            common.swap_spell(nec.spells.venin, 12)
        elseif nec.OPTS.USEMANATAP and not config.USEALLIANCE and nec.OPTS.USEINSPIRE then
            common.swap_spell(nec.spells.manatap, 8)
            common.swap_spell(nec.spells.ignite, 9)
            common.swap_spell(nec.spells.inspire, 12)
        elseif not nec.OPTS.USEMANATAP and not config.USEALLIANCE and not nec.OPTS.USEINSPIRE then
            common.swap_spell(nec.spells.ignite, 8)
            common.swap_spell(nec.spells.scourge, 9)
            common.swap_spell(nec.spells.venin, 12)
        elseif not nec.OPTS.USEMANATAP and not config.USEALLIANCE and nec.OPTS.USEINSPIRE then
            common.swap_spell(nec.spells.ignite, 8)
            common.swap_spell(nec.spells.scourge, 9)
            common.swap_spell(nec.spells.inspire, 12)
        elseif not nec.OPTS.USEMANATAP and config.USEALLIANCE and nec.OPTS.USEINSPIRE then
            common.swap_spell(nec.spells.ignite, 8)
            common.swap_spell(nec.spells.alliance, 9)
            common.swap_spell(nec.spells.inspire, 12)
        elseif not nec.OPTS.USEMANATAP and config.USEALLIANCE and not nec.OPTS.USEINSPIRE then
            common.swap_spell(nec.spells.ignite, 8)
            common.swap_spell(nec.spells.alliance, 9)
            common.swap_spell(nec.spells.venin, 12)
        end
    end
end

local nec_count_timer = timer:new(60)

-- if config.USEALLIANCE and nec_count_timer:timer_expired() then
--    get_necro_count()
--    nec_count_timer:reset()
-- end

nec.draw_burn_tab = function()
    nec.OPTS.BURNPROC = ui.draw_check_box('Burn On Proc', '##burnproc', nec.OPTS.BURNPROC, 'Burn when proliferation procs')
end

return nec