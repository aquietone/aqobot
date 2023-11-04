--- @type Mq
local mq = require 'mq'
local assist = require('routines.assist')
local camp = require('routines.camp')
local logger = require('utils.logger')
local timer = require('utils.timer')
local abilities = require('ability')
local state = require('state')

local mez = {}

function mez.init(aqo)

end

---Scan mobs in camp and reset mez timers to current time
function mez.initMezTimers(mez_spell)
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
function mez.doAE(mez_spell, ae_count)
    if state.mobCount >= ae_count and mez_spell then
        if mq.TLO.Me.Gem(mez_spell.CastName)() and mq.TLO.Me.GemTimer(mez_spell.CastName)() == 0 then
            logger.info('AE Mezzing (mobCount=%d)', state.mobCount)
            abilities.use(mez_spell)
            mez.initMezTimers()
            return true
        end
    end
end

---Cast single target mez spell if adds in camp.
---@param mez_spell table @The name of the single target mez spell to cast.
function mez.doSingle(mez_spell)
    if state.mobCount <= 1 or not mez_spell or not mq.TLO.Me.Gem(mez_spell.CastName)() then return end
    for id,mobdata in pairs(state.targets) do
        logger.debug(logger.flags.routines.mez, '[%s] meztimer: %s, currentTime: %s, timerExpired: %s', id, mobdata['meztimer'].start_time, mq.gettime(), mobdata['meztimer']:timerExpired())
        if id ~= state.assistMobID and (mobdata['meztimer'].start_time == 0 or mobdata['meztimer']:timerExpired()) then
            local mob = mq.TLO.Spawn('id '..id)
            if mob() and not state.mezImmunes[mob.CleanName()] then
                local spellData = mq.TLO.Spell(mez_spell.CastName)
                local maxLevel = spellData.Max(1)() or mq.TLO.Me.Level()
                if id ~= state.assistMobID and mob.Level() <= maxLevel and mob.Type() == 'NPC' then
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
                            logger.info('Mezzing >>> %s (%d) <<<', mob.Name(), mob.ID())
                            if mez_spell.precast then mez_spell.precast() end
                            abilities.use(mez_spell)
                            mq.delay(100)
                            mq.delay(3500, function() return not mq.TLO.Me.Casting() == mez_spell.CastName end)
                            logger.debug(logger.flags.routines.mez, 'STMEZ setting meztimer mob_id %d', id)
                            mobdata.meztimer = timer:new(mez_spell.DurationTotalSeconds*1000)
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

function mez.eventMezBreak(line, mob, breaker)
    logger.info('\at%s\ax mez broken by \at%s\ax', mob, breaker)
end

function mez.eventMezImmune(line)
    local mezTargetName = state.mezTargetName
    if mezTargetName then
        logger.info('Added to MEZ_IMMUNE: \at%s', mezTargetName)
        state.mezImmunes[mezTargetName] = 1
    end
end

function mez.eventMezResist(line, mob)
    local mezTargetName = state.mezTargetName
    if mezTargetName and mob == mezTargetName then
        logger.info('MEZ RESIST >>> \at%s\ax <<<', mezTargetName)
        state.targets[state.mezTargetID].meztimer:reset(0)
    end
end

function mez.setupEvents()
    mq.event('eventMezBreak', '#1# has been awakened by #2#.', mez.eventMezBreak)
    mq.event('eventMezImmune', 'Your target cannot be mesmerized#*#', mez.eventMezImmune)
    mq.event('eventMezResist', '#1# resisted your#*#slumber of the diabo#*#', mez.eventMezResist)
end

return mez