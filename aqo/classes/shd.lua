--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local timer = require('utils.timer')
local abilities = require('ability')
local common = require('common')
local mode = require('mode')
local state = require('state')

local ShadowKnight = class:new()

--[[
    touch of the devourer
    theft of agony
    terror of discord
    dread gaze
    spear of muram
    terror of thule
    voice of innoruuk
    blood of inruku
    touch of draygun
    ancient: bite of muram
    decrepit skin
]]
function ShadowKnight:init()
    self.classOrder = {'assist', 'cast', 'ae', 'mash', 'burn', 'recover', 'rest', 'buff', 'managepet'}
    self.spellRotations = {standard={},dps={}}
    self:initBase('shd')

    mq.cmd('/squelch /stick mod -2')
    mq.cmd('/squelch /stick set delaystrafe on')

    self:initClassOptions()
    self:loadSettings()
    self:initSpellLines()
    self:initSpellConditions()
    self:initSpellRotations()
    self:initTankAbilities()
    self:initDPSAbilities()
    self:initBurns()
    self:initBuffs()

    self.leechtouch = common.getAA('Leech Touch') -- 9min CD, giant lifetap

    self.epic = common.getItem('Innoruuk\'s Dark Blessing') or common.getItem('Innoruuk\'s Voice')
    self.summonCompanion = common.getAA('Summon Companion')
    self.pullSpell = self.spells.terror
end

function ShadowKnight:initClassOptions()
    self:addOption('USEHATESATTRACTION', 'Use Hate\'s Attraction', true, nil, 'Toggle use of Hates Attraction AA', 'checkbox', nil, 'UseHatesAttraction', 'bool')
    self:addOption('USEPROJECTION', 'Use Projection', true, nil, 'Toggle use of Projection AA', 'checkbox', nil, 'UseProjection', 'bool')
    self:addOption('USEAZIA', 'Use Unity Azia', true, nil, 'Toggle use of Unity (Azia) AA', 'checkbox', 'USEBEZA', 'UseAzia', 'bool')
    self:addOption('USEBEZA', 'Use Unity Beza', false, nil, 'Toggle use of Unity (Beza) AA', 'checkbox', 'USEAZIA', 'UseBeza', 'bool')
    self:addOption('USEDISRUPTION', 'Use Disruption', true, nil, 'Toggle use of Disruption', 'checkbox', nil, 'UseDisruption', 'bool')
    self:addOption('USEINSIDIOUS', 'Use Insidious', false, nil, 'Toggle use of Insidious', 'checkbox', nil, 'UseInsidious', 'bool')
    self:addOption('USELIFETAP', 'Use Lifetap', true, nil, 'Toggle use of lifetap spells', 'checkbox', nil, 'UseLifetap', 'bool')
    self:addOption('USEVOICEOFTHULE', 'Use Voice of Thule', false, nil, 'Toggle use of Voice of Thule buff', 'checkbox', nil, 'UseVoiceOfThule', 'bool')
    self:addOption('USETORRENT', 'Use Torrent', true, nil, 'Toggle use of torrent', 'checkbox', nil, 'UseTorrent', 'bool')
    self:addOption('USESWARM', 'Use Snare', true, nil, 'Toggle use of swarm pets', 'checkbox', nil, 'UseSwarm', 'bool')
    self:addOption('USEDEFLECTION', 'Use Deflection', false, nil, 'Toggle use of deflection discipline', 'checkbox', nil, 'UseDeflection', 'bool')
    self:addOption('DONTCAST', 'Don\'t Cast', false, nil, 'Don\'t cast spells in combat', 'checkbox', nil, 'DontCast', 'bool')
    self:addOption('USEEPIC', 'Use Epic', true, nil, 'Use epic in burns', 'checkbox', nil, 'UseEpic', 'bool')
end

