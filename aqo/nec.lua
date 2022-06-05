--- @type mq
local mq = require 'mq'
local common = require('aqo.common')
local ui = require('aqo.ui')
local persistence = require('aqo.persistence')

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
}
common.OPTS.SPELLSET = 'standard'

-- All spells ID + Rank name
local spells = {
    ['wounds']=common.get_spellid_and_rank('Infected Wounds'),
    ['fireshadow']=common.get_spellid_and_rank('Scalding Shadow'),
    ['combodis']=common.get_spellid_and_rank('Danvid\'s Grip of Decay'),
    ['pyreshort']=common.get_spellid_and_rank('Pyre of Va Xakra'),
    ['pyrelong']=common.get_spellid_and_rank('Pyre of the Neglected'),
    ['venom']=common.get_spellid_and_rank('Hemorrhagic Venom'),
    ['magic']=common.get_spellid_and_rank('Extinction'),
    ['haze']=common.get_spellid_and_rank('Zelnithak\'s Pallid Haze'),
    ['grasp']=common.get_spellid_and_rank('The Protector\'s Grasp'),
    ['leech']=common.get_spellid_and_rank('Twilight Leech'),
    ['ignite']=common.get_spellid_and_rank('Ignite Cognition'),
    ['scourge']=common.get_spellid_and_rank('Scourge of Destiny'),
    ['corruption']=common.get_spellid_and_rank('Decomposition'),
    ['alliance']=common.get_spellid_and_rank('Malevolent Coalition'),
    ['synergy']=common.get_spellid_and_rank('Proclamation for Blood'),
    ['composite']=common.get_spellid_and_rank('Composite Paroxysm'),
    ['decay']=common.get_spellid_and_rank('Fleshrot\'s Decay'),
    ['grip']=common.get_spellid_and_rank('Grip of Quietus'),
    ['proliferation']=common.get_spellid_and_rank('Infected Proliferation'),
    ['scentterris']=common.get_spellid_and_rank('Scent of Terris'),
    ['scentmortality']=common.get_spellid_and_rank('Scent of The Grave'),
    ['swarm']=common.get_spellid_and_rank('Call Skeleton Mass'),
    ['venin']=common.get_spellid_and_rank('Embalming Venin'),
    ['lich']=common.get_spellid_and_rank('Lunaside'),
    ['flesh']=common.get_spellid_and_rank('Flesh to Venom'),
    ['pet']=common.get_spellid_and_rank('Unrelenting Assassin'),
    ['pethaste']=common.get_spellid_and_rank('Sigil of Undeath'),
    ['shield']=common.get_spellid_and_rank('Shield of Inevitability'),
    ['manatap']=common.get_spellid_and_rank('Mind Atrophy'),
    ['petillusion']=common.get_spellid_and_rank('Form of Mottled Bone'),
    ['inspire']=common.get_spellid_and_rank('Inspire Ally'),
}
for name,spell in pairs(spells) do
    if spell['name'] then
        common.printf('[%s] Found spell: %s (%s)', name, spell['name'], spell['id'])
    else
        common.printf('[%s] Could not find spell!', name)
    end
end

-- entries in the dots table are pairs of {spell id, spell name} in priority order
local standard = {}
table.insert(standard, spells['wounds'])
table.insert(standard, spells['composite'])
table.insert(standard, spells['pyreshort'])
table.insert(standard, spells['venom'])
table.insert(standard, spells['magic'])
table.insert(standard, spells['decay'])
table.insert(standard, spells['haze'])
table.insert(standard, spells['grasp'])
table.insert(standard, spells['fireshadow'])
table.insert(standard, spells['leech'])
table.insert(standard, spells['grip'])
table.insert(standard, spells['pyrelong'])
table.insert(standard, spells['ignite'])
table.insert(standard, spells['scourge'])
table.insert(standard, spells['corruption'])

local short = {}
table.insert(short, spells['swarm'])
table.insert(short, spells['composite'])
table.insert(short, spells['pyreshort'])
table.insert(short, spells['venom'])
table.insert(short, spells['magic'])
table.insert(short, spells['decay'])
table.insert(short, spells['haze'])
table.insert(short, spells['grasp'])
table.insert(short, spells['fireshadow'])
table.insert(short, spells['leech'])
table.insert(short, spells['grip'])
table.insert(short, spells['pyrelong'])
table.insert(short, spells['ignite'])

local dots = {
    ['standard']=standard,
    ['short']=short,
}

-- Determine swap gem based on wherever wounds, broiling shadow or pyre of the wretched is currently mem'd
local swap_gem = mq.TLO.Me.Gem(spells['wounds']['name'])() or mq.TLO.Me.Gem(spells['fireshadow']['name'])() or mq.TLO.Me.Gem(spells['pyrelong']['name'])()
local swap_gem_dis = mq.TLO.Me.Gem(spells['decay']['name'])() or mq.TLO.Me.Gem(spells['grip']['name'])()

-- entries in the items table are MQ item datatypes
local items = {}
table.insert(items, mq.TLO.FindItem('Blightbringer\'s Tunic of the Grave').ID()) -- buff, 5 minute CD
table.insert(items, mq.TLO.InvSlot('Chest').Item.ID()) -- buff, Consuming Magic, 10 minute CD
table.insert(items, mq.TLO.FindItem('Rage of Rolfron').ID()) -- song, 30 minute CD

