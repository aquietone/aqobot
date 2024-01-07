---@type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local timer = require('utils.timer')
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
    self.spellRotations = {standard={}}
    self:initBase('dru')

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
        self.rezAbility = common.getAA('Rejuvination of Spirit') -- 96% rez ooc only
        self.rezStick = common.getItem('Staff of Forbidden Rites')
    end
    self.summonCompanion = common.getAA('Summon Companion')
    self.nuketimer = timer:new(500)
end

function Druid:initClassOptions()
    self:addOption('USENUKES', 'Use Nukes', false, nil, 'Toggle use of nuke spells', 'checkbox', nil, 'UseNukes', 'bool')
    self:addOption('USEDOTS', 'Use DoTs', false, nil, 'Toggle use of DoT spells', 'checkbox', nil, 'UseDoTs', 'bool')
    self:addOption('USESNARE', 'Use Snare', true, nil, 'Cast snare on mobs', 'checkbox', nil, 'UseSnare', 'bool')
    self:addOption('USEDEBUFF', 'Use Ro Debuff', false, nil, 'Use Blessing of Ro AA', 'checkbox', nil, 'UseDebuff', 'bool')
end

function Druid:initSpellLines()
    if state.emu then
        self:addSpell('heal', {'Ancient: Chlorobon', 'Sylvan Infusion', 'Nature\'s Infusion', 'Chloroblast', 'Superior Healing', 'Nature\'s Renewal', 'Light Healing', 'Minor Healing'}, {panic=true, regular=true, tank=true, pet=60})
        self:addSpell('groupheal', {'Word of Reconstitution', 'Word of Restoration', 'Moonshadow'}, {group=true})
        self:addSpell('firenuke', {'Dawnstrike', 'Sylvan Fire', 'Wildfire', 'Scoriae', 'Firestrike'}, {opt='USENUKES'})
        self:addSpell('coldnuke', {'Ancient: Glacier Frost'}, {opt='USENUKES'})
        self:addSpell('twincast', {'Sunburst Blessing'}, {opt='USENUKES'})
        self:addSpell('dot', {'Wasp Swarm', 'Swarming Death', 'Winged Death'}, {opt='USEDOTS'})
        self:addSpell('dot2', {'Vengeance of the Sun'}, {opt='USEDOTS'})
        self:addSpell('snare', {'Ensnare', 'Snare'}, {opt='USESNARE'})
        self:addSpell('aura', {'Aura of Life', 'Aura of the Grove'})
        self:addSpell('pet', {'Nature Wanderer\'s Behest'})
        self:addSpell('reptile', {'Skin of the Reptile'}, {classes={MNK=true,WAR=true,PAL=true,SHD=true}})
        self:addSpell('rgc', {'Remove Greater Curse'}, {curse=true})
    else
        -- Main spell set
        self:addSpell('twincast', {'Twincast'})
        self:addSpell('heal1', {'Resuscitation', 'Soothseance', 'Rejuvenescence', 'Revitalization', 'Resurgence'}, {panic=true, regular=true, tank=true, pet=60}) -- healing spam on cd
        self:addSpell('heal2', {'Adrenaline Fury', 'Adrenaline Spate', 'Adrenaline Deluge', 'Adrenaline Barrage', 'Adrenaline Torrent'}, {panic=true, regular=true, tank=true, pet=60}) -- healing spam on cd
        self:addSpell('groupheal1', {'Lunacea', 'Lunarush', 'Lunalesce', 'Lunasalve', 'Lunasoothe'}, {group=true}) -- group heal
        self:addSpell('groupheal2', {'Survival of the Heroic', 'Survival of the Unrelenting', 'Survival of the Favored', 'Survival of the Auspicious', 'Survival of the Serendipitous'}, {group=true}) -- group heal
        self:addSpell('dot1', {'Nature\'s Boiling Wrath', 'Nature\'s Sweltering Wrath', 'Nature\'s Fervid Wrath', 'Nature\'s Blistering Wrath', 'Nature\'s Fiery Wrath'}, {opt='USEDOTS'})
        self:addSpell('dot2', {'Horde of Hotaria', 'Horde of Duskwigs', 'Horde of Hyperboreads', 'Horde of Polybiads', 'Horde of Aculeids'}, {opt='USEDOTS'})
        self:addSpell('dot3', {'Sunscald', 'Sunpyre', 'Sunshock', 'Sunflame', 'Sunflash'}, {opt='USEDOTS'})
        self:addSpell('dot5', {'Searing Sunray', 'Tenebrous Sunray', 'Erupting Sunray', 'Overwhelming Sunray', 'Consuming Sunray'}, {opt='USEDOTS'}) -- inc spell dmg taken, dot, dec fire resist, dec AC
        --self:addSpell('', {'Mythical Moonbeam', 'Onyx Moonbeam', 'Opaline Moonbeam', 'Pearlescent Moonbeam', 'Argent Moonbeam'}) -- sunray but cold resist
        self:addSpell('nuke1', {'Remote Sunscorch', 'Remote Sunbolt', 'Remote Sunshock', 'Remote Sunblaze', 'Remote Sunflash'}, {opt='USENUKES'}) -- nuke + heal tot
        self:addSpell('nuke2', {'Winter\'s Wildgale', 'Winter\'s Wildbrume', 'Winter\'s Wildshock', 'Winter\'s Wildblaze', 'Winter\'s Wildflame'}, {opt='USENUKES'})
        self:addSpell('nuke3', {'Summer Sunscald', 'Summer Sunpyre', 'Summer Sunshock', 'Summer Sunflame', 'Summer Sunfire'}, {opt='USENUKES'})
        self:addSpell('nuke4', {'Tempest Roar', 'Bloody Roar', 'Typhonic Roar', 'Cyclonic Roar', 'Anabatic Roar'}, {opt='USENUKES'})

        self:addSpell('composite', {'Ecliptic Winds', 'Composite Winds', 'Dichotomic Winds'})
        self:addSpell('alliance', {'Arbor Tender\'s Coalition', 'Bosquetender\'s Alliance'})
        self:addSpell('unity', {'Wildtender\'s Unity', 'Copsetender\'s Unity'})
        
        -- Other spells
        self:addSpell('dot4', {'Chill of the Ferntender', 'Chill of the Dusksage Tender', 'Chill of the Arbor Tender', 'Chill of the Wildtender', 'Chill of the Copsetender'}, {opt='USEDOTS'})
        self:addSpell('heal3', {'Vivavida', 'Clotavida', 'Viridavida', 'Curavida', 'Panavida'}, {panic=true, regular=true, tank=true, pet=60}) -- healing spam if other heals on cd
        self:addSpell('growth', {'Overwhelming Growth', 'Fervent Growth', 'Frenzied Growth', 'Savage Growth', 'Ferocious Growth'})

        self:addSpell('healtot', {'Mythic Frost', 'Primal Frost', 'Restless Frost', 'Glistening Frost', 'Moonbright Frost'}) -- Heal tot, dec atk, dec AC
        self:addSpell('tcnuke', {'Sunbliss Blessing', 'Sunwarmth Blessing', 'Sunrake Blessing', 'Sunflash Blessing', 'Sunfire Blessing'}, {opt='USENUKES'})
        self:addSpell('harvest', {'Emboldened Growth', 'Bolstered Growth', 'Sustaining Growth', 'Nourishing Growth'}) -- self return 10k mana
        self:addSpell('cure', {'Sanctified Blood'}, {curse=true,disease=true,poison=true,corruption=true}) -- cure dis/poi/cor/cur

        -- Buffs
        self:addSpell('skin', {'Emberquartz Blessing', 'Luclinite Blessing', 'Opaline Blessing', 'Arcronite Blessing', 'Shieldstone Blessing'})
        self:addSpell('regen', {'Talisman of the Unforgettable', 'Talisman of the Tenacious', 'Talisman of the Enduring', 'Talisman of the Unwavering', 'Talisman of the Faithful'})
        self:addSpell('mask', {'Mask of the Ferntender', 'Mask of the Dusksage Tender', 'Mask of the Arbor Tender', 'Mask of the Wildtender', 'Mask of the Copsetender'}) -- self mana regen, part of unity AA
        self:addSpell('singleskin', {'Emberquartz Skin', 'Luclinite Skin', 'Opaline Skin', 'Arcronite Skin', 'Shieldstone Skin'})
        self:addSpell('reptile', {'Chitin of the Reptile', 'Bulwark of the Reptile', 'Defense of the Reptile', 'Guard of the Reptile', 'Pellicle of the Reptile'}, {classes={MNK=true,WAR=true,PAL=true,SHD=true}}) -- debuff on hit, lowers atk++AC

        -- Aura
        self:addSpell('aura', {'Coldburst Aura', 'Nightchill Aura', 'Icerend Aura', 'Frostreave Aura', 'Frostweave Aura'}) -- adds cold dmg proc to spells
    end
