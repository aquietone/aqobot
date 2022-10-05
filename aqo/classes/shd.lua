--- @type Mq
local mq = require 'mq'
local baseclass = require(AQO..'.classes.base')
local assist = require(AQO..'.routines.assist')
local timer = require(AQO..'.utils.timer')
local common = require(AQO..'.common')
local config = require(AQO..'.configuration')
local state = require(AQO..'.state')

mq.cmd('/squelch /stick mod -2')
mq.cmd('/squelch /stick set delaystrafe on')

local shd = baseclass

shd.class = 'shd'
shd.classOrder = {'assist', 'cast', 'mash', 'burn', 'aggro', 'recover', 'rest', 'buff', 'managepet'}

shd.SPELLSETS = {standard=1,dps=1}

shd.addOption('SPELLSET', 'Spell Set', 'standard', shd.SPELLSETS, nil, 'combobox')
shd.addOption('SUMMONPET', 'Summon Pet', true, nil, '', 'checkbox')
shd.addOption('BUFFPET', 'Buff Pet', true, nil, '', 'checkbox')
shd.addOption('USEHATESATTRACTION', 'Use Hate\'s Attraction', true, nil, '', 'checkbox')
shd.addOption('USEPROJECTION', 'Use Projection', true, nil, '', 'checkbox')
shd.addOption('USEBEZA', 'Use Unity Beza', false, nil, '', 'checkbox')
shd.addOption('USEDISRUPTION', 'Use Disruption', true, nil, '', 'checkbox')
shd.addOption('USEINSIDIOUS', 'Use Insidious', false, nil, '', 'checkbox')
shd.addOption('USELIFETAP', 'Use Lifetap', true, nil, '', 'checkbox')
shd.addOption('USEVOICEOFTHULE', 'Use Voice of Thule', false, nil, '', 'checkbox')
shd.addOption('USETORRENT', 'Use Torrent', true, nil, '', 'checkbox')
shd.addOption('USESWARM', 'Use Snare', true, nil, '', 'checkbox')
shd.addOption('USEDEFLECTION', 'Use Deflection', false, nil, '', 'checkbox')
shd.addOption('BYOS', 'BYOS', false, nil, 'Bring your own spells', 'checkbox')

shd.addSpell('composite', {'Composite Fang'}) -- big lifetap
shd.addSpell('alliance', {'Bloodletting Coalition'}) -- alliance
-- Aggro
shd.addSpell('challenge', {'Parlay for Power', 'Shroud of Hate'}) -- main hate spell
shd.addSpell('terror', {'Terror of Ander', 'Terror of Darkness'}) -- ST increase hate by 1
shd.addSpell('aeterror', {'Antipathy'}, {threshold=2}) -- ST increase hate by 1
--['']={'Usurper\'s Audacity'}), -- increase hate by a lot, does this get used?
-- Lifetaps
shd.addSpell('largetap', {'Dire Censure'}) -- large lifetap
shd.addSpell('tap1', {'Touch of Txiki'})--, 'Lifedraw'}) -- lifetap
shd.addSpell('tap2', {'Touch of Namdrows'}) -- lifetap + temp hp buff Gift of Namdrows
shd.addSpell('dottap', {'Bond of Bynn'}) -- lifetap dot
shd.addSpell('bitetap', {'Cruor\'s Bite'}) -- lifetap with hp/mana recourse
-- AE lifetap + aggro
shd.addSpell('aetap', {'Insidious Renunciation'}) -- large hate + lifetap
-- DPS
shd.addSpell('spear', {'Spear of Bloodwretch', 'Spear of Disease'}) -- poison nuke
shd.addSpell('poison', {'Blood of Tearc', 'Blood of Pain'}) -- poison dot
shd.addSpell('disease', {'Plague of Fleshrot'}) -- disease dot
shd.addSpell('corruption', {'Unscrupulous Blight'}) -- corruption dot
shd.addSpell('acdis', {'Dire Seizure'}) -- disease + ac dot
shd.addSpell('acdebuff', {'Torrent of Melancholy'}) -- ac debuff
--['']={'Despicable Bargain'}), -- nuke, does this get used?
-- Short Term Buffs
shd.addSpell('stance', {'Adamant Stance', 'Vampiric Embrace'}) -- temp HP buff, 2.5min
shd.addSpell('skin', {'Xenacious\' Skin'}) -- Xenacious' Skin proc, 5min buff
shd.addSpell('disruption', {'Confluent Disruption', 'Scream of Death'}) -- lifetap proc on heal
--['']={'Impertinent Influence'}), -- ac buff, 20% dmg mitigation, lifetap proc, is this upgraded by xetheg's carapace? stacks?
-- Pet
shd.addSpell('pet', {'Minion of Itzal', 'Animate Dead'}) -- pet
shd.addSpell('pethaste', {'Gift of Itzal'}) -- pet haste
-- Unity Buffs
shd.addSpell('shroud', {'Shroud of Zelinstein'}) -- Shroud of Zelinstein Strike proc
shd.addSpell('bezaproc', {'Mental Anguish'}) -- Mental Anguish Strike proc
shd.addSpell('aziaproc', {'Brightfield\'s Horror'}) -- Brightfield's Horror Strike proc
shd.addSpell('ds', {'Tekuel Skin'}) -- large damage shield self buff
shd.addSpell('lich', {'Aten Ha Ra\'s Covenant'}) -- lich mana regen
shd.addSpell('drape', {'Drape of the Akheva'}) -- self buff hp, ac, ds
shd.addSpell('atkbuff', {'Penumbral Call'}) -- atk buff, hp drain on self
--['']=common.get_best_spell({'Remorseless Demeanor'})

