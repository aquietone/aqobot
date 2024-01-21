---@type Mq
local mq = require('mq')
local assist = require('routines.assist')
local logger = require('utils.logger')
local timer = require('utils.timer')
local abilities = require('ability')
local common = require('common')
local constants = require('constants')
local state = require('state')

local class
local buff = {}

function buff.init(_class)
    class = _class
end

function buff.needsBuff(spell, buffTarget)
    if not buffTarget.BuffsPopulated() then
        buffTarget.DoTarget()
        mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end)
        buffTarget = mq.TLO.Target
    end
    return not buffTarget.Buff(spell.Name)() and mq.TLO.Spell(spell.Name).StacksSpawn(buffTarget.ID())() and (buffTarget.Distance3D() or 300) < 100
end

local function haveBuff(buffName)
    return buffName and (mq.TLO.Me.Buff(buffName)() or mq.TLO.Me.Song(buffName)())
end

local function summonItem(buff, base)
    if ((buff.summonMinimum or 1) < 0 or mq.TLO.FindItemCount(buff.SummonID)() < (buff.summonMinimum or 1)) and not mq.TLO.Me.Moving()
            and (not buff.ReagentID or mq.TLO.FindItemCount(buff.ReagentID)() >= buff.ReagentCount) then
        if abilities.use(buff, base) then
            state.queuedAction = function() mq.cmd('/autoinv') end
            return true
        end
    end
end

local buffCombatTimer = timer:new(3000)
local function buffCombat(base)
    if not buffCombatTimer:timerExpired() then return end
    buffCombatTimer:reset()
    -- common clicky buffs like geomantra and ... just geomantra
    common.checkCombatBuffs()
    -- typically instant disc buffs like war field champion, etc. or summoning arrows
    if assist.isFighting() then
        for _,buff in ipairs(base.combatBuffs) do
            if base:isAbilityEnabled(buff.opt) then
                if buff.SummonID then
                    summonItem(buff)
                else
                    local buffName = buff.CheckFor or buff.Name
                    if not haveBuff(buffName) and (not buff.skipifbuff or not mq.TLO.Me.Buff(buff.skipifbuff)()) then
                        abilities.use(buff, base)
                    end
                end
            end
        end
    end
end

local function buffAuras(base)
    for _,buff in ipairs(base.auras) do
        local buffName = buff.Name
        if state.subscription ~= 'GOLD' then buffName = buff.Name:gsub(' Rk%..*', '') end
        if not mq.TLO.Me.Aura(buff.CheckFor)() and not mq.TLO.Me.Song(buffName)() then
            if abilities.use(buff, base) then return true end
        end
    end
end

local function buffSelf(base)
    local result = false
    for _,buff in ipairs(base.selfBuffs) do
        local buffName = buff.Name -- TODO: buff name may not match AA or item name
        if state.subscription ~= 'GOLD' then buffName = buff.Name:gsub(' Rk%..*', '') end
        if buff.SummonID then
            if base:isAbilityEnabled(buff.opt) and (not buff.nodmz or not constants.DMZ[mq.TLO.Zone.ID()]) then
                return summonItem(buff, base)
            end
        else
            local canCast = abilities.IsReady.CAN_CAST
            if buff.CastType == abilities.Types.Spell then
                local spell = mq.TLO.Spell(buff.Name)
                canCast = abilities.canUseSpell(spell, buff)
            end
            if canCast == abilities.IsReady.CAN_CAST and not haveBuff(buffName) and not haveBuff(buff.CheckFor) and mq.TLO.Spell(buff.CheckFor or buff.Name).Stacks() and (not buff.nodmz or not constants.DMZ[mq.TLO.Zone.ID()]) then
                if buff.TargetType == 'Single' then mq.TLO.Me.DoTarget() end
                result = abilities.use(buff, base, true)
                if result then
                    if buff.RemoveBuff then
                        state.queuedAction = function()
                            if mq.TLO.Me.Casting() then
                                return state.queuedAction
                            else
                                mq.delay(100, function() return mq.TLO.Me.Buff(buff.RemoveBuff)() end)
                                if mq.TLO.Me.Buff(buff.RemoveBuff)() then
                                    logger.info('Removing buff \ag%s\ax', buff.RemoveBuff)
                                    mq.cmdf('/removebuff "%s"', buff.RemoveBuff)
                                end
                            end
                        end
                    elseif buff.RemoveFamiliar then
                        state.giveUpTimer = timer:new(5000)
                        state.queuedAction = function()
                            if mq.TLO.Me.Casting() or mq.TLO.Pet.ID() == 0 then
                                if state.giveUpTimer:timerExpired() then state.giveUpTimer = nil return nil end
                                return state.queuedAction
                            else
                                if mq.TLO.Pet.ID() > 0 and (mq.TLO.Pet.Level() == 1 or mq.TLO.Pet.CleanName():find('familiar')) then
                                    logger.info('Removing familiar')
                                    mq.cmdf('/squelch /pet get lost')
                                end
                            end
                        end
                    end
                    return result
                end
            end
        end
    end
