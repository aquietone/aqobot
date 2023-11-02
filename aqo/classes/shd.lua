--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local timer = require('utils.timer')
local abilities = require('ability')
local common = require('common')
local mode = require('mode')
local state = require('state')

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
function class.init(_aqo)
    class.classOrder = {'assist', 'cast', 'ae', 'mash', 'burn', 'recover', 'rest', 'buff', 'managepet'}
    class.spellRotations = {standard={},dps={}}
    class.initBase(_aqo, 'shd')

    mq.cmd('/squelch /stick mod -2')
    mq.cmd('/squelch /stick set delaystrafe on')

    class.initClassOptions()
    class.loadSettings()
    class.initSpellLines(_aqo)
    class.initSpellConditions(_aqo)
    class.initSpellRotations(_aqo)
    class.initTankAbilities(_aqo)
    class.initDPSAbilities(_aqo)
    class.initBurns(_aqo)
    class.initBuffs(_aqo)

    class.leechtouch = common.getAA('Leech Touch') -- 9min CD, giant lifetap

    class.epic = common.getItem('Innoruuk\'s Dark Blessing') or common.getItem('Innoruuk\'s Voice')
    class.summonCompanion = common.getAA('Summon Companion')
    class.pullSpell = class.spells.terror
end

function class.initClassOptions()
    class.addOption('USEHATESATTRACTION', 'Use Hate\'s Attraction', true, nil, 'Toggle use of Hates Attraction AA', 'checkbox', nil, 'UseHatesAttraction', 'bool')
    class.addOption('USEPROJECTION', 'Use Projection', true, nil, 'Toggle use of Projection AA', 'checkbox', nil, 'UseProjection', 'bool')
    class.addOption('USEAZIA', 'Use Unity Azia', true, nil, 'Toggle use of Unity (Azia) AA', 'checkbox', 'USEBEZA', 'UseAzia', 'bool')
    class.addOption('USEBEZA', 'Use Unity Beza', false, nil, 'Toggle use of Unity (Beza) AA', 'checkbox', 'USEAZIA', 'UseBeza', 'bool')
    class.addOption('USEDISRUPTION', 'Use Disruption', true, nil, 'Toggle use of Disruption', 'checkbox', nil, 'UseDisruption', 'bool')
    class.addOption('USEINSIDIOUS', 'Use Insidious', false, nil, 'Toggle use of Insidious', 'checkbox', nil, 'UseInsidious', 'bool')
    class.addOption('USELIFETAP', 'Use Lifetap', true, nil, 'Toggle use of lifetap spells', 'checkbox', nil, 'UseLifetap', 'bool')
    class.addOption('USEVOICEOFTHULE', 'Use Voice of Thule', false, nil, 'Toggle use of Voice of Thule buff', 'checkbox', nil, 'UseVoiceOfThule', 'bool')
    class.addOption('USETORRENT', 'Use Torrent', true, nil, 'Toggle use of torrent', 'checkbox', nil, 'UseTorrent', 'bool')
    class.addOption('USESWARM', 'Use Snare', true, nil, 'Toggle use of swarm pets', 'checkbox', nil, 'UseSwarm', 'bool')
    class.addOption('USEDEFLECTION', 'Use Deflection', false, nil, 'Toggle use of deflection discipline', 'checkbox', nil, 'UseDeflection', 'bool')
    class.addOption('DONTCAST', 'Don\'t Cast', false, nil, 'Don\'t cast spells in combat', 'checkbox', nil, 'DontCast', 'bool')
    class.addOption('USEEPIC', 'Use Epic', true, nil, 'Use epic in burns', 'checkbox', nil, 'UseEpic', 'bool')
end

