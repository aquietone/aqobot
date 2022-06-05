--- @type mq
local mq = require 'mq'
local assist = require('aqo.routines.assist')
local camp = require('aqo.routines.camp')
local pull = require('aqo.routines.pull')
local tank = require('aqo.routines.tank')
local logger = require('aqo.utils.logger')
local persistence = require('aqo.utils.persistence')
local timer = require('aqo.utils.timer')
local common = require('aqo.common')
local config = require('aqo.configuration')
local state = require('aqo.state')
local ui = require('aqo.ui')

local shd = {}

local SPELLSETS = {standard=1,dps=1}
local OPTS = {
    SUMMONPET=true,
    BUFFPET=true,
    USEHATESATTRACTION=true,
    USEPROJECTION=true,
    USEBEZA=false,
    USEDISRUPTION=true,
    USEINSIDIOUS=false,
    USELIFETAP=true,
    USEVOICEOFTHULE=false,
    USETORRENT=true,
    USESWARM=true,
    USEDEFLECTION=false,
}
config.set_spell_set('standard')
mq.cmd('/squelch /stick mod -2')

local spells = {
    ['composite']=common.get_spellid_and_rank('Composite Fang'), -- big lifetap
    ['alliance']=common.get_spellid_and_rank('Bloodletting Coalition'), -- alliance
    -- Aggro
    ['challenge']=common.get_spellid_and_rank('Parlay for Power'), -- main hate spell
    ['terror']=common.get_spellid_and_rank('Terror of Ander'), -- ST increase hate by 1
    ['aeterror']=common.get_spellid_and_rank('Antipathy'), -- ST increase hate by 1
    --['']=common.get_spellid_and_rank('Usurper\'s Audacity'), -- increase hate by a lot, does this get used?
    -- Lifetaps
    ['largetap']=common.get_spellid_and_rank('Dire Censure'), -- large lifetap
    ['tap1']=common.get_spellid_and_rank('Touch of Txiki'), -- lifetap
    ['tap2']=common.get_spellid_and_rank('Touch of Namdrows'), -- lifetap + temp hp buff Gift of Namdrows
    ['dottap']=common.get_spellid_and_rank('Bond of Bynn'), -- lifetap dot
    ['bitetap']=common.get_spellid_and_rank('Cruor\'s Bite'), -- lifetap with hp/mana recourse
    -- AE lifetap + aggro
    ['aetap']=common.get_spellid_and_rank('Insidious Renunciation'), -- large hate + lifetap
    -- DPS
    ['spear']=common.get_spellid_and_rank('Spear of Bloodwretch'), -- poison nuke
    ['poison']=common.get_spellid_and_rank('Blood of Tearc'), -- poison dot
    ['disease']=common.get_spellid_and_rank('Plague of Fleshrot'), -- disease dot
    ['corruption']=common.get_spellid_and_rank('Unscrupulous Blight'), -- corruption dot
    ['acdis']=common.get_spellid_and_rank('Dire Seizure'), -- disease + ac dot
    ['acdebuff']=common.get_spellid_and_rank('Torrent of Melancholy'), -- ac debuff
    --['']=common.get_spellid_and_rank('Despicable Bargain'), -- nuke, does this get used?
    -- Short Term Buffs
    ['stance']=common.get_spellid_and_rank('Adamant Stance'), -- temp HP buff, 2.5min
    ['skin']=common.get_spellid_and_rank('Xenacious\' Skin'), -- Xenacious' Skin proc, 5min buff
    ['disruption']=common.get_spellid_and_rank('Confluent Disruption'), -- lifetap proc on heal
    --['']=common.get_spellid_and_rank('Impertinent Influence'), -- ac buff, 20% dmg mitigation, lifetap proc, is this upgraded by xetheg's carapace? stacks?
    -- Pet
    ['pet']=common.get_spellid_and_rank('Minion of Itzal'), -- pet
    ['pethaste']=common.get_spellid_and_rank('Gift of Itzal'), -- pet haste
    -- Unity Buffs
    ['shroud']=common.get_spellid_and_rank('Shroud of Zelinstein'), -- Shroud of Zelinstein Strike proc
    ['bezaproc']=common.get_spellid_and_rank('Mental Anguish'), -- Mental Anguish Strike proc
    ['aziaproc']=common.get_spellid_and_rank('Brightfield\'s Horror'), -- Brightfield's Horror Strike proc
    ['ds']=common.get_spellid_and_rank('Tekuel Skin'), -- large damage shield self buff
    ['lich']=common.get_spellid_and_rank('Aten Ha Ra\'s Covenant'), -- lich mana regen
    ['drape']=common.get_spellid_and_rank('Drape of the Akheva'), -- self buff hp, ac, ds
    ['atkbuff']=common.get_spellid_and_rank('Penumbral Call'), -- atk buff, hp drain on self
    --['']=common.get_spellid_and_rank('Remorseless Demeanor')
}
for name,spell in pairs(spells) do
    if spell['name'] then
        logger.printf('[%s] Found spell: %s (%s)', name, spell['name'], spell['id'])
    else
        logger.printf('[%s] Could not find spell!', name)
    end
