local logger = require('aqo.utils.logger')
local timer = require('aqo.utils.timer')

local state = {
    debug = false,
    paused = true,
    burn_now = false,
    burn_active = false,
    burn_active_timer = timer:new(30),
    min_mana = 15,
    min_end = 15,
    spellset_loaded = nil,
    i_am_dead = false,
    assist_mob_id = 0,
    tank_mob_id = 0,
    pull_mob_id = 0,
    pull_in_progress = nil,
    targets = {},
    mob_count = 0,
    mez_immunes = {},
    mez_target_name = nil,
    mez_target_id = 0,
    subscription = 'GOLD',
}

function state.reset_combat_state()
    state.burn_active = false
    state.burn_active_timer:reset(0)
    state.assist_mob_id = 0
    state.tank_mob_id = 0
    state.pull_mob_id = 0
    state.pull_in_progress = nil
    state.targets = {}
    state.mob_count = 0
    state.mez_target_name = nil
    state.mez_target_id = 0
end

--for k,v in pairs(state.get_all()) do
--    logger.printf('%s: %s', k, v)
--end

return state