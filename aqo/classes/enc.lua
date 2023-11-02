--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local mez = require('routines.mez')
local timer = require('utils.timer')
local abilities = require('ability')
local common = require('common')
local config = require('interface.configuration')
local state = require('state')

function class.init(_aqo)
    class.classOrder = {'assist', 'mez', 'assist', 'aggro', 'debuff', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest', 'managepet', 'rez'}
    class.spellRotations = {standard={}}
    class.AURAS = {twincast=true, combatinnate=true, spellfocus=true, regen=true, disempower=true,}
    class.initBase(_aqo, 'enc')

    class.initClassOptions()
    class.loadSettings()
    class.initSpellLines(_aqo)
    class.initSpellRotations(_aqo)
    class.initBuffs(_aqo)
    class.initBurns(_aqo)
    class.initDebuffs(_aqo)
    class.initDefensiveAbilities(_aqo)

    class.mezbeam = common.getAA('Beam of Slumber')
    class.longmez = common.getAA('Noctambulate') -- 3min single target mez

    class.aekbblur = common.getAA('Beguiler\'s Banishment')
    class.kbblur = common.getAA('Beguiler\'s Directed Banishment')
    class.aeblur = common.getAA('Blanket of Forgetfulness')
    class.summonCompanion = common.getAA('Summon Companion')
    if class.spells.mezst then
        function class.beforeMez()
            if not mq.TLO.Target.Tashed() and class.isEnabled('TASHTHENMEZ') and class.spells.tash then
                class.spells.tash:use()
            end
            return true
        end
        class.spells.mezst.precast = class.beforeMez
    end
end

function class.initClassOptions()
    class.addOption('AURA1', 'Aura 1', 'twincast', class.AURAS, 'The first aura to keep up', 'combobox', nil, 'Aura1', 'string')
    class.addOption('AURA2', 'Aura 2', 'combatinnate', class.AURAS, 'The second aura to keep up', 'combobox', nil, 'Aura2', 'string')
    class.addOption('INTERRUPTFORMEZ', 'Interrupt for Mez', false, nil, 'Toggle interrupting current spell casts to cast mez', 'checkbox', nil, 'InterruptForMez', 'bool')
    class.addOption('TASHTHENMEZ', 'Tash Then Mez', true, nil, 'Toggle use of tash prior to attempting to mez mobs', 'checkbox', nil, 'TashThenMez', 'bool')
    class.addOption('USECHAOTIC', 'Use Chaotic', true, nil, 'Toggle use of Chaotic mez line', 'checkbox', nil, 'UseChaotic', 'bool')
    class.addOption('USECHARM', 'Use Charm', false, nil, 'Attempt to maintain a charm pet instead of using a regular pet', 'checkbox', nil, 'UseCharm', 'bool')
    class.addOption('USEDOT', 'Use DoT', true, nil, 'Toggle use of DoTs', 'checkbox', nil, 'UseDoT', 'bool')
    class.addOption('USEHASTE', 'Buff Haste', true, nil, 'Toggle use of haste buff line', 'checkbox', nil, 'UseHaste', 'bool')
    class.addOption('MEZST', 'Use Mez', true, nil, 'Use single target mez on adds within camp radius', 'checkbox', nil, 'MezST', 'bool')
    class.addOption('MEZAE', 'Use AE Mez', true, nil, 'Use AE Mez if 3 or more mobs are within camp radius', 'checkbox', nil, 'MezAE', 'bool')
    class.addOption('MEZAECOUNT', 'AE Mez Count', 3, nil, 'Threshold to use AE Mez ability', 'inputint', nil, 'MezAECount', 'bool')
    class.addOption('USEMINDOVERMATTER', 'Use Mind Over Matter', true, nil, 'Toggle use of Mind over Matter', 'checkbox', nil, 'UseMindOverMatter', 'bool')
    class.addOption('USENIGHTSTERROR', 'Buff Nights Terror', true, nil, 'Toggle use of Nights Terror buff line', 'checkbox', nil, 'UseNDT', 'bool')
    class.addOption('USENUKES', 'Use Nuke', true, nil, 'Toggle use of nukes', 'checkbox', nil, 'UseNukes', 'bool')
    class.addOption('USEPHANTASMAL', 'Use Phantasmal', true, nil, 'Toggle use of Phantasmal', 'checkbox', nil, 'UsePhantasmal', 'bool')
    class.addOption('USEREPLICATION', 'Buff Mana Proc', true, nil, 'Toggle use of Replication buff line', 'checkbox', nil, 'UseReplication', 'bool')
    class.addOption('USESHIELDOFFATE', 'Use Shield of Fate', true, nil, 'Toggle use of Shield of Fate', 'checkbox', nil, 'UseShieldOfFate', 'bool')
    class.addOption('USESLOW', 'Use Slow', false, nil, 'Toggle use of single target slow ability', 'checkbox', nil, 'UseSlow', 'bool')
    class.addOption('USESLOWAOE', 'Use Slow AOE', true, nil, 'Toggle use of AOE slow ability', 'checkbox', nil, 'UseSlowAOE', 'bool')
    class.addOption('USESPELLGUARD', 'Use Spell Guard', true, nil, 'Toggle use of Spell Guard', 'checkbox', nil, 'UseSpellGuard', 'bool')
    class.addOption('USEDEBUFF', 'Use Tash', false, nil, 'Toggle use of single target tash ability', 'checkbox', nil, 'UseDebuff', 'bool')
    class.addOption('USEDEBUFFAOE', 'Use Tash AOE', true, nil, 'Toggle use of AOE tash ability', 'checkbox', nil, 'UseDebuffAOE', 'bool')
    class.addOption('USEDISPEL', 'Use Dispel', true, nil, 'Dispel mobs with Eradicate Magic AA', 'checkbox', nil, 'UseDispel', 'bool')
end

function class.initSpellLines(_aqo)
    class.addSpell('composite', {'Composite Reinforcement', 'Dissident Reinforcement', 'Dichotomic Reinforcement'}) -- restore mana, add dmg proc, inc dmg
    class.addSpell('alliance', {'Chromatic Coalition', 'Chromatic Covenant'})

    class.addSpell('mezst', {'Flummox', 'Addle', 'Euphoria'}) -- 9 ticks
    class.addSpell('mezst2', {'Flummoxing Flash', 'Addling Flash'}) -- 6 ticks
    class.addSpell('mezae', {'Stupefying Wave', 'Bewildering Wave', 'Neutralizing Wave', 'Bliss of the Nihil'}) -- targeted AE mez
    class.addSpell('mezaehate', {'Vexing Glance', 'Confounding Glance'}) -- targeted AE mez + 100% hate reduction
    class.addSpell('mezpbae', {'Wonderment', 'Bewilderment'})
    class.addSpell('mezpbae2', {'Perilous Confounding', 'Perilous Bewilderment'}) -- lvl 120
    class.addSpell('meznoblur', {'Chaotic Conundrum', 'Chaotic Puzzlement', 'Chaotic Deception'})
    class.addSpell('mezaeprocblur', {'Entrancing Stare', 'Mesmeric Stare'}) -- targeted AE mez
    class.addSpell('mezshield', {'Ward of the Stupefier', 'Ward of the Beguiler', 'Ward of the Deviser'}) -- mez proc on being hit

    class.addSpell('rune', {'Disquieting Rune', 'Marvel\'s Rune'}) -- 160k rune, self
    class.addSpell('rune2', {'Rune of Zoraxmen', 'Rune of Tearc'}) -- 90k rune, single target
    class.addSpell('dotrune', {'Aegis of Dhakka', 'Aegis of Xetheg'}) -- absorb DoT dmg
    class.addSpell('guard', {'Shield of Inescapability', 'Shield of Inevitability', 'Shield of Destiny', 'Shield of Order'}) -- spell + melee guard
    class.addSpell('dotmiti', {'Deviser\'s Auspice', 'Transfixer\'s Auspice'}) -- DoT guard
    class.addSpell('spellmiti', {'Aegis of Elmara', 'Aegis of Sefra'}) -- 20% spell mitigation

    class.addSpell('meleemiti', {'Gloaming Auspice', 'Eclipsed Auspice'}) -- melee guard, + hate
    class.addSpell('absorbbuff', {'Brimstone Stability', 'Brimstone Endurance'}) -- increase absorb dmg, + hate
    class.addSpell('aggrorune', {'Esoteric Rune', 'Ghastly Rune'}) -- single target rune + hate increase
    -- Polyradiant Rune -- hate mod rune, stun proc on fade

    class.addSpell('groupdotrune', {'Legion of Dhakka', 'Legion of Xetheg', 'Legion of Cekenar'})
    class.addSpell('groupspellrune', {'Legion of Ogna', 'Legion of Liako', 'Legion of Kildrukaun'})
    class.addSpell('groupaggrorune', {'Gloaming Rune', 'Eclipsed Rune'}) -- group rune + aggro reduction proc

    class.addSpell('dot', {'Mind Whirl', 'Mind Vortex', 'Mind Coil', 'Mind Shatter'}, {opt='USEDOT'}) -- big dot
    class.addSpell('dot2', {'Asphyxiating Grasp', 'Throttling Grip', 'Pulmonary Grip', 'Arcane Noose'}, {opt='USEDOT'}) -- decent dot
    class.addSpell('debuffdot', {'Dismaying Constriction', 'Perplexing Constriction'}) -- debuff + nuke + dot
    class.addSpell('manadot', {'Tears of Kasha', 'Tears of Xenacious'}) -- hp + mana DoT
    class.addSpell('nukerune', {'Chromatic Spike', 'Chromatic Flare'}) -- 15k nuke + self rune
    class.addSpell('nuke', {'Cognitive Appropriation', 'Psychological Appropriation'}) -- 20k
    class.addSpell('nuke2', {'Chromaclap', 'Chromashear'}) -- 23k
    class.addSpell('nuke3', {'Polyradiant Assault', 'Polyluminous Assault'}) -- 27k nuke
    class.addSpell('nuke4', {'Obscuring Eclipse'}) -- 27k nuke
    class.addSpell('aenuke', {'Gravity Roil'}) -- 23k targeted ae nuke

    class.addSpell('calm', {'Still Mind'})
    class.addSpell('tash', {'Roar of Tashan', 'Edict of Tashan', 'Proclamation of Tashan', 'Bite of Tashani', 'Echo of Tashan'}, {opt='USEDEBUFF'})
    class.addSpell('stunst', {'Dizzying Spindle', 'Dizzying Vortex'}) -- single target stun
    class.addSpell('stunae', {'Remote Color Calibration', 'Remote Color Conflagration'})
    class.addSpell('stunpbae', {'Color Calibration', 'Color Conflagration'})
    class.addSpell('stunaerune', {'Polyluminous Rune', 'Polycascading Rune', 'Polyfluorescent Rune', 'Ethereal Rune', 'Arcane Rune'}) -- self rune, proc ae stun on fade

    class.addSpell('pet', {'Flariton\'s Animation', 'Constance\'s Animation', 'Aeidorb\'s Animation'})
    class.addSpell('pethaste', {'Invigorated Minion'})
    class.addSpell('charm', {'Esoteric Command', 'Marvel\'s Command'})
    -- buffs
    class.addSpell('unity', {'Esoteric Unity', 'Marvel\'s Unity', 'Deviser\'s Unity'}) -- mez proc on being hit
    class.addSpell('procbuff', {'Mana Reproduction', 'Mana Rebirth', 'Mana Recursion', 'Mana Flare'}) -- single target dmg proc buff
    class.addSpell('kei', {'Preordination', 'Scrying Visions', 'Sagacity', 'Voice of Quellious'})
    class.addSpell('keigroup', {'Voice of Preordination', 'Voice of Perception', 'Voice of Sagacity'})
    class.addSpell('haste', {'Speed of Margator', 'Speed of Itzal', 'Speed of Cekenar'}) -- single target buff
    class.addSpell('grouphaste', {'Hastening of Margator', 'Hastening of Jharin', 'Hastening of Cekenar'}) -- group haste
    class.addSpell('nightsterror', {'Night\'s Perpetual Terror', 'Night\'s Endless Terror'}) -- melee attack proc
    -- auras - mana, learners, spellfocus, combatinnate, disempower, rune, twincast
    class.addSpell('twincast', {'Twincast Aura'})
    class.addSpell('regen', {'Esoteric Aura', 'Marvel\'s Aura', 'Deviser\'s Aura'}) -- mana + end regen aura
    class.addSpell('spellfocus', {'Intensifying Aura', 'Enhancing Aura', 'Fortifying Aura'}) -- increase dmg of DDs
    class.addSpell('combatinnate', {'Mana Ripple Aura', 'Mana Radix Aura', 'Mana Replication Aura'}) -- dmg proc on spells, Issuance of Mana Radix == place aura at location
    class.addSpell('disempower', {'Arcane Disjunction Aura'})
    -- 'Runic Scintillation Aura' -- rune aura
    -- unity buffs
    class.addSpell('shield', {'Shield of Memories', 'Shield of Shadow', 'Shield of Restless Ice'})
    class.addSpell('ward', {'Ward of the Beguiler', 'Ward of the Transfixer'})

    class.addSpell('synergy', {'Mindrend', 'Mindreap', 'Mindrift', 'Mindslash'}) -- 63k nuke
    if class.spells.synergy then
        if class.spells.synergy.Name:find('rend') then
            class.addSpell('nuke5', {'Mindreap', 'Mindrift', 'Mindslash'})
        elseif class.spells.synergy.Name:find('reap') then
            class.addSpell('nuke5', {'Mindrift', 'Mindslash'})
        end
    end
    if state.emu then
        class.addSpell('nuke5', {'Chromaburst', 'Ancient: Neurosis', 'Madness of Ikkibi', 'Insanity'})
        class.addSpell('nuke4', {'Ancient: Neurosis', 'Madness of Ikkibi', 'Insanity'})
        class.addSpell('nuke3', {'Colored Chaos'})
        class.addSpell('unified', {'Unified Alacrity'})
        class.addSpell('dispel', {'Abashi\'s Disempowerment', 'Recant Magic'}, {opt='USEDISPEL'})
        class.addSpell('spasm', {'Synapsis Spasm'}, {opt='USEDEBUFF'})
    end
end

function class.initSpellRotations(_aqo)
    -- tash, command, chaotic, deceiving stare, pulmonary grip, mindrift, fortifying aura, mind coil, unity, dissident, mana replication, night's endless terror
    -- entries in the dots table are pairs of {spell id, spell name} in priority order
    table.insert(class.spellRotations.standard, class.spells.dotmiti)
    table.insert(class.spellRotations.standard, class.spells.meznoblur)
    table.insert(class.spellRotations.standard, class.spells.mezae)
    table.insert(class.spellRotations.standard, class.spells.dot)
    table.insert(class.spellRotations.standard, class.spells.dot2)
    table.insert(class.spellRotations.standard, class.spells.synergy)
    table.insert(class.spellRotations.standard, class.spells.nuke3)
    table.insert(class.spellRotations.standard, class.spells.nuke4)
    table.insert(class.spellRotations.standard, class.spells.nuke5)
    table.insert(class.spellRotations.standard, class.spells.composite)
    table.insert(class.spellRotations.standard, class.spells.stunaerune)
    table.insert(class.spellRotations.standard, class.spells.guard)
    table.insert(class.spellRotations.standard, class.spells.nightsterror)
    table.insert(class.spellRotations.standard, class.spells.combatinnate)
end

function class.initBurns(_aqo)
    table.insert(class.burnAbilities, common.getItem(mq.TLO.InvSlot('Chest').Item.Name()))
    table.insert(class.burnAbilities, common.getItem('Rage of Rolfron'))

    table.insert(class.burnAbilities, class.silent) -- song, 12 minute CD
    table.insert(class.burnAbilities, common.getAA('Illusions of Grandeur')) -- 12 minute CD, group spell crit buff
    table.insert(class.burnAbilities, common.getAA('Calculated Insanity')) -- 20 minute CD, increase crit for 27 spells
    if state.emu then
        table.insert(class.burnAbilities, common.getAA('Fundament: Second Spire of Enchantment'))
    else
        table.insert(class.burnAbilities, common.getAA('Spire of Enchantment')) -- buff, 7:30 minute CD
    end
    table.insert(class.burnAbilities, common.getAA('Improved Twincast')) -- 15min CD
    table.insert(class.burnAbilities, common.getAA('Chromatic Haze')) -- 15min CD
    table.insert(class.burnAbilities, common.getAA('Companion\'s Fury')) -- 10 minute CD
    table.insert(class.burnAbilities, common.getAA('Companion\'s Fortification')) -- 15 minute CD
    table.insert(class.burnAbilities, common.getAA('Mental Corruption')) -- decrease melee dmg + DoT
end

function class.initBuffs(_aqo)
    class.shield = common.getAA('Dimensional Shield')
    class.rune = common.getAA('Eldritch Rune')
    class.grouprune = common.getAA('Glyph Spray')
    class.reactiverune = common.getAA('Reactive Rune') -- group buff, melee/spell shield that procs rune
    class.manarune = common.getAA('Mind over Matter') -- absorb dmg using mana
    class.veil = common.getAA('Veil of Mindshadow') -- 5min CD, another rune?

    -- Buffs
    class.unity = common.getAA('Orator\'s Unity')
    -- Mana Recovery AAs
    class.azure = common.getAA('Azure Mind Crystal', {summonMinimum=1, nodmz=true}) -- summon clicky mana heal
    class.gathermana = common.getAA('Gather Mana')
    class.manadraw = common.getAA('Mana Draw')
    class.sanguine = common.getAA('Sanguine Mind Crystal', {summonMinimum=1, nodmz=true}) -- summon clicky hp heal

    table.insert(class.selfBuffs, class.spells.guard)
    table.insert(class.selfBuffs, class.spells.stunaerune)
    table.insert(class.selfBuffs, class.rune)
    table.insert(class.selfBuffs, class.veil)
    table.insert(class.selfBuffs, class.sanguine)
    table.insert(class.selfBuffs, class.azure)
    if class.spells.unified then
        table.insert(class.selfBuffs, class.spells.unified)
        class.kei = class.spells.unified
        class.haste = class.spells.unified
    else
        table.insert(class.selfBuffs, class.spells.kei)
        class.kei = class.spells.kei
        class.haste = class.spells.haste
    end
    class.addRequestAlias(class.kei, 'kei')
    class.addRequestAlias(class.haste, 'haste')

    table.insert(class.petBuffs, class.spells.pethaste)
    table.insert(class.petBuffs, common.getAA('Fortify Companion'))
    if state.emu then
        table.insert(class.auras, common.getAA('Auroria Mastery', {CheckFor='Aura of Bedazzlement'}))
        if class.spells.procbuff then class.spells.procbuff.classes = {MAG=true,WIZ=true,NEC=true,ENC=true,RNG=true} end
        table.insert(class.singleBuffs, class.spells.procbuff)
        table.insert(class.selfBuffs, class.spells.procbuff)
        local epic = common.getItem('Staff of Eternal Eloquence', {classes={MAG=true,WIZ=true,NEC=true,ENC=true,RNG=true}})
        table.insert(class.singleBuffs, epic)
    else
        table.insert(class.selfBuffs, common.getAA('Orator\'s Unity', {CheckFor='Ward of the Beguiler'}))
    end
end

function class.initDebuffs(_aqo)
    --class.debuff = common.getAA('Bite of Tashani')
    if state.emu then
        table.insert(class.debuffs, class.spells.dispel)
        table.insert(class.debuffs, class.spells.tash)
        table.insert(class.debuffs, common.getItem('Serpent of Vindication', {opt='USESLOW'}))
        table.insert(class.debuffs, class.spells.spasm)
    else
        table.insert(class.debuffs, common.getAA('Eradicate Magic', {opt='USEDISPEL'}))
        table.insert(class.debuffs, common.getAA('Bite of Tashani', {opt='USETASHAOE'}))
        table.insert(class.debuffs, common.getAA('Enveloping Helix', {opt='USESLOWAOE'})) -- AE slow on 8 targets
        table.insert(class.debuffs, common.getAA('Slowing Helix', {opt='USESLOW'})) -- single target slow
    end
end

function class.initDefensiveAbilities(_aqo)
    -- Aggro
    local postStasis = function()
        mq.delay(1000)
        mq.cmd('/removebuff "Self Stasis"')
        mq.cmd('/makemevis')
    end
    table.insert(class.fadeAbilities, common.getAA('Self Stasis', {postcast=postStasis}))
end

local function castSynergy()
    if class.spells.synergy and not mq.TLO.Me.Song('Beguiler\'s Synergy')() and mq.TLO.Me.SpellReady(class.spells.synergy.Name)() then
        if mq.TLO.Spell(class.spells.synergy.Name).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        class.spells.synergy:use()
        return true
    end
    return false
end

-- composite
-- synergy
-- nuke5
-- dot2
function class.findNextSpell()
    if not mq.TLO.Target.Tashed() and class.isEnabled('USEDEBUFF') and common.isSpellReady(class.spells.tash) then return class.spells.tash end
    if common.isSpellReady(class.spells.composite) then return class.spells.composite end
    if castSynergy() then return nil end
    --if state.emu and common.isSpellReady(class.spells.spasm) then return class.spells.spasm end
    if common.isSpellReady(class.spells.nuke5) then return class.spells.nuke5 end
    if common.isSpellReady(class.spells.dot) then return class.spells.dot end
    if common.isSpellReady(class.spells.dot2) then return class.spells.dot2 end
    if common.isSpellReady(class.spells.nuke4) then return class.spells.nuke4 end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

function class.recover()
    -- modrods
    common.checkMana()
    --if mq.TLO.Me.PctMana() < 20 then
    --    if class.gathermana and class.gathermana:use() then return end
    --end
    --if mq.TLO.Me.PctMana() < 20 then
    --    if class.manadraw and class.manadraw:use() then return end
    --end
    if mq.TLO.Me.PctMana() < 70 and class.azure then
        local cursor = mq.TLO.Cursor()
        if cursor and cursor:find(class.azure.Name) then mq.cmd('/autoinventory') mq.delay(1) end
        local manacrystal = mq.TLO.FindItem(class.azure.Name)
        if manacrystal() then
            abilities.use(abilities.Item:new({Name=manacrystal(), ID=manacrystal.ID()}))
        end
    end
    if mq.TLO.Zone.ShortName() ~= 'poknowledge' and mq.TLO.Me.PctMana() < config.get('MANASTONESTART') and mq.TLO.Me.PctHPs() > config.get('MANASTONESTARTHP') then
        local manastone = mq.TLO.FindItem('Manastone')
        if not manastone() then return end
        local manastoneTimer = timer:new((config.get('MANASTONETIME') or 0)*1000)
        while mq.TLO.Me.PctHPs() > config.get('MANASTONESTOPHP') and mq.TLO.Me.PctMana() < 90 do
            mq.cmd('/useitem Manastone')
            if manastoneTimer:timerExpired() then break end
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

local composite_names = {['Composite Reinforcement']=true,['Dissident Reinforcement']=true,['Dichotomic Reinforcement']=true}
local checkSpellTimer = timer:new(30000)
function class.checkSpellSet()
    if not common.clearToBuff() or mq.TLO.Me.Moving() or class.isEnabled('BYOS') then return end
    local spellSet = class.OPTS.SPELLSET.value
    if state.spellSetLoaded ~= spellSet or checkSpellTimer:timerExpired() then
        if spellSet == 'standard' then
            abilities.swapSpell(class.spells.tash, 1)
            abilities.swapSpell(class.spells.dotmiti, 2)
            abilities.swapSpell(class.spells.meznoblur, 3)
            abilities.swapSpell(class.spells.mezae, 4)
            abilities.swapSpell(class.spells.dot, 5)
            abilities.swapSpell(class.spells.dot2, 6)
            abilities.swapSpell(class.spells.synergy, 7)
            abilities.swapSpell(class.spells.nuke5, 8)
            abilities.swapSpell(class.spells.composite, 9, composite_names)
            abilities.swapSpell(class.spells.stunaerune, 10)
            abilities.swapSpell(class.spells.guard, 11)
            abilities.swapSpell(class.spells.nightsterror, 12)
            abilities.swapSpell(class.spells.combatinnate, 13)
            state.spellSetLoaded = spellSet
        end
        checkSpellTimer:reset()
    end
end

--[[
#Event CAST_IMMUNE                 "Your target has no mana to affect#*#"
#Event CAST_IMMUNE                 "Your target is immune to changes in its run speed#*#"
#Event CAST_IMMUNE                 "Your target is immune to snare spells#*#"
#Event CAST_IMMUNE                 "Your target is immune to the stun portion of this effect#*#"
#Event CAST_IMMUNE                 "Your target looks unaffected#*#"
]]--

return class