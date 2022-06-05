--- @type mq
local mq = require 'mq'
local assist = require('aqo.routines.assist')
local camp = require('aqo.routines.camp')
local mez = require('aqo.routines.mez')
local logger = require('aqo.utils.logger')
local persistence = require('aqo.utils.persistence')
local timer = require('aqo.utils.timer')
local common = require('aqo.common')
local config = require('aqo.configuration')
local state = require('aqo.state')
local ui = require('aqo.ui')

local enc = {}

local SPELLSETS = {standard=1}
local AURAS = {twincast=true, combatinnate=true, spellfocus=true, regen=true, disempower=true,}
local OPTS = {
    AURA1='twincast',
    AURA2='combatinnate',
    INTERRUPTFORMEZ=false,
    TASHTHENMEZ=true,
    USECHAOTIC=true,
    USECHARM=false,
    USEDOT=true,
    USEHASTE=true,
    USEMEZ=true,
    USEMINDOVERMATTER=true,
    USENIGHTSTERROR=true,
    USENUKE=true,
    USEPHANTASMAL=true,
    USEREPLICATION=true,
    USESHIELDOFFATE=true,
    USESLOW=false,
    USESLOWAOE=true,
    USESPELLGUARD=true,
    USETASH=false,
    USETASHAOE=true,
    SUMMONPET=false,
    BUFFPET=true,
    USEERADICATE=true,
}
config.set_spell_set('standard')

