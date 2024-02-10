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

    self:initClassOptions()
    self:loadSettings()
    self:initSpellLines()
    self:initSpellRotations()
    self:initAbilities()
    self:addCommonAbilities()
end

function Wizard:initClassOptions()
    self:addOption('USEDISPEL', 'Use Dispel', true, nil, 'Dispel mobs with Eradicate Magic AA', 'checkbox', nil, 'UseDispel', 'bool')
end

Wizard.SpellLines = {
    {Group='largefire', Spells={'Ether Flame', 'Corona Flare', 'White Fire', 'Conflagration', 'Fire Bolt'}},
    {Group='smallfire', Spells={'Chaos Flame', 'Draught of Ro', 'Draught of Fire', 'Inferno Shock', 'Flame Shock', 'Shock of Fire'}},
    {Group='smallice', Spells={'Ancient: Spear of Gelaqua', 'Black Ice', 'Claw of Frost', 'Ice Spear of Solist', 'Ice Shock', 'Frost Shock', 'Shock of Ice', 'Blast of Cold'}},
    {Group='lightning', Spells={'Shock of Lightning'}},
    {Group='stun', Spells={'Telekemara'}},
    {Group='Swarm', Spells={'Solist\'s Frozen Sword'}},
    {Group='firerain', Spells={'Firestorm'}},
    {Group='icerain', Spells={'Gelid Rains', 'Icestrike'}},
    {Group='aeTrap', Spells={'Fire Rune'}},
    {Group='ae1', Spells={'Circle of Thunder', 'Project Lightning'}},
    {Group='ae2', Spells={'Jyll\'s Static Pulse'}},
    {Group='ae3', Spells={'Jyll\'s Zephyr of Ice', 'Frost Spiral of Al\'Kabor', 'Column of Frost', 'Numbing Cold'}},
    {Group='ae4', Spells={'Jyll\'s Wave of Heat', 'Fire Spiral of Al\'Kabor', 'Pillar of Fire', 'Fingers of Fire'}},
    {Group='hpbuff', Spells={'Shielding', 'Lesser Shielding', 'Minor Shielding'}, Options={selfbuff=true}},
    {Group='ds', Spells={'O`Keil\'s Embers', 'O`Keil\'s Radiation'}, Options={singlebuff=true, classes={}}},
    {Group='dispel', Spells={'Cancel Magic'}, Options={debuff=true, dispel=true, opt='USEDISPEL'}},

    {Group='lurefire', Spells={'Firebane', 'Lure of Ro', 'Lure of Flame', 'Enticement of Flame'}},
    {Group='lureice', Spells={'Lure of Ice'}},
}

Wizard.compositeNames = {['Ecliptic Fire']=true,['Composite Fire']=true,['Dissident Fire']=true,['Dichotomic Fire']=true,}
Wizard.allDPSSpellGroups = {'largefire', 'smallfire', 'smallice', 'stun', 'Swarm', 'firerain', 'icerain', 'aeTrap', 'ae1', 'ae2', 'ae3', 'ae4'}

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
    self.spellRotations.standard = {}
    self.spellRotations.ae = {}
    table.insert(self.spellRotations.standard, self.spells.swarm)
    table.insert(self.spellRotations.standard, self.spells.largefire)
    table.insert(self.spellRotations.standard, self.spells.smallfire)
    table.insert(self.spellRotations.standard, self.spells.smallice)
    table.insert(self.spellRotations.standard, self.spells.stun)
    table.insert(self.spellRotations.ae, self.spells.aeTrap)
    table.insert(self.spellRotations.ae, self.spells.ae1)
    table.insert(self.spellRotations.ae, self.spells.ae2)
    table.insert(self.spellRotations.ae, self.spells.ae3)
    table.insert(self.spellRotations.ae, self.spells.ae4)
end

return Wizard