end

local standard = {}
table.insert(standard, spells['tap1'])
table.insert(standard, spells['tap2'])
table.insert(standard, spells['largetap'])
table.insert(standard, spells['composite'])
table.insert(standard, spells['spear'])
table.insert(standard, spells['terror'])
table.insert(standard, spells['aeterror'])
table.insert(standard, spells['dottap'])
table.insert(standard, spells['challenge'])
table.insert(standard, spells['bitetap'])
table.insert(standard, spells['stance'])
table.insert(standard, spells['skin'])
table.insert(standard, spells['acdebuff'])

local dps = {}
table.insert(dps, spells['tap1'])
table.insert(dps, spells['tap2'])
table.insert(dps, spells['largetap'])
table.insert(dps, spells['composite'])
table.insert(dps, spells['spear'])
table.insert(dps, spells['corruption'])
table.insert(dps, spells['poison'])
table.insert(dps, spells['dottap'])
table.insert(dps, spells['disease'])
table.insert(dps, spells['bitetap'])
table.insert(dps, spells['stance'])
table.insert(dps, spells['skin'])
table.insert(dps, spells['acdebuff'])

local spellsets = {
    ['standard']=standard,
    ['dps']=dps,
}

-- TANK
-- defensives
local flash = common.get_aaid_and_name('Shield Flash') -- 4min CD, short deflection
local mantle = common.get_discid_and_name('Fyrthek Mantle') -- 15min CD, 35% melee dmg mitigation, heal on fade
local carapace = common.get_discid_and_name('Xetheg\'s Carapace') -- 7m30s CD, ac buff, 20% dmg mitigation, lifetap proc
local guardian = common.get_discid_and_name('Corrupted Guardian Discipline') -- 12min CD, 36% mitigation, large damage debuff to self, lifetap proc
local deflection = common.get_discid_and_name('Deflection Discipline', 'USEDEFLECTION')

local mashAggroAbilities = {}
table.insert(mashAggroAbilities, 'Taunt')
local mashAggroSpells = {}
table.insert(mashAggroSpells, spells['challenge'])
table.insert(mashAggroSpells, spells['terror'])
local mashAggroDiscs = {}
table.insert(mashAggroDiscs, common.get_discid_and_name('Repudiate')) -- mash, 90% melee/spell dmg mitigation, 2 ticks or 85k dmg
local mashAggroAAs = {}
table.insert(mashAggroAAs, common.get_aaid_and_name('Projection of Doom', 'USEPROJECTION')) -- aggro swarm pet
--table.insert(mashAggroAAs, common.get_aaid_and_name('Hate\'s Attraction', 'USEHATESATTRACTION'))
local attraction = common.get_aaid_and_name('Hate\'s Attraction', 'USEHATESATTRACTION') -- aggro swarm pet

