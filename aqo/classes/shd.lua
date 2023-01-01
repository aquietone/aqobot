--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local assist = require('routines.assist')
local timer = require('utils.timer')
local common = require('common')
local config = require('configuration')
local state = require('state')

mq.cmd('/squelch /stick mod -2')
mq.cmd('/squelch /stick set delaystrafe on')

class.class = 'shd'
class.classOrder = {'assist', 'cast', 'ae', 'mash', 'burn', 'recover', 'rest', 'buff', 'managepet'}

class.SPELLSETS = {standard=1,dps=1}

-- theft of agony
-- decrepit skin
class.addCommonOptions()
class.addCommonAbilities()
class.addOption('USEHATESATTRACTION', 'Use Hate\'s Attraction', true, nil, '', 'checkbox')
class.addOption('USEPROJECTION', 'Use Projection', true, nil, '', 'checkbox')
class.addOption('USEAZIA', 'Use Unity Azia', true, nil, '', 'checkbox', 'USEBEZA')
class.addOption('USEBEZA', 'Use Unity Beza', false, nil, '', 'checkbox', 'USEAZIA')
class.addOption('USEDISRUPTION', 'Use Disruption', true, nil, '', 'checkbox')
class.addOption('USEINSIDIOUS', 'Use Insidious', false, nil, '', 'checkbox')
class.addOption('USELIFETAP', 'Use Lifetap', true, nil, '', 'checkbox')
class.addOption('USEVOICEOFTHULE', 'Use Voice of Thule', false, nil, '', 'checkbox')
class.addOption('USETORRENT', 'Use Torrent', true, nil, '', 'checkbox')
class.addOption('USESWARM', 'Use Snare', true, nil, '', 'checkbox')
class.addOption('USEDEFLECTION', 'Use Deflection', false, nil, '', 'checkbox')
class.addOption('DONTCAST', 'Don\'t Cast', false, nil, 'Don\'t cast spells in combat', 'checkbox')
class.addOption('USEEPIC', 'Use Epic', true, nil, 'Use epic in burns', 'checkbox')