-- All spells ID + Rank name
local spells = {
    ['composite']=common.get_spell('Composite Reinforcement') or common.get_spell('Dissident Reinforcement') or common.get_spell('Dichotomic Reinforcement') or {name=nil,id=nil}, -- restore mana, add dmg proc, inc dmg
    ['alliance']=common.get_spell('Chromatic Coalition') or common.get_spell('Chromatic Covenant') or {name=nil,id=nil},

    ['mezst']=common.get_spell('Addle'), -- 9 ticks
    ['mezst2']=common.get_spell('Addling Flash'), -- 6 ticks
    ['mezae']=common.get_spell('Bewildering Wave') or common.get_spell('Neutralizing Wave') or {name=nil,id=nil}, -- targeted AE mez
    ['mezaehate']=common.get_spell('Confounding Glance'), -- targeted AE mez + 100% hate reduction
    ['mezpbae']=common.get_spell('Bewilderment'),
    ['mezpbae2']=common.get_spell('Perilous Bewilderment'), -- lvl 120
    ['meznoblur']=common.get_spell('Chaotic Puzzlement') or common.get_spell('Chaotic Deception') or {name=nil,id=nil},
    ['mezaeprocblur']=common.get_spell('Mesmeric Stare'), -- targeted AE mez
    ['mezshield']=common.get_spell('Ward of the Beguiler') or common.get_spell('Ward of the Deviser') or {name=nil,id=nil}, -- mez proc on being hit

    ['rune']=common.get_spell('Marvel\'s Rune'), -- 160k rune, self
    ['rune2']=common.get_spell('Rune of Tearc'), -- 90k rune, single target
    ['dotrune']=common.get_spell('Aegis of Xetheg'), -- absorb DoT dmg
    ['guard']=common.get_spell('Shield of Inevitability') or common.get_spell('Shield of Destiny') or common.get_spell('Shield of Order') or {name=nil,id=nil}, -- spell + melee guard
    ['dotmiti']=common.get_spell('Deviser\'s Auspice') or common.get_spell('Transfixer\'s Auspice') or {name=nil,id=nil}, -- DoT guard
    ['meleemiti']=common.get_spell('Eclipsed Auspice'), -- melee guard
    ['spellmiti']=common.get_spell('Aegis of Sefra'), -- 20% spell mitigation
    ['absorbbuff']=common.get_spell('Brimstone Endurance'), -- increase absorb dmg

    ['aggrorune']=common.get_spell('Ghastly Rune'), -- single target rune + hate increase

    ['groupdotrune']=common.get_spell('Legion of Xetheg') or common.get_spell('Legion of Cekenar') or {name=nil,id=nil},
    ['groupspellrune']=common.get_spell('Legion of Liako') or common.get_spell('Legion of Kildrukaun') or {name=nil,id=nil},
    ['groupaggrorune']=common.get_spell('Eclipsed Rune'), -- group rune + aggro reduction proc

    ['dot']=common.get_spell('Mind Vortex') or common.get_spell('Mind Coil') or {name=nil,id=nil}, -- big dot
    ['dot2']=common.get_spell('Throttling Grip') or common.get_spell('Pulmonary Grip') or {name=nil,id=nil}, -- decent dot
    ['debuffdot']=common.get_spell('Perplexing Constriction'), -- debuff + nuke + dot
    ['manadot']=common.get_spell('Tears of Xenacious'), -- hp + mana DoT
    ['nukerune']=common.get_spell('Chromatic Flare'), -- 15k nuke + self rune
    ['nuke']=common.get_spell('Psychological Appropriation'), -- 20k
    ['nuke2']=common.get_spell('Chromashear'), -- 23k
    ['nuke3']=common.get_spell('Polyluminous Assault'), -- 27k nuke
    ['nuke4']=common.get_spell('Obscuring Eclipse'), -- 27k nuke
    ['aenuke']=common.get_spell('Gravity Roil'), -- 23k targeted ae nuke

    ['calm']=common.get_spell('Still Mind'),
    ['tash']=common.get_spell('Edict of Tashan') or common.get_spell('Proclamation of Tashan') or {name=nil,id=nil},
    ['stunst']=common.get_spell('Dizzying Vortex'), -- single target stun
    ['stunae']=common.get_spell('Remote Color Conflagration'),
    ['stunpbae']=common.get_spell('Color Conflagration'),
    ['stunaerune']=common.get_spell('Polyluminous Rune') or common.get_spell('Polycascading Rune') or common.get_spell('Polyfluorescent Rune') or {name=nil,id=nil}, -- self rune, proc ae stun on fade

    ['pet']=common.get_spell('Constance\'s Animation'),
    ['pethaste']=common.get_spell('Invigorated Minion'),
    ['charm']=common.get_spell('Marvel\'s Command'),
    -- buffs
    ['unity']=common.get_spell('Marvel\'s Unity') or common.get_spell('Deviser\'s Unity') or {name=nil,id=nil}, -- mez proc on being hit
    ['procbuff']=common.get_spell('Mana Rebirth'), -- single target dmg proc buff
    ['kei']=common.get_spell('Scrying Visions') or common.get_spell('Sagacity') or {name=nil,id=nil},
    ['keigroup']=common.get_spell('Voice of Perception') or common.get_spell('Voice of Sagacity') or {name=nil,id=nil},
    ['haste']=common.get_spell('Speed of Itzal') or common.get_spell('Speed of Cekenar') or {name=nil,id=nil}, -- single target buff
    ['grouphaste']=common.get_spell('Hastening of Jharin') or common.get_spell('Hastening of Cekenar') or {name=nil,id=nil}, -- group haste
    ['nightsterror']=common.get_spell('Night\'s Perpetual Terror') or common.get_spell('Night\'s Endless Terror') or {name=nil,id=nil}, -- melee attack proc
    -- auras - mana, learners, spellfocus, combatinnate, disempower, rune, twincast
    ['twincast']=common.get_spell('Twincast Aura'),
    ['regen']=common.get_spell('Marvel\'s Aura') or common.get_spell('Deviser\'s Aura') or {name=nil,id=nil}, -- mana + end regen aura
    ['spellfocus']=common.get_spell('Enhancing Aura') or common.get_spell('Fortifying Aura') or {name=nil,id=nil}, -- increase dmg of DDs
    ['combatinnate']=common.get_spell('Mana Radix Aura') or common.get_spell('Mana Replication Aura') or {name=nil,id=nil}, -- dmg proc on spells, Issuance of Mana Radix == place aura at location
    ['disempower']=common.get_spell('Arcane Disjunction Aura'),
    -- unity buffs
    ['shield']=common.get_spell('Shield of Shadow') or common.get_spell('Shield of Restless Ice') or {name=nil,id=nil},
    ['ward']=common.get_spell('Ward of the Beguiler') or common.get_spell('Ward of the Transfixer') or {name=nil,id=nil},
}
spells['synergy'] = common.get_spell('Mindreap') or common.get_spell('Mindrift') or common.get_spell('Mindslash') or {name=nil,id=nil} -- 63k nuke
if spells['synergy'] then
    if spells['synergy']['name']:find('reap') then
        spells['nuke5'] = common.get_spell('Mindrift') or common.get_spell('Mindslash') or {name=nil,id=nil}
    elseif spells['synergy']['name']:find('rift') then
        spells['nuke5'] = common.get_spell('Mindslash') or {name=nil,id=nil}
    end