local standard = {}
table.insert(standard, shd.spells.tap1)
table.insert(standard, shd.spells.tap2)
table.insert(standard, shd.spells.largetap)
table.insert(standard, shd.spells.composite)
table.insert(standard, shd.spells.spear)
table.insert(standard, shd.spells.terror)
table.insert(standard, shd.spells.aeterror)
table.insert(standard, shd.spells.dottap)
table.insert(standard, shd.spells.challenge)
table.insert(standard, shd.spells.bitetap)
table.insert(standard, shd.spells.stance)
table.insert(standard, shd.spells.skin)
table.insert(standard, shd.spells.acdebuff)

local dps = {}
table.insert(dps, shd.spells.tap1)
table.insert(dps, shd.spells.tap2)
table.insert(dps, shd.spells.largetap)
table.insert(dps, shd.spells.composite)
table.insert(dps, shd.spells.spear)
table.insert(dps, shd.spells.corruption)
table.insert(dps, shd.spells.poison)
table.insert(dps, shd.spells.dottap)
table.insert(dps, shd.spells.disease)
table.insert(dps, shd.spells.bitetap)
table.insert(dps, shd.spells.stance)
table.insert(dps, shd.spells.skin)
table.insert(dps, shd.spells.acdebuff)

local spellsets = {
    standard=standard,
    dps=dps,
}

-- TANK
-- defensives
local flash = common.getAA('Shield Flash') -- 4min CD, short deflection
local mantle = common.getBestDisc({'Fyrthek Mantle'}) -- 15min CD, 35% melee dmg mitigation, heal on fade
local carapace = common.getBestDisc({'Xetheg\'s Carapace'}) -- 7m30s CD, ac buff, 20% dmg mitigation, lifetap proc
local guardian = common.getBestDisc({'Corrupted Guardian Discipline'}) -- 12min CD, 36% mitigation, large damage debuff to self, lifetap proc
local deflection = common.getBestDisc({'Deflection Discipline'}, {opt='USEDEFLECTION'})

table.insert(shd.tankAbilities, common.getSkill('Taunt'))
table.insert(shd.tankAbilities, shd.spells.challenge)
table.insert(shd.tankAbilities, shd.spells.terror)
table.insert(shd.tankAbilities, common.getBestDisc({'Repudiate'})) -- mash, 90% melee/spell dmg mitigation, 2 ticks or 85k dmg
table.insert(shd.tankAbilities, common.getAA('Projection of Doom', {opt='USEPROJECTION'})) -- aggro swarm pet

local attraction = common.getAA('Hate\'s Attraction', {opt='USEHATESATTRACTION'}) -- aggro swarm pet

-- mash AE aggro
table.insert(shd.AETankAbilities, shd.spells.aeterror)
table.insert(shd.AETankAbilities, common.getAA('Explosion of Spite', {threshold=2})) -- 45sec CD
table.insert(shd.AETankAbilities, common.getAA('Explosion of Hatred', {threshold=4})) -- 45sec CD
--table.insert(mashAEAggroAAs4, common.getAA('Stream of Hatred')) -- large frontal cone ae aggro

