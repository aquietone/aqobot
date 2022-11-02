--- @type Mq
local mq = require('mq')
--- @type ImGui
require 'ImGui'

local camp = require(AQO..'.routines.camp')
local common = require(AQO..'.common')
local config = require(AQO..'.configuration')
local mode = require(AQO..'.mode')
local state = require(AQO..'.state')
local logger = require(AQO..'.utils.logger')

-- GUI Control variables
local open_gui = true
local should_draw_gui = true

local class_funcs
local ui = {}

local MINIMUM_WIDTH = 372
local FULL_BUTTON_WIDTH = 354
local HALF_BUTTON_WIDTH = 173
local BUTTON_HEIGHT = 22
local mid_x = 140
local item_width = 115
local X_COLUMN_OFFSET = 265
local Y_COLUMN_OFFSET = 30

ui.set_class_funcs = function(funcs)
    class_funcs = funcs
end

ui.toggle_gui = function(open)
    open_gui = open
end

local function help_marker(desc)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0)
        ImGui.Text(desc)
        ImGui.PopTextWrapPos()
        ImGui.EndTooltip()
    end
end

ui.draw_combo_box = function(label, resultvar, options, bykey, xOffset, yOffset)
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

ui.draw_check_box = function(labelText, idText, resultVar, helpText, xOffset, yOffset)
    if not yOffset and not xOffset then xOffset, yOffset = ImGui.GetCursorPos() end
    ImGui.SetCursorPosX(xOffset)
    ImGui.SetCursorPosY(yOffset+5)
    if resultVar then
        ImGui.TextColored(0, 1, 0, 1, labelText)
    else
        ImGui.TextColored(1, 0, 0, 1, labelText)
    end
    ImGui.SameLine()
    help_marker(helpText)
    ImGui.SameLine()
    local x,y = ImGui.GetCursorPos()
    ImGui.SetCursorPosY(y-3)
    ImGui.SetCursorPosX(mid_x + xOffset)
    resultVar,_ = ImGui.Checkbox(idText, resultVar)
    return resultVar
end

ui.draw_input_int = function(labelText, idText, resultVar, helpText, xOffset, yOffset)
    if not yOffset and not xOffset then xOffset, yOffset = ImGui.GetCursorPos() end
    ImGui.SetCursorPosX(xOffset)
    ImGui.SetCursorPosY(yOffset+5)
    ImGui.Text(labelText)
    ImGui.SameLine()
    help_marker(helpText)
    ImGui.SameLine()
    local _,y = ImGui.GetCursorPos()
    ImGui.SetCursorPosY(y-3)
    ImGui.SetCursorPosX(mid_x + xOffset)
    resultVar = ImGui.InputInt(idText, resultVar)
    return resultVar
end

ui.draw_input_text = function(labelText, idText, resultVar, helpText, xOffset, yOffset)
    if not yOffset and not xOffset then xOffset, yOffset = ImGui.GetCursorPos() end
    ImGui.SetCursorPosX(xOffset)
    ImGui.SetCursorPosY(yOffset+5)
    ImGui.Text(labelText)
    ImGui.SameLine()
    help_marker(helpText)
    ImGui.SameLine()
    local _,y = ImGui.GetCursorPos()
    ImGui.SetCursorPosY(y-3)
    ImGui.SetCursorPosX(mid_x + xOffset)
    resultVar = ImGui.InputText(idText, resultVar)
    return resultVar
end

ui.get_next_xy = function(startY, yAvail, xOffset, yOffset, maxY)
    yOffset = yOffset + Y_COLUMN_OFFSET
    if yOffset > maxY then maxY = yOffset end
    if yAvail - yOffset + startY < 25 then
        xOffset = xOffset + X_COLUMN_OFFSET
        yOffset = startY
    end
    return xOffset, yOffset, maxY
end

