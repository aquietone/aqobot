--- @type mq
local mq = require('mq')
--- @type ImGui
require 'ImGui'

local camp = require('aqo.routines.camp')
local config = require('aqo.configuration')
local state = require('aqo.state')

-- GUI Control variables
local open_gui = true
local should_draw_gui = true

local base_left_pane_size = 190
local left_pane_size = 190

-- icons for the checkboxes
--local checked = mq.FindTextureAnimation('A_TransparentCheckBoxPressed')
--local not_checked = mq.FindTextureAnimation('A_TransparentCheckBoxNormal')

local class_funcs
local ui = {}

ui.set_class_funcs = function(funcs)
    class_funcs = funcs
end

ui.toggle_gui = function(open)
    open_gui = open
end

local function draw_splitter(thickness, size0, min_size0)
    local x,y = ImGui.GetCursorPos()
    local delta = 0
    ImGui.SetCursorPosX(x + size0)

    ImGui.PushStyleColor(ImGuiCol.Button, 0, 0, 0, 0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0, 0, 0, 0)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.6, 0.6, 0.6, 0.1)
    ImGui.Button('##splitter', thickness, -1)
    ImGui.PopStyleColor(3)

    ImGui.SetItemAllowOverlap()

    if ImGui.IsItemActive() then
        delta,_ = ImGui.GetMouseDragDelta()

        if delta < min_size0 - size0 then
            delta = min_size0 - size0
        end
        if delta > 275 - size0 then
            delta = 275 - size0
        end

        size0 = size0 + delta
        left_pane_size = size0
    else
        base_left_pane_size = left_pane_size
    end
    ImGui.SetCursorPosX(x)
    ImGui.SetCursorPosY(y)
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
    ImGui.Text(label)
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
    resultVar,_ = ImGui.Checkbox(idText, resultVar)
    ImGui.SameLine()
    if resultVar then
        --ImGui.DrawTextureAnimation(checked, 15, 15)
        --if ImGui.IsItemHovered() and ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
        --    print('clicked checkbox')
        --    resultVar = not resultVar
        --end
        --ImGui.SameLine()
        ImGui.TextColored(0, 1, 0, 1, labelText)
    else
        --ImGui.DrawTextureAnimation(not_checked, 15, 15)
        --if ImGui.IsItemHovered() and ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
        --    print('clicked checkbox')
        --    resultVar = not resultVar
        --end
        --ImGui.SameLine()
        ImGui.TextColored(1, 0, 0, 1, labelText)
    end
    ImGui.SameLine()
    help_marker(helpText)
    return resultVar
end

ui.draw_input_int = function(labelText, idText, resultVar, helpText)
    ImGui.Text(labelText)
    ImGui.SameLine()
    help_marker(helpText)
    resultVar = ImGui.InputInt(idText, resultVar)
    return resultVar
end

ui.draw_input_int_sameline = function(labelText, idText, xoffset, resultVar, helpText)
    ImGui.Text(labelText)
    ImGui.SameLine()
    help_marker(helpText)
    ImGui.SameLine()
    ImGui.SetCursorPosX(xoffset)
    resultVar = ImGui.InputInt(idText, resultVar)
    return resultVar
end

ui.draw_input_text = function(labelText, idText, resultVar, helpText)
    ImGui.Text(labelText)
    ImGui.SameLine()
    help_marker(helpText)
    resultVar = ImGui.InputText(idText, resultVar)
    return resultVar
end

local function draw_left_pane_window()
    local _,y = ImGui.GetContentRegionAvail()
    if ImGui.BeginChild("left", left_pane_size, y-1, true) then
        class_funcs.draw_left_panel()
    end
    ImGui.EndChild()
end

local function draw_right_pane_window()
    local x,y = ImGui.GetContentRegionAvail()
    if ImGui.BeginChild("right", x, y-1, true) then
        class_funcs.draw_right_panel()
    end
    ImGui.EndChild()
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

ui.draw_pull_tab = function()
    local current_radius = config.get_pull_radius()
    local current_pullarc = config.get_pull_arc()
    ImGui.PushItemWidth(150)
    config.set_pull_radius(ui.draw_input_int_sameline('Pull Radius', '##pullrad', 200, config.get_pull_radius(), 'Radius to pull mobs within'))
    config.set_pull_min_level(ui.draw_input_int_sameline('Pull Min Level', '##pullminlvl', 200, config.get_pull_min_level(), 'Minimum level mobs to pull'))
    config.set_pull_z_high(ui.draw_input_int_sameline('Pull ZHigh', '##pullhigh', 200, config.get_pull_z_high(), 'Z High pull range'))
    config.set_pull_max_level(ui.draw_input_int_sameline('Pull Max Level', '##pullmaxlvl', 200, config.get_pull_max_level(), 'Maximum level mobs to pull'))
    config.set_pull_z_low(ui.draw_input_int_sameline('Pull ZLow', '##pulllow', 200, config.get_pull_z_low(), 'Z Low pull range'))
    config.set_pull_arc(ui.draw_input_int_sameline('Pull Arc', '##pullarc', 200, config.get_pull_arc(), 'Only pull from this slice of the radius, centered around your current heading'))
    ImGui.PopItemWidth()
    if current_radius ~= config.get_pull_radius() or current_pullarc ~= config.get_pull_arc() then
        camp.set_camp()
    end
