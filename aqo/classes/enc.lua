--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local mez = require('routines.mez')
local timer = require('utils.timer')
local abilities = require('ability')
local common = require('common')
local config = require('interface.configuration')
local state = require('state')

local Enchanter = class:new()

--[[
    https://forums.eqfreelance.net/index.php?topic=16075.0
]]
function Enchanter:init()
    self.classOrder = {'assist', 'mez', 'assist', 'aggro', 'debuff', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest', 'managepet', 'rez'}
    self.spellRotations = {standard={}}
    self.AURAS = {twincast=true, combatinnate=true, spellfocus=true, regen=true, disempower=true,}
    self:initBase('enc')

    self:initClassOptions()
    self:loadSettings()
    self:initSpellLines()
    self:initSpellRotations()
    self:initBuffs()
    self:initBurns()
    self:initDebuffs()
    self:initDefensiveAbilities()
    self:addCommonAbilities()

    self.mezbeam = common.getAA('Beam of Slumber')
    self.longmez = common.getAA('Noctambulate') -- 3min single target mez

    self.aekbblur = common.getAA('Beguiler\'s Banishment')
    self.kbblur = common.getAA('Beguiler\'s Directed Banishment')
    self.aeblur = common.getAA('Blanket of Forgetfulness')
    self.summonCompanion = common.getAA('Summon Companion')
    if self.spells.mezst then
        function Enchanter:beforeMez()
            if not mq.TLO.Target.Tashed() and self:isEnabled('TASHTHENMEZ') and self.spells.tash then
                self.spells.tash:use()
            end
            return true
        end
        self.spells.mezst.precast = self.beforeMez
    end
end

function Enchanter:availableBuffs()
    if self.spells.unified then
        self.spells.KEI = self.spells.unified
        self.spells.HASTE = self.spells.unified
    else
        self.spells.KEI = self.spells.keigroup
        self.spells.HASTE = self.spells.grouphaste
    end
    return {
        KEI = self.spells.KEI and self.spells.KEI.Name or nil,
        HASTE = self.spells.HASTE and self.spells.HASTE.Name or nil
    }
end

function Enchanter:initClassOptions()
    self:addOption('AURA1', 'Aura 1', 'twincast', self.AURAS, 'The first aura to keep up', 'combobox', nil, 'Aura1', 'string')
    self:addOption('AURA2', 'Aura 2', 'combatinnate', self.AURAS, 'The second aura to keep up', 'combobox', nil, 'Aura2', 'string')
    self:addOption('INTERRUPTFORMEZ', 'Interrupt for Mez', false, nil, 'Toggle interrupting current spell casts to cast mez', 'checkbox', nil, 'InterruptForMez', 'bool')
    self:addOption('TASHTHENMEZ', 'Tash Then Mez', true, nil, 'Toggle use of tash prior to attempting to mez mobs', 'checkbox', nil, 'TashThenMez', 'bool')
    self:addOption('USECHAOTIC', 'Use Chaotic', true, nil, 'Toggle use of Chaotic mez line', 'checkbox', nil, 'UseChaotic', 'bool')
    self:addOption('USECHARM', 'Use Charm', false, nil, 'Attempt to maintain a charm pet instead of using a regular pet', 'checkbox', nil, 'UseCharm', 'bool')
    self:addOption('USEDOT', 'Use DoT', true, nil, 'Toggle use of DoTs', 'checkbox', nil, 'UseDoT', 'bool')
    self:addOption('USEHASTE', 'Buff Haste', true, nil, 'Toggle use of haste buff line', 'checkbox', nil, 'UseHaste', 'bool')
    self:addOption('MEZST', 'Use Mez', true, nil, 'Use single target mez on adds within camp radius', 'checkbox', nil, 'MezST', 'bool')
    self:addOption('MEZAE', 'Use AE Mez', true, nil, 'Use AE Mez if 3 or more mobs are within camp radius', 'checkbox', nil, 'MezAE', 'bool')
    self:addOption('MEZAECOUNT', 'AE Mez Count', 3, nil, 'Threshold to use AE Mez ability', 'inputint', nil, 'MezAECount', 'bool')
    self:addOption('USEMINDOVERMATTER', 'Use Mind Over Matter', true, nil, 'Toggle use of Mind over Matter', 'checkbox', nil, 'UseMindOverMatter', 'bool')
    self:addOption('USENIGHTSTERROR', 'Buff Nights Terror', true, nil, 'Toggle use of Nights Terror buff line', 'checkbox', nil, 'UseNDT', 'bool')
    self:addOption('USENUKES', 'Use Nuke', true, nil, 'Toggle use of nukes', 'checkbox', nil, 'UseNukes', 'bool')
    self:addOption('USEPHANTASMAL', 'Use Phantasmal', true, nil, 'Toggle use of Phantasmal', 'checkbox', nil, 'UsePhantasmal', 'bool')
    self:addOption('USEREPLICATION', 'Buff Mana Proc', true, nil, 'Toggle use of Replication buff line', 'checkbox', nil, 'UseReplication', 'bool')
    self:addOption('USESHIELDOFFATE', 'Use Shield of Fate', true, nil, 'Toggle use of Shield of Fate', 'checkbox', nil, 'UseShieldOfFate', 'bool')
    self:addOption('USESLOW', 'Use Slow', false, nil, 'Toggle use of single target slow ability', 'checkbox', nil, 'UseSlow', 'bool')
    self:addOption('USESLOWAOE', 'Use Slow AOE', true, nil, 'Toggle use of AOE slow ability', 'checkbox', nil, 'UseSlowAOE', 'bool')
    self:addOption('USESPELLGUARD', 'Use Spell Guard', true, nil, 'Toggle use of Spell Guard', 'checkbox', nil, 'UseSpellGuard', 'bool')
    self:addOption('USEDEBUFF', 'Use Tash', false, nil, 'Toggle use of single target tash ability', 'checkbox', nil, 'UseDebuff', 'bool')
    self:addOption('USEDEBUFFAOE', 'Use Tash AOE', true, nil, 'Toggle use of AOE tash ability', 'checkbox', nil, 'UseDebuffAOE', 'bool')
    self:addOption('USEDISPEL', 'Use Dispel', true, nil, 'Dispel mobs with Eradicate Magic AA', 'checkbox', nil, 'UseDispel', 'bool')
end

function Enchanter:initSpellLines()
    self:addSpell('composite', {'Composite Reinforcement', 'Dissident Reinforcement', 'Dichotomic Reinforcement'}) -- restore mana, add dmg proc, inc dmg
    self:addSpell('alliance', {'Chromatic Coalition', 'Chromatic Covenant'})

    self:addSpell('mezst', {'Flummox', 'Addle', 'Euphoria'}) -- 9 ticks
    self:addSpell('mezst2', {'Flummoxing Flash', 'Addling Flash'}) -- 6 ticks
    self:addSpell('mezae', {'Stupefying Wave', 'Bewildering Wave', 'Neutralizing Wave', 'Bliss of the Nihil'}) -- targeted AE mez
    self:addSpell('mezaehate', {'Vexing Glance', 'Confounding Glance'}) -- targeted AE mez + 100% hate reduction
    self:addSpell('mezpbae', {'Wonderment', 'Bewilderment'})
    self:addSpell('mezpbae2', {'Perilous Confounding', 'Perilous Bewilderment'}) -- lvl 120
    self:addSpell('meznoblur', {'Chaotic Conundrum', 'Chaotic Puzzlement', 'Chaotic Deception'})
    self:addSpell('mezaeprocblur', {'Entrancing Stare', 'Mesmeric Stare'}) -- targeted AE mez
    self:addSpell('mezshield', {'Ward of the Stupefier', 'Ward of the Beguiler', 'Ward of the Deviser'}) -- mez proc on being hit

    self:addSpell('rune', {'Disquieting Rune', 'Marvel\'s Rune'}) -- 160k rune, self
    self:addSpell('rune2', {'Rune of Zoraxmen', 'Rune of Tearc'}) -- 90k rune, single target
    self:addSpell('dotrune', {'Aegis of Dhakka', 'Aegis of Xetheg'}) -- absorb DoT dmg
    self:addSpell('guard', {'Shield of Inescapability', 'Shield of Inevitability', 'Shield of Destiny', 'Shield of Order'}) -- spell + melee guard
    self:addSpell('dotmiti', {'Deviser\'s Auspice', 'Transfixer\'s Auspice'}) -- DoT guard
    self:addSpell('spellmiti', {'Aegis of Elmara', 'Aegis of Sefra'}) -- 20% spell mitigation

    self:addSpell('meleemiti', {'Gloaming Auspice', 'Eclipsed Auspice'}) -- melee guard, + hate
    self:addSpell('absorbbuff', {'Brimstone Stability', 'Brimstone Endurance'}) -- increase absorb dmg, + hate
    self:addSpell('aggrorune', {'Esoteric Rune', 'Ghastly Rune'}) -- single target rune + hate increase
    -- Polyradiant Rune -- hate mod rune, stun proc on fade

    self:addSpell('groupdotrune', {'Legion of Dhakka', 'Legion of Xetheg', 'Legion of Cekenar'})
    self:addSpell('groupspellrune', {'Legion of Ogna', 'Legion of Liako', 'Legion of Kildrukaun'})
    self:addSpell('groupaggrorune', {'Gloaming Rune', 'Eclipsed Rune'}) -- group rune + aggro reduction proc

    self:addSpell('dot', {'Mind Whirl', 'Mind Vortex', 'Mind Coil', 'Mind Shatter'}, {opt='USEDOT'}) -- big dot
    self:addSpell('dot2', {'Asphyxiating Grasp', 'Throttling Grip', 'Pulmonary Grip', 'Arcane Noose'}, {opt='USEDOT'}) -- decent dot
    self:addSpell('debuffdot', {'Dismaying Constriction', 'Perplexing Constriction'}) -- debuff + nuke + dot
    self:addSpell('manadot', {'Tears of Kasha', 'Tears of Xenacious'}) -- hp + mana DoT
    self:addSpell('nukerune', {'Chromatic Spike', 'Chromatic Flare'}) -- 15k nuke + self rune
    self:addSpell('nuke', {'Cognitive Appropriation', 'Psychological Appropriation'}) -- 20k
    self:addSpell('nuke2', {'Chromaclap', 'Chromashear'}) -- 23k
    self:addSpell('nuke3', {'Polyradiant Assault', 'Polyluminous Assault'}) -- 27k nuke
    self:addSpell('nuke4', {'Obscuring Eclipse'}) -- 27k nuke
    self:addSpell('aenuke', {'Gravity Roil'}) -- 23k targeted ae nuke

    self:addSpell('calm', {'Still Mind'})
    self:addSpell('tash', {'Roar of Tashan', 'Edict of Tashan', 'Proclamation of Tashan', 'Bite of Tashani', 'Echo of Tashan'}, {opt='USEDEBUFF'})
    self:addSpell('stunst', {'Dizzying Spindle', 'Dizzying Vortex'}) -- single target stun
    self:addSpell('stunae', {'Remote Color Calibration', 'Remote Color Conflagration'})
    self:addSpell('stunpbae', {'Color Calibration', 'Color Conflagration'})
    self:addSpell('stunaerune', {'Polyluminous Rune', 'Polycascading Rune', 'Polyfluorescent Rune', 'Ethereal Rune', 'Arcane Rune'}) -- self rune, proc ae stun on fade

    self:addSpell('pet', {'Flariton\'s Animation', 'Constance\'s Animation', 'Aeidorb\'s Animation'})
    self:addSpell('pethaste', {'Invigorated Minion'})
    self:addSpell('charm', {'Esoteric Command', 'Marvel\'s Command'})
    -- buffs
    self:addSpell('unity', {'Esoteric Unity', 'Marvel\'s Unity', 'Deviser\'s Unity'}) -- mez proc on being hit
    self:addSpell('procbuff', {'Mana Reproduction', 'Mana Rebirth', 'Mana Recursion', 'Mana Flare'}) -- single target dmg proc buff
    self:addSpell('kei', {'Preordination', 'Scrying Visions', 'Sagacity', 'Voice of Quellious'})
    self:addSpell('keigroup', {'Voice of Preordination', 'Voice of Perception', 'Voice of Sagacity', 'Voice of Clairvoyance', 'Voice of Quellious'})
    self:addSpell('haste', {'Speed of Margator', 'Speed of Itzal', 'Speed of Cekenar'}) -- single target buff
    self:addSpell('grouphaste', {'Hastening of Margator', 'Hastening of Jharin', 'Hastening of Cekenar'}) -- group haste
    self:addSpell('nightsterror', {'Night\'s Perpetual Terror', 'Night\'s Endless Terror'}) -- melee attack proc
    -- auras - mana, learners, spellfocus, combatinnate, disempower, rune, twincast
    self:addSpell('twincast', {'Twincast Aura'})
    self:addSpell('regen', {'Esoteric Aura', 'Marvel\'s Aura', 'Deviser\'s Aura'}) -- mana + end regen aura
    self:addSpell('spellfocus', {'Intensifying Aura', 'Enhancing Aura', 'Fortifying Aura'}) -- increase dmg of DDs
    self:addSpell('combatinnate', {'Mana Ripple Aura', 'Mana Radix Aura', 'Mana Replication Aura'}) -- dmg proc on spells, Issuance of Mana Radix == place aura at location
    self:addSpell('disempower', {'Arcane Disjunction Aura'})
    -- 'Runic Scintillation Aura' -- rune aura
    -- unity buffs
    self:addSpell('shield', {'Shield of Memories', 'Shield of Shadow', 'Shield of Restless Ice'})
    self:addSpell('ward', {'Ward of the Beguiler', 'Ward of the Transfixer'})

    self:addSpell('synergy', {'Mindrend', 'Mindreap', 'Mindrift', 'Mindslash'}) -- 63k nuke
    if self.spells.synergy then
        if self.spells.synergy.Name:find('rend') then
            self:addSpell('nuke5', {'Mindreap', 'Mindrift', 'Mindslash'})
        elseif self.spells.synergy.Name:find('reap') then
            self:addSpell('nuke5', {'Mindrift', 'Mindslash'})
        end
    end
    if state.emu then
        self:addSpell('nuke5', {'Chromaburst', 'Ancient: Neurosis', 'Madness of Ikkibi', 'Insanity'})
        self:addSpell('nuke4', {'Ancient: Neurosis', 'Madness of Ikkibi', 'Insanity'})
        self:addSpell('nuke3', {'Colored Chaos'})
        self:addSpell('unified', {'Unified Alacrity'})
        self:addSpell('dispel', {'Abashi\'s Disempowerment', 'Recant Magic'}, {opt='USEDISPEL'})
        self:addSpell('spasm', {'Synapsis Spasm'}, {opt='USEDEBUFF'})
    end
end

function Enchanter:initSpellRotations()
    -- tash, command, chaotic, deceiving stare, pulmonary grip, mindrift, fortifying aura, mind coil, unity, dissident, mana replication, night's endless terror
    -- entries in the dots table are pairs of {spell id, spell name} in priority order
    table.insert(self.spellRotations.standard, self.spells.dotmiti)
    table.insert(self.spellRotations.standard, self.spells.meznoblur)
    table.insert(self.spellRotations.standard, self.spells.mezae)
    table.insert(self.spellRotations.standard, self.spells.dot)
    table.insert(self.spellRotations.standard, self.spells.dot2)
    table.insert(self.spellRotations.standard, self.spells.synergy)
    table.insert(self.spellRotations.standard, self.spells.nuke3)
    table.insert(self.spellRotations.standard, self.spells.nuke4)
    table.insert(self.spellRotations.standard, self.spells.nuke5)
    table.insert(self.spellRotations.standard, self.spells.composite)
    table.insert(self.spellRotations.standard, self.spells.stunaerune)
    table.insert(self.spellRotations.standard, self.spells.guard)
    table.insert(self.spellRotations.standard, self.spells.nightsterror)
    table.insert(self.spellRotations.standard, self.spells.combatinnate)
end

function Enchanter:initBurns()
    table.insert(self.burnAbilities, common.getItem(mq.TLO.InvSlot('Chest').Item.Name()))
    table.insert(self.burnAbilities, common.getItem('Rage of Rolfron'))

    table.insert(self.burnAbilities, self.silent) -- song, 12 minute CD
    table.insert(self.burnAbilities, common.getAA('Illusions of Grandeur')) -- 12 minute CD, group spell crit buff
    table.insert(self.burnAbilities, common.getAA('Calculated Insanity')) -- 20 minute CD, increase crit for 27 spells
    if state.emu then
        table.insert(self.burnAbilities, common.getAA('Fundament: Second Spire of Enchantment'))
    else
        table.insert(self.burnAbilities, common.getAA('Spire of Enchantment')) -- buff, 7:30 minute CD
    end
    table.insert(self.burnAbilities, common.getAA('Improved Twincast')) -- 15min CD
    table.insert(self.burnAbilities, common.getAA('Chromatic Haze')) -- 15min CD
    table.insert(self.burnAbilities, common.getAA('Companion\'s Fury')) -- 10 minute CD
    table.insert(self.burnAbilities, common.getAA('Companion\'s Fortification')) -- 15 minute CD
    table.insert(self.burnAbilities, common.getAA('Mental Corruption')) -- decrease melee dmg + DoT
end

function Enchanter:initBuffs()
    self.shield = common.getAA('Dimensional Shield')
    self.rune = common.getAA('Eldritch Rune')
    self.grouprune = common.getAA('Glyph Spray')
    self.reactiverune = common.getAA('Reactive Rune') -- group buff, melee/spell shield that procs rune
    self.manarune = common.getAA('Mind over Matter') -- absorb dmg using mana
    self.veil = common.getAA('Veil of Mindshadow') -- 5min CD, another rune?

    -- Buffs
    self.unity = common.getAA('Orator\'s Unity')
    -- Mana Recovery AAs
    self.azure = common.getAA('Azure Mind Crystal', {summonMinimum=1, nodmz=true}) -- summon clicky mana heal
    self.gathermana = common.getAA('Gather Mana')
    self.manadraw = common.getAA('Mana Draw')
    self.sanguine = common.getAA('Sanguine Mind Crystal', {summonMinimum=1, nodmz=true}) -- summon clicky hp heal

    table.insert(self.selfBuffs, self.spells.guard)
    table.insert(self.selfBuffs, self.spells.stunaerune)
    table.insert(self.selfBuffs, self.rune)
    table.insert(self.selfBuffs, self.veil)
    table.insert(self.selfBuffs, self.sanguine)
    table.insert(self.selfBuffs, self.azure)
    if self.spells.unified then
        table.insert(self.selfBuffs, self.spells.unified)
        self.kei = self.spells.unified
        self.haste = self.spells.unified
    else
        table.insert(self.selfBuffs, self.spells.kei)
        self.kei = self.spells.kei
        self.haste = self.spells.haste
    end
    self:addRequestAlias(self.kei, 'kei')
    self:addRequestAlias(self.haste, 'haste')

    table.insert(self.petBuffs, self.spells.pethaste)
    table.insert(self.petBuffs, common.getAA('Fortify Companion'))
    if state.emu then
        table.insert(self.auras, common.getAA('Auroria Mastery', {CheckFor='Aura of Bedazzlement'}))
        if self.spells.procbuff then self.spells.procbuff.classes = {MAG=true,WIZ=true,NEC=true,ENC=true,RNG=true} end
        table.insert(self.singleBuffs, self.spells.procbuff)
        table.insert(self.selfBuffs, self.spells.procbuff)
        local epic = common.getItem('Staff of Eternal Eloquence', {classes={MAG=true,WIZ=true,NEC=true,ENC=true,RNG=true}})
        table.insert(self.singleBuffs, epic)
    else
        table.insert(self.selfBuffs, common.getAA('Orator\'s Unity', {CheckFor='Ward of the Beguiler'}))
    end
end

function Enchanter:initDebuffs()
    --self.debuff = common.getAA('Bite of Tashani')
    if state.emu then
        table.insert(self.debuffs, self.spells.dispel)
        table.insert(self.debuffs, self.spells.tash)
        table.insert(self.debuffs, common.getItem('Serpent of Vindication', {opt='USESLOW'}))
        table.insert(self.debuffs, self.spells.spasm)
    else
        table.insert(self.debuffs, common.getAA('Eradicate Magic', {opt='USEDISPEL'}))
        table.insert(self.debuffs, common.getAA('Bite of Tashani', {opt='USETASHAOE'}))
        table.insert(self.debuffs, common.getAA('Enveloping Helix', {opt='USESLOWAOE'})) -- AE slow on 8 targets
        table.insert(self.debuffs, common.getAA('Slowing Helix', {opt='USESLOW'})) -- single target slow
    end
end

function Enchanter:initDefensiveAbilities()
    -- Aggro
    local postStasis = function()
        mq.delay(1000)
        mq.cmd('/removebuff "Self Stasis"')
        mq.cmd('/makemevis')
    end
    table.insert(self.fadeAbilities, common.getAA('Self Stasis', {postcast=postStasis}))
end

local function castSynergy()
    if Enchanter.spells.synergy and not mq.TLO.Me.Song('Beguiler\'s Synergy')() and mq.TLO.Me.SpellReady(Enchanter.spells.synergy.Name)() then
        if mq.TLO.Spell(Enchanter.spells.synergy.Name).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        Enchanter.spells.synergy:use()
        return true
    end
    return false
end

-- composite
-- synergy
-- nuke5
-- dot2
function Enchanter:findNextSpell()
    if self:isEnabled('USEDEBUFF') and self.spells.tash and not mq.TLO.Target.Tashed() and self.spells.tash:isReady() then return self.spells.tash end
    if self.spells.composite and self.spells.composite:isReady() then return self.spells.composite end
    if castSynergy() then return nil end
    --if state.emu and self.spells.spasm and self.spells.spasm:isReady() then return self.spells.spasm end
    if self.spells.nuke5 and self.spells.nuke5:isReady() then return self.spells.nuke5 end
    if self.spells.dot and self.spells.dot:isReady() then return self.spells.dot end
    if self.spells.dot2 and self.spells.dot2:isReady() then return self.spells.dot2 end
    if self.spells.nuke4 and self.spells.nuke4:isReady() then return self.spells.nuke4 end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

function Enchanter:recover()
    -- modrods
    common.checkMana()
    --if mq.TLO.Me.PctMana() < 20 then
    --    if self.gathermana and self.gathermana:use() then return end
    --end
    --if mq.TLO.Me.PctMana() < 20 then
    --    if self.manadraw and self.manadraw:use() then return end
    --end
    if mq.TLO.Me.PctMana() < 70 and self.azure then
        local cursor = mq.TLO.Cursor()
        if cursor and cursor:find(self.azure.Name) then mq.cmd('/autoinventory') mq.delay(1) end
        local manacrystal = mq.TLO.FindItem(self.azure.Name)
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
function Enchanter:checkSpellSet()
    if not common.clearToBuff() or mq.TLO.Me.Moving() or self:isEnabled('BYOS') then return end
    local spellSet = self.OPTS.SPELLSET.value
    if state.spellSetLoaded ~= spellSet or checkSpellTimer:timerExpired() then
        if spellSet == 'standard' then
            abilities.swapSpell(self.spells.tash, 1)
            abilities.swapSpell(self.spells.dotmiti, 2)
            abilities.swapSpell(self.spells.meznoblur, 3)
            abilities.swapSpell(self.spells.mezae, 4)
            abilities.swapSpell(self.spells.dot, 5)
            abilities.swapSpell(self.spells.dot2, 6)
            abilities.swapSpell(self.spells.synergy, 7)
            abilities.swapSpell(self.spells.nuke5, 8)
            abilities.swapSpell(self.spells.composite, 9, composite_names)
            abilities.swapSpell(self.spells.stunaerune, 10)
            abilities.swapSpell(self.spells.guard, 11)
            abilities.swapSpell(self.spells.nightsterror, 12)
            abilities.swapSpell(self.spells.combatinnate, 13)
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

return Enchanter