local function draw_assist_tab()
    if ImGui.Button('Reset Camp', FULL_BUTTON_WIDTH, BUTTON_HEIGHT) then
        camp.set_camp(true)
    end
    config.ASSIST = ui.draw_combo_box('Assist', config.ASSIST, common.ASSISTS, true)
    config.AUTOASSISTAT = ui.draw_input_int('Assist %', '##assistat', config.AUTOASSISTAT, 'Percent HP to assist at')
    config.SWITCHWITHMA = ui.draw_check_box('Switch With MA', '##switchwithma', config.SWITCHWITHMA, 'Switch targets with MA')
    local current_camp_radius = config.CAMPRADIUS
    config.CAMPRADIUS = ui.draw_input_int('Camp Radius', '##campradius', config.CAMPRADIUS, 'Camp radius to assist within')
    config.CHASETARGET = ui.draw_input_text('Chase Target', '##chasetarget', config.CHASETARGET, 'Chase Target')
    config.CHASEDISTANCE = ui.draw_input_int('Chase Distance', '##chasedist', config.CHASEDISTANCE, 'Distance to follow chase target')
    config.MAINTANK = ui.draw_check_box('Main Tank', '##maintank', config.MAINTANK, 'Am i main tank')
    config.LOOTMOBS = ui.draw_check_box('Loot Mobs', '##lootmobs', config.LOOTMOBS, 'Loot corpses')

    if current_camp_radius ~= config.CAMPRADIUS then
        camp.set_camp()
    end
end

local function draw_camp_tab()
    if ImGui.Button('Reset Camp', FULL_BUTTON_WIDTH, BUTTON_HEIGHT) then
        camp.set_camp(true)
    end
    local current_camp_radius = config.CAMPRADIUS
    config.CAMPRADIUS = ui.draw_input_int('Camp Radius', '##campradius', config.CAMPRADIUS, 'Camp radius to assist within')
    config.CHASETARGET = ui.draw_input_text('Chase Target', '##chasetarget', config.CHASETARGET, 'Chase Target')
    config.CHASEDISTANCE = ui.draw_input_int('Chase Distance', '##chasedist', config.CHASEDISTANCE, 'Distance to follow chase target')
    if current_camp_radius ~= config.CAMPRADIUS then
        camp.set_camp()
    end
end

local function draw_skills_tab()
    local x, y = ImGui.GetCursorPos()
    local xOffset = x
    local yOffset = y
    local maxY = yOffset
    local _, yAvail = ImGui.GetContentRegionAvail()
    for _,key in ipairs(class_funcs.OPTS) do
        if key ~= 'USEGLYPH' and key ~= 'USEINTENSITY' then
            local option = class_funcs.OPTS[key]
            if option.type == 'checkbox' then
                option.value = ui.draw_check_box(option.label, '##'..key, option.value, option.tip, xOffset, yOffset)
                if option.value and option.exclusive then class_funcs.OPTS[option.exclusive].value = false end
            elseif option.type == 'combobox' then
                option.value = ui.draw_combo_box(option.label, option.value, option.options, true, xOffset, yOffset)
            elseif option.type == 'inputint' then
                option.value = ui.draw_input_int(option.label, '##'..key, option.value, option.tip, xOffset, yOffset)
            end
            xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
        end
    end
    config.RECOVERPCT = ui.draw_input_int('Recover Pct', '##recoverpct', config.RECOVERPCT, 'Percent Mana or End to use class recover abilities', xOffset, yOffset)
    local xAvail = ImGui.GetContentRegionAvail()
    x, y = ImGui.GetWindowSize()
    if x < xOffset + X_COLUMN_OFFSET or xAvail > 20 then x = math.max(MINIMUM_WIDTH, xOffset + X_COLUMN_OFFSET) ImGui.SetWindowSize(x, y) end
    if y < maxY or y > maxY+35 then ImGui.SetWindowSize(x, maxY+35) end
end

