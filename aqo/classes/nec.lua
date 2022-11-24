--- @type Mq
local mq = require 'mq'
local class = require(AQO..'.classes.classbase')
local assist = require(AQO..'.routines.assist')
local logger = require(AQO..'.utils.logger')
local timer = require(AQO..'.utils.timer')
local common = require(AQO..'.common')
local config = require(AQO..'.configuration')
local state = require(AQO..'.state')
local ui = require(AQO..'.ui')

class.class = 'nec'
class.classOrder = {'assist', 'cast', 'burn', 'aggro', 'recover', 'rez', 'buff', 'rest', 'managepet'}

class.SPELLSETS = {standard=1,short=1}
class.addCommonOptions()
class.addCommonAbilities()
class.addOption('STOPPCT', 'DoT Stop Pct', 0, nil, 'Percent HP to stop refreshing DoTs on mobs', 'inputint')
class.addOption('DEBUFF', 'Debuff', true, nil, 'Debuff targets', 'checkbox') -- enable use of debuffs
class.addOption('USEBUFFSHIELD', 'Buff Shield', false, nil, 'Keep shield buff up. Replaces corruption DoT.', 'checkbox')
class.addOption('USEMANATAP', 'Mana Drain', false, nil, 'Use group mana drain dot. Replaces Ignite DoT.', 'checkbox')
class.addOption('USEREZ', 'Use Rez', true, nil, 'Use Convergence AA to rez group members', 'checkbox')
class.addOption('USEFD', 'Feign Death', true, nil, 'Use FD AA\'s to reduce aggro', 'checkbox')
class.addOption('USEINSPIRE', 'Inspire Ally', true, nil, 'Use Inspire Ally pet buff', 'checkbox')
class.addOption('USEDISPEL', 'Use Dispel', true, nil, 'Dispel mobs with Eradicate Magic AA', 'checkbox')
class.addOption('USEWOUNDS', 'Use Wounds', true, nil, 'Use wounds DoT', 'checkbox')
class.addOption('MULTIDOT', 'Multi DoT', false, nil, 'DoT all mobs', 'checkbox')
class.addOption('MULTICOUNT', 'Multi DoT #', 3, nil, 'Number of mobs to rotate through when multi-dot is enabled', 'inputint')

class.addSpell('composite', {'Composite Paroxysm', 'Dissident Paroxysm'})
class.addSpell('wounds', {'Infected Wounds', 'Septic Wounds'})
class.addSpell('fireshadow', {'Scalding Shadow', 'Broiling Shadow'})
class.addSpell('pyreshort', {'Pyre of Va Xakra', 'Pyre of Klraggek'})
class.addSpell('pyrelong', {'Pyre of the Neglected', 'Pyre of the Wretched'})
class.addSpell('venom', {'Hemorrhagic Venom', 'Crystal Crawler Venom', 'Poison Bolt'})
class.addSpell('magic', {'Extinction', 'Oblivion'})
class.addSpell('decay', {'Fleshrot\'s Decay', 'Danvid\'s Decay'})
class.addSpell('grip', {'Grip of Quietus', 'Grip of Zorglim'})
class.addSpell('haze', {'Zelnithak\'s Pallid Haze', 'Drachnia\'s Pallid Haze'})
class.addSpell('grasp', {'The Protector\'s Grasp', 'Tserrina\'s Grasp'})
class.addSpell('leech', {'Twilight Leech', 'Frozen Leech'})
class.addSpell('ignite', {'Ignite Cognition', 'Ignite Intellect'})
class.addSpell('scourge', {'Scourge of Destiny'})
class.addSpell('corruption', {'Decomposition', 'Miasma'})
-- Wounds proc
class.addSpell('proliferation', {'Infected Proliferation', 'Septic Proliferation'})
-- combo dot, outdated
--combodis', {'Danvid\'s Grip of Decay'},
-- Alliance
class.addSpell('alliance', {'Malevolent Coalition', 'Malevolent Covenant'})
-- Nukes
class.addSpell('synergy', {'Proclamation for Blood', 'Assert for Blood'})
class.addSpell('venin', {'Embalming Venin', 'Searing Venin', 'Lifespike'})
-- Debuffs
class.addSpell('scentterris', {'Scent of Terris'})
class.addSpell('scentmortality', {'Scent of The Grave', 'Scent of Mortality'})
-- Mana Drain
class.addSpell('manatap', {'Mind Atrophy', 'Mind Erosion'})
-- Buffs
class.addSpell('lich', {'Lunaside', 'Gloomside'})
class.addSpell('flesh', {'Flesh to Venom'})
class.addSpell('shield', {'Shield of Inevitability', 'Shield of Destiny'})
-- Pet spells
class.addSpell('pet', {'Unrelenting Assassin', 'Restless Assassin'})
class.addSpell('pethaste', {'Sigil of Undeath', 'Sigil of Decay'})
class.addSpell('petillusion', {'Form of Mottled Bone'})
class.addSpell('inspire', {'Inspire Ally', 'Incite Ally'})
class.addSpell('swarm', {'Call Skeleton Mass', 'Call Skeleton Horde'})

