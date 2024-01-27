---@type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local timer = require('libaqo.timer')
local common = require('common')
local state = require('state')

local Druid = class:new()

--[[
    https://rexaraven.com/everquest/druid/druid-general-guide/

    -- Tank AAs
    self:addSpell('', {'Fervent Growth'}) -- temp max hp boost
    common.getAA('Swarm of Fireflies') -- instant heal + regen below 40% hp
    common.getAA('Bear Spirit') -- short duration max hp, ac, dodge buff

]]
--[[
    wasp swarm
    ancient: chlorobon
    hand of ro
    vengeance of the sun
    sunburst blessing
    incarnate anew
    word of restoration
    moonshadow
    blank
    remove greater curse
    circle of knowledge
    skin of the reptile
]]
function Druid:init()
    self.classOrder = {'heal', 'assist', 'debuff', 'cast', 'mash', 'burn', 'recover', 'rez', 'buff', 'rest', 'managepet'}
    self.spellRotations = {standard={},custom={}}
    self:initBase('DRU')

    self:initClassOptions()
    self:loadSettings()
    self:initSpellLines()
    self:initSpellRotations()
    self:initHeals()
    self:initCures()
    self:initBuffs()
    self:initBurns()
    self:initDPSAbilities()
    self:initDefensiveAbilities()
    self:initDebuffs()
    self:addCommonAbilities()

    -- Rezzing
    if state.emu then
        self.rezAbility = common.getAA('Call of the Wild')
    else
        self.callAbility = common.getAA('Call of the Wild') -- brez
        self.rezAbility = common.getAA('Rejuvenation of Spirit') -- 96% rez ooc only
        self.rezStick = common.getItem('Staff of Forbidden Rites')
    end
    self.summonCompanion = common.getAA('Summon Companion')
    state.nuketimer = timer:new(500)
end

function Druid:initClassOptions()
    self:addOption('USENUKES', 'Use Nukes', false, nil, 'Toggle use of nuke spells', 'checkbox', nil, 'UseNukes', 'bool')
    self:addOption('USEDOTS', 'Use DoTs', false, nil, 'Toggle use of DoT spells', 'checkbox', nil, 'UseDoTs', 'bool')
    self:addOption('USESNARE', 'Use Snare', true, nil, 'Cast snare on mobs', 'checkbox', nil, 'UseSnare', 'bool')
    self:addOption('USEDEBUFF', 'Use Ro Debuff', false, nil, 'Use Blessing of Ro AA', 'checkbox', nil, 'UseDebuff', 'bool')
end