function class.initSpellLines(_aqo)
    class.addSpell('composite', {'Composite Fang'}) -- big lifetap
    class.addSpell('alliance', {'Bloodletting Coalition'}) -- alliance
    -- Aggro
    class.addSpell('challenge', {'Petition for Power', 'Parlay for Power', 'Terror of Thule', 'Aura of Hate'}) -- main hate spell
    class.addSpell('terror', {'Terror of Tarantis', 'Terror of Ander', 'Terror of Discord', 'Terror of Terris',  'Terror of Death', 'Terror of Darkness'}) -- ST increase hate by 1
    class.addSpell('aeterror', {'Animus', 'Antipathy', 'Dread Gaze'}, {threshold=2}) -- ST increase hate by 1
    --['']={'Oppressor\'s Audacity', 'Usurper\'s Audacity'}), -- increase hate by a lot, does this get used?
    -- Lifetaps
    class.addSpell('largetap', {'Dire Rebuke', 'Dire Censure'}) -- large lifetap
    class.addSpell('tap1', {'Touch of Flariton', 'Touch of Txiki', 'Touch of Draygun', 'Touch of Innoruuk'})--, 'Drain Soul', 'Lifedraw'}) -- lifetap
    class.addSpell('tap2', {'Touch of Mortimus', 'Touch of Namdrows', 'Touch of the Devourer', 'Touch of Volatis'}) -- lifetap + temp hp buff Gift of Namdrows
    class.addSpell('dottap', {'Bond of Tatalros', 'Bond of Bynn', 'Bond of Inruku'}) -- lifetap dot
    class.addSpell('bitetap', {'Charka\'s Bite', 'Cruor\'s Bite', 'Ancient: Bite of Muram', 'Zevfeer\'s Bite'}) -- lifetap with hp/mana recourse
    -- AE lifetap + aggro
    class.addSpell('aetap', {'Insidious Repudiation', 'Insidious Renunciation'}) -- large hate + lifetap
    -- DPS
    class.addSpell('spear', {'Spear of Lazam', 'Spear of Bloodwretch', 'Spear of Muram', 'Miasmic Spear', 'Spear of Disease'}) -- poison nuke
    class.addSpell('poison', {'Blood of Shoru', 'Blood of Tearc', 'Blood of Inruku', 'Blood of Pain'}) -- poison dot
    class.addSpell('disease', {'Plague of the Fleawalker', 'Plague of Fleshrot'}) -- disease dot
    class.addSpell('corruption', {'Vitriolic Blight', 'Unscrupulous Blight'}) -- corruption dot
    class.addSpell('acdis', {'Dire Squelch', 'Dire Seizure'}) -- disease + ac dot
    class.addSpell('acdebuff', {'Torrent of Desolation', 'Torrent of Melancholy', 'Theft of Agony'}) -- ac debuff
    --['']={'Odious Bargain', 'Despicable Bargain'}), -- ae hate nuke, does this get used?
    -- Short Term Buffs
    class.addSpell('stance', {'Unwavering Stance', 'Adamant Stance', 'Vampiric Embrace'}) -- temp HP buff, 2.5min
    class.addSpell('skin', {'Krizad\'s Skin', 'Xenacious\' Skin', 'Decrepit Skin'}) -- Xenacious' Skin proc, 5min buff
    class.addSpell('disruption', {'Confluent Disruption', 'Scream of Death'}) -- lifetap proc on heal
    --['']={'Impertinent Influence'}), -- ac buff, 20% dmg mitigation, lifetap proc, is this upgraded by xetheg's carapace? stacks?
    -- Pet
    class.addSpell('pet', {'Minion of Fandrel', 'Minion of Itzal', 'Son of Decay', 'Invoke Death', 'Cackling Bones', 'Animate Dead'}) -- pet
    class.addSpell('pethaste', {'Gift of Fandrel', 'Gift of Itzal', 'Rune of Decay', 'Augmentation of Death', 'Augment Death'}) -- pet haste
    -- Unity Buffs
    class.addSpell('shroud', {'Shroud of Rimeclaw', 'Shroud of Zelinstein', 'Shroud of Discord', 'Black Shroud'}, {swap=false}) -- Shroud of Zelinstein Strike proc
    class.addSpell('bezaproc', {'Mental Wretchedness', 'Mental Anguish', 'Mental Horror'}, {opt='USEBEZA'}) -- Mental Anguish Strike proc
    class.addSpell('aziaproc', {'Mortimus\' Horror', 'Brightfield\'s Horror'}, {opt='USEAZIA'}) -- Brightfield's Horror Strike proc
    class.addSpell('ds', {'Goblin Skin', 'Tekuel Skin'}) -- large damage shield self buff
    class.addSpell('lich', {'Kar\'s Covenant', 'Aten Ha Ra\'s Covenant'}) -- lich mana regen
    class.addSpell('drape', {'Drape of the Ankexfen', 'Drape of the Akheva', 'Cloak of Discord', 'Cloak of Luclin'}) -- self buff hp, ac, ds
    class.addSpell('atkbuff', {'Call of Blight', 'Penumbral Call'}) -- atk buff, hp drain on self
    --['']=common.get_best_spell({'Remorseless Demeanor'})