function ShadowKnight:initSpellLines()
    self:addSpell('composite', {'Composite Fang'}) -- big lifetap
    self:addSpell('alliance', {'Bloodletting Coalition'}) -- alliance
    -- Aggro
    self:addSpell('challenge', {'Petition for Power', 'Parlay for Power', 'Terror of Thule', 'Aura of Hate'}) -- main hate spell
    self:addSpell('terror', {'Terror of Tarantis', 'Terror of Ander', 'Terror of Discord', 'Terror of Terris',  'Terror of Death', 'Terror of Darkness'}) -- ST increase hate by 1
    self:addSpell('aeterror', {'Animus', 'Antipathy', 'Dread Gaze'}, {threshold=2}) -- ST increase hate by 1
    --['']={'Oppressor\'s Audacity', 'Usurper\'s Audacity'}), -- increase hate by a lot, does this get used?
    -- Lifetaps
    self:addSpell('largetap', {'Dire Rebuke', 'Dire Censure'}) -- large lifetap
    self:addSpell('tap1', {'Touch of Flariton', 'Touch of Txiki', 'Touch of Draygun', 'Touch of Innoruuk'})--, 'Drain Soul', 'Lifedraw'}) -- lifetap
    self:addSpell('tap2', {'Touch of Mortimus', 'Touch of Namdrows', 'Touch of the Devourer', 'Touch of Volatis'}) -- lifetap + temp hp buff Gift of Namdrows
    self:addSpell('dottap', {'Bond of Tatalros', 'Bond of Bynn', 'Bond of Inruku'}) -- lifetap dot
    self:addSpell('bitetap', {'Charka\'s Bite', 'Cruor\'s Bite', 'Ancient: Bite of Muram', 'Zevfeer\'s Bite'}) -- lifetap with hp/mana recourse
    -- AE lifetap + aggro
    self:addSpell('aetap', {'Insidious Repudiation', 'Insidious Renunciation'}) -- large hate + lifetap
    -- DPS
    self:addSpell('spear', {'Spear of Lazam', 'Spear of Bloodwretch', 'Spear of Muram', 'Miasmic Spear', 'Spear of Disease'}) -- poison nuke
    self:addSpell('poison', {'Blood of Shoru', 'Blood of Tearc', 'Blood of Inruku', 'Blood of Pain'}) -- poison dot
    self:addSpell('disease', {'Plague of the Fleawalker', 'Plague of Fleshrot'}) -- disease dot
    self:addSpell('corruption', {'Vitriolic Blight', 'Unscrupulous Blight'}) -- corruption dot
    self:addSpell('acdis', {'Dire Squelch', 'Dire Seizure'}) -- disease + ac dot
    self:addSpell('acdebuff', {'Torrent of Desolation', 'Torrent of Melancholy', 'Theft of Agony'}) -- ac debuff
    --['']={'Odious Bargain', 'Despicable Bargain'}), -- ae hate nuke, does this get used?
    -- Short Term Buffs
    self:addSpell('stance', {'Unwavering Stance', 'Adamant Stance', 'Vampiric Embrace'}) -- temp HP buff, 2.5min
    self:addSpell('skin', {'Krizad\'s Skin', 'Xenacious\' Skin', 'Decrepit Skin'}) -- Xenacious' Skin proc, 5min buff
    self:addSpell('disruption', {'Confluent Disruption', 'Scream of Death'}) -- lifetap proc on heal
    --['']={'Impertinent Influence'}), -- ac buff, 20% dmg mitigation, lifetap proc, is this upgraded by xetheg's carapace? stacks?
    -- Pet
    self:addSpell('pet', {'Minion of Fandrel', 'Minion of Itzal', 'Son of Decay', 'Invoke Death', 'Cackling Bones', 'Animate Dead'}) -- pet
    self:addSpell('pethaste', {'Gift of Fandrel', 'Gift of Itzal', 'Rune of Decay', 'Augmentation of Death', 'Augment Death'}) -- pet haste
    -- Unity Buffs
    self:addSpell('shroud', {'Shroud of Rimeclaw', 'Shroud of Zelinstein', 'Shroud of Discord', 'Black Shroud'}, {swap=false}) -- Shroud of Zelinstein Strike proc
    self:addSpell('bezaproc', {'Mental Wretchedness', 'Mental Anguish', 'Mental Horror'}, {opt='USEBEZA'}) -- Mental Anguish Strike proc
    self:addSpell('aziaproc', {'Mortimus\' Horror', 'Brightfield\'s Horror'}, {opt='USEAZIA'}) -- Brightfield's Horror Strike proc
    self:addSpell('ds', {'Goblin Skin', 'Tekuel Skin'}) -- large damage shield self buff
    self:addSpell('lich', {'Kar\'s Covenant', 'Aten Ha Ra\'s Covenant'}) -- lich mana regen
    self:addSpell('drape', {'Drape of the Ankexfen', 'Drape of the Akheva', 'Cloak of Discord', 'Cloak of Luclin'}) -- self buff hp, ac, ds
    self:addSpell('atkbuff', {'Call of Blight', 'Penumbral Call'}) -- atk buff, hp drain on self
    --['']=common.get_best_spell({'Remorseless Demeanor'})
