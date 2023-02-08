--- @type Mq
local mq = require('mq')
--- @type ImGui
require 'ImGui'

local lists = require('data.lists')
local camp = require('routines.camp')
local logger = require('utils.logger')
local common = require('common')
local config = require('configuration')
local mode = require('mode')
local state = require('state')

-- UI Control variables
local openGUI = true
local shouldDrawGUI = true
local uiTheme = 'TEAL'

local abilityGUIOpen = false
local shouldDrawAbilityGUI = false

local helpGUIOpen = false
local shouldDrawHelpGUI = false

-- UI constants
local MINIMUM_WIDTH = 372
local HALF_BUTTON_WIDTH = 173
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

local aqo
local ui = {}

function ui.init(_aqo)
    aqo = _aqo
    mq.imgui.init('AQO Bot 1.0', ui.main)
end

function ui.toggleGUI(open)
    openGUI = open
end

local function helpMarker(desc)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0)
        ImGui.Text(desc)
        ImGui.PopTextWrapPos()
        ImGui.EndTooltip()
    end
end

function ui.drawComboBox(label, resultvar, options, bykey, xOffset, yOffset)
    if not yOffset and not xOffset then xOffset, yOffset = ImGui.GetCursorPos() end
    ImGui.SetCursorPosX(xOffset)
    ImGui.SetCursorPosY(yOffset+5)
    ImGui.Text(label)
    ImGui.SameLine()
    ImGui.SetCursorPosX(mid_x + xOffset)
    local _,y = ImGui.GetCursorPos()
    ImGui.SetCursorPosY(y-3)
    if ImGui.BeginCombo('##'..label, resultvar) then
        for i,j in pairs(options) do
            if bykey then
                if ImGui.Selectable(i, i == resultvar) then
                    resultvar = i
                end
            else
                if ImGui.Selectable(j, j == resultvar) then
                    resultvar = j
                end
            end
        end
        ImGui.EndCombo()
    end
    return resultvar
end

function ui.drawCheckBox(labelText, idText, resultVar, helpText, xOffset, yOffset)
    if not yOffset and not xOffset then xOffset, yOffset = ImGui.GetCursorPos() end
    ImGui.SetCursorPosX(xOffset)
    ImGui.SetCursorPosY(yOffset+5)
    if resultVar then
        ImGui.TextColored(GREEN, labelText)
    else
        ImGui.TextColored(RED, labelText)
    end
    ImGui.SameLine()
    helpMarker(helpText)
    ImGui.SameLine()
    local x,y = ImGui.GetCursorPos()
    ImGui.SetCursorPosY(y-3)
    ImGui.SetCursorPosX(mid_x + xOffset)
    resultVar,_ = ImGui.Checkbox(idText, resultVar)
    return resultVar
end

function ui.drawInputInt(labelText, idText, resultVar, helpText, xOffset, yOffset)
    if not yOffset and not xOffset then xOffset, yOffset = ImGui.GetCursorPos() end
    ImGui.SetCursorPosX(xOffset)
    ImGui.SetCursorPosY(yOffset+5)
    ImGui.Text(labelText)
    ImGui.SameLine()
    helpMarker(helpText)
    ImGui.SameLine()
    local _,y = ImGui.GetCursorPos()
    ImGui.SetCursorPosY(y-3)
    ImGui.SetCursorPosX(mid_x + xOffset)
    resultVar = ImGui.InputInt(idText, resultVar)
    return resultVar
end

function ui.drawInputText(labelText, idText, resultVar, helpText, xOffset, yOffset)
    if not yOffset and not xOffset then xOffset, yOffset = ImGui.GetCursorPos() end
    ImGui.SetCursorPosX(xOffset)
    ImGui.SetCursorPosY(yOffset+5)
    ImGui.Text(labelText)
    ImGui.SameLine()
    helpMarker(helpText)
    ImGui.SameLine()
    local _,y = ImGui.GetCursorPos()
    ImGui.SetCursorPosY(y-3)
    ImGui.SetCursorPosX(mid_x + xOffset)
    resultVar = ImGui.InputText(idText, resultVar)
    return resultVar
end