Druid.SpellLines = {
    -- Main spell set
    {Group='twincast', Spells={'Twincast'}},
    {Group='heal1', Spells={'Resuscitation', 'Soothseance', 'Rejuvenescence', 'Revitalization', 'Resurgence', 'Ancient: Chlorobon', 'Sylvan Infusion', 'Nature\'s Infusion', 'Chloroblast', 'Superior Healing', 'Nature\'s Renewal', 'Light Healing', 'Minor Healing'}, Options={panic=true, regular=true, tank=true, pet=60}},
    {Group='heal2', Spells={'Adrenaline Fury', 'Adrenaline Spate', 'Adrenaline Deluge', 'Adrenaline Barrage', 'Adrenaline Torrent'}, Options={panic=true, regular=true, tank=true, pet=60}}, -- healing spam on cd
    {Group='groupheal1', Spells={'Lunacea', 'Lunarush', 'Lunalesce', 'Lunasalve', 'Lunasoothe', 'Word of Reconstitution', 'Word of Restoration', 'Moonshadow'}, Options={group=true}},
    {Group='groupheal2', Spells={'Survival of the Heroic', 'Survival of the Unrelenting', 'Survival of the Favored', 'Survival of the Auspicious', 'Survival of the Serendipitous'}, Options={group=true}}, -- group heal
    {Group='dot1', Spells={'Nature\'s Boiling Wrath', 'Nature\'s Sweltering Wrath', 'Nature\'s Fervid Wrath', 'Nature\'s Blistering Wrath', 'Nature\'s Fiery Wrath'}, Options={opt='USEDOTS'}},
    {Group='dot2', Spells={'Horde of Hotaria', 'Horde of Duskwigs', 'Horde of Hyperboreads', 'Horde of Polybiads', 'Horde of Aculeids', 'Wasp Swarm', 'Swarming Death', 'Winged Death'}, Options={opt='USEDOTS'}},
    {Group='dot3', Spells={'Sunscald', 'Sunpyre', 'Sunshock', 'Sunflame', 'Sunflash', 'Vengeance of the Sun'}, Options={opt='USEDOTS'}},
    {Group='dot5', Spells={'Searing Sunray', 'Tenebrous Sunray', 'Erupting Sunray', 'Overwhelming Sunray', 'Consuming Sunray'}, Options={opt='USEDOTS'}}, -- inc spell dmg taken, dot, dec fire resist, dec AC
    --{Group='', Spells={'Mythical Moonbeam', 'Onyx Moonbeam', 'Opaline Moonbeam', 'Pearlescent Moonbeam', 'Argent Moonbeam'}}, -- sunray but cold resist
    {Group='nuke1', Spells={'Remote Sunscorch', 'Remote Sunbolt', 'Remote Sunshock', 'Remote Sunblaze', 'Remote Sunflash'}, Options={opt='USENUKES'}}, -- nuke + heal tot
    {Group='nuke2', Spells={'Winter\'s Wildgale', 'Winter\'s Wildbrume', 'Winter\'s Wildshock', 'Winter\'s Wildblaze', 'Winter\'s Wildflame', 'Ancient: Glacier Frost'}, Options={opt='USENUKES'}},
    {Group='nuke3', Spells={'Summer Sunscald', 'Summer Sunpyre', 'Summer Sunshock', 'Summer Sunflame', 'Summer Sunfire', 'Dawnstrike', 'Sylvan Fire', 'Wildfire', 'Scoriae', 'Firestrike'}, Options={opt='USENUKES'}},
    {Group='nuke4', Spells={'Tempest Roar', 'Bloody Roar', 'Typhonic Roar', 'Cyclonic Roar', 'Anabatic Roar'}, Options={opt='USENUKES'}},

    {Group='composite', Spells={'Ecliptic Winds', 'Composite Winds', 'Dichotomic Winds'}},
    {Group='alliance', Spells={'Arbor Tender\'s Coalition', 'Bosquetender\'s Alliance'}},
    {Group='unity', Spells={'Wildtender\'s Unity', 'Copsetender\'s Unity'}},

    -- Other spells
    {Group='dot4', Spells={'Chill of the Ferntender', 'Chill of the Dusksage Tender', 'Chill of the Arbor Tender', 'Chill of the Wildtender', 'Chill of the Copsetender'}, Options={opt='USEDOTS'}},
    {Group='heal3', Spells={'Vivavida', 'Clotavida', 'Viridavida', 'Curavida', 'Panavida'}, Options={panic=true, regular=true, tank=true, pet=60}}, -- healing spam if other heals on cd
    {Group='growth', Spells={'Overwhelming Growth', 'Fervent Growth', 'Frenzied Growth', 'Savage Growth', 'Ferocious Growth'}},
    {Group='snare', Spells={'Ensnare', 'Snare'}, Options={opt='USESNARE'}},

    {Group='healtot', Spells={'Mythic Frost', 'Primal Frost', 'Restless Frost', 'Glistening Frost', 'Moonbright Frost'}}, -- Heal tot, dec atk, dec AC
    {Group='tcnuke', Spells={'Sunbliss Blessing', 'Sunwarmth Blessing', 'Sunrake Blessing', 'Sunflash Blessing', 'Sunfire Blessing', 'Sunburst Blessing'}, Options={opt='USENUKES'}},
    {Group='harvest', Spells={'Emboldened Growth', 'Bolstered Growth', 'Sustaining Growth', 'Nourishing Growth'}}, -- self return 10k mana
    {Group='cure', Spells={'Sanctified Blood'}, Options={curse=true,disease=true,poison=true,corruption=true}}, -- cure dis/poi/cor/cur
    {Group='rgc', Spells={'Remove Greater Curse'}, Options={curse=true}},
    {Group='pet', Spells={'Nature Wanderer\'s Behest'}, Options={opt='USEPET'}},

    -- Buffs
    {Group='skin', Spells={'Emberquartz Blessing', 'Luclinite Blessing', 'Opaline Blessing', 'Arcronite Blessing', 'Shieldstone Blessing'}},
    {Group='regen', Spells={'Talisman of the Unforgettable', 'Talisman of the Tenacious', 'Talisman of the Enduring', 'Talisman of the Unwavering', 'Talisman of the Faithful'}},
    {Group='mask', Spells={'Mask of the Ferntender', 'Mask of the Dusksage Tender', 'Mask of the Arbor Tender', 'Mask of the Wildtender', 'Mask of the Copsetender'}}, -- self mana regen, part of unity AA
    {Group='singleskin', Spells={'Emberquartz Skin', 'Luclinite Skin', 'Opaline Skin', 'Arcronite Skin', 'Shieldstone Skin'}},
    {Group='reptile', Spells={'Chitin of the Reptile', 'Bulwark of the Reptile', 'Defense of the Reptile', 'Guard of the Reptile', 'Pellicle of the Reptile', 'Skin of the Reptile'}, Options={classes={MNK=true,WAR=true,PAL=true,SHD=true}}}, -- debuff on hit, lowers atk++AC

    -- Aura
    {Group='aura', Spells={'Coldburst Aura', 'Nightchill Aura', 'Icerend Aura', 'Frostreave Aura', 'Frostweave Aura', 'Aura of Life', 'Aura of the Grove'}}, -- adds cold dmg proc to spells
}

