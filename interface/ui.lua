local mq = require('mq')
require 'ImGui'
local icons = require('mq.icons')

local config = require('interface.configuration')
local customAbilities = require('interface.customabilityui')
local widgets = require('libaqo.widgets')
local camp = require('routines.camp')
local pull = require('routines.pull')
local helpers = require('utils.helpers')
local logger = require('utils.logger')
local guiLoot = require('interface.loot_hist')
local constants = require('constants')
local mode = require('mode')
local state = require('state')

-- UI Control variables
local openGUI, shouldDrawGUI, minimize = true, true, true
local stateGUIOpen, shouldDrawStateGUI = false, false
local spellRotationUIOpen, shouldDrawSpellRotationUI = false, false
local abilityGUIOpen, shouldDrawAbilityGUI = false, false
local clickyManagerOpen, shouldDrawClickyManager = false, false
local helpGUIOpen, shouldDrawHelpGUI= false, false
local buffGUIOpen, showBuffGUI = false, false

-- UI constants
local MINIMUM_WIDTH = 430
local BUTTON_HEIGHT = 22
local mid_x = 140
local item_width = 115
local X_COLUMN_OFFSET = 265
local Y_COLUMN_OFFSET = 30

local WHITE = ImVec4(1, 1, 1, 1)
local GREEN = ImVec4(0, 1, 0, 1)
local YELLOW = ImVec4(1, 1, 0, 1)
local RED = ImVec4(1, 0, 0, 1)
local LIGHT_BLUE = ImVec4(.6, .8, 1, 1)
local ORANGE = ImVec4(1, .65, 0, 1)
local GREY = ImVec4(.8, .8, .8, 1)
local GOLD = ImVec4(.7, .5, 0, 1)

local class
local ui = {}

local aqoImg = mq.CreateTexture(mq.luaDir .. "/aqo/aqo.png")

function ui.init(_class)
    class = _class
    mq.imgui.init('AQO Bot 1.0', ui.main)
    minimize = config.get('STARTMINIMIZED')
end

function ui.toggleGUI(open)
    openGUI = open
end

function ui.getNextXY(startY, yAvail, xOffset, yOffset, maxY, maxLabelWidth)
    yOffset = yOffset + Y_COLUMN_OFFSET
    if yOffset > maxY then maxY = yOffset end
    if yAvail - yOffset + startY < 27 then
        xOffset = xOffset + maxLabelWidth + item_width
        yOffset = startY
    end
    return xOffset, yOffset, maxY
end

local function drawConfigurationForCategory(configs)
    local x, y = ImGui.GetCursorPos()
    local xOffset = x
    local yOffset = y
    local maxY = yOffset
    local _, yAvail = ImGui.GetContentRegionAvail()

    local maxLabelWidth = 0
    for _,cfgKey in ipairs(configs) do
        local labelSize = ImGui.CalcTextSize(config[cfgKey].label)
        if labelSize > maxLabelWidth then maxLabelWidth = labelSize end
    end
    for _,cfgKey in ipairs(configs) do
        local cfg = config[cfgKey]
        if (cfg.emu == nil or (cfg.emu and state.emu) or (cfg.emu == false and not state.emu)) and
                (cfg.classes == nil or cfg.classes[state.class]) then
            if cfg.type == 'combobox' then
                config.set(cfgKey, widgets.ComboBox(cfg.label, cfg.value, cfg.options, true, cfg.tip, item_width, xOffset, yOffset))
                xOffset, yOffset, maxY = ui.getNextXY(y, yAvail, xOffset, yOffset, maxY, maxLabelWidth)
            elseif cfg.type == 'inputtext' then
                config.set(cfgKey, widgets.InputText(cfg.label, cfg.value, cfg.tip, item_width, xOffset, yOffset))
                xOffset, yOffset, maxY = ui.getNextXY(y, yAvail, xOffset, yOffset, maxY, maxLabelWidth)
            elseif cfg.type == 'inputint' then
                config.set(cfgKey, widgets.InputInt(cfg.label, cfg.value, cfg.tip, item_width, xOffset, yOffset))
                xOffset, yOffset, maxY = ui.getNextXY(y, yAvail, xOffset, yOffset, maxY, maxLabelWidth)
            end
        end
    end
    for _,cfgKey in ipairs(configs) do
        local cfg = config[cfgKey]
        if (cfg.emu == nil or (cfg.emu and state.emu) or (cfg.emu == false and not state.emu)) and
                (cfg.classes == nil or cfg.classes[state.class]) then
            if cfg.type == 'checkbox' then
                config.set(cfgKey, widgets.CheckBox(cfg.label, cfg.value, cfg.tip, xOffset, yOffset))
                xOffset, yOffset, maxY = ui.getNextXY(y, yAvail, xOffset, yOffset, maxY, maxLabelWidth)
            end
        end
    end
end

-- Combine Assist and Camp categories
local assistTabConfigs = {
    'ASSIST','AUTOASSISTAT','ASSISTNAMES','SWITCHWITHMA','CAMPRADIUS',
    'STICKCOMMAND','CHASETARGET','CHASEDISTANCE','CHASESTOPDISTANCE','CHASEPAUSED','RESISTSTOPCOUNT',
    'NUKEMANAMIN','DOTMANAMIN','MAINTANK','OFFTANK','LOOTMOBS','LOOTCOMBAT',
}
local function drawAssistTab()
    local x,_ = ImGui.GetContentRegionAvail() - 10
    if ImGui.Button('Reset Camp', x/2, BUTTON_HEIGHT) then
        camp.setCamp(true)
    end
    ImGui.SameLine()
    if ImGui.Button('Return to Camp', x/2, BUTTON_HEIGHT) then
        camp.returnToCamp(true)
    end
    local current_camp_radius = config.get('CAMPRADIUS')

    drawConfigurationForCategory(assistTabConfigs)

    if current_camp_radius ~= config.get('CAMPRADIUS') then
        camp.setCamp()
    end
