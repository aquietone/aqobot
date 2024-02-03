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
    self.spellRotations = {standard={}, ae={},custom={}}
    self:initBase('WIZ')

    self:loadSettings()
    self:initSpellLines()
    self:initSpellRotations()
    self:initAbilities()
    self:addCommonAbilities()
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

Wizard.compositeNames = {['Ecliptic Fire']=true,['Composite Fire']=true,['Dissident Fire']=true,['Dichotomic Fire']=true,}
Wizard.allDPSSpellGroups = {'nuke1', 'nuke2', 'Swarm', 'rain', 'aeTrap', 'ae1', 'ae2', 'ae3', 'ae4'}

Wizard.Abilities = {
    -- DPS
    {
        Type='AA',
        Name='Force of Will',
        Options={dps=true}
    },

    -- Burns
    {
        Type='AA',
        Name='Fury of Ro',
        Options={first=true}
    },
    {
        Type='AA',
        Name='Prolonged Destruction',
        Options={first=true}
    },
    {
        Type='AA',
        Name='Fundament: Second Spire of Arcanum',
        Options={first=true}
    },
    {
        Type='AA',
        Name='Mana Blaze',
        Options={first=true}
    },

    -- Buffs
    {
        Type='AA',
        Name='Pyromancy',
        Options={selfbuff=true}
    },
    {
        Type='AA',
        Name='Kerafyrm\'s Prismatic Familiar',
        Options={selfbuff=true}
    },

    -- Recover
    {
        Type='AA',
        Name='Harvest of Druzzil',
        Options={recover=true}
    }
}
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

return Wizard