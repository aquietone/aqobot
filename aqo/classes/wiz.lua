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
    self:initBase('wiz')

    self:loadSettings()
    self:initSpellLines()
    self:initSpellRotations()
    self:initDPSAbilities()
    self:initBurns()
    self:initBuffs()
    self:addCommonAbilities()
    table.insert(self.recoverAbilities, common.getAA('Harvest of Druzzil'))
end

function Wizard:initSpellLines()
    self:addSpell('nuke1', {'Ether Flame', 'Draught of Ro', 'Pillar of Fire'})
    self:addSpell('nuke2', {'Ancient: Spear of Gelaqua', 'Fire Spiral of Al\'Kabor'})
    self:addSpell('Swarm', {'Solist\'s Frozen Sword'})
    self:addSpell('rain', {'Gelid Rains'})
    self:addSpell('aeTrap', {'Fire Rune'})
    self:addSpell('ae1', {'Circle of Thunder'})
    self:addSpell('ae2', {'Jyll\'s Static Pulse'})
    self:addSpell('ae3', {'Jyll\'s Zephyr of Ice'})
    self:addSpell('ae4', {'Jyll\'s Wave of Heat'})
end

function Wizard:initSpellRotations()
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