end

local function drawSkillsTab()
    if ImGui.Button('View Ability Lists', x, BUTTON_HEIGHT) then
        abilityGUIOpen = true
    end
    ImGui.SameLine()
    if ImGui.Button('Manage Clickies', x, BUTTON_HEIGHT) then
        clickyManagerOpen = true
    end
    if class.allDPSSpellGroups then
        ImGui.SameLine()
        if ImGui.Button('Spell Rotation', x, BUTTON_HEIGHT) then
            spellRotationUIOpen = true
        end
    end
    ImGui.SameLine()
    if ImGui.Button('Buffs', x, BUTTON_HEIGHT) then
        buffGUIOpen = true
    end
    local x, y = ImGui.GetCursorPos()
    local xOffset = x
    local yOffset = y
    local maxY = yOffset
    local _, yAvail = ImGui.GetContentRegionAvail()
    local maxLabelWidth = 0
    for _,key in ipairs(class.options) do
        local labelSize = ImGui.CalcTextSize(class.options[key].label)
        if labelSize > maxLabelWidth then maxLabelWidth = labelSize end
    end
    for _,key in ipairs(class.options) do
        if key ~= 'USEGLYPH' and key ~= 'USEINTENSITY' then
            local option = class.options[key]
            if option.type == 'combobox' then
                local newValue = widgets.ComboBox(option.label, option.value, option.options, true, option.tip, item_width, xOffset, yOffset)
                if newValue ~= option.value then option.value = newValue state.spellSetLoaded = nil end
                xOffset, yOffset, maxY = ui.getNextXY(y, yAvail, xOffset, yOffset, maxY, maxLabelWidth)
            elseif option.type == 'inputint' then
                class:set(key, widgets.InputInt(option.label, option.value, option.tip, item_width, xOffset, yOffset))
                xOffset, yOffset, maxY = ui.getNextXY(y, yAvail, xOffset, yOffset, maxY, maxLabelWidth)
            end
        end
    end
    for _,key in ipairs(class.options) do
        if key ~= 'USEGLYPH' and key ~= 'USEINTENSITY' then
            local option = class.options[key]
            if option.type == 'checkbox' then
                local newValue = widgets.CheckBox(option.label, option.value, option.tip, xOffset, yOffset)
                if newValue and option.exclusive then class.options[option.exclusive].value = false end
                if newValue ~= option.value then option.value = newValue state.spellSetLoaded = nil end
                xOffset, yOffset, maxY = ui.getNextXY(y, yAvail, xOffset, yOffset, maxY, maxLabelWidth)
            end
        end
    end
    local xAvail = ImGui.GetContentRegionAvail()
    x, y = ImGui.GetWindowSize()
    if x < xOffset + X_COLUMN_OFFSET or xAvail > 20 then x = math.max(MINIMUM_WIDTH, xOffset + X_COLUMN_OFFSET) ImGui.SetWindowSize(x, y) end
    if y < maxY or y > maxY+35 then ImGui.SetWindowSize(x, maxY+35) end
end

local function drawHealTab()
    drawConfigurationForCategory(config.getByCategory('Heal'))
end

local function drawBurnTab()
    local x,_ = ImGui.GetContentRegionAvail()
    local buttonWidth = (x / 3) - 6
    if ImGui.Button('Burn Now', buttonWidth, BUTTON_HEIGHT) then
        mq.cmdf('/%s burnnow', state.class)
    end
    ImGui.SameLine()
    if ImGui.Button('Quick Burn', buttonWidth, BUTTON_HEIGHT) then
        mq.cmdf('/%s burnnow quick', state.class)
    end
    ImGui.SameLine()
    if ImGui.Button('Long Burn', buttonWidth, BUTTON_HEIGHT) then
        mq.cmdf('/%s burnnow long', state.class)
    end
    drawConfigurationForCategory(config.getByCategory('Burn'))
    if class.drawBurnTab then class:drawBurnTab() end
end

local function drawPullTab()
    local x,_ = ImGui.GetContentRegionAvail()
    local buttonWidth = (x / 2) - 4
    if ImGui.Button('Add Ignore', buttonWidth, BUTTON_HEIGHT) then
        mq.cmdf('/%s ignore', state.class)
    end
    ImGui.SameLine()
    if ImGui.Button('Remove Ignore', buttonWidth, BUTTON_HEIGHT) then
        mq.cmdf('/%s unignore', state.class)
    end
    local current_radius = config.PULLRADIUS.value
    local current_pullarc = config.PULLARC.value

    drawConfigurationForCategory(config.getByCategory('Pull'))

    if current_radius ~= config.get('PULLRADIUS') or current_pullarc ~= config.get('PULLARC') then
        pull.clearPullVars('configupdate')
        camp.setCamp()
    end
end

local function drawRestTab()
    drawConfigurationForCategory(config.getByCategory('Rest'))
end

local function drawDebugComboBox()
    ImGui.PushItemWidth(300)
    if ImGui.BeginCombo('##debugoptions', 'Console Flags...') then
        for category, subcategories in pairs(logger.flags) do
            for subcategory, enabled in pairs(subcategories) do
                logger.flags[category][subcategory] = ImGui.Checkbox(category..' - '..subcategory, enabled)
            end
        end
        ImGui.EndCombo()
    end
    ImGui.PopItemWidth()
end

