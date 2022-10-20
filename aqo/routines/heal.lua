local mq = require('mq')
local Abilities = require(AQO..'.ability')
local common = require(AQO..'.common')
local config = require(AQO..'.configuration')
local timer = require(AQO..'.utils.timer')

local healing = {}

local HEAL_TYPES = {
    GROUP='group',
    HOT='hot',
    PANIC='panic',
    REGULAR='regular',
}

local tankClasses = {WAR=true,PAL=true,SHD=true}
local melees = {MNK=true,BER=true,ROG=true,BST=true,WAR=true,PAL=true,SHD=true,RNG=true}
local hottimers = {}

local function healEnabled(opts, key)
    return opts[key] and opts[key].value
end


--[[
    1. Determine who to heal:
        a. self very hurt -- self,panic
        b. tank very hurt -- tank,panic
        c. other very hurt -- other,panic
        d. multiple hurt -- group
        e. self hurt -- self,regular
        f. tank hurt -- tank,regular
        g. other hurt -- other,regular
        h. melee hot
        i. xtargets
    2. Determine heal to use
        a. panic
        b. group
        c. regular
]]
-- returns:
-- me.ID, 'panic'
-- me.ID, 'regular'
-- tank.ID, 'panic'
-- member.ID, 'regular'
-- 'group', 'regular'
local function getHurt(opts)
    local numHurt = 0
    local mostHurtName = nil
    local mostHurtID = 0
    local mostHurtPct = 100
    local mostHurtClass = nil
    local mostHurtDistance = 300
    local myHP = mq.TLO.Me.PctHPs()
    if myHP < config.PANICHEALPCT then
        return mq.TLO.Me.ID(), HEAL_TYPES.PANIC
    elseif myHP < config.HOTHEALPCT then
        mostHurtName = mq.TLO.Me.CleanName()
        mostHurtID = mq.TLO.Me.ID()
        mostHurtPct = myHP
        mostHurtClass = mq.TLO.Me.Class.ShortName()
        mostHurtDistance = 0
        if myHP < config.HEALPCT then numHurt = numHurt + 1 end
    end
    local tank = mq.TLO.Group.MainTank
    if not tank() then
        tank = mq.TLO.Group.MainAssist
    end
    if tank() and not tank.Dead() then
        local tankHP = tank.PctHPs() or 100
        local distance = tank.Distance3D() or 300
        if tankHP < config.PANICHEALPCT and distance < 200 then return tank.ID(), HEAL_TYPES.PANIC end
    end
    if healEnabled(opts, 'HEALPET') and mq.TLO.Pet.ID() > 0 then
        local memberPetHP = mq.TLO.Pet.PctHPs() or 100
        local memberPetDistance = mq.TLO.Pet.Distance3D() or 300
        if memberPetHP < 60 and memberPetDistance < 200 then
            mostHurtName = mq.TLO.Pet.CleanName()
            mostHurtID = mq.TLO.Pet.ID()
            mostHurtPct = memberPetHP
            mostHurtClass = nil
            mostHurtDistance = memberPetDistance
        end
    end
    local groupSize = mq.TLO.Group.GroupSize()
    if groupSize then
        for i=1,groupSize-1 do
            local member = mq.TLO.Group.Member(i)
            if not member.Dead() then
                local memberHP = member.PctHPs() or 100
                local distance = member.Distance3D() or 300
                if memberHP < config.HOTHEALPCT and distance < 200 then
                    if memberHP < mostHurtPct then
                        mostHurtName = member.CleanName()
                        mostHurtID = member.ID()
                        mostHurtPct = memberHP
                        mostHurtClass = member.Class.ShortName()
                        mostHurtDistance = distance
                    end
                    if memberHP < config.GROUPHEALPCT and distance < 80 then numHurt = numHurt + 1 end
                    -- work around lazarus Group.MainTank never working, tank just a group member
                    if tankClasses[member.Class.ShortName()] and memberHP < config.PANICHEALPCT and distance < 200 then
                        return member.ID(), HEAL_TYPES.PANIC
                    end
                end
                if healEnabled(opts, 'HEALPET') then
                    local memberPetHP = member.Pet.PctHPs() or 100
                    local memberPetDistance = member.Pet.Distance3D() or 300
                    if memberPetHP < config.HEALPCT and memberPetDistance < 200 then
                        mostHurtName = member.Pet.CleanName()
                        mostHurtID = member.Pet.ID()
                        mostHurtPct = memberPetHP
                        mostHurtClass = nil
                        mostHurtDistance = memberPetDistance
                    end
                end
            end
        end
    end
    if mostHurtPct < config.PANICHEALPCT then
        return mostHurtID, HEAL_TYPES.PANIC
    elseif numHurt > config.GROUPHEALMIN then
        return nil, HEAL_TYPES.GROUP
    elseif mostHurtPct < config.HEALPCT and mostHurtDistance < 200 then
        return mostHurtID, HEAL_TYPES.REGULAR
    elseif mostHurtPct < config.HOTHEALPCT and melees[mostHurtClass] and mostHurtDistance < 100 then
        local hotTimer = hottimers[mostHurtName]
        if (not hotTimer or hotTimer:timer_expired()) then
            return mostHurtID, HEAL_TYPES.HOT
        end
    end
    if healEnabled(opts, 'XTARGETHEAL') then
        mostHurtPct = 100
        for i=1,13 do
            local xtarSpawn = mq.TLO.Me.XTarget(i)
            local xtarType = xtarSpawn.Type()
            if xtarType == 'PC' or xtarType == 'Pet' then
                local xtargetHP = xtarSpawn.PctHPs() or 100
                local xtarDistance = xtarSpawn.Distance3D() or 300
                if xtargetHP < config.HOTHEALPCT and xtarDistance < 200 then
                    if xtargetHP < mostHurtPct then
                        mostHurtName = xtarSpawn.CleanName()
                        mostHurtID = xtarSpawn.ID()
                        mostHurtPct = xtargetHP
                        mostHurtClass = xtarSpawn.Class.ShortName()
                        mostHurtDistance = xtarDistance
                    end
                end
            end
        end
        if mostHurtPct < config.PANICHEALPCT then
            return mostHurtID, HEAL_TYPES.PANIC
        elseif mostHurtPct < config.HEALPCT and mostHurtDistance < 200 then
            return mostHurtID, HEAL_TYPES.REGULAR
        elseif mostHurtPct < config.HOTHEALPCT and melees[mostHurtClass] and mostHurtDistance < 100 then
            local hotTimer = hottimers[mostHurtName]
            if (not hotTimer or hotTimer:timer_expired()) then
                return mostHurtID, HEAL_TYPES.HOT
            end
        end
    end