Druid.compositeNames = {['Ecliptic Winds']=true,['Composite Winds']=true,['Dissident Winds']=true,['Dichotomic Winds']=true,}
Druid.allDPSSpellGroups = {'dot1', 'dot2', 'dot3', 'dot4', 'dot5', 'tcnuke', 'nuke1', 'nuke2', 'nuke3', 'nuke4', 'snare'}

function Druid:initSpellRotations()
    self:initBYOSCustom()
    table.insert(self.spellRotations.standard, self.spells.dot1)
    table.insert(self.spellRotations.standard, self.spells.dot2)
    table.insert(self.spellRotations.standard, self.spells.dot3)
    table.insert(self.spellRotations.standard, self.spells.dot4)
    table.insert(self.spellRotations.standard, self.spells.dot5)

    table.insert(self.spellRotations.standard, self.spells.tcnuke)
    table.insert(self.spellRotations.standard, self.spells.nuke1)
    table.insert(self.spellRotations.standard, self.spells.nuke2)
    table.insert(self.spellRotations.standard, self.spells.nuke3)
    table.insert(self.spellRotations.standard, self.spells.nuke4)
end

function Druid:initHeals()
    table.insert(self.healAbilities, self.spells.heal1)
    table.insert(self.healAbilities, self.spells.heal2)
    table.insert(self.healAbilities, self.spells.heal3)
    table.insert(self.healAbilities, self.spells.groupheal1)
    table.insert(self.healAbilities, self.spells.groupheal2)
    table.insert(self.healAbilities, common.getAA('Convergence of Spirits', {panic=true}))
    if state.emu then
        table.insert(self.healAbilities, common.getAA('Peaceful Convergence of Spirits', {panic=true}))
    else
        -- Heal AA's
        table.insert(self.healAbilities, common.getAA('Convergence of Spirits')) -- instant heal + hot
        table.insert(self.healAbilities, common.getAA('Blessing of Tunare')) -- targeted AE splash heal if lunarush down
        table.insert(self.healAbilities, common.getAA('Wildtender\'s Survival')) -- casts highest survival spell. group heal
        table.insert(self.healAbilities, common.getAA('Nature\'s Boon')) -- stationary healing ward
        table.insert(self.healAbilities, common.getAA('Spirit of the Wood')) -- group hot, MGB'able
    end
end

function Druid:initCures()
    if state.emu then
        table.insert(self.cures, self.radiant)
        table.insert(self.cures, self.spells.rgc)
    else
        -- Cures
        table.insert(self.cureAbilities, self.spells.cure)
        table.insert(self.cureAbilities, self.radiant) -- poi,dis,cur, any detri
    end
end

-- Group Spirit of the Black Wolf
-- Group Spirit of the White Wolf

-- storm strike, nuke aa, 30 sec cd
-- spirits of nature, 10min cd, swarm pets

-- spirit of the wood, 15 min cd, regen+ds group
-- peaceful spirit of the wood, 15 min cd, regen+ds group

-- protection of direwood, 15min cd, what is direwood guard
-- spirit of the white wolf, buffs healing
-- spirit of the black wolf, buffs spell damage

-- spirit of the bear, 10min cd, temp hp buff

-- blessing of ro, combined hand+fixation of ro

