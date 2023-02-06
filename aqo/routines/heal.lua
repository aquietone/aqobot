--- @type Mq
local mq = require('mq')
local timer = require('utils.timer')
local Abilities = require('ability')
local config = require('configuration')
local state = require('state')

local healing = {}

function healing.init(aqo)

end

local HEAL_TYPES = {
    GROUP='group',
    HOT='hot',
    PANIC='panic',
    REGULAR='regular',
    TANK='tank',
    GROUPHOT='grouphot',
}

local tankClasses = {WAR=true,PAL=true,SHD=true}
local melees = {MNK=true,BER=true,ROG=true,BST=true,WAR=true,PAL=true,SHD=true,RNG=true}
local hottimers = {}
local reztimer = timer:new(30)

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
    local myHP = state.loop.PctHPs
    if myHP < config.PANICHEALPCT.value then
        return state.loop.ID, HEAL_TYPES.PANIC
    elseif myHP < config.HOTHEALPCT.value then
        mostHurtName = mq.TLO.Me.CleanName()
        mostHurtID = state.loop.ID
        mostHurtPct = myHP
        mostHurtClass = mq.TLO.Me.Class.ShortName()
        mostHurtDistance = 0
        if myHP < config.HEALPCT.value then numHurt = numHurt + 1 end
    end
    local tank = mq.TLO.Group.MainTank
    if not tank() and config.PRIORITYTARGET.value:len() > 0 then
        tank = mq.TLO.Spawn('='..config.PRIORITYTARGET.value)
    end
    if tank() and not tank.Dead() then
        local tankHP = tank.PctHPs() or 100
        local distance = tank.Distance3D() or 300
        if tankHP < config.PANICHEALPCT.value and distance < 200 then return tank.ID(), HEAL_TYPES.PANIC end
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
                if memberHP < config.HOTHEALPCT.value and distance < 200 then
                    if memberHP < mostHurtPct then
                        mostHurtName = member.CleanName()
                        mostHurtID = member.ID()
                        mostHurtPct = memberHP
                        mostHurtClass = member.Class.ShortName()
                        mostHurtDistance = distance
                    end
                    if memberHP < config.GROUPHEALPCT.value and distance < 80 then numHurt = numHurt + 1 end
                    -- work around lazarus Group.MainTank never working, tank just a group member
                    if tankClasses[member.Class.ShortName()] and memberHP < config.PANICHEALPCT.value and distance < 200 then
                        return member.ID(), HEAL_TYPES.PANIC
                    end
                end
                if healEnabled(opts, 'HEALPET') then
                    local memberPetHP = member.Pet.PctHPs() or 100
                    local memberPetDistance = member.Pet.Distance3D() or 300
                    if memberPetHP < config.HEALPCT.value and memberPetDistance < 200 then
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
    if mostHurtPct < config.PANICHEALPCT.value then
        return mostHurtID, HEAL_TYPES.PANIC
    elseif numHurt > config.GROUPHEALMIN.value then
        return nil, HEAL_TYPES.GROUP
    elseif mostHurtPct < config.HEALPCT.value and mostHurtDistance < 200 then
        return mostHurtID, ((tankClasses[mostHurtClass] or mostHurtName==config.PRIORITYTARGET.value) and HEAL_TYPES.TANK) or HEAL_TYPES.REGULAR
    elseif mostHurtPct < config.HOTHEALPCT.value and melees[mostHurtClass] and mostHurtDistance < 100 then
        local hotTimer = hottimers[mostHurtName]
        if (not hotTimer or hotTimer:timerExpired()) then
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
                if xtargetHP < config.HOTHEALPCT.value and xtarDistance < 200 then
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
        if mostHurtPct < config.PANICHEALPCT.value then
            return mostHurtID, HEAL_TYPES.PANIC
        elseif mostHurtPct < config.HEALPCT.value and mostHurtDistance < 200 then
            return mostHurtID, HEAL_TYPES.REGULAR
        elseif mostHurtPct < config.HOTHEALPCT.value and melees[mostHurtClass] and mostHurtDistance < 100 then
            local hotTimer = hottimers[mostHurtName]
            if (not hotTimer or hotTimer:timerExpired()) then
                return mostHurtID, HEAL_TYPES.HOT
            end
        end
    end
    return nil, HEAL_TYPES.GROUPHOT
end

local groupHOTTimer = timer:new(60)
local function getHeal(healAbilities, healType, whoToHeal)
    for _,heal in ipairs(healAbilities) do
        if heal[healType] then
            if not heal.tot or (mq.TLO.Me.CombatState() == 'COMBAT' and whoToHeal ~= state.loop.ID) then
                if healType == HEAL_TYPES.GROUPHOT then
                    if mq.TLO.Me.CombatState() == 'COMBAT' and groupHOTTimer:timerExpired() and not mq.TLO.Me.Song(heal.name)() and heal:isReady() then return heal end
                elseif heal.type == Abilities.Types.Spell then
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
end

