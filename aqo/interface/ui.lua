--- @type Mq
local mq = require('mq')
--- @type ImGui
require 'ImGui'
local icons = require('mq.icons')

local config = require('interface.configuration')
local widgets = require('libaqo.widgets')
local camp = require('routines.camp')
local helpers = require('utils.helpers')
local logger = require('utils.logger')
local constants = require('constants')
local mode = require('mode')
local state = require('state')

-- UI Control variables
local openGUI, shouldDrawGUI = true, true
local stateGUIOpen, shouldDrawStateGUI = false, false
local spellRotationUIOpen, shouldDrawSpellRotationUI = false, false
local abilityGUIOpen, shouldDrawAbilityGUI = false, false
local clickyManagerOpen, shouldDrawClickyManager = false, false
local helpGUIOpen, shouldDrawHelpGUI= false, false

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

function ui.init(_class)
    class = _class
    mq.imgui.init('AQO Bot 1.0', ui.main)
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
    'ASSIST','AUTOASSISTAT','ASSISTNAMES','SWITCHWITHMA',
    'CAMPRADIUS','CHASETARGET','CHASEDISTANCE','CHASEPAUSED','RESISTSTOPCOUNT',
    'NUKEMANAMIN','DOTMANAMIN','MAINTANK','LOOTMOBS','LOOTCOMBAT',
}
local function drawAssistTab()
    local x,_ = ImGui.GetContentRegionAvail()
    if ImGui.Button('Reset Camp', x, BUTTON_HEIGHT) then
        camp.setCamp(true)
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
    if ImGui.Button('View State Inspector', x, BUTTON_HEIGHT) then
        stateGUIOpen = true
    end
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
        end
    else
        if ImGui.Button('Stop Force Engage') then
            state.forceEngage = nil
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
    -- Reduce spacing so everything fits snugly together
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
    local contentSizeX, contentSizeY = ImGui.GetContentRegionAvail()
    console:Render(ImVec2(contentSizeX, contentSizeY))
    ImGui.PopStyleVar()
end

local function drawDisplayTab()
    config.THEME.value = widgets.ComboBox('Theme', config.THEME.value, constants.uiThemes, true, 'Pick a UI color scheme', item_width)
    config.OPACITY.value = widgets.SliderInt('Opacity', config.OPACITY.value, 'Set the window opacity', 0, 100, item_width)
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

local function drawHeader()
    local x, y = ImGui.GetContentRegionAvail()
    local buttonWidth = (x / 2) - 37--22
    if state.paused then
        if ImGui.Button(icons.FA_PLAY, buttonWidth, BUTTON_HEIGHT) then
            camp.setCamp()
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
    ImGui.SetCursorPosX(buttonWidth+16)
    if state.paused then
        ImGui.TextColored(RED, 'PAUSED')
    else
        ImGui.TextColored(GREEN, 'RUNNING')
    end
    local current_mode = config.get('MODE')
    ImGui.PushItemWidth(item_width)
    mid_x = buttonWidth+15
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

local function drawTableTree(table)
    if ImGui.BeginTable('StateTable', 2, TABLE_FLAGS, -1, -1) then
        ImGui.TableSetupScrollFreeze(0, 1)
        ImGui.TableSetupColumn('Key', ImGuiTableColumnFlags.None, 2, 1)
        ImGui.TableSetupColumn('Value', ImGuiTableColumnFlags.None, 2, 2)
        ImGui.TableHeadersRow()
        for k, v in pairs(table) do
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
                    if ImGui.Selectable(spell.Name, selected_right == spellGroup) then
                        selected_right = spellGroup
                    end
                end
                ImGui.EndListBox()
            end
        end
        ImGui.End()
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
                            if ImGui.TreeNode(spellSetName..'##spellset') then
                                for _,spell in ipairs(spellSet) do
                                    ImGui.Text(spell.Name)
                                end
                                ImGui.TreePop()
                            end
                        end
                    end
                    if class.BYOSRotation and #class.BYOSRotation > 0 then
                        if ImGui.TreeNode('BYOS##spellset') then
                            for _,spell in ipairs(class.BYOSRotation) do
                                ImGui.Text(spell.Name)
                            end
                            ImGui.TreePop()
                        end
                    end
                    if class.customRotation and #class.customRotation > 0 then
                        if ImGui.TreeNode('BYOSCustom##spellset') then
                            for _,spell in ipairs(class.customRotation) do
                                ImGui.Text(spell.Name)
                            end
                            ImGui.TreePop()
                        end
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
                    end
                end
                if class.rezAbility then
                    if ImGui.TreeNode('rezAbility') then
                        for opt,value in pairs(class.rezAbility) do
                            if (type(value) == 'number' or type(value) == 'string' or type(value) == 'boolean') then  -- opt ~= 'Name' and 
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
        end
        ImGui.End()
    end
end

