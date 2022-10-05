--- @type Mq
local mq = require 'mq'
local baseclass = require(AQO..'.classes.base')
local mez = require(AQO..'.routines.mez')
local timer = require(AQO..'.utils.timer')
local common = require(AQO..'.common')
local state = require(AQO..'.state')

local enc = baseclass

enc.class = 'enc'
enc.classOrder = {'assist', 'mez', 'assist', 'cast', 'mash', 'burn', 'aggro', 'recover', 'buff', 'rest'}

enc.SPELLSETS = {standard=1}
enc.AURAS = {twincast=true, combatinnate=true, spellfocus=true, regen=true, disempower=true,}

enc.addOption('SPELLSET', 'Spell Set', 'standard', enc.SPELLSETS, nil, 'combobox')
enc.addOption('AURA1', 'Aura 1', 'twincast', enc.AURAS, nil, 'combobox')
enc.addOption('AURA2', 'Aura 2', 'combatinnate', enc.AURAS, nil, 'combobox')
enc.addOption('INTERRUPTFORMEZ', 'Interrupt for Mez', false, nil, '', 'checkbox')
enc.addOption('TASHTHENMEZ', 'Tash Then Mez', true, nil, '', 'checkbox')
enc.addOption('USECHAOTIC', 'Use Chaotic', true, nil, '', 'checkbox')
enc.addOption('USEMELEE', 'Use Melee', false, nil, 'Toggle attacking mobs with melee', 'checkbox')
enc.addOption('USECHARM', 'Use Charm', false, nil, '', 'checkbox')
enc.addOption('USEDOT', 'Use DoT', true, nil, '', 'checkbox')
enc.addOption('USEHASTE', 'Buff Haste', true, nil, '', 'checkbox')
enc.addOption('MEZST', 'Use Mez', true, nil, '', 'checkbox')
enc.addOption('MEZAE', 'Use AE Mez', true, nil, '', 'checkbox')
enc.addOption('AEMEZCOUNT', 'AE Mez Count', 3, nil, 'Threshold to use AE Mez ability', 'inputint')
enc.addOption('USEMINDOVERMATTER', 'Use Mind Over Matter', true, nil, '', 'checkbox')
enc.addOption('USENIGHTSTERROR', 'Buff Nights Terror', true, nil, '', 'checkbox')
enc.addOption('USENUKE', 'Use Nuke', true, nil, '', 'checkbox')
enc.addOption('USEPHANTASMAL', 'Use Phantasmal', true, nil, '', 'checkbox')
enc.addOption('USEREPLICATION', 'Buff Mana Proc', true, nil, '', 'checkbox')
enc.addOption('USESHIELDOFFATE', 'Use Shield of Fate', true, nil, '', 'checkbox')
enc.addOption('USESLOW', 'Use Slow', false, nil, '', 'checkbox')
enc.addOption('USESLOWAOE', 'Use Slow AOE', true, nil, '', 'checkbox')
enc.addOption('USESPELLGUARD', 'Use Spell Guard', true, nil, '', 'checkbox')
enc.addOption('USEDEBUFF', 'Use Tash', false, nil, '', 'checkbox')
enc.addOption('USEDEBUFFAOE', 'Use Tash AOE', true, nil, '', 'checkbox')
enc.addOption('SUMMONPET', 'Summon Pet', false, nil, '', 'checkbox')
enc.addOption('BUFFPET', 'Buff Pet', true, nil, '', 'checkbox')
enc.addOption('USEDISPEL', 'Use Dispel', true, nil, 'Dispel mobs with Eradicate Magic AA', 'checkbox')

enc.addSpell('composite', {'Composite Reinforcement', 'Dissident Reinforcement', 'Dichotomic Reinforcement'}) -- restore mana, add dmg proc, inc dmg
enc.addSpell('alliance', {'Chromatic Coalition', 'Chromatic Covenant'})

enc.addSpell('mezst', {'Addle'}) -- 9 ticks
enc.addSpell('mezst2', {'Addling Flash'}) -- 6 ticks
enc.addSpell('mezae', {'Bewildering Wave', 'Neutralizing Wave'}) -- targeted AE mez
enc.addSpell('mezaehate', {'Confounding Glance'}) -- targeted AE mez + 100% hate reduction
enc.addSpell('mezpbae', {'Bewilderment'})
enc.addSpell('mezpbae2', {'Perilous Bewilderment'}) -- lvl 120
enc.addSpell('meznoblur', {'Chaotic Puzzlement', 'Chaotic Deception'})
enc.addSpell('mezaeprocblur', {'Mesmeric Stare'}) -- targeted AE mez
enc.addSpell('mezshield', {'Ward of the Beguiler', 'Ward of the Deviser'}) -- mez proc on being hit

