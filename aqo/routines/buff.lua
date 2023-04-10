---@type Mq
local mq = require('mq')
local timer = require('utils.timer')
local abilities = require('ability')
local castUtil = require('cast')
local common = require('common')
local state = require('state')

local aqo
local buff = {}

function buff.init(_aqo)
    aqo = _aqo
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

local function summonItem(buff)
    if mq.TLO.FindItemCount(buff.SummonID)() < (buff.summonMinimum or 1) and not mq.TLO.Me.Moving() and (not buff.summonComponent or mq.TLO.FindItemCount(buff.summonComponent)() > 0) then
        if abilities.use(buff) then
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
    if mq.TLO.Me.CombatState() == 'COMBAT' then
        for _,buff in ipairs(base.combatBuffs) do
            if base.isAbilityEnabled(buff.opt) then
                if buff.SummonID then
                    summonItem(buff)
                else
                    local buffName = buff.CheckFor or buff.Name
                    if not haveBuff(buffName) and (not buff.skipifbuff or not mq.TLO.Me.Buff(buff.skipifbuff)()) then
                        abilities.use(buff)
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
            if abilities.use(buff) then return true end
        end
    end
end

local function buffSelf(base)
    local originalTargetID = 0
    local result = false
    for _,buff in ipairs(base.selfBuffs) do
        --[[if buff.CastName then
            local buffName = buff.SpellName
            if state.subscription ~= 'GOLD' then buffName = buff.Name:gsub(' Rk%..*', '') end
            if not haveBuff(buffName) and not haveBuff(buff.CheckFor) and mq.TLO.Spell(buff.CheckFor or buffName).Stacks() and (not buff.nodmz or not aqo.lists.DMZ[mq.TLO.Zone.ID()]) then
                castUtil.cast(buff)
            end
        else]]
            local buffName = buff.Name -- TODO: buff name may not match AA or item name
            if state.subscription ~= 'GOLD' then buffName = buff.Name:gsub(' Rk%..*', '') end
            if buff.SummonID then
                if base.isAbilityEnabled(buff.opt) and (not buff.nodmz or not aqo.lists.DMZ[mq.TLO.Zone.ID()]) then
                    return summonItem(buff)
                end
            else
                if not haveBuff(buffName) and not haveBuff(buff.CheckFor) and mq.TLO.Spell(buff.CheckFor or buff.Name).Stacks() and (not buff.nodmz or not aqo.lists.DMZ[mq.TLO.Zone.ID()]) then
                    if buff.TargetType == 'Single' then mq.TLO.Me.DoTarget() end
                    result = abilities.use(buff, true)
                    if result then
                        if buff.RemoveBuff then
                            state.queuedAction = function()
                                if mq.TLO.Me.Casting() then
                                    return state.queuedAction
                                else
                                    mq.delay(100) mq.cmdf('/removebuff "%s"', buff.RemoveBuff)
                                end
                            end
                        elseif buff.RemoveFamiliar then
                            state.queuedAction = function()
                                if mq.TLO.Me.Casting() then
                                    return state.queuedAction
                                else
                                    if mq.TLO.Pet.ID() > 0 and mq.TLO.Pet.CleanName():find('familiar') then mq.delay(100) mq.cmdf('/squelch /pet get lost') end
                                end
                            end
                        end
                        return result
                    end
                end
            end
        --end
    end
end

local function buffSingle(base)
    local groupSize = mq.TLO.Group.Members() or 0
    for i=1,groupSize do
        local member = mq.TLO.Group.Member(i)
        local memberClass = member.Class.ShortName()
        local memberDistance = member.Distance3D() or 300
        for _,buff in ipairs(base.singleBuffs) do
            if buff.classes[memberClass] and mq.TLO.Me.SpellReady(buff.Name)() and not member.Buff(buff.Name)() and not member.Dead() and memberDistance < 100 then
                member.DoTarget()
                mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end)
                if mq.TLO.Target.ID() == member.ID() and not mq.TLO.Target.Buff(buff.Name)() and mq.TLO.Spell(buff.Name).StacksTarget() then
                    if abilities.use(buff) then return true end
                end
            end
        end
    end
end

local function buffGroup(base)
    for _,aBuff in ipairs(base.groupBuffs) do
        local buffName = aBuff.Name -- TODO: buff name may not match AA or item name
        if state.subscription ~= 'GOLD' then buffName = aBuff.Name:gsub(' Rk%..*', '') end
        if aBuff.CastType == abilities.Types.Spell then
            local anyoneMissing = false
            if not mq.TLO.Group.GroupSize() then
                if not mq.TLO.Me.Buff(buffName)() and not mq.TLO.Me.Song(buffName)() then
                    anyoneMissing = true
                end
            else
                for i=1,mq.TLO.Group.Members() do
                    local member = mq.TLO.Group.Member(i)
                    local distance = member.Distance3D() or 300
                    if buff.needsBuff(aBuff, member) and distance < 100 then
                        anyoneMissing = true
                    end
                end
            end
            if anyoneMissing then
                if common.swapAndCast(aBuff, state.swapGem) then return true end
            end
        elseif aBuff.CastType == abilities.Types.Disc then
            
        elseif aBuff.CastType == abilities.Types.AA then
            buff.groupBuff(aBuff)
        elseif aBuff.CastType == abilities.Types.Item then
            local item = mq.TLO.FindItem(aBuff.ID)
            if not mq.TLO.Me.Buff(item.Spell.Name())() then
                aBuff:use()
            end
        end
    end
