---@type Mq
local mq = require('mq')

local cure = {}

-- SPA 35 - disease
-- SPA 36 - poison
-- SPA 116 - curse
-- SPA 369 - corruption

cure.selfCure = function(spell)
    local shouldCast = false
    if spell.HasSPA(35)() and mq.TLO.Me.Diseased() and mq.TLO.Me.CountersDisease() > 0 then
        shouldCast = true
    elseif spell.HasSPA(36)() and mq.TLO.Me.Poisoned() and mq.TLO.Me.CountersPoison() > 0 then
        shouldCast = true
    elseif spell.HasSPA(116)() and mq.TLO.Me.Cursed() and mq.TLO.Me.CountersCurse() > 0 then
        shouldCast = true
    elseif spell.HasSPA(369)() and mq.TLO.Me.Corruption() and mq.TLO.Me.CountersCorruption() > 0 then
        shouldCast = true
    end
    if shouldCast then return spell:use() end
end

local function needsCure(spell, buffTarget)
    if not buffTarget.BuffsPopulated() then
        buffTarget.DoTarget()
        mq.delay(100, function() return mq.TLO.Target.ID() == buffTarget.ID() end)
        mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end)
        buffTarget = mq.TLO.Target
    end
    return not buffTarget.Buff(spell.name)() and mq.TLO.Spell(spell.name).StacksSpawn(buffTarget)
end

cure.singleCure = function(spell, buffTarget)
    if needsCure(spell, buffTarget) then
        return spell:use()
    end
end

cure.groupCure = function(spell)
    local anyoneNeedsCure = false
    if not mq.TLO.Group.GroupSize() then return cure.selfCure(spell) end
    for i=0,mq.TLO.Group.GroupSize()-1 do
        local member = mq.TLO.Group.Member(i)
        if needsCure(spell, member) then
            anyoneNeedsCure = true
        end
    end
    if anyoneNeedsCure then
        return spell:use()
    end
end

cure.setupCureEvents = function(callback)
    mq.event('CureSay', '#1# says, \'Cure Please!\'', callback)
    mq.event('CureGroup', '#1# tells the group, \'Cure Please!\'', callback)
    mq.event('CureRaid', '#1# tells the raid, \'Cure Please!\'', callback)
    mq.event('CureTell', '#1# tells you, \'Cure Please!\'', callback)
end

return cure