end

for name,spell in pairs(spells) do
    if spell['name'] then
        logger.printf('[%s] Found spell: %s (%s)', name, spell['name'], spell['id'])
    else
        logger.printf('[%s] Could not find spell!', name)
    end
end

-- tash, command, chaotic, deceiving stare, pulmonary grip, mindrift, fortifying aura, mind coil, unity, dissident, mana replication, night's endless terror
-- entries in the dots table are pairs of {spell id, spell name} in priority order
local standard = {}
table.insert(standard, spells['tash'])
table.insert(standard, spells['dotmiti'])
table.insert(standard, spells['meznoblur'])
table.insert(standard, spells['mezae'])
table.insert(standard, spells['dot'])
table.insert(standard, spells['dot2'])
table.insert(standard, spells['synergy'])
table.insert(standard, spells['nuke5'])
table.insert(standard, spells['composite'])
table.insert(standard, spells['stunaerune'])
table.insert(standard, spells['guard'])
table.insert(standard, spells['nightsterror'])
table.insert(standard, spells['combatinnate'])

-- entries in the items table are MQ item datatypes
local items = {}
table.insert(items, mq.TLO.InvSlot('Chest').Item.ID()) -- buff, Consuming Magic, 10 minute CD
table.insert(items, mq.TLO.FindItem('Rage of Rolfron').ID()) -- song, 30 minute CD

-- entries in the AAs table are pairs of {aa name, aa id}
local AAs = {}
table.insert(AAs, common.get_aa('Silent Casting')) -- song, 12 minute CD
table.insert(AAs, common.get_aa('Focus of Arcanum')) -- buff, 10 minute CD
table.insert(AAs, common.get_aa('Illusions of Grandeur')) -- 12 minute CD, group spell crit buff
table.insert(AAs, common.get_aa('Calculated Insanity')) -- 20 minute CD, increase crit for 27 spells
table.insert(AAs, common.get_aa('Spire of Enchantment')) -- buff, 7:30 minute CD
table.insert(AAs, common.get_aa('Improved Twincast')) -- 15min CD
table.insert(AAs, common.get_aa('Chromatic Haze')) -- 15min CD
table.insert(AAs, common.get_aa('Companion\'s Fury')) -- 10 minute CD
table.insert(AAs, common.get_aa('Companion\'s Fortification')) -- 15 minute CD

--table.insert(AAs, get_aaid_and_name('Glyph of Destruction (115+)'))
--table.insert(AAs, get_aaid_and_name('Intensity of the Resolute'))

local mezbeam = common.get_aa('Beam of Slumber')
local longmez = common.get_aa('Noctambulate') -- 3min single target mez

local aekbblur = common.get_aa('Beguiler\'s Banishment')
local kbblur = common.get_aa('Beguiler\'s Directed Banishment')
local tash = common.get_aa('Bite of Tashani')
local aeblur = common.get_aa('Blanket of Forgetfulness')

local haze = common.get_aa('Chromatic Haze') -- 10min CD, buff 2 nukes for group

local shield = common.get_aa('Dimensional Shield')
local rune = common.get_aa('Eldritch Rune')
local grouprune = common.get_aa('Glyph Spray')
local reactiverune = common.get_aa('Reactive Rune') -- group buff, melee/spell shield that procs rune
local manarune = common.get_aa('Mind over Matter') -- absorb dmg using mana
local veil = common.get_aa('Veil of Mindshadow') -- 5min CD, another rune?