end

function ShadowKnight:initSpellConditions()
    local function mobsMissingAggro()
        if state.mobCount >= 2 then
            local xtar_aggro_count = 0
            for i=1,13 do
                local xtar = mq.TLO.Me.XTarget(i)
                if xtar.ID() ~= mq.TLO.Target.ID() and xtar.TargetType() == 'Auto Hater' and xtar.PctAggro() < 100 then
                    xtar_aggro_count = xtar_aggro_count + 1
                end
            end
            return xtar_aggro_count > 0
        end
    end

    if self.spells.aeterror then self.spells.aeterror.condition = function() return mode.currentMode:isTankMode() and state.loop.PctHPs > 70 and mobsMissingAggro() end end
    local aggroCondition = function() return mode.currentMode:isTankMode() and state.loop.PctHPs > 70 end
    if self.spells.challenge then self.spells.challenge.condition = aggroCondition end
    --if self.spells.terror then self.spells.terror.condition = aggroCondition end
    local lifetapCondition = function() return state.loop.PctHPs < 85 end
    if self.spells.largetap then self.spells.largetap.condition = lifetapCondition end
    if self.spells.tap1 then self.spells.tap1.condition = lifetapCondition end
end

function ShadowKnight:initSpellRotations()
    table.insert(self.spellRotations.standard, self.spells.aeterror)
    if not state.emu then table.insert(self.spellRotations.standard, self.spells.challenge) end
    table.insert(self.spellRotations.standard, self.spells.terror)
    table.insert(self.spellRotations.standard, self.spells.bitetap)
    table.insert(self.spellRotations.standard, self.spells.spear)
    table.insert(self.spellRotations.standard, self.spells.composite)
    table.insert(self.spellRotations.standard, self.spells.largetap)
    table.insert(self.spellRotations.standard, self.spells.tap1)
    table.insert(self.spellRotations.standard, self.spells.tap2)
    table.insert(self.spellRotations.standard, self.spells.dottap)
    --table.insert(self.spellRotations.standard, self.spells.stance)
    --table.insert(self.spellRotations.standard, self.spells.skin)
    table.insert(self.spellRotations.standard, self.spells.acdebuff)

    table.insert(self.spellRotations.dps, self.spells.tap1)
    table.insert(self.spellRotations.dps, self.spells.tap2)
    table.insert(self.spellRotations.dps, self.spells.largetap)
    table.insert(self.spellRotations.dps, self.spells.composite)
    table.insert(self.spellRotations.dps, self.spells.spear)
    table.insert(self.spellRotations.dps, self.spells.corruption)
    table.insert(self.spellRotations.dps, self.spells.poison)
    table.insert(self.spellRotations.dps, self.spells.dottap)
    table.insert(self.spellRotations.dps, self.spells.disease)
    table.insert(self.spellRotations.dps, self.spells.bitetap)
    table.insert(self.spellRotations.dps, self.spells.stance)
    table.insert(self.spellRotations.dps, self.spells.skin)
    table.insert(self.spellRotations.dps, self.spells.acdebuff)
end

