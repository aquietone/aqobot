--- @type Mq
local mq = require('mq')
--- @type ImGui
require 'ImGui'

local assist = require('routines.assist')
local camp = require('routines.camp')
local movement = require('routines.movement')
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
        print(logger.logLine('Not in game, stopping aqo.'))
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
        PetID = mq.TLO.Pet.ID()
    }
end

local function detect_raid_or_group()
    if not config.AUTODETECTRAID then return end
    if mq.TLO.Raid.Members() > 0 then
        local leader = mq.TLO.Group.Leader() or nil
        if config.ASSIST == 'group' and leader and leader ~= mq.TLO.Me.CleanName() then
            config.ASSIST = 'manual'
            config.CHASETARGET = mq.TLO.Group.Leader()
            config.BURNALWAYS = false
            config.BURNCOUNT = 100
        end
    else
        if config.ASSIST == 'manual' then
            config.ASSIST = 'group'
        end
    end
end

---Display help information for the script.
local function show_help()
    local output = logger.logLine('AQO Bot 1.0\n')
    --print(logger.logLine(('Commands:\n- /cls help\n- /cls burnnow\n- /cls pause on|1|off|0\n- /cls show|hide\n- /cls mode 0|manual|1|assist|2|chase|3|vorpal|4|tank|5|pullertank|6|puller|7|huntertank\n- /cls resetcamp'):gsub('cls', state.class)))
    output = output .. ('\ayCommands:\aw\n- /cls help\n- /cls burnnow\n- /cls pause on|1|off|0\n- /cls show|hide\n- /cls mode 0|manual|1|assist|2|chase|3|vorpal|4|tank|5|pullertank|6|puller|7|huntertank\n- /cls resetcamp'):gsub('cls', state.class)
    output = output .. ('\n- /%s addclicky <mash|burn|buff|heal> -- Adds the currently held item to the clicky group specified'):format(state.class)
    output = output .. ('\n- /%s removeclicky -- Removes the currently held item from clickies'):format(state.class)
    output = output .. ('\n- /%s ignore -- Adds the targeted mob to the ignore list for the current zone'):format(state.class)
    output = output .. ('\n- /%s unignore -- Removes the targeted mob from the ignore list for the current zone'):format(state.class)
    output = output .. ('\n- /%s sell -- Sells items marked to be sold to the targeted or already opened vendor'):format(state.class)
    output = output .. ('\n- /%s update -- Downloads the latest source zip'):format(state.class)
    output = output .. ('\n- /%s docs -- Launches the documentation site in a browser window'):format(state.class)
    output = output .. ('\n- /%s wiki -- Launches the Lazarus wiki in a browser window'):format(state.class)
    output = output .. ('\n- /%s wiki -- Launches the Lazarus Bazaar in a browser window'):format(state.class)
    output = output .. ('\n- /%s manastone -- Spam manastone to get some mana back'):format(state.class)
    local prefix = '\n- /'..state.class..' '
    output = output .. '\n\ayGeneric Configuration\aw'
    for key,value in pairs(config) do
        local valueType = type(value)
        if valueType == 'string' or valueType == 'number' or valueType == 'boolean' then
            output = output .. prefix .. key .. ' <' .. valueType .. '> -- '..config.tips[key]
        end
    end
    output = output .. '\n\ayClass Configuration\aw'
    for key,value in pairs(aqoclass.OPTS) do
        local valueType = type(value.value)
        if valueType == 'string' or valueType == 'number' or valueType == 'boolean' then
            output = output .. prefix .. key .. ' <' .. valueType .. '>'--' -- '..value.tip
            if value.tip then output = output .. ' -- '..value.tip end
        end
    end
    output = output .. '\n\ayGear Check:\aw /tell <name> gear <slotname> -- Slot Names: earrings, rings, leftear, rightear, leftfinger, rightfinger, face, head, neck, shoulder, chest, feet, arms, leftwrist, rightwrist, wrists, charm, powersource, mainhand, offhand, ranged, ammo, legs, waist, hands'
    output = output .. '\n\ayBuff Begging:\aw /tell <name> <alias> -- Aliases: '
    for alias,_ in pairs(aqoclass.requestAliases) do
        output = output .. alias .. ', '
    end
    output = output .. '\ax'
    print(output)
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
    local new_value = args[2] and args[2]:lower() or nil
    if opt == 'help' then
        show_help()
    elseif opt == 'restart' then
        mq.cmd('/multiline ; /lua stop aqo ; /timed 5 /lua run aqo')
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
            if config.booleans[new_value] == nil then return end
            state.paused = config.booleans[new_value]
            if state.paused then
                state.reset_combat_state()
                mq.cmd('/stopcast')
            else
                camp.set_camp()
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
            print(logger.logLine('Mode: %s', config.MODE:get_name()))
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
        print(logger.logLine('assist: %s', config.ASSIST))
    elseif opt == 'ignore' then
        local zone = mq.TLO.Zone.ShortName()
        if new_value then
            config.add_ignore(zone, args[2]) -- use not lowercased value
        else
            local target_name = mq.TLO.Target.CleanName()
            if target_name then config.add_ignore(zone, target_name) end
        end
    elseif opt == 'unignore' then
        local zone = mq.TLO.Zone.ShortName()
        if new_value then
            config.remove_ignore(zone, args[2]) -- use not lowercased value
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
            print(logger.logLine('addclicky Usage:\n\tPlace clicky item on cursor\n\t/%s addclicky category\n\tCategories: burn, mash, heal, buff', state.class))
        end
    elseif opt == 'removeclicky' then
        local itemName = mq.TLO.Cursor()
        if itemName then
            aqoclass.removeClicky(itemName)
            aqoclass.save_settings()
        else
            print(logger.logLine('removeclicky Usage:\n\tPlace clicky item on cursor\n\t/%s removeclicky', state.class))
        end
    elseif opt == 'invis' then
        if aqoclass.invis then
            aqoclass.invis()
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
    elseif opt == 'nowcast' then
        aqoclass.nowCast(args)
    elseif opt == 'update' then
        os.execute('start https://github.com/aquietone/aqobot/archive/refs/heads/emu.zip')
    elseif opt == 'docs' then
        os.execute('start https://aquietone.github.io/docs/aqobot/classes/'..state.class)
    elseif opt == 'wiki' then
        os.execute('start https://www.lazaruseq.com/Wiki/index.php/Main_Page')
    elseif opt == 'baz' then
        os.execute('start https://www.lazaruseq.com/Magelo/index.php?page=bazaar')
    elseif opt == 'door' then
        mq.cmd('/dgga /doortarget')
        mq.delay(50)
        mq.cmd('/dgga /click left door')
    elseif opt == 'manastone' then
        local manastone = mq.TLO.FindItem('Manastone')
        if not manastone() then return end
        local manastoneTimer = timer:new(5)
        manastoneTimer:reset()
        while mq.TLO.Me.PctHPs() > 50 and mq.TLO.Me.PctMana() < 90 do
            mq.cmd('/useitem Manastone')
            if manastoneTimer:timer_expired() then break end
        end
    else
        aqoclass.process_cmd(opt:upper(), new_value)
    end