local slow = common.get_aa('Slowing Helix') -- single target slow
local aeslow = common.get_aa('Enveloping Helix') -- AE slow on 8 targets
local debuffdot = common.get_aa('Mental Corruption') -- decrease melee dmg + DoT

-- Buffs
local unity = common.get_aa('Orator\'s Unity')
-- Mana Recovery AAs
local azure = common.get_aa('Azure Mind Crystal') -- summon clicky mana heal
local gathermana = common.get_aa('Gather Mana')
local sanguine = common.get_aa('Sanguine Mind Crystal') -- summon clicky hp heal
-- Mana Recovery items
--local item_feather = mq.TLO.FindItem('Unified Phoenix Feather')
--local item_horn = mq.TLO.FindItem('Miniature Horn of Unity') -- 10 minute CD
-- Agro
local stasis = common.get_aa('Self Stasis')

local dispel = common.get_aa('Eradicate Magic')

local buffs={
    ['self']={},
    ['pet']={
        spells['pethaste'],
    },
}
--[[
    track data about our targets, for one-time or long-term affects.
    for example: we do not need to continually poll when to debuff a mob if the debuff will last 17+ minutes
    if the mob aint dead by then, you should re-roll a wizard.
]]--
local targets = {}

local SETTINGS_FILE = ('%s/encbot_%s_%s.lua'):format(mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me.CleanName())
enc.load_settings = function()
    local settings = config.load_settings(SETTINGS_FILE)
    if not settings or not settings.enc then return end
    if settings.enc.AURA1 ~= nil then OPTS.AURA1 = settings.enc.AURA1 end
    if settings.enc.AURA2 ~= nil then OPTS.AURA2 = settings.enc.AURA2 end
    if settings.enc.USEMEZ ~= nil then OPTS.USEMEZ = settings.enc.USEMEZ end
    if settings.enc.TASHTHENMEZ ~= nil then OPTS.TASHTHENMEZ = settings.enc.TASHTHENMEZ end
    if settings.enc.INTERRUPTFORMEZ ~= nil then OPTS.INTERRUPTFORMEZ = settings.enc.INTERRUPTFORMEZ end
    if settings.enc.USECHAOTIC ~= nil then OPTS.USECHAOTIC = settings.enc.USECHAOTIC end
    if settings.enc.USEDOT ~= nil then OPTS.USEDOT = settings.enc.USEDOT end
    if settings.enc.USENUKE ~= nil then OPTS.USENUKE = settings.enc.USENUKE end
    if settings.enc.USEERADICATE ~= nil then OPTS.USEERADICATE = settings.enc.USEERADICATE end
    if settings.enc.USETASH ~= nil then OPTS.USETASH = settings.enc.USETASH end
    if settings.enc.USETASHAOE ~= nil then OPTS.USETASHAOE = settings.enc.USETASHAOE end
    if settings.enc.USESLOW ~= nil then OPTS.USESLOW = settings.enc.USESLOW end
    if settings.enc.USESLOWAOE ~= nil then OPTS.USESLOWAOE = settings.enc.USESLOWAOE end
    if settings.enc.USEPHANTASMAL ~= nil then OPTS.USEPHANTASMAL = settings.enc.USEPHANTASMAL end
    if settings.enc.USEREPLICATION ~= nil then OPTS.USEREPLICATION = settings.enc.USEREPLICATION end
    if settings.enc.USESHIELDOFFATE ~= nil then OPTS.USESHIELDOFFATE = settings.enc.USESHIELDOFFATE end
    if settings.enc.USEMINDOVERMATTER ~= nil then OPTS.USEMINDOVERMATTER = settings.enc.USEMINDOVERMATTER end
    if settings.enc.USESPELLGUARD ~= nil then OPTS.USESPELLGUARD = settings.enc.USESPELLGUARD end
    if settings.enc.USENIGHTSTERROR ~= nil then OPTS.USENIGHTSTERROR = settings.enc.USENIGHTSTERROR end
    if settings.enc.USEHASTE ~= nil then OPTS.USEHASTE = settings.enc.USEHASTE end
    if settings.enc.SUMMONPET ~= nil then OPTS.SUMMONPET = settings.enc.SUMMONPET end
    if settings.enc.BUFFPET ~= nil then OPTS.BUFFPET = settings.enc.BUFFPET end
    if settings.enc.USECHARM ~= nil then OPTS.USECHARM = settings.enc.USECHARM end
