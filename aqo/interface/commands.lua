--- @type Mq
local mq = require('mq')
local config = require('interface.configuration')
local ui = require('interface.ui')
local assist = require('routines.assist')
local camp = require('routines.camp')
local helpers = require('utils.helpers')
local logger = require('utils.logger')
local loot = require('utils.lootutils')
local movement = require('utils.movement')
local timer = require('utils.timer')
local constants = require('constants')
local mode = require('mode')
local state = require('state')

local aqo
local commands = {}

function commands.init(_aqo)
    aqo = _aqo

    mq.bind('/aqo', commands.commandHandler)
    mq.bind(('/%s'):format(state.class), commands.commandHandler)
    mq.bind('/nowcast', commands.nowcastHandler)
end

---Display help information for the script.
local function showHelp()
    local myClass = mq.TLO.Me.Class.ShortName():lower()
    local prefix = '\n- /'..state.class..' '
    local output = logger.logLine('AQO Bot 1.0\n')
    output = output .. '\ayCommands:\aw'
    for _,command in ipairs(constants.commandHelp) do
        output = output .. prefix .. command.command .. ' -- ' .. command.tip
    end
    output = output .. '\n- /nowcast [name] alias <targetID> -- Tells the named character or yourself to cast a spell on the specified target ID.'
    for _,category in ipairs(config.categories()) do
        output = output .. '\n\ay' .. category .. ' configuration:\aw'
        for _,key in ipairs(config.getByCategory(category)) do
            local cfg = config[key]
            if type(cfg) == 'table' and (not cfg.classes or cfg.classes[myClass]) then
                output = output .. prefix .. key .. ' <' .. type(cfg.value) .. '> -- '..cfg.tip
            end
        end
    end
    output = output .. '\n\ayClass Configuration\aw'
    for key,value in pairs(aqo.class.OPTS) do
        local valueType = type(value.value)
        if valueType == 'string' or valueType == 'number' or valueType == 'boolean' then
            output = output .. prefix .. key .. ' <' .. valueType .. '>'
            if value.tip then output = output .. ' -- '..value.tip end
        end
    end
    output = output .. '\n\ayGear Check:\aw /tell <name> gear <slotname> -- Slot Names: ' .. constants.slotList
    output = output .. '\n\ayBuff Begging:\aw /tell <name> <alias> -- Aliases: '
    for alias,_ in pairs(aqo.class.requestAliases) do
        output = output .. alias .. ', '
    end
    output = (output .. '\ax'):gsub('cls', state.class)
    -- output is too long for the boring old chat window
    if not mq.TLO.Plugin.IsLoaded('MQ2ChatWnd')() then print(output) end
end

