--- @type Mq
local mq = require('mq')
--- @type ImGui
require 'ImGui'

local camp = require('routines.camp')
local common = require('common')
local config = require('configuration')
local mode = require('mode')
local state = require('state')
local logger = require('utils.logger')

-- UI Control variables
local open_gui = true
local should_draw_gui = true

-- UI constants
local MINIMUM_WIDTH = 372
local FULL_BUTTON_WIDTH = 354
local HALF_BUTTON_WIDTH = 173
local BUTTON_HEIGHT = 22
local mid_x = 140
local item_width = 115
local X_COLUMN_OFFSET = 265
local Y_COLUMN_OFFSET = 30

local icons = {
    FA_PLAY = '\xef\x81\x8b',
    FA_PAUSE = '\xef\x81\x8c',
    FA_STOP = '\xef\x81\x8d',
    FA_SAVE = '\xee\x85\xa1',
    FA_HEART = '\xef\x80\x84',
    FA_FIRE = '\xef\x81\xad',
}

local aqo
local ui = {}

function ui.init(_aqo)
    aqo = _aqo
    mq.imgui.init('AQO Bot 1.0', ui.main)
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
    config.ASSIST.value = ui.draw_combo_box('Assist', config.ASSIST.value, common.ASSISTS, true)
    config.AUTOASSISTAT.value = ui.draw_input_int('Assist %', '##assistat', config.AUTOASSISTAT.value, 'Percent HP to assist at')
    config.SWITCHWITHMA.value = ui.draw_check_box('Switch With MA', '##switchwithma', config.SWITCHWITHMA.value, 'Switch targets with MA')
    local current_camp_radius = config.CAMPRADIUS.value
    config.CAMPRADIUS.value = ui.draw_input_int('Camp Radius', '##campradius', config.CAMPRADIUS.value, 'Camp radius to assist within')
    config.CHASETARGET.value = ui.draw_input_text('Chase Target', '##chasetarget', config.CHASETARGET.value, 'Chase Target')
    config.CHASEDISTANCE.value = ui.draw_input_int('Chase Distance', '##chasedist', config.CHASEDISTANCE.value, 'Distance to follow chase target')
    config.RESISTSTOPCOUNT.value = ui.draw_input_int('Resist Stop Count', '##resiststopcount', config.RESISTSTOPCOUNT.value, 'The number of resists after which to stop trying casting a spell on a mob')
    if state.emu then
        config.MAINTANK.value = ui.draw_check_box('Main Tank', '##maintank', config.MAINTANK.value, 'Am i main tank')
        config.LOOTMOBS.value = ui.draw_check_box('Loot Mobs', '##lootmobs', config.LOOTMOBS.value, 'Loot corpses')
        config.AUTODETECTRAID.value = ui.draw_check_box('Auto-Detect Raid', '##detectraid', config.AUTODETECTRAID.value, 'Set raid assist settings automatically if in a raid')
    end

    if current_camp_radius ~= config.CAMPRADIUS.value then
        camp.set_camp()
    end
end

local function draw_skills_tab()
    local x, y = ImGui.GetCursorPos()
    local xOffset = x
    local yOffset = y
    local maxY = yOffset
    local _, yAvail = ImGui.GetContentRegionAvail()
    for _,key in ipairs(aqo.class.OPTS) do
        if key ~= 'USEGLYPH' and key ~= 'USEINTENSITY' then
            local option = aqo.class.OPTS[key]
            if option.type == 'checkbox' then
                option.value = ui.draw_check_box(option.label, '##'..key, option.value, option.tip, xOffset, yOffset)
                if option.value and option.exclusive then aqo.class.OPTS[option.exclusive].value = false end
            elseif option.type == 'combobox' then
                option.value = ui.draw_combo_box(option.label, option.value, option.options, true, xOffset, yOffset)
            elseif option.type == 'inputint' then
                option.value = ui.draw_input_int(option.label, '##'..key, option.value, option.tip, xOffset, yOffset)
            end
            xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
        end
    end
    config.RECOVERPCT.value = ui.draw_input_int('Recover Pct', '##recoverpct', config.RECOVERPCT.value, 'Percent Mana or End to use class recover abilities', xOffset, yOffset)
    local xAvail = ImGui.GetContentRegionAvail()
    x, y = ImGui.GetWindowSize()
    if x < xOffset + X_COLUMN_OFFSET or xAvail > 20 then x = math.max(MINIMUM_WIDTH, xOffset + X_COLUMN_OFFSET) ImGui.SetWindowSize(x, y) end
    if y < maxY or y > maxY+35 then ImGui.SetWindowSize(x, maxY+35) end
end

