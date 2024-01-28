local class = require('classes.classbase')
local conditions = require('routines.conditions')
local sharedabilities = require('utils.sharedabilities')
local timer = require('libaqo.timer')
local common = require('common')
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
    self.classOrder = {'assist', 'cast', 'heal', 'mash', 'burn', 'recover', 'buff', 'rest'}
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
    self:addCommonAbilities()

    -- self:addSpell('brells', {'Brell's Brawny Bulwark'})
    -- table.insert(self.selfBuffs, self.spells.brells)
    -- self:addRequestAlias(self.spells.brells, 'BRELLS')

    self.rezStick = common.getItem('Staff of Forbidden Rites')

    state.nukeTimer = timer:new(2000)
    self.useCommonListProcessor = true
end

function Paladin:initClassOptions()

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
        Options={Gem=7, group=true},
    },
    {
        Group='grouphealfast',
        Spells={'Aurora of Daybreak'},
        Options={Gem=8, group=true},
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

function Paladin:initSpellRotations()
    self:initBYOSCustom()
    table.insert(self.spellRotations.standard, self.spells.challenge)
    table.insert(self.spellRotations.standard, self.spells.twincast)
    table.insert(self.spellRotations.standard, self.spells.stun1)
    table.insert(self.spellRotations.standard, self.spells.stun2)
    table.insert(self.spellRotations.standard, self.spells.stun3)
    table.insert(self.spellRotations, self.spells.healtot)
end

function Paladin:initTankAbilities()
    table.insert(self.tankAbilities, sharedabilities.getTaunt())
    table.insert(self.DPSAbilities, sharedabilities.getBash())
end

function Paladin:initDPSAbilities()
end

function Paladin:initHeals()
    --table.insert(self.healAbilities, self.spells.ohshitheal)
    table.insert(self.healAbilities, self.spells.groupheal)
    table.insert(self.healAbilities, self.spells.grouphealfast)
end

function Paladin:initBuffs()
    table.insert(self.selfBuffs, self.spells.selfarmor)
    table.insert(self.selfBuffs, self.spells.brells)
    table.insert(self.selfBuffs, self.spells.procbuff)
    table.insert(self.combatBuffs, self.spells.growth)
end

return Paladin