enc.addSpell('rune', {'Marvel\'s Rune'}) -- 160k rune, self
enc.addSpell('rune2', {'Rune of Tearc'}) -- 90k rune, single target
enc.addSpell('dotrune', {'Aegis of Xetheg'}) -- absorb DoT dmg
enc.addSpell('guard', {'Shield of Inevitability', 'Shield of Destiny', 'Shield of Order'}) -- spell + melee guard
enc.addSpell('dotmiti', {'Deviser\'s Auspice', 'Transfixer\'s Auspice'}) -- DoT guard
enc.addSpell('meleemiti', {'Eclipsed Auspice'}) -- melee guard
enc.addSpell('spellmiti', {'Aegis of Sefra'}) -- 20% spell mitigation
enc.addSpell('absorbbuff', {'Brimstone Endurance'}) -- increase absorb dmg

enc.addSpell('aggrorune', {'Ghastly Rune'}) -- single target rune + hate increase

enc.addSpell('groupdotrune', {'Legion of Xetheg', 'Legion of Cekenar'})
enc.addSpell('groupspellrune', {'Legion of Liako', 'Legion of Kildrukaun'})
enc.addSpell('groupaggrorune', {'Eclipsed Rune'}) -- group rune + aggro reduction proc

enc.addSpell('dot', {'Mind Vortex', 'Mind Coil'}) -- big dot
enc.addSpell('dot2', {'Throttling Grip', 'Pulmonary Grip'}) -- decent dot
enc.addSpell('debuffdot', {'Perplexing Constriction'}) -- debuff + nuke + dot
enc.addSpell('manadot', {'Tears of Xenacious'}) -- hp + mana DoT
enc.addSpell('nukerune', {'Chromatic Flare'}) -- 15k nuke + self rune
enc.addSpell('nuke', {'Psychological Appropriation'}) -- 20k
enc.addSpell('nuke2', {'Chromashear'}) -- 23k
enc.addSpell('nuke3', {'Polyluminous Assault'}) -- 27k nuke
enc.addSpell('nuke4', {'Obscuring Eclipse'}) -- 27k nuke
enc.addSpell('aenuke', {'Gravity Roil'}) -- 23k targeted ae nuke

enc.addSpell('calm', {'Still Mind'})
enc.addSpell('tash', {'Edict of Tashan', 'Proclamation of Tashan'})
enc.addSpell('stunst', {'Dizzying Vortex'}) -- single target stun
enc.addSpell('stunae', {'Remote Color Conflagration'})
enc.addSpell('stunpbae', {'Color Conflagration'})
enc.addSpell('stunaerune', {'Polyluminous Rune', 'Polycascading Rune', 'Polyfluorescent Rune'}) -- self rune, proc ae stun on fade

enc.addSpell('pet', {'Constance\'s Animation'})
enc.addSpell('pethaste', {'Invigorated Minion'})
enc.addSpell('charm', {'Marvel\'s Command'})
-- buffs
enc.addSpell('unity', {'Marvel\'s Unity', 'Deviser\'s Unity'}) -- mez proc on being hit
enc.addSpell('procbuff', {'Mana Rebirth'}) -- single target dmg proc buff
enc.addSpell('kei', {'Scrying Visions', 'Sagacity'})
enc.addSpell('keigroup', {'Voice of Perception', 'Voice of Sagacity'})
enc.addSpell('haste', {'Speed of Itzal', 'Speed of Cekenar'}) -- single target buff
enc.addSpell('grouphaste', {'Hastening of Jharin', 'Hastening of Cekenar'}) -- group haste
enc.addSpell('nightsterror', {'Night\'s Perpetual Terror', 'Night\'s Endless Terror'}) -- melee attack proc
-- auras - mana, learners, spellfocus, combatinnate, disempower, rune, twincast
enc.addSpell('twincast', {'Twincast Aura'})
enc.addSpell('regen', {'Marvel\'s Aura', 'Deviser\'s Aura'}) -- mana + end regen aura
enc.addSpell('spellfocus', {'Enhancing Aura', 'Fortifying Aura'}) -- increase dmg of DDs
enc.addSpell('combatinnate', {'Mana Radix Aura', 'Mana Replication Aura'}) -- dmg proc on spells, Issuance of Mana Radix == place aura at location
enc.addSpell('disempower', {'Arcane Disjunction Aura'})
-- unity buffs
enc.addSpell('shield', {'Shield of Shadow', 'Shield of Restless Ice'})
enc.addSpell('ward', {'Ward of the Beguiler', 'Ward of the Transfixer'})

