--- @type Mq
local mq = require('mq')

local aqo
local commands = {
    help = {
        {command='help', tip='Output the help text'},
        {command='burnnow', tip='Activate burn abilities'},
        {command='pause [on|1|off|0]', tip='Pause or resume the script'},
        {command='show', tip='Display the UI window'},
        {command='hide', tip='Hide the UI window'},
        {command='mode [mode]', tip='Set the current mode of the script. Valid Modes:\n0|manual|1|assist|2|chase|3|vorpal|4|tank|5|pullertank|6|puller|7|huntertank'},
        {command='resetcamp', tip='Reset the centerpoint of the camp to your current X,Y,Z coordinates'},
        {command='addclicky <mash|burn|buff|heal>', tip='Adds the currently held item to the clicky group specified'},
        {command='removeclicky', tip='Removes the currently held item from clickies'},
        {command='door', tip='Click the nearest door'},
        {command='ignore', tip='Adds the targeted mob to the ignore list for the current zone'},
        {command='unignore', tip='Removes the targeted mob from the ignore list for the current zone'},
        {command='sell', tip='Sells items marked to be sold to the targeted or already opened vendor'},
        {command='update', tip='Downloads the latest source zip'},
        {command='docs', tip='Launches the documentation site in a browser window'},
        {command='wiki', tip='Launches the Lazarus wiki in a browser window'},
        {command='baz', tip='Launches the Lazarus Bazaar in a browser window'},
        {command='manastone', tip='Spam manastone to get some mana back'},
    }
}

function commands.init(_aqo)
    aqo = _aqo

    mq.bind('/aqo', commands.commandHandler)
    mq.bind(('/%s'):format(aqo.state.class), commands.commandHandler)
    mq.bind('/nowcast', commands.nowcastHandler)
end

