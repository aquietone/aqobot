local mq = require 'mq'
local class = require('classes.classbase')
local conditions = require('routines.conditions')
local tank = require('routines.tank')
local timer = require('libaqo.timer')
local movement = require('utils.movement')
local abilities = require('ability')
local common = require('common')
local mode = require('mode')
local state = require('state')

local ShadowKnight = class:new()

--[[
    https://forums.eqfreelance.net/index.php?topic=16303.0
    
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
    self.spellRotations = {standard={},dps={},custom={}}
    self:initBase('SHD')

    mq.cmd('/squelch /stick mod -2')
    mq.cmd('/squelch /stick set delaystrafe on')

    self:initClassOptions()
    self:loadSettings()
    self:initSpellLines()
    self:initSpellRotations()
    self:initAbilities()
    self:addCommonAbilities()

    self.pullSpell = self.spells.terror

    self.useCommonListProcessor = true
end

function ShadowKnight:initClassOptions()
    self:addOption('USEATTRACTION', 'Use Hate\'s Attraction', true, nil, 'Toggle use of Hates Attraction AA', 'checkbox', nil, 'UseAttraction', 'bool')
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

ShadowKnight.SpellLines = {
    {-- Regular lifetap. Slot 1
        Group='tap1',
        Spells={'Touch of Flariton', 'Touch of Txiki', 'Touch of Draygun', 'Touch of Innoruuk', --[[emu cutoff]] 'Lifedraw', 'Lifespike', 'Lifetap'},
        Options={Gem=1, condition=function() return mq.TLO.Me.PctHPs() < 85 end}
    },--, 'Drain Soul', 'Lifedraw'})
    {-- Temp buff (Gift of) lifetap. Slot 2
        Group='tap2',
        Spells={'Touch of Mortimus', 'Touch of Namdrows', 'Touch of the Devourer', 'Touch of Volatis'},
        Options={Gem=2}
    },
    {-- large lifetap. Slot 3
        Group='largetap',
        Spells={'Dire Rebuke', 'Dire Censure'},
        Options={Gem=3, condition=function() return mq.TLO.Me.PctHPs() < 85 end}
    },
    {-- big lifetap. Slot 4
        Group='composite',
        Spells={'Ecliptic Fang', 'Composite Fang', 'Dissident Fang', 'Dichotomic Fang'},
        Options={Gem=4}
    },
    {-- poison nuke. Slot 5
        Group='spear',
        Spells={'Spear of Lazam', 'Spear of Bloodwretch', 'Spear of Muram', 'Miasmic Spear', 'Spear of Disease'},
        Options={Gem=5}
    },
    {-- ST increase hate by 1. Slot 6
        Group='terror',
        Spells={'Terror of Tarantis', 'Terror of Ander', 'Terror of Discord', 'Terror of Terris',  'Terror of Death', 'Terror of Darkness'},
        Options={Gem=function() return ShadowKnight:get('SPELLSET') == 'standard' and 6 or nil end}
    },
    -- DPS spellset. poison dot. Slot 6
    {
        Group='poison',
        Spells={'Blood of Shoru', 'Blood of Tearc', 'Blood of Inruku', 'Blood of Pain', --[[emu cutoff]] 'Heat Blood'},
        Options={Gem=function(lvl) return (ShadowKnight:get('SPELLSET') == 'dps' and 6) or (lvl <= 60 and 4) or nil end}
    },
    {-- ST increase hate by 1. Slot 7
        Group='aeterror',
        Spells={'Animus', 'Antipathy', 'Dread Gaze'},
        Options={aetank=true, Gem=function() return ShadowKnight:get('SPELLSET') == 'standard' and 7 or nil end, threshold=2, condition=function() return mode.currentMode:isTankMode() and mq.TLO.Me.PctHPs() > 70 and conditions.mobsMissingAggro() end}
    },
    {-- AE lifetap + aggro. Slot 7
        Group='aetap',
        Spells={'Insidious Repudiation', 'Insidious Renunciation'},
        Options={aetank=true, opt='USEINSIDIOUS', Gem=function() return ShadowKnight:get('SPELLSET') == 'standard' and 7 or nil end, threshold=2}
    },
    {-- DPS spellset. disease dot. Slot 7
        Group='disease',
        Spells={'Plague of the Fleawalker', 'Plague of Fleshrot', --[[emu cutoff]] 'Disease Cloud'},
        Options={Gem=function(lvl) return (ShadowKnight:get('SPELLSET') == 'dps' and 7) or (lvl <= 60 and 3) or nil end}
    },
    {-- lifetap dot. Slot 8
        Group='dottap',
        Spells={'Bond of Tatalros', 'Bond of Bynn', 'Bond of Inruku'},
        Options={Gem=function(lvl) return lvl <= 70 and 3 or 8 end}
    },
    {-- main hate spell. Slot 9
        Group='challenge',
        Spells={'Petition for Power', 'Parlay for Power', 'Terror of Thule', 'Aura of Hate', 'Scream of Pain', 'Scream of Hate'},
        Options={tanking=true, Gem=function(lvl) return (ShadowKnight:get('SPELLSET') == 'standard' and 9) or (lvl <= 60 and 2) or nil end, condition=function() return mode.currentMode:isTankMode() and mq.TLO.Me.PctHPs() > 70 end}
    },
    {-- DPS spellset. corruption dot. Slot 9
        Group='corruption',
        Spells={'Vitriolic Blight', 'Unscrupulous Blight'},
        Options={Gem=function() return ShadowKnight:get('SPELLSET') == 'dps' and 9 or nil end}
    },
    {-- ac debuff. Slot 10
        Group='acdebuff',
        Spells={'Torrent of Desolation', 'Torrent of Melancholy', 'Theft of Agony', --[[emu cutoff]] 'Shroud of Hate', 'Despair', 'Siphon Strength'},
        Options={opt='USETORRENT', Gem=function(lvl) return (lvl <= 60 and 7) or 10 end}
    },
    {-- temp HP buff, 2.5min. Slot 11
        Group='stance',
        Spells={'Unwavering Stance', 'Adamant Stance', 'Vampiric Embrace'},
        Options={Gem=function(lvl) return lvl <= 60 and 6 or 11 end}
    },
    {-- Xenacious' Skin proc, 5min buff. Slot 12
        Group='skin',
        Spells={'Krizad\'s Skin', 'Xenacious\' Skin', 'Decrepit Skin', 'Vampiric Embrace'},
        Options={Gem=function(lvl) return lvl <= 70 and 8 or 12 end, selfbuff=true}
    },
    {-- lifetap with hp/mana recourse. Slot 13
        Group='bitetap',
        Spells={'Charka\'s Bite', 'Cruor\'s Bite', 'Ancient: Bite of Muram', 'Zevfeer\'s Bite', 'Inruku\'s Bite'},
        Options={Gem=function(lvl) return (lvl <= 70 and 4) or (ShadowKnight:isEnabled('USETORRENT') and 13) or 10 end}
    },
    {-- Slot 13
        Group='tap3',
        Spells={'Touch of Drendar'},
        Options={Gem=13}
    },

    {Group='alliance', Spells={'Bloodletting Conjunction', 'Bloodletting Coalition', 'Bloodletting Covenant', 'Bloodletting Alliance'}}, -- alliance
    --['']={'Oppressor\'s Audacity', 'Usurper\'s Audacity'}), -- increase hate by a lot, does this get used?

    {Group='acdis', Spells={'Dire Squelch', 'Dire Seizure'}}, -- disease + ac dot
    --['']={'Odious Bargain', 'Despicable Bargain'}), -- ae hate nuke, does this get used?
    -- Short Term Buffs
    {Group='disruption', Spells={'Confluent Disruption', 'Scream of Death'}}, -- lifetap proc on heal
    --['']={'Impertinent Influence'}), -- ac buff, 20% dmg mitigation, lifetap proc, is this upgraded by xetheg's carapace? stacks?
    -- Pet
    {Group='pet', Spells={'Minion of Fandrel', 'Minion of Itzal', 'Son of Decay', 'Invoke Death', 'Cackling Bones', 'Animate Dead', 'Restless Bones', 'Convoke Shadow', 'Bone Walk', 'Leering Corpse'}, Options={Gem=function(lvl) return lvl <= 60 and 8 end}}, -- pet
    {Group='pethaste', Spells={'Gift of Fandrel', 'Gift of Itzal', 'Rune of Decay', 'Augmentation of Death', 'Augment Death', 'Strengthen Death'}, Options={petbuff=true}}, -- pet haste
    -- Unity Buffs
    {Group='shroud', Spells={'Shroud of Rimeclaw', 'Shroud of Zelinstein', 'Shroud of Discord', 'Black Shroud'}, Options={Gem=function(lvl) return lvl <= 70 and 11 or nil end, swap=false, selfbuff=true}}, -- Shroud of Zelinstein Strike proc
    {Group='bezaproc', Spells={'Mental Wretchedness', 'Mental Anguish', 'Mental Horror'}, Options={opt='USEBEZA', selfbuff=true}}, -- Mental Anguish Strike proc
    {Group='aziaproc', Spells={'Mortimus\' Horror', 'Brightfield\'s Horror'}, Options={opt='USEAZIA'}}, -- Brightfield's Horror Strike proc
    {Group='ds', Spells={'Goblin Skin', 'Tekuel Skin'}}, -- large damage shield self buff
    {Group='lich', Spells={'Kar\'s Covenant', 'Aten Ha Ra\'s Covenant'}, Options={selfbuff=true}}, -- lich mana regen
    {Group='drape', Spells={'Drape of the Ankexfen', 'Drape of the Akheva', 'Cloak of Discord', 'Cloak of Luclin'}, Options={selfbuff=true}}, -- self buff hp, ac, ds
    {Group='atkbuff', Spells={'Call of Blight', 'Penumbral Call', 'Dark Temptation', 'Grim Aura'}}, -- atk buff, hp drain on self
    {Group='voice', Spells={'Voice of Innoruuk'}, Options={Gem=function(lvl) return lvl <= 70 and 12 or nil end, opt='USEVOICEOFTHULE', selfbuff=true}},
    --['']=common.get_best_spell({'Remorseless Demeanor'})
    {Group='snare', Spells={'Engulfing Darkness', 'Clinging Darkness'}, Options={Gem=function(lvl) return lvl <= 60 and 2 end, opt='USESNARE', debuff=true}},
    {Group='undeadnuke', Spells={'Ward Undead'}, Options={opt='USENUKES'}},
}

