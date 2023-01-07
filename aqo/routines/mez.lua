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

---Scan mobs in camp and reset mez timers to current time
mez.init_mez_timers = function(mez_spell)
    camp.mob_radar()
    for id,_ in pairs(state.targets) do
        local mob = mq.TLO.Spawn('id '..id)
        if mob() and not state.mez_immunes[mob.CleanName()] then
            mob.DoTarget()
            mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end)
            if mq.TLO.Target() and mq.TLO.Target.Buff(mez_spell)() then
                logger.debug(logger.log_flags.routines.mez, 'AEMEZ setting meztimer mob_id %d', id)
                state.targets[id].meztimer:reset()
            end
        end
    end
end

---Cast AE mez spell if AE Mez condition (>=3 mobs) is met.
---@param mez_spell table @The name of the AE mez spell to cast.
---@param ae_count number @The mob threshold for using AE mez.
mez.do_ae = function(mez_spell, ae_count)
    if state.mob_count >= ae_count and mez_spell then
        if mq.TLO.Me.Gem(mez_spell.name)() and mq.TLO.Me.GemTimer(mez_spell.name)() == 0 then
            print(logger.logLine('AE Mezzing (MOB_COUNT=%d)', state.mob_count))
            mez_spell:use()
            mez.init_mez_timers()
            return true
        end
    end
end

---Cast single target mez spell if adds in camp.
---@param mez_spell table @The name of the single target mez spell to cast.
mez.do_single = function(mez_spell)
    if state.mob_count <= 1 or not mez_spell or not mq.TLO.Me.Gem(mez_spell.name)() then return end
    for id,mobdata in pairs(state.targets) do
        if state.debug then
            logger.debug(logger.log_flags.routines.mez, '[%s] meztimer: %s, current_time: %s, timer_expired: %s', id, mobdata['meztimer'].start_time, timer.current_time(), mobdata['meztimer']:timer_expired())
        end
        if id ~= state.assist_mob_id and (mobdata['meztimer'].start_time == 0 or mobdata['meztimer']:timer_expired()) then
            local mob = mq.TLO.Spawn('id '..id)
            if mob() and not state.mez_immunes[mob.CleanName()] then
                if id ~= state.assist_mob_id and mob.Level() <= 123 and mob.Type() == 'NPC' then
                    mq.cmd('/attack off')
                    mq.delay(100, function() return not mq.TLO.Me.Combat() end)
                    mob.DoTarget()
                    mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end)
                    local pct_hp = mq.TLO.Target.PctHPs()
                    if mq.TLO.Target() and mq.TLO.Target.Type() == 'Corpse' then
                        state.targets[id] = nil
                    elseif pct_hp and pct_hp > 85 then
                        local assist_spawn = assist.get_assist_spawn()
                        if assist_spawn == -1 or assist_spawn.ID() ~= id then
                            state.mez_target_name = mob.CleanName()
                            state.mez_target_id = id
                            print(logger.logLine('Mezzing >>> %s (%d) <<<', mob.Name(), mob.ID()))
                            if mez_spell.precast then mez_spell.precast() end
                            mez_spell:use()
                            logger.debug(logger.log_flags.routines.mez, 'STMEZ setting meztimer mob_id %d', id)
                            state.targets[id].meztimer:reset()
                            mq.doevents('event_mezimmune')
                            mq.doevents('event_mezresist')
                            state.mez_target_id = 0
                            state.mez_target_name = nil
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

mez.event_mezbreak = function(line, mob, breaker)
    print(logger.logLine('\at%s\ax mez broken by \at%s\ax', mob, breaker))
end

mez.event_mezimmune = function(line)
    local mez_target_name = state.mez_target_name
    if mez_target_name then
        print(logger.logLine('Added to MEZ_IMMUNE: \at%s', mez_target_name))
        state.mez_immunes[mez_target_name] = 1
    end
end

mez.event_mezresist = function(line, mob)
    local mez_target_name = state.mez_target_name
    if mez_target_name and mob == mez_target_name then
        print(logger.logLine('MEZ RESIST >>> \at%s\ax <<<', mez_target_name))
        state.targets[state.mez_target_id].meztimer:reset(0)
    end
end

mez.setup_events = function()
    mq.event('event_mezbreak', '#1# has been awakened by #2#.', mez.event_mezbreak)
    mq.event('event_mezimmune', 'Your target cannot be mesmerized#*#', mez.event_mezimmune)
    mq.event('event_mezresist', '#1# resisted your#*#slumber of the diabo#*#', mez.event_mezresist)
end

return mez