class.addSpell('composite', {'Composite Fang'}) -- big lifetap
class.addSpell('alliance', {'Bloodletting Coalition'}) -- alliance
-- Aggro
class.addSpell('challenge', {'Parlay for Power', 'Aura of Hate'}) -- main hate spell
class.addSpell('terror', {'Terror of Ander', 'Terror of Thule', 'Terror of Terris',  'Terror of Death', 'Terror of Darkness'}) -- ST increase hate by 1
class.addSpell('aeterror', {'Antipathy', 'Dread Gaze'}, {threshold=2}) -- ST increase hate by 1
--['']={'Usurper\'s Audacity'}), -- increase hate by a lot, does this get used?
-- Lifetaps
class.addSpell('largetap', {'Dire Censure'}) -- large lifetap
class.addSpell('tap1', {'Touch of Txiki', 'Touch of Draygun', 'Touch of Innoruuk'})--, 'Drain Soul', 'Lifedraw'}) -- lifetap
class.addSpell('tap2', {'Touch of Namdrows', 'Touch of the Devourer', 'Touch of Volatis'}) -- lifetap + temp hp buff Gift of Namdrows
class.addSpell('dottap', {'Bond of Bynn', 'Bond of Inruku'}) -- lifetap dot
class.addSpell('bitetap', {'Cruor\'s Bite', 'Zevfeer\'s Bite', 'Ancient: Bite of Muram'}) -- lifetap with hp/mana recourse
-- AE lifetap + aggro
class.addSpell('aetap', {'Insidious Renunciation'}) -- large hate + lifetap
-- DPS
class.addSpell('spear', {'Spear of Bloodwretch', 'Spear or Muram', 'Miasmic Spear', 'Spear of Disease'}) -- poison nuke
class.addSpell('poison', {'Blood of Tearc', 'Blood of Inruku', 'Blood of Pain'}) -- poison dot
class.addSpell('disease', {'Plague of Fleshrot'}) -- disease dot
class.addSpell('corruption', {'Unscrupulous Blight'}) -- corruption dot
class.addSpell('acdis', {'Dire Seizure'}) -- disease + ac dot
class.addSpell('acdebuff', {'Torrent of Melancholy', 'Theft of Agony'}) -- ac debuff
--['']={'Despicable Bargain'}), -- nuke, does this get used?
-- Short Term Buffs
class.addSpell('stance', {'Adamant Stance', 'Vampiric Embrace'}) -- temp HP buff, 2.5min
class.addSpell('skin', {'Xenacious\' Skin', 'Decrepit Skin'}) -- Xenacious' Skin proc, 5min buff
class.addSpell('disruption', {'Confluent Disruption', 'Scream of Death'}) -- lifetap proc on heal
--['']={'Impertinent Influence'}), -- ac buff, 20% dmg mitigation, lifetap proc, is this upgraded by xetheg's carapace? stacks?
-- Pet
class.addSpell('pet', {'Minion of Itzal', 'Son of Decay', 'Invoke Death', 'Cackling Bones', 'Animate Dead'}) -- pet
class.addSpell('pethaste', {'Gift of Itzal', 'Rune of Decay', 'Augmentation of Death', 'Augment Death'}) -- pet haste
-- Unity Buffs
class.addSpell('shroud', {'Shroud of Zelinstein', 'Shroud of Discord', 'Black Shroud'}) -- Shroud of Zelinstein Strike proc
class.addSpell('bezaproc', {'Mental Anguish', 'Mental Horror'}, {opt='USEBEZA'}) -- Mental Anguish Strike proc
class.addSpell('aziaproc', {'Brightfield\'s Horror'}, {opt='USEAZIA'}) -- Brightfield's Horror Strike proc
class.addSpell('ds', {'Tekuel Skin'}) -- large damage shield self buff
class.addSpell('lich', {'Aten Ha Ra\'s Covenant'}) -- lich mana regen
class.addSpell('drape', {'Drape of the Akheva', 'Cloak of Discord', 'Cloak of Luclin'}) -- self buff hp, ac, ds
class.addSpell('atkbuff', {'Penumbral Call'}) -- atk buff, hp drain on self
--['']=common.get_best_spell({'Remorseless Demeanor'})

local standard = {}
table.insert(standard, class.spells.tap1)
table.insert(standard, class.spells.tap2)
table.insert(standard, class.spells.largetap)
table.insert(standard, class.spells.composite)
table.insert(standard, class.spells.spear)
table.insert(standard, class.spells.terror)
table.insert(standard, class.spells.aeterror)
table.insert(standard, class.spells.dottap)
table.insert(standard, class.spells.challenge)
table.insert(standard, class.spells.bitetap)
table.insert(standard, class.spells.stance)
table.insert(standard, class.spells.skin)
table.insert(standard, class.spells.acdebuff)

local dps = {}
table.insert(dps, class.spells.tap1)
table.insert(dps, class.spells.tap2)
table.insert(dps, class.spells.largetap)
table.insert(dps, class.spells.composite)
table.insert(dps, class.spells.spear)
table.insert(dps, class.spells.corruption)
table.insert(dps, class.spells.poison)
table.insert(dps, class.spells.dottap)
table.insert(dps, class.spells.disease)
table.insert(dps, class.spells.bitetap)
table.insert(dps, class.spells.stance)
table.insert(dps, class.spells.skin)
table.insert(dps, class.spells.acdebuff)

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

table.insert(class.tankAbilities, common.getSkill('Taunt', {aggro=true}))
table.insert(class.tankAbilities, class.spells.challenge)
table.insert(class.tankAbilities, class.spells.terror)
table.insert(class.tankAbilities, common.getBestDisc({'Repudiate'})) -- mash, 90% melee/spell dmg mitigation, 2 ticks or 85k dmg
table.insert(class.tankAbilities, common.getAA('Projection of Doom', {opt='USEPROJECTION'})) -- aggro swarm pet

local attraction = common.getAA('Hate\'s Attraction', {opt='USEHATESATTRACTION'}) -- aggro swarm pet