-- entries in the dots table are pairs of {spell id, spell name} in priority order
local standard = {}
table.insert(standard, class.spells.wounds)
table.insert(standard, class.spells.composite)
table.insert(standard, class.spells.pyreshort)
table.insert(standard, class.spells.venom)
table.insert(standard, class.spells.magic)
table.insert(standard, class.spells.decay)
table.insert(standard, class.spells.haze)
table.insert(standard, class.spells.grasp)
table.insert(standard, class.spells.fireshadow)
table.insert(standard, class.spells.leech)
table.insert(standard, class.spells.grip)
table.insert(standard, class.spells.pyrelong)
table.insert(standard, class.spells.ignite)
table.insert(standard, class.spells.scourge)
table.insert(standard, class.spells.corruption)

local short = {}
table.insert(short, class.spells.swarm)
table.insert(short, class.spells.composite)
table.insert(short, class.spells.pyreshort)
table.insert(short, class.spells.venom)
table.insert(short, class.spells.magic)
table.insert(short, class.spells.decay)
table.insert(short, class.spells.haze)
table.insert(short, class.spells.grasp)
table.insert(short, class.spells.fireshadow)
table.insert(short, class.spells.leech)
table.insert(short, class.spells.grip)
table.insert(short, class.spells.pyrelong)
table.insert(short, class.spells.ignite)

class.spellRotations = {
    standard=standard,
    short=short,
}

local swap_gem = nil
local swap_gem_dis = nil

-- entries in the items table are MQ item datatypes
table.insert(class.burnAbilities, common.getItem(mq.TLO.InvSlot('Chest').Item.Name()))
table.insert(class.burnAbilities, common.getItem('Rage of Rolfron'))
table.insert(class.burnAbilities, common.getItem('Blightbringer\'s Tunic of the Grave')) -- buff, 5 minute CD
--table.insert(items, common.getItem('Vicious Rabbit')) -- 5 minute CD
--table.insert(items, common.getItem('Necromantic Fingerbone')) -- 3 minute CD
--table.insert(items, common.getItem('Amulet of the Drowned Mariner')) -- 5 minute CD

local pre_burn_items = {}
table.insert(pre_burn_items, common.getItem('Blightbringer\'s Tunic of the Grave')) -- buff
table.insert(pre_burn_items, common.getItem(mq.TLO.InvSlot('Chest').Item.Name())) -- buff, Consuming Magic

-- entries in the AAs table are pairs of {aa name, aa id}
table.insert(class.burnAbilities, common.getAA('Silent Casting')) -- song, 12 minute CD
table.insert(class.burnAbilities, common.getAA('Focus of Arcanum')) -- buff, 10 minute CD
table.insert(class.burnAbilities, common.getAA('Mercurial Torment')) -- buff, 24 minute CD
table.insert(class.burnAbilities, common.getAA('Heretic\'s Twincast')) -- buff, 15 minute CD
table.insert(class.burnAbilities, common.getAA('Spire of Necromancy')) -- buff, 7:30 minute CD
table.insert(class.burnAbilities, common.getAA('Hand of Death')) -- song, 8:30 minute CD
table.insert(class.burnAbilities, common.getAA('Gathering Dusk')) -- song, Duskfall Empowerment, 10 minute CD
table.insert(class.burnAbilities, common.getAA('Companion\'s Fury')) -- 10 minute CD
table.insert(class.burnAbilities, common.getAA('Companion\'s Fortification')) -- 15 minute CD
table.insert(class.burnAbilities, common.getAA('Rise of Bones', {delay=1500})) -- 10 minute CD
table.insert(class.burnAbilities, common.getAA('Swarm of Decay', {delay=1500})) -- 9 minute CD