table.insert(shd.tankBurnAbilities, common.getBestDisc({'Unrelenting Acrimony'})) -- instant aggro
table.insert(shd.tankBurnAbilities, common.getAA('Ageless Enmity')) -- big taunt
table.insert(shd.tankBurnAbilities, common.getAA('Veil of Darkness')) -- large agro, lifetap, blind, mana/end tap
table.insert(shd.tankBurnAbilities, common.getAA('Reaver\'s Bargain')) -- 20min CD, 75% melee dmg absorb

-- DPS
table.insert(shd.DPSAbilities, common.getSkill('Bash'))
table.insert(shd.DPSAbilities, common.getBestDisc({'Reflexive Resentment'})) -- 3x 2hs attack + heal
table.insert(shd.DPSAbilities, common.getAA('Vicious Bite of Chaos')) -- 1min CD, nuke + group heal
table.insert(shd.DPSAbilities, common.getAA('Spire of the Reavers')) -- 7m30s CD, dmg,crit,parry,avoidance buff

table.insert(shd.burnAbilities, common.getBestDisc({'Grisly Blade'})) -- 2hs attack
table.insert(shd.burnAbilities, common.getBestDisc({'Sanguine Blade'})) -- 3 strikes
table.insert(shd.burnAbilities, common.getAA('Gift of the Quick Spear')) -- 10min CD, twincast
table.insert(shd.burnAbilities, common.getAA('T`Vyl\'s Resolve')) -- 10min CD, dmg buff on 1 target
table.insert(shd.burnAbilities, common.getAA('Harm Touch')) -- 20min CD, giant nuke + dot
table.insert(shd.burnAbilities, common.getAA('Leech Touch')) -- 9min CD, giant lifetap
table.insert(shd.burnAbilities, common.getAA('Thought Leech')) -- 18min CD, nuke + mana/end tap
table.insert(shd.burnAbilities, common.getAA('Scourge Skin')) -- 15min CD, large DS
table.insert(shd.burnAbilities, common.getAA('Chattering Bones', {opt='USESWARM'})) -- 10min CD, swarm pet
table.insert(shd.burnAbilities, common.getAA('Visage of Death')) -- 12min CD, melee dmg burn
table.insert(shd.burnAbilities, common.getAA('Visage of Decay')) -- 12min CD, dot dmg burn

local leechtouch = common.getAA('Leech Touch') -- 9min CD, giant lifetap

-- Buffs
-- dark lord's unity azia X -- shroud of zelinstein, brightfield's horror, drape of the akheva, remorseless demeanor, tekuel skin, aten ha ra's covenant, penumbral call
local buffazia = common.getAA('Dark Lord\'s Unity (Azia)')
-- dark lord's unity beza X -- shroud of zelinstein, mental anguish, drape of the akheva, remorseless demeanor, tekuel skin, aten ha ra's covenant, penumbral call
local buffbeza = common.getAA('Dark Lord\'s Unity (Beza)', {opt='USEBEZA'})
local voice = common.getAA('Voice of Thule', {opt='USEVOICEOFTHULE'}) -- aggro mod buff

-- entries in the items table are MQ item datatypes
table.insert(shd.burnAbilities, common.getItem(mq.TLO.InvSlot('Chest').Item.Name()))
table.insert(shd.burnAbilities, common.getItem('Rage of Rolfron'))
table.insert(shd.burnAbilities, common.getItem('Blood Drinker\'s Coating'))

local epic = common.getItem('Innoruuk\'s Dark Blessing')

table.insert(shd.buffs, common.getItem('Chestplate of the Dark Flame'))
table.insert(shd.buffs, common.getItem('Violet Conch of the Tempest'))

