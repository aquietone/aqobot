--- @type mq
local mq = require('mq')
--- @type ImGui
require 'ImGui'

local class = mq.TLO.Me.Class.ShortName():lower()
local class_funcs = require('aqo.classes.'..class)
local assist = require('aqo.routines.assist')
local camp = require('aqo.routines.camp')
local logger = require('aqo.utils.logger')
local timer = require('aqo.utils.timer')
local common = require('aqo.common')
local config = require('aqo.configuration')
local mode = require('aqo.mode')
local state = require('aqo.state')
local ui = require('aqo.ui')

---Check if the current game state is not INGAME, and exit the script if it is.
local function check_game_state()
    if mq.TLO.MacroQuest.GameState() ~= 'INGAME' then
        logger.printf('Not in game, stopping aqo.')
        mq.exit()
    end
end

---Display help information for the script.
local function show_help()
    logger.printf('AQO Bot 1.0')
    logger.printf(('Commands:\n- /cls burnnow\n- /cls pause on|1|off|0\n- /cls show|hide\n- /cls mode 0|1|2\n- /cls resetcamp\n- /cls help'):gsub('cls', class))
end

---Get or set the specified configuration option. Currently applies to pull settings only.
---@param name string @The name of the setting.
---@param current_value any @The current value of the specified setting.
---@param new_value string @The new value for the setting.
---@param setter function @The function used to set the desired settings value.
local function get_or_set_opt(name, current_value, new_value, setter)
    if new_value then
        if type(current_value) == 'number' then
            setter(tonumber(new_value) or current_value)
        elseif type(current_value) == 'boolean' then
            if common.BOOL.TRUE[new_value] then
                setter(true)
            elseif common.BOOL.FALSE[new_value] then
                setter(false)
            end
        else
            setter(new_value)
        end
    else
        logger.printf('%s: %s', name, current_value)
    end
end

---Process binding commands.
---@param ... vararg @The input given to the bind command.
local function cmd_bind(...)
    local args = {...}
    if not args[1] then
        show_help()
        return
    end

    local opt = args[1]:lower()
    local new_value = args[2]
    if opt == 'help' then
        show_help()
    elseif opt == 'burnnow' then
        state.set_burn_now(true)
    elseif opt == 'pause' then
        if not new_value then
            state.set_paused(not state.get_paused())
            if state.get_paused() then
                state.reset_combat_state()
            end
        else
            if common.BOOL.TRUE[new_value] then
                state.set_paused(true)
                state.reset_combat_state()
            elseif common.BOOL.FALSE[new_value] then
                camp.set_camp()
                state.set_paused(false)
            end
        end
    elseif opt == 'show' then
        ui.toggle_gui(true)
    elseif opt == 'hide' then
        ui.toggle_gui(false)
    elseif opt == 'mode' then
        if new_value then
            config.set_mode(mode.from_string(new_value) or config.get_mode())
        else
            logger.printf('Mode: %s', config:get_mode():get_name())
        end
        camp.set_camp()
    elseif opt == 'resetcamp' then
        camp.set_camp(true)
    elseif opt == 'campradius' then
        get_or_set_opt(opt, config.get_camp_radius(), new_value, config.set_camp_radius)
        camp.set_camp()
    elseif opt == 'radius' then
        get_or_set_opt(opt, config.get_pull_radius(), new_value, config.set_pull_radius)
        camp.set_camp()
    elseif opt == 'pullarc' then
        get_or_set_opt(opt, config.get_pull_arc(), new_value, config.set_pull_arc)
        camp.set_camp()
    elseif opt == 'levelmin' then
        get_or_set_opt(opt, config.get_pull_min_level(), new_value, config.set_pull_min_level)
    elseif opt == 'levelmax' then
        get_or_set_opt(opt, config.get_pull_max_level(), new_value, config.set_pull_max_level)
    elseif opt == 'zlow' then
        get_or_set_opt(opt, config.get_pull_z_low(), new_value, config.set_pull_z_low)
    elseif opt == 'zhigh' then
        get_or_set_opt(opt, config.get_pull_z_high(), new_value, config.set_pull_z_high)
    elseif opt == 'zradius' then
        get_or_set_opt(opt, config.get_pull_z_low(), new_value, config.set_pull_z_low)
        get_or_set_opt(opt, config.get_pull_z_high(), new_value, config.set_pull_z_high)
    elseif opt == 'groupwatch' then
        if common.GROUP_WATCH_OPTS[new_value] then
            get_or_set_opt(opt, config.get_group_watch_who(), new_value, config.set_group_watch_who)
        end
    elseif opt == 'medmanastart' then
        get_or_set_opt(opt, config.get_med_mana_start(), new_value, config.set_med_mana_start)
    elseif opt == 'medmanastop' then
        get_or_set_opt(opt, config.get_med_mana_stop(), new_value, config.set_med_mana_stop)
    elseif opt == 'medendstart' then
        get_or_set_opt(opt, config.get_med_end_start(), new_value, config.set_med_end_start)
    elseif opt == 'medendstop' then
        get_or_set_opt(opt, config.get_med_end_stop(), new_value, config.set_med_end_stop)
    elseif opt == 'usealliance' then
        get_or_set_opt(opt, config.get_use_alliance(), new_value, config.set_use_alliance)
    elseif opt == 'burnallnamed' then
        get_or_set_opt(opt, config.get_burn_all_named(), new_value, config.set_burn_all_named)
    elseif opt == 'burnalways' then
        get_or_set_opt(opt, config.get_burn_always(), new_value, config.set_burn_always)
    elseif opt == 'burncount' then
        get_or_set_opt(opt, config.get_burn_count(), new_value, config.set_burn_count)
    elseif opt == 'burnpercent' then
        get_or_set_opt(opt, config.get_burn_percent(), new_value, config.set_burn_percent)
    elseif opt == 'chasetarget' then
        get_or_set_opt(opt, config.get_chase_target(), new_value, config.set_chase_target)
    elseif opt == 'chasedistance' then
        get_or_set_opt(opt, config.get_chase_distance(), new_value, config.set_chase_distance)
    elseif opt == 'autoassistat' then
        get_or_set_opt(opt, config.get_auto_assist_at(), new_value, config.set_auto_assist_at)
    elseif opt == 'assist' then
        if new_value and common.ASSISTS[new_value] then
            config.set_assist(new_value)
        end
        logger.printf('assist: %s', config.get_assist())
    elseif opt == 'ignore' then
        local zone = mq.TLO.Zone.ShortName()
        if new_value then
            config.add_ignore(zone, new_value)
        else
            local target_name = mq.TLO.Target.CleanName()
            if target_name then config.add_ignore(zone, target_name) end
        end
    elseif opt == 'unignore' then
        local zone = mq.TLO.Zone.ShortName()
        if new_value then
            config.remove_ignore(zone, new_value)
        else
            local target_name = mq.TLO.Target.CleanName()
            if target_name then config.remove_ignore(zone, target_name) end
        end
    else
        class_funcs.process_cmd(opt:upper(), new_value)
    end