end

enc.save_settings = function()
    persistence.store(SETTINGS_FILE, {common=config.get_all(), enc=OPTS})
end

enc.reset_class_timers = function()
    -- no-op
end

local function check_mez()
    if OPTS.MEZ then
        mez.do_ae(spells['mezae']['name'], common.cast)
        if not mq.TLO.Me.SpellInCooldown() then
            if not mq.TLO.Target.Tashed() and OPTS.TASHTHENMEZ and tash then
                common.use_aa(tash)
            end
            mez.do_single(spells['mezst']['name'], common.cast)
        end
    end
end

local function cast_synergy()
    if spells['synergy'] and not mq.TLO.Me.Song('Beguiler\'s Synergy')() and mq.TLO.Me.SpellReady(spells['synergy']['name'])() then
        if mq.TLO.Spell(spells['synergy']['name']).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        common.cast(spells['synergy']['name'], true)
        return true
    end
    return false
end

-- composite
-- synergy
-- nuke5
-- dot2
local function find_next_spell_to_cast()
    if not mq.TLO.Target.Tashed() and OPTS.USETASH and common.is_spell_ready(spells['tash']) then return spells['tash'] end
    if common.is_spell_ready(spells['composite']) then return spells['composite'] end
    if cast_synergy() then return nil end
    if common.is_spell_ready(spells['nuke5']) then return spells['nuke5'] end
    if common.is_dot_ready(spells['dot2']) then return spells['dot2'] end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

local SLOW_IMMUNES = {}

local function cycle_spells()
    if common.am_i_dead() then return false end
    local cur_mode = config.get_mode()
    if (cur_mode:is_tank_mode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:is_assist_mode() and assist.should_assist()) or (cur_mode:is_manual_mode() and mq.TLO.Me.CombatState() == 'COMBAT') then
        if mq.TLO.Target.Beneficial() and OPTS.USEERADICATE and dispel then
            common.use_aa(dispel)
        end
        if not mq.TLO.Target.Tashed() and OPTS.USETASHAOE and tash then
            common.use_aa(tash)
        end
        if not mq.TLO.Target.Slowed() and not SLOW_IMMUNES[mq.TLO.Target.CleanName()] then
            if OPTS.USESLOWAOE and aeslow then
                common.use_aa(aeslow)
            elseif OPTS.USESLOW and slow then
                common.use_aa(slow)
            end
            mq.doevents('event_slowimmune')
        end
        local spell = find_next_spell_to_cast() -- find the first available dot to cast that is missing from the target
        if spell then -- if a dot was found
            common.cast(spell['name'], true) -- then cast the dot
            return true
        end
    end
    return false
end

local function try_burn()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag.
    -- Test them both for each item, and see which one(s) actually work.
    if common.is_burn_condition_met() then
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
        |Spell Burn
        |===========================================================================================
        ]]--

        for _,aa in ipairs(AAs) do
            common.use_aa(aa)
        end

    end
end

local function check_mana()
    -- modrods
    common.check_mana()
    local pct_mana = mq.TLO.Me.PctMana()
    if gathermana and pct_mana < 50 then
        -- death bloom at some %
        common.use_aa(gathermana)
    end
    if pct_mana < 75 then
        local cursor = mq.TLO.Cursor()
        if cursor and cursor:find(azure['name']) then mq.cmd('/autoinventory') end
        local manacrystal = mq.TLO.FindItem(azure['name'])
        common.use_item(manacrystal)
    end
end

local check_aggro_timer = timer:new(10)
local function check_aggro()
    if mq.TLO.Me.PctHPs() < 40 then
        local cursor = mq.TLO.Cursor()
        if cursor and cursor:find(sanguine['name']) then mq.cmd('/autoinventory') end
        local hpcrystal = mq.TLO.FindItem('='..sanguine['name'])
        common.use_item(hpcrystal)
    end
    if mq.TLO.Me.CombatState() == 'COMBAT' and mq.TLO.Target() then
        if mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID() or check_aggro_timer:timer_expired() then
            if mq.TLO.Me.PctAggro() >= 90 then

            end
        end
    end
