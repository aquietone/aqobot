--- @type Mq
local mq = require('mq')

local aqo
local events = {}

---Initialize common event handlers.
function events.init(_aqo)
    aqo = _aqo

    mq.event('zoned', 'You have entered #*#', events.zoned)
    mq.event('CannotSee', '#*#cannot see your target#*#', events.movecloser)
    mq.event('TooFar', '#*#Your target is too far away#*#', events.movecloser)
    mq.event('event_dead_released', '#*#Returning to Bind Location#*#', events.event_dead)
    mq.event('event_dead', 'You died.', events.event_dead)
    mq.event('event_dead_slain', 'You have been slain by#*#', events.event_dead)
    mq.event('event_resist', '#1# resisted your #2#!', events.event_resist)
end

function events.zoned()
    aqo.state.reset_combat_state()
    if aqo.state.currentZone == mq.TLO.Zone.ID() then
        -- evac'd
        aqo.camp.set_camp()
        aqo.movement.stop()
    end
    aqo.state.currentZone = mq.TLO.Zone.ID()
    mq.cmd('/pet ghold on')
    if not aqo.state.paused and aqo.config.MODE.value:is_pull_mode() then
        aqo.config.MODE.value = aqo.mode.from_string('manual')
        aqo.camp.set_camp()
        aqo.movement.stop()
    end
end

function events.movecloser()
    if aqo.config.MODE.value:is_assist_mode() and not aqo.state.paused then
        aqo.movement.navToTarget(nil, 1000)
    end
end

---Event callback for handling spell resists from mobs
---@param line any
---@param target_name any
---@param spell_name any
function events.event_resist(line, target_name, spell_name)
    if mq.TLO.Target.CleanName() == target_name then
        aqo.state.resists[spell_name] = (aqo.state.resists[spell_name] or 0) + 1
        print(aqo.logger.logLine('%s resisted spell %s, resist count = %s', target_name, spell_name, aqo.state.resists[spell_name]))
    end
end

---Set common.I_AM_DEAD flag to true in the event of death.
function events.event_dead()
    print(aqo.logger.logLine('HP hit 0. what do!'))
    aqo.state.i_am_dead = true
    aqo.state.reset_combat_state()
    aqo.movement.stop()
end

return events