---Display help information for the script.
local function showHelp()
    local prefix = '\n- /'..aqo.state.class..' '
    local output = aqo.logger.logLine('AQO Bot 1.0\n')
    output = output .. '\ayCommands:\aw'
    for _,command in ipairs(commands.help) do
        output = output .. prefix .. command.command .. ' -- ' .. command.tip
    end
    output = output .. '\n\ayGeneric Configuration\aw'
    for key,cfg in pairs(aqo.config) do
        if type(cfg) == 'table' then
            output = output .. prefix .. key .. ' <' .. type(cfg.value) .. '> -- '..cfg.tip
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
    output = output .. '\n\ayGear Check:\aw /tell <name> gear <slotname> -- Slot Names: ' .. aqo.lists.slotList
    output = output .. '\n\ayBuff Begging:\aw /tell <name> <alias> -- Aliases: '
    for alias,_ in pairs(aqo.class.requestAliases) do
        output = output .. alias .. ', '
    end
    output = (output .. '\ax'):gsub('cls', aqo.state.class)
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

    local opt = args[1]:lower()
    local new_value = args[2] and args[2]:lower() or nil
    local configName = aqo.config.getNameForAlias(opt)
    if opt == 'help' then
        showHelp()
    elseif opt == 'restart' then
        mq.cmd('/multiline ; /lua stop aqo ; /timed 5 /lua run aqo')
    elseif opt == 'debug' then
        local section = args[2]
        local subsection = args[3]
        if aqo.logger.flags[section] and aqo.logger.flags[section][subsection] ~= nil then
            aqo.logger.flags[section][subsection] = not aqo.logger.flags[section][subsection]
        end
    elseif opt == 'sell' and not new_value then
        aqo.loot.sellStuff()
    elseif opt == 'burnnow' then
        aqo.state.burnNow = true
        if new_value == 'quick' or new_value == 'long' then
            aqo.state.burn_type = new_value
        end
    elseif opt == 'preburn' then
        if aqo.class.preburn then aqo.class.preburn() end
    elseif opt == 'pause' then
        if not new_value then
            aqo.state.paused = not aqo.state.paused
            if aqo.state.paused then
                aqo.state.resetCombatState()
                mq.cmd('/stopcast')
            end
        else
            if aqo.lists.booleans[new_value] == nil then return end
            aqo.state.paused = aqo.lists.booleans[new_value]
            if aqo.state.paused then
                aqo.state.resetCombatState()
                mq.cmd('/stopcast')
            else
                aqo.camp.setCamp()
            end
        end
    elseif opt == 'show' then
        aqo.ui.toggleGUI(true)
    elseif opt == 'hide' then
        aqo.ui.toggleGUI(false)
    elseif opt == 'mode' then
        if new_value then
            aqo.config.MODE.value = aqo.mode.fromString(new_value) or aqo.config.MODE.value
            aqo.state.resetCombatState()
        else
            print(aqo.logger.logLine('Mode: %s', aqo.config.MODE.value:getName()))
        end
        aqo.camp.setCamp()
    elseif opt == 'resetcamp' then
        aqo.camp.setCamp(true)
    elseif opt == 'campradius' or opt == 'radius' or opt == 'pullarc' then
        aqo.config.getOrSetOption(opt, aqo.config[configName].value, new_value, configName)
        aqo.camp.setCamp()
    elseif opt == 'timestamps' then
        aqo.config.getOrSetOption(opt, aqo.config[configName].value, new_value, configName)
        aqo.logger.timestamps = aqo.config[configName].value
    elseif configName then
        aqo.config.getOrSetOption(opt, aqo.config[configName].value, new_value, configName)
    elseif opt == 'groupwatch' and aqo.common.GROUP_WATCH_OPTS[new_value] then
        aqo.config.getOrSetOption(opt, aqo.config[configName].value, new_value, configName)
    elseif opt == 'assist' then
        if new_value and aqo.common.ASSISTS[new_value] then
            aqo.config.ASSIST.value = new_value
        end
        print(aqo.logger.logLine('assist: %s', aqo.config.ASSIST.value))
    elseif opt == 'ignore' then
        local zone = mq.TLO.Zone.ShortName()
        if new_value then
            aqo.config.addIgnore(zone, args[2]) -- use not lowercased value
        else
            local target_name = mq.TLO.Target.CleanName()
            if target_name then aqo.config.addIgnore(zone, target_name) end
        end
    elseif opt == 'unignore' then
        local zone = mq.TLO.Zone.ShortName()
        if new_value then
            aqo.config.removeIgnore(zone, args[2]) -- use not lowercased value
        else
            local target_name = mq.TLO.Target.CleanName()
            if target_name then aqo.config.removeIgnore(zone, target_name) end
        end
    elseif opt == 'addclicky' then
        local clickyType = new_value
        local itemName = mq.TLO.Cursor()
        if itemName then
            local clicky = {name=itemName, clickyType=clickyType}
            aqo.class.addClicky(clicky)
            aqo.class.saveSettings()
        else
            print(aqo.logger.logLine('addclicky Usage:\n\tPlace clicky item on cursor\n\t/%s addclicky category\n\tCategories: burn, mash, heal, buff', aqo.state.class))
        end
    elseif opt == 'removeclicky' then
        local itemName = mq.TLO.Cursor()
        if itemName then
            aqo.class.removeClicky(itemName)
            aqo.class.saveSettings()
        else
            print(aqo.logger.logLine('removeclicky Usage:\n\tPlace clicky item on cursor\n\t/%s removeclicky', aqo.state.class))
        end
    elseif opt == 'listclickies' then
        local clickies = ''
        for _,clicky in ipairs(aqo.class.clickies) do
            clickies = clickies .. '\n- ' .. clicky.name .. ' (' .. clicky.clickyType .. ')'
        end
        print(aqo.logger.logLine('Clickies: %s', clickies))
    elseif opt == 'invis' then
        if aqo.class.invis then
            aqo.class.invis()
        end
    elseif opt == 'tribute' then
        aqo.common.toggleTribute()
    elseif opt == 'bark' then
        local repeatstring = ''
        for i=2,#args do
            repeatstring = repeatstring .. ' ' .. args[i]
        end
        mq.cmdf('/dgga /say %s', repeatstring)
    elseif opt == 'force' then
        aqo.assist.forceAssist(new_value)
    elseif opt == 'update' then
        os.execute('start https://github.com/aquietone/aqobot/archive/refs/heads/emu.zip')
    elseif opt == 'docs' then
        os.execute('start https://aquietone.github.io/docs/aqobot/classes/'..aqo.state.class)
    elseif opt == 'wiki' then
        os.execute('start https://www.lazaruseq.com/Wiki/index.php/Main_Page')
    elseif opt == 'baz' then
        os.execute('start https://www.lazaruseq.com/Magelo/index.php?page=bazaar')
    elseif opt == 'door' then
        mq.cmd('/doortarget')
        mq.delay(50)
        mq.cmd('/click left door')
    elseif opt == 'manastone' then
        local manastone = mq.TLO.FindItem('Manastone')
        if not manastone() then return end
        local manastoneTimer = aqo.timer:new(5)
        manastoneTimer:reset()
        while mq.TLO.Me.PctHPs() > 50 and mq.TLO.Me.PctMana() < 90 do
            mq.cmd('/useitem Manastone')
            if manastoneTimer:timerExpired() then break end
        end
    else
        commands.classSettingsHandler(opt:upper(), new_value)
    end
