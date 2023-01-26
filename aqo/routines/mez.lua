--- @type Mq
local mq = require 'mq'
local assist = require('routines.assist')
local camp = require('routines.camp')
local logger = require('utils.logger')
local timer = require('utils.timer')
local common = require('common')
local state = require('state')
local config = require('configuration')

local mez = {}

function mez.init(aqo)

end

---Scan mobs in camp and reset mez timers to current time
mez.initMezTimers = function(mez_spell)
    camp.mobRadar()
    for id,_ in pairs(state.targets) do
        local mob = mq.TLO.Spawn('id '..id)
        if mob() and not state.mezImmunes[mob.CleanName()] then
            mob.DoTarget()
            mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end)
            if mq.TLO.Target() and mq.TLO.Target.Buff(mez_spell)() then
                logger.debug(logger.flags.routines.mez, 'AEMEZ setting meztimer mob_id %d', id)
                state.targets[id].meztimer:reset()
            end
        end
    end
end

---Cast AE mez spell if AE Mez condition (>=3 mobs) is met.
---@param mez_spell table @The name of the AE mez spell to cast.
---@param ae_count number @The mob threshold for using AE mez.
mez.doAE = function(mez_spell, ae_count)
    if state.mobCount >= ae_count and mez_spell then
        if mq.TLO.Me.Gem(mez_spell.name)() and mq.TLO.Me.GemTimer(mez_spell.name)() == 0 then
            print(logger.logLine('AE Mezzing (mobCount=%d)', state.mobCount))
            mez_spell:use()
            mez.initMezTimers()
            return true
        end
    end
end

---Cast single target mez spell if adds in camp.
---@param mez_spell table @The name of the single target mez spell to cast.
mez.doSingle = function(mez_spell)
    if state.mobCount <= 1 or not mez_spell or not mq.TLO.Me.Gem(mez_spell.name)() then return end
    for id,mobdata in pairs(state.targets) do
        if state.debug then
            logger.debug(logger.flags.routines.mez, '[%s] meztimer: %s, currentTime: %s, timerExpired: %s', id, mobdata['meztimer'].start_time, timer.currentTime(), mobdata['meztimer']:timerExpired())
        end
        if id ~= state.assistMobID and (mobdata['meztimer'].start_time == 0 or mobdata['meztimer']:timerExpired()) then
            local mob = mq.TLO.Spawn('id '..id)
            if mob() and not state.mezImmunes[mob.CleanName()] then
                if id ~= state.assistMobID and mob.Level() <= 123 and mob.Type() == 'NPC' then
                    mq.cmd('/attack off')
                    mq.delay(100, function() return not mq.TLO.Me.Combat() end)
                    mob.DoTarget()
                    mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end)
                    local pct_hp = mq.TLO.Target.PctHPs()
                    if mq.TLO.Target() and mq.TLO.Target.Type() == 'Corpse' then
                        state.targets[id] = nil
                    elseif pct_hp and pct_hp > 85 then
                        local assist_spawn = assist.getAssistSpawn()
                        if assist_spawn == -1 or assist_spawn.ID() ~= id then
                            state.mezTargetName = mob.CleanName()
                            state.mezTargetID = id
                            print(logger.logLine('Mezzing >>> %s (%d) <<<', mob.Name(), mob.ID()))
                            if mez_spell.precast then mez_spell.precast() end
                            mez_spell:use()
                            logger.debug(logger.flags.routines.mez, 'STMEZ setting meztimer mob_id %d', id)
                            state.targets[id].meztimer:reset()
                            mq.doevents('eventMezImmune')
                            mq.doevents('eventMezResist')
                            state.mezTargetID = 0
                            state.mezTargetName = nil
                            return true
                        end
                    end
                elseif mob.Type() == 'Corpse' then
                    state.targets[id] = nil
                end
            end
        end
    end
end

mez.eventMezBreak = function(line, mob, breaker)
    print(logger.logLine('\at%s\ax mez broken by \at%s\ax', mob, breaker))
end

mez.eventMezImmune = function(line)
    local mezTargetName = state.mezTargetName
    if mezTargetName then
        print(logger.logLine('Added to MEZ_IMMUNE: \at%s', mezTargetName))
        state.mezImmunes[mezTargetName] = 1
    end
end

mez.eventMezResist = function(line, mob)
    local mezTargetName = state.mezTargetName
    if mezTargetName and mob == mezTargetName then
        print(logger.logLine('MEZ RESIST >>> \at%s\ax <<<', mezTargetName))
        state.targets[state.mezTargetID].meztimer:reset(0)
    end
end

mez.setupEvents = function()
    mq.event('eventMezBreak', '#1# has been awakened by #2#.', mez.eventMezBreak)
    mq.event('eventMezImmune', 'Your target cannot be mesmerized#*#', mez.eventMezImmune)
    mq.event('eventMezResist', '#1# resisted your#*#slumber of the diabo#*#', mez.eventMezResist)
end

return mez