local function drawDebugTab()
    local x,_ = ImGui.GetContentRegionAvail()
    local buttonWidth = (x / 2) - 4
    if ImGui.Button(icons.FA_REFRESH..' Restart AQO', buttonWidth, BUTTON_HEIGHT) then
        mq.cmd('/multiline ; /lua stop aqo ; /timed 10 /lua run aqo')
    end
    ImGui.SameLine()
    if ImGui.Button(icons.FA_DOWNLOAD..' Update AQO', buttonWidth, BUTTON_HEIGHT) then
        os.execute('start https://github.com/aquietone/aqobot/archive/refs/heads/emu.zip')
    end
    if ImGui.Button('View State Inspector', buttonWidth, BUTTON_HEIGHT) then
        stateGUIOpen = true
    end
    ImGui.SameLine()
    if ImGui.Button('View Loot', buttonWidth, BUTTON_HEIGHT) then
        guiLoot.openGUI = not guiLoot.openGUI
    end
    config.DELAYFORLAG.value = widgets.SliderInt('Delay for Lag', config.DELAYFORLAG.value, 'Set the amount of delay to account for lag in various places', 0, 1000, item_width)
    ImGui.TextColored(YELLOW, 'Mode:')
    ImGui.SameLine()
    ImGui.SetCursorPosX(150)
    ImGui.TextColored(WHITE, '%s', config.get('MODE'))

    ImGui.TextColored(YELLOW, 'Camp:')
    ImGui.SameLine()
    ImGui.SetCursorPosX(150)
    if camp.Active then
        ImGui.TextColored(YELLOW, 'X: %.02f  Y: %.02f  Z: %.02f', camp.X, camp.Y, camp.Z)
        ImGui.TextColored(YELLOW, 'Radius:')
        ImGui.SameLine()
        ImGui.SetCursorPosX(150)
        ImGui.TextColored(YELLOW, '%d', config.CAMPRADIUS.value)
        ImGui.TextColored(YELLOW, 'Distance from camp:')
        ImGui.SameLine()
        ImGui.SetCursorPosX(150)
        ImGui.TextColored(YELLOW, '%d', math.sqrt(helpers.distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), camp.X, camp.Y)))
    else
        ImGui.TextColored(RED, '--')
    end
    if not state.forceEngage then
        if ImGui.Button('Force Engage') then
            state.forceEngage = {ID=mq.TLO.Target.ID(), Name=mq.TLO.Target.CleanName()}
            state.assistMobID = mq.TLO.Target.ID()
        end
    else
        if ImGui.Button('Stop Force Engage') then
            state.forceEngage = nil
            state.assistMobID = 0
        end
        if state.forceEngage then
            ImGui.TextColored(RED, 'Fighting %s (%s)', state.forceEngage.Name, state.forceEngage.ID)
        end
    end
end

---@ConsoleWidget
local console = nil
function ui.setConsole(_console)
    console = _console
end

local function drawConsole()
    drawDebugComboBox()
    ImGui.SameLine()
    config.TIMESTAMPS.value = widgets.CheckBox('Timestamps', config.TIMESTAMPS.value, 'Toggle timestamps on log messages', ImGui.GetCursorPosX(), ImGui.GetCursorPosY()-5)
    logger.timestamps = config.TIMESTAMPS.value
    ImGui.SameLine()
    if ImGui.Button('Clear') then
        console:Clear()
    end
    -- Reduce spacing so everything fits snugly together
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
    local contentSizeX, contentSizeY = ImGui.GetContentRegionAvail()
    console:Render(ImVec2(contentSizeX, contentSizeY))
    ImGui.PopStyleVar()
end

local function drawDisplayTab()
    config.THEME.value = widgets.ComboBox('Theme', config.THEME.value, constants.uiThemes, true, 'Pick a UI color scheme', item_width)
    config.OPACITY.value = widgets.SliderInt('Opacity', config.OPACITY.value, 'Set the window opacity', 0, 100, item_width)
    config.STARTMINIMIZED.value = widgets.CheckBox(config.STARTMINIMIZED.label, config.STARTMINIMIZED.value, config.STARTMINIMIZED.tip)
end

local uiTabs = {
    {label=icons.MD_CHAT..' Console', draw=drawConsole},
    {label=icons.MD_SETTINGS..' General', draw=drawAssistTab, color=GREY},
    {label=icons.FA_LIST_UL..' Skills', draw=drawSkillsTab, color=GOLD},
    {label=icons.FA_HEART..' Heal', draw=drawHealTab, color=LIGHT_BLUE},
    {label=icons.FA_FIRE..' Burn', draw=drawBurnTab, color=ORANGE},
    {label=icons.FA_BICYCLE..' Pull', draw=drawPullTab, color=GREEN},
    {label=icons.FA_BATTERY_QUARTER..' Rest', draw=drawRestTab, color=RED},
    {label=icons.FA_PICTURE_O..' Display', draw=drawDisplayTab, color=GREY},
    {label=icons.FA_CODE..' Debug', draw=drawDebugTab, color=YELLOW},
    -- {label='Custom', draw=function() customAbilities:render(class) end, color=LIGHT_BLUE},
}
local function drawBody()
    if ImGui.BeginTabBar('##tabbar', ImGuiTabBarFlags.None) then
        for _,tab in ipairs(uiTabs) do
            if tab.color then ImGui.PushStyleColor(ImGuiCol.Text, tab.color) end
            if ImGui.BeginTabItem(tab.label) then
                if tab.color then ImGui.PopStyleColor() end
                if ImGui.BeginChild(tab.label, -1, -1, 0, ImGuiWindowFlags.HorizontalScrollbar) then
                    tab.draw()
                end
                ImGui.EndChild()
                ImGui.EndTabItem()
            elseif tab.color then
                ImGui.PopStyleColor()
            end
        end
        ImGui.EndTabBar()
    end
end