end

function commands.classSettingsHandler(opt, new_value)
    if new_value then
        if opt == 'SPELLSET' and aqo.class.OPTS.SPELLSET ~= nil then
            if aqo.class.spellRotations[new_value] then
                print(aqo.logger.logLine('Setting %s to: %s', opt, new_value))
                aqo.class.OPTS.SPELLSET.value = new_value
            end
        elseif opt == 'USEEPIC' and aqo.class.OPTS.USEEPIC ~= nil then
            if aqo.class.EPIC_OPTS[new_value] then
                print(aqo.logger.logLine('Setting %s to: %s', opt, new_value))
                aqo.class.OPTS.USEEPIC.value = new_value
            end
        elseif opt == 'AURA1' and aqo.class.OPTS.AURA1 ~= nil then
            if aqo.class.AURAS[new_value] then
                print(aqo.logger.logLine('Setting %s to: %s', opt, new_value))
                aqo.class.OPTS.AURA1.value = new_value
            end
        elseif opt == 'AURA2' and aqo.class.OPTS.AURA2 ~= nil then
            if aqo.class.AURAS[new_value] then
                print(aqo.logger.logLine('Setting %s to: %s', opt, new_value))
                aqo.class.OPTS.AURA2.value = new_value
            end
        elseif aqo.class.OPTS[opt] and type(aqo.class.OPTS[opt].value) == 'boolean' then
            if aqo.lists.booleans[new_value] == nil then return end
            aqo.class.OPTS[opt].value = aqo.lists.booleans[new_value]
            print(aqo.logger.logLine('Setting %s to: %s', opt, aqo.lists.booleans[new_value]))
        elseif aqo.class.OPTS[opt] and type(aqo.class.OPTS[opt].value) == 'number' then
            if tonumber(new_value) then
                print(aqo.logger.logLine('Setting %s to: %s', opt, tonumber(new_value)))
                if aqo.class.OPTS[opt].value ~= nil then aqo.class.OPTS[opt].value = tonumber(new_value) end
            end
        else
            print(aqo.logger.logLine('Unsupported command line option: %s %s', opt, new_value))
        end
    else
        if aqo.class.OPTS[opt] ~= nil then
            print(aqo.logger.logLine('%s: %s', opt:lower(), aqo.class.OPTS[opt].value))
        else
            print(aqo.logger.logLine('Unrecognized option: %s', opt))
        end
    end
end

function commands.nowcastHandler(...)
    aqo.class.nowCast({...})
end

return commands