-- mash AE aggro
local mashAESpells = {}
table.insert(mashAESpells, spells['aeterror'])
local mashAEAggroAAs2 = {}
table.insert(mashAEAggroAAs2, common.get_aaid_and_name('Explosion of Spite')) -- 45sec CD
local mashAEAggroAAs4 = {}
table.insert(mashAEAggroAAs4, common.get_aaid_and_name('Explosion of Hatred')) -- 45sec CD
--table.insert(mashAEAggroAAs4, common.get_aaid_and_name('Stream of Hatred')) -- large frontal cone ae aggro

local burnAggroDiscs = {}
table.insert(burnAggroDiscs, common.get_discid_and_name('Unrelenting Acrimony')) -- instant aggro
local burnAggroAAs = {}
table.insert(burnAggroAAs, common.get_aaid_and_name('Ageless Enmity')) -- big taunt
table.insert(burnAggroAAs, common.get_aaid_and_name('Veil of Darkness')) -- large agro, lifetap, blind, mana/end tap
table.insert(burnAggroAAs, common.get_aaid_and_name('Reaver\'s Bargain')) -- 20min CD, 75% melee dmg absorb

-- DPS
local mashDPSAbilities = {}
table.insert(mashDPSAbilities, 'Bash')

local mashDPSDiscs = {}
table.insert(mashDPSDiscs, common.get_discid_and_name('Reflexive Resentment')) -- 3x 2hs attack + heal

local mashDPSAAs = {}
table.insert(mashDPSAAs, common.get_aaid_and_name('Vicious Bite of Chaos')) -- 1min CD, nuke + group heal
table.insert(mashDPSAAs, common.get_aaid_and_name('Spire of the Reavers')) -- 7m30s CD, dmg,crit,parry,avoidance buff

local burnDPSDiscs = {}
table.insert(burnDPSDiscs, common.get_discid_and_name('Grisly Blade')) -- 2hs attack
table.insert(burnDPSDiscs, common.get_discid_and_name('Sanguine Blade')) -- 3 strikes

local burnDPSAAs = {}
table.insert(burnDPSAAs, common.get_aaid_and_name('Gift of the Quick Spear')) -- 10min CD, twincast
table.insert(burnDPSAAs, common.get_aaid_and_name('T`Vyl\'s Resolve')) -- 10min CD, dmg buff on 1 target
table.insert(burnDPSAAs, common.get_aaid_and_name('Harm Touch')) -- 20min CD, giant nuke + dot
table.insert(burnDPSAAs, common.get_aaid_and_name('Leech Touch')) -- 9min CD, giant lifetap
table.insert(burnDPSAAs, common.get_aaid_and_name('Thought Leech')) -- 18min CD, nuke + mana/end tap
table.insert(burnDPSAAs, common.get_aaid_and_name('Scourge Skin')) -- 15min CD, large DS
table.insert(burnDPSAAs, common.get_aaid_and_name('Chattering Bones', 'USESWARM')) -- 10min CD, swarm pet
table.insert(burnDPSAAs, common.get_aaid_and_name('Visage of Death')) -- 12min CD, melee dmg burn
table.insert(burnDPSAAs, common.get_aaid_and_name('Visage of Decay')) -- 12min CD, dot dmg burn

local leechtouch = common.get_aaid_and_name('Leech Touch') -- 9min CD, giant lifetap

-- Buffs
-- dark lord's unity azia X -- shroud of zelinstein, brightfield's horror, drape of the akheva, remorseless demeanor, tekuel skin, aten ha ra's covenant, penumbral call
local buffazia = common.get_aaid_and_name('Dark Lord\'s Unity (Azia)')
-- dark lord's unity beza X -- shroud of zelinstein, mental anguish, drape of the akheva, remorseless demeanor, tekuel skin, aten ha ra's covenant, penumbral call
local buffbeza = common.get_aaid_and_name('Dark Lord\'s Unity (Beza)', 'USEBEZA')
local voice = common.get_aaid_and_name('Voice of Thule', 'USEVOICEOFTHULE') -- aggro mod buff

-- entries in the items table are MQ item datatypes
local items = {}
table.insert(items, mq.TLO.InvSlot('Chest').Item.ID())
table.insert(items, mq.TLO.FindItem('Rage of Rolfron').ID())
table.insert(items, mq.TLO.FindItem('Blood Drinker\'s Coating').ID())