end

local function buffOOC(base)
    -- call class specific buff routine for any special cases
    if base.buff_class then
        if base.buff_class() then return true end
    end
    common.checkItemBuffs()
    -- find an actual buff spell that takes time to cast
    if buffAuras(base) then return true end
    if buffSelf(base) then return true end
    if buffSingle(base) then return true end
    --if buff_tank(base) then return true end
    --if buffGroup(base) then return true end

end

local function buffPet(base)
    if base.isEnabled('BUFFPET') and mq.TLO.Pet.ID() > 0 then
        local distance = mq.TLO.Pet.Distance3D() or 300
        if distance > 100 then return false end
        if aqo.class.useCommonListProcessor then
            aqo.common.processList(base.petBuffs, true)
            return
        end
        for _,buff in ipairs(base.petBuffs) do
            local tempName = buff.Name
            if state.subscription ~= 'GOLD' then tempName = tempName:gsub(' Rk%..*', '') end
            if not mq.TLO.Pet.Buff(tempName)() and not mq.TLO.Pet.Buff(buff.CheckFor)() and mq.TLO.Spell(buff.CheckFor or buff.Name).StacksPet() and (not buff.skipifbuff or not mq.TLO.Pet.Buff(buff.skipifbuff)()) then
                if abilities.use(buff) then return end
            end
        end
    end
end

function buff.reportBuffs()
    local buffList = ''
    for i=1,42 do
        local buffID = mq.TLO.Me.Buff(i).Spell.ID()
        if buffID then buffList = buffList .. buffID .. '|' end
    end
    for i=1,20 do
        local songID = mq.TLO.Me.Song(i).Spell.ID()
        if songID then buffList = buffList .. songID .. '|' end
    end
    if buffList ~= '' then
        mq.cmdf('/squelch /dga aqo /squelch /docommand /$\\{Me.Class.ShortName} bufflist %s %s %s', mq.TLO.Me.CleanName(), mq.TLO.Me.Class.ShortName(), buffList)
    end
end

function buff.reportSick()
    local sickList = ''
    if mq.TLO.Me.Poisoned() then
        sickList = sickList .. 'P_' .. mq.TLO.Me.Poisoned() .. '_' .. mq.TLO.Me.CountersPoison() .. '|'
    end
    if mq.TLO.Me.Diseased() then
        sickList = sickList .. 'D_' .. mq.TLO.Me.Diseased() .. '_' .. mq.TLO.Me.CountersDisease() .. '|'
    end
    if mq.TLO.Me.Cursed() then
        sickList = sickList .. 'C_' .. mq.TLO.Me.Cursed() .. '_' .. mq.TLO.Me.CountersCurse() .. '|'
    end
    if sickList ~= '' then
        mq.cmdf('/squelch /dga aqo /squelch /docommand /$\\{Me.Class.ShortName} sicklist %s %s', mq.TLO.Me.CleanName(), sickList)
    end
end

local reportBuffsTimer = timer:new(60000)
local reportSickTimer = timer:new(5000)
function buff.broadcast()
    if reportBuffsTimer:timerExpired() then
        aqo.buff.reportBuffs()
        reportBuffsTimer:reset()
    end
    if reportSickTimer:timerExpired() then
        aqo.buff.reportSick()
        reportSickTimer:reset()
    end
end

local checkClickiesLoadedTimer = timer:new(300000)
local function checkClickiesLoaded(base)
    if checkClickiesLoadedTimer:timerExpired() then
        for clickyName,clickyType in pairs(base.clickies) do
            local t = base.getTableForClicky(clickyType)
            if t then
                local found = false
                for _,clicky in ipairs(t) do
                    if clicky.name == clickyName then
                        found = true
                        break
                    end
                end
                if not found then
                    base.addClicky({name=clickyName, clickyType=clickyType})
                end
            end
        end
        checkClickiesLoadedTimer:reset()
    end
end

local buffOOCTimer = timer:new(3000)
function buff.buff(base)
    checkClickiesLoaded(base)
    if buffCombat(base) then return true end

    if not common.clearToBuff() or not buffOOCTimer:timerExpired() or mq.TLO.Me.Moving() then return end
    buffOOCTimer:reset()
    local originalTargetID = mq.TLO.Target.ID()

    if buffOOC(base) or buffPet(base) then
        local action = state.queuedAction
        state.queuedAction = function()
            local targetID = mq.TLO.Target.ID()
            if targetID ~= 0 and originalTargetID ~= targetID then mq.cmd('/squelch /mqt clear') else mq.cmdf('/squelch /mqt id %s', originalTargetID) end
            return action
        end
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