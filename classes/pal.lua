local mq = require('mq')
local class = require('classes.classbase')
local config = require('interface.configuration')
local conditions = require('routines.conditions')
local tank = require('routines.tank')
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
    self.classOrder = {'assist', 'heal', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest'}
    self.spellRotations = {standard={},custom={}}
    self:initBase('PAL')

    self:initClassOptions()
    self:loadSettings()
    self:initSpellLines()
    self:initSpellRotations()
    self:initAbilities()
    self:addCommonAbilities()

    state.swapGem = 10
    state.nukeTimer = timer:new(500)
    self.useCommonListProcessor = true
end

function Paladin:initClassOptions()
    self:addOption('USEATTRACTION', 'Use Divine Call', true, nil, 'Toggle use of Divine Call AA', 'checkbox', nil, 'UseAttraction', 'bool')
    self:addOption('USEPROJECTION', 'Use Projection', true, nil, 'Toggle use of Projection AA', 'checkbox', nil, 'UseProjection', 'bool')
    self:addOption('USENUKES', 'Use Nukes', true, nil, 'Toggle use of nuke spells', 'checkbox', nil, 'UseNukes', 'bool')
end

Paladin.SpellLines = {
    {
        Group='groupheal',
        NumToPick=3,
        Spells={'Wave of Penitence', --[[emu cutoff]] 'Wave of Piety', 'Wave of Trushar', 'Wave of Marr'},
        Options={Gems=state.emu and {1,2,3} or {7}, heal=true, group=true},
    },
    { -- Normal no damage stun line
        Group='stun1',
        Spells={'Force of Marr', --[[emu cutoff]] 'Force of Piety', 'Force of Akilae', 'Force of Akera', 'Stun', 'Desist', 'Cease'},
        Options={Gem=4},
    },
    { -- Stun line with damage
        Group='stun2',
        Spells={'Earnest Force', --[[emu cutoff]] 'Serene Command', 'Quellious\' Word of Serenity', 'Force', 'Holy Might'},
        Options={Gem=5},
    },
    { -- Second no damage stun line
        Group='stun3',
        Spells={'Lesson of Repentance', --[[emu cutoff]] 'Ancient: Force of Jeron', 'Ancient: Force of Chaos'},
        Options={Gem=6},
    },
    {
        Group='stunaoenuke',
        Spells={'The Silent Command'},
        Options={Gem=7, opt='USEAOE', threshold=2}
    },
    {
        Group='stunaoe',
        Spells={'Stun Command'},
        Options={Gem=8}
    },
    {
        Group='twincast',
        Spells={'Glorious Exoneration', --[[emu cutoff]] 'Justice of Marr'},
        Options={Gem=9},
    },
    -- {
    --     Group='healtot',
    --     Spells={'Burst of Daybreak'},
    --     Options={Gem=5},
    -- },
    -- {
    --     Group='ohshitheal',
    --     Spells={'Penitence'},
    --     Options={Gem=6, panic=true},
    -- },
    -- {
    --     Group='grouphealfast',
    --     Spells={'Aurora of Daybreak'},
    --     Options={Gem=8, threshold=2, heal=true, group=true},
    -- },
    -- {
    --     Group='challenge',
    --     Spells={'Confrontation for Honor'},
    --     Options={Gem=9, condition=conditions.lowAggro},
    -- },
    -- {
    --     Group='totshield',
    --     Spells={'Protective Devotion'},
    --     Options={Gem=10},
    -- },
    {
        Group='growth',
        Spells={'Stubborn Stance', --[[emu cutoff]] 'Ward of Tunare'},
        Options={Gem=11, combatbuff=true},
    },
    {
        Group='procbuff',
        Spells={'Preservation of Marr', 'Instrument of Nife', --[[emu cutoff]] 'Pious Fury'},
        Options={Gem=12, combatbuff=true},
    },
    {-- same stats as cleric aego
        Group='aego',
        Spells={'Oauthbound Keeper', --[[emu cutoff]] 'Daring', 'Center', 'Courage'},
        Options={},
    },
    {
        Group='brells',
        Spells={'Brell\'s Unbreakable Palisade', 'Brell\'s Tenacious Barrier', 'Brell\'s Blessed Barrier', 'Brell\'s Blessed Bastion', 'Brell\'s Stalwart Bulwark', 'Brell\'s Steadfast Bulwark', 'Brell\'s Adamantine Armor', 'Brell\'s Tellurian Rampart', 'Brell\'s Loamy Ward', 'Brell\'s Earthen Aegis', 'Brell\'s Stony Guard', 'Brell\'s Vibrant Barricade', 'Brell\'s Brawny Bulwark', 'Brell\'s Stalwart Shield', 'Brell\'s Mountainous Barrier', 'Brell\'s Steadfast Aegis'},
        Options={alias='BRELLS', selfbuff=true},--Gem=function(lvl) return lvl <= 70 and 12 or nil end, 
    },
    {
        Group='selfarmor',
        Spells={'Armor of Implacable Faith', --[[emu cutoff]] 'Armor of the Champion'},
        Options={selfbuff=true},
    },
    -- {
    --     Group='heal',
    --     Spells={'Greater Healing', 'Healing', 'Light Healing', 'Minor Healing', 'Salve'},
    --     Options={Gem=function(lvl) return lvl <= 60 and 2 or nil end, heal=true, tank=true, regular=true}
    -- },
    {
        Group='curepoison',
        Spells={'Counteract Poison', 'Cure Poison'},
        Options={cure=true, Poison=true}
    },
    {
        Group='curedisease',
        Spells={'Counteract Disease', 'Cure Disease'},
        Options={cure=true, Disease=true}
    },
    {
        Group='Yaulp',
        Spells={'Yaulp II', 'Yaulp'},
        Options={Gem=function(lvl) return lvl <= 60 and 6 or nil end}
    },
    {
        Group='undeadnuke',
        Spells={'Last Rites', 'Expulse Undead', 'Ward Undead'},
        Options={Gem=function(lvl) return lvl <= 60 and 3 or nil end, opt='USENUKES', condition=function() return mq.TLO.Target.Body() == 'Undead' end}
    },
    {
        Group='rgc',
        Spells={'Remove Lesser Curse', 'Remove Minor Curse'},
        Options={cure=true, Curse=true}
    },
    {
        Group='dispel',
        Spells={'Cancel Magic'},
        Options={debuff=true}
    },
    {
        Group='aura',
        Spells={'Blessed Aura',},
        Options={aura=true, aurabuff=true,}
    },
}
Paladin.compositeNames = {['Ecliptic Force']=true, ['Composite Force']=true, ['Dissident Force']=true, ['Dichotomic Force']=true}
Paladin.allDPSSpellGroups = {'stun1', 'stun2', 'stun3', 'stunaoenuke', 'stunaoe', 'twincast'}

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
    self.spellRotations.standard = {}
    table.insert(self.spellRotations.standard, self.spells.challenge)
    table.insert(self.spellRotations.standard, self.spells.twincast)
    table.insert(self.spellRotations.standard, self.spells.healtot)
    table.insert(self.spellRotations.standard, self.spells.stun1)
    table.insert(self.spellRotations.standard, self.spells.stun2)
    table.insert(self.spellRotations.standard, self.spells.stun3)
    table.insert(self.spellRotations.standard, self.spells.undeadnuke)
    table.insert(self.spellRotations.standard, self.spells.stunaoenuke)
    table.insert(self.spellRotations.standard, self.spells.stunaoe)
end

Paladin.Abilities = {
    {
        Type='AA',
        Name='Gift of Resurrection',
        Options={rez=true}
    },
    {
        Type='Item',
        Name='Staff of Forbidden Rites',
        Options={key='rezStick'}
    },

    {
        Type='Skill',
        Name='Taunt',
        Options={tanking=true, aggro=true, condition=conditions.lowAggroInMelee}
    },
    {
        Type='Disc',
        Group='defy',
        Names={'Defy'},
        Options={tanking=true}
    },
    { -- agro + interrupt, mash
        Type='AA',
        Name='Force of Disruption',
        Options={tanking=true, condition=function() return mq.TLO.Me.PctAggro() < 100 end}
    },
    { -- agro generating swarm pet
        Type='AA',
        Name='Projection of Piety',
        Options={tanking=true, opt='USEPROJECTION'}
    },
    { -- pbae stun/agro, 5m cd, timer 30
        Type='AA',
        Name='Beacon of the Righteous',
        Options={alias='BEACON', aetank=true, threshold=3, condition=function() return mq.TLO.Me.PctAggro() < 100 end}
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
    { -- DD + agro + interrupt, mash
        Type='AA',
        Name='Disruptive Persecution',
        Options={dps=true, condition=function() return mq.TLO.Me.PctAggro() >= 100 or not config.get('MAINTANK') end}
    },

    -- Burn
    { -- 35% dmg absorb, 15m cd, 1m duration
        Type='Disc',
        Group='mantle',
        Names={'Exalted Mantle'},
        Options={first=true}
    },
    { -- 20% dmg absorb, stun attackers, 7.5m cd, 2m duration
        Type='Disc',
        Group='armor',
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
        Options={first=true, emu=false}
    },
    { -- inc incoming instant duration heal effectiveness for group, 10m cd, timer 40
        Type='AA',
        Name='Fundament: First Spire of Holiness',
        Options={first=true, emu=true}
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
    {
        Type='Disc',
        Group='hallowforge',
        Names={'Hallowforge Discipline'},
        Options={first=true}
    },
    {
        Type='Item',
        Name='Nightbane, Sword of the Ancients',
        Options={first=true}
    },
    {
        Type='Item',
        Name='Nightbane, Sword of the Valiant',
        Options={first=true}
    },
    {
        Type='Item',
        Name='Redemption',
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
        Options={heal=true, grouppanic=true}
    },
    {
        Type='AA',
        Name='Lay on Hands',
        Options={heal=true, panic=true}
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
    -- { -- reduce groups agro generation, 5m cd, timer 16
    --     Type='AA',
    --     Name='Marr\'s Salvation',
    --     Options={selfbuff=true}
    -- },
    { -- self buffs
        Type='AA',
        Name='Yaulp',
        Options={combatbuff=true}
    },
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

    if tank.isTank() then
        -- hate's attraction
        if self.attraction and self:isEnabled(self.attraction.opt) and mobhp and mobhp > 95 then
            self.attraction:use()
        end
    end
end

return Paladin