local epic = mq.TLO.FindItem('=Innoruuk\'s Dark Blessing').ID()

local buff_items = {}
table.insert(buff_items, mq.TLO.FindItem('Chestplate of the Dark Flame').ID())
table.insert(buff_items, mq.TLO.FindItem('Violet Conch of the Tempest').ID())

local SETTINGS_FILE = ('%s/shdbot_%s_%s.lua'):format(mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me.CleanName())
shd.load_settings = function()
    local settings = config.load_settings(SETTINGS_FILE)
    if not settings or not settings.shd then return end
    if settings.shd.SUMMONPET ~= nil then OPTS.SUMMONPET = settings.shd.SUMMONPET end
    if settings.shd.BUFFPET ~= nil then OPTS.BUFFPET = settings.shd.BUFFPET end
    if settings.shd.USEHATESATTRACTION ~= nil then OPTS.USEHATESATTRACTION = settings.shd.USEHATESATTRACTION end
    if settings.shd.USEPROJECTION ~= nil then OPTS.USEPROJECTION = settings.shd.USEPROJECTION end
    if settings.shd.USEBEZA ~= nil then OPTS.USEBEZA = settings.shd.USEBEZA end
    if settings.shd.USEDISRUPTION ~= nil then OPTS.USEDISRUPTION = settings.shd.USEDISRUPTION end
    if settings.shd.USEINSIDIOUS ~= nil then OPTS.USEINSIDIOUS = settings.shd.USEINSIDIOUS end
    if settings.shd.USELIFETAP ~= nil then OPTS.USELIFETAP = settings.shd.USELIFETAP end
    if settings.shd.USEVOICEOFTHULE ~= nil then OPTS.USEVOICEOFTHULE = settings.shd.USEVOICEOFTHULE end
    if settings.shd.USETORRENT ~= nil then OPTS.USETORRENT = settings.shd.USETORRENT end
    if settings.shd.USESWARM ~= nil then OPTS.USESWARM = settings.shd.USESWARM end
    if settings.shd.USEDEFLECTION ~= nil then OPTS.USEDEFLECTION = settings.shd.USEDEFLECTION end
end

shd.save_settings = function()
    persistence.store(SETTINGS_FILE, {common=config.get_all(), shd=OPTS})
end

shd.reset_class_timers = function()
    -- no-op
end

local function is_dot_ready(spell)
    local spellId = spell['id']
    local spellName = spell['name']
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

local function is_spell_ready(spell)
    local spellName = spell['name']
    if mq.TLO.Spell(spellName).Mana() > mq.TLO.Me.CurrentMana() or (mq.TLO.Spell(spellName).Mana() > 1000 and mq.TLO.Me.PctMana() < state.get_min_mana()) then
        return false
    end
    if mq.TLO.Spell(spellName).EnduranceCost() > mq.TLO.Me.CurrentEndurance() or (mq.TLO.Spell(spellName).EnduranceCost() > 1000 and mq.TLO.Me.PctEndurance() < state.get_min_end()) then
        return false
    end
    if mq.TLO.Spell(spellName).TargetType() == 'Single' then
        if not mq.TLO.Target() or mq.TLO.Target.Type() == 'Corpse' then return false end
    end

    if not mq.TLO.Me.SpellReady(spellName)() then
        return false
    end

    return true
end

local function find_next_spell()
    local myhp = mq.TLO.Me.PctHPs()
    -- aggro
    if config.get_mode():is_tank_mode() and config.get_spell_set() == 'standard' and myhp > 70 then
        if state.get_mob_count() > 2 and is_spell_ready(spells['aeterror']) then return spells['aeterror'] end
        if is_spell_ready(spells['terror']) then return spells['terror'] end
    end
    -- taps
    if myhp < 75 then
        if is_spell_ready(spells['composite']) then return spells['composite'] end
        if is_spell_ready(spells['largetap']) then return spells['largetap'] end
    end
    if myhp < 95 then
        if is_spell_ready(spells['tap1']) then return spells['tap1'] end
        if is_spell_ready(spells['tap2']) then return spells['tap2'] end
    end
    if is_dot_ready(spells['dottap']) then return spells['dottap'] end
    if is_spell_ready(spells['bitetap']) then return spells['bitetap'] end
    if is_dot_ready(spells['acdebuff']) then return spells['acdebuff'] end
    -- dps
    if is_spell_ready(spells['spear']) then return spells['spear'] end
    if config.get_mode():is_assist_mode() and config.get_spell_set() == 'dps' then
        if is_dot_ready(spells['poison']) then return spells['poison'] end
        if is_dot_ready(spells['disease']) then return spells['disease'] end
        if is_dot_ready(spells['corruption']) then return spells['corruption'] end
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

