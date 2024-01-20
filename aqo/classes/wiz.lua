--- @type Mq
local mq = require('mq')
local class = require('classes.classbase')
local common = require('common')

local Wizard = class:new()

--[[
    https://forums.eqfreelance.net/index.php?topic=16645.0
]]
function Wizard:init()
    self.classOrder = {'assist', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest', 'rez'}
    self.spellRotations = {standard={}, ae={}}
    self:initBase('WIZ')

    self:loadSettings()
    self:initSpellLines()
    self:initSpellRotations()
    self:initDPSAbilities()
    self:initBurns()
    self:initBuffs()
    self:addCommonAbilities()
    table.insert(self.recoverAbilities, common.getAA('Harvest of Druzzil'))
end

Wizard.SpellLines = {
    {Group='nuke1', Spells={'Ether Flame', 'Draught of Ro', 'Pillar of Fire'}},
    {Group='nuke2', Spells={'Ancient: Spear of Gelaqua', 'Fire Spiral of Al\'Kabor'}},
    {Group='Swarm', Spells={'Solist\'s Frozen Sword'}},
    {Group='rain', Spells={'Gelid Rains'}},
    {Group='aeTrap', Spells={'Fire Rune'}},
    {Group='ae1', Spells={'Circle of Thunder'}},
    {Group='ae2', Spells={'Jyll\'s Static Pulse'}},
    {Group='ae3', Spells={'Jyll\'s Zephyr of Ice'}},
    {Group='ae4', Spells={'Jyll\'s Wave of Heat'}},
}

Wizard.allDPSSpellGroups = {'nuke1', 'nuke2', 'Swarm', 'rain', 'aeTrap', 'ae1', 'ae2', 'ae3', 'ae4'}

function Wizard:initSpellRotations()
    self:initBYOSCustom()
    table.insert(self.spellRotations.standard, self.spells.swarm)
    table.insert(self.spellRotations.standard, self.spells.nuke1)
    table.insert(self.spellRotations.standard, self.spells.nuke2)
    table.insert(self.spellRotations.ae, self.spells.aeTrap)
    table.insert(self.spellRotations.ae, self.spells.ae1)
    table.insert(self.spellRotations.ae, self.spells.ae2)
    table.insert(self.spellRotations.ae, self.spells.ae3)
    table.insert(self.spellRotations.ae, self.spells.ae4)
end

function Wizard:initDPSAbilities()
    table.insert(self.DPSAbilities, common.getAA('Force of Will'))
end

function Wizard:initBurns()
    table.insert(self.burnAbilities, common.getAA('Fury of Ro'))
    table.insert(self.burnAbilities, common.getAA('Prolonged Destruction'))
    table.insert(self.burnAbilities, common.getAA('Fundament: Second Spire of Arcanum'))
    table.insert(self.burnAbilities, common.getAA('Mana Blaze'))
end

function Wizard:initBuffs()
    table.insert(self.selfBuffs, common.getAA('Pyromancy'))
    table.insert(self.selfBuffs, common.getAA('Kerafyrm\'s Prismatic Familiar'))
end

return Wizard