local function find_next_spell()
    local myhp = mq.TLO.Me.PctHPs()
    -- aggro
    if config.MODE:is_tank_mode() and shd.OPTS.SPELLSET == 'standard' and myhp > 70 then
        if state.mob_count > 2 then
            local xtar_aggro_count = 0
            for i=1,13 do
                local xtar = mq.TLO.Me.XTarget(i)
                if xtar.ID() ~= mq.TLO.Target.ID() and xtar.TargetType() == 'Auto Hater' and xtar.PctAggro() < 100 then
                    xtar_aggro_count = xtar_aggro_count + 1
                end
            end
            if xtar_aggro_count ~= 0 and common.is_spell_ready(shd.spells['aeterror']) then return shd.spells['aeterror'] end
        end
        if common.is_dot_ready(shd.spells['challenge']) then return shd.spells['challenge'] end
        if common.is_spell_ready(shd.spells['terror']) then return shd.spells['terror'] end
    end
    -- taps
    if common.is_spell_ready(shd.spells['composite']) then return shd.spells['composite'] end
    if myhp < 80 then
        if common.is_spell_ready(shd.spells['largetap']) then return shd.spells['largetap'] end
    end
    if myhp < 85 then
        if common.is_spell_ready(shd.spells['tap1']) then return shd.spells['tap1'] end
    end
    if not mq.TLO.Me.Buff('Gift of Namdrows')() and common.is_spell_ready(shd.spells['tap2']) then return shd.spells['tap2'] end
    if common.is_dot_ready(shd.spells['dottap']) then return shd.spells['dottap'] end
    if common.is_spell_ready(shd.spells['bitetap']) then return shd.spells['bitetap'] end
    if common.is_dot_ready(shd.spells['acdebuff']) then return shd.spells['acdebuff'] end
    -- dps
    if common.is_spell_ready(shd.spells['spear']) then return shd.spells['spear'] end
    if config.MODE:is_assist_mode() and shd.OPTS.SPELLSET == 'dps' then
        if common.is_dot_ready(shd.spells['poison']) then return shd.spells['poison'] end
        if common.is_dot_ready(shd.spells['disease']) then return shd.spells['disease'] end
        if common.is_dot_ready(shd.spells['corruption']) then return shd.spells['corruption'] end
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

shd.cast = function()
    if common.am_i_dead() then return end
    if not mq.TLO.Me.Invis() then
        if assist.is_fighting() then
            local spell = find_next_spell()
            if spell then
                if mq.TLO.Spell(spell.name).TargetType() == 'Single' then
                    spell:use()
                else
                    spell:use()
                end
                return true
            end
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
    for i=1,20 do
        local xtar = mq.TLO.Me.XTarget(i)
        if xtar.ID() ~= mq.TLO.Target.ID() and xtar.TargetType() == 'Auto Hater' and xtar.PctAggro() < 100 then
            xtar_aggro_count = xtar_aggro_count + 1
        end
    end
    -- if 1 or more mobs on xtarget < 100 aggro then no ae needed
    if xtar_aggro_count == 0 then return end
    -- now see how many xtarhater spawns are actually in range of ae
    local mobs_in_range = mq.TLO.SpawnCount(aggro_nopet_count)()
    if mobs_in_range >= 3 then
        epic:use()
        carapace:use()
    end
    if mobs_in_range >= 2 then
        -- Discs to use when 2 or more mobs on aggro
        for _,aa in ipairs(mashAEAggroAAs2) do
            if not aa.opt or OPTS[aa.opt] then
                if aa:use() then return end
            end
        end
        if mobs_in_range >= 3 then
            -- Discs to use when 4 or more mobs on aggro
            for _,aa in ipairs(mashAEAggroAAs4) do
                if not aa.opt or OPTS[aa.opt] then
                    if aa:use() then return end
                end
            end
        end
    end
end

shd.mash_class = function()
    local target = mq.TLO.Target
    local mobhp = target.PctHPs()

    if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
        -- hate's attraction
        if shd.OPTS.USEHATESATTRACTION.value and attraction and mobhp and mobhp > 95 then
            attraction:use()
        end
    end
end

shd.burn_class = function()
    if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
        mantle:use()
        carapace:use()
        guardian:use()
    end

    epic:use()
end

shd.ohshit = function()
    if mq.TLO.Me.PctHPs() < 35 and mq.TLO.Me.CombatState() == 'COMBAT' then
        if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
            if flash and mq.TLO.Me.AltAbilityReady(flash.name)() then
                flash:use()
            elseif shd.OPTS.USEDEFLECTION.value then
                deflection:use()
            end
            leechtouch:use()
        end
    end
end

local function missing_unity_buffs(name)
    local spell = mq.TLO.Spell(name)
    for i=1,spell.NumEffects() do
        local trigger_spell = spell.Trigger(i)
        if not mq.TLO.Me.Buff(trigger_spell.Name())() and mq.TLO.Spell(trigger_spell.Name()).Stacks() then return true end
    end
    return false