function ShadowKnight:initTankAbilities()
    -- TANK
    -- defensives
    -- common.getBestDisc({'Gird'}) -- absorb melee/spell dmg, short cd mash ability
    self.flash = common.getAA('Shield Flash') -- 4min CD, short deflection
    self.mantle = common.getBestDisc({'Geomimus Mantle', 'Fyrthek Mantle'}) -- 15min CD, 35% melee dmg mitigation, heal on fade
    self.carapace = common.getBestDisc({'Kanghammer\'s Carapace', 'Xetheg\'s Carapace'}) -- 7m30s CD, ac buff, 20% dmg mitigation, lifetap proc
    self.guardian = common.getBestDisc({'Corrupted Guardian Discipline'}) -- 12min CD, 36% mitigation, large damage debuff to self, lifetap proc
    self.deflection = common.getBestDisc({'Deflection Discipline'}, {opt='USEDEFLECTION'})

    table.insert(self.tankAbilities, common.getSkill('Taunt', {aggro=true}))
    table.insert(self.tankAbilities, self.spells.challenge)
    table.insert(self.tankAbilities, self.spells.terror)
    table.insert(self.tankAbilities, common.getBestDisc({'Repudiate'})) -- mash, 90% melee/spell dmg mitigation, 2 ticks or 85k dmg
    table.insert(self.tankAbilities, common.getAA('Projection of Doom', {opt='USEPROJECTION'})) -- aggro swarm pet

    self.attraction = common.getAA('Hate\'s Attraction', {opt='USEHATESATTRACTION'}) -- aggro swarm pet

    -- mash AE aggro
    table.insert(self.AETankAbilities, self.spells.aeterror)
    table.insert(self.AETankAbilities, common.getAA('Explosion of Spite', {threshold=2})) -- 45sec CD
    table.insert(self.AETankAbilities, common.getAA('Explosion of Hatred', {threshold=4})) -- 45sec CD
    --table.insert(mashAEAggroAAs4, common.getAA('Stream of Hatred')) -- large frontal cone ae aggro

    table.insert(self.tankBurnAbilities, common.getBestDisc({'Unconditional Acrimony', 'Unrelenting Acrimony'})) -- instant aggro
    table.insert(self.tankBurnAbilities, common.getAA('Ageless Enmity')) -- big taunt
    table.insert(self.tankBurnAbilities, common.getAA('Veil of Darkness')) -- large agro, lifetap, blind, mana/end tap
    table.insert(self.tankBurnAbilities, common.getAA('Reaver\'s Bargain')) -- 20min CD, 75% melee dmg absorb
end

function ShadowKnight:initDPSAbilities()
    -- DPS
    table.insert(self.DPSAbilities, common.getSkill('Bash'))
    table.insert(self.DPSAbilities, common.getBestDisc({'Reflexive Resentment'})) -- 3x 2hs attack + heal
    table.insert(self.DPSAbilities, common.getAA('Vicious Bite of Chaos')) -- 1min CD, nuke + group heal
    table.insert(self.DPSAbilities, common.getAA('Spire of the Reavers')) -- 7m30s CD, dmg,crit,parry,avoidance buff
end

function ShadowKnight:initBurns()
    table.insert(self.burnAbilities, common.getBestDisc({'Incapacitating Blade', 'Grisly Blade'})) -- 2hs attack
    table.insert(self.burnAbilities, common.getBestDisc({'ncarnadine Blade', 'Sanguine Blade'})) -- 3 strikes
    table.insert(self.burnAbilities, common.getAA('Gift of the Quick Spear')) -- 10min CD, twincast
    table.insert(self.burnAbilities, common.getAA('T`Vyl\'s Resolve')) -- 10min CD, dmg buff on 1 target
    --table.insert(self.burnAbilities, common.getAA('Harm Touch')) -- 20min CD, giant nuke + dot
    --table.insert(self.burnAbilities, common.getAA('Leech Touch')) -- 9min CD, giant lifetap
    table.insert(self.burnAbilities, common.getAA('Thought Leech')) -- 18min CD, nuke + mana/end tap
    table.insert(self.burnAbilities, common.getAA('Scourge Skin')) -- 15min CD, large DS
    table.insert(self.burnAbilities, common.getAA('Chattering Bones', {opt='USESWARM'})) -- 10min CD, swarm pet
    --table.insert(self.burnAbilities, common.getAA('Visage of Death')) -- 12min CD, melee dmg burn
    table.insert(self.burnAbilities, common.getAA('Visage of Decay')) -- 12min CD, dot dmg burn
end

function ShadowKnight:initHeals()

end

function ShadowKnight:initBuffs()
-- Buffs
    -- dark lord's unity azia X -- shroud of zelinstein, brightfield's horror, drape of the akheva, remorseless demeanor, tekuel skin, aten ha ra's covenant, penumbral call
    local buffazia = common.getAA('Dark Lord\'s Unity (Azia)')
    -- dark lord's unity beza X -- shroud of zelinstein, mental anguish, drape of the akheva, remorseless demeanor, tekuel skin, aten ha ra's covenant, penumbral call
    local buffbeza = common.getAA('Dark Lord\'s Unity (Beza)', {opt='USEBEZA'})
    local voice = common.getAA('Voice of Thule', {opt='USEVOICEOFTHULE'}) -- aggro mod buff

    if state.emu then
        table.insert(self.selfBuffs, self.spells.drape)
        table.insert(self.selfBuffs, self.spells.bezaproc)
        table.insert(self.selfBuffs, self.spells.skin)
        table.insert(self.selfBuffs, self.spells.shroud)
        table.insert(self.selfBuffs, common.getAA('Touch of the Cursed'))
        self:addSpell('voice', {'Voice of Innoruuk'}, {opt='USEVOICEOFTHULE'})
        table.insert(self.selfBuffs, self.spells.voice)
    else
        table.insert(self.selfBuffs, buffazia)
        table.insert(self.selfBuffs, buffbeza)
        table.insert(self.selfBuffs, voice)
    end
    table.insert(self.petBuffs, self.spells.pethaste)