local glyph = common.getAA('Mythic Glyph of Ultimate Power V')
local intensity = common.getAA('Intensity of the Resolute')

local wakethedead = common.getAA('Wake the Dead') -- 3 minute CD

local funeralpyre = common.getAA('Funeral Pyre') -- song, 20 minute CD

local pre_burn_AAs = {}
table.insert(pre_burn_AAs, common.getAA('Focus of Arcanum')) -- buff
table.insert(pre_burn_AAs, common.getAA('Mercurial Torment')) -- buff
table.insert(pre_burn_AAs, common.getAA('Heretic\'s Twincast')) -- buff
table.insert(pre_burn_AAs, common.getAA('Spire of Necromancy')) -- buff

local tcclick = common.getItem('Bifold Focus of the Evil Eye')

-- lifeburn/dying grasp combo
local lifeburn = common.getAA('Life Burn')
local dyinggrasp = common.getAA('Dying Grasp')
-- Buffs
local unity = common.getAA('Mortifier\'s Unity')
-- Mana Recovery AAs
local deathbloom = common.getAA('Death Bloom')
local bloodmagic = common.getAA('Blood Magic')
-- Agro
local deathpeace = common.getAA('Death Peace')
local deathseffigy = common.getAA('Death\'s Effigy')

local convergence = common.getAA('Convergence')
local dispel = common.getAA('Eradicate Magic')

local scent = common.getAA('Scent of Thule')
local debuff_timer = timer:new(30)

local buffs={
    self={},
    pet={
        class.spells.pethaste,
        class.spells.petillusion,
    },
}

local neccount = 1

-- Determine swap gem based on wherever wounds, broiling shadow or pyre of the wretched is currently mem'd
local function set_swap_gems()
    swap_gem = mq.TLO.Me.Gem(class.spells.wounds and class.spells.wounds.name or 'unknown')() or
            mq.TLO.Me.Gem(class.spells.fireshadow and class.spells.fireshadow.name or 'unknown')() or
            mq.TLO.Me.Gem(class.spells.pyrelong and class.spells.pyrelong.name or 'unknown')() or 10
    swap_gem_dis = mq.TLO.Me.Gem(class.spells.decay and class.spells.decay.name or 'unknown')() or mq.TLO.Me.Gem(class.spells.grip and class.spells.grip.name or 'unknown')() or 11
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

class.reset_class_timers = function()
    debuff_timer:reset(0)
end

