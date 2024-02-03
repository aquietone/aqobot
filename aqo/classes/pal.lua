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
    self:initAbilities()
    self:addCommonAbilities()

    self.rezStick = common.getItem('Staff of Forbidden Rites')
    self.rezAbility = self:addAA('Gift of Resurrection', {}) -- 90% rez

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
        Options={Gem=7, threshold=2, heal=true, group=true},
    },
    {
        Group='grouphealfast',
        Spells={'Aurora of Daybreak'},
        Options={Gem=8, threshold=2, heal=true, group=true},
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
        Options={Gem=11, combatbuff=true},
    },
    {
        Group='procbuff',
        Spells={'Preservation of Marr'},
        Options={Gem=12, selfbuff=true},
    },
    {-- same stats as cleric aego
        Group='aego',
        Spells={'Oauthbound Keeper'},
        Options={},
    },
    {
        Group='brells',
        Spells={'Brell\'s Tellurian Rampart'},
        Options={alias='BRELLS', selfbuff=true},
    },
    {
        Group='selfarmor',
        Spells={'Armor of Implacable Faith'},
        Options={selfbuff=true},
    },
}
Paladin.compositeNames = {['Ecliptic Force']=true, ['Composite Force']=true, ['Dissident Force']=true, ['Dichotomic Force']=true}
Paladin.allDPSSpellGroups = {}

--[[ AA's to sort out
self:addAA('Bestow Divine Aura', {}) -- 
self:addAA('Divine Aura', {}) -- 

self:addAA('Shackles of Tunare', {}) -- root
self:addAA('Speed of the Savior', {}) -- 18s movement speed buff, 15m cd, timer 13

self:addAA('Balefire Burst', {}) -- fade, 10m cd, timer 15
self:addAA('Cloak of Light', {}) -- self IVU
self:addAA('Group Perfected Invisibility to Undead', {}) -- group IVU
self:addAA('Leap of Faith', {}) -- standard leap ability
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

Paladin.Abilities = {
    {
        Type='Skill',
        Name='Taunt',
        Options={tanking=true, aggro=true, condition=conditions.lowAggroInMelee}
    },
    {
        Type='Disc',
        Group='',
        Names={'Defy'},
        Options={tanking=true}
    },
    { -- DD + agro + interrupt, mash
        Type='AA',
        Name='Disruptive Persecution',
        Options={tanking=true}
    },
    { -- agro + interrupt, mash
        Type='AA',
        Name='Force of Disruption',
        Options={tanking=true}
    },
    { -- agro generating swarm pet
        Type='AA',
        Name='Projection of Piety',
        Options={tanking=true, opt='USEPROJECTION'}
    },
    { -- pbae stun/agro, 5m cd, timer 30
        Type='AA',
        Name='Beacon of the Righteous',
        Options={aetank=true, threshold=3}
    },
    { -- pbae stun/agro, 5m cd, timer 36
        Type='AA',
        Name='Hallowed Lodestar',
        Options={aetank=true, threshold=3}
    },
    {
        Type='AA',
        Name='Ageless Enmity',
        Options={tankburn=true, aggro=true, condition=conditions.lowAggroInMelee}
    },
    { -- agro + pull mob in, 2m cd, timer 14
        Type='AA',
        Name='Divine Call',
        Options={tanking=true, opt='USEATTRACTION', key='attraction'}
    },

    -- DPS
    {
        Type='Skill',
        Name='Bash',
        Options={dps=true, condition=conditions.useBash}
    },

    -- Burn
    { -- 35% dmg absorb, 15m cd, 1m duration
        Type='Disc',
        Group='',
        Names={'Exalted Mantle'},
        Options={first=true}
    },
    { -- 20% dmg absorb, stun attackers, 7.5m cd, 2m duration
        Type='Disc',
        Group='',
        Names={'Armor of Courage'},
        Options={first=true}
    },
    { -- inc incoming instant heal effectiveness for 1m, 15m cd, timer 10
        Type='AA',
        Name='Armor of the Inquisitor',
        Options={first=true}
    },
    { -- inc incoming instant heal effectiveness for 2min to group, 20m cd, timer 8
        Type='AA',
        Name='Group Armor of the Inquisitor',
        Options={first=true}
    },
    { -- twincast heals, 15m cd, timer 35
        Type='AA',
        Name='Hand of Tunare',
        Options={first=true}
    },
    { -- dps burn, dd + agro reducer proc, 12m cd, timer 52
        Type='AA',
        Name='Inquisitor\'s Judgement',
        Options={first=true}
    },
    { -- inc incoming instant duration heal effectiveness for group, 10m cd, timer 40
        Type='AA',
        Name='Spire of Chivalry',
        Options={first=true}
    },
    { -- inc dmg of spells and crit chance, 9m cd, timer 17
        Type='AA',
        Name='Thunder of Karana',
        Options={first=true}
    },
    { -- inc base melee dmg and crits, 20m cd, timer 75
        Type='AA',
        Name='Valorous Rage',
        Options={first=true}
    },

    -- Heals
    { -- large aoe heal + hot, 24m cd, timer 38
        Type='AA',
        Name='Gift of Life',
        Options={heal=true}
    },
    { -- instant group heal, 24m cd, timer 4
        Type='AA',
        Name='Hand of Piety',
        Options={heal=true}
    },
    {
        Type='AA',
        Name='Lay on Hands',
        Options={heal=true}
    },
    { -- large self hp/mana/end heal, 10m cd, timer 32
        Type='AA',
        Name='Marr\'s Gift',
        Options={heal=true}
    },

    -- Cures
    { -- cure target any detrimental, 14m cd, timer 6
        Type='AA',
        Name='Blessing of Purification',
        Options={cure=true, all=true}
    },
    { -- remove detrimentals from self, 14m cd, timer 6
        Type='AA',
        Name='Purification',
        Options={cure=true, all=true}
    },

    -- Buffs
    { -- self buffs
        Type='AA',
        Name='Divine Protector\'s Unity',
        Options={selfbuff=true}
    },
    { -- reduce groups agro generation, 5m cd, timer 16
        Type='AA',
        Name='Marr\'s Salvation',
        Options={selfbuff=true}
    }
}
-- Sort out these ones
-- self:addAA('Heroic Leap', {}) -- leap to target + ae agro, 2m cd, timer 9
-- self:addAA('Divine Stun', {}) -- kb + stun, mash
-- self:addAA('Halt the Dead', {}) -- undead snare
-- self:addAA('Vanquish the Fallen', {}) -- large undead nuke, 3m cd, timer 43
-- self:addAA('Shield Flash', {}) -- 6 second deflection, 4m cd

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