local fullSize = nil
local function drawHeader()
    if ImGui.Button(icons.MD_FULLSCREEN_EXIT) then
        minimize = true
        fullSize = ImGui.GetWindowSizeVec()
    end
    ImGui.SameLine()
    local x, y = ImGui.GetContentRegionAvail()
    local buttonWidth = (x / 2) - 37--22
    if state.paused then
        if ImGui.Button(icons.FA_PLAY, buttonWidth, BUTTON_HEIGHT) then
            camp.setCamp()
            state.resetCombatState()
            state.paused = false
        end
    else
        if ImGui.Button(icons.FA_PAUSE, buttonWidth, BUTTON_HEIGHT) then
            state.paused = true
            state.resetCombatState()
            mq.cmd('/stopcast')
        end
    end
    widgets.HelpMarker('Pause/Resume')
    ImGui.SameLine()
    if ImGui.Button(icons.MD_SAVE, buttonWidth, BUTTON_HEIGHT) then
        class:saveSettings()
    end
    widgets.HelpMarker('Save Settings')
    ImGui.SameLine()
    if ImGui.Button(icons.MD_HELP, 26, BUTTON_HEIGHT) then
        helpGUIOpen = true
    end
    widgets.HelpMarker('Help')
    ImGui.SameLine()
    local oldLocked = config.get('LOCKED')
    config.LOCKED.value = widgets.LockButton('aqolocked', config.get('LOCKED'))
    if not oldLocked and config.get('LOCKED') then
        -- lock window
        local windowPos = ImGui.GetWindowPosVec()
        local windowSize = ImGui.GetWindowSizeVec()
        config.set('WINDOWPOSX', windowPos.x)
        config.set('WINDOWPOSY', windowPos.y)
        config.set('WINDOWWIDTH', windowSize.x)
        config.set('WINDOWHEIGHT', windowSize.y)
    end
    ImGui.Text('Bot Status: ')
    ImGui.SameLine()
    ImGui.SetCursorPosX(buttonWidth+42)
    local status = 'Running'
    local statusColor = GREEN
    if state.paused then
        status = 'Paused'
        statusColor = RED
    elseif (state.assistMobID or 0) > 0 then
        status = 'Assisting'
    elseif (state.tankMobID or 0) > 0 then
        status = 'Tanking'
    elseif (state.pullMobID or 0) > 0 then
        status = 'Pulling'
    elseif state.medding then
        status = 'Medding'
    elseif state.groupWatchWaiting then
        status = 'GroupWatchWaiting'
    end
    ImGui.TextColored(statusColor, status)
    local current_mode = config.get('MODE')
    ImGui.PushItemWidth(item_width)
    mid_x = buttonWidth+42
    config.MODE.value = widgets.ComboBoxLeftText('Mode', 'Mode', config.get('MODE'), mode.mode_names, false, config.MODE.tip, item_width, nil, nil, mid_x)
    mode.currentMode = mode.fromString(config.get('MODE'))
    mid_x = 140
    ImGui.PopItemWidth()
    if current_mode ~= config.get('MODE') and not state.paused then
        camp.setCamp()
    end
end

local function pushStyle(theme)
    local t = constants.uiThemes[theme]
    t.windowbg.w = 1*(config.OPACITY.value/100)
    t.bg.w = 1*(config.OPACITY.value/100)
    ImGui.PushStyleColor(ImGuiCol.WindowBg, t.windowbg)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, t.bg)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, t.active)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, t.bg)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, t.hovered)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive, t.active)
    ImGui.PushStyleColor(ImGuiCol.Button, t.button)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, t.hovered)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, t.active)
    ImGui.PushStyleColor(ImGuiCol.PopupBg, t.bg)
    ImGui.PushStyleColor(ImGuiCol.Tab, 0, 0, 0, 0)
    ImGui.PushStyleColor(ImGuiCol.TabActive, t.active)
    ImGui.PushStyleColor(ImGuiCol.TabHovered, t.hovered)
    ImGui.PushStyleColor(ImGuiCol.TabUnfocused, t.bg)
    ImGui.PushStyleColor(ImGuiCol.TabUnfocusedActive, t.hovered)
    ImGui.PushStyleColor(ImGuiCol.TextDisabled, t.text)
    ImGui.PushStyleColor(ImGuiCol.CheckMark, t.text)
    ImGui.PushStyleColor(ImGuiCol.Separator, t.hovered)

    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 10)
end

local function popStyles()
    ImGui.PopStyleColor(18)

    ImGui.PopStyleVar(1)
end

local TABLE_FLAGS = bit32.bor(ImGuiTableFlags.ScrollY,ImGuiTableFlags.RowBg,ImGuiTableFlags.BordersOuter,ImGuiTableFlags.BordersV,ImGuiTableFlags.SizingStretchSame,ImGuiTableFlags.Sortable,
                                ImGuiTableFlags.Hideable, ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable)

local debugFilter = ''

local function drawNestedTableTree(table)
    for k, v in pairs(table) do
        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        if type(v) == 'table' then
            local open = ImGui.TreeNodeEx(tostring(k), ImGuiTreeNodeFlags.SpanFullWidth)
            if open then
                drawNestedTableTree(v)
                ImGui.TreePop()
            end
        else
            ImGui.TextColored(YELLOW, '%s', k)
            ImGui.TableNextColumn()
            ImGui.TextColored(RED, '%s', v)
            ImGui.TableNextColumn()
        end
    end
end

local function matchFilters(k, filters)
    for filter,_ in pairs(filters) do
        if k:lower():find(filter) then return true end
    end
end

local function drawTableTree(table, filter)
    local filters = nil
    if filter then
        filters = helpers.splitSet(filter:lower(), '|')
    end
    if ImGui.BeginTable('StateTable', 2, TABLE_FLAGS, -1, -1) then
        ImGui.TableSetupScrollFreeze(0, 1)
        ImGui.TableSetupColumn('Key', ImGuiTableColumnFlags.None, 2, 1)
        ImGui.TableSetupColumn('Value', ImGuiTableColumnFlags.None, 2, 2)
        ImGui.TableHeadersRow()
        for k, v in pairs(table) do
            if not filters or matchFilters(k, filters) then
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                if type(v) == 'table' then
                    local open = ImGui.TreeNodeEx(k, ImGuiTreeNodeFlags.SpanFullWidth)
                    if open then
                        drawNestedTableTree(v)
                        ImGui.TreePop()
                    end
                elseif type(v) ~= 'function' then
                    ImGui.TextColored(YELLOW, '%s', k)
                    ImGui.TableNextColumn()
                    ImGui.TextColored(RED, '%s', v)
                    ImGui.TableNextColumn()
                end
            end
        end
        ImGui.EndTable()
    end
