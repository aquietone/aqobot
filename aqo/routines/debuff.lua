--- @type Mq
local mq = require('mq')
local abilities = require('ability')
local constants = require('constants')

local class
local debuff = {}

debuff.SLOW_IMMUNES = {}
debuff.SNARE_IMMUNES = {}

function debuff.init(_class)
    class = _class
end

function debuff.shouldUseDebuff(ability)
    if ability.opt == 'USEDISPEL' then
        local beneficial = mq.TLO.Target.Beneficial
        return beneficial() and beneficial.Dispellable() and not constants.ignoreBuff[beneficial]
    elseif ability.opt == 'USESLOWAOE' or ability.opt == 'USESLOW' then
        return mq.TLO.Target() and not mq.TLO.Target.Slowed() and not debuff.SLOW_IMMUNES[mq.TLO.Target.CleanName()]
    elseif ability.opt == 'USESNARE' then
        return mq.TLO.Target() and not mq.TLO.Target.Snared() and not debuff.SNARE_IMMUNES[mq.TLO.Target.CleanName()] and (mq.TLO.Target.PctHPs() or 100) < 40
    else
        return (not ability.condition and not mq.TLO.Target.Buff(ability.CheckFor or ability.Name)() and mq.TLO.Spell(ability.CheckFor or ability.Name).StacksTarget()) or (ability.condition and ability.condition())
    end
end

function debuff.findNextDebuff(opt)
    for _,ability in ipairs(class.debuffs) do
        if ability.opt == opt and debuff.shouldUseDebuff(ability) then
            if abilities.use(ability) then return true end
        end
    end
end

function debuff.castDebuffs()
    if mq.TLO.Target.Type() ~= 'NPC' or not mq.TLO.Target.Aggressive() then return end
    if class:isEnabled('USEDISPEL') then
        if debuff.findNextDebuff('USEDISPEL') then return true end
    end
    if class:isEnabled('USEDEBUFFAOE') then
        if debuff.findNextDebuff('USEDEBUFFAOE') then return true end
    end
    if class:isEnabled('USEDEBUFF') then
        if debuff.findNextDebuff('USEDEBUFF') then return true end
    end
    if class:isEnabled('USESLOWAOE') then
        if debuff.findNextDebuff('USESLOWAOE') then
            mq.doevents('event_debuffSlowImmune')
            return true
        end
    end
    if class:isEnabled('USESLOW') then
        if debuff.findNextDebuff('USESLOW') then
            mq.doevents('event_debuffSlowImmune')
            return true
        end
    end
    if class:isEnabled('USESNARE') then
        if debuff.findNextDebuff('USESNARE') then
            mq.doevents('event_debuffSnareImmune')
            return true
        end
    end
end

-- attempt to avoid trying to slow mobs that are slow immune. currently this table is never cleaned up unless restarted
function debuff.eventSlowImmune(line)
    local target_name = mq.TLO.Target.CleanName()
    if target_name and not debuff.SLOW_IMMUNES[target_name] then
        debuff.SLOW_IMMUNES[target_name] = 1
    end
end

-- attempt to avoid trying to snare mobs that are snare immune. currently this table is never cleaned up unless restarted
function debuff.eventSnareImmune()
    local target_name = mq.TLO.Target.CleanName()
    if target_name and not debuff.SNARE_IMMUNES[target_name] then
        debuff.SNARE_IMMUNES[target_name] = 1
    end
end

function debuff.setupEvents()
    if class.OPTS.USESLOW or class.OPTS.USESLOWAOE then
        mq.event('event_debuffSlowImmune', 'Your target is immune to changes in its attack speed#*#', debuff.eventSlowImmune)
    end
    if class.OPTS.USESNARE then
        mq.event('event_debuffRunspeedImmune', 'Your target is immune to changes in its run speed#*#', debuff.eventSnareImmune)
        mq.event('event_debuffSnareImmune', 'Your target is immune to snare spells#*#', debuff.eventSnareImmune)
    end
end

return debuff