-- mash AE aggro
table.insert(class.AETankAbilities, class.spells.aeterror)
table.insert(class.AETankAbilities, common.getAA('Explosion of Spite', {threshold=2})) -- 45sec CD
table.insert(class.AETankAbilities, common.getAA('Explosion of Hatred', {threshold=4})) -- 45sec CD
--table.insert(mashAEAggroAAs4, common.getAA('Stream of Hatred')) -- large frontal cone ae aggro

table.insert(class.tankBurnAbilities, common.getBestDisc({'Unrelenting Acrimony'})) -- instant aggro
table.insert(class.tankBurnAbilities, common.getAA('Ageless Enmity')) -- big taunt
table.insert(class.tankBurnAbilities, common.getAA('Veil of Darkness')) -- large agro, lifetap, blind, mana/end tap
table.insert(class.tankBurnAbilities, common.getAA('Reaver\'s Bargain')) -- 20min CD, 75% melee dmg absorb

-- DPS
table.insert(class.DPSAbilities, common.getSkill('Bash'))
table.insert(class.DPSAbilities, common.getBestDisc({'Reflexive Resentment'})) -- 3x 2hs attack + heal
table.insert(class.DPSAbilities, common.getAA('Vicious Bite of Chaos')) -- 1min CD, nuke + group heal
table.insert(class.DPSAbilities, common.getAA('Spire of the Reavers')) -- 7m30s CD, dmg,crit,parry,avoidance buff

table.insert(class.burnAbilities, common.getBestDisc({'Grisly Blade'})) -- 2hs attack
table.insert(class.burnAbilities, common.getBestDisc({'Sanguine Blade'})) -- 3 strikes
table.insert(class.burnAbilities, common.getAA('Gift of the Quick Spear')) -- 10min CD, twincast
table.insert(class.burnAbilities, common.getAA('T`Vyl\'s Resolve')) -- 10min CD, dmg buff on 1 target
table.insert(class.burnAbilities, common.getAA('Harm Touch')) -- 20min CD, giant nuke + dot
table.insert(class.burnAbilities, common.getAA('Leech Touch')) -- 9min CD, giant lifetap
table.insert(class.burnAbilities, common.getAA('Thought Leech')) -- 18min CD, nuke + mana/end tap
table.insert(class.burnAbilities, common.getAA('Scourge Skin')) -- 15min CD, large DS
table.insert(class.burnAbilities, common.getAA('Chattering Bones', {opt='USESWARM'})) -- 10min CD, swarm pet
--table.insert(class.burnAbilities, common.getAA('Visage of Death')) -- 12min CD, melee dmg burn
table.insert(class.burnAbilities, common.getAA('Visage of Decay')) -- 12min CD, dot dmg burn

local leechtouch = common.getAA('Leech Touch') -- 9min CD, giant lifetap

-- Buffs
-- dark lord's unity azia X -- shroud of zelinstein, brightfield's horror, drape of the akheva, remorseless demeanor, tekuel skin, aten ha ra's covenant, penumbral call
local buffazia = common.getAA('Dark Lord\'s Unity (Azia)')
-- dark lord's unity beza X -- shroud of zelinstein, mental anguish, drape of the akheva, remorseless demeanor, tekuel skin, aten ha ra's covenant, penumbral call
local buffbeza = common.getAA('Dark Lord\'s Unity (Beza)', {opt='USEBEZA'})
local voice = common.getAA('Voice of Thule', {opt='USEVOICEOFTHULE'}) -- aggro mod buff

-- entries in the items table are MQ item datatypes
table.insert(class.burnAbilities, common.getItem(mq.TLO.InvSlot('Chest').Item.Name()))
table.insert(class.burnAbilities, common.getItem('Rage of Rolfron'))
table.insert(class.burnAbilities, common.getItem('Blood Drinker\'s Coating'))

local epic = common.getItem('Innoruuk\'s Dark Blessing') or common.getItem('Innoruuk\'s Voice')

