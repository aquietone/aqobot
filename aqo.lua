--- @type Mq
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
local loot = require('aqo.utils.lootutils')

---Check if the current game state is not INGAME, and exit the script if it is.
local function check_game_state()
    if state.subscription ~= 'GOLD' then
        if mq.TLO.Me.Subscription() == 'GOLD' then
            state.subscription = 'GOLD'
        end
    end
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
---@param key string @The configuration key to be set.
local function get_or_set_opt(name, current_value, new_value, key)
    if new_value then
        if type(current_value) == 'number' then
            config[key] = tonumber(new_value) or current_value
        elseif type(current_value) == 'boolean' then
            if common.BOOL.TRUE[new_value] then
                config[key] = true
            elseif common.BOOL.FALSE[new_value] then
                config[key] = false
            end
        else
            config[key] = new_value
        end
    else
        logger.printf('%s: %s', name, current_value)
    end
end

---Process binding commands.
---@vararg string @The input given to the bind command.
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
        state.burn_now = true
    elseif opt == 'pause' then
        if not new_value then
            state.paused = not state.paused
            if state.paused then
                state.reset_combat_state()
            end
        else
            if common.BOOL.TRUE[new_value] then
                state.paused = true
                state.reset_combat_state()
            elseif common.BOOL.FALSE[new_value] then
                camp.set_camp()
                state.paused = false
            end
        end
    elseif opt == 'show' then
        ui.toggle_gui(true)
    elseif opt == 'hide' then
        ui.toggle_gui(false)
    elseif opt == 'mode' then
        if new_value then
            config.MODE = mode.from_string(new_value) or config.MODE
        else
            logger.printf('Mode: %s', config.MODE:get_name())
        end
        camp.set_camp()
    elseif opt == 'resetcamp' then
        camp.set_camp(true)
    elseif opt == 'campradius' then
        get_or_set_opt(opt, config.CAMPRADIUS, new_value, 'CAMPRADIUS')
        camp.set_camp()
    elseif opt == 'radius' then
        get_or_set_opt(opt, config.PULLRADIUS, new_value, 'PULLRADIUS')
        camp.set_camp()
    elseif opt == 'pullarc' then
        get_or_set_opt(opt, config.PULLARC, new_value, 'PULLARC')
        camp.set_camp()
    elseif opt == 'levelmin' then
        get_or_set_opt(opt, config.PULLMINLEVEL, new_value, 'PULLMINLEVEL')
    elseif opt == 'levelmax' then
        get_or_set_opt(opt, config.PULLMAXLEVEL, new_value, 'PULLMAXLEVEL')
    elseif opt == 'zlow' then
        get_or_set_opt(opt, config.PULLLOW, new_value, 'PULLLOW')
    elseif opt == 'zhigh' then
        get_or_set_opt(opt, config.PULLHIGH, new_value, 'PULLHIGH')
    elseif opt == 'zradius' then
        get_or_set_opt(opt, config.PULLLOW, new_value, 'PULLLOW')
        get_or_set_opt(opt, config.PULLHIGH, new_value, 'PULLHIGH')
    elseif opt == 'groupwatch' then
        if common.GROUP_WATCH_OPTS[new_value] then
            get_or_set_opt(opt, config.GROUPWATCHWHO, new_value, 'GROUPWATCHWHO')
        end
    elseif opt == 'medmanastart' then
        get_or_set_opt(opt, config.MEDMANASTART, new_value, 'MEDMANASTART')
    elseif opt == 'medmanastop' then
        get_or_set_opt(opt, config.MEDMANASTOP, new_value, 'MEDMANASTOP')
    elseif opt == 'medendstart' then
        get_or_set_opt(opt, config.MEDENDSTART, new_value, 'MEDENDSTART')
    elseif opt == 'medendstop' then
        get_or_set_opt(opt, config.MEDENDSTOP, new_value, 'MEDENDSTOP')
    elseif opt == 'usealliance' then
        get_or_set_opt(opt, config.USEALLIANCE, new_value, 'USEALLIANCE')
    elseif opt == 'burnallnamed' then
        get_or_set_opt(opt, config.BURNALLNAMED, new_value, 'BURNALLNAMED')
    elseif opt == 'burnalways' then
        get_or_set_opt(opt, config.BURNALWAYS, new_value, 'BURNALWAYS')
    elseif opt == 'burncount' then
        get_or_set_opt(opt, config.BURNCOUNT, new_value, 'BURNCOUNT')
    elseif opt == 'burnpercent' then
        get_or_set_opt(opt, config.BURNPCT, new_value, 'BURNPCT')
    elseif opt == 'chasetarget' then
        get_or_set_opt(opt, config.CHASETARGET, new_value, 'CHASETARGET')
    elseif opt == 'chasedistance' then
        get_or_set_opt(opt, config.CHASEDISTANCE, new_value, 'CHASEDISTANCE')
    elseif opt == 'autoassistat' then
        get_or_set_opt(opt, config.AUTOASSISTAT, new_value, 'AUTOASSISTAT')
    elseif opt == 'assist' then
        if new_value and common.ASSISTS[new_value] then
            config.ASSIST = new_value
        end
        logger.printf('assist: %s', config.ASSIST)
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
state.subscription = mq.TLO.Me.Subscription()

ui.set_class_funcs(class_funcs)
mq.imgui.init('AQO Bot 1.0', ui.main)

mq.cmd('/squelch /stick set verbflags 0')
mq.cmd('/squelch /plugin melee unload noauto')

local debug_timer = timer:new(3)
-- Main Loop
while true do
    check_game_state()
    if state.debug and debug_timer:timer_expired() then
        logger.debug(state.debug, 'main loop: PAUSED=%s, Me.Invis=%s', state.paused, mq.TLO.Me.Invis())
        logger.debug(state.debug, '#TARGETS: %d, MOB_COUNT: %d', common.table_size(state.targets), state.mob_count)
        debug_timer:reset()
    end

    if not mq.TLO.Target() and (mq.TLO.Me.Combat() or mq.TLO.Me.AutoFire()) then
        common.ASSIST_TARGET_ID = 0
        mq.cmd('/multiline ; /attack off; /autofire off;')
    end

    if camp.Active and camp.ZoneID ~= mq.TLO.Zone.ID() then
        state.reset_combat_state()
    end

    -- Process death events
    mq.doevents()
    if not state.paused then
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
            if mq.TLO.Group.Leader() == mq.TLO.Me.CleanName() then
                loot.lootMobs()
            end
            class_funcs.main_loop()
            mq.delay(50)
        else
            -- stay in camp or stay chasing chase target if not paused but invis
            local pet_target_id = mq.TLO.Pet.Target.ID() or 0
            if mq.TLO.Pet.ID() > 0 and pet_target_id > 0 then mq.cmd('/pet back') end
            camp.mob_radar()
            if (mode:is_tank_mode() and state.mob_count > 0) or (mode:is_assist_mode() and assist.should_assist()) then mq.cmd('/makemevis') end
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