end

function ShadowKnight:mashClass()
    local target = mq.TLO.Target
    local mobhp = target.PctHPs()

    if mode.currentMode:isTankMode() or mq.TLO.Group.MainTank.ID() == state.loop.ID then
        -- hate's attraction
        if self.attraction and self:isEnabled(self.attraction.opt) and mobhp and mobhp > 95 then
            self.attraction:use()
        end
    end
end

function ShadowKnight:burnClass()
    if mode.currentMode:isTankMode() or mq.TLO.Group.MainTank.ID() == state.loop.ID then
        if self.mantle then self.mantle:use() end
        if self.carapace then self.carapace:use() end
        if self.guardian then self.guardian:use() end
    end

    if self:isEnabled('USEEPIC') and self.epic then self.epic:use() end
end

function ShadowKnight:ohshit()
    if state.loop.PctHPs < 35 and mq.TLO.Me.CombatState() == 'COMBAT' then
        if mode.currentMode:isTankMode() or mq.TLO.Group.MainTank.ID() == state.loop.ID then
            if self.flash and mq.TLO.Me.AltAbilityReady(self.flash.Name)() then
                self.flash:use()
            elseif self.deflection and self:isEnabled(self.deflection.opt)  then
                self.deflection:use()
            end
            if self.leechtouch then self.leechtouch:use() end
        end
    end
end

local composite_names = {['Composite Fang']=true,['Dissident Fang']=true,['Dichotomic Fang']=true}
local checkSpellTimer = timer:new(30000)
function ShadowKnight:checkSpellSet()
    if not common.clearToBuff() or mq.TLO.Me.Moving() or self:isEnabled('BYOS') then return end
    local spellSet = self.OPTS.SPELLSET.value
    if state.spellSetLoaded ~= spellSet or checkSpellTimer:timerExpired() then
        if spellSet == 'standard' then
            abilities.swapSpell(self.spells.tap1, 1)
            abilities.swapSpell(self.spells.tap2, 2)
            abilities.swapSpell(self.spells.largetap, 3)
            abilities.swapSpell(self.spells.composite, 4, composite_names)
            abilities.swapSpell(self.spells.spear, 5)
            abilities.swapSpell(self.spells.terror, 6)
            abilities.swapSpell(self.spells.aeterror, 7)
            abilities.swapSpell(self.spells.dottap, 8)
            abilities.swapSpell(self.spells.challenge, 9)
            abilities.swapSpell(self.spells.bitetap, 10)
            abilities.swapSpell(self.spells.stance, 11)
            abilities.swapSpell(self.spells.skin, 12)
            abilities.swapSpell(self.spells.acdebuff, 13)
            state.spellSetLoaded = spellSet
        elseif spellSet == 'dps' then
            abilities.swapSpell(self.spells.tap1, 1)
            abilities.swapSpell(self.spells.tap2, 2)
            abilities.swapSpell(self.spells.largetap, 3)
            abilities.swapSpell(self.spells.composite, 4, composite_names)
            abilities.swapSpell(self.spells.spear, 5)
            abilities.swapSpell(self.spells.corruption, 6)
            abilities.swapSpell(self.spells.poison, 7)
            abilities.swapSpell(self.spells.dottap, 8)
            abilities.swapSpell(self.spells.disease, 9)
            abilities.swapSpell(self.spells.bitetap, 10)
            abilities.swapSpell(self.spells.stance, 11)
            abilities.swapSpell(self.spells.skin, 12)
            abilities.swapSpell(self.spells.acdebuff, 13)
            state.spellSetLoaded = spellSet
        end
        checkSpellTimer:reset()
    end
end

--[[self.pullCustom = function()
    if self.spells.challenge then
        movement.stop()
        for _=1,3 do
            if mq.TLO.Me.SpellReady(self.spells.terror.Name)() then
                mq.cmdf('/cast %s', self.spells.terror.Name)
                break
            end
            mq.delay(100)
        end
    end
end]]

return ShadowKnight