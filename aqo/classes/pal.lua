local mq = require('mq')
local class = require('classes.classbase')
local conditions = require('routines.conditions')
local sharedabilities = require('utils.sharedabilities')
local timer = require('libaqo.timer')
local common = require('common')
local mode = require('mode')
local state = require('state')

local Paladin = class:new()

--[[
    https://forums.daybreakgames.com/eq/index.php?threads/paladin-pro-tips.239287/ worst guide ever
    Burst
    Grief
    Burst
    Splash
    BV
    -adjustable / undead nuke-
    Valiant deflection
    Crush
    -adjustable / heal proc-
    -adjustable / harmonious-
    Preservation
    Staunch

    -- Defensives
    Skalber Mantle
    Armor of Ardency
    Holy Guardian Discipline

    -- Aggro Spam
    Crush of the Darkened Sea
    Crush of Povar
    Valiant Defense
    Ardent Force
    Force of Disruption

    Radiant Cure
    Splash of Purification

    Dicho - debatable usefulness?
    Aurora
    Wave

    Brilliant Vindication

    Stance
]]
function Paladin:init()
    self.classOrder = {'tank', 'assist', 'heal', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest'}
    self.spellRotations = {standard={},custom={}}
    self:initBase('PAL')

    self:initClassOptions()
    self:loadSettings()
    self:initSpellLines()
    self:initSpellRotations()
    self:initHeals()
    self:initTankAbilities()
    self:initDPSAbilities()
    self:initBuffs()
    self:initCures()
    self:addCommonAbilities()

    -- self:addSpell('brells', {'Brell's Brawny Bulwark'})
    -- table.insert(self.selfBuffs, self.spells.brells)
    -- self:addRequestAlias(self.spells.brells, 'BRELLS')

    self.rezStick = common.getItem('Staff of Forbidden Rites')
    self.rezAbility = common.getAA('Gift of Resurrection', {}) -- 90% rez

    state.nukeTimer = timer:new(2000)
    self.useCommonListProcessor = true
end

function Paladin:initClassOptions()
    self:addOption('USEATTRACTION', 'Use Divine Call', true, nil, 'Toggle use of Divine Call AA', 'checkbox', nil, 'UseAttraction', 'bool')
    self:addOption('USEPROJECTION', 'Use Projection', true, nil, 'Toggle use of Projection AA', 'checkbox', nil, 'UseProjection', 'bool')
end

Paladin.SpellLines = {
    {
        Group='stun1',
        Spells={'Force of Marr'},
        Options={Gem=1},
    },
    {
        Group='stun2',
        Spells={'Earnest Force'},
        Options={Gem=2},
    },
    {
        Group='stun3',
        Spells={'Lesson of Repentance'},
        Options={Gem=3},
    },
    {
        Group='twincast',
        Spells={'Glorious Exoneration'},
        Options={Gem=4},
    },
    {
        Group='healtot',
        Spells={'Burst of Daybreak'},
        Options={Gem=5},
    },
    {
        Group='ohshitheal',
        Spells={'Penitence'},
        Options={Gem=6, panic=true},
    },
    {
        Group='groupheal',
        Spells={'Wave of Penitence'},
        Options={Gem=7, threshold=2, group=true},
    },
    {
        Group='grouphealfast',
        Spells={'Aurora of Daybreak'},
        Options={Gem=8, threshold=2, group=true},
    },
    {
        Group='challenge',
        Spells={'Confrontation for Honor'},
        Options={Gem=9, condition=conditions.lowAggro},
    },
    {
        Group='totshield',
        Spells={'Protective Devotion'},
        Options={Gem=10},
    },
    {
        Group='growth',
        Spells={'Stubborn Stance'},
        Options={Gem=11},
    },
    {
        Group='procbuff',
        Spells={'Preservation of Marr'},
        Options={Gem=12},
    },
    {-- same stats as cleric aego
        Group='aego',
        Spells={'Oauthbound Keeper'},
        Options={},
    },
    {
        Group='brells',
        Spells={'Brell\'s Tellurian Rampart'},
        Options={},
    },
    {
        Group='selfarmor',
        Spells={'Armor of Implacable Faith'},
        Options={},
    },
}
Paladin.compositeNames = {['Ecliptic Force']=true, ['Composite Force']=true, ['Dissident Force']=true, ['Dichotomic Force']=true}
Paladin.allDPSSpellGroups = {}

--[[ AA's to sort out
common.getAA('Bestow Divine Aura', {}) -- 
common.getAA('Divine Aura', {}) -- 

common.getAA('Shackles of Tunare', {}) -- root
common.getAA('Speed of the Savior', {}) -- 18s movement speed buff, 15m cd, timer 13

common.getAA('Balefire Burst', {}) -- fade, 10m cd, timer 15
common.getAA('Cloak of Light', {}) -- self IVU
common.getAA('Group Perfected Invisibility to Undead', {}) -- group IVU
common.getAA('Leap of Faith', {}) -- standard leap ability
]]

function Paladin:initSpellRotations()
    self:initBYOSCustom()
    table.insert(self.spellRotations.standard, self.spells.challenge)
    table.insert(self.spellRotations.standard, self.spells.twincast)
    table.insert(self.spellRotations, self.spells.healtot)
    table.insert(self.spellRotations.standard, self.spells.stun1)
    table.insert(self.spellRotations.standard, self.spells.stun2)
    table.insert(self.spellRotations.standard, self.spells.stun3)
end

function Paladin:initTankAbilities()
    table.insert(self.tankAbilities, sharedabilities.getTaunt())
    table.insert(self.tankAbilities, common.getBestDisc({'Defy'}))
    table.insert(self.tankAbilities, common.getAA('Disruptive Persecution', {})) -- DD + agro + interrupt, mash
    table.insert(self.tankAbilities, common.getAA('Force of Disruption', {})) -- agro + interrupt, mash
    table.insert(self.tankAbilities, common.getAA('Projection of Piety', {opt='USEPROJECTION'})) -- agro generating swarm pet

    table.insert(self.AETankAbilities, common.getAA('Beacon of the Righteous', {threshold=3})) -- pbae stun/agro, 5m cd, timer 30
    table.insert(self.AETankAbilities, common.getAA('Hallowed Lodestar', {threshold=3})) -- pbae stun/agro, 5m cd, timer 36

    table.insert(self.tankBurnAbilities, common.getAA('Ageless Enmity', {aggro=true, condition=conditions.lowAggroInMelee})) -- 

    self.attraction = common.getAA('Divine Call', {opt='USEATTRACTION'}) -- agro + pull mob in, 2m cd, timer 14

    -- Sort out these ones
    -- common.getAA('Heroic Leap', {}) -- leap to target + ae agro, 2m cd, timer 9
    -- common.getAA('Divine Stun', {}) -- kb + stun, mash
    -- common.getAA('Halt the Dead', {}) -- undead snare
    -- common.getAA('Vanquish the Fallen', {}) -- large undead nuke, 3m cd, timer 43
    -- common.getAA('Shield Flash', {}) -- 6 second deflection, 4m cd
end

function Paladin:initDPSAbilities()
    table.insert(self.DPSAbilities, sharedabilities.getBash())
end

function Paladin:initBurns()
    table.insert(self.tankBurnAbilities, common.getBestDisc({'Exalted Mantle'})) -- 35% dmg absorb, 15m cd, 1m duration
    table.insert(self.tankBurnAbilities, common.getBestDisc({'Armor of Courage'})) -- 20% dmg absorb, stun attackers, 7.5m cd, 2m duration

    common.getAA('Armor of the Inquisitor', {}) -- inc incoming instant heal effectiveness for 1m, 15m cd, timer 10
    common.getAA('Group Armor of the Inquisitor', {}) -- inc incoming instant heal effectiveness for 2min to group, 20m cd, timer 8
    common.getAA('Hand of Tunare', {}) -- twincast heals, 15m cd, timer 35
    common.getAA('Inquisitor\'s Judgement', {}) -- dps burn, dd + agro reducer proc, 12m cd, timer 52
    common.getAA('Spire of Chivalry', {}) -- inc incoming instant duration heal effectiveness for group, 10m cd, timer 40
    common.getAA('Thunder of Karana', {}) -- inc dmg of spells and crit chance, 9m cd, timer 17
    common.getAA('Valorous Rage', {}) -- inc base melee dmg and crits, 20m cd, timer 75
end

function Paladin:initHeals()
    common.getAA('Gift of Life', {}) -- large aoe heal + hot, 24m cd, timer 38
    common.getAA('Hand of Piety', {}) -- instant group heal, 24m cd, timer 4
    common.getAA('Lay on Hands', {}) -- 
    common.getAA('Marr\'s Gift', {}) -- large self hp/mana/end heal, 10m cd, timer 32

    --table.insert(self.healAbilities, self.spells.ohshitheal)
    table.insert(self.healAbilities, self.spells.groupheal)
    table.insert(self.healAbilities, self.spells.grouphealfast)
end

function Paladin:initCures()
    common.getAA('Blessing of Purification', {}) -- cure target any detrimental, 14m cd, timer 6
    common.getAA('Purification', {}) -- remove detrimentals from self, 14m cd, timer 6
end

function Paladin:initBuffs()
    table.insert(self.selfBuffs, self.spells.selfarmor)
    table.insert(self.selfBuffs, self.spells.brells)
    table.insert(self.selfBuffs, self.spells.procbuff)
    table.insert(self.combatBuffs, self.spells.growth)

    common.getAA('Divine Protector\'s Unity', {}) -- self buffs
    common.getAA('Marr\'s Salvation', {}) -- reduce groups agro generation, 5m cd, timer 16
end

function Paladin:mashClass()
    local target = mq.TLO.Target
    local mobhp = target.PctHPs()

    if mode.currentMode:isTankMode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
        -- hate's attraction
        if self.attraction and self:isEnabled(self.attraction.opt) and mobhp and mobhp > 95 then
            self.attraction:use()
        end
    end
end

return Paladin