local function draw_heal_tab()
    if state.class == 'clr' or state.class == 'dru' or state.class == 'shm' then
        config.HEALPCT = ui.draw_input_int('Heal Pct', '##healpct', config.HEALPCT, 'Percent HP to begin casting regular heals')
        config.PANICHEALPCT = ui.draw_input_int('Panic Heal Pct', '##panichealpct', config.PANICHEALPCT, 'Percent HP to begin casting panic heals')
        config.GROUPHEALPCT = ui.draw_input_int('Group Heal Pct', '##grouphealpct', config.GROUPHEALPCT, 'Percent HP to begin casting group heals')
        config.GROUPHEALMIN = ui.draw_input_int('Group Heal Min', '##grouphealmin', config.GROUPHEALMIN, 'Minimum number of hurt group members to begin casting group heals')
        config.HOTHEALPCT = ui.draw_input_int('HoT Pct', '##hothealpct', config.HOTHEALPCT, 'Percent HP to begin casting HoTs')
        config.REZGROUP = ui.draw_check_box('Rez Group', '##rezgroup', config.REZGROUP, 'Rez Group Members')
        config.REZRAID = ui.draw_check_box('Rez Raid', '##rezraid', config.REZRAID, 'Rez Raid Members')
        config.REZINCOMBAT = ui.draw_check_box('Rez In Combat', '##rezincombat', config.REZINCOMBAT, 'Rez In Combat')
        config.PRIORITYTARGET = ui.draw_input_text('Priority Target', '##prioritytarget', config.PRIORITYTARGET, 'Main focus for heals')
    end
end

local function draw_burn_tab()
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
    config.BURNCOUNT = ui.draw_input_int('Burn Count', '##burncnt', config.BURNCOUNT, 'Trigger burns if this many mobs are on aggro')
    config.BURNPCT = ui.draw_input_int('Burn Percent', '##burnpct', config.BURNPCT, 'Percent health to begin burns')
    config.BURNALWAYS = ui.draw_check_box('Burn Always', '##burnalways', config.BURNALWAYS, 'Always be burning')
    config.BURNALLNAMED = ui.draw_check_box('Burn Named', '##burnnamed', config.BURNALLNAMED, 'Burn all named')
    config.USEGLYPH = ui.draw_check_box('Use Glyph', '##glyph', config.USEGLYPH, 'Use Glyph of Destruction on Burn')
    config.USEINTENSITY = ui.draw_check_box('Use Intensity', '##intensity', config.USEINTENSITY, 'Use Intensity of the Resolute on Burn')
    if class_funcs.draw_burn_tab then class_funcs.draw_burn_tab() end
end

