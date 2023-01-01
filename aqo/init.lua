--- @type Mq
local mq = require('mq')
--- @type ImGui
require 'ImGui'

AQO='aqo'
local assist = require('routines.assist')
local camp = require('routines.camp')
local logger = require('utils.logger')
local loot = require('utils.lootutils')
local timer = require('utils.timer')
local common = require('common')
local config = require('configuration')
local mode = require('mode')
local state = require('state')
local ui = require('ui')
local aqoclass

---Check if the current game state is not INGAME, and exit the script if it is.
local function check_game_state()
    if mq.TLO.MacroQuest.GameState() ~= 'INGAME' then
        logger.printf('Not in game, stopping aqo.')
        mq.exit()
    end
    state.loop = {
        PctHPs = mq.TLO.Me.PctHPs(),
        PctMana = mq.TLO.Me.PctMana(),
        PctEndurance = mq.TLO.Me.PctEndurance(),
        ID = mq.TLO.Me.ID(),
        Invis = mq.TLO.Me.Invis(),
        PetName = mq.TLO.Me.Pet.CleanName(),
        TargetID = mq.TLO.Target.ID(),
        TargetHP = mq.TLO.Target.PctHPs(),
    }
end

---Display help information for the script.
local function show_help()
    logger.printf('AQO Bot 1.0')
    logger.printf(('Commands:\n- /cls burnnow\n- /cls pause on|1|off|0\n- /cls show|hide\n- /cls mode 0|1|2\n- /cls resetcamp\n- /cls help'):gsub('cls', state.class))
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
    elseif opt == 'debug' then
        local section = args[2]
        local subsection = args[3]
        if logger.log_flags[section] and logger.log_flags[section][subsection] ~= nil then
            logger.log_flags[section][subsection] = not logger.log_flags[section][subsection]
        end
    elseif opt == 'sell' and not new_value then
        loot.sellStuff()
    elseif opt == 'burnnow' then
        state.burn_now = true
        if new_value == 'quick' or new_value == 'long' then
            state.burn_type = new_value
        end
    elseif opt == 'pause' then
        if not new_value then
            state.paused = not state.paused
            if state.paused then
                state.reset_combat_state()
                mq.cmd('/stopcast')
            end
        else
            if config.BOOL.TRUE[new_value] then
                state.paused = true
                state.reset_combat_state()
                mq.cmd('/stopcast')
            elseif config.BOOL.FALSE[new_value] then
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
            state.reset_combat_state()
        else
            logger.printf('Mode: %s', config.MODE:get_name())
        end
        camp.set_camp()
    elseif opt == 'resetcamp' then
        camp.set_camp(true)
    elseif opt == 'campradius' or opt == 'radius' or opt == 'pullarc' then
        config.getOrSetOption(opt, config[config.aliases[opt]], new_value, config.aliases[opt])
        camp.set_camp()
    elseif config.aliases[opt] then
        config.getOrSetOption(opt, config[config.aliases[opt]], new_value, config.aliases[opt])
    elseif opt == 'groupwatch' and common.GROUP_WATCH_OPTS[new_value] then
        config.getOrSetOption(opt, config[config.aliases[opt]], new_value, config.aliases[opt])
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
    elseif opt == 'addclicky' then
        local clickyType = new_value
        local itemName = mq.TLO.Cursor()
        if itemName then
            local clicky = {name=itemName, clickyType=clickyType}
            aqoclass.addClicky(clicky)
            aqoclass.save_settings()
        else
            logger.printf('addclicky Usage:\n\tPlace clicky item on cursor\n\t/%s addclicky category\n\tCategories: burn, mash, heal, buff', state.class)
        end
    elseif opt == 'removeclicky' then
        local itemName = mq.TLO.Cursor()
        if itemName then
            aqoclass.removeClicky(itemName)
            aqoclass.save_settings()
        else
            logger.printf('removeclicky Usage:\n\tPlace clicky item on cursor\n\t/%s removeclicky', state.class)
        end
    elseif opt == 'tribute' then
        common.toggleTribute()
    elseif opt == 'bark' then
        local repeatstring = ''
        for i=2,#args do
            repeatstring = repeatstring .. ' ' .. args[i]
        end
        mq.cmdf('/dgga /say %s', repeatstring)
    elseif opt == 'force' then
        assist.force_assist(new_value)
    else
        aqoclass.process_cmd(opt:upper(), new_value)
    end