ShadowKnight.compositeNames = {['Ecliptic Fang']=true,['Composite Fang']=true,['Dissident Fang']=true,['Dichotomic Fang']=true}
ShadowKnight.allDPSSpellGroups = {'tap1', 'tap2', 'largetap', 'composite', 'spear', 'terror', 'poison', 'aeterror', 'aetap', 'disease', 'dottap', 'challenge',
    'corruption', 'acdebuff', 'bitetap', 'tap3', 'alliance', 'acdis'}

function ShadowKnight:initSpellRotations()
    self:initBYOSCustom()
    self.spellRotations.standard = {}
    self.spellRotations.dps = {}
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
    table.insert(self.spellRotations.standard, self.spells.acdebuff)
    table.insert(self.spellRotations.standard, self.spells.tap3)

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
    table.insert(self.spellRotations.dps, self.spells.acdebuff)
    table.insert(self.spellRotations.dps, self.spells.tap3)
end

ShadowKnight.Abilities = {
    { -- 9min CD, giant lifetap
        Type='AA',
        Name='Leech Touch',
        Options={key='leechtouch'}
    },
    {
        Type='AA',
        Name='Summon Companion',
        Options={key='summoncompanion'}
    },
    {
        Type='Item',
        Name='Innoruuk\'s Dark Blessing',
        Options={key='epic'}
    },
    {
        Type='Item',
        Name='Innoruuk\'s Voice',
        Options={key='epic'}
    },

    { -- 4min CD, short deflection
        Type='AA',
        Name='Shield Flash',
        Options={key='flash'}
    },
    { -- 15min CD, 35% melee dmg mitigation, heal on fade
        Type='Disc',
        Group='mantle',
        Names={'Geomimus Mantle', 'Fyrthek Mantle'},
        Options={}
    },
    { -- 7m30s CD, ac buff, 20% dmg mitigation, lifetap proc
        Type='Disc',
        Group='carapace',
        Names={'Kanghammer\'s Carapace', 'Xetheg\'s Carapace'},
        Options={}
    },
    { -- 12min CD, 36% mitigation, large damage debuff to self, lifetap proc
        Type='Disc',
        Group='guardian',
        Names={'Corrupted Guardian Discipline'},
        Options={}
    },
    {
        Type='Disc',
        Group='deflection',
        Names={'Deflection Discipline'},
        Options={opt='USEDEFLECTION'}
    },
    { -- yank mob to you
        Type='AA',
        Name='Hate\'s Attraction',
        Options={key='attraction', opt='USEATTRACTION'}
    },

    -- Tanking
    {
        Type='Skill',
        Name='Taunt',
        Options={tanking=true, aggro=true, condition=conditions.lowAggroInMelee}
    },
    { -- mash, 90% melee/spell dmg mitigation, 2 ticks or 85k dmg
        Type='Disc',
        Group='repudiate',
        Names={'Repudiate'},
        Options={tanking=true}
    },
    { -- aggro swarm pet
        Type='AA',
        Name='Projection of Doom',
        Options={tanking=true, opt='USEPROJECTION'}
    },
    -- common.getBestDisc({'Gird'}) -- absorb melee/spell dmg, short cd mash ability

    -- AE Tank
    { -- 45 sec cd
        Type='AA',
        Name='Explosion of Spite',
        Options={tanking=true, threshold=2, condition=conditions.aboveMobThreshold}
    },
    { -- 45 sec cd
        Type='AA',
        Name='Explosion of Hatred',
        Options={tanking=true, threshold=4, condition=conditions.aboveMobThreshold}
    },
    -- { -- large frontal cone ae aggro
    --     Type='AA',
    --     Name='Stream of Hatred',
    --     Options={aetank=true}
    -- },

    -- Tank burns
    { -- instant aggro
        Type='Disc',
        Group='acrimony',
        Names={'Unconditional Acrimony', 'Unrelenting Acrimony'},
        Options={tankburn=true, condition=conditions.withinMeleeDistance}
    },
    { -- big taunt
        Type='AA',
        Name='Ageless Enmity',
        Options={tankburn=true, aggro=true, condition=conditions.lowAggroInMelee}
    },
    { -- large agro, lifetap, blind, mana/end tap
        Type='AA',
        Name='Veil of Darkness',
        Options={tankburn=true}
    },
    { -- 20min CD, 75% melee dmg absorb
        Type='AA',
        Name='Reaver\'s Bargain',
        Options={tankburn=true}
    },
    {
        Type='AA',
        Name='Fundament: Third Spire of the Reaver',
        Options={tankburn=true}
    },

    -- DPS
    {
        Type='Skill',
        Name='Bash',
        Options={dps=true, condition=conditions.useBash}
    },
    { -- 3x 2hs attack + heal
        Type='Disc',
        Group='reflexive',
        Names={'Reflexive Resentment'},
        Options={dps=true, condition=conditions.withinMaxDistance}
    },
    { -- 1min CD, nuke + group heal
        Type='AA',
        Name='Vicious Bite of Chaos',
        Options={dps=true}
    },
    { -- 7m30s CD, dmg,crit,parry,avoidance buff
        Type='AA',
        Name='Spire of the Reavers',
        Options={dps=true}
    },

    {
        Type='AA',
        Name='Fundament: Second Spire of the Reaver',
        Options={first=true}
    },
    { -- 2hs attack
        Type='Disc',
        Group='2hblade',
        Names={'Incapacitating Blade', 'Grisly Blade'},
        Options={first=true, condition=conditions.withinMaxDistance}
    },
    { -- 3 strikes
        Type='Disc',
        Group='tripleblade',
        Names={'Incarnadine Blade', 'Sanguine Blade'},
        Options={first=true, condition=conditions.withinMaxDistance}
    },
    { -- 10min CD, twincast
        Type='AA',
        Name='Gift of the Quick Spear',
        Options={first=true}
    },
    { -- 10min CD, dmg buff on 1 target
        Type='AA',
        Name='T`Vyl\'s Resolve',
        Options={first=true}
    },
    --table.insert(self.burnAbilities, self:addAA('Harm Touch')) -- 20min CD, giant nuke + dot
    --table.insert(self.burnAbilities, self:addAA('Leech Touch')) -- 9min CD, giant lifetap
    { -- 18min CD, nuke + mana/end tap
        Type='AA',
        Name='Thought Leech',
        Options={first=true}
    },
    { -- 15min CD, large DS
        Type='AA',
        Name='Scourge Skin',
        Options={first=true}
    },
    { -- 10min CD, swarm pet
        Type='AA',
        Name='Chattering Bones',
        Options={first=true, opt='USESWARM'}
    },
    { -- 12min CD, dot dmg burn
        Type='AA',
        Name='Visage of Decay',
        Options={first=true}
    },
    --table.insert(self.burnAbilities, self:addAA('Visage of Death')) -- 12min CD, melee dmg burn

    -- Buffs
    { -- emu
        Type='AA',
        Name='Touch of the Cursed',
        Options={selfbuff=true}
    },
    { -- dark lord's unity azia X -- shroud of zelinstein, brightfield's horror, drape of the akheva, remorseless demeanor, tekuel skin, aten ha ra's covenant, penumbral call
        Type='AA',
        Name='Dark Lord\'s Unity (Azia)',
        Options={selfbuff=true}
    },
    { -- dark lord's unity beza X -- shroud of zelinstein, mental anguish, drape of the akheva, remorseless demeanor, tekuel skin, aten ha ra's covenant, penumbral call
        Type='AA',
        Name='Dark Lord\'s Unity (Beza)',
        Options={selfbuff=true, opt='USEBEZA'}
    },
    { -- aggro mod buff
        Type='AA',
        Name='Voice of Thule',
        Options={selfbuff=true, opt='USEVOICEOFTHULE'}
    },

    {
        Type='Disc',
        Group='soulshield',
        Names={'Soul Shield', 'Ichor Guard'},
        Options={},
    },
    {
        Type='Disc',
        Group='rampart',
        Names={'Rampart Discipline'},
        Options={},
    },
}