enc.addSpell('synergy', {'Mindreap', 'Mindrift', 'Mindslash'}) -- 63k nuke
if enc.spells.synergy then
    if enc.spells.synergy.name:find('reap') then
        enc.spells.nuke5 = common.get_best_spell({'Mindrift', 'Mindslash'})
    elseif enc.spells.synergy.name:find('rift') then
        enc.spells.nuke5 = common.get_best_spell({'Mindslash'})
    end
end

-- tash, command, chaotic, deceiving stare, pulmonary grip, mindrift, fortifying aura, mind coil, unity, dissident, mana replication, night's endless terror
-- entries in the dots table are pairs of {spell id, spell name} in priority order
local standard = {}
table.insert(standard, enc.spells.tash)
table.insert(standard, enc.spells.dotmiti)
table.insert(standard, enc.spells.meznoblur)
table.insert(standard, enc.spells.mezae)
table.insert(standard, enc.spells.dot)
table.insert(standard, enc.spells.dot2)
table.insert(standard, enc.spells.synergy)
table.insert(standard, enc.spells.nuke5)
table.insert(standard, enc.spells.composite)
table.insert(standard, enc.spells.stunaerune)
table.insert(standard, enc.spells.guard)
table.insert(standard, enc.spells.nightsterror)
table.insert(standard, enc.spells.combatinnate)

table.insert(enc.burnAbilities, common.getItem(mq.TLO.InvSlot('Chest').Item.Name()))
table.insert(enc.burnAbilities, common.getItem('Rage of Rolfron'))

table.insert(enc.burnAbilities, common.getAA('Silent Casting')) -- song, 12 minute CD
table.insert(enc.burnAbilities, common.getAA('Focus of Arcanum')) -- buff, 10 minute CD
table.insert(enc.burnAbilities, common.getAA('Illusions of Grandeur')) -- 12 minute CD, group spell crit buff
table.insert(enc.burnAbilities, common.getAA('Calculated Insanity')) -- 20 minute CD, increase crit for 27 spells
table.insert(enc.burnAbilities, common.getAA('Spire of Enchantment')) -- buff, 7:30 minute CD
table.insert(enc.burnAbilities, common.getAA('Improved Twincast')) -- 15min CD
table.insert(enc.burnAbilities, common.getAA('Chromatic Haze')) -- 15min CD
table.insert(enc.burnAbilities, common.getAA('Companion\'s Fury')) -- 10 minute CD
table.insert(enc.burnAbilities, common.getAA('Companion\'s Fortification')) -- 15 minute CD

--table.insert(AAs, getAAid_and_name('Glyph of Destruction (115+)'))
--table.insert(AAs, getAAid_and_name('Intensity of the Resolute'))

enc.debuff = common.getAA('Bite of Tashani')
enc.slow = common.getAA('Slowing Helix') -- single target slow
enc.aeslow = common.getAA('Enveloping Helix') -- AE slow on 8 targets
enc.dispel = common.getAA('Eradicate Magic')

local mezbeam = common.getAA('Beam of Slumber')
local longmez = common.getAA('Noctambulate') -- 3min single target mez

local aekbblur = common.getAA('Beguiler\'s Banishment')
local kbblur = common.getAA('Beguiler\'s Directed Banishment')
local aeblur = common.getAA('Blanket of Forgetfulness')

local haze = common.getAA('Chromatic Haze') -- 10min CD, buff 2 nukes for group

local shield = common.getAA('Dimensional Shield')
local rune = common.getAA('Eldritch Rune')
local grouprune = common.getAA('Glyph Spray')
local reactiverune = common.getAA('Reactive Rune') -- group buff, melee/spell shield that procs rune
local manarune = common.getAA('Mind over Matter') -- absorb dmg using mana
local veil = common.getAA('Veil of Mindshadow') -- 5min CD, another rune?

