--- @type Mq
local mq = require('mq')
local config = require('configuration')

local aqo
local conditions = {}

function conditions.init(_aqo)
    aqo = _aqo
end

---@field delay? number # time in MS to delay after using an ability, primarily for swarm pets that take time to spawn after activation
---@field me? number # ignored currently. should be % hp to use self heal abilities since non-heal classes don't expose healer options
---@field pet? number # percent HP to begin casting pet heal
---@field self? boolean # indicates the heal ability is a self heal, like monk mend
---@field regular? boolean # flag to indicate heal should be used as a regular heal
---@field panic? boolean # flag to indicate heal should be used as a panic heal
---@field group? boolean # flag to indicate heal should be used as a group heal
---@field precast? string # function to call prior to using an ability
---@field postcast? string # function to call after to using an ability
---@field overwritedisc? string # name of disc which is acceptable to overwrite
---@field stand? boolean # flag to indicate if should stand after use, for FD dropping agro
---@field tot? boolean # flag to indicate if spell is target-of-target
---@field RemoveBuff? string # name of buff / song to remove after cast

function conditions.isEnabled(ability)
    return not ability.opt or aqo.class.isEnabled(ability.opt)
end

-- Heal Ability conditions

function conditions.spawnBelowHealPct(spawn)
    return (spawn.PctHPs() or 100) < config.get('HEALPCT')
end

function conditions.spawnBelowPanicHealPct(spawn)
    return (spawn.PctHPs() or 100) < config.get('PANICHEALPCT')
end

function conditions.spawnBelowGroupHealPct(spawn)
    return (spawn.PctHPs() or 100) < config.get('GROUPHEALPCT')
end

function conditions.spawnBelowHoTHealPct(spawn)
    return (spawn.PctHPs() or 100) < config.get('HOTHEALPCT')
end

-- Buff Ability conditions

function conditions.classesTarget(ability)
    return conditions.classes(ability, mq.TLO.Target)
end

function conditions.classes(ability, spawn)
    return not ability.classes or ability.classes[spawn.Class.ShortName()]
end

function conditions.missingPetCheckFor(ability)
    return not mq.TLO.Pet.Buff(ability.CheckFor)()
end

function conditions.missingPetBuff(ability)
    return not mq.TLO.Pet.Buff(ability.Name)()
end

function conditions.missingBuff(ability)
    return not conditions.hasBuff(ability)
end

function conditions.hasBuff(ability)
    return mq.TLO.Me.Buff(ability.Name)() or mq.TLO.Me.Song(ability.Name)()
end

function conditions.missingCheckFor(ability)
    return not conditions.checkFor(ability)
end

function conditions.checkFor(ability)
    return not ability.CheckFor or mq.TLO.Me.Buff(ability.CheckFor)() or mq.TLO.Me.Song(ability.CheckFor)()
end

function conditions.skipIfBuff(ability)
    return not ability.skipifbuff or not (mq.TLO.Me.Buff(ability.skipifbuff)() or mq.TLO.Me.Song(ability.skipifbuff)())
end

function conditions.dmz(ability)
    return not ability.dmz or aqo.lists.DMZ[mq.TLO.Zone.ID()]
end

function conditions.summonMinimum(ability)
    return not ability.summonMinimum or mq.TLO.FindItemCount(ability.SummonID)() < ability.summonMinimum
end

function conditions.stacksPet(ability)
    return not mq.TLO.Pet.Buff(ability.Name)() and mq.TLO.Spell(ability.Name).StacksPet()
end

function conditions.checkMana(ability)
    return mq.TLO.Me.CurrentMana() >= mq.TLO.Spell(ability.Name).Mana()
end

-- Recover Ability conditions

function conditions.aboveMinHP(ability)
    return not ability.minhp or mq.TLO.Me.PctHPs() > ability.minhp
end

-- TODO: define hpbelow
function conditions.belowDesiredHP(ability)
    return not ability.hpbelow or mq.TLO.Me.PctHPs() < ability.hpbelow
end

-- TODO: define manabelow
function conditions.belowDesiredMana(ability)
    return not ability.manabelow or mq.TLO.Me.PctMana() < ability.manabelow
end

-- TODO: define endbelow
function conditions.belowDesiredEndurance(ability)
    return not ability.endbelow or mq.TLO.Me.PctEndurance() < ability.endbelow
end

function conditions.inCombat(ability)
    return not ability.combat or mq.TLO.Me.CombatState() == 'COMBAT'
end

function conditions.OOC(ability)
    local combatState = mq.TLO.Me.CombatState()
    return not ability.ooc or combatState == 'ACTIVE' or combatState == 'RESTING'
end

-- DPS Ability conditions

function conditions.burnType(ability)
    return not aqo.state.burn_type or ability[aqo.state.burn_type]
end

function conditions.targetHPBelow(ability)
    local targetHP = mq.TLO.Target.PctHPs() or 100
    return not ability.usebelowpct or targetHP <= ability.usebelowpct
end

function conditions.withinMaxDistance(ability)
    local targetDistance = mq.TLO.Target.Distance3D() or 300
    return not ability.maxdistance or targetDistance <= ability.maxdistance
end

function conditions.withinMeleeDistance(ability)
    local targetDistance = mq.TLO.Target.Distance3D() or 300
    local targetMaxRange  = mq.TLO.Target.MaxRangeTo() or 0
    return targetDistance <= targetMaxRange
end

function conditions.aboveMobThreshold(ability)
    return ability.threshold == nil or ability.threshold <= aqo.state.mobCountNoPets
end

function conditions.aggroBelow(ability)
    local aggropct = mq.TLO.Target.PctAggro() or 100
    return ability.aggro == nil or aggropct < 100
end

return conditions