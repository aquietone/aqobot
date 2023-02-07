---@type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local timer = require('utils.timer')
local common = require('common')

function class.init(_aqo)
    class.classOrder = {'heal', 'assist', 'debuff', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest', 'managepet'}
    class.spellRotations = {standard={}}
    class.initBase(_aqo, 'dru')


    class.initClassOptions()
    class.loadSettings()
    class.initSpellLines(_aqo)
    class.initSpellRotations(_aqo)
    class.initHeals(_aqo)
    class.initBuffs(_aqo)
    class.initBurns(_aqo)
    class.initDPSAbilities(_aqo)

    table.insert(class.cures, class.radiant)
    --table.insert(class.cures, class.rgc)

    table.insert(class.debuffs, common.getAA('Blessing of Ro', {opt='USEDEBUFF'}))
    table.insert(class.debuffs, class.spells.snare)

    class.nuketimer = timer:new(5)
end

function class.initClassOptions()
    class.addOption('USENUKES', 'Use Nukes', false, nil, 'Toggle use of nuke spells', 'checkbox')
    class.addOption('USEDOTS', 'Use DoTs', false, nil, 'Toggle use of DoT spells', 'checkbox')
    class.addOption('USESNARE', 'Use Snare', true, nil, 'Cast snare on mobs', 'checkbox')
    class.addOption('USEDEBUFF', 'Use Ro Debuff', false, nil, '', 'checkbox')
end

function class.initSpellLines(_aqo)
    class.addSpell('heal', {'Ancient: Chlorobon', 'Sylvan Infusion', 'Nature\'s Infusion', 'Chloroblast', 'Superior Healing', 'Nature\'s Renewal', 'Light Healing', 'Minor Healing'}, {panic=true, regular=true, tank=true, pet=60})
    class.addSpell('groupheal', {'Moonshadow', 'Word of Restoration'}, {group=true})
    class.addSpell('firenuke', {'Dawnstrike', 'Sylvan Fire', 'Wildfire', 'Scoriae', 'Firestrike'}, {opt='USENUKES'})
    class.addSpell('dot', {'Swarming Death', 'Winged Death'}, {opt='USEDOTS'})
    class.addSpell('dot2', {'Vengeance of the Sun'}, {opt='USEDOTS'})
    class.addSpell('snare', {'Ensnare', 'Snare'}, {opt='USESNARE'})
    class.addSpell('aura', {'Aura of Life', 'Aura of the Grove'})
    class.addSpell('pet', {'Nature Wanderer\'s Behest'})
    class.addSpell('reptile', {'Skin of the Reptile'}, {classes={MNK=true,WAR=true,PAL=true,SHD=true}})
    class.addSpell('rgc', {'Remove Greater Curse'}, {curse=true})
end

function class.initSpellRotations(_aqo)
    table.insert(class.spellRotations.standard, class.spells.firenuke)
    table.insert(class.spellRotations.standard, class.spells.dot)
    table.insert(class.spellRotations.standard, class.spells.dot2)
end

function class.initHeals(_aqo)
    table.insert(class.healAbilities, class.spells.heal)
    table.insert(class.healAbilities, class.spells.groupheal)
    table.insert(class.healAbilities, common.getAA('Convergence of Spirits', {panic=true}))
    table.insert(class.healAbilities, common.getAA('Peaceful Convergence of Spirits', {panic=true}))
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
function class.initBurns(_aqo)
    table.insert(class.burnAbilities, common.getAA('Spirits of Nature', {delay=1500}))
    table.insert(class.burnAbilities, common.getAA('Group Spirit of the Black Wolf'))
    table.insert(class.burnAbilities, common.getAA('Nature\'s Guardian'))
    table.insert(class.burnAbilities, common.getAA('Nature\'s Fury'))
    table.insert(class.burnAbilities, common.getAA('Nature\'s Boon'))
    table.insert(class.burnAbilities, common.getAA('Nature\'s Blessing'))
    table.insert(class.burnAbilities, common.getAA('Improved Twincast'))
    table.insert(class.burnAbilities, common.getAA('Fundament: Second Spire of Nature'))
end

function class.initDPSAbilities(_aqo)
    table.insert(class.DPSAbilities, common.getItem('Nature Walker\'s Scimitar'))
    table.insert(class.DPSAbilities, common.getAA('Storm Strike'))
end

function class.initBuffs(_aqo)
    -- Aura of the Grove, Aura of the Grove Effect
    table.insert(class.auras, class.spells.aura)

    table.insert(class.singleBuffs, class.spells.reptile)
    table.insert(class.selfBuffs, class.spells.reptile)
    table.insert(class.selfBuffs, common.getAA('Spirit of the Black Wolf'))
end

return class