local logger = require('aqo.utils.logger')
local timer = require('aqo.utils.timer')

local state = {}

local debug = false

---controls the main combat loop
local paused = true

---toggled by /burnnow binding to burn immediately
local burn_now = false

local burn_active = false

local burn_active_timer = timer:new(30)

local camp = nil

local min_mana = 15

local min_end = 15

local spellset_loaded = nil

local i_am_dead = false

local assist_mob_id = 0

local targets = {}

local mob_count = 0

local tank_mob_id = 0

local pull_mob_id = 0

local pull_in_progress = nil

local mez_immunes = {}

local mez_target_name = nil

local mez_target_id = 0

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
        tank_mob_id=tank_mob_id,
        pull_mob_id=pull_mob_id,
        pull_in_progress=pull_in_progress,
        targets=targets,
        mob_count=mob_count,
        mez_ummunes=mez_immunes,
        mez_target_name=mez_target_name,
        mez_target_id=mez_target_id,
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

function state.get_pull_in_progress()
    return pull_in_progress
end

function state.set_pull_in_progress(new_pull_in_progress)
    pull_in_progress = new_pull_in_progress
end

function state.get_pull_mob_id()
    return pull_mob_id
end

function state.set_pull_mob_id(new_pull_mob_id)
    pull_mob_id = new_pull_mob_id
end

function state.get_tank_mob_id()
    return tank_mob_id
end

function state.set_tank_mob_id(new_tank_mob_id)
    tank_mob_id = new_tank_mob_id
end

function state.get_assist_mob_id()
    return assist_mob_id
end

function state.set_assist_mob_id(new_assist_mob_id)
    assist_mob_id = new_assist_mob_id
end

function state.get_targets()
    return targets
end

function state.set_targets(new_targets)
    targets = targets
end

function state.get_mob_count()
    return mob_count
end

function state.set_mob_count(new_mob_count)
    mob_count = new_mob_count
end

function state.get_mez_target_name()
    return mez_target_name
end

function state.set_mez_target_name(new_mez_target_name)
    mez_target_name = new_mez_target_name
end

function state.get_mez_target_id()
    return mez_target_id
end

function state.set_mez_target_id(new_mez_target_id)
    mez_target_id = new_mez_target_id
end

function state.get_mez_immunes()
    return mez_immunes
end

function state.set_mez_immunes(new_mez_immunes)
    mez_immunes = new_mez_immunes
end

function state.reset_combat_state()
    burn_active=false
    burn_active_timer:reset(0)
    tank_mob_id=0
    pull_mob_id=0
    targets={}
    mob_count=0
    mez_target_name=nil
    mez_target_id=0
end

--for k,v in pairs(state.get_all()) do
--    logger.printf('%s: %s', k, v)
--end
return state