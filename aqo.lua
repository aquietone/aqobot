--- @type mq
local mq = require('mq')
--- @type ImGui
require 'ImGui'

local common = require('aqo.common')
local class = mq.TLO.Me.Class.ShortName():lower()
local class_funcs = require('aqo.'..class)
local ui = require('aqo.ui')

local function show_help()
    common.printf('AQO Bot 1.0')
    common.printf(('Commands:\n- /cls burnnow\n- /cls pause on|1|off|0\n- /cls show|hide\n- /cls mode 0|1|2\n- /cls resetcamp\n- /cls help'):gsub('cls', class))
end

local function cmd_bind(...)
    local args = {...}
    if not args[1] or args[1] == 'help' then
        show_help()
    elseif args[1]:lower() == 'burnnow' then
        common.BURN_NOW = true
    elseif args[1] == 'pause' then
        if not args[2] then
            common.PAUSED = not common.PAUSED
        else
            if args[2] == 'on' or args[2] == '1' then
                common.PAUSED = true
            elseif args[2] == 'off' or args[2] == '0' then
                common.PAUSED = false
            end
        end
    elseif args[1] == 'show' then
        ui.toggle_gui(true)
    elseif args[1] == 'hide' then
        ui.toggle_gui(false)
    elseif args[1] == 'mode' then
        if args[2] == '0' then -- manual, clears camp
            common.OPTS.MODE = common.MODES[1]
            common.set_camp()
        elseif args[2] == '1' then -- assist, sets camp
            common.OPTS.MODE = common.MODES[2]
            common.set_camp()
        elseif args[2] == '2' then -- chase, clears camp
            common.OPTS.MODE = common.MODES[3]
            common.set_camp()
        elseif args[2] == '3' and common.MODES[4] then -- vorpal, clears camp
            common.OPTS.MODE = common.MODES[4]
            common.set_camp()
        elseif args[2] == '4' and common.MODES[5] then -- tank, sets camp
            common.OPTS.MODE = common.MODES[5]
            common.set_camp()
        elseif args[2] == '5' and common.MODES[6] then -- pullertank, sets camp
            common.OPTS.MODE = common.MODES[6]
            common.set_camp()
        elseif args[2] == '6' and common.MODES[7] then -- puller, sets camp
            common.OPTS.MODE = common.MODES[7]
            common.set_camp()
        elseif not args[2] then
            common.printf('%s: %s', 'Mode', common.OPTS.MODE)
        end
    elseif args[1] == 'resetcamp' then
        common.set_camp(true)
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

mq.TLO.Lua.Turbo(500)
mq.cmd('/squelch /stick set verbosity off')
mq.cmd('/squelch /plugin melee unload noauto')

local debug_timer = 0
local autoinv_timer = 0
-- Main Loop
while true do
    if common.DEBUG and common.timer_expired(debug_timer, 3) then
        common.debug('main loop: PAUSED=%s, Me.Invis=%s', common.PAUSED, mq.TLO.Me.Invis())
        common.debug('#TARGETS: %d, MOB_COUNT: %d', common.table_size(common.TARGETS), common.MOB_COUNT)
        debug_timer = common.current_time()
    end

    common.clean_targets()
    if not mq.TLO.Target() and (mq.TLO.Me.Combat() or mq.TLO.Me.AutoFire()) then
        common.ASSIST_TARGET_ID = 0
        mq.cmd('/multiline ; /attack off; /autofire off;')
    end
    if mq.TLO.Target() and mq.TLO.Target.Type() == 'Corpse' then
        common.ASSIST_TARGET_ID = 0
        mq.cmd('/squelch /mqtarget clear')
    end
    -- Process death events
    mq.doevents()
    -- do active combat assist things when not paused and not invis
    if not common.PAUSED and not mq.TLO.Me.Invis() then
        -- keep cursor clear for spell swaps and such
        if mq.TLO.Cursor() then
            if autoinv_timer == 0 then
                autoinv_timer = common.current_time()
                common.printf('Dropping cursor item into inventory in 15 seconds')
            elseif os.difftime(common.current_time(), autoinv_timer) > 15 then
                mq.cmd('/autoinventory')
                autoinv_timer = 0
            end
        elseif autoinv_timer > 0 then
            common.debug('Cursor is empty, resetting autoinv_timer')
            autoinv_timer = 0
        end
        class_funcs.main_loop()
    elseif not common.PAUSED and mq.TLO.Me.Invis() then
        -- stay in camp or stay chasing chase target if not paused but invis
        if mq.TLO.Pet.ID() > 0 and mq.TLO.Pet.Target() and mq.TLO.Pet.Target.ID() > 0 then mq.cmd('/pet back') end
        if common.OPTS.MODE == 'assist' and common.should_assist() then mq.cmd('/makemevis') end
        common.check_camp()
        common.check_chase()
        common.rest()
        mq.delay(50)
    else
        -- paused, spin
        if mq.TLO.Pet.ID() > 0 and mq.TLO.Pet.Target() and mq.TLO.Pet.Target.ID() > 0 then mq.cmd('/pet back') end
        mq.delay(500)
    end
end