end

local selected_left = nil
local selected_right = nil
local function drawSpellRotationUI()
    if spellRotationUIOpen then
        spellRotationUIOpen, shouldDrawSpellRotationUI = ImGui.Begin(('DPS Spell Rotation Customizer##AQOBOTUI%s'):format(state.class), spellRotationUIOpen)
        if shouldDrawSpellRotationUI then
            ImGui.Text('Custom Rotation')
            ImGui.SameLine()
            ImGui.SetCursorPosX(280)
            ImGui.Text('Available Spells')
            if not class.customRotation then class.customRotation = {} end
            if ImGui.BeginListBox('##AssignedSpells', ImVec2(200,-1)) then
                for i,spell in ipairs(class.customRotation) do
                    if ImGui.Selectable(('%s: %s'):format(i, spell.Name), selected_left == i) then
                        selected_left = i
                    end
                    if ImGui.IsMouseDown(0) and ImGui.IsItemHovered() then
                        if ImGui.BeginDragDropSource() then
                            ImGui.SetDragDropPayload("Spell", i)
                            ImGui.Button(class.customRotation[i].Name)
                            ImGui.EndDragDropSource()
                        end
                    end
                    if ImGui.BeginDragDropTarget() then
                        local payload = ImGui.AcceptDragDropPayload("Spell")
                        if payload ~= nil then
                            local j = payload.Data;
                            -- swap the keys in the button set
                            class.customRotation[i], class.customRotation[j] = class.customRotation[j], class.customRotation[i]
                        end
                        ImGui.EndDragDropTarget()
                    end
                end
                ImGui.EndListBox()
            end
            ImGui.SameLine()
            if ImGui.Button(icons.FA_ARROW_LEFT) and selected_right then table.insert(class.customRotation, class.spells[selected_right]) end
            ImGui.SameLine()
            if ImGui.Button(icons.FA_ARROW_RIGHT) and selected_left then table.remove(class.customRotation, selected_left) end
            ImGui.SameLine()
            if ImGui.BeginListBox('##AllSpells', ImVec2(200,-1)) then
                for _,spellGroup in pairs(class.allDPSSpellGroups) do
                    local spell = class.spells[spellGroup]
                    if spell and ImGui.Selectable(spell.Name, selected_right == spellGroup) then
                        selected_right = spellGroup
                    end
                end
                ImGui.EndListBox()
            end
        end
        ImGui.End()
    end
end

local function drawBuffLists()
    if buffGUIOpen then
        buffGUIOpen, showBuffGUI = ImGui.Begin(('Buffs##AQOBOTUI%s'):format(state.class), buffGUIOpen, ImGuiWindowFlags.None)
        if showBuffGUI then
            if ImGui.CollapsingHeader('Want Buffs') then
                ImGui.Indent(30)
                for _,category in ipairs(constants.buffcategories) do
                    if ImGui.CollapsingHeader(category..'##want') then
                        for _,buff in ipairs(constants.bufflines) do
                            if buff.category == category then
                                class.desiredBuffs[buff.key] = ImGui.Checkbox(buff.label..' ['..buff.key..']'..'##desired', class.desiredBuffs[buff.key] or false)
                                if buff.exclusivewith then
                                    ImGui.Indent(30)
                                    ImGui.Text('Does not stack with: %s', buff.exclusivewith)
                                    ImGui.Unindent(30)
                                end
                            end
                        end
                    end
                end
                ImGui.Unindent(30)
            end
            if ImGui.CollapsingHeader('Offer Buffs') then
                ImGui.Indent(30)
                for _,category in ipairs(constants.buffcategories) do
                    if ImGui.CollapsingHeader(category..'##offer') then
                        for _,buff in ipairs(constants.bufflines) do
                            if buff.category == category then
                                if class.requestAliases[buff.key] then
                                    class.availableBuffs[buff.key] = ImGui.Checkbox(buff.label..' ['..buff.key..']'..'##available', class.availableBuffs[buff.key] or false)
                                end
                            end
                        end
                    end
                end
                ImGui.Unindent(30)
            end
        end
        ImGui.End()
    end
end

local function drawSpellSetTree(name, spells)
    if ImGui.TreeNode(name..'##spellset') then
        for _,spell in ipairs(spells) do
            ImGui.Text(spell.Name)
        end
        ImGui.TreePop()
    end
end