local function should_swap_dots()
    -- Only swap spells in standard spell set
    if state.spellset_loaded ~= 'standard' or mq.TLO.Me.Moving() then return end

    local woundsName = class.spells.wounds and class.spells.wounds.name
    local pyrelongName = class.spells.pyrelong and class.spells.pyrelong.name
    local fireshadowName = class.spells.fireshadow and class.spells.fireshadow.name
    local woundsDuration = mq.TLO.Target.MyBuffDuration(woundsName)()
    local pyrelongDuration = mq.TLO.Target.MyBuffDuration(pyrelongName)()
    local fireshadowDuration = mq.TLO.Target.MyBuffDuration(fireshadowName)()
    if mq.TLO.Me.Gem(woundsName)() then
        if not class.OPTS.USEWOUNDS.value or (woundsDuration and woundsDuration > 20000) then
            if not pyrelongDuration or pyrelongDuration < 20000 then
                common.swap_spell(class.spells.pyrelong, swap_gem or 10)
            elseif not fireshadowDuration or fireshadowDuration < 20000 then
                common.swap_spell(class.spells.fireshadow, swap_gem or 10)
            end
        end
    elseif mq.TLO.Me.Gem(pyrelongName)() then
        if pyrelongDuration and pyrelongDuration > 20000 then
            if class.OPTS.USEWOUNDS.value and (not woundsDuration or woundsDuration < 20000) then
                common.swap_spell(class.spells.wounds, swap_gem or 10)
            elseif not fireshadowDuration or fireshadowDuration < 20000 then
                common.swap_spell(class.spells.fireshadow, swap_gem or 10)
            end
        end
    elseif mq.TLO.Me.Gem(fireshadowName)() then
        if fireshadowDuration and fireshadowDuration > 20000 then
            if class.OPTS.USEWOUNDS.value and (not woundsDuration or woundsDuration < 20000) then
                common.swap_spell(class.spells.wounds, swap_gem or 10)
            elseif not pyrelongDuration or pyrelongDuration < 20000 then
                common.swap_spell(class.spells.pyrelong, swap_gem or 10)
            end
        end
    else
        -- maybe we got interrupted or something and none of these are mem'd anymore? just memorize wounds again
        common.swap_spell(class.spells.wounds, swap_gem or 10)
    end

    local decayName = class.spells.decay and class.spells.decay.name
    local gripName = class.spells.grip and class.spells.grip.name
    local decayDuration = mq.TLO.Target.MyBuffDuration(decayName)()
    local gripDuration = mq.TLO.Target.MyBuffDuration(gripName)()
    if mq.TLO.Me.Gem(decayName)() then
        if decayDuration and decayDuration > 20000 then
            if not gripDuration or gripDuration < 20000 then
                common.swap_spell(class.spells.grip, swap_gem_dis or 11)
            end
        end
    elseif mq.TLO.Me.Gem(gripName)() then
        if gripDuration and gripDuration > 20000 then
            if not decayDuration or decayDuration < 20000 then
                common.swap_spell(class.spells.decay, swap_gem_dis or 11)
            end
        end
    else
        -- maybe we got interrupted or something and none of these are mem'd anymore? just memorize decay again
        common.swap_spell(class.spells.decay, swap_gem_dis or 11)
    end
end

-- Casts alliance if we are fighting, alliance is enabled, the spell is ready, alliance isn't already on the mob, there is > 1 necro in group or raid, and we have at least a few dots on the mob.
local function try_alliance()
    if class.OPTS.USEALLIANCE.value and class.spells.alliance then
        if mq.TLO.Spell(class.spells.alliance.name).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        if mq.TLO.Me.SpellReady(class.spells.alliance.name)() and neccount > 1 and not mq.TLO.Target.Buff(class.spells.alliance.name)() and mq.TLO.Spell(class.spells.alliance.name).StacksTarget() then
            -- pick the first 3 dots in the rotation as they will hopefully always be up given their priority
            if mq.TLO.Target.MyBuff(class.spells.pyreshort and class.spells.pyreshort.name)() and
                    mq.TLO.Target.MyBuff(class.spells.venom and class.spells.venom.name)() and
                    mq.TLO.Target.MyBuff(class.spells.magic and class.spells.magic.name)() then
                class.spells.alliance:use()
                return true
            end
        end
    end
    return false
end

local function cast_synergy()
    if class.spells.synergy and not mq.TLO.Me.Song('Defiler\'s Synergy')() and mq.TLO.Me.SpellReady(class.spells.synergy.name)() then
        if mq.TLO.Spell(class.spells.synergy.name).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        -- don't bother with proc'ing synergy until we've got most dots applied
        if mq.TLO.Target.MyBuff(class.spells.pyreshort and class.spells.pyreshort.name)() and
                    mq.TLO.Target.MyBuff(class.spells.venom and class.spells.venom.name)() and
                    mq.TLO.Target.MyBuff(class.spells.magic and class.spells.magic.name)() then
            class.spells.synergy:use()
            return true
        end
    end
    return false
end