function ui.getNextXY(startY, yAvail, xOffset, yOffset, maxY)
    yOffset = yOffset + Y_COLUMN_OFFSET
    if yOffset > maxY then maxY = yOffset end
    if yAvail - yOffset + startY < 25 then
        xOffset = xOffset + X_COLUMN_OFFSET
        yOffset = startY
    end
    return xOffset, yOffset, maxY
end

local function drawAssistTab()
    local x,_ = ImGui.GetContentRegionAvail()
    if ImGui.Button('Reset Camp', x, BUTTON_HEIGHT) then
        camp.setCamp(true)
    end
    config.ASSIST.value = ui.drawComboBox('Assist', config.ASSIST.value, lists.assists, true)
    config.AUTOASSISTAT.value = ui.drawInputInt('Assist %', '##assistat', config.AUTOASSISTAT.value, 'Percent HP to assist at')
    config.ASSISTNAMES.value = ui.drawInputText('Assist Names', '##assistnames', config.ASSISTNAMES.value, 'Command separated, ordered list of names to assist, mainly for manual assist mode in raids.')
    config.SWITCHWITHMA.value = ui.drawCheckBox('Switch With MA', '##switchwithma', config.SWITCHWITHMA.value, 'Switch targets with MA')
    local current_camp_radius = config.CAMPRADIUS.value
    config.CAMPRADIUS.value = ui.drawInputInt('Camp Radius', '##campradius', config.CAMPRADIUS.value, 'Camp radius to assist within')
    config.CHASETARGET.value = ui.drawInputText('Chase Target', '##chasetarget', config.CHASETARGET.value, 'Chase Target')
    config.CHASEDISTANCE.value = ui.drawInputInt('Chase Distance', '##chasedist', config.CHASEDISTANCE.value, 'Distance to follow chase target')
    config.RESISTSTOPCOUNT.value = ui.drawInputInt('Resist Stop Count', '##resiststopcount', config.RESISTSTOPCOUNT.value, 'The number of resists after which to stop trying casting a spell on a mob')
    if state.emu then
        config.MAINTANK.value = ui.drawCheckBox('Main Tank', '##maintank', config.MAINTANK.value, 'Am i main tank')
        config.LOOTMOBS.value = ui.drawCheckBox('Loot Mobs', '##lootmobs', config.LOOTMOBS.value, 'Loot corpses')
        config.AUTODETECTRAID.value = ui.drawCheckBox('Auto-Detect Raid', '##detectraid', config.AUTODETECTRAID.value, 'Set raid assist settings automatically if in a raid')
    end

    if current_camp_radius ~= config.CAMPRADIUS.value then
        camp.setCamp()
    end
    uiTheme = ui.drawComboBox('Theme', uiTheme, lists.uiThemes, true)
end

local function drawSkillsTab()
    local x, y = ImGui.GetCursorPos()
    local xOffset = x
    local yOffset = y
    local maxY = yOffset
    local _, yAvail = ImGui.GetContentRegionAvail()
    for _,key in ipairs(aqo.class.OPTS) do
        if key ~= 'USEGLYPH' and key ~= 'USEINTENSITY' then
            local option = aqo.class.OPTS[key]
            if option.type == 'checkbox' then
                option.value = ui.drawCheckBox(option.label, '##'..key, option.value, option.tip, xOffset, yOffset)
                if option.value and option.exclusive then aqo.class.OPTS[option.exclusive].value = false end
            elseif option.type == 'combobox' then
                option.value = ui.drawComboBox(option.label, option.value, option.options, true, xOffset, yOffset)
            elseif option.type == 'inputint' then
                option.value = ui.drawInputInt(option.label, '##'..key, option.value, option.tip, xOffset, yOffset)
            end
            xOffset, yOffset, maxY = ui.getNextXY(y, yAvail, xOffset, yOffset, maxY)
        end
    end
    local xAvail = ImGui.GetContentRegionAvail()
    x, y = ImGui.GetWindowSize()
    if x < xOffset + X_COLUMN_OFFSET or xAvail > 20 then x = math.max(MINIMUM_WIDTH, xOffset + X_COLUMN_OFFSET) ImGui.SetWindowSize(x, y) end
    if y < maxY or y > maxY+35 then ImGui.SetWindowSize(x, maxY+35) end