local debuffdot = common.getAA('Mental Corruption') -- decrease melee dmg + DoT

-- Buffs
local unity = common.getAA('Orator\'s Unity')
-- Mana Recovery AAs
local azure = common.getAA('Azure Mind Crystal') -- summon clicky mana heal
local gathermana = common.getAA('Gather Mana')
local sanguine = common.getAA('Sanguine Mind Crystal') -- summon clicky hp heal
-- Agro
local stasis = common.getAA('Self Stasis')

local buffs={
    self={},
    pet={
        enc.spells.pethaste,
    },
}
--[[
    track data about our targets, for one-time or long-term affects.
    for example: we do not need to continually poll when to debuff a mob if the debuff will last 17+ minutes
    if the mob aint dead by then, you should re-roll a wizard.
]]--
local targets = {}

enc.mez = function()
    if enc.OPTS.MEZAE.value then
        mez.do_ae(enc.spells.mezae, enc.OPTS.AEMEZCOUNT.value)
    end
    if enc.OPTS.MEZST.value and not mq.TLO.Me.SpellInCooldown() then
        if not mq.TLO.Target.Tashed() and enc.OPTS.TASHTHENMEZ.value and enc.tash then
            enc.tash:use()
        end
        mez.do_single(enc.spells.mezst)
    end
end

local function cast_synergy()
    if enc.spells.synergy and not mq.TLO.Me.Song('Beguiler\'s Synergy')() and mq.TLO.Me.SpellReady(enc.spells.synergy.name)() then
        if mq.TLO.Spell(enc.spells.synergy.name).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        enc.spells.synergy:use()
        return true
    end
    return false
end

-- composite
-- synergy
-- nuke5
-- dot2
enc.find_next_spell = function()
    if not mq.TLO.Target.Tashed() and enc.OPTS.USEDEBUFF.value and common.is_spell_ready(enc.spells.tash) then return enc.spells.tash end
    if common.is_spell_ready(enc.spells.composite) then return enc.spells.composite end
    if cast_synergy() then return nil end
    if common.is_spell_ready(enc.spells.nuke5) then return enc.spells.nuke5 end
    if common.is_dot_ready(enc.spells.dot2) then return enc.spells.dot2 end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

enc.recover = function()
    -- modrods
    common.check_mana()
    local pct_mana = mq.TLO.Me.PctMana()
    if gathermana and pct_mana < 50 then
        -- death bloom at some %
        gathermana:use()
    end
    if pct_mana < 75 and azure then
        local cursor = mq.TLO.Cursor()
        if cursor and cursor:find(azure.name) then mq.cmd('/autoinventory') end
        local manacrystal = mq.TLO.FindItem(azure.name)
        common.use_item(manacrystal)
    end
end

local check_aggro_timer = timer:new(10)
enc.aggro = function()
    if mq.TLO.Me.PctHPs() < 40 and sanguine then
        local cursor = mq.TLO.Cursor()
        if cursor and cursor:find(sanguine.name) then mq.cmd('/autoinventory') end
        local hpcrystal = mq.TLO.FindItem('='..sanguine.name)
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
enc.buff = function()
    if common.am_i_dead() or mq.TLO.Me.Moving() then return end