end

-- ImGui main function for rendering the UI window
ui.main = function()
    if not open_gui then return end
    open_gui, should_draw_gui = ImGui.Begin('AQO Bot 1.0', open_gui)
    if should_draw_gui then
        if ImGui.GetWindowHeight() == 500 and ImGui.GetWindowWidth() == 500 then
            ImGui.SetWindowSize(400, 200)
        end
        if state.get_paused() then
            if ImGui.Button('RESUME') then
                camp.set_camp()
                state.set_paused(false)
            end
        else
            if ImGui.Button('PAUSE') then
                state.set_paused(true)
            end
        end
        ImGui.SameLine()
        if ImGui.Button('Save Settings') then
            class_funcs.save_settings()
        end
        ImGui.SameLine()
        if state.get_debug() then
            if ImGui.Button('Debug OFF') then
                state.set_debug(false)
            end
        else
            if ImGui.Button('Debug ON') then
                state.set_debug(true)
            end
        end
        if ImGui.BeginTabBar('##tabbar') then
            if ImGui.BeginTabItem('Settings') then
                draw_splitter(8, base_left_pane_size, 190)
                ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 6, 6)
                draw_left_pane_window()
                ImGui.PopStyleVar()
                ImGui.SameLine()
                ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 6, 6)
                draw_right_pane_window()
                ImGui.PopStyleVar()
                ImGui.EndTabItem()
            end
            if config.get_mode():is_pull_mode() then
                if ImGui.BeginTabItem('Pulling') then
                    ui.draw_pull_tab()
                    ImGui.EndTabItem()
                end
            end
            if ImGui.BeginTabItem('Status') then
                ImGui.TextColored(1, 1, 0, 1, 'Status:')
                ImGui.SameLine()
                local x,_ = ImGui.GetCursorPos()
                ImGui.SetCursorPosX(90)
                if state.get_paused() then
                    ImGui.TextColored(1, 0, 0, 1, 'PAUSED')
                else
                    ImGui.TextColored(0, 1, 0, 1, 'RUNNING')
                end
                ImGui.TextColored(1, 1, 0, 1, 'Mode:')
                ImGui.SameLine()
                x,_ = ImGui.GetCursorPos()
                ImGui.SetCursorPosX(90)
                ImGui.TextColored(1, 1, 1, 1, config.get_mode():get_name())

                ImGui.TextColored(1, 1, 0, 1, 'Camp:')
                ImGui.SameLine()
                x,_ = ImGui.GetCursorPos()
                ImGui.SetCursorPosX(90)
                local camp = state.get_camp()
                if camp then
                    ImGui.TextColored(1, 1, 0, 1, string.format('X: %.02f  Y: %.02f  Z: %.02f  Rad: %d', camp.X, camp.Y, camp.Z, config.get_camp_radius()))
                else
                    ImGui.TextColored(1, 0, 0, 1, '--')
                end

                ImGui.TextColored(1, 1, 0, 1, 'Target:')
                ImGui.SameLine()
                x,_ = ImGui.GetCursorPos()
                ImGui.SetCursorPosX(90)
                ImGui.TextColored(1, 0, 0, 1, string.format('%s', mq.TLO.Target()))

                ImGui.TextColored(1, 1, 0, 1, 'AM_I_DEAD:')
                ImGui.SameLine()
                x,_ = ImGui.GetCursorPos()
                ImGui.SetCursorPosX(90)
                ImGui.TextColored(1, 0, 0, 1, string.format('%s', state.get_i_am_dead()))

                ImGui.TextColored(1, 1, 0, 1, 'Burning:')
                ImGui.SameLine()
                x,_ = ImGui.GetCursorPos()
                ImGui.SetCursorPosX(90)
                ImGui.TextColored(1, 0, 0, 1, string.format('%s', state.get_burn_active()))
                ImGui.EndTabItem()
            end
        end
        ImGui.EndTabBar()
    end
    ImGui.End()
end

return ui