end

local function missing_unity_buffs(name)
    local spell = mq.TLO.Spell(name)
    for i=1,spell.NumEffects() do
        local trigger_spell = spell.Trigger(i)
        if not mq.TLO.Me.Buff(trigger_spell.Name())() then return true end
    end
    return false
end

-- group guards - legion of liako / xetheg
local function check_buffs()
    if common.am_i_dead() or mq.TLO.Me.Moving() then return end
-- now buffs:
-- - spells['guard'] (shield of inevitability - quick-refresh, strong direct damage spell guard and melee-strike rune combined into one.)
-- - spells['stunaerune'] (polyluminous rune - quick-refresh, damage absorption rune with a PB AE stun once consumed.)
-- - rune (eldritch rune - AA rune, always pre-buffed.)
-- - veil (Veil of the Mindshadow – AA rune, always pre-buffed.)
    if spells['guard'] and not mq.TLO.Me.Buff(spells['guard']['name'])() then
        if common.cast(spells['guard']['name']) then return end
    end
    if spells['stunaerune'] and not mq.TLO.Me.Buff(spells['stunaerune']['name'])() then
        if common.cast(spells['stunaerune']['name']) then return end
    end
    if rune and not mq.TLO.Me.Buff(rune['name'])() then
        if common.use_aa(rune['name']) then return end
    end
    if veil and not mq.TLO.Me.Buff(veil['name'])() then
        if common.use_aa(veil['name']) then return end
    end
    common.check_combat_buffs()
    --if common.is_fighting() then return end
    if not common.clear_to_buff() then return end

    if unity and missing_unity_buffs(unity['name']) then
        if common.use_aa(unity) then return end
    end

    local hpcrystal = mq.TLO.FindItem(sanguine['name'])
    local manacrystal = mq.TLO.FindItem(azure['name'])
    if sanguine and not hpcrystal() then
        if common.use_aa(sanguine) then return end
    end
    if azure and not manacrystal() then
        if common.use_aa(azure) then return end
    end

    if OPTS.AURA1 == 'twincast' and spells['twincast'] and not mq.TLO.Me.Aura('Twincast Aura')() then
        if common.swap_and_cast(spells[OPTS.AURA1], 13) then return end
    elseif OPTS.AURA1 ~= 'twincast' and spells[OPTS.AURA1] and not mq.TLO.Me.Aura(spells[OPTS.AURA1]['name'])() then
        if common.swap_and_cast(spells[OPTS.AURA1], 13) then return end
    end
    if OPTS.AURA2 == 'twincast' and spells['twincast'] and not mq.TLO.Me.Aura('Twincast Aura')() then
        if common.swap_and_cast(spells[OPTS.AURA2], 13) then return end
    elseif OPTS.AURA2 ~= 'twincast' and spells[OPTS.AURA2] and not mq.TLO.Me.Aura(spells[OPTS.AURA2]['name'])() then
        if common.swap_and_cast(spells[OPTS.AURA2], 13) then return end
    end

    -- kei
    -- haste

    common.check_item_buffs()

    if OPTS.BUFFPET and mq.TLO.Pet.ID() > 0 then
        --for _,buff in ipairs(buffs['pet']) do
        --    if not mq.TLO.Pet.Buff(buff['name'])() and mq.TLO.Spell(buff['name']).StacksPet() and mq.TLO.Spell(buff['name']).Mana() < mq.TLO.Me.CurrentMana() then
        --        common.swap_and_cast(buff['name'], 13)
        --    end
        --end
    end
end

local function check_pet()
    if not common.clear_to_buff() or mq.TLO.Pet.ID() > 0 or mq.TLO.Me.Moving() or not spells['pet'] then return end
    if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.get_camp_radius()))() > 0 then return end
    if mq.TLO.Spell(spells['pet']['name']).Mana() > mq.TLO.Me.CurrentMana() then return end
    common.swap_and_cast(spells['pet'], 13)
end