--table.insert(items, mq.TLO.FindItem('Bifold Focus of the Evil Eye').ID())
--table.insert(items, mq.TLO.FindItem('Necromantic Fingerbone').ID()) -- 3 minute CD
--table.insert(items, mq.TLO.FindItem('Amulet of the Drowned Mariner').ID()) -- 5 minute CD

local pre_burn_items = {}
table.insert(pre_burn_items, mq.TLO.FindItem('Blightbringer\'s Tunic of the Grave').ID()) -- buff
table.insert(pre_burn_items, mq.TLO.InvSlot('Chest').Item.ID()) -- buff, Consuming Magic

-- entries in the AAs table are pairs of {aa name, aa id}
local AAs = {}
table.insert(AAs, common.get_aaid_and_name('Silent Casting')) -- song, 12 minute CD
table.insert(AAs, common.get_aaid_and_name('Focus of Arcanum')) -- buff, 10 minute CD
table.insert(AAs, common.get_aaid_and_name('Mercurial Torment')) -- buff, 24 minute CD
table.insert(AAs, common.get_aaid_and_name('Heretic\'s Twincast')) -- buff, 15 minute CD
table.insert(AAs, common.get_aaid_and_name('Spire of Necromancy')) -- buff, 7:30 minute CD
table.insert(AAs, common.get_aaid_and_name('Hand of Death')) -- song, 8:30 minute CD
table.insert(AAs, common.get_aaid_and_name('Funeral Pyre')) -- song, 20 minute CD
table.insert(AAs, common.get_aaid_and_name('Gathering Dusk')) -- song, Duskfall Empowerment, 10 minute CD
table.insert(AAs, common.get_aaid_and_name('Companion\'s Fury')) -- 10 minute CD
table.insert(AAs, common.get_aaid_and_name('Companion\'s Fortification')) -- 15 minute CD
table.insert(AAs, common.get_aaid_and_name('Rise of Bones')) -- 10 minute CD
table.insert(AAs, common.get_aaid_and_name('Wake the Dead')) -- 3 minute CD
table.insert(AAs, common.get_aaid_and_name('Swarm of Decay')) -- 9 minute CD

--table.insert(AAs, get_aaid_and_name('Life Burn')) -- 20 minute CD
--table.insert(AAs, get_aaid_and_name('Dying Grasp')) -- 20 minute CD

--table.insert(AAs, get_aaid_and_name('Glyph of Destruction (115+)'))
--table.insert(AAs, get_aaid_and_name('Intensity of the Resolute'))

local pre_burn_AAs = {}
table.insert(pre_burn_AAs, common.get_aaid_and_name('Focus of Arcanum')) -- buff
table.insert(pre_burn_AAs, common.get_aaid_and_name('Mercurial Torment')) -- buff
table.insert(pre_burn_AAs, common.get_aaid_and_name('Heretic\'s Twincast')) -- buff
table.insert(pre_burn_AAs, common.get_aaid_and_name('Spire of Necromancy')) -- buff

-- lifeburn/dying grasp combo
local lifeburn = common.get_aaid_and_name('Life Burn')
local dyinggrasp = common.get_aaid_and_name('Dying Grasp')
-- Buffs
local unity = common.get_aaid_and_name('Mortifier\'s Unity')
-- Mana Recovery AAs
local deathbloom = common.get_aaid_and_name('Death Bloom')
local bloodmagic = common.get_aaid_and_name('Blood Magic')
-- Mana Recovery items
--local item_feather = mq.TLO.FindItem('Unified Phoenix Feather')
--local item_horn = mq.TLO.FindItem('Miniature Horn of Unity') -- 10 minute CD
-- Agro
local deathpeace = common.get_aaid_and_name('Death Peace')
local deathseffigy = common.get_aaid_and_name('Death\'s Effigy')

local convergence = common.get_aaid_and_name('Convergence')

