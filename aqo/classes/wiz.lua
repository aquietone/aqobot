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
    {Group='largefire', Spells={'Ether Flame', 'Corona Flare', 'White Fire', 'Conflagration', 'Fire Bolt'}, Options={Gem=3}},
    {Group='smallfire', Spells={'Chaos Flame', 'Draught of Ro', 'Draught of Fire', 'Inferno Shock', 'Flame Shock', 'Shock of Fire'}, Options={Gem=2}},
    {Group='smallice', Spells={'Ancient: Spear of Gelaqua', 'Black Ice', 'Claw of Frost', 'Ice Spear of Solist', 'Elnerick\'s Entombment of Ice', 'Ice Shock', 'Frost Shock', 'Shock of Ice', 'Blast of Cold'}, Options={Gem=1}},
    {Group='lightning', Spells={'Thunder Strike', 'Garrison\'s Mighty Mana Shock', 'Force Snap', 'Shock of Lightning'}, Options={Gem=4}},
    {Group='stun', Spells={'Telekara', 'Thunderclap', 'Tishan\'s Clash'}},
    {Group='Swarm', Spells={'Solist\'s Frozen Sword'}},
    {Group='firerain', Spells={'Lava Storm', 'Firestorm'}, Options={opt='USEAOE'}},
    {Group='icerain', Spells={'Gelid Rains', 'Icestrike'}, Options={opt='USEAOE'}},
    {Group='lightningrain', Spells={'Energy Storm', 'Lightning Storm'}, Options={opt='USEAOE'}},
    {Group='aeTrap', Spells={'Fire Rune'}},
    {Group='ae1', Spells={'Column of Lightning', 'Shock Spiral of Al`Kabor', 'Circle of Thunder', 'Project Lightning'}, Options={opt='USEAOE', Gem=6}},
    {Group='ae2', Spells={'Jyll\'s Static Pulse', 'Force Spiral of Al`Kabor', 'Circle of Force', 'Cast Force'}, Options={opt='USEAOE'}},
    {Group='ae3', Spells={'Jyll\'s Zephyr of Ice', 'Frost Spiral of Al\'Kabor', 'Column of Frost', 'Numbing Cold'}, Options={opt='USEAOE', Gem=7}},
    {Group='ae4', Spells={'Jyll\'s Wave of Heat', 'Fire Spiral of Al\'Kabor', 'Pillar of Fire', 'Fingers of Fire'}, Options={opt='USEAOE', Gem=8}},
    {Group='hpbuff', Spells={'Greater Shielding', 'Major Shielding', 'Shielding', 'Lesser Shielding', 'Minor Shielding'}, Options={selfbuff=true}},
    {Group='ds', Spells={'O`Keil\'s Flickering Flame', 'O`Keil\'s Levity', 'O`Keil\'s Embers', 'O`Keil\'s Radiation'}, Options={singlebuff=true, classes={}}},
    {Group='dispel', Spells={'Nullify Magic', 'Cancel Magic'}, Options={debuff=true, dispel=true, opt='USEDISPEL'}},

    {Group='lurefire', Spells={'Firebane', 'Lure of Ro', 'Lure of Flame', 'Enticement of Flame'}},
    {Group='lureice', Spells={'Lure of Ice'}},

    {Group='familiar', Spells={'Minor Familiar'}},

    {Group='harvest', Spells={'Harvest'}, Options={Gem=5}},
}

Wizard.compositeNames = {['Ecliptic Fire']=true,['Composite Fire']=true,['Dissident Fire']=true,['Dichotomic Fire']=true,}
Wizard.allDPSSpellGroups = {'largefire', 'smallfire', 'smallice', 'lightning', 'stun', 'Swarm', 'firerain', 'icerain', 'lightningrain', 'aeTrap', 'ae1', 'ae2', 'ae3', 'ae4'}

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
    table.insert(self.spellRotations.standard, self.spells.lightning)
    table.insert(self.spellRotations.standard, self.spells.stun)
    table.insert(self.spellRotations.ae, self.spells.aeTrap)
    table.insert(self.spellRotations.ae, self.spells.ae1)
    table.insert(self.spellRotations.ae, self.spells.ae2)
    table.insert(self.spellRotations.ae, self.spells.ae3)
    table.insert(self.spellRotations.ae, self.spells.ae4)
    table.insert(self.spellRotations.ae, self.spells.firerain)
    table.insert(self.spellRotations.ae, self.spells.icerain)
    table.insert(self.spellRotations.ae, self.spells.lightningrain)
end

Wizard.Ports = {
    -- 'Nexus Gate'
    -- 'North Gate'
    -- 'Tox Gate'
    -- 'Blightfire Moors Gate'
    -- 'Fay Gate'
    -- 'Grimling Gate'
    -- 'Common Gate'
    -- 'Stonebrunt Gate'
    -- 'Nek Gate'
    -- 'Ro Gate'
    -- 'Twilight Gate'
    -- 'Cazic Gate'
    -- 'West Gate'
    -- 'Combine Gate'
    -- 'Knowledge Gate'
    -- 'Iceclad Gate',
    -- 'Great Divide Gate'

    -- 'Blightfire Moors Portal',
    -- 'North Portal'
    -- 'Fay Portal',
    -- 'Stonebrunt Portal'
    -- 'Tox Portal'
    -- 'Grimling Portal'
    -- 'Dawnshroud Portal',
    -- 'Nexus Portal'
    -- 'Nek Portal'
    -- 'Iceclad Portal'
    -- 'Cazic Portal'
    -- 'Twilight Portal'
    -- 'Combine Portal'
    -- 'Common Portal'

    -- 'Translocate: Blightfire Moors'
    -- 'Translocate: North'
    -- 'Translocate Stonebrunt'

}
return Wizard