if state.emu then
    table.insert(class.selfBuffs, class.spells.drape)
    table.insert(class.selfBuffs, class.spells.bezaproc)
    table.insert(class.selfBuffs, class.spells.skin)
    table.insert(class.selfBuffs, class.spells.shroud)
    table.insert(class.selfBuffs, common.getAA('Touch of the Cursed'))
    table.insert(class.selfBuffs, common.getItem('Pauldron of Dark Auspices', {checkfor='Frost Guard'}))
    table.insert(class.selfBuffs, common.getItem('Band of Primordial Energy', {checkfor='Form of Defense'}))
    --table.insert(class.selfBuffs, common.getItem('Veil of the Inferno', {checkfor='Form of Endurance'}))
    class.addSpell('voice', {'Voice of Innoruuk'})
    table.insert(class.selfBuffs, class.spells.voice)
end
table.insert(class.selfBuffs, common.getItem('Chestplate of the Dark Flame'))
table.insert(class.selfBuffs, common.getItem('Violet Conch of the Tempest'))
table.insert(class.petBuffs, class.spells.pethaste)

local function find_next_spell()
    local myhp = state.loop.PctHPs
    -- aggro
    if config.MODE:is_tank_mode() and class.OPTS.SPELLSET.value == 'standard' and myhp > 70 then
        if state.mob_count > 2 then
            local xtar_aggro_count = 0
            for i=1,13 do
                local xtar = mq.TLO.Me.XTarget(i)
                if xtar.ID() ~= mq.TLO.Target.ID() and xtar.TargetType() == 'Auto Hater' and xtar.PctAggro() < 100 then
                    xtar_aggro_count = xtar_aggro_count + 1
                end
            end
            if xtar_aggro_count ~= 0 and common.is_spell_ready(class.spells['aeterror']) then return class.spells['aeterror'] end
        end
        if common.is_spell_ready(class.spells['challenge']) then return class.spells['challenge'] end
        if common.is_spell_ready(class.spells['terror']) then return class.spells['terror'] end
    end
    if common.is_spell_ready(class.spells['bitetap']) then return class.spells['bitetap'] end
    -- taps
    if common.is_spell_ready(class.spells['composite']) then return class.spells['composite'] end
    if myhp < 80 then
        if common.is_spell_ready(class.spells['largetap']) then return class.spells['largetap'] end
    end
    if myhp < 85 then
        if common.is_spell_ready(class.spells['tap1']) then return class.spells['tap1'] end
    end
    if common.is_spell_ready(class.spells['spear']) then return class.spells['spear'] end
    --if not mq.TLO.Me.Buff('Gift of Namdrows')() and common.is_spell_ready(class.spells['tap2']) then return class.spells['tap2'] end
    if common.is_spell_ready(class.spells.tap2) then return class.spells.tap2 end
    if common.is_spell_ready(class.spells['dottap']) then return class.spells['dottap'] end
    if common.is_spell_ready(class.spells['acdebuff']) then return class.spells['acdebuff'] end
    if config.MODE:is_assist_mode() and class.OPTS.SPELLSET.value == 'dps' then
        if common.is_spell_ready(class.spells['poison']) then return class.spells['poison'] end
        if common.is_spell_ready(class.spells['disease']) then return class.spells['disease'] end
        if common.is_spell_ready(class.spells['corruption']) then return class.spells['corruption'] end
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

class.cast = function()
    if common.am_i_dead() then return end
    if class.isEnabled('DONTCAST') then return end
    if not state.loop.Invis then
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

class.mash_class = function()
    local target = mq.TLO.Target
    local mobhp = target.PctHPs()

    if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank.ID() == state.loop.ID then
        -- hate's attraction
        if class.OPTS.USEHATESATTRACTION.value and attraction and mobhp and mobhp > 95 then
            attraction:use()
        end
    end
end

class.burn_class = function()
    if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank.ID() == state.loop.ID then
        if mantle then mantle:use() end
        if carapace then carapace:use() end
        if guardian then guardian:use() end
    end

    if class.isEnabled('USEEPIC') and epic then epic:use() end
end

class.ohshit = function()
    if state.loop.PctHPs < 35 and mq.TLO.Me.CombatState() == 'COMBAT' then
        if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank.ID() == state.loop.ID then
            if flash and mq.TLO.Me.AltAbilityReady(flash.name)() then
                flash:use()
            elseif class.OPTS.USEDEFLECTION.value and deflection then
                deflection:use()
            end
            if leechtouch then leechtouch:use() end
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

