---@type Mq
local mq = require('mq')
local timer = require('utils.timer')
local Abilities = require('ability')
local common = require('common')
local state = require('state')

local buff = {}

function buff.init(aqo)

end

buff.hasBuff = function(spell)
    local hasBuff = mq.TLO.Me.Buff(spell.name)()
    if not hasBuff then
        hasBuff = mq.TLO.Me.Song(spell.name)()
    end
    return hasBuff
end

buff.selfBuff = function(spell)
    if not mq.TLO.Me.Buff(spell.name)() and mq.TLO.Spell(spell.name).Stacks() then
        if mq.TLO.Spell(spell.name).TargetType() == 'Single' then
            mq.cmd('/mqtarget myself')
            mq.delay(100, function() return mq.TLO.Target.ID() == state.loop.ID end)
        end
        return spell:use()
    end
end

buff.needsBuff = function(spell, buffTarget)
    if not buffTarget.BuffsPopulated() then
        buffTarget.DoTarget()
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

local function haveBuff(buffName)
    return buffName and (mq.TLO.Me.Buff(buffName)() or mq.TLO.Me.Song(buffName)())
end

local function summonItem(buff)
    if mq.TLO.FindItemCount(buff.summons)() < buff.summonMinimum and not mq.TLO.Me.Moving() and (not buff.summonComponent or mq.TLO.FindItemCount(buff.summonComponent)() > 0) then
        buff:use()
        if mq.TLO.Cursor() then
            mq.delay(50)
            mq.cmd('/autoinv')
        end
    end
end

local function buffCombat(base)
    -- common clicky buffs like geomantra and ... just geomantra
    common.checkCombatBuffs()
    -- typically instant disc buffs like war field champion, etc. or summoning arrows
    if mq.TLO.Me.CombatState() == 'COMBAT' then
        for _,buff in ipairs(base.combatBuffs) do
            if base.isAbilityEnabled(buff.opt) then
                if buff.summons then
                    if base.isAbilityEnabled(buff.opt) then summonItem(buff) end
                else
                    local buffName = buff.checkfor or buff.name
                    if not haveBuff(buffName) and (not buff.skipifbuff or not mq.TLO.Me.Buff(buff.skipifbuff)()) then
                        buff:use()
                    end
                end
            end
        end
    end
end

local function buffAuras(base)
    for _,buff in ipairs(base.auras) do
        local buffName = buff.name
        if state.subscription ~= 'GOLD' then buffName = buff.name:gsub(' Rk%..*', '') end
        if not mq.TLO.Me.Aura(buff.checkfor)() and not mq.TLO.Me.Song(buffName)() then
            if buff.type == Abilities.Types.Spell then
                local restore_gem = nil
                if not mq.TLO.Me.Gem(buff.name)() then
                    restore_gem = {name=mq.TLO.Me.Gem(state.swapGem)()}
                    common.swapSpell(buff, state.swapGem)
                end
                mq.delay(3000, function() return mq.TLO.Me.Gem(buff.name)() and mq.TLO.Me.GemTimer(buff.name)() == 0 end)
                buff:use()
                -- project lazarus super long cast time special bard aura stupidity
                if state.emu and state.class == 'brd' then mq.delay(100) mq.delay(6000, function() return not mq.TLO.Window('CastingWindow').Open() end) end
                if restore_gem and restore_gem.name then
                    common.swapSpell(restore_gem, state.swapGem)
                end
            elseif buff.type == Abilities.Types.Disc then
                if buff:use() then mq.delay(3000, function() return mq.TLO.Me.Casting() == nil end) end
            elseif buff.type == Abilities.Types.AA then
                buff:use()
            end
            return true
        end
    end
end

local function buffSelf(base)
    local originalTargetID = 0
    for _,buff in ipairs(base.selfBuffs) do
        local buffName = buff.name -- TODO: buff name may not match AA or item name
        if state.subscription ~= 'GOLD' then buffName = buff.name:gsub(' Rk%..*', '') end
        if buff.summons then
            if base.isAbilityEnabled(buff.opt) then summonItem(buff) end
        elseif base.isAbilityEnabled(buff.opt) and not haveBuff(buffName) and not haveBuff(buff.checkfor)
                and mq.TLO.Spell(buff.checkfor or buff.name).Stacks()
                and ((buff.targettype ~= 'Pet' and buff.targettype ~= 'Pet2') or mq.TLO.Pet.ID() > 0) then
            if buff.targettype == 'Single' then
                originalTargetID = mq.TLO.Target.ID()
                mq.TLO.Me.DoTarget()
            end
            if buff.type == Abilities.Types.Spell then
                if common.swapAndCast(buff, state.swapGem) then
                    if originalTargetID == 0 then mq.cmdf('/squelch /mqtar clear') end
                    return true
                end
            elseif buff.type == Abilities.Types.Disc then
                if buff:use() then mq.delay(3000, function() return mq.TLO.Me.Casting() == nil end) return true end
            else
                if not base.itemTimer or base.itemTimer:timerExpired() then
                    buff:use()
                    if base.itemTimer then base.itemTimer:reset() end
                end
            end
            if buff.removesong then mq.cmdf('/removebuff %s', buff.removesong) end
        end
    end