local function cycle_spells()
    if common.am_i_dead() then return end
    if not mq.TLO.Me.Invis() and common.is_fighting() then
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

local aggro_nopet_count = 'xtarhater radius 50 zradius 50 nopet'
local function check_ae()
    if common.am_i_dead() then return end
    -- count number of aggro mobs on xtarget that are < 100% aggro
    -- and not current target.
    -- if > 0, then we need some ae aggro
    local xtar_aggro_count = 0
    for i=1,mq.TLO.Me.XTarget() do
        local xtar = mq.TLO.Me.XTarget(i)
        local xtarid = xtar.ID()
        local targettype = xtar.TargetType()
        local pctaggro = xtar.PctAggro()
        if xtarid ~= mq.TLO.Target.ID() and targettype == 'Auto Hater' and pctaggro and pctaggro < 100 then
            xtar_aggro_count = xtar_aggro_count + 1
        end
    end
    -- if 1 or more mobs on xtarget < 100 aggro then no ae needed
    if xtar_aggro_count == 0 then return end
    -- now see how many xtarhater spawns are actually in range of ae
    local mobs_in_range = mq.TLO.SpawnCount(aggro_nopet_count)()
    if mobs_in_range >= 3 then
        local epicitem = mq.TLO.FindItem(epic)
        common.use_item(epicitem)
        common.use_disc(carapace)
    end
    if mobs_in_range >= 2 then
        -- Discs to use when 2 or more mobs on aggro
        for _,aa in ipairs(mashAEAggroAAs2) do
            if not aa['opt'] or OPTS[aa['opt']] then
                if common.use_aa(aa) then return end
            end
        end
        if mobs_in_range >= 4 then
            -- Discs to use when 4 or more mobs on aggro
            for _,aa in ipairs(mashAEAggroAAs4) do
                if not aa['opt'] or OPTS[aa['opt']] then
                    if common.use_aa(aa) then return end
                end
            end
        end
    end
end

local function mash()
    if common.is_fighting() or assist.should_assist() then
        local target = mq.TLO.Target
        local dist = target.Distance3D()
        local maxdist = target.MaxRangeTo()
        local mobhp = target.PctHPs()

        -- hate's attraction
        if OPTS.USEHATESATTRACTION and mobhp and mobhp > 95 then
            common.use_aa(attraction)
        end

        if config.get_mode():is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
            for _,disc in ipairs(mashAggroDiscs) do
                if not disc['opt'] or OPTS[disc['opt']] then
                    common.use_disc(disc)
                end
            end
            for _,aa in ipairs(mashAggroAAs) do
                if not aa['opt'] or OPTS[aa['opt']] then
                    common.use_aa(aa)
                end
            end
            if dist and maxdist and dist < maxdist then
                for _,ability in ipairs(mashAggroAbilities) do
                    common.use_ability(ability)
                end
            end
        end
        for _,aa in ipairs(mashDPSAAs) do
            if not aa['opt'] or OPTS[aa['opt']] then
                common.use_aa(aa)
            end
        end
        for _,disc in ipairs(mashDPSDiscs) do
            if not disc['opt'] or OPTS[disc['opt']] then
                common.use_disc(disc)
            end
        end
        if dist and maxdist and dist < maxdist then
            for _,ability in ipairs(mashDPSAbilities) do
                common.use_ability(ability)
            end
        end
    end
end