end

local function drawHealTab()
    config.HEALPCT.value = ui.drawInputInt('Heal Pct', '##healpct', config.HEALPCT.value, 'Percent HP to begin casting regular heals on self or others')
    if lists.healClasses[state.class] then
        config.PANICHEALPCT.value = ui.drawInputInt('Panic Heal Pct', '##panichealpct', config.PANICHEALPCT.value, 'Percent HP to begin casting panic heals')
        config.GROUPHEALPCT.value = ui.drawInputInt('Group Heal Pct', '##grouphealpct', config.GROUPHEALPCT.value, 'Percent HP to begin casting group heals')
        config.GROUPHEALMIN.value = ui.drawInputInt('Group Heal Min', '##grouphealmin', config.GROUPHEALMIN.value, 'Minimum number of hurt group members to begin casting group heals')
        config.HOTHEALPCT.value = ui.drawInputInt('HoT Pct', '##hothealpct', config.HOTHEALPCT.value, 'Percent HP to begin casting HoTs')
        config.PRIORITYTARGET.value = ui.drawInputText('Priority Target', '##prioritytarget', config.PRIORITYTARGET.value, 'Main focus for heals')
        config.XTARGETHEAL.value = ui.drawCheckBox('Heal XTarget', '##healxtarget', config.XTARGETHEAL.value, 'Toggle healing of PCs on XTarget')
    end
    config.REZGROUP.value = ui.drawCheckBox('Rez Group', '##rezgroup', config.REZGROUP.value, 'Rez Group Members')
    config.REZRAID.value = ui.drawCheckBox('Rez Raid', '##rezraid', config.REZRAID.value, 'Rez Raid Members')
    config.REZINCOMBAT.value = ui.drawCheckBox('Rez In Combat', '##rezincombat', config.REZINCOMBAT.value, 'Rez In Combat')
end

local function drawBurnTab()
    if ImGui.Button('Burn Now', 112, BUTTON_HEIGHT) then
        mq.cmdf('/%s burnnow', state.class)
    end
    ImGui.SameLine()
    if ImGui.Button('Quick Burn', 112, BUTTON_HEIGHT) then
        mq.cmdf('/%s burnnow quick', state.class)
    end
    ImGui.SameLine()
    if ImGui.Button('Long Burn', 112, BUTTON_HEIGHT) then
        mq.cmdf('/%s burnnow long', state.class)
    end
    config.BURNCOUNT.value = ui.drawInputInt('Burn Count', '##burncnt', config.BURNCOUNT.value, 'Trigger burns if this many mobs are on aggro')
    config.BURNPCT.value = ui.drawInputInt('Burn Percent', '##burnpct', config.BURNPCT.value, 'Percent health to begin burns')
    config.BURNALWAYS.value = ui.drawCheckBox('Burn Always', '##burnalways', config.BURNALWAYS.value, 'Always be burning')
    config.BURNALLNAMED.value = ui.drawCheckBox('Burn Named', '##burnnamed', config.BURNALLNAMED.value, 'Burn all named')
    config.USEGLYPH.value = ui.drawCheckBox('Use Glyph', '##glyph', config.USEGLYPH.value, 'Use Glyph of Destruction on Burn')
    config.USEINTENSITY.value = ui.drawCheckBox('Use Intensity', '##intensity', config.USEINTENSITY.value, 'Use Intensity of the Resolute on Burn')
    if aqo.class.drawBurnTab then aqo.class.drawBurnTab() end
end