local function draw_heal_tab()
    if state.class == 'clr' or state.class == 'dru' or state.class == 'shm' then
        config.HEALPCT.value = ui.draw_input_int('Heal Pct', '##healpct', config.HEALPCT.value, 'Percent HP to begin casting regular heals')
        config.PANICHEALPCT.value = ui.draw_input_int('Panic Heal Pct', '##panichealpct', config.PANICHEALPCT.value, 'Percent HP to begin casting panic heals')
        config.GROUPHEALPCT.value = ui.draw_input_int('Group Heal Pct', '##grouphealpct', config.GROUPHEALPCT.value, 'Percent HP to begin casting group heals')
        config.GROUPHEALMIN.value = ui.draw_input_int('Group Heal Min', '##grouphealmin', config.GROUPHEALMIN.value, 'Minimum number of hurt group members to begin casting group heals')
        config.HOTHEALPCT.value = ui.draw_input_int('HoT Pct', '##hothealpct', config.HOTHEALPCT.value, 'Percent HP to begin casting HoTs')
        config.REZGROUP.value = ui.draw_check_box('Rez Group', '##rezgroup', config.REZGROUP.value, 'Rez Group Members')
        config.REZRAID.value = ui.draw_check_box('Rez Raid', '##rezraid', config.REZRAID.value, 'Rez Raid Members')
        config.REZINCOMBAT.value = ui.draw_check_box('Rez In Combat', '##rezincombat', config.REZINCOMBAT.value, 'Rez In Combat')
        config.PRIORITYTARGET.value = ui.draw_input_text('Priority Target', '##prioritytarget', config.PRIORITYTARGET.value, 'Main focus for heals')
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
    config.BURNCOUNT.value = ui.draw_input_int('Burn Count', '##burncnt', config.BURNCOUNT.value, 'Trigger burns if this many mobs are on aggro')
    config.BURNPCT.value = ui.draw_input_int('Burn Percent', '##burnpct', config.BURNPCT.value, 'Percent health to begin burns')
    config.BURNALWAYS.value = ui.draw_check_box('Burn Always', '##burnalways', config.BURNALWAYS.value, 'Always be burning')
    config.BURNALLNAMED.value = ui.draw_check_box('Burn Named', '##burnnamed', config.BURNALLNAMED.value, 'Burn all named')
    config.USEGLYPH.value = ui.draw_check_box('Use Glyph', '##glyph', config.USEGLYPH.value, 'Use Glyph of Destruction on Burn')
    config.USEINTENSITY.value = ui.draw_check_box('Use Intensity', '##intensity', config.USEINTENSITY.value, 'Use Intensity of the Resolute on Burn')
    if aqo.class.draw_burn_tab then aqo.class.draw_burn_tab() end
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
    config.PULLWITH.value = ui.draw_combo_box('Pull With', config.PULLWITH.value, common.PULL_WITH, true, xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    local current_radius = config.PULLRADIUS.value
    local current_pullarc = config.PULLARC.value
    config.PULLRADIUS.value = ui.draw_input_int('Pull Radius', '##pullrad', config.PULLRADIUS.value, 'Radius to pull mobs within', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.PULLLOW.value = ui.draw_input_int('Pull ZLow', '##pulllow', config.PULLLOW.value, 'Z Low pull range', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.PULLHIGH.value = ui.draw_input_int('Pull ZHigh', '##pullhigh', config.PULLHIGH.value, 'Z High pull range', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.PULLMINLEVEL.value = ui.draw_input_int('Pull Min Level', '##pullminlvl', config.PULLMINLEVEL.value, 'Minimum level mobs to pull', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.PULLMAXLEVEL.value = ui.draw_input_int('Pull Max Level', '##pullmaxlvl', config.PULLMAXLEVEL.value, 'Maximum level mobs to pull', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.PULLARC.value = ui.draw_input_int('Pull Arc', '##pullarc', config.PULLARC.value, 'Only pull from this slice of the radius, centered around your current heading', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.GROUPWATCHWHO.value = ui.draw_combo_box('Group Watch', config.GROUPWATCHWHO.value, common.GROUP_WATCH_OPTS, true, xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.MEDMANASTART.value = ui.draw_input_int('Med Mana Start', '##medmanastart', config.MEDMANASTART.value, 'Pct Mana to begin medding', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.MEDMANASTOP.value = ui.draw_input_int('Med Mana Stop', '##medmanastop', config.MEDMANASTOP.value, 'Pct Mana to stop medding', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.MEDENDSTART.value = ui.draw_input_int('Med End Start', '##medendstart', config.MEDENDSTART.value, 'Pct End to begin medding', xOffset, yOffset)
    xOffset, yOffset, maxY = ui.get_next_xy(y, yAvail, xOffset, yOffset, maxY)
    config.MEDENDSTOP.value = ui.draw_input_int('Med End Stop', '##medendstop', config.MEDENDSTOP.value, 'Pct End to stop medding', xOffset, yOffset)
    if current_radius ~= config.PULLRADIUS.value or current_pullarc ~= config.PULLARC.value then
        camp.set_camp()
    end
    local xAvail, yAvail = ImGui.GetContentRegionAvail()
    local x, y = ImGui.GetWindowSize()
    if x < xOffset + X_COLUMN_OFFSET or xAvail > 20 then x = math.max(MINIMUM_WIDTH, xOffset + X_COLUMN_OFFSET) ImGui.SetWindowSize(x, y) end
    if y < maxY or y > maxY+35 then ImGui.SetWindowSize(x, maxY+35) end
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
    ImGui.TextColored(1, 1, 1, 1, config.MODE.value:get_name())

    ImGui.TextColored(1, 1, 0, 1, 'Camp:')
    ImGui.SameLine()
    ImGui.SetCursorPosX(150)
    if camp.Active then
        ImGui.TextColored(1, 1, 0, 1, string.format('X: %.02f  Y: %.02f  Z: %.02f', camp.X, camp.Y, camp.Z))
        ImGui.TextColored(1, 1, 0, 1, 'Radius:')
        ImGui.SameLine()
        ImGui.SetCursorPosX(150)    
        ImGui.TextColored(1, 1, 0, 1, string.format('%d', config.CAMPRADIUS.value))
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
            if ImGui.BeginChild('General', -1, -1, false, ImGuiWindowFlags.HorizontalScrollbar) then
                ImGui.PushItemWidth(item_width)
                draw_assist_tab()
                ImGui.PopItemWidth()
                ImGui.EndTabItem()
            end
            ImGui.EndChild()
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem('Skills') then
            if ImGui.BeginChild('Skills', -1, -1, false, ImGuiWindowFlags.HorizontalScrollbar) then
                ImGui.PushItemWidth(item_width)
                draw_skills_tab()
                ImGui.PopItemWidth()
            end
            ImGui.EndChild()
            ImGui.EndTabItem()
        end
        if state.class  == 'clr' or state.class == 'shm' or state.class == 'dru' then
            ImGui.PushStyleColor(ImGuiCol.Text, .6, .8, 1, 1)
            if ImGui.BeginTabItem(icons.FA_HEART..' Heal') then
                ImGui.PopStyleColor()
                if ImGui.BeginChild('Heal', -1, -1, false, ImGuiWindowFlags.HorizontalScrollbar) then
                    ImGui.PushItemWidth(item_width)
                    draw_heal_tab()
                    ImGui.PopItemWidth()
                    ImGui.EndTabItem()
                end
                ImGui.EndChild()
                ImGui.EndTabItem()
            else
                ImGui.PopStyleColor()
            end
        end
        ImGui.PushStyleColor(ImGuiCol.Text, 1, .65, 0, 1)
        if ImGui.BeginTabItem(icons.FA_FIRE..' Burn') then
            ImGui.PopStyleColor()
            if ImGui.BeginChild('Burn', -1, -1, false, ImGuiWindowFlags.HorizontalScrollbar) then
                ImGui.PushItemWidth(item_width)
                draw_burn_tab()
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
                draw_pull_tab()
                ImGui.PopItemWidth()
            end
            ImGui.EndChild()
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem('Debug') then
            if ImGui.BeginChild('Debug', -1, -1, false, ImGuiWindowFlags.HorizontalScrollbar) then
                ImGui.PushItemWidth(item_width)
                draw_debug_tab()
                ImGui.PopItemWidth()
                ImGui.EndTabItem()
            end
            ImGui.EndChild()
            ImGui.EndTabItem()
        end
        ImGui.EndTabBar()
    end
end

local function draw_header()
    if state.paused then
        if ImGui.Button(icons.FA_PLAY, HALF_BUTTON_WIDTH, BUTTON_HEIGHT) then
            camp.set_camp()
            state.paused = false
        end
    else
        if ImGui.Button(icons.FA_PAUSE, HALF_BUTTON_WIDTH, BUTTON_HEIGHT) then
            state.paused = true
            state.reset_combat_state()
            mq.cmd('/stopcast')
        end
    end
    ImGui.SameLine()
    if ImGui.Button(icons.FA_SAVE, HALF_BUTTON_WIDTH, BUTTON_HEIGHT) then
        aqo.class.save_settings()
    end
    ImGui.Text('Bot Status: ')
    ImGui.SameLine()
    ImGui.SetCursorPosX(190)
    if state.paused then
        ImGui.TextColored(1, 0, 0, 1, 'PAUSED')
    else
        ImGui.TextColored(0, 1, 0, 1, 'RUNNING')
    end

    local current_mode = config.MODE.value:get_name()
    ImGui.PushItemWidth(item_width)
    mid_x = 182
    config.MODE.value = mode.from_string(ui.draw_combo_box('Mode', config.MODE.value:get_name(), mode.mode_names))
    mid_x = 140
    ImGui.PopItemWidth()
    if current_mode ~= config.MODE.value:get_name() and not state.paused then
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
    open_gui, should_draw_gui = ImGui.Begin(string.format('AQO Bot 1.0 - %s###AQOBOTUI%s', state.class, state.class), open_gui, 0)
    if should_draw_gui then
        local width, length = ImGui.GetWindowSize()
        if width < 330 then
            ImGui.SetNextWindowSize(330, length)
        end
        if length < 400 then
            ImGui.SetNextWindowSize(width, 400)
        end
        draw_header()
        draw_body()
    end
    ImGui.End()
    pop_styles()
end

return ui