local function drawAbilityInspector()
    if abilityGUIOpen then
        abilityGUIOpen, shouldDrawAbilityGUI = ImGui.Begin(('Ability Inspector##AQOBOTUI%s'):format(state.class), abilityGUIOpen, ImGuiWindowFlags.AlwaysAutoResize)
        if shouldDrawAbilityGUI then
            if ImGui.TreeNode('Class Order') then
                for _,routine in ipairs(class.classOrder) do
                    ImGui.Text(routine)
                end
                ImGui.TreePop()
            end
            if #class.debuffs > 0 and ImGui.TreeNode('Debuff Order') then
                if ImGui.BeginListBox('##debufforder', ImVec2(160,150)) then
                    for i,debuffType in ipairs(class.debuffOrder) do
                        if ImGui.Selectable(('%s: %s'):format(i, debuffType), selected_left == i) then
                            selected_left = i
                        end
                        if ImGui.IsMouseDown(0) and ImGui.IsItemHovered() then
                            if ImGui.BeginDragDropSource() then
                                ImGui.SetDragDropPayload("DebuffType", i)
                                ImGui.Button(debuffType)
                                ImGui.EndDragDropSource()
                            end
                        end
                        if ImGui.BeginDragDropTarget() then
                            local payload = ImGui.AcceptDragDropPayload("DebuffType")
                            if payload ~= nil then
                                local j = payload.Data;
                                -- swap the keys in the button set
                                class.debuffOrder[i], class.debuffOrder[j] = class.debuffOrder[j], class.debuffOrder[i]
                            end
                            ImGui.EndDragDropTarget()
                        end
                    end
                    ImGui.EndListBox()
                end
                ImGui.TreePop()
            end
            if mq.TLO.Me.Class.CanCast() then
                if ImGui.TreeNode('Spells') then
                    for alias,spell in pairs(class.spells) do
                        if ImGui.TreeNode(alias..'##spellalias') then
                            ImGui.Text('Name: %s', spell.Name)
                            for opt,value in pairs(spell) do
                                if opt ~= 'Name' and (type(value) == 'number' or type(value) == 'string' or type(value) == 'boolean') then
                                    ImGui.Text('%s: %s', opt, value)
                                end
                            end
                            ImGui.TreePop()
                        end
                    end
                    ImGui.TreePop()
                end
                if ImGui.TreeNode('DPS Spell Rotations') then
                    for spellSetName,spellSet in pairs(class.spellRotations) do
                        if spellSetName ~= 'custom' then
                            drawSpellSetTree(spellSetName, spellSet)
                        end
                    end
                    if class.BYOSRotation and #class.BYOSRotation > 0 then
                        drawSpellSetTree('BYOS', class.BYOSRotation)
                    end
                    if class.customRotation and #class.customRotation > 0 then
                        drawSpellSetTree('BYOSCustom', class.customRotation)
                    end
                    ImGui.TreePop()
                end
            end
            if ImGui.TreeNode('Class Lists') then
                for i, list in ipairs(constants.classLists) do
                    if #class[list] > 0 then
                        if ImGui.TreeNode(list..'##lists'..i) then
                            for j,ability in ipairs(class[list]) do
                                if ImGui.TreeNode(ability.Name..'##list'..list..i..j) then
                                    for opt,value in pairs(ability) do
                                        if opt ~= 'Name' and (type(value) == 'number' or type(value) == 'string' or type(value) == 'boolean') then
                                            local color = WHITE
                                            if opt == 'opt' then if class:isEnabled(value) then color = GREEN else color = RED end end
                                            ImGui.TextColored(color, '%s: %s', opt, value)
                                        end
                                    end
                                    ImGui.TreePop()
                                end
                            end
                            ImGui.TreePop()
                        end
                    elseif list == 'clickies' then
                        if ImGui.TreeNode(list..'##lists'..i) then
                            for clickyName,clicky in pairs(class.clickies) do
                                ImGui.Text('%s (%s)', clickyName, clicky.clickyType)
                            end
                            ImGui.TreePop()
                        end
                    elseif list == 'requestAliases' then
                        if ImGui.TreeNode(list..'##aliases'..i) then
                            for alias,name in pairs(class.requestAliases) do
                                ImGui.Text('%s: %s', alias, name)
                            end
                            ImGui.TreePop()
                        end
                    end
                end
                -- if class.rezAbility then
                --     if ImGui.TreeNode('rezAbility') then
                --         for opt,value in pairs(class.rezAbility) do
                --             if (type(value) == 'number' or type(value) == 'string' or type(value) == 'boolean') then  -- opt ~= 'Name' and 
                --                 local color = WHITE
                --                 if opt == 'opt' then if class:isEnabled(value) then color = GREEN else color = RED end end
                --                 ImGui.TextColored(color, '%s: %s', opt, value)
                --             end
                --         end
                --         ImGui.TreePop()
                --     end
                -- end
                ImGui.TreePop()
            end
        end
        ImGui.End()
    end
end

local function drawStateInspector()
    if stateGUIOpen then
        stateGUIOpen, shouldDrawStateGUI = ImGui.Begin(('State Inspector##AQOBOTUI%s'):format(state.class), stateGUIOpen)
        if shouldDrawStateGUI then
            debugFilter = ImGui.InputTextWithHint('##debugfilter', 'Filter...', debugFilter)
            drawTableTree(state, debugFilter ~= '' and debugFilter)
        end
        ImGui.End()
    end
end

local sortedClickies = {}

local ColumnID_Type = 2
local ColumnID_Name = 3

local current_sort_specs = nil
local function CompareWithSortSpecs(a, b)
    for n = 1, current_sort_specs.SpecsCount, 1 do
        local clickyA = class.clickies[a]
        local clickyB = class.clickies[b]
        -- Here we identify columns using the ColumnUserID value that we ourselves passed to TableSetupColumn()
        -- We could also choose to identify columns based on their index (sort_spec.ColumnIndex), which is simpler!
        local sort_spec = current_sort_specs:Specs(n)
        local delta = 0

        if sort_spec.ColumnUserID == ColumnID_Name then
            if a < b then
                delta = -1
            elseif b < a then
                delta = 1
            else
                delta = 0
            end
        elseif sort_spec.ColumnUserID == ColumnID_Type then
            if (clickyA and clickyA.clickyType or '') < (clickyB and clickyB.clickyType or '') then
                delta = -1
            elseif (clickyB and clickyB.clickyType or '') < (clickyA and clickyA.clickyType or '') then
                delta = 1
            else
                delta = 0
            end
        end
        if delta ~= 0 then
            if sort_spec.SortDirection == ImGuiSortDirection.Ascending then
                return delta < 0
            end
            return delta > 0
        end
    end

    -- Always return a way to differentiate items.
    -- Your own compare function may want to avoid fallback on implicit sort specs e.g. a Name compare if it wasn't already part of the sort specs.
    return a < b
end