end

local function getHeal(healAbilities, healType)
    for _,heal in ipairs(healAbilities) do
        if heal[healType] then
            if heal.type == Abilities.Types.Spell then
                local spell = mq.TLO.Spell(heal.name)
                if Abilities.canUseSpell(spell, heal.type) then
                    return heal
                end
            elseif heal.type == Abilities.Types.Item then
                local theItem = mq.TLO.FindItem(heal.id)
                if heal:isReady(theItem) then return heal end
            else
                if heal:isReady() then return heal end
            end
        end
    end
end

healing.heal = function(healAbilities, opts)
    if common.am_i_dead() then return end
    local whoToHeal, typeOfHeal = getHurt(opts)
    if typeOfHeal == HEAL_TYPES.HOT and not healEnabled(opts, 'USEHOT') then return end
    local healToUse = getHeal(healAbilities, typeOfHeal)
    if healToUse then
        if whoToHeal and mq.TLO.Target.ID() ~= whoToHeal then
            mq.cmdf('/mqt id %s', whoToHeal)
        end
        healToUse:use()
        if typeOfHeal == HEAL_TYPES.HOT then
            local targetName = mq.TLO.Target.CleanName()
            local hotTimer = hottimers[targetName]
            if not hotTimer then
                hottimers[targetName] = timer:new(24)
                hottimers[targetName]:reset()
            else
                hotTimer:reset()
            end
        end
    end
end

healing.healPetOrSelf = function(healAbilities, opts)
    if common.am_i_dead() then return end
    local myHP = mq.TLO.Me.PctHPs()
    local petHP = mq.TLO.Pet.PctHPs() or 100
    if myHP < 60 then healing.healSelf(healAbilities, opts) end
    if not healEnabled(opts, 'HEALPET') then return end
    for _,heal in ipairs(healAbilities) do
        if heal.pet and petHP < heal.pet then
            if heal.type == Abilities.Types.Spell then
                local spell = mq.TLO.Spell(heal.name)
                if Abilities.canUseSpell(spell, heal.type) then
                    heal:use()
                    return
                end
            else
                if heal:isReady() then
                    heal:use()
                    return
                end
            end
        end
    end
end

healing.healSelf = function(healAbilities, opts)
    if common.am_i_dead() or mq.TLO.Me.PctHPs() > 60 then return end
    for _,heal in ipairs(healAbilities) do
        if heal.self then
            if heal.type == Abilities.Types.Spell then
                local spell = mq.TLO.Spell(heal.name)
                if Abilities.canUseSpell(spell, heal.type) then
                    local targetID = mq.TLO.Target.ID()
                    if spell.TargetType() == 'Single' and targetID ~= mq.TLO.Me.ID() then
                        mq.TLO.Me.DoTarget()
                        mq.delay(100, function() return mq.TLO.Target.ID() == mq.TLO.Me.ID() end)
                    end
                    heal:use()
                    if targetID ~= mq.TLO.Target.ID() then mq.cmdf('/mqt id %s', targetID) end
                    return
                end
            else
                if heal:isReady() then
                    local targetID = mq.TLO.Target.ID()
                    if heal.type == Abilities.Types.AA then
                        local spell = mq.TLO.AltAbility(heal.name).Spell
                        if spell.TargetType() == 'Single' and targetID ~= mq.TLO.Me.ID() then
                            mq.TLO.Me.DoTarget()
                            mq.delay(100, function() return mq.TLO.Target.ID() == mq.TLO.Me.ID() end)
                        end
                    end
                    heal:use()
                    if targetID ~= mq.TLO.Target.ID() then mq.cmdf('/mqt id %s', targetID) end
                    return
                end
            end
        end
    end
end

return healing