local function drawPullTab()
    if ImGui.Button('Add Ignore', HALF_BUTTON_WIDTH, BUTTON_HEIGHT) then
        mq.cmdf('/%s ignore', state.class)
    end
    ImGui.SameLine()
    if ImGui.Button('Remove Ignore', HALF_BUTTON_WIDTH, BUTTON_HEIGHT) then
        mq.cmdf('/%s unignore', state.class)
    end
    local x, y = ImGui.GetCursorPos()
    local xOffset = x
    local yOffset = y
    local maxY = yOffset
    local _, yAvail = ImGui.GetContentRegionAvail()
    config.PULLWITH.value = ui.drawComboBox('Pull With', config.PULLWITH.value, lists.pullWith, true, xOffset, yOffset)
    xOffset, yOffset, maxY = ui.getNextXY(y, yAvail, xOffset, yOffset, maxY)
    local current_radius = config.PULLRADIUS.value
    local current_pullarc = config.PULLARC.value
    config.PULLRADIUS.value = ui.drawInputInt('Pull Radius', '##pullrad', config.PULLRADIUS.value, 'Radius to pull mobs within', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.getNextXY(y, yAvail, xOffset, yOffset, maxY)
    config.PULLLOW.value = ui.drawInputInt('Pull ZLow', '##pulllow', config.PULLLOW.value, 'Z Low pull range', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.getNextXY(y, yAvail, xOffset, yOffset, maxY)
    config.PULLHIGH.value = ui.drawInputInt('Pull ZHigh', '##pullhigh', config.PULLHIGH.value, 'Z High pull range', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.getNextXY(y, yAvail, xOffset, yOffset, maxY)
    config.PULLMINLEVEL.value = ui.drawInputInt('Pull Min Level', '##pullminlvl', config.PULLMINLEVEL.value, 'Minimum level mobs to pull', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.getNextXY(y, yAvail, xOffset, yOffset, maxY)
    config.PULLMAXLEVEL.value = ui.drawInputInt('Pull Max Level', '##pullmaxlvl', config.PULLMAXLEVEL.value, 'Maximum level mobs to pull', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.getNextXY(y, yAvail, xOffset, yOffset, maxY)
    config.PULLARC.value = ui.drawInputInt('Pull Arc', '##pullarc', config.PULLARC.value, 'Only pull from this slice of the radius, centered around your current heading', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.getNextXY(y, yAvail, xOffset, yOffset, maxY)
    config.GROUPWATCHWHO.value = ui.drawComboBox('Group Watch', config.GROUPWATCHWHO.value, lists.groupWatchOptions, true, xOffset, yOffset)
    if current_radius ~= config.PULLRADIUS.value or current_pullarc ~= config.PULLARC.value then
        camp.setCamp()
    end
    local xAvail, yAvail = ImGui.GetContentRegionAvail()
    local x, y = ImGui.GetWindowSize()
    if x < xOffset + X_COLUMN_OFFSET or xAvail > 20 then x = math.max(MINIMUM_WIDTH, xOffset + X_COLUMN_OFFSET) ImGui.SetWindowSize(x, y) end
    if y < maxY or y > maxY+35 then ImGui.SetWindowSize(x, maxY+35) end
end

local function drawRestTab()
    config.MEDCOMBAT.value = ui.drawCheckBox('Med In Combat', '##medcombat', config.MEDCOMBAT.value, 'Toggle medding during combat')
    config.RECOVERPCT.value = ui.drawInputInt('Recover Pct', '##recoverpct', config.RECOVERPCT.value, 'Percent Mana or End to use class recover abilities')
    config.MEDMANASTART.value = ui.drawInputInt('Med Mana Start', '##medmanastart', config.MEDMANASTART.value, 'Pct Mana to begin medding')
    config.MEDMANASTOP.value = ui.drawInputInt('Med Mana Stop', '##medmanastop', config.MEDMANASTOP.value, 'Pct Mana to stop medding')
    config.MEDENDSTART.value = ui.drawInputInt('Med End Start', '##medendstart', config.MEDENDSTART.value, 'Pct End to begin medding')
    config.MEDENDSTOP.value = ui.drawInputInt('Med End Stop', '##medendstop', config.MEDENDSTOP.value, 'Pct End to stop medding')
    if state.emu then
        config.MANASTONESTART.value = ui.drawInputInt('Manastone Start', '##manastonestart', config.MANASTONESTART.value, 'Pct Mana to start using manastone')
        config.MANASTONESTARTHP.value = ui.drawInputInt('Manastone Start HP', '##manastonestarthp', config.MANASTONESTARTHP.value, 'Only begin manastone if Pct HP above this pct')
        config.MANASTONESTOPHP.value = ui.drawInputInt('Manastone Stop HP', '##manastonestophp', config.MANASTONESTOPHP.value, 'Stop manastone once Pct HP reaches this pct')
        config.MANASTONETIME.value = ui.drawInputInt('Manastone Duration', '##manastonetime', config.MANASTONETIME.value, 'Use manastone for up to this number of seconds')
    end
end

local function drawDebugComboBox()
    ImGui.PushItemWidth(300)
    if ImGui.BeginCombo('##debugoptions', 'debug options') then
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
    local buttonWidth = (x / 2)
    if ImGui.Button('Restart AQO', buttonWidth, BUTTON_HEIGHT) then
        mq.cmd('/multiline ; /lua stop aqo ; /timed 10 /lua run aqo')
    end
    ImGui.SameLine()
    if ImGui.Button('Update AQO', buttonWidth, BUTTON_HEIGHT) then
        os.execute('start https://github.com/aquietone/aqobot/archive/refs/heads/emu.zip')
    end
    if ImGui.Button('View Ability Lists', x, BUTTON_HEIGHT) then
        abilityGUIOpen = true
    end
    config.TIMESTAMPS.value = ui.drawCheckBox('Timestamps', '##timestamps', config.TIMESTAMPS.value, 'Toggle timestamps on log messages')
    logger.timestamps = config.TIMESTAMPS.value
    drawDebugComboBox()
    ImGui.TextColored(YELLOW, 'Mode:')
    ImGui.SameLine()
    ImGui.SetCursorPosX(150)
    ImGui.TextColored(WHITE, config.MODE.value:getName())

    ImGui.TextColored(YELLOW, 'Camp:')
    ImGui.SameLine()
    ImGui.SetCursorPosX(150)
    if camp.Active then
        ImGui.TextColored(YELLOW, string.format('X: %.02f  Y: %.02f  Z: %.02f', camp.X, camp.Y, camp.Z))
        ImGui.TextColored(YELLOW, 'Radius:')
        ImGui.SameLine()
        ImGui.SetCursorPosX(150)    
        ImGui.TextColored(YELLOW, string.format('%d', config.CAMPRADIUS.value))
        ImGui.TextColored(YELLOW, 'Distance from camp:')
        ImGui.SameLine()
        ImGui.SetCursorPosX(150)
        ImGui.TextColored(YELLOW, string.format('%d', common.checkDistance(mq.TLO.Me.X(), mq.TLO.Me.Y(), camp.X, camp.Y)))
    else
        ImGui.TextColored(RED, '--')
    end

    for k,v in pairs(state) do
        if type(v) ~= 'table' and type(v) ~= 'function' then
            ImGui.TextColored(YELLOW, ('%s:'):format(k))
            ImGui.SameLine()
            ImGui.SetCursorPosX(150)
            ImGui.TextColored(RED, ('%s'):format(v))
        end
    end
end

local function drawBody()
    if ImGui.BeginTabBar('##tabbar') then
        if ImGui.BeginTabItem('General') then
            if ImGui.BeginChild('General', -1, -1, false, ImGuiWindowFlags.HorizontalScrollbar) then
                ImGui.PushItemWidth(item_width)
                drawAssistTab()
                ImGui.PopItemWidth()
                ImGui.EndTabItem()
            end
            ImGui.EndChild()
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem('Skills') then
            if ImGui.BeginChild('Skills', -1, -1, false, ImGuiWindowFlags.HorizontalScrollbar) then
                ImGui.PushItemWidth(item_width)
                drawSkillsTab()
                ImGui.PopItemWidth()
            end
            ImGui.EndChild()
            ImGui.EndTabItem()
        end
        ImGui.PushStyleColor(ImGuiCol.Text, LIGHT_BLUE)
        if ImGui.BeginTabItem(lists.icons.FA_HEART..' Heal') then
            ImGui.PopStyleColor()
            if ImGui.BeginChild('Heal', -1, -1, false, ImGuiWindowFlags.HorizontalScrollbar) then
                ImGui.PushItemWidth(item_width)
                drawHealTab()
                ImGui.PopItemWidth()
                ImGui.EndTabItem()
            end
            ImGui.EndChild()
            ImGui.EndTabItem()
        else
            ImGui.PopStyleColor()
        end
        ImGui.PushStyleColor(ImGuiCol.Text, ORANGE)
        if ImGui.BeginTabItem(lists.icons.FA_FIRE..' Burn') then
            ImGui.PopStyleColor()
            if ImGui.BeginChild('Burn', -1, -1, false, ImGuiWindowFlags.HorizontalScrollbar) then
                ImGui.PushItemWidth(item_width)
                drawBurnTab()
                ImGui.PopItemWidth()
                ImGui.EndTabItem()
            end
            ImGui.EndChild()
            ImGui.EndTabItem()
        else
            ImGui.PopStyleColor()
        end
        if ImGui.BeginTabItem('Pull') then
            if ImGui.BeginChild('Pull', -1, -1, false, ImGuiWindowFlags.HorizontalScrollbar) then
                ImGui.PushItemWidth(item_width)
                drawPullTab()
                ImGui.PopItemWidth()
            end
            ImGui.EndChild()
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem('Rest') then
            if ImGui.BeginChild('Rest', -1, -1, false, ImGuiWindowFlags.HorizontalScrollbar) then
                ImGui.PushItemWidth(item_width)
                drawRestTab()
                ImGui.PopItemWidth()
            end
            ImGui.EndChild()
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem('Debug') then
            if ImGui.BeginChild('Debug', -1, -1, false, ImGuiWindowFlags.HorizontalScrollbar) then
                ImGui.PushItemWidth(item_width)
                drawDebugTab()
                ImGui.PopItemWidth()
                ImGui.EndTabItem()
            end
            ImGui.EndChild()
            ImGui.EndTabItem()
        end
        ImGui.EndTabBar()
    end
end

local function drawHeader()
    local x, y = ImGui.GetContentRegionAvail()
    local buttonWidth = (x / 2) - 22
    if state.paused then
        if ImGui.Button(lists.icons.FA_PLAY, buttonWidth, BUTTON_HEIGHT) then
            camp.setCamp()
            state.paused = false
        end
    else
        if ImGui.Button(lists.icons.FA_PAUSE, buttonWidth, BUTTON_HEIGHT) then
            state.paused = true
            state.resetCombatState()
            mq.cmd('/stopcast')
        end
    end
    helpMarker('Pause/Resume')
    ImGui.SameLine()
    if ImGui.Button(lists.icons.FA_SAVE, buttonWidth, BUTTON_HEIGHT) then
        aqo.class.saveSettings()
    end
    helpMarker('Save Settings')
    ImGui.SameLine()
    if ImGui.Button(lists.icons.MD_HELP, -1, BUTTON_HEIGHT) then
        helpGUIOpen = true
    end
    helpMarker('Help')
    ImGui.Text('Bot Status: ')
    ImGui.SameLine()
    ImGui.SetCursorPosX(buttonWidth+16)
    if state.paused then
        ImGui.TextColored(RED, 'PAUSED')
    else
        ImGui.TextColored(GREEN, 'RUNNING')
    end
    local current_mode = config.MODE.value:getName()
    ImGui.PushItemWidth(item_width)
    mid_x = buttonWidth+8
    config.MODE.value = mode.fromString(ui.drawComboBox('Mode', config.MODE.value:getName(), mode.mode_names))
    mid_x = 140
    ImGui.PopItemWidth()
    if current_mode ~= config.MODE.value:getName() and not state.paused then
        camp.setCamp()
    end
end

local function pushStyle(theme)
    local t = lists.uiThemes[theme]
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
end

local function popStyles()
    ImGui.PopStyleColor(18)
end

local function drawAbilityInspector()
    if abilityGUIOpen then
        abilityGUIOpen, shouldDrawAbilityGUI = ImGui.Begin(('Ability Inspector##AQOBOTUI%s'):format(state.class), abilityGUIOpen, ImGuiWindowFlags.AlwaysAutoResize)
        if shouldDrawAbilityGUI then
            if ImGui.TreeNode('Class Order') then
                for _,routine in ipairs(aqo.class.classOrder) do
                    ImGui.Text(routine)
                end
                ImGui.TreePop()
            end
            if mq.TLO.Me.Class.CanCast() then
                if ImGui.TreeNode('Spells') then
                    for alias,spell in pairs(aqo.class.spells) do
                        if ImGui.TreeNode(alias..'##spellalias') then
                            ImGui.Text('Name: %s', spell.name)
                            for opt,value in pairs(spell) do
                                if opt ~= 'name' and (type(value) == 'number' or type(value) == 'string' or type(value) == 'boolean') then
                                    ImGui.Text('%s: %s', opt, value)
                                end
                            end
                            ImGui.TreePop()
                        end
                    end
                    ImGui.TreePop()
                end
                if ImGui.TreeNode('Spell Sets') then
                    for spellSetName,spellSet in pairs(aqo.class.spellRotations) do
                        if ImGui.TreeNode(spellSetName..'##spellset') then
                            for _,spell in ipairs(spellSet) do
                                ImGui.Text(spell.name)
                            end
                            ImGui.TreePop()
                        end
                    end
                    ImGui.TreePop()
                end
            end
            if ImGui.TreeNode('Lists') then
                for i, list in ipairs(lists.classLists) do
                    if #aqo.class[list] > 0 then
                        if ImGui.TreeNode(list..'##lists'..i) then
                            for j,ability in ipairs(aqo.class[list]) do
                                if ImGui.TreeNode(ability.name..'##list'..list..i..j) then
                                    for opt,value in pairs(ability) do
                                        if opt ~= 'name' and (type(value) == 'number' or type(value) == 'string' or type(value) == 'boolean') then
                                            local color = WHITE
                                            if opt == 'opt' then if aqo.class.isEnabled(value) then color = GREEN else color = RED end end
                                            ImGui.TextColored(color, '%s: %s', opt, value)
                                        end
                                    end
                                    ImGui.TreePop()
                                end
                            end
                            ImGui.TreePop()
                        end
                    end
                end
                ImGui.TreePop()
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
                for _,command in ipairs(aqo.commands.help) do
                    ImGui.TextColored(YELLOW, '/aqo '..command.command) ImGui.SameLine() ImGui.Text(command.tip)
                end
                ImGui.TreePop()
            end
            for _,category in ipairs(config.categories()) do
                local categoryConfigs = config.getByCategory(category)
                if ImGui.TreeNode(category..' Configuration') then
                    for _,key in ipairs(categoryConfigs) do
                        local cfg = config[key]
                        if type(cfg) == 'table' then
                            ImGui.TextColored(YELLOW, '/aqo ' .. key .. ' <' .. type(cfg.value) .. '>')
                            ImGui.SameLine()
                            ImGui.Text(cfg.tip)
                        end
                    end
                    ImGui.TreePop()
                end
            end
            if ImGui.TreeNode('Class Configuration') then
                for key,value in pairs(aqo.class.OPTS) do
                    local valueType = type(value.value)
                    if valueType == 'string' or valueType == 'number' or valueType == 'boolean' then
                        ImGui.TextColored(YELLOW, '/aqo ' .. key .. ' <' .. valueType .. '>')
                        ImGui.SameLine()
                        ImGui.Text(value.tip)
                    end
                end
                ImGui.TreePop()
            end
            if ImGui.TreeNode('Gear Check (WARNING*: Characters announce their gear to guild chat!') then
                ImGui.TextColored(YELLOW, '/tell <name> gear <slotname>')
                ImGui.TextColored(YELLOW, 'Slot Names')
                ImGui.SameLine()
                ImGui.Text(lists.slotList)
                ImGui.TreePop()
            end
            if ImGui.TreeNode('Buff Begging  (WARNING*: Characters accounce requests to group or raid chat!') then
                ImGui.TextColored(YELLOW, '/tell <name> <alias>')
                ImGui.TextColored(YELLOW, 'Aliases:')
                for alias,_ in pairs(aqo.class.requestAliases) do
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
    pushStyle(uiTheme)
    openGUI, shouldDrawGUI = ImGui.Begin(string.format('AQO Bot 1.0 - %s###AQOBOTUI%s', state.class, state.class), openGUI, 0)
    if shouldDrawGUI then
        drawHeader()
        drawBody()
    end
    ImGui.End()
    drawAbilityInspector()
    drawHelpWindow()
    popStyles()
end

return ui