end

-- buff group members, not necessarily your own characters
local function buffSingle(base)
    local groupSize = mq.TLO.Group.Members() or 0
    for i=1,groupSize do
        local member = mq.TLO.Group.Member(i)
        local memberClass = member.Class.ShortName()
        local memberDistance = member.Distance3D() or 300
        for _,buff in ipairs(base.singleBuffs) do
            local canCast = abilities.IsReady.CAN_CAST
            if buff.CastType == abilities.Types.Spell then
                local spell = mq.TLO.Spell(buff.Name)
                canCast = abilities.canUseSpell(spell, buff)
            end
            if (canCast == abilities.IsReady.CAN_CAST and not buff.classes or buff.classes[memberClass]) and mq.TLO.Me.SpellReady(buff.Name)() and not member.Buff(buff.Name)() and not member.Dead() and memberDistance < 100 then
                member.DoTarget()
                mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end)
                if mq.TLO.Target.ID() == member.ID() and not mq.TLO.Target.Buff(buff.Name)() and mq.TLO.Spell(buff.Name).StacksTarget() then
                    if abilities.use(buff, base, true) then return true end
                end
            end
        end
    end
end

-- buff characters on the same post office
local function buffActors(base)
    local availableBuffs = base:getRequestAliases()
    for name, charState in pairs(state.actors) do
        local wantBuffs = charState.wantBuffs
        if wantBuffs then
            for _,buff in ipairs(wantBuffs) do
                if availableBuffs[buff] then
                    --logger.info('Can cast buff %s for %s', availableBuffs[buff], name)
                    local spawn = mq.TLO.Spawn('pc ='..name..' radius 150')
                    spawn.DoTarget()
                    mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end)
                    if mq.TLO.Target.ID() == spawn.ID() and not mq.TLO.Target.Buff(availableBuffs[buff])() then
                        if abilities.use(base:getAbilityForAlias(buff), base, true) then return true end
                    end
                end
            end
        end
    end
end

local function buffOOC(base)
    common.checkItemBuffs()
    if mq.TLO.SpawnCount('pccorpse radius 25')() > 0 then return false end
    -- find an actual buff spell that takes time to cast
    if buffAuras(base) then return true end
    if buffSelf(base) then return true end
    if buffActors(base) then return true end
    if buffSingle(base) then return true end
end

local function buffPet(base)
    if base:isEnabled('BUFFPET') and mq.TLO.Pet.ID() > 0 then
        local distance = mq.TLO.Pet.Distance3D() or 300
        if distance > 100 then return false end
        if class.useCommonListProcessor then
            common.processList(base.petBuffs, base, true)
            return
        end
        for _,buff in ipairs(base.petBuffs) do
            local tempName = buff.Name
            if state.subscription ~= 'GOLD' then tempName = tempName:gsub(' Rk%..*', '') end
            if not mq.TLO.Pet.Buff(tempName)() and not mq.TLO.Pet.Buff(buff.CheckFor)() and mq.TLO.Spell(buff.CheckFor or buff.Name).StacksPet() and (not buff.skipifbuff or not mq.TLO.Pet.Buff(buff.skipifbuff)()) then
                if abilities.use(buff, base, true) then return end
            end
        end
    end
end

local checkClickiesLoadedTimer = timer:new(300000)
local function checkClickiesLoaded(base)
    if checkClickiesLoadedTimer:timerExpired() then
        for clickyName,clicky in pairs(base.clickies) do
            local t = base:getTableForClicky(clicky.clickyType)
            if t then
                local found = false
                for _,clicky in ipairs(t) do
                    if clicky.CastName == clickyName then
                        found = true
                        break
                    end
                end
                if not found then
                    base:addClicky({name=clickyName, clickyType=clicky.clickyType, summonMinimum=clicky.summonMinimum, opt=clicky.opt, enabled=clicky.enabled})
                end
            end
        end
        checkClickiesLoadedTimer:reset()
    end
end

local buffOOCTimer = timer:new(3000)
function buff.buff(base)
    if not state.justZonedTimer:timerExpired() then return false end
    checkClickiesLoaded(base)
    if buffCombat(base) then return true end

    if not common.clearToBuff() or not buffOOCTimer:timerExpired() or mq.TLO.Me.Moving() then return end
    buffOOCTimer:reset()
    local originalTargetID = mq.TLO.Target.ID()

    if buffOOC(base) or buffPet(base) then
        state.reacquireTargetID = originalTargetID > 0 and originalTargetID or nil
        return true
    end

    common.checkItemBuffs()
end

function buff.setupBegEvents(callback)
    mq.event('BegSay', '#1# says, \'Buffs Please!\'', callback)
    mq.event('BegGroup', '#1# tells the group, \'Buffs Please!\'', callback)
    mq.event('BegRaid', '#1# tells the raid, \'Buffs Please!\'', callback)
    mq.event('BegTell', '#1# tells you, \'Buffs Please!\'', callback)
end

return buff