local composite_names = {['Composite Reinforcement']=true,['Dissident Reinforcement']=true,['Dichotomic Reinforcement']=true}
local check_spell_timer = timer:new(30)
local function check_spell_set()
    if not common.clear_to_buff() or mq.TLO.Me.Moving() or common.am_i_dead() then return end
    if state.get_spellset_loaded() ~= config.get_spell_set() or check_spell_timer:timer_expired() then
        if config.get_spell_set() == 'standard' then
            common.swap_spell(spells['tash'], 1)
            common.swap_spell(spells['dotmiti'], 2)
            common.swap_spell(spells['meznoblur'], 3)
            common.swap_spell(spells['mezae'], 4)
            common.swap_spell(spells['dot'], 5)
            common.swap_spell(spells['dot2'], 6)
            common.swap_spell(spells['synergy'], 7)
            common.swap_spell(spells['nuke5'], 8)
            common.swap_spell(spells['composite'], 9, composite_names)
            common.swap_spell(spells['stunaerune'], 10)
            common.swap_spell(spells['guard'], 11)
            common.swap_spell(spells['nightsterror'], 12)
            common.swap_spell(spells['combatinnate'], 13)
            state.set_spellset_loaded(config.get_spell_set())
        end
        check_spell_timer:reset()
    end
end

local function event_slowimmune(line)
    local target_name = mq.TLO.Target.CleanName()
    if target_name and not SLOW_IMMUNES[target_name] then
        SLOW_IMMUNES[target_name] = 1
    end
end

--[[
#Event CAST_IMMUNE                 "Your target has no mana to affect#*#"
#Event CAST_IMMUNE                 "Your target is immune to changes in its attack speed#*#"
#Event CAST_IMMUNE                 "Your target is immune to changes in its run speed#*#"
#Event CAST_IMMUNE                 "Your target is immune to snare spells#*#"
#Event CAST_IMMUNE                 "Your target is immune to the stun portion of this effect#*#"
#Event CAST_IMMUNE                 "Your target cannot be mesmerized#*#"
#Event CAST_IMMUNE                 "Your target looks unaffected#*#"
]]--
enc.setup_events = function()
    mez.setup_events()
    mq.event('event_slowimmune', 'Your target is immune to changes in its attack speed#*#', event_slowimmune)
end

enc.process_cmd = function(opt, new_value)
    if new_value then
        if opt == 'AURA1' then
            if AURAS[new_value] then
                logger.printf('Setting %s to: %s', opt, new_value)
                OPTS.AURA1 = new_value
            end
        elseif opt == 'AURA2' then
            if AURAS[new_value] then
                logger.printf('Setting %s to: %s', opt, new_value)
                OPTS.AURA2 = new_value
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
        if OPTS[opt] ~= nil then
            logger.printf('%s: %s', opt:lower(), OPTS[opt])
        else
            logger.printf('Unrecognized option: %s', opt)
        end
    end
end

enc.main_loop = function()
    -- ensure correct spells are loaded based on selected spell set
    -- currently only checks at startup or when selection changes
    check_spell_set()
    -- check whether we need to return to camp
    camp.check_camp()
    -- check whether we need to go chasing after the chase target
    common.check_chase()
    camp.mob_radar()
    -- check we have the correct target to attack
    assist.check_target()
    check_mez()
    -- if we should be assisting but aren't in los, try to be?
    assist.check_los()
    -- begin actual combat stuff
    assist.send_pet()
    cycle_spells()
    -- pop a bunch of burn stuff if burn conditions are met
    try_burn()
    -- try not to run OOM
    check_aggro()
    check_mana()
    check_buffs()
    check_pet()
    common.rest()
end