function healing.heal(healAbilities, opts)
    local whoToHeal, typeOfHeal = getHurt(opts)
    if typeOfHeal == HEAL_TYPES.HOT and not healEnabled(opts, 'USEHOT') then return end
    if typeOfHeal == HEAL_TYPES.GROUPHOT and not healEnabled(opts, 'USEGROUPHOT') then return end
    local healToUse = getHeal(healAbilities, typeOfHeal, whoToHeal)
    if healToUse then
        if whoToHeal and mq.TLO.Target.ID() ~= whoToHeal then
            mq.cmdf('/mqt id %s', whoToHeal)
        end
        healToUse:use()
        if typeOfHeal == HEAL_TYPES.HOT then
            local targetName = mq.TLO.Target.CleanName()
            if not targetName then return end
            local hotTimer = hottimers[targetName]
            if not hotTimer then
                hottimers[targetName] = timer:new(60)
                hottimers[targetName]:reset()
            else
                hotTimer:reset()
            end
        end
    end
end

function healing.healPetOrSelf(healAbilities, opts)
    local myHP = state.loop.PctHPs
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

function healing.healSelf(healAbilities, opts)
    if state.loop.PctHPs > 60 then return end
    for _,heal in ipairs(healAbilities) do
        if heal.self then
            if heal.type == Abilities.Types.Spell then
                local spell = mq.TLO.Spell(heal.name)
                if Abilities.canUseSpell(spell, heal.type) then
                    local targetID = mq.TLO.Target.ID()
                    if spell.TargetType() == 'Single' and targetID ~= state.loop.ID then
                        mq.TLO.Me.DoTarget()
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
                        if spell.TargetType() == 'Single' and targetID ~= state.loop.ID then
                            mq.TLO.Me.DoTarget()
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

local function doRezFor(rezAbility)
    local corpse = mq.TLO.Spawn('pccorpse tank radius 100 noalert 0')
    if not corpse() then
        corpse = mq.TLO.Spawn('pccorpse healer radius 100 noalert 0')
        if not corpse() then
            corpse = mq.TLO.Spawn('pccorpse radius 100 noalert 0')
            if not corpse() then
                return false
            end
        end
    end
    local corpseName = corpse.Name()
    if not corpseName then return false end
    corpseName = corpseName:gsub('\'s corpse.*', '')
    if (config.REZGROUP.value and mq.TLO.Group.Member(corpseName)()) or (config.REZRAID.value and mq.TLO.Raid.Member(corpseName)()) then
        corpse.DoTarget()
        if mq.TLO.Target.Type() == 'Corpse' then
            mq.cmd('/keypress CONSIDER')
            mq.delay(100)
            mq.doevents('eventCannotRez')
            if state.cannotRez then
                --mq.cmdf('/squelch /alert add 0 corpse "%s"', corpse.CleanName())
                mq.cmdf('/squelch /alert add 0 id %s', corpse.ID())
                state.cannotRez = nil
                reztimer:reset()
                return false
            end
            mq.cmd('/corpse')
            mq.delay(50)
            rezAbility:use()
            if not rezAbility:isReady() then
                --mq.cmdf('/squelch /alert add 0 corpse "%s"', corpse.CleanName())
                mq.cmdf('/squelch /alert add 0 id %s', corpse.ID())
                reztimer:reset()
                return true
            end
        end
    end
end

local rezCheckTimer = timer:new(3)
function healing.rez(rezAbility)
    if not rezCheckTimer:timerExpired() or not rezAbility then return end
    rezCheckTimer:reset()
    if not config.REZINCOMBAT.value and mq.TLO.Me.CombatState() == 'COMBAT' then return end
    if rezAbility.type == Abilities.Types.AA and not mq.TLO.Me.AltAbilityReady(rezAbility.name)() then return
    elseif rezAbility.type == Abilities.Types.Spell and not mq.TLO.Me.SpellReady(rezAbility.name)() then return
    elseif rezAbility.type == Abilities.Types.Item and not mq.TLO.Me.ItemReady(rezAbility.name)() then return end
    if mq.TLO.Me.Class.ShortName() == 'NEC' and mq.TLO.FindItemCount('=Essence Emerald')() == 0 then return end
    if rezAbility.name == 'Token of Resurrection' and mq.TLO.FindItemCount('=Token of Resurrection')() == 0 then return end
    if reztimer:timerExpired() and mq.TLO.Alert(0)() then mq.cmd('/squelch /alert clear 0') end
    return doRezFor(rezAbility)
end

return healing