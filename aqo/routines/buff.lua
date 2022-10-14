---@type Mq
local mq = require('mq')

local buff = {}

buff.selfBuff = function(spell)
    if not mq.TLO.Me.Buff(spell.name)() and mq.TLO.Spell(spell.name).Stacks() then
        if mq.TLO.Spell(spell.name).TargetType() == 'Single' then
            mq.cmd('/mqtarget myself')
            mq.delay(100, function() return mq.TLO.Target.ID() == mq.TLO.Me.ID() end)
        end
        return spell:use()
    end
end

buff.needsBuff = function(spell, buffTarget)
    if not buffTarget.BuffsPopulated() then
        buffTarget.DoTarget()
        mq.delay(100, function() return mq.TLO.Target.ID() == buffTarget.ID() end)
        mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end)
        buffTarget = mq.TLO.Target
    end
    return not buffTarget.Buff(spell.name)() and mq.TLO.Spell(spell.name).StacksSpawn(buffTarget.ID())() and (buffTarget.Distance3D() or 300) < 100
end

buff.singleBuff = function(spell, buffTarget)
    if buff.needsBuff(spell, buffTarget) then
        return spell:use()
    end
end

buff.groupBuff = function(spell)
    local anyoneMissing = false
    if not mq.TLO.Group.GroupSize() then return buff.selfBuff(spell) end
    for i=1,mq.TLO.Group.GroupSize()-1 do
        local member = mq.TLO.Group.Member(i)
        if buff.needsBuff(spell, member) then
            anyoneMissing = true
        end
    end
    if anyoneMissing then
        return spell:use()
    end
end

buff.petBuff = function(spell)
    if mq.TLO.Pet.ID() > 0 and not mq.TLO.Pet.Buff(spell.name) and mq.TLO.Spell(spell.name).StacksPet() then
        -- Do we need to target the pet..
        -- Do we need to buff others pets..
        return spell:use()
    end
end

buff.setupBegEvents = function(callback)
    mq.event('BegSay', '#1# says, \'Buffs Please!\'', callback)
    mq.event('BegGroup', '#1# tells the group, \'Buffs Please!\'', callback)
    mq.event('BegRaid', '#1# tells the raid, \'Buffs Please!\'', callback)
    mq.event('BegTell', '#1# tells you, \'Buffs Please!\'', callback)
end

return buff