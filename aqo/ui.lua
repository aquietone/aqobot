--- @type Mq
local mq = require('mq')
--- @type ImGui
require 'ImGui'

local camp = require('aqo.routines.camp')
local common = require('aqo.common')
local config = require('aqo.configuration')
local mode = require('aqo.mode')
local state = require('aqo.state')

-- GUI Control variables
local open_gui = true
local should_draw_gui = true

local class_funcs
local ui = {}

local mid_x = 159
local item_width = 153

ui.set_class_funcs = function(funcs)
    class_funcs = funcs
end

ui.toggle_gui = function(open)
    open_gui = open
end

local function help_marker(desc)
    ImGui.TextDisabled('(?)')
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0)
        ImGui.Text(desc)
        ImGui.PopTextWrapPos()
        ImGui.EndTooltip()
    end
end

ui.draw_combo_box = function(label, resultvar, options, bykey)
    local _,y = ImGui.GetCursorPos()
    ImGui.SetCursorPosY(y+5)
    ImGui.Text(label)
    ImGui.SameLine()
    ImGui.SetCursorPosX(mid_x)
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

ui.draw_check_box = function(labelText, idText, resultVar, helpText)
    local _,y = ImGui.GetCursorPos()
    ImGui.SetCursorPosY(y+5)
    if resultVar then
        ImGui.TextColored(0, 1, 0, 1, labelText)
    else
        ImGui.TextColored(1, 0, 0, 1, labelText)
    end
    ImGui.SameLine()
    help_marker(helpText)
    ImGui.SameLine()
    local _,y = ImGui.GetCursorPos()
    ImGui.SetCursorPosY(y-3)
    ImGui.SetCursorPosX(mid_x)
    resultVar,_ = ImGui.Checkbox(idText, resultVar)
    return resultVar
end

ui.draw_input_int = function(labelText, idText, resultVar, helpText)
    local _,y = ImGui.GetCursorPos()
    ImGui.SetCursorPosY(y+5)
    ImGui.Text(labelText)
    ImGui.SameLine()
    help_marker(helpText)
    ImGui.SameLine()
    local _,y = ImGui.GetCursorPos()
    ImGui.SetCursorPosY(y-3)
    ImGui.SetCursorPosX(mid_x)
    resultVar = ImGui.InputInt(idText, resultVar)
    return resultVar
end

ui.draw_input_text = function(labelText, idText, resultVar, helpText)
    local _,y = ImGui.GetCursorPos()
    ImGui.SetCursorPosY(y+5)
    ImGui.Text(labelText)
    ImGui.SameLine()
    help_marker(helpText)
    ImGui.SameLine()
    local _,y = ImGui.GetCursorPos()
    ImGui.SetCursorPosY(y-3)
    ImGui.SetCursorPosX(mid_x)
    resultVar = ImGui.InputText(idText, resultVar)
    return resultVar
end

ui.get_next_item_loc = function()
    ImGui.SameLine()
    local x = ImGui.GetCursorPosX()
    if x < 205 then ImGui.SetCursorPosX(205) elseif x < 410 then ImGui.SetCursorPosX(410) end
    local avail = ImGui.GetContentRegionAvail()
    if x >= 410 or avail < 95 then
        ImGui.NewLine()
    end
end

local function draw_assist_tab()
    config.ASSIST = ui.draw_combo_box('Assist', config.ASSIST, common.ASSISTS, true)
    config.AUTOASSISTAT = ui.draw_input_int('Assist %', '##assistat', config.AUTOASSISTAT, 'Percent HP to assist at')
    config.SWITCHWITHMA = ui.draw_check_box('Switch With MA', '##switchwithma', config.SWITCHWITHMA, 'Switch targets with MA')
end

local function draw_camp_tab()
    local current_camp_radius = config.CAMPRADIUS
    config.CAMPRADIUS = ui.draw_input_int('Camp Radius', '##campradius', config.CAMPRADIUS, 'Camp radius to assist within')
    config.CHASETARGET = ui.draw_input_text('Chase Target', '##chasetarget', config.CHASETARGET, 'Chase Target')
    config.CHASEDISTANCE = ui.draw_input_int('Chase Distance', '##chasedist', config.CHASEDISTANCE, 'Distance to follow chase target')
    if current_camp_radius ~= config.CAMPRADIUS then
        camp.set_camp()
    end
end

