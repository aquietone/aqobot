local logger = require('aqo.logger')

local state = {}

local debug = false

---controls the main combat loop
local paused = true

---toggled by /burnnow binding to burn immediately
local burn_now = false

local burn_active = false

local burn_active_timer = 0

local camp = nil

local min_mana = 15

local min_end = 15

local spellset_loaded = nil

local i_am_dead = false

function state.get_all()
    return {
        debug=debug,
        paused=paused,
        burn_now=burn_now,
        burn_active=burn_active,
        burn_active_timer=burn_active_timer,
        camp=camp,
        min_mana=min_mana,
        min_end=min_end,
        spellset_loaded=spellset_loaded,
        i_am_dead=i_am_dead,
    }
end

function state.get_debug()
    return debug
end

function state.set_debug(new_debug)
    debug = new_debug
end

function state.get_paused()
    return paused
end

function state.set_paused(new_paused)
    paused = new_paused
end

function state.get_burn_now()
    return burn_now
end

function state.set_burn_now(new_burn_now)
    burn_now = new_burn_now
end

function state.get_burn_active()
    return burn_active
end

function state.set_burn_active(new_burn_active)
    burn_active = new_burn_active
end

function state.get_burn_active_timer()
    return burn_active_timer
end

function state.set_burn_active_timer(new_burn_active_timer)
    burn_active_timer = new_burn_active_timer
end

function state.get_camp()
    return camp
end

function state.set_camp(new_camp)
    camp = new_camp
end

function state.get_min_mana()
    return min_mana
end

function state.set_min_mana(new_min_mana)
    min_mana = new_min_mana
end

function state.get_min_end()
    return min_end
end

function state.set_min_end(new_min_end)
    min_end = new_min_end
end

function state.get_spellset_loaded()
    return spellset_loaded
end

function state.set_spellset_loaded(new_spellset_loaded)
    spellset_loaded = new_spellset_loaded
end

function state.get_i_am_dead()
    return i_am_dead
end

function state.set_i_am_dead(new_i_am_dead)
    i_am_dead = new_i_am_dead
end

--for k,v in pairs(state.get_all()) do
--    logger.printf('%s: %s', k, v)
--end
return state