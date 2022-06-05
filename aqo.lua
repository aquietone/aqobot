--- @type mq
local mq = require('mq')
--- @type ImGui
require 'ImGui'

local class = mq.TLO.Me.Class.ShortName():lower()
local class_funcs = require('aqo.'..class)
local common = require('aqo.common')
local config = require('aqo.configuration')
local logger = require('aqo.logger')
local mode = require('aqo.mode')
local ui = require('aqo.ui')

local function check_game_state()
    if mq.TLO.MacroQuest.GameState() ~= 'INGAME' then
        logger.printf('Not in game, stopping aqo.')
        mq.exit()
    end
end

local function show_help()
    logger.printf('AQO Bot 1.0')
    logger.printf(('Commands:\n- /cls burnnow\n- /cls pause on|1|off|0\n- /cls show|hide\n- /cls mode 0|1|2\n- /cls resetcamp\n- /cls help'):gsub('cls', class))
end

local function get_or_set_opt(name, current_value, new_value, setter)
    if new_value then
        if type(current_value) == 'number' then
            setter(tonumber(new_value) or current_value)
        else
            setter(new_value)
        end
    else
        logger.printf('%s: %s', name, current_value)
    end
end

local function cmd_bind(...)
    local args = {...}
    if not args[1] or args[1] == 'help' then
        show_help()
    elseif args[1]:lower() == 'burnnow' then
        state.set_burn_now(true)
    elseif args[1] == 'pause' then
        if not args[2] then
            state.set_paused(not state.get_paused())
        else
            if args[2] == 'on' or args[2] == '1' then
                state.set_paused(true)
            elseif args[2] == 'off' or args[2] == '0' then
                state.set_paused(false)
            end
        end
    elseif args[1] == 'show' then
        ui.toggle_gui(true)
    elseif args[1] == 'hide' then
        ui.toggle_gui(false)
    elseif args[1] == 'mode' then
        if args[2] then
            config.set_mode(mode.from_string(args[2]) or config.get_mode())
        else
            logger.printf('Mode: %s', config:get_mode():get_name())
        end
    elseif args[1] == 'resetcamp' then
        common.set_camp(true)
    elseif args[1] == 'radius' then
        get_or_set_opt('PULLRADIUS', config.get_pull_radius(), args[2], config.set_pull_radius)
        common.set_camp(true)
    elseif args[1] == 'pullarc' then
        get_or_set_opt('PULLARC', config.get_pull_arc(), args[2], config.set_pull_arc)
        common.set_camp(true)
    elseif args[1] == 'levelmin' then
        get_or_set_opt('PULLMINLEVEL', config.get_pull_min_level(), args[2], config.set_pull_min_level)
    elseif args[1] == 'levelmax' then
        get_or_set_opt('PULLMAXLEVEL', config.get_pull_max_level(), args[2], config.set_pull_max_level)
    elseif args[1] == 'zlow' then
        get_or_set_opt('PULLLOW', config.get_pull_z_low(), args[2], config.set_pull_z_low)
    elseif args[1] == 'zhigh' then
        get_or_set_opt('PULLHIGH', config.set_pull_z_high(), args[2], config.set_pull_z_high)
    elseif args[1] == 'zradius' then
        get_or_set_opt('PULLLOW', config.get_pull_z_low(), args[2], config.set_pull_z_low)
        get_or_set_opt('PULLHIGH', config.set_pull_z_high(), args[2], config.set_pull_z_high)
    elseif args[1] == 'ignore' then
        
    else
        -- some other argument, show or modify a setting
        local opt = args[1]:upper()
        local new_value = args[2]
        class_funcs.process_cmd(opt, new_value)
    end
end
mq.bind(('/%s'):format(class), cmd_bind)

class_funcs.load_settings()
common.setup_events()
class_funcs.setup_events()

ui.set_class_funcs(class_funcs)
mq.imgui.init('AQO Bot 1.0', ui.main)

mq.cmd('/squelch /stick set verbflags 0')
mq.cmd('/squelch /plugin melee unload noauto')

local debug_timer = 0
-- Main Loop
while true do
    check_game_state()
    if state.get_debug() and common.timer_expired(debug_timer, 3) then
        logger.debug(state.get_debug(), 'main loop: PAUSED=%s, Me.Invis=%s', state.get_paused(), mq.TLO.Me.Invis())
        logger.debug(state.get_debug(), '#TARGETS: %d, MOB_COUNT: %d', common.table_size(common.TARGETS), common.MOB_COUNT)
        debug_timer = common.current_time()
    end

    if not mq.TLO.Target() and (mq.TLO.Me.Combat() or mq.TLO.Me.AutoFire()) then
        common.ASSIST_TARGET_ID = 0
        mq.cmd('/multiline ; /attack off; /autofire off;')
    end

    -- Process death events
    mq.doevents()
    if not state.get_paused() then
        common.clean_targets()
        if mq.TLO.Target() and mq.TLO.Target.Type() == 'Corpse' then
            common.ASSIST_TARGET_ID = 0
            mq.cmd('/squelch /mqtarget clear')
        end
        if not mq.TLO.Me.Invis() then
            -- do active combat assist things when not paused and not invis
            if mq.TLO.Me.Feigning() and common.FD_CLASSES[class] then
                mq.cmd('/stand')
            end
            common.check_cursor()
            class_funcs.main_loop()
        else
            -- stay in camp or stay chasing chase target if not paused but invis
            local pet_target_id = mq.TLO.Pet.Target.ID() or 0
            if mq.TLO.Pet.ID() > 0 and pet_target_id > 0 then mq.cmd('/pet back') end
            common.mob_radar()
            if (mode:is_tank_mode() and common.MOB_COUNT > 0) or (mode:is_assist_mode() and common.should_assist()) then mq.cmd('/makemevis') end
            common.check_camp()
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