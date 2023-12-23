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

local class
local commands = {}

function commands.init(_class)
    class = _class

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
    for key,value in pairs(class.OPTS) do
        local valueType = type(value.value)
        if valueType == 'string' or valueType == 'number' or valueType == 'boolean' then
            output = output .. prefix .. key .. ' <' .. valueType .. '>'
            if value.tip then output = output .. ' -- '..value.tip end
        end
    end
    output = output .. '\n\ayGear Check:\aw /tell <name> gear <slotname> -- Slot Names: ' .. constants.slotList
    output = output .. '\n\ayBuff Begging:\aw /tell <name> <alias> -- Aliases: '
    for alias,_ in pairs(class.requestAliases) do
        output = output .. alias .. ', '
    end
    output = (output .. '\ax'):gsub('cls', state.class)
    -- output is too long for the boring old chat window
    if not mq.TLO.Plugin('MQ2ChatWnd').IsLoaded() then logger.info(output) end
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
        logger.info('\arActivating Burns (on demand%s)\ax', state.burn_type and ' - '..state.burn_type or '')
        state.burnNow = true
        if constants.burns[new_value] then
            state.burn_type = new_value
        end
    elseif opt == 'PREBURN' then
        if class.preburn then class:preburn() end
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
        local nextIndex = 3
        if not itemName then
            itemName = args[3]
            nextIndex = 4
        end
        if args[nextIndex] then
            if tonumber(args[nextIndex]) then
                summonMinimum = tonumber(args[nextIndex])
            else
                useif = args[nextIndex]
            end
            nextIndex = nextIndex + 1
        end
        if args[nextIndex] then
            if tonumber(args[nextIndex]) then
                summonMinimum = tonumber(args[nextIndex])
            else
                useif = args[nextIndex]
            end
        end
        if itemName then
            local clicky = {name=itemName, clickyType=clickyType, summonMinimum=summonMinimum, opt=useif}
            class:addClicky(clicky)
            class:saveSettings()
        else
            logger.info('addclicky Usage:\n\tPlace clicky item on cursor\n\t/%s addclicky category\n\tCategories: burn, mash, heal, buff', state.class)
        end
    elseif opt == 'REMOVECLICKY' then
        local itemName = mq.TLO.Cursor()
        if not itemName then
            itemName = args[2]
        end
        if itemName then
            class:removeClicky(itemName)
            class:saveSettings()
        else
            logger.info('removeclicky Usage:\n\tPlace clicky item on cursor\n\t/%s removeclicky', state.class)
        end
    elseif opt == 'ENABLECLICKY' then
        local itemName = mq.TLO.Cursor()
        if not itemName then
            itemName = args[2]
        end
        if itemName then
            class:enableClicky(itemName)
            class:saveSettings()
        else
            logger.info('enableclickyUsage:\n\tPlace clicky item on cursor\n\t/%s enableclicky', state.class)
        end
    elseif opt == 'DISABLECLICKY' then
        local itemName = mq.TLO.Cursor()
        if not itemName then
            itemName = args[2]
        end
        if itemName then
            class:disableClicky(itemName)
            class:saveSettings()
        else
            logger.info('disableclickyUsage:\n\tPlace clicky item on cursor\n\t/%s disableclicky', state.class)
        end
    elseif opt == 'LISTCLICKIES' then
        local clickies = ''
        for clickyName,clicky in pairs(class.clickies) do
            clickies = clickies .. '\n- ' .. clickyName .. ' (' .. clicky.clickyType .. ') Enabled='..tostring(clicky.enabled)
        end
        logger.info('Clickies: %s', clickies)
    elseif opt == 'INVIS' then
        if class.invis then
            class:invis()
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
    elseif opt == 'PAUSEFORBUFFS' then
        if mode.currentMode:getName() == 'huntertank' then
            movement.stop()
            state.holdForBuffs = timer:new(15000)
            logger.info('Holding pulls for 15 seconds for buffing')
        end
    elseif opt == 'RESUMEFORBUFFS' then
        if mode.currentMode:getName() == 'huntertank' then
            state.holdForBuffs = nil
        end
    elseif opt == 'ARMPETS' then
        class:armPets()
    else
        commands.classSettingsHandler(opt, new_value)
    end
end

function commands.classSettingsHandler(opt, new_value)
    if new_value then
        if opt == 'SPELLSET' and class.OPTS.SPELLSET ~= nil then
            if class.spellRotations[new_value] then
                logger.info('Setting %s to: %s', opt, new_value)
                class.OPTS.SPELLSET.value = new_value
            end
        elseif opt == 'USEEPIC' and class.OPTS.USEEPIC ~= nil then
            if class.EPIC_OPTS[new_value] then
                logger.info('Setting %s to: %s', opt, new_value)
                class.OPTS.USEEPIC.value = new_value
            end
        elseif opt == 'AURA1' and class.OPTS.AURA1 ~= nil then
            if class.AURAS[new_value] then
                logger.info('Setting %s to: %s', opt, new_value)
                class.OPTS.AURA1.value = new_value
            end
        elseif opt == 'AURA2' and class.OPTS.AURA2 ~= nil then
            if class.AURAS[new_value] then
                logger.info('Setting %s to: %s', opt, new_value)
                class.OPTS.AURA2.value = new_value
            end
        elseif class.OPTS[opt] and type(class.OPTS[opt].value) == 'boolean' then
            if constants.booleans[new_value] == nil then return end
            class.OPTS[opt].value = constants.booleans[new_value]
            logger.info('Setting %s to: %s', opt, constants.booleans[new_value])
        elseif class.OPTS[opt] and type(class.OPTS[opt].value) == 'number' then
            if tonumber(new_value) then
                logger.info('Setting %s to: %s', opt, tonumber(new_value))
                if class.OPTS[opt].value ~= nil then class.OPTS[opt].value = tonumber(new_value) end
            end
        else
            logger.info('Unsupported command line option: %s %s', opt, new_value)
        end
    else
        if class.OPTS[opt] ~= nil then
            logger.info('%s: %s', opt:lower(), class.OPTS[opt].value)
        else
            logger.info('Unrecognized option: %s', opt)
        end
    end
end

function commands.nowcastHandler(...)
    class:nowCast({...})
end

return commands