end

function class.initSpellConditions(_aqo)
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

    if class.spells.aeterror then class.spells.aeterror.condition = function() return mode.currentMode:isTankMode() and state.loop.PctHPs > 70 and mobsMissingAggro() end end
    local aggroCondition = function() return mode.currentMode:isTankMode() and state.loop.PctHPs > 70 end
    if class.spells.challenge then class.spells.challenge.condition = aggroCondition end
    --if class.spells.terror then class.spells.terror.condition = aggroCondition end
    local lifetapCondition = function() return state.loop.PctHPs < 85 end
    if class.spells.largetap then class.spells.largetap.condition = lifetapCondition end
    if class.spells.tap1 then class.spells.tap1.condition = lifetapCondition end
end

function class.initSpellRotations(_aqo)
    table.insert(class.spellRotations.standard, class.spells.aeterror)
    if not state.emu then table.insert(class.spellRotations.standard, class.spells.challenge) end
    table.insert(class.spellRotations.standard, class.spells.terror)
    table.insert(class.spellRotations.standard, class.spells.bitetap)
    table.insert(class.spellRotations.standard, class.spells.spear)
    table.insert(class.spellRotations.standard, class.spells.composite)
    table.insert(class.spellRotations.standard, class.spells.largetap)
    table.insert(class.spellRotations.standard, class.spells.tap1)
    table.insert(class.spellRotations.standard, class.spells.tap2)
    table.insert(class.spellRotations.standard, class.spells.dottap)
    --table.insert(class.spellRotations.standard, class.spells.stance)
    --table.insert(class.spellRotations.standard, class.spells.skin)
    table.insert(class.spellRotations.standard, class.spells.acdebuff)

    local dps = {}
    table.insert(class.spellRotations.dps, class.spells.tap1)
    table.insert(class.spellRotations.dps, class.spells.tap2)
    table.insert(class.spellRotations.dps, class.spells.largetap)
    table.insert(class.spellRotations.dps, class.spells.composite)
    table.insert(class.spellRotations.dps, class.spells.spear)
    table.insert(class.spellRotations.dps, class.spells.corruption)
    table.insert(class.spellRotations.dps, class.spells.poison)
    table.insert(class.spellRotations.dps, class.spells.dottap)
    table.insert(class.spellRotations.dps, class.spells.disease)
    table.insert(class.spellRotations.dps, class.spells.bitetap)
    table.insert(class.spellRotations.dps, class.spells.stance)
    table.insert(class.spellRotations.dps, class.spells.skin)
    table.insert(class.spellRotations.dps, class.spells.acdebuff)
end

function class.initTankAbilities(_aqo)
    -- TANK
    -- defensives
    -- common.getBestDisc({'Gird'}) -- absorb melee/spell dmg, short cd mash ability
    class.flash = common.getAA('Shield Flash') -- 4min CD, short deflection
    class.mantle = common.getBestDisc({'Geomimus Mantle', 'Fyrthek Mantle'}) -- 15min CD, 35% melee dmg mitigation, heal on fade
    class.carapace = common.getBestDisc({'Kanghammer\'s Carapace', 'Xetheg\'s Carapace'}) -- 7m30s CD, ac buff, 20% dmg mitigation, lifetap proc
    class.guardian = common.getBestDisc({'Corrupted Guardian Discipline'}) -- 12min CD, 36% mitigation, large damage debuff to self, lifetap proc
    class.deflection = common.getBestDisc({'Deflection Discipline'}, {opt='USEDEFLECTION'})

    table.insert(class.tankAbilities, common.getSkill('Taunt', {aggro=true}))
    table.insert(class.tankAbilities, class.spells.challenge)
    table.insert(class.tankAbilities, class.spells.terror)
    table.insert(class.tankAbilities, common.getBestDisc({'Repudiate'})) -- mash, 90% melee/spell dmg mitigation, 2 ticks or 85k dmg
    table.insert(class.tankAbilities, common.getAA('Projection of Doom', {opt='USEPROJECTION'})) -- aggro swarm pet

    class.attraction = common.getAA('Hate\'s Attraction', {opt='USEHATESATTRACTION'}) -- aggro swarm pet

    -- mash AE aggro
    table.insert(class.AETankAbilities, class.spells.aeterror)
    table.insert(class.AETankAbilities, common.getAA('Explosion of Spite', {threshold=2})) -- 45sec CD
    table.insert(class.AETankAbilities, common.getAA('Explosion of Hatred', {threshold=4})) -- 45sec CD
    --table.insert(mashAEAggroAAs4, common.getAA('Stream of Hatred')) -- large frontal cone ae aggro

    table.insert(class.tankBurnAbilities, common.getBestDisc({'Unconditional Acrimony', 'Unrelenting Acrimony'})) -- instant aggro
    table.insert(class.tankBurnAbilities, common.getAA('Ageless Enmity')) -- big taunt
    table.insert(class.tankBurnAbilities, common.getAA('Veil of Darkness')) -- large agro, lifetap, blind, mana/end tap
    table.insert(class.tankBurnAbilities, common.getAA('Reaver\'s Bargain')) -- 20min CD, 75% melee dmg absorb