end

local function zoned()
    state.reset_combat_state()
    if state.currentZone == mq.TLO.Zone.ID() then
        -- evac'd
    end
    state.currentZone = mq.TLO.Zone.ID()
    mq.cmd('/pet ghold on')
end

local lootMyBody = false
local function rezzed()
    lootMyBody = true
end

local function init()
    state.class = mq.TLO.Me.Class.ShortName():lower()
    state.currentZone = mq.TLO.Zone.ID()
    state.subscription = mq.TLO.Me.Subscription()
    if mq.TLO.EverQuest.Server() == 'Project Lazarus' or mq.TLO.EverQuest.Server() == 'EZ (Linux) x4 Exp' then state.emu = true end
    common.set_swap_gem()

    aqoclass = require('classes.'..state.class)
    mq.bind(('/%s'):format(state.class), cmd_bind)

    aqoclass.load_settings()
    aqoclass.setup_events()
    ui.set_class_funcs(aqoclass)
    common.setup_events()
    config.load_ignores()

    mq.imgui.init('AQO Bot 1.0', ui.main)

    if state.emu then
        mq.cmd('/hidecorpse looted')
    else
        mq.cmd('/hidecorpse alwaysnpc')
    end
    mq.cmd('/multiline ; /pet ghold on')
    mq.cmd('/squelch /stick set verbflags 0')
    mq.cmd('/squelch /plugin melee unload noauto')
    mq.cmd('/squelch rez accept on')
    mq.cmd('/squelch rez pct 90')
    mq.cmdf('/setwintitle %s (Level %s %s)', mq.TLO.Me.CleanName(), mq.TLO.Me.Level(), state.class)
    mq.event('zoned', 'You have entered #*#', zoned)
    if state.emu then
        mq.event('rezzed', 'You regain #*# experience from resurrection', rezzed)
    end
    --loot.logger.loglevel = 'debug'
end

local function main()
    init()

    local debug_timer = timer:new(3)
    -- Main Loop
    while true do
        if state.debug and debug_timer:timer_expired() then
            logger.debug(logger.log_flags.aqo.main, 'Start Main Loop')
            debug_timer:reset()
        end
        mq.doevents()
        state.actionTaken = false
        check_game_state()

        if not mq.TLO.Target() and (mq.TLO.Me.Combat() or mq.TLO.Me.AutoFire()) then
            state.assist_mob_id = 0
            state.tank_mob_id = 0
            state.pull_mob_id = 0
            mq.cmd('/multiline ; /attack off; /autofire off;')
        end
        if state.class == 'nec' and state.loop.PctHPs < 40 and aqoclass.spells.lich then
            mq.cmdf('/removebuff %s', aqoclass.spells.lich.name)
        end
        if not state.paused or not common.in_control() then
            camp.clean_targets()
            if mq.TLO.Target() and mq.TLO.Target.Type() == 'Corpse' then
                state.tank_mob_id = 0
                state.assist_mob_id = 0
                state.pull_mob_id = 0
                if not common.HEALER_CLASSES[state.class] then
                    mq.cmd('/squelch /mqtarget clear')
                end
            end
            if mq.TLO.Me.Hovering() then
                mq.delay(50)
            elseif not state.loop.Invis and not common.blocking_window_open() then
                -- do active combat assist things when not paused and not invis
                if mq.TLO.Me.Feigning() and not common.FD_CLASSES[state.class] then
                    mq.cmd('/stand')
                end
                common.check_cursor()
                if state.emu then
                    if lootMyBody and mq.TLO.Me.Buff('Resurrection Sickness')() then
                        loot.lootMyCorpse()
                        lootMyBody = false
                        state.actionTaken = true
                    end
                    if config.LOOTMOBS and mq.TLO.Me.CombatState() ~= 'COMBAT' and not state.pull_in_progress then
                        state.actionTaken = loot.lootMobs()
                    end
                end
                if not state.actionTaken then
                    aqoclass.main_loop()
                end
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
            if state.loop.Invis then
                -- if paused and invis, back pet off, otherwise let it keep doing its thing if we just paused mid-combat for something
                local pet_target_id = mq.TLO.Pet.Target.ID() or 0
                if mq.TLO.Pet.ID() > 0 and pet_target_id > 0 then mq.cmd('/pet back') end
            end
            mq.delay(500)
        end
    end
end

main()