local function find_next_dot_to_cast()
    if try_alliance() then return nil end
    if cast_synergy() then return nil end
    -- Just cast composite as part of the normal dot rotation, no special handling
    --if common.is_spell_ready(spells.composite.id, spells.composite.name) then
    --    return spells.composite.id, spells.composite.name
    --end
    if class.spells.manatap and mq.TLO.Me.PctMana() < 40 and mq.TLO.Me.SpellReady(class.spells.manatap.name)() and mq.TLO.Spell(class.spells.manatap.name).Mana() < mq.TLO.Me.CurrentMana() then
        return class.spells.manatap
    end
    if class.spells.swarm and class.OPTS.SPELLSET.value == 'short' and mq.TLO.Me.SpellReady(class.spells.swarm.name)() and mq.TLO.Spell(class.spells.swarm.name).Mana() < mq.TLO.Me.CurrentMana() then
        return class.spells.swarm
    end
    local pct_hp = mq.TLO.Target.PctHPs()
    if pct_hp and pct_hp > class.OPTS.STOPPCT.value then
        for _,dot in ipairs(class.spellRotations[class.OPTS.SPELLSET.value]) do -- iterates over the dots array. ipairs(dots) returns 2 values, an index and its value in the array. we don't care about the index, we just want the dot
            -- ToL has no combo disease dot spell, so the 2 disease dots are just in the normal rotation now.
            -- if spell_id == spells.combodis.id then
            --     if (not is_target_dotted_with(spells.decay.id, spells.decay.name) or not is_target_dotted_with(spells.grip.id, spells.grip.name)) and mq.TLO.Me.SpellReady(spells.combodis.name)() then
            --         return dot
            --     end
            -- else
            if (class.OPTS.USEWOUNDS.value or dot.id ~= class.spells.wounds.id) and common.is_spell_ready(dot) then
                return dot -- if is_dot_ready returned true then return this dot as the dot we should cast
            end
        end
    end
    if class.spells.manatap and mq.TLO.Me.SpellReady(class.spells.manatap.name)() and mq.TLO.Spell(class.spells.manatap.name).Mana() < mq.TLO.Me.CurrentMana() then
        return class.spells.manatap
    end
    if class.spells.venin and class.OPTS.SPELLSET.value == 'short' and mq.TLO.Me.SpellReady(class.spells.venin.name)() and mq.TLO.Spell(class.spells.venin.name).Mana() < mq.TLO.Me.CurrentMana() then
        return class.spells.venin
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

class.cast = function()
    if mq.TLO.Me.SpellInCooldown() then return false end
    if assist.is_fighting() then
        if class.OPTS.USEDISPEL.value and mq.TLO.Target.Beneficial() then
            dispel:use()
        end
        if class.OPTS.DEBUFF.value and class.spells.scentterris and not mq.TLO.Target.Buff(class.spells.scentterris.name)() and mq.TLO.Spell(class.spells.scentterris.name).StacksTarget() then
            scent:use()
            debuff_timer:reset()
        end
        local spell = find_next_dot_to_cast() -- find the first available dot to cast that is missing from the target
        if spell then -- if a dot was found
            if spell.name == class.spells.pyreshort.name and not mq.TLO.Me.Buff('Heretic\'s Twincast')() then
                tcclick:use()
            end
            spell:use() -- then cast the dot
        end

        if class.OPTS.MULTIDOT.value then
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
                            spell:use()
                            dotted_count = dotted_count + 1
                            if dotted_count >= class.OPTS.MULTICOUNT.value then break end
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
    if not mq.TLO.Target.MyBuff(class.spells.proliferation and class.spells.proliferation.name)() then return false else return true end
end

local function is_nec_burn_condition_met()
    if class.OPTS.BURNPROC.value and target_has_proliferation() then
        logger.printf('\arActivating Burns (proliferation proc)\ax')
        state.burn_active_timer:reset()
        state.burn_active = true
        return true
    end
end

class.always_condition = function()
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
class.burn_class = function()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag.
    -- Test them both for each item, and see which one(s) actually work.
    --if common.is_burn_condition_met(class.always_condition) or is_nec_burn_condition_met() then
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
        wakethedead:use()
        mq.delay(1500)
    end

    if class.OPTS.USEGLYPH.value and intensity and glyph then
        if not mq.TLO.Me.Song(intensity.name)() and mq.TLO.Me.Buff('heretic\'s twincast')() then
            glyph:use()
        end
    end
    if class.OPTS.USEINTENSITY.value and glyph and intensity then
        if not mq.TLO.Me.Buff(glyph.name)() and mq.TLO.Me.Buff('heretic\'s twincast')() then
            intensity:use()
        end
    end

    if mq.TLO.Me.PctHPs() > 90 and mq.TLO.Me.AltAbilityReady('Life Burn')() and mq.TLO.Me.AltAbilityReady('Dying Grasp')() then
        lifeburn:use()
        mq.delay(5)
        dyinggrasp:use()
    end
end