local function draw_pull_tab()
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
    local current_radius = config.PULLRADIUS
    local current_pullarc = config.PULLARC
    config.PULLRADIUS = ui.draw_input_int('Pull Radius', '##pullrad', config.PULLRADIUS, 'Radius to pull mobs within', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.PULLLOW = ui.draw_input_int('Pull ZLow', '##pulllow', config.PULLLOW, 'Z Low pull range', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.PULLHIGH = ui.draw_input_int('Pull ZHigh', '##pullhigh', config.PULLHIGH, 'Z High pull range', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.PULLMINLEVEL = ui.draw_input_int('Pull Min Level', '##pullminlvl', config.PULLMINLEVEL, 'Minimum level mobs to pull', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.PULLMAXLEVEL = ui.draw_input_int('Pull Max Level', '##pullmaxlvl', config.PULLMAXLEVEL, 'Maximum level mobs to pull', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.PULLARC = ui.draw_input_int('Pull Arc', '##pullarc', config.PULLARC, 'Only pull from this slice of the radius, centered around your current heading', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.GROUPWATCHWHO = ui.draw_combo_box('Group Watch', config.GROUPWATCHWHO, common.GROUP_WATCH_OPTS, true, xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.MEDMANASTART = ui.draw_input_int('Med Mana Start', '##medmanastart', config.MEDMANASTART, 'Pct Mana to begin medding', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.MEDMANASTOP = ui.draw_input_int('Med Mana Stop', '##medmanastop', config.MEDMANASTOP, 'Pct Mana to stop medding', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.MEDENDSTART = ui.draw_input_int('Med End Start', '##medendstart', config.MEDENDSTART, 'Pct End to begin medding', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.MEDENDSTOP = ui.draw_input_int('Med End Stop', '##medendstop', config.MEDENDSTOP, 'Pct End to stop medding', xOffset, yOffset)
    if current_radius ~= config.PULLRADIUS or current_pullarc ~= config.PULLARC then
        camp.set_camp()
    end
    local xAvail, yAvail = ImGui.GetContentRegionAvail()
    local x, y = ImGui.GetWindowSize()
    if x < xOffset + X_COLUMN_OFFSET or xAvail > 20 then x = math.max(MINIMUM_WIDTH, xOffset + X_COLUMN_OFFSET) ImGui.SetWindowSize(x, y) end
    if y < maxY or y > maxY+35 then ImGui.SetWindowSize(x, maxY+35) end
end

local function draw_loot_tab()
    config.LOOTMOBS = ui.draw_check_box('Loot Mobs', '##lootmobs', config.LOOTMOBS, 'Loot corpses')
end

local function draw_debug_combo_box()
    ImGui.PushItemWidth(300)
    if ImGui.BeginCombo('##debugoptions', 'debug options') then
        for category, subcategories in pairs(logger.log_flags) do
            for subcategory, enabled in pairs(subcategories) do
                logger.log_flags[category][subcategory] = ImGui.Checkbox(category..' - '..subcategory, enabled)
            end
        end
        ImGui.EndCombo()
    end
    ImGui.PopItemWidth()
end

local function draw_debug_tab()
    draw_debug_combo_box()
    ImGui.TextColored(1, 1, 0, 1, 'Mode:')
    ImGui.SameLine()
    ImGui.SetCursorPosX(150)
    ImGui.TextColored(1, 1, 1, 1, config.MODE:get_name())

    ImGui.TextColored(1, 1, 0, 1, 'Camp:')
    ImGui.SameLine()
    ImGui.SetCursorPosX(150)
    if camp.Active then
        ImGui.TextColored(1, 1, 0, 1, string.format('X: %.02f  Y: %.02f  Z: %.02f', camp.X, camp.Y, camp.Z))
        ImGui.TextColored(1, 1, 0, 1, 'Radius:')
        ImGui.SameLine()
        ImGui.SetCursorPosX(150)    
        ImGui.TextColored(1, 1, 0, 1, string.format('%d', config.CAMPRADIUS))
    else
        ImGui.TextColored(1, 0, 0, 1, '--')
    end

    for k,v in pairs(state) do
        if type(v) ~= 'table' and type(v) ~= 'function' then
            ImGui.TextColored(1, 1, 0, 1, ('%s:'):format(k))
            ImGui.SameLine()
            ImGui.SetCursorPosX(150)
            ImGui.TextColored(1, 0, 0, 1, ('%s'):format(v))
        end
    end
end

local function draw_body()
    if ImGui.BeginTabBar('##tabbar') then
        if ImGui.BeginTabItem('General') then
            ImGui.PushItemWidth(item_width)
            draw_assist_tab()
            ImGui.PopItemWidth()
            ImGui.EndTabItem()
        end
        --[[if ImGui.BeginTabItem('Camp') then
            ImGui.PushItemWidth(item_width)
            draw_camp_tab()
            ImGui.PopItemWidth()
            ImGui.EndTabItem()
        end]]
        if ImGui.BeginTabItem('Skills') then
                ImGui.PushItemWidth(item_width)
                draw_skills_tab()
                ImGui.PopItemWidth()
            ImGui.EndTabItem()
        end
        if state.class  == 'clr' or state.class == 'shm' or state.class == 'dru' then
            if ImGui.BeginTabItem('Heal') then
                ImGui.PushItemWidth(item_width)
                draw_heal_tab()
                ImGui.PopItemWidth()
                ImGui.EndTabItem()
            end
        end
        if ImGui.BeginTabItem('Burn') then
            ImGui.PushItemWidth(item_width)
            draw_burn_tab()
            ImGui.PopItemWidth()
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem('Pull') then
                ImGui.PushItemWidth(item_width)
                draw_pull_tab()
                ImGui.PopItemWidth()
            ImGui.EndTabItem()
        end
        --[[if ImGui.BeginTabItem('Loot') then
            ImGui.PushItemWidth(item_width)
            draw_loot_tab()
            ImGui.PopItemWidth()
            ImGui.EndTabItem()
        end]]
        if ImGui.BeginTabItem('Debug') then
            ImGui.PushItemWidth(item_width)
            draw_debug_tab()
            ImGui.PopItemWidth()
            ImGui.EndTabItem()
        end
        ImGui.EndTabBar()
    end
end

local function draw_header()
    if state.paused then
        if ImGui.Button('RESUME', HALF_BUTTON_WIDTH, BUTTON_HEIGHT) then
            camp.set_camp()
            state.paused = false
        end
    else
        if ImGui.Button('PAUSE', HALF_BUTTON_WIDTH, BUTTON_HEIGHT) then
            state.paused = true
            state.reset_combat_state()
            mq.cmd('/stopcast')
        end
    end
    ImGui.SameLine()
    if ImGui.Button('Save Settings', HALF_BUTTON_WIDTH, BUTTON_HEIGHT) then
        class_funcs.save_settings()
    end
    ImGui.Text('Bot Status: ')
    ImGui.SameLine()
    ImGui.SetCursorPosX(190)
    if state.paused then
        ImGui.TextColored(1, 0, 0, 1, 'PAUSED')
    else
        ImGui.TextColored(0, 1, 0, 1, 'RUNNING')
    end

    local current_mode = config.MODE:get_name()
    ImGui.PushItemWidth(item_width)
    mid_x = 182
    config.MODE = mode.from_string(ui.draw_combo_box('Mode', config.MODE:get_name(), mode.mode_names))
    mid_x = 140
    ImGui.PopItemWidth()
    if current_mode ~= config.MODE:get_name() and not state.paused then
        camp.set_camp()
    end
end

local function push_styles()
    ImGui.PushStyleColor(ImGuiCol.WindowBg, .1, .1, .1, .7)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, 0, .3, .3, 1)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, 0, .5, .5, 1)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, 0, .3, .3, 1)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, 0, .4, .4, 1)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive, 0, .4, .4, 1)
    ImGui.PushStyleColor(ImGuiCol.Button, 0,.3,.3,1)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0,.5,.5,1)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0,.5,.5,1)
    ImGui.PushStyleColor(ImGuiCol.PopupBg, 0,.5,.5,1)
    ImGui.PushStyleColor(ImGuiCol.Tab, 0, 0, 0, 0)
    ImGui.PushStyleColor(ImGuiCol.TabActive, 0, .4, .4, 1)
    ImGui.PushStyleColor(ImGuiCol.TabHovered, 0, .5, .50, 1)
    ImGui.PushStyleColor(ImGuiCol.TabUnfocused, 0, 0, 0, 0)
    ImGui.PushStyleColor(ImGuiCol.TabUnfocusedActive, 0, .3, .3, 1)
    ImGui.PushStyleColor(ImGuiCol.TextDisabled, 1, 1, 1, 1)
    ImGui.PushStyleColor(ImGuiCol.CheckMark, 1, 1, 1, 1)
    ImGui.PushStyleColor(ImGuiCol.Separator, 0, .4, .4, 1)
end

local function pop_styles()
    ImGui.PopStyleColor(18)
end

-- ImGui main function for rendering the UI window
ui.main = function()
    if not open_gui then return end
    push_styles()
    open_gui, should_draw_gui = ImGui.Begin(string.format('AQO Bot 1.0 - %s###AQOBOTUI', state.class), open_gui, 0)
    if should_draw_gui then
        draw_header()
        draw_body()
    end
    ImGui.End()
    pop_styles()
end

return ui