end

--[[shd.buff_class = function()
    -- stance, disruption, skin
    if shd.spells.stance and not mq.TLO.Me.Buff(shd.spells.stance.name)() then
        if shd.spells.stance:use() then return end
    end
    if shd.spells.skin and not mq.TLO.Me.Buff(shd.spells.skin.name)() then
        if shd.spells.skin:use() then return end
    end

    if shd.OPTS.USEDISRUPTION.value and shd.spells.disruption and not mq.TLO.Me.Buff(shd.spells.disruption.name)() then
        if common.swap_and_cast(shd.spells.disruption, 13) then return end
    end

    if not shd.OPTS.USEBEZA.value and buffazia and missing_unity_buffs(buffazia.name) then
        if buffazia:use() then return end
    end
    if shd.OPTS.USEBEZA.value and buffbeza and missing_unity_buffs(buffbeza.name) then
        if buffbeza:use() then return end
    end

    if shd.OPTS.BUFFPET.value and mq.TLO.Pet.ID() > 0 and shd.spells.pethaste then
        if not mq.TLO.Pet.Buff(shd.spells.pethaste.name)() and mq.TLO.Spell(shd.spells.pethaste.name).StacksPet() and mq.TLO.Spell(shd.spells.pethaste.name).Mana() < mq.TLO.Me.CurrentMana() then
            common.swap_and_cast(shd.spells.pethaste, 13)
        end
    end
end]]

local composite_names = {['Composite Fang']=true,['Dissident Fang']=true,['Dichotomic Fang']=true}
local check_spell_timer = timer:new(30)
shd.check_spell_set = function()
    if not common.clear_to_buff() or mq.TLO.Me.Moving() or common.am_i_dead() or shd.OPTS.BYOS.value then return end
    if state.spellset_loaded ~= shd.OPTS.SPELLSET.value or check_spell_timer:timer_expired() then
        if shd.OPTS.SPELLSET.value == 'standard' then
            common.swap_spell(shd.spells.tap1, 1)
            common.swap_spell(shd.spells.tap2, 2)
            common.swap_spell(shd.spells.largetap, 3)
            common.swap_spell(shd.spells.composite, 4, composite_names)
            common.swap_spell(shd.spells.spear, 5)
            common.swap_spell(shd.spells.terror, 6)
            common.swap_spell(shd.spells.aeterror, 7)
            common.swap_spell(shd.spells.dottap, 8)
            common.swap_spell(shd.spells.challenge, 9)
            common.swap_spell(shd.spells.bitetap, 10)
            common.swap_spell(shd.spells.stance, 11)
            common.swap_spell(shd.spells.skin, 12)
            common.swap_spell(shd.spells.acdebuff, 13)
            state.spellset_loaded = shd.OPTS.SPELLSET
        elseif shd.OPTS.SPELLSET.value == 'dps' then
            common.swap_spell(shd.spells.tap1, 1)
            common.swap_spell(shd.spells.tap2, 2)
            common.swap_spell(shd.spells.largetap, 3)
            common.swap_spell(shd.spells.composite, 4, composite_names)
            common.swap_spell(shd.spells.spear, 5)
            common.swap_spell(shd.spells.corruption, 6)
            common.swap_spell(shd.spells.poison, 7)
            common.swap_spell(shd.spells.dottap, 8)
            common.swap_spell(shd.spells.disease, 9)
            common.swap_spell(shd.spells.bitetap, 10)
            common.swap_spell(shd.spells.stance, 11)
            common.swap_spell(shd.spells.skin, 12)
            common.swap_spell(shd.spells.acdebuff, 13)
            state.spellset_loaded = shd.OPTS.SPELLSET.value
        end
        check_spell_timer:reset()
    end
end

shd.pull_func = function()
    if shd.spells.challenge then
        if mq.TLO.Me.Moving() or mq.TLO.Navigation.Active() then
            mq.cmd('/squelch /nav stop')
            mq.delay(300)
        end
        for _=1,3 do
            if mq.TLO.Me.SpellReady(shd.spells.terror.name)() then
                mq.cmdf('/cast %s', shd.spells.terror.name)
                break
            end
            mq.delay(100)
        end
    end
end

return shd