end

local function willLandOther(toon, buff)
    local hasBuffQ = ('Me.Buff[%s]'):format(buff)
    local willLandQ = ('Spell[%s].WillLand'):format(buff)
    mq.cmdf('/dquery %s -q "%s"', toon, willLandQ)
    mq.cmdf('/dquery %s -q "hasBuffQ"', toon, hasBuffQ)
    mq.delay(250, function() return mq.TLO.DanNet(toon).QReceived(willLandQ)() > 0 and mq.TLO.DanNet(toon).QReceived(hasBuffQ)() end)
    local willLand = mq.TLO.DanNet(toon).Q(willLandQ)()
    local hasBuff = mq.TLO.DanNet(toon).Q(hasBuffQ)()
    return willLand > 0 and hasBuff
end

local function buffSingle(base)
    local groupSize = mq.TLO.Group.Members() or 0
    for i=1,groupSize do
        local member = mq.TLO.Group.Member(i)
        local memberClass = member.Class.ShortName()
        local memberDistance = member.Distance3D() or 300
        for _,buff in ipairs(base.singleBuffs) do
            if base.isAbilityEnabled(buff.opt) and buff.classes[memberClass] and mq.TLO.Me.SpellReady(buff.name)() and not member.Buff(buff.name)() and not member.Dead() and memberDistance < 100 then
                member.DoTarget()
                mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end)
                if not mq.TLO.Target.Buff(buff.name)() and mq.TLO.Spell(buff.name).StacksTarget() then
                    if buff:use() then return true end
                end
            end
        end
    end
end

local function buffGroup(base)
    for _,aBuff in ipairs(base.groupBuffs) do
        local buffName = aBuff.name -- TODO: buff name may not match AA or item name
        if state.subscription ~= 'GOLD' then buffName = aBuff.name:gsub(' Rk%..*', '') end
        if aBuff.type == Abilities.Types.Spell then
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
        elseif aBuff.type == Abilities.Types.Disc then
            
        elseif aBuff.type == Abilities.Types.AA then
            buff.groupBuff(aBuff)
        elseif aBuff.type == Abilities.Types.Item then
            local item = mq.TLO.FindItem(aBuff.id)
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
    -- find an actual buff spell that takes time to cast
    if buffAuras(base) then return true end
    if buffSelf(base) then return true end
    if buffSingle(base) then return true end
    --if buff_tank(base) then return true end
    if buffGroup(base) then return true end

    common.checkItemBuffs()
end

local function buffPet(base)
    if base.isEnabled('BUFFPET') and mq.TLO.Pet.ID() > 0 then
        local distance = mq.TLO.Pet.Distance3D() or 300
        if distance > 100 then return false end
        for _,buff in ipairs(base.petBuffs) do
            if buff.type == Abilities.Types.Spell then
                local tempName = buff.name
                if state.subscription ~= 'GOLD' then tempName = tempName:gsub(' Rk%..*', '') end
                if not mq.TLO.Pet.Buff(tempName)() and mq.TLO.Spell(buff.name).StacksPet() and mq.TLO.Spell(buff.name).Mana() < mq.TLO.Me.CurrentMana() and (not buff.skipifbuff or not mq.TLO.Pet.Buff(buff.skipifbuff)()) then
                    if common.swapAndCast(buff, state.swapGem) then return true end
                end
            elseif buff.type == Abilities.Types.AA then
                if not mq.TLO.Pet.Buff(buff.name)() and mq.TLO.Me.AltAbilityReady(buff.name)() and (not buff.checkfor or not mq.TLO.Pet.Buff(buff.checkfor)()) then
                    buff:use()
                end
            elseif buff.type == Abilities.Types.Item then
                local item = mq.TLO.FindItem(buff.id)
                if not mq.TLO.Pet.Buff(item.Spell.Name())() and (not buff.checkfor or not mq.TLO.Pet.Buff(buff.checkfor)()) then
                    buff:use()
                end
            end
        end
    end
end

local buffCacheTimer = timer:new(120)
buff.refreshBuffCaches = function()
    if not buffCacheTimer:timerExpired() then return end
    local memberCount = mq.TLO.Group.Members()
    for i=1,memberCount do
        local member = mq.TLO.Group.Member(i)
        if member.Present() then
            member.DoTarget()
            mq.delay(1000, function() return mq.TLO.Target.ID() == member.ID() and mq.TLO.Target.BuffsPopulated() end)
        end
    end
    buffCacheTimer:reset()
end

buff.buff = function(base)
    if buffCombat(base) then return true end

    if not common.clearToBuff() then return end
    --buff.refreshBuffCaches()

    if buffOOC(base) then return true end

    if buffPet(base) then return true end

    common.checkItemBuffs()
end

buff.setupBegEvents = function(callback)
    mq.event('BegSay', '#1# says, \'Buffs Please!\'', callback)
    mq.event('BegGroup', '#1# tells the group, \'Buffs Please!\'', callback)
    mq.event('BegRaid', '#1# tells the raid, \'Buffs Please!\'', callback)
    mq.event('BegTell', '#1# tells you, \'Buffs Please!\'', callback)
end

return buff