local function drawStateInspector()
    if stateGUIOpen then
        stateGUIOpen, shouldDrawStateGUI = ImGui.Begin(('State Inspector##AQOBOTUI%s'):format(state.class), stateGUIOpen)
        if shouldDrawStateGUI then
            drawTableTree(state)
        end
        ImGui.End()
    end
end

local function drawClickyManager()
    if clickyManagerOpen then
        clickyManagerOpen, shouldDrawClickyManager = ImGui.Begin(('AQO Clickies##AQOBOTUI%s'):format(state.class), clickyManagerOpen)
        if shouldDrawClickyManager then
            if ImGui.BeginTable('clickies', 3) then
                ImGui.TableSetupColumn('Enabled', ImGuiTableColumnFlags.None, 1)
                ImGui.TableSetupColumn('Type', ImGuiTableColumnFlags.None, 1)
                ImGui.TableSetupColumn('Name', ImGuiTableColumnFlags.None, 3)
                ImGui.TableHeadersRow()
                for clickyName, clicky in pairs(class.clickies) do
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
                end
                ImGui.EndTable()
            end
        end
        ImGui.End()
    end
end

local function drawHelpWindow()
    if helpGUIOpen then
        helpGUIOpen, shouldDrawHelpGUI = ImGui.Begin(('AQO Help##AQOBOTUI%s'):format(state.class), helpGUIOpen, ImGuiWindowFlags.AlwaysAutoResize)
        if shouldDrawHelpGUI then
            ImGui.PushTextWrapPos(750)
            if ImGui.TreeNode('General Commands') then
                for _,command in ipairs(constants.commandHelp) do
                    ImGui.TextColored(YELLOW, '/aqo '..command.command) ImGui.SameLine() ImGui.Text(command.tip)
                end
                ImGui.TextColored(YELLOW, '/nowcast [name] alias <targetID>') ImGui.SameLine() ImGui.Text('Tells the named character or yourself to cast a spell on the specified target ID.')
                ImGui.TreePop()
            end
            for _,category in ipairs(config.categories()) do
                local categoryConfigs = config.getByCategory(category)
                if ImGui.TreeNode(category..' Configuration') then
                    for _,key in ipairs(categoryConfigs) do
                        local cfg = config[key]
                        if type(cfg) == 'table' then
                            ImGui.TextColored(YELLOW, '/aqo %s <%s>', key, type(cfg.value))
                            ImGui.SameLine()
                            ImGui.Text(cfg.tip)
                        end
                    end
                    ImGui.TreePop()
                end
            end
            if ImGui.TreeNode('Class Configuration') then
                for key,value in pairs(class.options) do
                    local valueType = type(value.value)
                    if valueType == 'string' or valueType == 'number' or valueType == 'boolean' then
                        ImGui.TextColored(YELLOW, '/aqo %s <%s>', key, valueType)
                        ImGui.SameLine()
                        ImGui.Text('%s', value.tip)
                    end
                end
                ImGui.TreePop()
            end
            if ImGui.TreeNode('Gear Check (WARNING*: Characters announce their gear to guild chat!') then
                ImGui.TextColored(YELLOW, '/tell <name> gear <slotname>')
                ImGui.TextColored(YELLOW, 'Slot Names')
                ImGui.SameLine()
                ImGui.Text(constants.slotList)
                ImGui.TreePop()
            end
            if ImGui.TreeNode('Buff Begging  (WARNING*: Characters accounce requests to group or raid chat!') then
                ImGui.TextColored(YELLOW, '/tell <name> <alias>')
                ImGui.TextColored(YELLOW, 'Aliases:')
                for alias,_ in pairs(class.requestAliases) do
                    ImGui.Text(alias)
                end
                ImGui.TreePop()
            end
            ImGui.PopTextWrapPos()
        end
        ImGui.End()
    end
end

-- ImGui main function for rendering the UI window
function ui.main()
    if not openGUI then return end
    pushStyle(config.THEME.value)
    local flags = 0
    if config.get('LOCKED') then
        flags = bit32.bor(ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoResize)
    end
    local posX, posY = config.get('WINDOWPOSX'), config.get('WINDOWPOSY')
    local width, height = config.get('WINDOWWIDTH'), config.get('WINDOWHEIGHT')
    if posX and posY then ImGui.SetNextWindowPos(ImVec2(posX, posY), ImGuiCond.Once) end
    if width and height then ImGui.SetNextWindowSize(ImVec2(width, height), ImGuiCond.Once) end
    openGUI, shouldDrawGUI = ImGui.Begin(string.format('AQO Bot 1.0 - %s###AQOBOTUI%s', state.class, state.class), openGUI, flags)
    if shouldDrawGUI then
        drawHeader()
        drawBody()
        local x, y = ImGui.GetWindowSize()
        if x < MINIMUM_WIDTH then ImGui.SetWindowSize(MINIMUM_WIDTH, y) end
    end
    ImGui.End()
    drawSpellRotationUI()
    drawAbilityInspector()
    drawStateInspector()
    drawClickyManager()
    drawHelpWindow()
    popStyles()
end

return ui