end

function class.initDPSAbilities(_aqo)
    -- DPS
    table.insert(class.DPSAbilities, common.getSkill('Bash'))
    table.insert(class.DPSAbilities, common.getBestDisc({'Reflexive Resentment'})) -- 3x 2hs attack + heal
    table.insert(class.DPSAbilities, common.getAA('Vicious Bite of Chaos')) -- 1min CD, nuke + group heal
    table.insert(class.DPSAbilities, common.getAA('Spire of the Reavers')) -- 7m30s CD, dmg,crit,parry,avoidance buff
end

function class.initBurns(_aqo)
    table.insert(class.burnAbilities, common.getBestDisc({'Incapacitating Blade', 'Grisly Blade'})) -- 2hs attack
    table.insert(class.burnAbilities, common.getBestDisc({'ncarnadine Blade', 'Sanguine Blade'})) -- 3 strikes
    table.insert(class.burnAbilities, common.getAA('Gift of the Quick Spear')) -- 10min CD, twincast
    table.insert(class.burnAbilities, common.getAA('T`Vyl\'s Resolve')) -- 10min CD, dmg buff on 1 target
    --table.insert(class.burnAbilities, common.getAA('Harm Touch')) -- 20min CD, giant nuke + dot
    --table.insert(class.burnAbilities, common.getAA('Leech Touch')) -- 9min CD, giant lifetap
    table.insert(class.burnAbilities, common.getAA('Thought Leech')) -- 18min CD, nuke + mana/end tap
    table.insert(class.burnAbilities, common.getAA('Scourge Skin')) -- 15min CD, large DS
    table.insert(class.burnAbilities, common.getAA('Chattering Bones', {opt='USESWARM'})) -- 10min CD, swarm pet
    --table.insert(class.burnAbilities, common.getAA('Visage of Death')) -- 12min CD, melee dmg burn
    table.insert(class.burnAbilities, common.getAA('Visage of Decay')) -- 12min CD, dot dmg burn
end

function class.initHeals(_aqo)

end

function class.initBuffs(_aqo)
-- Buffs
    -- dark lord's unity azia X -- shroud of zelinstein, brightfield's horror, drape of the akheva, remorseless demeanor, tekuel skin, aten ha ra's covenant, penumbral call
    local buffazia = common.getAA('Dark Lord\'s Unity (Azia)')
    -- dark lord's unity beza X -- shroud of zelinstein, mental anguish, drape of the akheva, remorseless demeanor, tekuel skin, aten ha ra's covenant, penumbral call
    local buffbeza = common.getAA('Dark Lord\'s Unity (Beza)', {opt='USEBEZA'})
    local voice = common.getAA('Voice of Thule', {opt='USEVOICEOFTHULE'}) -- aggro mod buff

    if state.emu then
        table.insert(class.selfBuffs, class.spells.drape)
        table.insert(class.selfBuffs, class.spells.bezaproc)
        table.insert(class.selfBuffs, class.spells.skin)
        table.insert(class.selfBuffs, class.spells.shroud)
        table.insert(class.selfBuffs, common.getAA('Touch of the Cursed'))
        class.addSpell('voice', {'Voice of Innoruuk'}, {opt='USEVOICEOFTHULE'})
        table.insert(class.selfBuffs, class.spells.voice)
    else
        table.insert(class.selfBuffs, buffazia)
        table.insert(class.selfBuffs, buffbeza)
        table.insert(class.selfBuffs, voice)
    end
    table.insert(class.petBuffs, class.spells.pethaste)