local function pre_pop_burns()
    logger.printf('Pre-burn')
    --[[
    |===========================================================================================
    |Item Burn
    |===========================================================================================
    ]]--

    for _,item in ipairs(pre_burn_items) do
        item:use()
    end

    --[[
    |===========================================================================================
    |Spell Burn
    |===========================================================================================
    ]]--

    for _,aa in ipairs(pre_burn_AAs) do
        aa:use()
    end

    if class.OPTS.USEGLYPH.value and intensity and glyph then
        if not mq.TLO.Me.Song(intensity.name)() and mq.TLO.Me.Buff('heretic\'s twincast')() then
            glyph:use()
        end
    end
end

class.recover = function()
    -- modrods
    common.check_mana()
    local pct_mana = mq.TLO.Me.PctMana()
    if pct_mana < 65 then
        -- death bloom at some %
        deathbloom:use()
    end
    if mq.TLO.Me.CombatState() == 'COMBAT' then
        if pct_mana < 40 then
            -- blood magic at some %
            bloodmagic:use()
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
class.aggro = function()
    if config.MODE:is_manual_mode() then return end
    if class.OPTS.USEFD.value and mq.TLO.Me.CombatState() == 'COMBAT' and mq.TLO.Target() then
        if mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID() or check_aggro_timer:timer_expired() then
            if mq.TLO.Me.PctAggro() >= 90 then
                if mq.TLO.Me.PctHPs() < 40 and mq.TLO.Me.AltAbilityReady('Dying Grasp')() then
                    dyinggrasp:use()
                end
                deathseffigy:use()
                if mq.TLO.Me.Feigning() then
                    check_aggro_timer:reset()
                    mq.delay(500)
                    if safe_to_stand() then
                        mq.TLO.Me.Sit() -- Use a sit TLO to stand up, what wizardry is this?
                        mq.cmd('/makemevis')
                    end
                end
            elseif mq.TLO.Me.PctAggro() >= 70 then
                deathpeace:use()
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
class.rez = function()
    if not class.OPTS.USEREZ.value or not convergence or common.am_i_dead() then return end
    if not rez_timer:timer_expired() then return end
    if not mq.TLO.Me.AltAbilityReady(convergence.name)() then return end
    if mq.TLO.FindItemCount('=Essence Emerald')() == 0 then return end
    if mq.TLO.SpawnCount('pccorpse group healer radius 100')() > 0 then
        mq.TLO.Spawn('pccorpse group healer radius 100').DoTarget()
        mq.cmd('/corpse')
        convergence:use()
        rez_timer:reset()
        return
    end
    if mq.TLO.SpawnCount('pccorpse raid healer radius 100')() > 0 then
        mq.TLO.Spawn('pccorpse raid healer radius 100').DoTarget()
        mq.cmd('/corpse')
        convergence:use()
        rez_timer:reset()
        return
    end
    if mq.TLO.Group.MainTank() and mq.TLO.Group.MainTank.Dead() then
        mq.TLO.Group.MainTank.DoTarget()
        local corpse_x = mq.TLO.Target.X()
        local corpse_y = mq.TLO.Target.Y()
        if corpse_x and corpse_y and common.check_distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), corpse_x, corpse_y) > 100 then return end
        mq.cmd('/corpse')
        convergence:use()
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
                convergence:use()
                rez_timer:reset()
                return
            end
        end
    end
end

class.buff = function()
    if common.am_i_dead() or mq.TLO.Me.Moving() then return end
    if class.OPTS.USEBUFFSHIELD.value and class.spells.shield then
        local tempName = class.spells.shield.name
        if state.subscription ~= 'GOLD' then tempName = tempName:gsub(' Rk%..*', '') end
        if not mq.TLO.Me.Buff(tempName)() then
            class.spells.shield:use()
        end
    end
    if class.OPTS.USEINSPIRE.value and class.spells.inspire then
        local tempName = class.spells.inspire.name
        if state.subscription ~= 'GOLD' then tempName = tempName:gsub(' Rk%..*', '') end
        if not mq.TLO.Pet.Buff(tempName)() then
            class.spells.inspire:use()
        end
    end
    common.check_combat_buffs()
    if not common.clear_to_buff() then return end
    --if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.get_camp_radius()))() > 0 then return end
    if class.spells.lich and not mq.TLO.Me.Buff(class.spells.lich.name)() or not mq.TLO.Me.Buff(class.spells.flesh.name)() then
        unity:use()
    end

    common.check_item_buffs()

    if class.OPTS.BUFFPET.value and mq.TLO.Pet.ID() > 0 then
        for _,buff in ipairs(buffs.pet) do
            local tempName = buff.name
            if state.subscription ~= 'GOLD' then tempName = tempName:gsub(' Rk%..*', '') end
            if not mq.TLO.Pet.Buff(tempName)() and mq.TLO.Spell(buff.name).StacksPet() and mq.TLO.Spell(buff.name).Mana() < mq.TLO.Me.CurrentMana() then
                common.swap_and_cast(buff, 13)
            end
        end
    end