local buffs={
    ['self']={},
    ['pet']={
        spells['pethaste'],
        spells['petillusion'],
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
    local settings = common.load_settings(SETTINGS_FILE)
    if not settings or not settings.nec then return end
    if settings.nec.STOPPCT ~= nil then OPTS.STOPPCT = settings.nec.STOPPCT end
    if settings.nec.DEBUFF ~= nil then OPTS.DEBUFF = settings.nec.DEBUFF end
    if settings.nec.SUMMONPET ~= nil then OPTS.SUMMONPET = settings.nec.SUMMONPET end
    if settings.nec.BUFFPET ~= nil then OPTS.BUFFPET = settings.nec.BUFFPET end
    if settings.nec.USEBUFFSHIELD ~= nil then OPTS.USEBUFFSHIELD = settings.nec.USEBUFFSHIELD end
    if settings.nec.USEMANATAP ~= nil then OPTS.USEMANATAP = settings.nec.USEMANATAP end
    if settings.nec.USEFD ~= nil then OPTS.USEFD = settings.nec.USEFD end
    if settings.nec.USEINSPIRE ~= nil then OPTS.USEINSPIRE = settings.nec.USEINSPIRE end
    if settings.nec.USEREZ ~= nil then OPTS.USEREZ = settings.nec.USEREZ end
end

nec.save_settings = function()
    persistence.store(SETTINGS_FILE, {common=common.OPTS, nec=OPTS})
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
    if common.OPTS.USEALLIANCE then
        if mq.TLO.Spell(spells['alliance']['name']).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        if mq.TLO.Me.SpellReady(spells['alliance']['name'])() and neccount > 1 and not mq.TLO.Target.Buff(spells['alliance']['name'])() and mq.TLO.Spell(spells['alliance']['name']).StacksTarget() then
            -- pick the first 3 dots in the rotation as they will hopefully always be up given their priority
            if mq.TLO.Target.MyBuff(spells['pyreshort']['name'])() and mq.TLO.Target.MyBuff(spells['venom']['name'])() and mq.TLO.Target.MyBuff(spells['magic']['name'])() then
                common.cast(spells['alliance']['name'], true, true)
                return true
            end
        end
    end
    return false
end

local function cast_synergy()
    if not mq.TLO.Me.Song('Defiler\'s Synergy')() and mq.TLO.Me.SpellReady(spells['synergy']['name'])() then
        if mq.TLO.Spell(spells['synergy']['name']).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        -- don't bother with proc'ing synergy until we've got most dots applied
        if mq.TLO.Target.MyBuff(spells['pyreshort']['name'])() and mq.TLO.Target.MyBuff(spells['venom']['name'])() and mq.TLO.Target.MyBuff(spells['magic']['name'])() then
            common.cast(spells['synergy']['name'], true, true)
            return true
        end
    end
    return false
end

local function is_dot_ready(spellId, spellName)
    local buffDuration = 0
    local remainingCastTime = 0
    if not mq.TLO.Me.SpellReady(spellName)() then
        return false
    end

    if mq.TLO.Spell(spellName).Mana() > mq.TLO.Me.CurrentMana() then
        return false
    end
    buffDuration = mq.TLO.Target.MyBuffDuration(spellName)()
    if not common.is_target_dotted_with(spellId, spellName) then
        -- target does not have the dot, we are ready
        return true
    else
        if not buffDuration then
            return true
        end
        -- Do not return wounds as ready while it still has any duration left
        if spellId == spells['wounds']['id'] then return false end
        remainingCastTime = mq.TLO.Spell(spellName).MyCastTime()
        return buffDuration < remainingCastTime + 3000
    end

    return false
end

local function find_next_dot_to_cast()
    if try_alliance() then return nil end
    if cast_synergy() then return nil end
    -- Just cast composite as part of the normal dot rotation, no special handling
    --if is_dot_ready(spells['composite']['id'], spells['composite']['name']) then
    --    return spells['composite']['id'], spells['composite']['name']
    --end
    if mq.TLO.Me.PctMana() < 40 and mq.TLO.Me.SpellReady(spells['manatap']['name'])() and mq.TLO.Spell(spells['manatap']['name']).Mana() < mq.TLO.Me.CurrentMana() then
        return spells['manatap']
    end
    if common.OPTS.SPELLSET == 'short' and mq.TLO.Me.SpellReady(spells['swarm']['name'])() and mq.TLO.Spell(spells['swarm']['name']).Mana() < mq.TLO.Me.CurrentMana() then
        return spells['swarm']
    end
    local pct_hp = mq.TLO.Target.PctHPs()
    if pct_hp and pct_hp > OPTS.STOPPCT then
        for _,dot in ipairs(dots[common.OPTS.SPELLSET]) do -- iterates over the dots array. ipairs(dots) returns 2 values, an index and its value in the array. we don't care about the index, we just want the dot
            local spell_id = dot['id']
            local spell_name = dot['name']
            -- ToL has no combo disease dot spell, so the 2 disease dots are just in the normal rotation now.
            -- if spell_id == spells['combodis']['id'] then
            --     if (not is_target_dotted_with(spells['decay']['id'], spells['decay']['name']) or not is_target_dotted_with(spells['grip']['id'], spells['grip']['name'])) and mq.TLO.Me.SpellReady(spells['combodis']['name'])() then
            --         return dot
            --     end
            -- else
            if is_dot_ready(spell_id, spell_name) then
                return dot -- if is_dot_ready returned true then return this dot as the dot we should cast
            end
        end
    end
    if mq.TLO.Me.SpellReady(spells['manatap']['name'])() and mq.TLO.Spell(spells['manatap']['name']).Mana() < mq.TLO.Me.CurrentMana() then
        return spells['manatap']
    end
    if common.OPTS.SPELLSET == 'short' and mq.TLO.Me.SpellReady(spells['venin']['name'])() and mq.TLO.Spell(spells['venin']['name']).Mana() < mq.TLO.Me.CurrentMana() then
        return spells['venin']
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

local function cycle_dots()
    if common.is_fighting() or common.should_assist() then
        local spell = find_next_dot_to_cast() -- find the first available dot to cast that is missing from the target
        if spell then -- if a dot was found
            common.cast(spell['name'], true, true) -- then cast the dot
            return true
        end
    end
    return false
end

local function try_debuff_target()
    if (common.is_fighting() or common.should_assist()) and OPTS.DEBUFF then
        local targetID = mq.TLO.Target.ID()
        if targetID and targetID > 0 and (not targets[targetID] or not targets[targetID][2]) then
            local isScentAAReady = mq.TLO.Me.AltAbilityReady('Scent of Thule')()

            local isDebuffedAlready = common.is_target_dotted_with(spells['scentterris']['id'], spells['scentterris']['name'])
            if isDebuffedAlready then
                isDebuffedAlready = common.is_target_dotted_with(spells['scentmortality']['id'], spells['scentmortality']['name'])
            end
            if not mq.TLO.Spell(spells['scentterris']['name']).StacksTarget() then
                isDebuffedAlready = true
            end
            if not mq.TLO.Spell(spells['scentmortality']['name']).StacksTarget() then
                isDebuffedAlready = true
            end

            if isScentAAReady and not isDebuffedAlready then
                common.printf('use_aa: \ax\arScent of Thule\ax')
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
    if not mq.TLO.Target.MyBuff(spells['proliferation']['name'])() then return false else return true end
end

local function is_nec_burn_condition_met()
    if OPTS.BURNPROC and target_has_proliferation() then
        common.printf('\arActivating Burns (proliferation proc)\ax')
        common.BURN_ACTIVE_TIMER = common.current_time()
        common.BURN_ACTIVE = true
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
            if aa['name']:lower() == 'funeral pyre' then
                if not mq.TLO.Me.AltAbilityReady('heretic\'s twincast')() and not mq.TLO.Me.Buff('heretic\'s twincast')() then
                    common.use_aa(aa)
                end
            elseif aa['name']:lower() == 'wake the dead' then
                if mq.TLO.SpawnCount('corpse radius 150')() > 0 then
                    common.use_aa(aa)
                end
            else
                common.use_aa(aa)
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
    common.printf('Pre-burn')
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
end

local function check_mana()
    -- modrods
    common.check_mana()
    local pct_mana = mq.TLO.Me.PctMana()
    if pct_mana < 65 then
        -- death bloom at some %
        common.use_aa(deathbloom)
    end
    if common.is_fighting() then
        if pct_mana < 40 then
            -- blood magic at some %
            common.use_aa(bloodmagic)
        end
    end
end

local function safe_to_stand()
    if mq.TLo.Raid.Members() > 0 and mq.TLO.SpawnCount('pc raid tank radius 300')() > 2 then
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

local check_aggro_timer = 0
local function check_aggro()
    if OPTS.USEFD and common.is_fighting() and mq.TLO.Target() then
        if mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID() or common.timer_expired(check_aggro_timer, 10) then
            if mq.TLO.Me.PctAggro() >= 90 then
                if mq.TLO.Me.PctHPs() < 40 and mq.TLO.Me.AltAbilityReady('Dying Grasp')() then
                    common.use_aa(dyinggrasp)
                end
                common.use_aa(deathseffigy)
                if mq.TLO.Me.Feigning() then
                    check_aggro_timer = common.current_time()
                    mq.delay(500)
                    if safe_to_stand() then
                        mq.TLO.Me.Sit() -- Use a sit TLO to stand up, what wizardry is this?
                        mq.cmd('/makemevis')
                    end
                end
            elseif mq.TLO.Me.PctAggro() >= 70 then
                common.use_aa(deathpeace)
                if mq.TLO.Me.Feigning() then
                    check_aggro_timer = common.current_time()
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

local rez_timer = 0
local function check_rez()
    if not OPTS.USEREZ or common.am_i_dead() then return end
    if common.time_remaining(rez_timer, 5) then return end
    if not mq.TLO.Me.AltAbilityReady(convergence['name'])() then return end
    if mq.TLO.FindItemCount('=Essence Emerald')() == 0 then return end
    if mq.TLO.SpawnCount('pccorpse group healer radius 100')() > 0 then
        mq.TLO.Spawn('pccorpse group healer radius 100').DoTarget()
        mq.cmd('/corpse')
        common.use_aa(convergence)
        rez_timer = common.current_time()
        return
    end
    if mq.TLO.SpawnCount('pccorpse raid healer radius 100')() > 0 then
        mq.TLO.Spawn('pccorpse raid healer radius 100').DoTarget()
        mq.cmd('/corpse')
        common.use_aa(convergence)
        rez_timer = common.current_time()
        return
    end
    if mq.TLO.Group.MainTank() and mq.TLO.Group.MainTank.Dead() then
        mq.TLO.Group.MainTank.DoTarget()
        local corpse_x = mq.TLO.Target.X()
        local corpse_y = mq.TLO.Target.Y()
        if corpse_x and corpse_y and common.check_distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), corpse_x, corpse_y) > 100 then return end
        mq.cmd('/corpse')
        common.use_aa(convergence)
        rez_timer = common.current_time()
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
                rez_timer = common.current_time()
                return
            end
        end
    end