end

function class.mashClass()
    local target = mq.TLO.Target
    local mobhp = target.PctHPs()

    if mode.currentMode:isTankMode() or mq.TLO.Group.MainTank.ID() == state.loop.ID then
        -- hate's attraction
        if class.attraction and class.isEnabled(class.attraction.opt) and mobhp and mobhp > 95 then
            class.attraction:use()
        end
    end
end

function class.burnClass()
    if mode.currentMode:isTankMode() or mq.TLO.Group.MainTank.ID() == state.loop.ID then
        if class.mantle then class.mantle:use() end
        if class.carapace then class.carapace:use() end
        if class.guardian then class.guardian:use() end
    end

    if class.isEnabled('USEEPIC') and class.epic then class.epic:use() end
end

function class.ohshit()
    if state.loop.PctHPs < 35 and mq.TLO.Me.CombatState() == 'COMBAT' then
        if mode.currentMode:isTankMode() or mq.TLO.Group.MainTank.ID() == state.loop.ID then
            if class.flash and mq.TLO.Me.AltAbilityReady(class.flash.Name)() then
                class.flash:use()
            elseif class.deflection and class.isEnabled(class.deflection.opt)  then
                class.deflection:use()
            end
            if class.leechtouch then class.leechtouch:use() end
        end
    end
end

local composite_names = {['Composite Fang']=true,['Dissident Fang']=true,['Dichotomic Fang']=true}
local checkSpellTimer = timer:new(30000)
function class.checkSpellSet()
    if not common.clearToBuff() or mq.TLO.Me.Moving() or class.isEnabled('BYOS') then return end
    local spellSet = class.OPTS.SPELLSET.value
    if state.spellSetLoaded ~= spellSet or checkSpellTimer:timerExpired() then
        if spellSet == 'standard' then
            abilities.swapSpell(class.spells.tap1, 1)
            abilities.swapSpell(class.spells.tap2, 2)
            abilities.swapSpell(class.spells.largetap, 3)
            abilities.swapSpell(class.spells.composite, 4, composite_names)
            abilities.swapSpell(class.spells.spear, 5)
            abilities.swapSpell(class.spells.terror, 6)
            abilities.swapSpell(class.spells.aeterror, 7)
            abilities.swapSpell(class.spells.dottap, 8)
            abilities.swapSpell(class.spells.challenge, 9)
            abilities.swapSpell(class.spells.bitetap, 10)
            abilities.swapSpell(class.spells.stance, 11)
            abilities.swapSpell(class.spells.skin, 12)
            abilities.swapSpell(class.spells.acdebuff, 13)
            state.spellSetLoaded = spellSet
        elseif spellSet == 'dps' then
            abilities.swapSpell(class.spells.tap1, 1)
            abilities.swapSpell(class.spells.tap2, 2)
            abilities.swapSpell(class.spells.largetap, 3)
            abilities.swapSpell(class.spells.composite, 4, composite_names)
            abilities.swapSpell(class.spells.spear, 5)
            abilities.swapSpell(class.spells.corruption, 6)
            abilities.swapSpell(class.spells.poison, 7)
            abilities.swapSpell(class.spells.dottap, 8)
            abilities.swapSpell(class.spells.disease, 9)
            abilities.swapSpell(class.spells.bitetap, 10)
            abilities.swapSpell(class.spells.stance, 11)
            abilities.swapSpell(class.spells.skin, 12)
            abilities.swapSpell(class.spells.acdebuff, 13)
            state.spellSetLoaded = spellSet
        end
        checkSpellTimer:reset()
    end
end

--[[class.pullCustom = function()
    if class.spells.challenge then
        movement.stop()
        for _=1,3 do
            if mq.TLO.Me.SpellReady(class.spells.terror.Name)() then
                mq.cmdf('/cast %s', class.spells.terror.Name)
                break
            end
            mq.delay(100)
        end
    end
end]]

return class