enc.draw_skills_tab = function()
    OPTS.AURA1 = ui.draw_combo_box('Aura 1', OPTS.AURA1, AURAS, true)
    OPTS.AURA2 = ui.draw_combo_box('Aura 2', OPTS.AURA2, AURAS, true)
    OPTS.USEMEZ = ui.draw_check_box('Use Mez', '##userez', OPTS.USEMEZ, 'Use Convergence AA to rez group members')
    OPTS.TASHTHENMEZ = ui.draw_check_box('Tash Then Mez', '##tashmez', OPTS.TASHTHENMEZ, 'Use pet buff')
    OPTS.INTERRUPTFORMEZ = ui.draw_check_box('Interrupt for Mez', '##interrupt', OPTS.INTERRUPTFORMEZ, 'Summon pet')
    OPTS.USECHAOTIC = ui.draw_check_box('Use Chaotic', '##chaoticmez', OPTS.USECHAOTIC, 'Use Inspire Ally pet buff')
    OPTS.USEDOT = ui.draw_check_box('Use DoT', '##usedot', OPTS.USEDOT, 'Use group mana drain dot. Replaces Ignite DoT.')
    OPTS.USENUKE = ui.draw_check_box('Use Nuke', '##usenuke', OPTS.USENUKE, 'Use Convergence AA to rez group members')
    OPTS.USEERADICATE = ui.draw_check_box('Use Dispel', '##dispel', OPTS.USEERADICATE, 'Dispel mobs with Eradicate Magic AA')
    OPTS.USETASH = ui.draw_check_box('Use Tash', '##usetash', OPTS.USETASH, 'Use Convergence AA to rez group members')
    OPTS.USETASHAOE = ui.draw_check_box('Use Tash AOE', '##usetashaoe', OPTS.USETASHAOE, 'Use Convergence AA to rez group members')
    OPTS.USESLOW = ui.draw_check_box('Use Slow', '##useslow', OPTS.USESLOW, 'Use Convergence AA to rez group members')
    OPTS.USESLOWAOE = ui.draw_check_box('Use Slow AOE', '##useslowaoe', OPTS.USESLOWAOE, 'Use Convergence AA to rez group members')
    OPTS.USESPELLGUARD = ui.draw_check_box('Use Spell Guard', '##usespellguard', OPTS.USESPELLGUARD, 'Use Convergence AA to rez group members')
    OPTS.USEMINDOVERMATTER = ui.draw_check_box('Use Mind Over Matter', '##usemom', OPTS.USEMINDOVERMATTER, 'Use Convergence AA to rez group members')
    OPTS.USEPHANTASMAL = ui.draw_check_box('Use Phantasmal', '##usephant', OPTS.USEPHANTASMAL, 'Use Convergence AA to rez group members')
    OPTS.USESHIELDOFFATE = ui.draw_check_box('Use Shield of Fate', '##useshield', OPTS.USESHIELDOFFATE, 'Use Convergence AA to rez group members')
    OPTS.USEREPLICATION = ui.draw_check_box('Buff Mana Proc', '##userepl', OPTS.USEREPLICATION, 'Use Convergence AA to rez group members')
    OPTS.USENIGHTSTERROR = ui.draw_check_box('Buff Nights Terror', '##useterror', OPTS.USENIGHTSTERROR, 'Debuff targets')
    OPTS.USEHASTE = ui.draw_check_box('Buff Haste', '##usehaste', OPTS.USEHASTE, 'Use FD AA\'s to reduce aggro')
    OPTS.SUMMONPET = ui.draw_check_box('Summon Pet', '##summonpet', OPTS.SUMMONPET, 'Use Convergence AA to rez group members')
    OPTS.BUFFPET = ui.draw_check_box('Buff Pet', '##buffpet', OPTS.BUFFPET, 'Use Convergence AA to rez group members')
    OPTS.USECHARM = ui.draw_check_box('Use Charm', '##usecharm', OPTS.USECHARM, 'Keep shield buff up. Replaces corruption DoT.')
end

enc.draw_burn_tab = function()
    config.set_burn_always(ui.draw_check_box('Burn Always', '##burnalways', config.get_burn_always(), 'Always be burning'))
    config.set_burn_all_named(ui.draw_check_box('Burn Named', '##burnnamed', config.get_burn_all_named(), 'Burn all named'))
    config.set_burn_count(ui.draw_input_int('Burn Count', '##burncnt', config.get_burn_count(), 'Trigger burns if this many mobs are on aggro'))
    config.set_burn_percent(ui.draw_input_int('Burn Percent', '##burnpct', config.get_burn_percent(), 'Percent health to begin burns'))
end

return enc