-- convergence of spirits, 15min cd large heal
-- peaceful convergence of spirits, 15min cd large heal
-- Fundament: Second Spire of Nature -- improved healing (first spire=damage, third spire=group hp buff)
-- improved twincast
-- nature's blessing, 12 seconds all heals crit, 30min cd
-- nature's boon, 30min cd, healing ward
-- nature's fury, 45min cd, improved damage
-- nature's guardian, 22min  cd, temp pet
function Druid:initBurns()
    if state.emu then
        table.insert(self.burnAbilities, common.getAA('Spirits of Nature', {delay=1500}))
        table.insert(self.burnAbilities, common.getAA('Group Spirit of the Black Wolf'))
        table.insert(self.burnAbilities, common.getAA('Nature\'s Guardian'))
        table.insert(self.burnAbilities, common.getAA('Nature\'s Fury'))
        table.insert(self.burnAbilities, common.getAA('Nature\'s Boon'))
        table.insert(self.burnAbilities, common.getAA('Nature\'s Blessing'))
        table.insert(self.burnAbilities, common.getAA('Improved Twincast'))
        table.insert(self.burnAbilities, common.getAA('Fundament: Second Spire of Nature'))
    else
        -- Wolf forms. Alternate them
        common.getAA('Group Spirit of the Great Wolf') -- reduce mana cost, inc crit, mana regen
        common.getAA('Spirit of the Great Wolf') -- self only

        -- Pre Burn
        -- Silent Casting, Distant Conflagration, BP click, Blessing of Ro, Season\'s Wrath

        -- Burn Order
        -- group wolf, ITC+DV+NF+FA, Nature\'s Sweltering Wrath, Horde of Duskwigs, Sunpyre, Chill of the Dusksage Tender, Tenebrous Sunray

        -- Lesser Burn
        -- Twincast, Spire of Nature

        -- Main Burn
        table.insert(self.burnAbilities, common.getAA('Group Spirit of the Great Wolf', {first=true})) -- reduce mana cost, inc crit, mana regen
        table.insert(self.burnAbilities, common.getAA('Improved Twincast', {first=true}))
        table.insert(self.burnAbilities, common.getAA('Destructive Vortex', {first=true}))
        table.insert(self.burnAbilities, common.getAA('Nature\'s Fury', {first=true}))
        table.insert(self.burnAbilities, common.getAA('Focus of Arcanum', {first=true}))

        table.insert(self.burnAbilities, common.getAA('Spire of Nature', {second=true}))
    end
end

function Druid:initDPSAbilities()
    if state.emu then
        table.insert(self.DPSAbilities, common.getItem('Nature Walkers Scimitar'))
        table.insert(self.DPSAbilities, common.getAA('Storm Strike'))
    else
        -- Nuke Order
        -- nuke1, natures fire, nuke2, natures bolt, nuke3, natures frost, nuke4
        -- Nuke AAs
        table.insert(self.DPSAbilities, common.getAA('Nature\'s Fire'))
        table.insert(self.DPSAbilities, common.getAA('Nature\'s Bolt'))
        table.insert(self.DPSAbilities, common.getAA('Nature\'s Frost'))
    end
end

function Druid:initBuffs()
    -- Aura of the Grove, Aura of the Grove Effect
    table.insert(self.auras, self.spells.aura)

    table.insert(self.singleBuffs, self.spells.reptile)
    table.insert(self.singleBuffs, common.getAA('Wrath of the Wild', {classes={DRU=true,CLR=true,SHM=true,ENC=true,MAG=true,WIZ=true,RNG=true,MNK=true}}))
    table.insert(self.selfBuffs, self.spells.reptile)
    table.insert(self.selfBuffs, common.getAA('Spirit of the Black Wolf'))
    self.bear = common.getAA('Spirit of the Bear')
    self:addRequestAlias(self.bear, 'GROWTH')
    self:addRequestAlias(self.spells.reptile, 'REPTILE')
    self:addRequestAlias(self.spells.skin, 'SKIN')

    table.insert(self.selfBuffs, self.spells.skin)
    table.insert(self.selfBuffs, self.spells.regen)
    table.insert(self.selfBuffs, self.spells.mask)
    table.insert(self.selfBuffs, common.getAA('Preincarnation')) -- invuln instead of death AA
end

function Druid:initDefensiveAbilities()
    table.insert(self.defensiveAbilities, common.getAA('Protection of Direwood'))
    -- fade
    table.insert(self.fadeAbilities, common.getAA('Veil of the Underbrush'))
end

function Druid:initDebuffs()
    table.insert(self.debuffs, common.getAA('Blessing of Ro', {opt='USEDEBUFF'})) -- always cast. lower atk, fire resist, ac, heals tot
    table.insert(self.debuffs, common.getAA('Season\'s Wrath', {opt='USEDEBUFF'})) -- inc dmg from fire+cold
    table.insert(self.debuffs, self.spells.snare)
end

return Druid