function ShadowKnight:mashClass()
    local target = mq.TLO.Target
    local mobhp = target.PctHPs()

    if tank.isTank() then
        -- hate's attraction
        if self.attraction and self:isEnabled(self.attraction.opt) and mobhp and mobhp > 95 then
            self.attraction:use()
        end
    end
end

function ShadowKnight:burnClass()
    if tank.isTank() then
        if self.mantle then self.mantle:use() end
        if self.carapace then self.carapace:use() end
        if self.guardian then self.guardian:use() end
    end

    if self:isEnabled('USEEPIC') and self.epic then self.epic:use() end
end

function ShadowKnight:ohshit()
    if mq.TLO.Me.PctHPs() < 35 and mq.TLO.Me.CombatState() == 'COMBAT' then
        if tank.isTank() then
            if self.flash and mq.TLO.Me.AltAbilityReady(self.flash.Name)() then
                self.flash:use()
            elseif self.deflection and self:isEnabled(self.deflection.opt)  then
                self.deflection:use()
            end
            if self.leechtouch then self.leechtouch:use() end
        end
    end
end

function ShadowKnight:pullCustom()
    if self.spells.challenge and (mq.TLO.Target.Distance3D() or 300) < 175 then
        movement.stop()
        for _=1,3 do
            if mq.TLO.Me.SpellReady(self.spells.terror.Name)() then
                mq.cmdf('/cast %s', self.spells.terror.Name)
                break
            end
            mq.delay(100)
        end
    end
end

return ShadowKnight