local function try_burn()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag.
    -- Test them both for each item, and see which one(s) actually work.
    if common.is_burn_condition_met() then
        if config.get_mode():is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
            -- , , 
            common.use_disc(mantle)
            common.use_disc(carapace)
            common.use_disc(guardian)

            for _,disc in ipairs(burnAggroDiscs) do
                common.use_disc(disc)
            end
            for _,aa in ipairs(burnAggroAAs) do
                common.use_aa(aa)
            end
        end

        local epicitem = mq.TLO.FindItem(epic)
        common.use_item(epicitem)

        for _,disc in ipairs(burnDPSDiscs) do
            common.use_disc(disc)
        end

        -- use DPS burn AAs in either mode
        for _,aa in ipairs(burnDPSAAs) do
            common.use_aa(aa)
        end

        --Item Burn
        for _,item_id in ipairs(items) do
            local item = mq.TLO.FindItem(item_id)
            common.use_item(item)
        end
    end
end

local function oh_shit()
    if mq.TLO.Me.PctHPs() < 35 and common.is_fighting() then
        if config.get_mode():is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
            if mq.TLO.Me.AltAbilityReady(flash['name'])() then
                common.use_aa(flash)
            elseif OPTS.USEDEFLECTION then
                common.use_disc(deflection)
            end
            common.use_aa(leechtouch)
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

local function check_buffs()
    if common.am_i_dead() then return end
    common.check_combat_buffs()
    -- stance, disruption, skin
    if not mq.TLO.Me.Buff(spells['stance']['name'])() then
        if common.cast(spells['stance']['name']) then return end
    end
    if not mq.TLO.Me.Buff(spells['skin']['name'])() then
        if common.cast(spells['skin']['name']) then return end
    end

    if common.is_fighting() then return end
    if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.get_camp_radius()))() > 0 then return end

    if OPTS.USEDISRUPTION and not mq.TLO.Me.Buff(spells['disruption']['name'])() then
        if common.swap_and_cast(spells['disruption']['name'], 13) then return end
    end

    if not OPTS.USEBEZA and missing_unity_buffs(buffazia['name']) then
        if common.use_aa(buffazia) then return end
    end
    if OPTS.USEBEZA and missing_unity_buffs(buffbeza['name']) then
        if common.use_aa(buffbeza) then return end
    end

    common.check_item_buffs()
    for _,itemid in ipairs(buff_items) do
        local item = mq.TLO.FindItem(itemid)
        if not mq.TLO.Me.Buff(item.Clicky())() then
            common.use_item(item)
        end
    end

    if OPTS.BUFFPET and mq.TLO.Pet.ID() > 0 then
        if not mq.TLO.Pet.Buff(spells['pethaste']['name'])() and mq.TLO.Spell(spells['pethaste']['name']).StacksPet() and mq.TLO.Spell(spells['pethaste']['name']).Mana() < mq.TLO.Me.CurrentMana() then
            common.swap_and_cast(spells['pethaste']['name'], 13)
        end
    end
end

local function check_pet()
    if common.is_fighting() or mq.TLO.Pet.ID() > 0 or mq.TLO.Me.Moving() then return end
    if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.get_camp_radius()))() > 0 then return end
    if mq.TLO.Spell(spells['pet']['name']).Mana() > mq.TLO.Me.CurrentMana() then return end
    common.swap_and_cast(spells['pet']['name'], 13)
end