end

function Druid:initSpellRotations()
    if state.emu then
        table.insert(self.spellRotations.standard, self.spells.dot)
        table.insert(self.spellRotations.standard, self.spells.dot2)
        table.insert(self.spellRotations.standard, self.spells.twincast)
        table.insert(self.spellRotations.standard, self.spells.firenuke)
        table.insert(self.spellRotations.standard, self.spells.coldnuke)
    else
        table.insert(self.spellRotations.standard, self.spells.dot1)
        table.insert(self.spellRotations.standard, self.spells.dot2)
        table.insert(self.spellRotations.standard, self.spells.dot3)
        table.insert(self.spellRotations.standard, self.spells.dot4)
        table.insert(self.spellRotations.standard, self.spells.dot5)

        table.insert(self.spellRotations.standard, self.spells.nuke1)
        table.insert(self.spellRotations.standard, self.spells.nuke2)
        table.insert(self.spellRotations.standard, self.spells.nuke3)
        table.insert(self.spellRotations.standard, self.spells.nuke4)
    end
end

function Druid:initHeals()
    if state.emu then
        table.insert(self.healAbilities, self.spells.heal)
        table.insert(self.healAbilities, self.spells.groupheal)
        table.insert(self.healAbilities, common.getAA('Convergence of Spirits', {panic=true}))
        table.insert(self.healAbilities, common.getAA('Peaceful Convergence of Spirits', {panic=true}))
    else
        -- Heal AA's
        table.insert(self.healAbilities, self.spells.heal1)
        table.insert(self.healAbilities, self.spells.heal2)
        table.insert(self.healAbilities, self.spells.heal3)
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
        table.insert(self.cureAbilities, common.getAA('Radiant Cure')) -- poi,dis,cur, any detri
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