end

local function check_buffs()
    if common.am_i_dead() or mq.TLO.Me.Moving() then return end
    if OPTS.USEBUFFSHIELD then
        if not mq.TLO.Me.Buff(spells['shield']['name'])() and mq.TLO.Me.SpellReady(spells['shield']['name'])() and mq.TLO.Spell(spells['shield']['name']).Mana() < mq.TLO.Me.CurrentMana() then
            common.cast(spells['shield']['name'])
        end
    end
    if OPTS.USEINSPIRE then
        if not mq.TLO.Pet.Buff(spells['inspire']['name'])() and mq.TLO.Me.SpellReady(spells['inspire']['name'])() and mq.TLO.Spell(spells['inspire']['name']).Mana() < mq.TLO.Me.CurrentMana() then
            common.cast(spells['inspire']['name'])
        end
    end
    common.check_combat_buffs()
    if common.is_fighting() then return end
    if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', common.OPTS.CAMPRADIUS))() > 0 then return end
    if not mq.TLO.Me.Buff(spells['lich']['name'])() or not mq.TLO.Me.Buff(spells['flesh']['name'])() then
        common.use_aa(unity)
    end

    common.check_item_buffs()

    if OPTS.BUFFPET and mq.TLO.Pet.ID() > 0 then
        for _,buff in ipairs(buffs['pet']) do
            if not mq.TLO.Pet.Buff(buff['name'])() and mq.TLO.Spell(buff['name']).StacksPet() and mq.TLO.Spell(buff['name']).Mana() < mq.TLO.Me.CurrentMana() then
                local restore_gem = nil
                if not mq.TLO.Me.Gem(buff['name'])() then
                    restore_gem = mq.TLO.Me.Gem(13)()
                    common.swap_spell(buff['name'], 13)
                end
                mq.delay('3s', function() return mq.TLO.Me.SpellReady(buff['name'])() end)
                common.cast(buff['name'])
                if restore_gem then
                    common.swap_spell(restore_gem, 13)
                end
            end
        end
    end
