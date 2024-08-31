local mq = require('mq')
local class = require('classes.classbase')
local common = require('common')
local state = require('state')

local Wizard = class:new()

--[[
    https://forums.eqfreelance.net/index.php?topic=16645.0
]]
function Wizard:init()
    self.classOrder = {'aggro', 'assist', 'burn', 'cast', 'mash', 'recover', 'buff', 'rest', 'rez'}
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
    self:addOption('USEHARVEST', 'Use Harvest', true, nil, 'Toggle use of Harvest spell/AA', 'checkbox', nil, 'UseHarvest', 'bool')
end
-- circle of thunder, jyll's wave of heat, jyll's static pulse (pbae)
-- scepter of incantations, molten orb, aged shissar elementalist's staff
-- concussive intuition (aggro)
-- maelin's leggings of lore (aggro)
-- imbued rune of mana weave (Weave of Power)
-- mana weave (Weave of Power)
-- ether flame (power buff)
-- force of will
-- telekemara
-- mind crash (aggro)
-- gelid rains, tears of ro
-- ether flame
Wizard.SpellLines = {
    {Group='largefire', Spells={'Ether Flame', 'Corona Flare', 'White Fire', 'Strike of Solusek', 'Conflagration', 'Fire Bolt'}, Options={Gem=1}},
    {Group='weavenuke', Spells={'Ether Flame', 'Corona Flare', 'White Fire', 'Strike of Solusek', 'Conflagration', 'Fire Bolt'}, Options={condition=function() return mq.TLO.Me.Buff('Weave of Power')() or mq.TLO.Me.Song('Weave of Power')() end}},
    {Group='stun', Spells={'Telakemara', 'Telekara', 'Telaka', 'Telekin', 'Markar\'s Discord', 'Tishan\'s Discord', 'Markar\'s Clash', 'Tishan\'s Clash', 'Thunderclap'}, Options={Gem=2}},
    {Group='firerain', Spells={--[['Tears of the Sun', 'Tears of Arlyxir', ]]'Tears of Ro', 'Tears of Solusek', 'Lava Storm', 'Firestorm'}, Options={opt='USEAOE', Gem=3}},
    {Group='icerain', Spells={'Gelid Rains', 'Tears of Marr', 'Tears of Prexus', 'Frost Storm', 'Icestrike'}, Options={opt='USEAOE', Gem=4}},
    {Group='weave', Spells={'Mana Weave'}, Options={Gem=function(lvl) return lvl <= 70 and 5 end, condition=function() return not mq.TLO.Me.Buff('Weave of Power')() and not mq.TLO.Me.Song('Weave of Power')() end}},
    {Group='pbaelightning', Spells={'Circle of Thunder', 'Jyll\'s Static Pulse', 'Cast Force', 'Project Lightning'}, Options={opt='USEAOE', Gem=6, condition=function() return (mq.TLO.Target.Distance3D() or 100) < 45 and state.mobCountNoPets > 2 end}},
    {Group='pbaeice', Spells={--[['Winds of Gelid', ]]'Jyll\'s Zephyr of Ice', 'Numbing Cold'}, Options={opt='USEAOE', Gem=7, condition=function() return (mq.TLO.Target.Distance3D() or 100) < 45 and state.mobCountNoPets > 2 end}},
    {Group='pbaefire', Spells={--[['Circle of Fire', ]]'Jyll\'s Wave of Heat', 'Fingers of Fire'}, Options={opt='USEAOE', Gem=8, condition=function() return (mq.TLO.Target.Distance3D() or 100) < 45 and state.mobCountNoPets > 2 end}},

    {Group='harvest', Spells={'Harvest'}, Options={Gem=9, opt='USEHARVEST', condition=function() return not state.burn_active end}},
    {Group='rune', Spells={'Ether Skin'}, Options={selfbuff=true, Gem=10}},
    {Group='dispel', Spells={'Annul Magic', 'Nullify Magic', 'Cancel Magic'}, Options={debuff=true, dispel=true, opt='USEDISPEL',}},-- Gem=11}},
    {Group='hpbuff', Spells={'Ether Shield', 'Greater Shielding', 'Major Shielding', 'Shielding', 'Lesser Shielding', 'Minor Shielding'}, Options={selfbuff=true, Gem=12}},

    {Group='largeice', Spells={'Gelidin Comet', 'Ice Meteor', 'Ice Comet'}, Options={}},-- Gem=3
    {Group='smallice', Spells={'Claw of Vox', 'Spark of Ice', 'Claw of Frost', 'Ice Shock', 'Frost Shock', 'Shock of Ice', 'Blast of Cold'}, Options={}},-- Gem=1
    {Group='fastice', Spells={'Ancient: Spear of Gelaqua', 'Black Ice', 'Ice Spear of Solist', 'Draught of E`ci', 'Draught of Ice'}, Options={Gem=11}},-- Gem=2
    {Group='lureice', Spells={'Icebane', 'Lure of Ice', 'Lure of Frost'}, Options={}},-- Gem=12
    -- {Group='targetpbaeice', Spells={'Retribution of Al\'Kabor', 'Wrath of Al\'Kabor', 'Frost Spiral of Al\'Kabor', 'Column of Frost'}, Options={opt='USEAOE', Gem=3}},

    {Group='smallfire', Spells={'Inferno Shock', 'Flame Shock', 'Shock of Fire'}, Options={}},-- Gem=4
    {Group='fastfire', Spells={'Chaos Flame', 'Draught of Ro', 'Draught of Fire'}, Options={}},-- Gem=5
    {Group='lurefire', Spells={'Firebane', 'Lure of Ro', 'Lure of Flame', 'Enticement of Flame'}, Options={}},-- Gem=11
    -- {Group='targetpbaefire', Spells={'Pillar of Flame', 'Inferno of Al`Kabor', 'Fire Spiral of Al\'Kabor', 'Pillar of Fire'}, Options={opt='USEAOE', Gem=6}},

    {Group='lightning', Spells={'Thunder Strike', 'Garrison\'s Mighty Mana Shock', 'Force Snap', 'Shock of Lightning'}, Options={}},-- Gem=7
    {Group='lightningrain', Spells={'Energy Storm', 'Lightning Storm'}, Options={opt='USEAOE'}},
    -- {Group='targetpbaelightning', Spells={'Vengeance of Al`Kabor', 'Thunderbolt', 'Pillar of Lightning', 'Force Spiral of Al`Kabor', 'Circle of Force', 'Shock Spiral of Al`Kabor', 'Column of Lightning'}, Options={opt='USEAOE'}},

    {Group='swarm', Spells={'Solist\'s Frozen Sword'}},
    {Group='aetrap', Spells={'Fire Rune'}},
    {Group='ds', Spells={'O`Keil\'s Flickering Flame', 'O`Keil\'s Levity', 'O`Keil\'s Embers', 'O`Keil\'s Radiation'}, Options={singlebuff=true, classes={}}},

    {Group='familiar', Spells={'Minor Familiar'}},
}