---Process binding commands.
---@vararg string @The input given to the bind command.
function commands.commandHandler(...)
    local args = {...}
    if not args[1] then
        showHelp()
        return
    end

    local opt = args[1]:upper()
    local new_value = args[2] and args[2]:lower()
    local configName = config[opt] and opt or nil
    if opt == 'HELP' then
        showHelp()
    elseif opt == 'RESTART' then
        mq.cmd('/multiline ; /lua stop aqo ; /timed 5 /lua run aqo')
    elseif opt == 'DEBUG' then
        local section = args[2]
        local subsection = args[3]
        if logger.flags[section] and logger.flags[section][subsection] ~= nil then
            logger.flags[section][subsection] = not logger.flags[section][subsection]
        end
    elseif opt == 'SELL' and not new_value then
        loot.sellStuff()
    elseif opt == 'BURNNOW' then
        print(logger.logLine('\arActivating Burns (on demand%s)\ax', state.burn_type and ' - '..state.burn_type or ''))
        state.burnNow = true
        if new_value == 'quick' or new_value == 'long' then
            state.burn_type = new_value
        end
    elseif opt == 'PREBURN' then
        if aqo.class.preburn then aqo.class.preburn() end
    elseif opt == 'PAUSE' then
        if not new_value then
            state.paused = not state.paused
            if state.paused then
                state.resetCombatState()
                mq.cmd('/stopcast')
            end
        else
            if constants.booleans[new_value] == nil then return end
            state.paused = constants.booleans[new_value]
            if state.paused then
                state.resetCombatState()
                mq.cmd('/stopcast')
            else
                camp.setCamp()
            end
        end
    elseif opt == 'SHOW' then
        ui.toggleGUI(true)
    elseif opt == 'HIDE' then
        ui.toggleGUI(false)
    elseif opt == 'MODE' then
        local current_mode = config.get('MODE')
        if new_value then new_value = mode.nameFromString(new_value) end
        config.getOrSetOption(opt, config.get(configName), new_value, configName)
        if config.get('MODE') ~= current_mode then
            mode.currentMode = mode.fromString(config.get('MODE'))
            state.resetCombatState()
            if not state.paused then camp.setCamp() end
        end
    elseif opt == 'RESETCAMP' then
        camp.setCamp(true)
    elseif opt == 'CAMPRADIUS' or opt == 'RADIUS' or opt == 'PULLARC' then
        config.getOrSetOption(opt, config.get(configName), new_value, configName)
        camp.setCamp()
    elseif opt == 'TIMESTAMPS' then
        config.getOrSetOption(opt, config.get(configName), new_value, configName)
        logger.timestamps = config.get(configName)
    elseif configName then
        config.getOrSetOption(opt, config.get(configName), new_value, configName)
    elseif opt == 'IGNORE' then
        local zone = mq.TLO.Zone.ShortName()
        if new_value then
            config.addIgnore(zone, args[2]) -- use not lowercased value
        else
            local target_name = mq.TLO.Target.CleanName()
            if target_name then config.addIgnore(zone, target_name) end
        end
    elseif opt == 'UNIGNORE' then
        local zone = mq.TLO.Zone.ShortName()
        if new_value then
            config.removeIgnore(zone, args[2]) -- use not lowercased value
        else
            local target_name = mq.TLO.Target.CleanName()
            if target_name then config.removeIgnore(zone, target_name) end
        end
    elseif opt == 'ADDCLICKY' then
        local clickyType = new_value
        local itemName = mq.TLO.Cursor()
        local summonMinimum = nil
        local useif = nil
        if args[3] then
            if tonumber(args[3]) then
                summonMinimum = tonumber(args[3])
            else
                useif = args[3]
            end
        end
        if args[4] then
            if tonumber(args[4]) then
                summonMinimum = tonumber(args[4])
            else
                useif = args[4]
            end
        end
        if itemName then
            local clicky = {name=itemName, clickyType=clickyType, summonMinimum=summonMinimum, opt=useif}
            aqo.class.addClicky(clicky)
            aqo.class.saveSettings()
        else
            print(logger.logLine('addclicky Usage:\n\tPlace clicky item on cursor\n\t/%s addclicky category\n\tCategories: burn, mash, heal, buff', state.class))
        end
    elseif opt == 'REMOVECLICKY' then
        local itemName = mq.TLO.Cursor()
        if itemName then
            aqo.class.removeClicky(itemName)
            aqo.class.saveSettings()
        else
            print(logger.logLine('removeclicky Usage:\n\tPlace clicky item on cursor\n\t/%s removeclicky', state.class))
        end
    elseif opt == 'LISTCLICKIES' then
        local clickies = ''
        for clickyName,clicky in pairs(aqo.class.clickies) do
            clickies = clickies .. '\n- ' .. clickyName .. ' (' .. clicky.clickyType .. ')'
        end
        print(logger.logLine('Clickies: %s', clickies))
    elseif opt == 'INVIS' then
        if aqo.class.invis then
            aqo.class.invis()
        end
    elseif opt == 'TRIBUTE' then
        mq.cmd('/keypress TOGGLE_TRIBUTEBENEFITWIN')
        mq.cmd('/notify TBW_PersonalPage TBWP_ActivateButton leftmouseup')
        mq.cmd('/keypress TOGGLE_TRIBUTEBENEFITWIN')
    elseif opt == 'BARK' then
        local repeatstring = ''
        for i=2,#args do
            repeatstring = repeatstring .. ' ' .. args[i]
        end
        mq.cmdf('/dgga /say %s', repeatstring)
    elseif opt == 'FORCE' then
        assist.forceAssist(new_value)
    elseif opt == 'UPDATE' then
        os.execute('start https://github.com/aquietone/aqobot/archive/refs/heads/emu.zip')
    elseif opt == 'DOCS' then
        os.execute('start https://aquietone.github.io/docs/aqobot/classes/'..state.class)
    elseif opt == 'WIKI' then
        os.execute('start https://www.lazaruseq.com/Wiki/index.php/Main_Page')
    elseif opt == 'BAZ' then
        os.execute('start https://www.lazaruseq.com/Magelo/index.php?page=bazaar')
    elseif opt == 'DOOR' then
        mq.cmd('/doortarget')
        mq.delay(50)
        mq.cmd('/click left door')
    elseif opt == 'MANASTONE' then
        local manastone = mq.TLO.FindItem('Manastone')
        if not manastone() then return end
        local manastoneTimer = timer:new(5000)
        while mq.TLO.Me.PctHPs() > 50 and mq.TLO.Me.PctMana() < 90 do
            mq.cmd('/useitem Manastone')
            if manastoneTimer:timerExpired() then break end
        end
    elseif opt == 'BUFFLIST' then
        local buffSet = helpers.splitSet(args[4])
        state.buffs[new_value] = {class=args[3], buffs=buffSet}
    elseif opt == 'SICKLIST' then
        local sickList = helpers.split(args[3])
        state.sick[new_value] = sickList
    elseif opt == 'PAUSEFORBUFFS' then
        if mode.currentMode:getName() == 'huntertank' then
            movement.stop()
            state.holdForBuffs = timer:new(15000)
            print(logger.logLine('Holding pulls for 15 seconds for buffing'))
        end
    elseif opt == 'RESUMEFORBUFFS' then
        if mode.currentMode:getName() == 'huntertank' then
            state.holdForBuffs = nil
        end
    elseif opt == 'ARMPETS' then
        aqo.class.armPets()
    else
        commands.classSettingsHandler(opt, new_value)
    end