local function draw_burn_tab()
    config.BURNCOUNT = ui.draw_input_int('Burn Count', '##burncnt', config.BURNCOUNT, 'Trigger burns if this many mobs are on aggro')
    config.BURNPCT = ui.draw_input_int('Burn Percent', '##burnpct', config.BURNPCT, 'Percent health to begin burns')
    config.BURNALWAYS = ui.draw_check_box('Burn Always', '##burnalways', config.BURNALWAYS, 'Always be burning')
    config.BURNALLNAMED = ui.draw_check_box('Burn Named', '##burnnamed', config.BURNALLNAMED, 'Burn all named')
    config.USEGLYPH = ui.draw_check_box('Use Glyph', '##glyph', config.USEGLYPH, 'Use Glyph of Destruction on Burn')
    config.USEINTENSITY = ui.draw_check_box('Use Intensity', '##intensity', config.USEINTENSITY, 'Use Intensity of the Resolute on Burn')
    if class_funcs.draw_burn_tab then class_funcs.draw_burn_tab() end
end

local function draw_pull_tab()
    local current_radius = config.PULLRADIUS
    local current_pullarc = config.PULLARC
    config.PULLRADIUS = ui.draw_input_int('Pull Radius', '##pullrad', config.PULLRADIUS, 'Radius to pull mobs within')
    config.PULLLOW = ui.draw_input_int('Pull ZLow', '##pulllow', config.PULLLOW, 'Z Low pull range')
    config.PULLHIGH = ui.draw_input_int('Pull ZHigh', '##pullhigh', config.PULLHIGH, 'Z High pull range')
    config.PULLMINLEVEL = ui.draw_input_int('Pull Min Level', '##pullminlvl', config.PULLMINLEVEL, 'Minimum level mobs to pull')
    config.PULLMAXLEVEL = ui.draw_input_int('Pull Max Level', '##pullmaxlvl', config.PULLMAXLEVEL, 'Maximum level mobs to pull')
    config.PULLARC = ui.draw_input_int('Pull Arc', '##pullarc', config.PULLARC, 'Only pull from this slice of the radius, centered around your current heading')
    config.GROUPWATCHWHO = ui.draw_combo_box('Group Watch', config.GROUPWATCHWHO, common.GROUP_WATCH_OPTS, true)
    config.MEDMANASTART = ui.draw_input_int('Med Mana Start', '##medmanastart', config.MEDMANASTART, 'Pct Mana to begin medding')
    config.MEDMANASTOP = ui.draw_input_int('Med Mana Stop', '##medmanastop', config.MEDMANASTOP, 'Pct Mana to stop medding')
    config.MEDENDSTART = ui.draw_input_int('Med End Start', '##medendstart', config.MEDENDSTART, 'Pct End to begin medding')
    config.MEDENDSTOP = ui.draw_input_int('Med End Stop', '##medendstop', config.MEDENDSTOP, 'Pct End to stop medding')
    if current_radius ~= config.PULLRADIUS or current_pullarc ~= config.PULLARC then
        camp.set_camp()
    end
end