local check_spell_timer = timer:new(30)
local function check_spell_set()
    if common.is_fighting() or mq.TLO.Me.Moving() or common.am_i_dead() or OPTS.BYOS then return end
    if state.get_spellset_loaded() ~= config.get_spell_set() or check_spell_timer:timer_expired() then
        if config.get_spell_set() == 'standard' then
            if mq.TLO.Me.Gem(1)() ~= spells['tap1']['name'] then common.swap_spell(spells['tap1']['name'], 1) end
            if mq.TLO.Me.Gem(2)() ~= spells['tap2']['name'] then common.swap_spell(spells['tap2']['name'], 2) end
            if mq.TLO.Me.Gem(3)() ~= spells['largetap']['name'] then common.swap_spell(spells['largetap']['name'], 3) end
            if not mq.TLO.Me.Gem(4)() or (mq.TLO.Me.Gem(4)() ~= 'Composite Fang' and mq.TLO.Me.Gem(4)() ~= 'Dissident Fang' and mq.TLO.Me.Gem(4)() ~= 'Dichotomic Fang') then common.swap_spell(spells['composite']['name'], 4) end
            if mq.TLO.Me.Gem(5)() ~= spells['spear']['name'] then common.swap_spell(spells['spear']['name'], 5) end
            if mq.TLO.Me.Gem(6)() ~= spells['terror']['name'] then common.swap_spell(spells['terror']['name'], 6) end
            if mq.TLO.Me.Gem(7)() ~= spells['aeterror']['name'] then common.swap_spell(spells['aeterror']['name'], 7) end
            if mq.TLO.Me.Gem(8)() ~= spells['dottap']['name'] then common.swap_spell(spells['dottap']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['challenge']['name'] then common.swap_spell(spells['challenge']['name'], 9) end
            if mq.TLO.Me.Gem(10)() ~= spells['bitetap']['name'] then common.swap_spell(spells['bitetap']['name'], 10) end
            if mq.TLO.Me.Gem(11)() ~= spells['stance']['name'] then common.swap_spell(spells['stance']['name'], 11) end
            if mq.TLO.Me.Gem(12)() ~= spells['skin']['name'] then common.swap_spell(spells['skin']['name'], 12) end
            if mq.TLO.Me.Gem(13)() ~= spells['acdebuff']['name'] then common.swap_spell(spells['acdebuff']['name'], 13) end
            state.set_spellset_loaded(config.get_spell_set())
        elseif config.get_spell_set() == 'dps' then
            if mq.TLO.Me.Gem(1)() ~= spells['tap1']['name'] then common.swap_spell(spells['tap1']['name'], 1) end
            if mq.TLO.Me.Gem(2)() ~= spells['tap2']['name'] then common.swap_spell(spells['tap2']['name'], 2) end
            if mq.TLO.Me.Gem(3)() ~= spells['largetap']['name'] then common.swap_spell(spells['largetap']['name'], 3) end
            if not mq.TLO.Me.Gem(4)() or (mq.TLO.Me.Gem(4)() ~= 'Composite Fang' and mq.TLO.Me.Gem(4)() ~= 'Dissident Fang' and mq.TLO.Me.Gem(4)() ~= 'Dichotomic Fang') then common.swap_spell(spells['composite']['name'], 4) end
            if mq.TLO.Me.Gem(5)() ~= spells['spear']['name'] then common.swap_spell(spells['spear']['name'], 5) end
            if mq.TLO.Me.Gem(6)() ~= spells['corruption']['name'] then common.swap_spell(spells['corruption']['name'], 6) end
            if mq.TLO.Me.Gem(7)() ~= spells['poison']['name'] then common.swap_spell(spells['poison']['name'], 7) end
            if mq.TLO.Me.Gem(8)() ~= spells['dottap']['name'] then common.swap_spell(spells['dottap']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['disease']['name'] then common.swap_spell(spells['disease']['name'], 9) end
            if mq.TLO.Me.Gem(10)() ~= spells['bitetap']['name'] then common.swap_spell(spells['bitetap']['name'], 10) end
            if mq.TLO.Me.Gem(11)() ~= spells['stance']['name'] then common.swap_spell(spells['stance']['name'], 11) end
            if mq.TLO.Me.Gem(12)() ~= spells['skin']['name'] then common.swap_spell(spells['skin']['name'], 12) end
            if mq.TLO.Me.Gem(13)() ~= spells['acdebuff']['name'] then common.swap_spell(spells['acdebuff']['name'], 13) end
            state.set_spellset_loaded(config.get_spell_set())
        end
        check_spell_timer:reset()
    end
end

shd.pull_func = function()
    if mq.TLO.Me.Moving() or mq.TLO.Navigation.Active() then
        mq.cmd('/squelch /nav stop')
        mq.delay(300)
    end
    common.cast(spells['challenge']['name'], true, true)
end

shd.setup_events = function()
    -- no-op
end

shd.process_cmd = function(opt, new_value)
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

shd.main_loop = function()
    if not mq.TLO.Target() and not mq.TLO.Me.Combat() then
        state.set_tank_mob_id(0)
    end
    check_spell_set()
    if config.get_mode():is_tank_mode() then
        -- get mobs in camp
        camp.mob_radar()
        -- pick mob to tank if not tanking
        tank.find_mob_to_tank()
        tank.tank_mob()
    end
    -- check whether we need to return to camp
    camp.check_camp()
    -- check whether we need to go chasing after the chase target
    common.check_chase()
    -- ae aggro if multiples in camp -- do after return to camp to try to be in range when using
    oh_shit()
    if config.get_mode():is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
        check_ae()
    end
    -- if in an assist mode
    if config.get_mode():is_assist_mode() then
        assist.check_target(shd.reset_class_timers)
        assist.attack()
    end
    -- if in a pull mode and no mobs
    if config.get_mode():is_pull_mode() and state.get_assist_mob_id() == 0 and state.get_tank_mob_id() == 0 and state.get_pull_mob_id() == 0 and mq.TLO.Me.XTarget() == 0 then
        mq.cmd('/multiline ; /squelch /nav stop; /attack off; /autofire off;')
        mq.delay(50)
        pull.pull_radar()
        pull.pull_mob(shd.pull_func)
    end
    -- begin actual combat stuff
    assist.send_pet()
    cycle_spells()
    mash()
    -- pop a bunch of burn stuff if burn conditions are met
    try_burn()
    common.check_mana()
    check_buffs()
    check_pet()
    common.rest()
    mq.delay(1)
end

shd.draw_skills_tab = function()
    config.set_spell_set(ui.draw_combo_box('Spell Set', config.get_spell_set(), SPELLSETS, true))
    OPTS.SUMMONPET = ui.draw_check_box('Summon Pet', '##summonpet', OPTS.SUMMONPET, '')
    OPTS.BUFFPET = ui.draw_check_box('Buff Pet', '##buffpet', OPTS.BUFFPET, '')
    OPTS.USEHATESATTRACTION = ui.draw_check_box('Use Hate\'s Attraction', '##usehatesattr', OPTS.USEHATESATTRACTION, '')
    OPTS.USEPROJECTION = ui.draw_check_box('Use Projection', '##useprojection', OPTS.USEPROJECTION, '')
    OPTS.USEBEZA = ui.draw_check_box('Use Unity Beza', '##usebeza', OPTS.USEBEZA, '')
    OPTS.USEDISRUPTION = ui.draw_check_box('Use Disruption', '##usedisruption', OPTS.USEDISRUPTION, '')
    OPTS.USEINSIDIOUS = ui.draw_check_box('Use Insidious', '##useinsidious', OPTS.USEINSIDIOUS, '')
    OPTS.USELIFETAP = ui.draw_check_box('Use Lifetap', '##uselifetap', OPTS.USELIFETAP, '')
    OPTS.USEVOICEOFTHULE = ui.draw_check_box('Use Voice of Thule', '##usevoice', OPTS.USEVOICEOFTHULE, '')
    OPTS.USETORRENT = ui.draw_check_box('Use Torrent', '##usetorrent', OPTS.USETORRENT, '')
    OPTS.USESWARM = ui.draw_check_box('Use Snare', '##useswarm', OPTS.USESWARM, '')
    OPTS.USEDEFLECTION = ui.draw_check_box('Use Deflection', '##usedeflect', OPTS.USEDEFLECTION, '')
end

shd.draw_burn_tab = function()
    config.set_burn_always(ui.draw_check_box('Burn Always', '##burnalways', config.get_burn_always(), 'Always be burning'))
    config.set_burn_all_named(ui.draw_check_box('Burn Named', '##burnnamed', config.get_burn_all_named(), 'Burn all named'))
    config.set_burn_count(ui.draw_input_int('Burn Count', '##burncnt', config.get_burn_count(), 'Trigger burns if this many mobs are on aggro'))
    config.set_burn_percent(ui.draw_input_int('Burn Percent', '##burnpct', config.get_burn_percent(), 'Percent health to begin burns'))
end

return shd