local function drawClickyManager()
    if clickyManagerOpen then
        clickyManagerOpen, shouldDrawClickyManager = ImGui.Begin(('AQO Clickies##AQOBOTUI%s'):format(state.class), clickyManagerOpen)
        if shouldDrawClickyManager then
            if ImGui.BeginTable('clickies', 5, ImGuiTableFlags.Sortable) then
                ImGui.TableSetupColumn('Enabled', ImGuiTableColumnFlags.NoSort, 1, 1)
                ImGui.TableSetupColumn('Type', ImGuiTableColumnFlags.DefaultSort, 1, ColumnID_Type)
                ImGui.TableSetupColumn('Name', ImGuiTableColumnFlags.DefaultSort, 3, ColumnID_Name)
                ImGui.TableSetupColumn('Effect', ImGuiTableColumnFlags.NoSort, 3, 4)
                ImGui.TableSetupColumn('Options', ImGuiTableColumnFlags.NoSort, 3, 5)
                ImGui.TableHeadersRow()

                local sort_specs = ImGui.TableGetSortSpecs()
                if sort_specs then
                    if sort_specs.SpecsDirty or #sortedClickies == 0 then
                        sortedClickies = {}
                        for k,_ in pairs(class.clickies) do table.insert(sortedClickies, k) end
                        current_sort_specs = sort_specs
                        table.sort(sortedClickies, CompareWithSortSpecs)
                        current_sort_specs = nil
                        sort_specs.SpecsDirty = false
                    end
                end

                for _,clickyName in pairs(sortedClickies) do
                    local clicky = class.clickies[clickyName]
                    if clicky then
                        ImGui.TableNextRow()
                        ImGui.TableNextColumn()
                        local tempEnabled = ImGui.Checkbox('##isEnabled'..clickyName, clicky.enabled)
                        if tempEnabled ~= clicky.enabled then
                            if not tempEnabled then class:disableClicky(clickyName)
                            else class:enableClicky(clickyName) end
                        end
                        ImGui.TableNextColumn()
                        ImGui.Text(clicky.clickyType)
                        ImGui.TableNextColumn()
                        ImGui.Text(clickyName)
                        ImGui.TableNextColumn()
                        ImGui.Text('%s', mq.TLO.FindItem(clickyName).Clicky() or mq.TLO.FindItemBank(clickyName).Clicky())
                        ImGui.TableNextColumn()
                        local opts = ''
                        if clicky.opt then opts = opts .. 'Opt: ' .. clicky.opt end
                        if clicky.condition then opts = opts .. ' Condition: ' .. clicky.condition end
                        ImGui.Text('%s', opts)
                    end
                end
                ImGui.EndTable()
            end
        end
        ImGui.End()
    end
end

local gettingStartedOpen, shouldDrawGettingStarted = true, true
local function drawGettingStarted()
    if state.ShowGettingStarted then
        ImGui.SetNextWindowSize(850, 320, ImGuiCond.Appearing)
        local windowSize = ImGui.GetIO().DisplaySize
        ImGui.SetNextWindowPos(windowSize.x/2 - 425, windowSize.y/2 - 160)
        gettingStartedOpen, shouldDrawGettingStarted = ImGui.Begin(('AQO Getting Started##AQOBOTUI%s'):format(state.class), gettingStartedOpen, bit32.bor(ImGuiWindowFlags.NoResize, ImGuiWindowFlags.NoMove))
        if shouldDrawGettingStarted then
            ImGui.Text('1. AQO commands can be run using either "/aqo" or "/${Me.Class.ShortName}" (e.g. /shd useaoe on).')
            ImGui.Text('2. Pause and unpause your group with "/cwtna pause on" and "/cwtna pause off".')
            ImGui.Text('3. You can create aliases to broadcast commands similar to CWTN plugins:\n\t/noparse /alias /cwtn /dgge /aqo\n\t/noparse /alias /cwtna /dgga /aqo\n\t/noparse /alias /cwtnr /dgre /aqo\n\t/noparse /alias /cwtnra /dgra /aqo')
            ImGui.Text('4. By default, AQO depends on group main tank and group main assist role assignments.')
            ImGui.Text('5. Group Main Assist does not function in raids, so you can set assist to "manual" with "/cwtn assist manual"\n\tand set who to assist with "/cwtn assistnames ${Me.CleanName}".')
            ImGui.Text('6. Group Main Tank does not function in raids, so you can configure to use tank abilities while in manual mode with "/aqo maintank on".')
            ImGui.Text('7. AQO supports several modes for characters. Most common will be manual, assist and chase modes.\n\tSet modes with "/aqo mode manual" (set driver to manual) or "/cwtn mode chase" (set group to chase).')
            ImGui.Text('8. For chase mode, set a chase target with "/cwtn chasetarget ${Me.CleanName}".')
            ImGui.Text('9. For anything else, use "/aqo" or the "?" button on the UI for more info.')
        end
        ImGui.End()
        if not gettingStartedOpen then
            state.ShowGettingStarted = false
        end
    end
end