end

local function zoned()
    state.reset_combat_state()
    if state.currentZone == mq.TLO.Zone.ID() then
        -- evac'd
        camp.set_camp()
        movement.stop()
    end
    state.currentZone = mq.TLO.Zone.ID()
    mq.cmd('/pet ghold on')
    if not state.paused and config.MODE:is_pull_mode() then
        config.MODE = mode.from_string('manual')
        camp.set_camp()
        movement.stop()
    end
end

local lootMyBody = false
local function rezzed()
    lootMyBody = true
end

local function movecloser()
    if config.MODE:is_assist_mode() and not state.paused then
        movement.navToTarget(nil, 1000)
    end
end

local function init()
    state.class = mq.TLO.Me.Class.ShortName():lower()
    state.currentZone = mq.TLO.Zone.ID()
    state.subscription = mq.TLO.Me.Subscription()
    if mq.TLO.EverQuest.Server() == 'Project Lazarus' or mq.TLO.EverQuest.Server() == 'EZ (Linux) x4 Exp' then state.emu = true end
    common.set_swap_gem()

    mq.bind('/aqo', cmd_bind)
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
    mq.event('CannotSee', '#*#cannot see your target#*#', movecloser)
    mq.event('TooFar', '#*#too far away from your target#*#', movecloser)
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
        detect_raid_or_group()

        if not mq.TLO.Target() then
            state.assist_mob_id = 0
            state.tank_mob_id = 0
            if (mq.TLO.Me.Combat() or mq.TLO.Me.AutoFire()) then
                mq.cmd('/multiline ; /attack off; /autofire off;')
            end
        end
        if state.class == 'nec' and state.loop.PctHPs < 40 and aqoclass.spells.lich then
            mq.cmdf('/removebuff %s', aqoclass.spells.lich.name)
        end
        if not state.paused and common.in_control() and not common.am_i_dead() then
            camp.clean_targets()
            if mq.TLO.Target() and mq.TLO.Target.Type() == 'Corpse' then
                state.tank_mob_id = 0
                state.assist_mob_id = 0
                if not common.HEALER_CLASSES[state.class] then
                    mq.cmd('/squelch /mqtarget clear')
                end
            end
            if not mq.TLO.Me.Casting() and state.loop.PetID > 0 and mq.TLO.Target.ID() == state.loop.PetID then
                mq.cmd('/squelch /mqtarget clear')
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
                    if mq.TLO.Spawn('corpse '..mq.TLO.Me.CleanName())() then
                        loot.lootMyCorpse()
                        state.actionTaken = true
                    end
                    if config.LOOTMOBS and mq.TLO.Me.CombatState() ~= 'COMBAT' and not state.pull_in_progress then
                        state.actionTaken = loot.lootMobs()
                        if state.lootBeforePull then state.lootBeforePull = false end
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