Wizard.compositeNames = {['Ecliptic Fire']=true,['Composite Fire']=true,['Dissident Fire']=true,['Dichotomic Fire']=true,}
Wizard.allDPSSpellGroups = {'weave', 'weavenuke', 'largefire', 'largeice', 'smallfire', 'smallice', 'firefire', 'fastice', 'lurefire', 'lureice', 'lightning', 'stun', 'swarm', 'firerain', 'icerain', 'lightningrain', 'aetrap', 'pbaefire', --[['targetpbaefire', ]]'pbaeice', --[['targetpbaeice', ]]'pbaelightning', --[['targetpbaelightning']]}

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
    -- {
    --     Type='AA',
    --     Name='Mana Blaze',
    --     Options={first=true}
    -- },
    {
        Type='AA',
        Name='Improved Twincast',
        Options={first=true}
    },
    {
        Type='Item',
        Name='Staff of Ancient Power',
        Options={first=true, epicburn=true}
    },
    {
        Type='Item',
        Name='Staff of Phenomenal Power',
        Options={first=true, epicburn=true}
    },
    {
        Type='AA',
        Name='Volatile Mana Blaze',
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

    {
        Type='AA',
        Name='Concussive Intuition',
        Options={dps=true, condition=function() return mq.TLO.Target.PctAggro() or 0 > 70 end}
    },

    -- Recover
    {
        Type='AA',
        Name='Harvest of Druzzil',
        Options={recover=true, opt='USEHARVEST', condition=function() return not state.burn_active end}
    }
}
function Wizard:initSpellRotations()
    self:initBYOSCustom()
    self.spellRotations.standard = {}
    self.spellRotations.ae = {}
    table.insert(self.spellRotations.standard, self.spells.pbaelightning)
    table.insert(self.spellRotations.standard, self.spells.pbaefire)
    table.insert(self.spellRotations.standard, self.spells.pbaeice)
    table.insert(self.spellRotations.standard, self.spells.weave)
    table.insert(self.spellRotations.standard, self.spells.weavenuke)
    table.insert(self.spellRotations.standard, self.spells.stun)
    table.insert(self.spellRotations.standard, self.spells.fastice)
    table.insert(self.spellRotations.standard, self.spells.firerain)
    table.insert(self.spellRotations.standard, self.spells.icerain)
    table.insert(self.spellRotations.standard, self.spells.largefire)
    -- table.insert(self.spellRotations.standard, self.spells.swarm)
    -- table.insert(self.spellRotations.standard, self.spells.largefire)
    -- table.insert(self.spellRotations.standard, self.spells.largeice)
    -- table.insert(self.spellRotations.standard, self.spells.smallfire)
    -- table.insert(self.spellRotations.standard, self.spells.smallice)
    -- table.insert(self.spellRotations.standard, self.spells.fastfire)
    -- table.insert(self.spellRotations.standard, self.spells.fastice)
    -- table.insert(self.spellRotations.standard, self.spells.lightning)
    -- table.insert(self.spellRotations.standard, self.spells.stun)
    table.insert(self.spellRotations.ae, self.spells.aetrap)
    table.insert(self.spellRotations.ae, self.spells.pbaefire)
    table.insert(self.spellRotations.ae, self.spells.pbaeice)
    table.insert(self.spellRotations.ae, self.spells.pbaelightning)
    table.insert(self.spellRotations.ae, self.spells.targetpbaefire)
    table.insert(self.spellRotations.ae, self.spells.targetpbaeice)
    table.insert(self.spellRotations.ae, self.spells.targetpbaelightning)
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