end

local composite_names = {['Composite Paroxysm']=true, ['Dissident Paroxysm']=true, ['Dichotomic Paroxysm']=true}
local check_spell_timer = timer:new(30)
class.check_spell_set = function()
    if not common.clear_to_buff() or mq.TLO.Me.Moving() or common.am_i_dead() then return end
    if state.spellset_loaded ~= class.OPTS.SPELLSET.value or check_spell_timer:timer_expired() then
        if class.OPTS.SPELLSET.value == 'standard' then
            common.swap_spell(class.spells.composite, 1, composite_names)
            common.swap_spell(class.spells.pyreshort, 2)
            common.swap_spell(class.spells.venom, 3)
            common.swap_spell(class.spells.magic, 4)
            common.swap_spell(class.spells.haze, 5)
            common.swap_spell(class.spells.grasp, 6)
            common.swap_spell(class.spells.leech, 7)
            --common.swap_spell(spells.wounds, 10)
            common.swap_spell(class.spells.decay, 11)
            common.swap_spell(class.spells.synergy, 13)
            state.spellset_loaded = class.OPTS.SPELLSET.value
        elseif class.OPTS.SPELLSET.value == 'short' then
            common.swap_spell(class.spells.composite, 1, composite_names)
            common.swap_spell(class.spells.pyreshort, 2)
            common.swap_spell(class.spells.venom, 3)
            common.swap_spell(class.spells.magic, 4)
            common.swap_spell(class.spells.haze, 5)
            common.swap_spell(class.spells.grasp, 6)
            common.swap_spell(class.spells.leech, 7)
            common.swap_spell(class.spells.swarm, 10)
            common.swap_spell(class.spells.decay, 11)
            common.swap_spell(class.spells.synergy, 13)
            state.spellset_loaded = class.OPTS.SPELLSET.value
        end
        check_spell_timer:reset()
        set_swap_gems()
    end
    if class.OPTS.SPELLSET.value == 'standard' then
        if class.OPTS.USEMANATAP.value and class.OPTS.USEALLIANCE.value and class.OPTS.USEBUFFSHIELD.value then
            common.swap_spell(class.spells.manatap, 8)
            common.swap_spell(class.spells.alliance, 9)
            common.swap_spell(class.spells.shield, 12)
        elseif class.OPTS.USEMANATAP.value and class.OPTS.USEALLIANCE.value and not class.OPTS.USEBUFFSHIELD.value then
            common.swap_spell(class.spells.manatap, 8)
            common.swap_spell(class.spells.alliance, 9)
            common.swap_spell(class.spells.ignite, 12)
        elseif class.OPTS.USEMANATAP.value and not class.OPTS.USEALLIANCE.value and not class.OPTS.USEBUFFSHIELD.value then
            common.swap_spell(class.spells.manatap, 8)
            common.swap_spell(class.spells.scourge, 9)
            common.swap_spell(class.spells.ignite, 12)
        elseif class.OPTS.USEMANATAP.value and not class.OPTS.USEALLIANCE.value and class.OPTS.USEBUFFSHIELD.value then
            common.swap_spell(class.spells.manatap, 8)
            common.swap_spell(class.spells.ignite, 9)
            common.swap_spell(class.spells.shield, 12)
        elseif not class.OPTS.USEMANATAP.value and not class.OPTS.USEALLIANCE.value and not class.OPTS.USEBUFFSHIELD.value then
            common.swap_spell(class.spells.ignite, 8)
            common.swap_spell(class.spells.scourge, 9)
            common.swap_spell(class.spells.corruption, 12)
        elseif not class.OPTS.USEMANATAP.value and not class.OPTS.USEALLIANCE.value and class.OPTS.USEBUFFSHIELD.value then
            common.swap_spell(class.spells.ignite, 8)
            common.swap_spell(class.spells.scourge, 9)
            common.swap_spell(class.spells.shield, 12)
        elseif not class.OPTS.USEMANATAP.value and class.OPTS.USEALLIANCE.value and class.OPTS.USEBUFFSHIELD.value then
            common.swap_spell(class.spells.ignite, 8)
            common.swap_spell(class.spells.alliance, 9)
            common.swap_spell(class.spells.shield, 12)
        elseif not class.OPTS.USEMANATAP.value and class.OPTS.USEALLIANCE.value and not class.OPTS.USEBUFFSHIELD.value then
            common.swap_spell(class.spells.ignite, 8)
            common.swap_spell(class.spells.alliance, 9)
            common.swap_spell(class.spells.scourge, 12)
        end
        if not class.OPTS.USEWOUNDS then
            common.swap_spell(class.spells.pyrelong, 10)
        else
            common.swap_spell(class.spells.wounds, 10)
        end
    elseif class.OPTS.SPELLSET.value == 'short' then
        if class.OPTS.USEMANATAP.value and class.OPTS.USEALLIANCE.value and class.OPTS.USEINSPIRE.value then
            common.swap_spell(class.spells.manatap, 8)
            common.swap_spell(class.spells.alliance, 9)
            common.swap_spell(class.spells.inspire, 12)
        elseif class.OPTS.USEMANATAP.value and class.OPTS.USEALLIANCE.value and not class.OPTS.USEINSPIRE.value then
            common.swap_spell(class.spells.manatap, 8)
            common.swap_spell(class.spells.alliance, 9)
            common.swap_spell(class.spells.venin, 12)
        elseif class.OPTS.USEMANATAP.value and not class.OPTS.USEALLIANCE.value and not class.OPTS.USEINSPIRE.value then
            common.swap_spell(class.spells.manatap, 8)
            common.swap_spell(class.spells.ignite, 9)
            common.swap_spell(class.spells.venin, 12)
        elseif class.OPTS.USEMANATAP.value and not class.OPTS.USEALLIANCE.value and class.OPTS.USEINSPIRE.value then
            common.swap_spell(class.spells.manatap, 8)
            common.swap_spell(class.spells.ignite, 9)
            common.swap_spell(class.spells.inspire, 12)
        elseif not class.OPTS.USEMANATAP.value and not class.OPTS.USEALLIANCE.value and not class.OPTS.USEINSPIRE.value then
            common.swap_spell(class.spells.ignite, 8)
            common.swap_spell(class.spells.scourge, 9)
            common.swap_spell(class.spells.venin, 12)
        elseif not class.OPTS.USEMANATAP.value and not class.OPTS.USEALLIANCE.value and class.OPTS.USEINSPIRE.value then
            common.swap_spell(class.spells.ignite, 8)
            common.swap_spell(class.spells.scourge, 9)
            common.swap_spell(class.spells.inspire, 12)
        elseif not class.OPTS.USEMANATAP.value and class.OPTS.USEALLIANCE.value and class.OPTS.USEINSPIRE.value then
            common.swap_spell(class.spells.ignite, 8)
            common.swap_spell(class.spells.alliance, 9)
            common.swap_spell(class.spells.inspire, 12)
        elseif not class.OPTS.USEMANATAP.value and class.OPTS.USEALLIANCE.value and not class.OPTS.USEINSPIRE.value then
            common.swap_spell(class.spells.ignite, 8)
            common.swap_spell(class.spells.alliance, 9)
            common.swap_spell(class.spells.venin, 12)
        end
    end
end

local nec_count_timer = timer:new(60)

-- if class.OPTS.USEALLIANCE.value and nec_count_timer:timer_expired() then
--    get_necro_count()
--    nec_count_timer:reset()
-- end

class.draw_burn_tab = function()
    class.OPTS.BURNPROC.value = ui.draw_check_box('Burn On Proc', '##burnproc', class.OPTS.BURNPROC.value, 'Burn when proliferation procs')
end

return class