end

local function check_pet()
    common.debug('is_fighting=%s Pet.ID=%s spawncount=%s spellmana=%s memana=%s', common.is_fighting(), mq.TLO.Pet.ID(), mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', common.OPTS.CAMPRADIUS))(), mq.TLO.Spell(spells['pet']['name']).Mana(), mq.TLO.Me.CurrentMana())
    if common.is_fighting() or mq.TLO.Pet.ID() > 0 or mq.TLO.Me.Moving() then return end
    if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', common.OPTS.CAMPRADIUS))() > 0 then return end
    if mq.TLO.Spell(spells['pet']['name']).Mana() > mq.TLO.Me.CurrentMana() then return end
    local restore_gem = nil
    if not mq.TLO.Me.Gem(spells['pet']['name'])() then
        restore_gem = mq.TLO.Me.Gem(13)()
        common.swap_spell(spells['pet']['name'], 13)
    end
    mq.delay('3s', function() return mq.TLO.Me.SpellReady(spells['pet']['name'])() end)
    common.cast(spells['pet']['name'])
    if restore_gem then
        common.swap_spell(restore_gem, 13)
    end
end

local function should_swap_dots()
    -- Only swap spells in standard spell set
    if common.SPELLSET_LOADED ~= 'standard' or mq.TLO.Me.Moving() then return end

    local woundsDuration = mq.TLO.Target.MyBuffDuration(spells['wounds']['name'])()
    local pyrelongDuration = mq.TLO.Target.MyBuffDuration(spells['pyrelong']['name'])()
    local fireshadowDuration = mq.TLO.Target.MyBuffDuration(spells['fireshadow']['name'])()
    if mq.TLO.Me.Gem(spells['wounds']['name'])() then
        if woundsDuration and woundsDuration > 20000 then
            if not pyrelongDuration or pyrelongDuration < 20000 then
                common.swap_spell(spells['pyrelong']['name'], swap_gem or 10)
            elseif not fireshadowDuration or fireshadowDuration < 20000 then
                common.swap_spell(spells['fireshadow']['name'], swap_gem or 10)
            end
        end
    elseif mq.TLO.Me.Gem(spells['pyrelong']['name'])() then
        if pyrelongDuration and pyrelongDuration > 20000 then
            if not woundsDuration or woundsDuration < 20000 then
                common.swap_spell(spells['wounds']['name'], swap_gem or 10)
            elseif not fireshadowDuration or fireshadowDuration < 20000 then
                common.swap_spell(spells['fireshadow']['name'], swap_gem or 10)
            end
        end
    elseif mq.TLO.Me.Gem(spells['fireshadow']['name'])() then
        if fireshadowDuration and fireshadowDuration > 20000 then
            if not woundsDuration or woundsDuration < 20000 then
                common.swap_spell(spells['wounds']['name'], swap_gem or 10)
            elseif not pyrelongDuration or pyrelongDuration < 20000 then
                common.swap_spell(spells['pyrelong']['name'], swap_gem or 10)
            end
        end
    else
        -- maybe we got interrupted or something and none of these are mem'd anymore? just memorize wounds again
        common.swap_spell(spells['wounds']['name'], swap_gem or 10)
    end

    local decayDuration = mq.TLO.Target.MyBuffDuration(spells['decay']['name'])()
    local gripDuration = mq.TLO.Target.MyBuffDuration(spells['grip']['name'])()
    if mq.TLO.Me.Gem(spells['decay']['name'])() then
        if decayDuration and decayDuration > 20000 then
            if not gripDuration or gripDuration < 20000 then
                common.swap_spell(spells['grip']['name'], swap_gem_dis or 11)
            end
        end
    elseif mq.TLO.Me.Gem(spells['grip']['name'])() then
        if gripDuration and gripDuration > 20000 then
            if not decayDuration or decayDuration < 20000 then
                common.swap_spell(spells['decay']['name'], swap_gem_dis or 11)
            end
        end
    else
        -- maybe we got interrupted or something and none of these are mem'd anymore? just memorize decay again
        common.swap_spell(spells['decay']['name'], swap_gem_dis or 11)
    end
end

local check_spell_timer = 0
local function check_spell_set()
    if common.is_fighting() or mq.TLO.Me.Moving() or common.am_i_dead() then return end
    if common.SPELLSET_LOADED ~= common.OPTS.SPELLSET or common.timer_expired(check_spell_timer, 30) then
        if common.OPTS.SPELLSET == 'standard' then
            if mq.TLO.Me.Gem(1)() ~= 'Composite Paroxysm' then common.swap_spell(spells['composite']['name'], 1) end
            if mq.TLO.Me.Gem(2)() ~= spells['pyreshort']['name'] then common.swap_spell(spells['pyreshort']['name'], 2) end
            if mq.TLO.Me.Gem(3)() ~= spells['venom']['name'] then common.swap_spell(spells['venom']['name'], 3) end
            if mq.TLO.Me.Gem(4)() ~= spells['magic']['name'] then common.swap_spell(spells['magic']['name'], 4) end
            if mq.TLO.Me.Gem(5)() ~= spells['haze']['name'] then common.swap_spell(spells['haze']['name'], 5) end
            if mq.TLO.Me.Gem(6)() ~= spells['grasp']['name'] then common.swap_spell(spells['grasp']['name'], 6) end
            if mq.TLO.Me.Gem(7)() ~= spells['leech']['name'] then common.swap_spell(spells['leech']['name'], 7) end
            if mq.TLO.Me.Gem(10)() ~= spells['wounds']['name'] then common.swap_spell(spells['wounds']['name'], 10) end
            if mq.TLO.Me.Gem(11)() ~= spells['decay']['name'] then common.swap_spell(spells['decay']['name'], 11) end
            if mq.TLO.Me.Gem(13)() ~= spells['synergy']['name'] then common.swap_spell(spells['synergy']['name'], 13) end
            common.SPELLSET_LOADED = common.OPTS.SPELLSET
        elseif common.OPTS.SPELLSET == 'short' then
            if mq.TLO.Me.Gem(1)() ~= 'Composite Paroxysm' then common.swap_spell(spells['composite']['name'], 1) end
            if mq.TLO.Me.Gem(2)() ~= spells['pyreshort']['name'] then common.swap_spell(spells['pyreshort']['name'], 2) end
            if mq.TLO.Me.Gem(3)() ~= spells['venom']['name'] then common.swap_spell(spells['venom']['name'], 3) end
            if mq.TLO.Me.Gem(4)() ~= spells['magic']['name'] then common.swap_spell(spells['magic']['name'], 4) end
            if mq.TLO.Me.Gem(5)() ~= spells['haze']['name'] then common.swap_spell(spells['haze']['name'], 5) end
            if mq.TLO.Me.Gem(6)() ~= spells['grasp']['name'] then common.swap_spell(spells['grasp']['name'], 6) end
            if mq.TLO.Me.Gem(7)() ~= spells['leech']['name'] then common.swap_spell(spells['leech']['name'], 7) end
            if mq.TLO.Me.Gem(10)() ~= spells['swarm']['name'] then common.swap_spell(spells['swarm']['name'], 10) end
            if mq.TLO.Me.Gem(11)() ~= spells['decay']['name'] then common.swap_spell(spells['decay']['name'], 11) end
            if mq.TLO.Me.Gem(13)() ~= spells['synergy']['name'] then common.swap_spell(spells['synergy']['name'], 13) end
            common.SPELLSET_LOADED = common.OPTS.SPELLSET
        end
        check_spell_timer = common.current_time()
        swap_gem = mq.TLO.Me.Gem(spells['wounds']['name'])() or mq.TLO.Me.Gem(spells['fireshadow']['name'])() or mq.TLO.Me.Gem(spells['pyrelong']['name'])() or 10
        swap_gem_dis = mq.TLO.Me.Gem(spells['decay']['name'])() or mq.TLO.Me.Gem(spells['grip']['name'])() or 11
    end
    if common.OPTS.SPELLSET == 'standard' then
        if OPTS.USEMANATAP and common.OPTS.USEALLIANCE and OPTS.USEBUFFSHIELD then
            if mq.TLO.Me.Gem(8)() ~= spells['manatap']['name'] then common.swap_spell(spells['manatap']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['alliance']['name'] then common.swap_spell(spells['alliance']['name'], 9) end
            if mq.TLO.Me.Gem(12)() ~= spells['shield']['name'] then common.swap_spell(spells['shield']['name'], 12) end
        elseif OPTS.USEMANATAP and common.OPTS.USEALLIANCE and not OPTS.USEBUFFSHIELD then
            if mq.TLO.Me.Gem(8)() ~= spells['manatap']['name'] then common.swap_spell(spells['manatap']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['alliance']['name'] then common.swap_spell(spells['alliance']['name'], 9) end
            if mq.TLO.Me.Gem(12)() ~= spells['ignite']['name'] then common.swap_spell(spells['ignite']['name'], 12) end
        elseif OPTS.USEMANATAP and not common.OPTS.USEALLIANCE and not OPTS.USEBUFFSHIELD then
            if mq.TLO.Me.Gem(8)() ~= spells['manatap']['name'] then common.swap_spell(spells['manatap']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['scourge']['name'] then common.swap_spell(spells['scourge']['name'], 9) end
            if mq.TLO.Me.Gem(12)() ~= spells['ignite']['name'] then common.swap_spell(spells['ignite']['name'], 12) end
        elseif OPTS.USEMANATAP and not common.OPTS.USEALLIANCE and OPTS.USEBUFFSHIELD then
            if mq.TLO.Me.Gem(8)() ~= spells['manatap']['name'] then common.swap_spell(spells['manatap']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['ignite']['name'] then common.swap_spell(spells['ignite']['name'], 9) end
            if mq.TLO.Me.Gem(12)() ~= spells['shield']['name'] then common.swap_spell(spells['shield']['name'], 12) end
        elseif not OPTS.USEMANATAP and not common.OPTS.USEALLIANCE and not OPTS.USEBUFFSHIELD then
            if mq.TLO.Me.Gem(8)() ~= spells['ignite']['name'] then common.swap_spell(spells['ignite']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['scourge']['name'] then common.swap_spell(spells['scourge']['name'], 9) end
            if mq.TLO.Me.Gem(12)() ~= spells['corruption']['name'] then common.swap_spell(spells['corruption']['name'], 12) end
        elseif not OPTS.USEMANATAP and not common.OPTS.USEALLIANCE and OPTS.USEBUFFSHIELD then
            if mq.TLO.Me.Gem(8)() ~= spells['ignite']['name'] then common.swap_spell(spells['ignite']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['scourge']['name'] then common.swap_spell(spells['scourge']['name'], 9) end
            if mq.TLO.Me.Gem(12)() ~= spells['shield']['name'] then common.swap_spell(spells['shield']['name'], 12) end
        elseif not OPTS.USEMANATAP and common.OPTS.USEALLIANCE and OPTS.USEBUFFSHIELD then
            if mq.TLO.Me.Gem(8)() ~= spells['ignite']['name'] then common.swap_spell(spells['ignite']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['alliance']['name'] then common.swap_spell(spells['alliance']['name'], 9) end
            if mq.TLO.Me.Gem(12)() ~= spells['shield']['name'] then common.swap_spell(spells['shield']['name'], 12) end
        elseif not OPTS.USEMANATAP and common.OPTS.USEALLIANCE and not OPTS.USEBUFFSHIELD then
            if mq.TLO.Me.Gem(8)() ~= spells['ignite']['name'] then common.swap_spell(spells['ignite']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['alliance']['name'] then common.swap_spell(spells['alliance']['name'], 9) end
            if mq.TLO.Me.Gem(12)() ~= spells['scourge']['name'] then common.swap_spell(spells['scourge']['name'], 12) end
        end
    elseif common.OPTS.SPELLSET == 'short' then
        if OPTS.USEMANATAP and common.OPTS.USEALLIANCE and OPTS.USEINSPIRE then
            if mq.TLO.Me.Gem(8)() ~= spells['manatap']['name'] then common.swap_spell(spells['manatap']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['alliance']['name'] then common.swap_spell(spells['alliance']['name'], 9) end
            if mq.TLO.Me.Gem(12)() ~= spells['inspire']['name'] then common.swap_spell(spells['inspire']['name'], 12) end
        elseif OPTS.USEMANATAP and common.OPTS.USEALLIANCE and not OPTS.USEINSPIRE then
            if mq.TLO.Me.Gem(8)() ~= spells['manatap']['name'] then common.swap_spell(spells['manatap']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['alliance']['name'] then common.swap_spell(spells['alliance']['name'], 9) end
            if mq.TLO.Me.Gem(12)() ~= spells['venin']['name'] then common.swap_spell(spells['venin']['name'], 12) end
        elseif OPTS.USEMANATAP and not common.OPTS.USEALLIANCE and not OPTS.USEINSPIRE then
            if mq.TLO.Me.Gem(8)() ~= spells['manatap']['name'] then common.swap_spell(spells['manatap']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['ignite']['name'] then common.swap_spell(spells['ignite']['name'], 9) end
            if mq.TLO.Me.Gem(12)() ~= spells['venin']['name'] then common.swap_spell(spells['venin']['name'], 12) end
        elseif OPTS.USEMANATAP and not common.OPTS.USEALLIANCE and OPTS.USEINSPIRE then
            if mq.TLO.Me.Gem(8)() ~= spells['manatap']['name'] then common.swap_spell(spells['manatap']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['ignite']['name'] then common.swap_spell(spells['ignite']['name'], 9) end
            if mq.TLO.Me.Gem(12)() ~= spells['inspire']['name'] then common.swap_spell(spells['inspire']['name'], 12) end
        elseif not OPTS.USEMANATAP and not common.OPTS.USEALLIANCE and not OPTS.USEINSPIRE then
            if mq.TLO.Me.Gem(8)() ~= spells['ignite']['name'] then common.swap_spell(spells['ignite']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['scourge']['name'] then common.swap_spell(spells['scourge']['name'], 9) end
            if mq.TLO.Me.Gem(12)() ~= spells['venin']['name'] then common.swap_spell(spells['venin']['name'], 12) end
        elseif not OPTS.USEMANATAP and not common.OPTS.USEALLIANCE and OPTS.USEINSPIRE then
            if mq.TLO.Me.Gem(8)() ~= spells['ignite']['name'] then common.swap_spell(spells['ignite']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['scourge']['name'] then common.swap_spell(spells['scourge']['name'], 9) end
            if mq.TLO.Me.Gem(12)() ~= spells['inspire']['name'] then common.swap_spell(spells['inspire']['name'], 12) end
        elseif not OPTS.USEMANATAP and common.OPTS.USEALLIANCE and OPTS.USEINSPIRE then
            if mq.TLO.Me.Gem(8)() ~= spells['ignite']['name'] then common.swap_spell(spells['ignite']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['alliance']['name'] then common.swap_spell(spells['alliance']['name'], 9) end
            if mq.TLO.Me.Gem(12)() ~= spells['inspire']['name'] then common.swap_spell(spells['inspire']['name'], 12) end
        elseif not OPTS.USEMANATAP and common.OPTS.USEALLIANCE and not OPTS.USEINSPIRE then
            if mq.TLO.Me.Gem(8)() ~= spells['ignite']['name'] then common.swap_spell(spells['ignite']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['alliance']['name'] then common.swap_spell(spells['alliance']['name'], 9) end
            if mq.TLO.Me.Gem(12)() ~= spells['venin']['name'] then common.swap_spell(spells['venin']['name'], 12) end
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
        if opt == 'PREP' then
            pre_pop_burns()
        elseif OPTS[opt] ~= nil then
            common.printf('%s: %s', opt, OPTS[opt])
        elseif common.OPTS[opt] ~= nil then
            common.printf('%s: %s', opt, common.OPTS[opt])
        else
            common.printf('Unrecognized option: %s', opt)
        end
    end
end

local nec_count_timer = 0
nec.main_loop = function()
    -- keep cursor clear for spell swaps and such
    if common.OPTS.USEALLIANCE and common.timer_expired(nec_count_timer, 60) then
        get_necro_count()
        nec_count_timer = common.current_time()
    end
    -- ensure correct spells are loaded based on selected spell set
    -- currently only checks at startup or when selection changes
    check_spell_set()
    -- check whether we need to return to camp
    common.check_camp()
    -- check whether we need to go chasing after the chase target
    common.check_chase()
    -- check we have the correct target to attack
    common.check_target()
    -- if we should be assisting but aren't in los, try to be?
    common.check_los()
    -- begin actual combat stuff
    common.send_pet()
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
    mq.delay(1)
end

nec.draw_left_panel = function()
    common.OPTS.MODE = ui.draw_combo_box('Mode', common.OPTS.MODE, common.MODES)
    common.set_camp()
    common.OPTS.SPELLSET = ui.draw_combo_box('Spell Set', common.OPTS.SPELLSET, SPELLSETS, true)
    common.OPTS.ASSIST = ui.draw_combo_box('Assist', common.OPTS.ASSIST, common.ASSISTS, true)
    common.OPTS.AUTOASSISTAT = ui.draw_input_int('Assist %', '##assistat', common.OPTS.AUTOASSISTAT, 'Percent HP to assist at')
    common.OPTS.CAMPRADIUS = ui.draw_input_int('Camp Radius', '##campradius', common.OPTS.CAMPRADIUS, 'Camp radius to assist within')
    common.OPTS.CHASETARGET = ui.draw_input_text('Chase Target', '##chasetarget', common.OPTS.CHASETARGET, 'Chase Target')
    common.OPTS.CHASEDISTANCE = ui.draw_input_int('Chase Distance', '##chasedist', common.OPTS.CHASEDISTANCE, 'Distance to follow chase target')
    common.OPTS.BURNPCT = ui.draw_input_int('Burn Percent', '##burnpct', common.OPTS.BURNPCT, 'Percent health to begin burns')
    common.OPTS.BURNCOUNT = ui.draw_input_int('Burn Count', '##burncnt', common.OPTS.BURNCOUNT, 'Trigger burns if this many mobs are on aggro')
    OPTS.STOPPCT = ui.draw_input_int('Stop Percent', '##stoppct', OPTS.STOPPCT, 'Percent HP to stop dotting')
end

nec.draw_right_panel = function()
    common.OPTS.BURNALWAYS = ui.draw_check_box('Burn Always', '##burnalways', common.OPTS.BURNALWAYS, 'Always be burning')
    ui.get_next_item_loc()
    common.OPTS.BURNALLNAMED = ui.draw_check_box('Burn Named', '##burnnamed', common.OPTS.BURNALLNAMED, 'Burn all named')
    ui.get_next_item_loc()
    OPTS.BURNPROC = ui.draw_check_box('Burn On Proc', '##burnproc', OPTS.BURNPROC, 'Burn when proliferation procs')
    ui.get_next_item_loc()
    OPTS.DEBUFF = ui.draw_check_box('Debuff', '##debuff', OPTS.DEBUFF, 'Debuff targets')
    ui.get_next_item_loc()
    common.OPTS.USEALLIANCE = ui.draw_check_box('Alliance', '##alliance', common.OPTS.USEALLIANCE, 'Use alliance spell')
    ui.get_next_item_loc()
    common.OPTS.SWITCHWITHMA = ui.draw_check_box('Switch With MA', '##switchwithma', common.OPTS.SWITCHWITHMA, 'Switch targets with MA')
    ui.get_next_item_loc()
    OPTS.SUMMONPET = ui.draw_check_box('Summon Pet', '##summonpet', OPTS.SUMMONPET, 'Summon pet')
    ui.get_next_item_loc()
    OPTS.BUFFPET = ui.draw_check_box('Buff Pet', '##buffpet', OPTS.BUFFPET, 'Use pet buff')
    ui.get_next_item_loc()
    OPTS.USEINSPIRE = ui.draw_check_box('Inspire Ally', '##inspire', OPTS.USEINSPIRE, 'Use Inspire Ally pet buff')
    ui.get_next_item_loc()
    OPTS.USEBUFFSHIELD = ui.draw_check_box('Buff Shield', '##buffshield', OPTS.USEBUFFSHIELD, 'Keep shield buff up. Replaces corruption DoT.')
    ui.get_next_item_loc()
    OPTS.USEMANATAP = ui.draw_check_box('Mana Drain', '##manadrain', OPTS.USEMANATAP, 'Use group mana drain dot. Replaces Ignite DoT.')
    ui.get_next_item_loc()
    OPTS.USEFD = ui.draw_check_box('Feign Death', '##dofeign', OPTS.USEFD, 'Use FD AA\'s to reduce aggro')
    ui.get_next_item_loc()
    OPTS.USEREZ = ui.draw_check_box('Use Rez', '##userez', OPTS.USEREZ, 'Use Convergence AA to rez group members')
end

return nec