end

function commands.classSettingsHandler(opt, new_value)
    if new_value then
        if opt == 'SPELLSET' and aqo.class.OPTS.SPELLSET ~= nil then
            if aqo.class.spellRotations[new_value] then
                print(logger.logLine('Setting %s to: %s', opt, new_value))
                aqo.class.OPTS.SPELLSET.value = new_value
            end
        elseif opt == 'USEEPIC' and aqo.class.OPTS.USEEPIC ~= nil then
            if aqo.class.EPIC_OPTS[new_value] then
                print(logger.logLine('Setting %s to: %s', opt, new_value))
                aqo.class.OPTS.USEEPIC.value = new_value
            end
        elseif opt == 'AURA1' and aqo.class.OPTS.AURA1 ~= nil then
            if aqo.class.AURAS[new_value] then
                print(logger.logLine('Setting %s to: %s', opt, new_value))
                aqo.class.OPTS.AURA1.value = new_value
            end
        elseif opt == 'AURA2' and aqo.class.OPTS.AURA2 ~= nil then
            if aqo.class.AURAS[new_value] then
                print(logger.logLine('Setting %s to: %s', opt, new_value))
                aqo.class.OPTS.AURA2.value = new_value
            end
        elseif aqo.class.OPTS[opt] and type(aqo.class.OPTS[opt].value) == 'boolean' then
            if constants.booleans[new_value] == nil then return end
            aqo.class.OPTS[opt].value = constants.booleans[new_value]
            print(logger.logLine('Setting %s to: %s', opt, constants.booleans[new_value]))
        elseif aqo.class.OPTS[opt] and type(aqo.class.OPTS[opt].value) == 'number' then
            if tonumber(new_value) then
                print(logger.logLine('Setting %s to: %s', opt, tonumber(new_value)))
                if aqo.class.OPTS[opt].value ~= nil then aqo.class.OPTS[opt].value = tonumber(new_value) end
            end
        else
            print(logger.logLine('Unsupported command line option: %s %s', opt, new_value))
        end
    else
        if aqo.class.OPTS[opt] ~= nil then
            print(logger.logLine('%s: %s', opt:lower(), aqo.class.OPTS[opt].value))
        else
            print(logger.logLine('Unrecognized option: %s', opt))
        end
    end
end

function commands.nowcastHandler(...)
    aqo.class.nowCast({...})
end

return commands