-- now buffs:
-- - enc.spells.guard (shield of inevitability - quick-refresh, strong direct damage spell guard and melee-strike rune combined into one.)
-- - enc.spells.stunaerune (polyluminous rune - quick-refresh, damage absorption rune with a PB AE stun once consumed.)
-- - rune (eldritch rune - AA rune, always pre-buffed.)
-- - veil (Veil of the Mindshadow – AA rune, always pre-buffed.)
    local tempName
    if enc.spells.guard and not mq.TLO.Me.Buff(tempName)() then
        tempName = enc.spells.guard.name
        if state.subscription ~= 'GOLD' then tempName = tempName:gsub(' Rk%..*', '') end
        if enc.spells.guard:use() then return end
    end
    if enc.spells.stunaerune and not mq.TLO.Me.Buff(tempName)() then
        tempName = enc.spells.stunaerune.name
        if state.subscription ~= 'GOLD' then tempName = tempName:gsub(' Rk%..*', '') end
        if enc.spells.stunaerune:use() then return end
    end
    if rune and not mq.TLO.Me.Buff(rune.name)() then
        if rune:use() then return end
    end
    if veil and not mq.TLO.Me.Buff(veil.name)() then
        if veil:use() then return end
    end
    common.check_combat_buffs()
    if not common.clear_to_buff() then return end

    if unity and missing_unity_buffs(unity.name) then
        if unity:use() then return end
    end

    local hpcrystal = sanguine and mq.TLO.FindItem(sanguine.name)
    local manacrystal = azure and mq.TLO.FindItem(azure.name)
    if hpcrystal and not hpcrystal() then
        if sanguine:use() then
            mq.cmd('/autoinv')
            return
        end
    end
    if manacrystal and not manacrystal() then
        if azure:use() then
            mq.cmd('/autoinv')
            return
        end
    end

    if enc.OPTS.AURA1.value == 'twincast' and enc.spells.twincast and not mq.TLO.Me.Aura('Twincast Aura')() then
        if common.swap_and_cast(enc.spells[enc.OPTS.AURA1.value], 13) then return end
    elseif enc.OPTS.AURA1.value ~= 'twincast' and enc.spells[enc.OPTS.AURA1.value] and not mq.TLO.Me.Aura(enc.spells[enc.OPTS.AURA1.value].name)() then
        if common.swap_and_cast(enc.spells[enc.OPTS.AURA1.value], 13) then return end
    end
    if enc.OPTS.AURA2.value == 'twincast' and enc.spells.twincast and not mq.TLO.Me.Aura('Twincast Aura')() then
        if common.swap_and_cast(enc.spells[enc.OPTS.AURA2.value], 13) then return end
    elseif enc.OPTS.AURA2.value ~= 'twincast' and enc.spells[enc.OPTS.AURA2.value] and not mq.TLO.Me.Aura(enc.spells[enc.OPTS.AURA2.value].name)() then
        if common.swap_and_cast(enc.spells[enc.OPTS.AURA2.value], 13) then return end
    end

    -- kei
    -- haste

    common.check_item_buffs()

    if enc.OPTS.BUFFPET.value and mq.TLO.Pet.ID() > 0 then
        --for _,buff in ipairs(buffs.pet) do
        --    if not mq.TLO.Pet.Buff(buff.name)() and mq.TLO.Spell(buff.name).StacksPet() and mq.TLO.Spell(buff.name).Mana() < mq.TLO.Me.CurrentMana() then
        --        common.swap_and_cast(buff.name, 13)
        --    end
        --end
    end
end

local composite_names = {['Composite Reinforcement']=true,['Dissident Reinforcement']=true,['Dichotomic Reinforcement']=true}
local check_spell_timer = timer:new(30)
enc.check_spell_set = function()
    if not common.clear_to_buff() or mq.TLO.Me.Moving() or common.am_i_dead() then return end
    if state.spellset_loaded ~= enc.OPTS.SPELLSET.value or check_spell_timer:timer_expired() then
        if enc.OPTS.SPELLSET.value == 'standard' then
            common.swap_spell(enc.spells.tash, 1)
            common.swap_spell(enc.spells.dotmiti, 2)
            common.swap_spell(enc.spells.meznoblur, 3)
            common.swap_spell(enc.spells.mezae, 4)
            common.swap_spell(enc.spells.dot, 5)
            common.swap_spell(enc.spells.dot2, 6)
            common.swap_spell(enc.spells.synergy, 7)
            common.swap_spell(enc.spells.nuke5, 8)
            common.swap_spell(enc.spells.composite, 9, composite_names)
            common.swap_spell(enc.spells.stunaerune, 10)
            common.swap_spell(enc.spells.guard, 11)
            common.swap_spell(enc.spells.nightsterror, 12)
            common.swap_spell(enc.spells.combatinnate, 13)
            state.spellset_loaded = enc.OPTS.SPELLSET.value
        end
        check_spell_timer:reset()
    end
end

--[[
#Event CAST_IMMUNE                 "Your target has no mana to affect#*#"
#Event CAST_IMMUNE                 "Your target is immune to changes in its run speed#*#"
#Event CAST_IMMUNE                 "Your target is immune to snare spells#*#"
#Event CAST_IMMUNE                 "Your target is immune to the stun portion of this effect#*#"
#Event CAST_IMMUNE                 "Your target looks unaffected#*#"
]]--

return enc