local helpSelected = 'Commands'
local function drawHelpWindow()
    if helpGUIOpen then
        ImGui.SetNextWindowSize(1240, 400)
        helpGUIOpen, shouldDrawHelpGUI = ImGui.Begin(('AQO Help##AQOBOTUI%s'):format(state.class), helpGUIOpen, ImGuiWindowFlags.NoResize)
        if shouldDrawHelpGUI then
            if ImGui.BeginListBox('##Category', ImVec2(130, -1)) then
                if ImGui.Selectable('Commands', helpSelected == 'Commands') then
                    helpSelected = 'Commands'
                end
                if ImGui.Selectable('Class', helpSelected == 'Class') then
                    helpSelected = 'Class'
                end
                for _,category in ipairs(config.categories()) do
                    if ImGui.Selectable(category, helpSelected == category) then
                        helpSelected = category
                    end
                end
                ImGui.EndListBox()
            end
            ImGui.SameLine()
            if helpSelected == 'Commands' then
                if ImGui.BeginTable('commands', 3, bit32.bor(ImGuiTableFlags.RowBg, ImGuiTableFlags.Borders, ImGuiTableFlags.ScrollY)) then
                    ImGui.TableSetupColumn('Command', ImGuiTableColumnFlags.WidthFixed, 250)
                    ImGui.TableSetupColumn('Description', ImGuiTableColumnFlags.WidthFixed, 450)
                    ImGui.TableSetupColumn('Example', ImGuiTableColumnFlags.WidthFixed, 250)
                    ImGui.TableSetupScrollFreeze(0,1)
                    ImGui.TableHeadersRow()

                    for _,command in ipairs(constants.commandHelp) do
                        ImGui.TableNextRow()
                        ImGui.TableNextColumn()
                        ImGui.Text(command.command)
                        ImGui.TableNextColumn()
                        ImGui.PushTextWrapPos(0)
                        ImGui.Text(command.tip)
                        ImGui.PopTextWrapPos()
                        ImGui.TableNextColumn()
                        if command.example then ImGui.Text(command.example) else ImGui.Text('/aqo %s', command.command) end
                    end
                    ImGui.EndTable()
                end
            else
                if ImGui.BeginTable('settings', 5, bit32.bor(ImGuiTableFlags.RowBg, ImGuiTableFlags.Borders, ImGuiTableFlags.ScrollY)) then
                    ImGui.TableSetupColumn('Setting/Command', ImGuiTableColumnFlags.WidthFixed, 145)
                    ImGui.TableSetupColumn('TLO Member', ImGuiTableColumnFlags.WidthFixed, 130)
                    ImGui.TableSetupColumn('DataType', ImGuiTableColumnFlags.WidthFixed, 70)
                    ImGui.TableSetupColumn('Description', ImGuiTableColumnFlags.WidthFixed, 450)
                    ImGui.TableSetupColumn('Example', ImGuiTableColumnFlags.WidthFixed, 250)
                    ImGui.TableSetupScrollFreeze(0,1)
                    ImGui.TableHeadersRow()

                    if helpSelected == 'Class' then
                        for _,key in ipairs(class.options) do
                            local value = class.options[key]
                            local valueType = type(value.value)
                            if valueType == 'string' or valueType == 'number' or valueType == 'boolean' then
                                ImGui.TableNextRow()
                                ImGui.TableNextColumn()
                                ImGui.Text(key)
                                ImGui.TableNextColumn()
                                ImGui.Text('%s', value.tlo)
                                ImGui.TableNextColumn()
                                ImGui.Text('%s', value.tlotype)
                                ImGui.TableNextColumn()
                                ImGui.PushTextWrapPos(0)
                                ImGui.Text('%s', value.tip)
                                ImGui.PopTextWrapPos()
                                ImGui.TableNextColumn()
                                ImGui.Text('/aqo %s <%s>', key, valueType)
                            end
                        end
                    else
                        local categoryConfigs = config.getByCategory(helpSelected)
                        for _,key in ipairs(categoryConfigs) do
                            local cfg = config[key]
                            if cfg and type(cfg) == 'table' then
                                ImGui.TableNextRow()
                                ImGui.TableNextColumn()
                                ImGui.Text(key)
                                ImGui.TableNextColumn()
                                ImGui.Text('%s', cfg.tlo)
                                ImGui.TableNextColumn()
                                ImGui.Text('%s', cfg.tlotype)
                                ImGui.TableNextColumn()
                                ImGui.PushTextWrapPos(0)
                                ImGui.Text('%s', cfg.tip)
                                ImGui.PopTextWrapPos()
                                ImGui.TableNextColumn()
                                ImGui.Text('/aqo %s <%s>', key, type(cfg.value))
                            end
                        end
                    end
                    ImGui.EndTable()
                end
            end
        end
        ImGui.End()
    end
end

-- ImGui main function for rendering the UI window
function ui.main()
    if not openGUI then return end
    pushStyle(config.THEME.value)
    local flags = ImGuiWindowFlags.NoTitleBar
    if config.get('LOCKED') then
        flags = bit32.bor(flags, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoResize)
    end
    local posX, posY = config.get('WINDOWPOSX'), config.get('WINDOWPOSY')
    -- local width, height = config.get('WINDOWWIDTH'), config.get('WINDOWHEIGHT')
    if posX and posY then ImGui.SetNextWindowPos(ImVec2(posX, posY), ImGuiCond.Once) end
    -- if width and height then ImGui.SetNextWindowSize(ImVec2(width, height), ImGuiCond.Once) end
    if minimize then ImGui.SetNextWindowSize(-1,-1) end
    openGUI, shouldDrawGUI = ImGui.Begin(string.format('AQO Bot 1.0 - %s###AQOBOTUI%s', state.class, state.class), openGUI, flags)
    if shouldDrawGUI then
        if not minimize then
            drawHeader()
            drawBody()
            local x, y = ImGui.GetWindowSize()
            if x < MINIMUM_WIDTH then ImGui.SetWindowSize(MINIMUM_WIDTH, y) end
        else
            ImGui.SetWindowSize(-1, -1)
            ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
            ImGui.PushStyleColor(ImGuiCol.Button, 0,0,0,0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0,0,0,0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0,0,0,0)
            if state.paused then
                if ImGui.ImageButton('AQOButton', aqoImg:GetTextureID(), ImVec2(40, 40),ImVec2(0.0, 0.0), ImVec2(0.62, 0.62), ImVec4(0,0,0,0),ImVec4(1,0,0,1)) then
                    minimize = false
                end
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip("AQO is Paused")
                end
            else
                if ImGui.ImageButton('AQOButton', aqoImg:GetTextureID(), ImVec2(40, 40),ImVec2(0.0,0.0), ImVec2(0.62, 0.62)) then
                    minimize = false
                end
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip("AQO is Running")
                end
            end
            ImGui.PopStyleColor(3)
            ImGui.PopStyleVar()
            if not minimize then
                if fullSize then
                    ImGui.SetWindowSize(fullSize.x, fullSize.y)
                else
                    -- ImGui.SetWindowSize(630, 260)
                    ImGui.SetWindowSize(config.get('WINDOWWIDTH'), config.get('WINDOWHEIGHT'))
                end
            end
        end
    end
    ImGui.End()
    drawGettingStarted()
    drawSpellRotationUI()
    drawAbilityInspector()
    drawStateInspector()
    drawClickyManager()
    drawHelpWindow()
    drawBuffLists()
    popStyles()
end

return ui