--[[class.buff_class = function()
    -- stance, disruption, skin
    if class.spells.stance and not mq.TLO.Me.Buff(class.spells.stance.name)() then
        if class.spells.stance:use() then return end
    end
    if class.spells.skin and not mq.TLO.Me.Buff(class.spells.skin.name)() then
        if class.spells.skin:use() then return end
    end

    if class.OPTS.USEDISRUPTION.value and class.spells.disruption and not mq.TLO.Me.Buff(class.spells.disruption.name)() then
        if common.swap_and_cast(class.spells.disruption, 13) then return end
    end

    if not class.OPTS.USEBEZA.value and buffazia and missing_unity_buffs(buffazia.name) then
        if buffazia:use() then return end
    end
    if class.OPTS.USEBEZA.value and buffbeza and missing_unity_buffs(buffbeza.name) then
        if buffbeza:use() then return end
    end

    if class.OPTS.BUFFPET.value and mq.TLO.Pet.ID() > 0 and class.spells.pethaste then
        if not mq.TLO.Pet.Buff(class.spells.pethaste.name)() and mq.TLO.Spell(class.spells.pethaste.name).StacksPet() and mq.TLO.Spell(class.spells.pethaste.name).Mana() < mq.TLO.Me.CurrentMana() then
            common.swap_and_cast(class.spells.pethaste, 13)
        end
    end
end]]

local composite_names = {['Composite Fang']=true,['Dissident Fang']=true,['Dichotomic Fang']=true}
local check_spell_timer = timer:new(30)
class.check_spell_set = function()
    if not common.clear_to_buff() or mq.TLO.Me.Moving() or common.am_i_dead() or class.OPTS.BYOS.value then return end
    if state.spellset_loaded ~= class.OPTS.SPELLSET.value or check_spell_timer:timer_expired() then
        if class.OPTS.SPELLSET.value == 'standard' then
            common.swap_spell(class.spells.tap1, 1)
            common.swap_spell(class.spells.tap2, 2)
            common.swap_spell(class.spells.largetap, 3)
            common.swap_spell(class.spells.composite, 4, composite_names)
            common.swap_spell(class.spells.spear, 5)
            common.swap_spell(class.spells.terror, 6)
            common.swap_spell(class.spells.aeterror, 7)
            common.swap_spell(class.spells.dottap, 8)
            common.swap_spell(class.spells.challenge, 9)
            common.swap_spell(class.spells.bitetap, 10)
            common.swap_spell(class.spells.stance, 11)
            common.swap_spell(class.spells.skin, 12)
            common.swap_spell(class.spells.acdebuff, 13)
            state.spellset_loaded = class.OPTS.SPELLSET.value
        elseif class.OPTS.SPELLSET.value == 'dps' then
            common.swap_spell(class.spells.tap1, 1)
            common.swap_spell(class.spells.tap2, 2)
            common.swap_spell(class.spells.largetap, 3)
            common.swap_spell(class.spells.composite, 4, composite_names)
            common.swap_spell(class.spells.spear, 5)
            common.swap_spell(class.spells.corruption, 6)
            common.swap_spell(class.spells.poison, 7)
            common.swap_spell(class.spells.dottap, 8)
            common.swap_spell(class.spells.disease, 9)
            common.swap_spell(class.spells.bitetap, 10)
            common.swap_spell(class.spells.stance, 11)
            common.swap_spell(class.spells.skin, 12)
            common.swap_spell(class.spells.acdebuff, 13)
            state.spellset_loaded = class.OPTS.SPELLSET.value
        end
        check_spell_timer:reset()
    end
end

--[[class.pull_func = function()
    if class.spells.challenge then
        if mq.TLO.Me.Moving() or mq.TLO.Navigation.Active() then
            mq.cmd('/squelch /nav stop')
            mq.delay(300)
        end
        for _=1,3 do
            if mq.TLO.Me.SpellReady(class.spells.terror.name)() then
                mq.cmdf('/cast %s', class.spells.terror.name)
                break
            end
            mq.delay(100)
        end
    end
end]]

return class