end
mq.bind(('/%s'):format(class), cmd_bind)

class_funcs.load_settings()
common.setup_events()
class_funcs.setup_events()
config.load_ignores()

ui.set_class_funcs(class_funcs)
mq.imgui.init('AQO Bot 1.0', ui.main)

mq.cmd('/squelch /stick set verbflags 0')
mq.cmd('/squelch /plugin melee unload noauto')

local debug_timer = timer:new(3)
-- Main Loop
while true do
    check_game_state()
    if state.get_debug() and debug_timer:timer_expired() then
        logger.debug(state.get_debug(), 'main loop: PAUSED=%s, Me.Invis=%s', state.get_paused(), mq.TLO.Me.Invis())
        logger.debug(state.get_debug(), '#TARGETS: %d, MOB_COUNT: %d', common.table_size(state.get_targets()), state.get_mob_count())
        debug_timer:reset()
    end

    if not mq.TLO.Target() and (mq.TLO.Me.Combat() or mq.TLO.Me.AutoFire()) then
        common.ASSIST_TARGET_ID = 0
        mq.cmd('/multiline ; /attack off; /autofire off;')
    end

    local my_camp = state.get_camp()
    if my_camp and my_camp.ZoneID ~= mq.TLO.Zone.ID() then
        state.reset_combat_state()
    end

    -- Process death events
    mq.doevents()
    if not state.get_paused() then
        camp.clean_targets()
        if mq.TLO.Target() and mq.TLO.Target.Type() == 'Corpse' then
            common.ASSIST_TARGET_ID = 0
            mq.cmd('/squelch /mqtarget clear')
        end
        if mq.TLO.Me.Hovering() then
            mq.delay(50)
        elseif not mq.TLO.Me.Invis() and not common.blocking_window_open() then
            -- do active combat assist things when not paused and not invis
            if mq.TLO.Me.Feigning() and not common.FD_CLASSES[class] then
                mq.cmd('/stand')
            end
            common.check_cursor()
            class_funcs.main_loop()
            mq.delay(50)
        else
            -- stay in camp or stay chasing chase target if not paused but invis
            local pet_target_id = mq.TLO.Pet.Target.ID() or 0
            if mq.TLO.Pet.ID() > 0 and pet_target_id > 0 then mq.cmd('/pet back') end
            camp.mob_radar()
            if (mode:is_tank_mode() and state.get_mob_count() > 0) or (mode:is_assist_mode() and assist.should_assist()) then mq.cmd('/makemevis') end
            camp.check_camp()
            common.check_chase()
            common.rest()
            mq.delay(50)
        end
    else
        if mq.TLO.Me.Invis() then
            -- if paused and invis, back pet off, otherwise let it keep doing its thing if we just paused mid-combat for something
            local pet_target_id = mq.TLO.Pet.Target.ID() or 0
            if mq.TLO.Pet.ID() > 0 and pet_target_id > 0 then mq.cmd('/pet back') end
        end
        mq.delay(500)
    end
end