local function draw_debug_tab()
    if state.debug then
        if ImGui.Button('Disable Debug', 303, 22) then
            state.debug = false
        end
    else
        if ImGui.Button('Enable Debug', 303, 22) then
            state.debug = true
        end
    end
    ImGui.TextColored(1, 1, 0, 1, 'Mode:')
    ImGui.SameLine()
    x,_ = ImGui.GetCursorPos()
    ImGui.SetCursorPosX(100)
    ImGui.TextColored(1, 1, 1, 1, config.MODE:get_name())

    ImGui.TextColored(1, 1, 0, 1, 'Camp:')
    ImGui.SameLine()
    ImGui.SetCursorPosX(100)
    if camp.Active then
        ImGui.TextColored(1, 1, 0, 1, string.format('X: %.02f  Y: %.02f  Z: %.02f', camp.X, camp.Y, camp.Z))
        ImGui.TextColored(1, 1, 0, 1, 'Radius:')
        ImGui.SameLine()
        ImGui.SetCursorPosX(100)    
        ImGui.TextColored(1, 1, 0, 1, string.format('%d', config.CAMPRADIUS))
    else
        ImGui.TextColored(1, 0, 0, 1, '--')
    end

    ImGui.TextColored(1, 1, 0, 1, 'Target:')
    ImGui.SameLine()
    x,_ = ImGui.GetCursorPos()
    ImGui.SetCursorPosX(100)
    ImGui.TextColored(1, 0, 0, 1, string.format('%s', mq.TLO.Target()))

    ImGui.TextColored(1, 1, 0, 1, 'AM_I_DEAD:')
    ImGui.SameLine()
    x,_ = ImGui.GetCursorPos()
    ImGui.SetCursorPosX(100)
    ImGui.TextColored(1, 0, 0, 1, string.format('%s', state.i_am_dead))

    ImGui.TextColored(1, 1, 0, 1, 'Burning:')
    ImGui.SameLine()
    x,_ = ImGui.GetCursorPos()
    ImGui.SetCursorPosX(100)
    ImGui.TextColored(1, 0, 0, 1, string.format('%s', state.burn_active))

    ImGui.TextColored(1, 1, 0, 1, 'tank_mob_id:')
    ImGui.SameLine()
    x,_ = ImGui.GetCursorPos()
    ImGui.SetCursorPosX(100)
    ImGui.TextColored(1, 0, 0, 1, string.format('%s', state.tank_mob_id))

    ImGui.TextColored(1, 1, 0, 1, 'pull_mob_id:')
    ImGui.SameLine()
    x,_ = ImGui.GetCursorPos()
    ImGui.SetCursorPosX(100)
    ImGui.TextColored(1, 0, 0, 1, string.format('%s', state.pull_mob_id))

    ImGui.TextColored(1, 1, 0, 1, 'pull_in_progress:')
    ImGui.SameLine()
    x,_ = ImGui.GetCursorPos()
    ImGui.SetCursorPosX(100)
    ImGui.TextColored(1, 0, 0, 1, string.format('%s', state.pull_in_progress))

    ImGui.TextColored(1, 1, 0, 1, 'mob_count:')
    ImGui.SameLine()
    x,_ = ImGui.GetCursorPos()
    ImGui.SetCursorPosX(100)
    ImGui.TextColored(1, 0, 0, 1, string.format('%s', state.mob_count))
end

local function draw_body()
    if ImGui.BeginTabBar('##tabbar') then
        if ImGui.BeginTabItem('Assist') then
            ImGui.PushItemWidth(item_width)
            draw_assist_tab()
            ImGui.PopItemWidth()
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem('Camp') then
            ImGui.PushItemWidth(item_width)
            draw_camp_tab()
            ImGui.PopItemWidth()
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem('Skills') then
            if ImGui.BeginChild('Skills', ImGui.GetContentRegionAvail(), 150) then
                ImGui.PushItemWidth(item_width-25)
                class_funcs.draw_skills_tab()
                ImGui.PopItemWidth()
            end
            ImGui.EndChild()
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem('Burn') then
            ImGui.PushItemWidth(item_width)
            draw_burn_tab()
            ImGui.PopItemWidth()
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem('Pull') then
            if ImGui.BeginChild('Pull', ImGui.GetContentRegionAvail(), 150) then
                ImGui.PushItemWidth(item_width)
                draw_pull_tab()
                ImGui.PopItemWidth()
            end
            ImGui.EndChild()
            ImGui.EndTabItem()
        end
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
        if ImGui.Button('RESUME', 147, 22) then
            camp.set_camp()
            state.paused = false
        end
    else
        if ImGui.Button('PAUSE', 147, 22) then
            state.paused = true
            state.reset_combat_state()
        end
    end
    ImGui.SameLine()
    if ImGui.Button('Save Settings', 147, 22) then
        class_funcs.save_settings()
    end
    ImGui.Text('Bot Status: ')
    ImGui.SameLine()
    ImGui.SetCursorPosX(159)
    if state.paused then
        ImGui.TextColored(1, 0, 0, 1, 'PAUSED')
    else
        ImGui.TextColored(0, 1, 0, 1, 'RUNNING')
    end

    local current_mode = config.MODE:get_name()
    ImGui.PushItemWidth(item_width)
    config.MODE = mode.from_string(ui.draw_combo_box('Mode', config.MODE:get_name(), mode.mode_names))
    ImGui.PopItemWidth()
    if current_mode ~= config.MODE:get_name() then
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
    local classname = mq.TLO.Me.Class.ShortName()
    open_gui, should_draw_gui = ImGui.Begin(string.format('AQO Bot 1.0 - %s###AQOBOTUI', classname), open_gui, ImGuiWindowFlags.AlwaysAutoResize)
    if should_draw_gui then
        draw_header()
        draw_body()
    end
    ImGui.End()
    pop_styles()
end

return ui