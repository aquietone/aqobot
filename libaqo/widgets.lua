local imgui = require('ImGui')
local icons = require('mq.icons')

---@class widgets
local widgets = {version="0.1",author="aquietone"}

local GREEN = ImVec4(0, 1, 0, 1)
local RED = ImVec4(1, 0, 0, 1)

---Draw a tooltip with the provided text when hovering over the last drawn item
---@param desc string #The tooltip text to display when hovering
function widgets.HelpMarker(desc)
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.PushTextWrapPos(ImGui.GetFontSize() * 35.0)
        imgui.Text(desc)
        imgui.PopTextWrapPos()
        imgui.EndTooltip()
    end
end

---Draw a button with locked or unlocked icon based on locked value
---@param id string #The imgui id text for the button
---@param locked boolean #The current lock value
---@return boolean #The new or unchanged lock value
function widgets.LockButton(id, locked)
    local lockedIcon = locked and icons.FA_LOCK .. '##' .. id or icons.FA_UNLOCK .. '##' .. id
    if imgui.Button(lockedIcon) then
        locked = not locked
    end
    widgets.HelpMarker('Lock or unlock window movement')
    return locked
end

---Draw a combo box with provided options as selectable items
---@param label string #The label for the combo box
---@param resultVar string #The selected value of the combo box
---@param options table #The table of options for the combo box
---@param bykey boolean #Use table keys as options for the combo box when true, otherwise use values
---@param helpText string #The tooltip text to display when hovering
---@param width? number #The item width of the combo box
---@param posX? number #The X cursor position to draw at
---@param posY? number #The Y cursor position to draw at
---@return string #The new or unchanged selected value of the combo box
function widgets.ComboBox(label, resultVar, options, bykey, helpText, width, posX, posY)
    imgui.SetCursorPosX(posX or imgui.GetCursorPosX())
    imgui.SetCursorPosY((posY or imgui.GetCursorPosY()) + 5)
    if width then imgui.SetNextItemWidth(width) end
    if imgui.BeginCombo(label, resultVar) then
        for i,j in pairs(options) do
            if bykey then
                if imgui.Selectable(i, i == resultVar) then
                    resultVar = i
                end
            else
                if imgui.Selectable(j, j == resultVar) then
                    resultVar = j
                end
            end
        end
        imgui.EndCombo()
    end
    widgets.HelpMarker(helpText)
    return resultVar
end

---Draw a combo box with provided options as selectable items and label text on the left hand side
---@param label string #The label for the combo box
---@param id string #The imgui id for the combo box
---@param resultVar string #The selected value of the combo box
---@param options table #The table of options for the combo box
---@param bykey boolean #Use table keys as options for the combo box when true, otherwise use values
---@param helpText string #The tooltip text to display when hovering
---@param width? number #The item width of the combo box
---@param posX? number #The X cursor position to draw at label at
---@param posY? number #The Y cursor position to draw at
---@param posX2? number #The X cursor position to draw at the combo box at
---@return string #The new or unchanged selected value of the combo box
function widgets.ComboBoxLeftText(label, id, resultVar, options, bykey, helpText, width, posX, posY, posX2)
    imgui.SetCursorPosX(posX or imgui.GetCursorPosX())
    imgui.SetCursorPosY((posY or imgui.GetCursorPosY()) + 5)
    imgui.Text(label)
    imgui.SameLine()
    widgets.HelpMarker(helpText)
    imgui.SameLine()
    ImGui.SetCursorPosX((posX or 0) + posX2)
    imgui.SetCursorPosY(imgui.GetCursorPosY()-3)
    if width then imgui.SetNextItemWidth(width) end
    if imgui.BeginCombo('##'..id, resultVar) then
        for i,j in pairs(options) do
            if bykey then
                if imgui.Selectable(i, i == resultVar) then
                    resultVar = i
                end
            else
                if imgui.Selectable(j, j == resultVar) then
                    resultVar = j
                end
            end
        end
        imgui.EndCombo()
    end
    return resultVar
end

---Draw a checkbox
---@param label string #The label for the checkbox
---@param resultVar boolean #The current value of the checkbox
---@param helpText string #The tooltip text to display when hovering
---@param posX? number #The X cursor position to draw at
---@param posY? number #The Y cursor position to draw at
---@return boolean #The new or unchanged value of the checkbox
function widgets.CheckBox(label, resultVar, helpText, posX, posY)
    imgui.SetCursorPosX(posX or imgui.GetCursorPosX())
    imgui.SetCursorPosY((posY or imgui.GetCursorPosY()) + 5)
    if resultVar then imgui.PushStyleColor(ImGuiCol.Text, GREEN) else imgui.PushStyleColor(ImGuiCol.Text, RED) end
    resultVar,_ = imgui.Checkbox(label, resultVar)
    imgui.PopStyleColor(1)
    widgets.HelpMarker(helpText)
    return resultVar
end

---Draw a checkbox with the label text on the left hand side
---@param label string #The label for the checkbox
---@param id string #The imgui id for the checkbox
---@param resultVar boolean #The current value of the checkbox
---@param helpText string #The tooltip text to display when hovering
---@param posX? number #The X cursor position to draw at
---@param posY? number #The Y cursor position to draw at
---@param posX2? number #The X cursor position to draw at the checkbox at
---@return boolean #The new or unchanged value of the checkbox
function widgets.CheckBoxLeftLabel(label, id, resultVar, helpText, posX, posY, posX2)
    imgui.SetCursorPosX(posX or imgui.GetCursorPosX())
    imgui.SetCursorPosY((posY or imgui.GetCursorPosY()) + 5)
    if resultVar then
        imgui.TextColored(GREEN, label)
    else
        imgui.TextColored(RED, label)
    end
    imgui.SameLine()
    widgets.HelpMarker(helpText)
    imgui.SameLine()
    ImGui.SetCursorPosX((posX or 0) + posX2)
    imgui.SetCursorPosY(imgui.GetCursorPosY()-3)
    resultVar,_ = imgui.Checkbox('##'..id, resultVar)
    return resultVar
end

---Draw a slider int
---@param label string #The label for the slider int
---@param resultVar number #The current value of the slider int
---@param helpText string #The tooltip text to display when hovering
---@param minValue number #The minimum value for the int range
---@param maxValue number #The maximum value for the int range
---@param width? number #The item width of the slider int
---@param posX? number #The X cursor position to draw at
---@param posY? number #The Y cursor position to draw at
---@return number #The new or unchanged value of the slider int
function widgets.SliderInt(label, resultVar, helpText, minValue, maxValue, width, posX, posY)
    imgui.SetCursorPosX(posX or imgui.GetCursorPosX())
    imgui.SetCursorPosY((posY or imgui.GetCursorPosY()) + 5)
    if width then imgui.SetNextItemWidth(width) end
    resultVar = imgui.SliderInt(label, resultVar, minValue, maxValue)
    widgets.HelpMarker(helpText)
    return resultVar
end

---Draw a slider int with the label on the left hand side
---@param label string #The label for the slider int
---@param id string #The imgui id for the slider int
---@param resultVar number #The current value of the slider int
---@param helpText string #The tooltip text to display when hovering
---@param minValue number #The minimum value for the int range
---@param maxValue number #The maximum value for the int range
---@param width? number #The item width of the slider int
---@param posX? number #The X cursor position to draw at
---@param posY? number #The Y cursor position to draw at
---@param posX2? number #The X cursor position to draw at the combo box at
---@return number #The new or unchanged value of the slider int
function widgets.SliderIntLeftLabel(label, id, resultVar, helpText, minValue, maxValue, width, posX, posY, posX2)
    imgui.SetCursorPosX(posX or imgui.GetCursorPosX())
    imgui.SetCursorPosY((posY or imgui.GetCursorPosY()) + 5)
    imgui.Text(label)
    imgui.SameLine()
    widgets.HelpMarker(helpText)
    imgui.SameLine()
    ImGui.SetCursorPosX((posX or 0) + posX2)
    imgui.SetCursorPosY(imgui.GetCursorPosY()-3)
    if width then imgui.SetNextItemWidth(width) end
    resultVar = imgui.SliderInt('##'..id, resultVar, minValue, maxValue)
    return resultVar
end

---Draw an input int
---@param label string #The label for the input int
---@param resultVar number #The current value of the input int
---@param helpText string #The tooltip text to display when hovering
---@param width? number #The item width of the input int
---@param posX? number #The X cursor position to draw at
---@param posY? number #The Y cursor position to draw at
---@return number #The new or unchanged value of the input int
function widgets.InputInt(label, resultVar, helpText, width, posX, posY)
    imgui.SetCursorPosX(posX or imgui.GetCursorPosX())
    imgui.SetCursorPosY((posY or imgui.GetCursorPosY()) + 5)
    if width then imgui.SetNextItemWidth(width) end
    resultVar = imgui.InputInt(label, resultVar)
    widgets.HelpMarker(helpText)
    return resultVar
end

---Draw an input int with the label on the left hand side
---@param label string #The label for the input int
---@param id string #The imgui id for the input int
---@param resultVar number #The current value of the input int
---@param helpText string #The tooltip text to display when hovering
---@param width? number #The item width of the input int
---@param posX? number #The X cursor position to draw at
---@param posY? number #The Y cursor position to draw at
---@param posX2? number #The X cursor position to draw at the combo box at
---@return number #The new or unchanged value of the input int
function widgets.InputIntLeftLabel(label, id, resultVar, helpText, width, posX, posY, posX2)
    imgui.SetCursorPosX(posX or imgui.GetCursorPosX())
    imgui.SetCursorPosY((posY or imgui.GetCursorPosY()) + 5)
    imgui.Text(label)
    imgui.SameLine()
    widgets.HelpMarker(helpText)
    imgui.SameLine()
    ImGui.SetCursorPosX((posX or 0) + posX2)
    imgui.SetCursorPosY(imgui.GetCursorPosY()-3)
    if width then imgui.SetNextItemWidth(width) end
    resultVar = imgui.InputInt('##'..id, resultVar)
    return resultVar
end

---Draw an input text
---@param label string #The label for the input text
---@param resultVar string #The current value of the input text
---@param helpText string #The tooltip text to display when hovering
---@param width? number #The item width of the input text
---@param posX? number #The X cursor position to draw at
---@param posY? number #The Y cursor position to draw at
---@return string #The new or unchanged value of the input text
function widgets.InputText(label, resultVar, helpText, width, posX, posY)
    imgui.SetCursorPosX(posX or imgui.GetCursorPosX())
    imgui.SetCursorPosY((posY or imgui.GetCursorPosY()) + 5)
    if width then imgui.SetNextItemWidth(width) end
    resultVar = ImGui.InputText(label, resultVar)
    widgets.HelpMarker(helpText)
    return resultVar
end

---Draw an input text with the label on the left hand side
---@param label string #The label for the input text
---@param id string #The imgui id for the input text
---@param resultVar string #The current value of the input text
---@param helpText string #The tooltip text to display when hovering
---@param width? number #The item width of the input text
---@param posX? number #The X cursor position to draw at
---@param posY? number #The Y cursor position to draw at
---@param posX2? number #The X cursor position to draw at the combo box at
---@return string #The new or unchanged value of the input text
function widgets.InputTextLeftLabel(label, id, resultVar, helpText, width, posX, posY, posX2)
    imgui.SetCursorPosX(posX or imgui.GetCursorPosX())
    imgui.SetCursorPosY((posY or imgui.GetCursorPosY()) + 5)
    imgui.Text(label)
    imgui.SameLine()
    widgets.HelpMarker(helpText)
    imgui.SameLine()
    ImGui.SetCursorPosX((posX or 0) + posX2)
    imgui.SetCursorPosY(imgui.GetCursorPosY()-3)
    if width then imgui.SetNextItemWidth(width) end
    resultVar = imgui.InputText('##'..id, resultVar)
    return resultVar
end

local COMBO_POPUP_FLAGS = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoResize, ImGuiWindowFlags.ChildWindow)
---Draw a combo box with filterable options
---@param label string #The label for the combo
---@param current_value string #The current selected value or filter text for the combo
---@param options table #The selectable options for the combo
---@param width? number #The width to be applied to the text field and popup of the combo
---@return string,boolean #Return the selected value or partial filter text as well as whether the value changed
function widgets.ComboFiltered(label, current_value, options, width)
    if width then ImGui.SetNextItemWidth(width) end
    local result, changed = imgui.InputText(label, current_value, ImGuiInputTextFlags.EnterReturnsTrue)
    local active = imgui.IsItemActive()
    local activated = imgui.IsItemActivated()
    if activated then imgui.OpenPopup('##combopopup'..label) end
    local itemRectMinX, _ = imgui.GetItemRectMin()
    local _, itemRectMaxY = imgui.GetItemRectMax()
    imgui.SetNextWindowPos(itemRectMinX, itemRectMaxY)
    if width then imgui.SetNextWindowSize(ImVec2(width, -1)) end
    if imgui.BeginPopup('##combopopup'..label, COMBO_POPUP_FLAGS) then
        for _,value in ipairs(options) do
            if imgui.Selectable(value) then
                result = value
            end
        end
        if changed or (not active and not imgui.IsWindowFocused()) then
            imgui.CloseCurrentPopup()
        end
        imgui.EndPopup()
    end
    return result, current_value ~= result
end

---Filter values to only include entries with the substring value, for use with ComboFiltered
---@param value any
---@param values any
---@return table #The filtered table of values
function widgets.Filter(value, values)
    if value == "" then return values end
    local filtered = {}
    for i,v in ipairs(values) do
        -- substitute special regex characters in value before calling find
        if v:lower():find(value:lower():gsub('%(.*',''):gsub('%[.*',''):gsub('%%.*','')) then
            table.insert(filtered, v)
        end
    end
    return filtered
end

---Lua port of https://github.com/macroquest/macroquest/blob/90e598564c4d7b0358e8e611c9bf0b01a8eaca6e/src/imgui/ImGuiUtils.cpp#L152
---
---Example: Vertical splitter:
---
---local menuSplitter = splitter:new('menu', 10, false, 75, 200)
---
---    local x,y = ImGui.GetCursorPos()
---    -- draw vertical splitter
---    menuSplitter:draw()
---    ImGui.Text('content left of vertical splitter')
---    ImGui.SetCursorPos(menuSplitter.offset + menuSplitter.thickness + 5, y)
---    ImGui.Text('content right of vertical splitter')
---
---Example: Horizontal splitter:
---
---local headerSplitter = splitter:new('header', 10, true, 75, 200)
---
---    local x,y = ImGui.GetCursorPos()
---    -- draw vertical splitter
---    headerSplitter:draw(true)
---    ImGui.Text('content above horizontal splitter')
---    ImGui.SetCursorPos(x, headerSplitter.offset + headerSplitter.thickness + 30)
---    ImGui.Text('content below horizontal splitter')
---@class splitter
---@field ID string # Unique ID for the splitter
---@field thickness number # The width or height of the splitter
---@field horizontal boolean # Whether the splitter is horizontal or not
---@field min_size number # The minimum x or y offset the splitter can be dragged to
---@field max_size number # The maximum x or y offset the splitter can be dragged to
---@field offset number # The current x or y offset of the splitter
---@field tmp_offset number # The temporary x or y offset as the splitter is being dragged
widgets.splitter = {}

---Create a new splitter instance
---@param ID string # Unique ID for the splitter
---@param thickness number # The width or height of the splitter
---@param horizontal boolean # Whether the splitter is horizontal or not
---@param min_size number # The minimum x or y offset the splitter can be dragged to
---@param max_size number # The maximum x or y offset the splitter can be dragged to
function widgets.splitter:new(ID, thickness, horizontal, min_size, max_size)
    local s = {
        ID = ID or '',
        thickness = thickness or 10,
        horizontal = horizontal or false,
        min_size = min_size or 75,
        max_size = max_size or 200,
        offset = max_size or 200,
        tmp_offset = max_size or 200
    }
    setmetatable(s, self)
    self.__index = self
    return s
end

---Draws the splitter bar as a button which can be dragged within the defined min and max offsets
function widgets.splitter:draw()
    local x,y = imgui.GetCursorPos()
    if self.horizontal then
        imgui.SetCursorPosY(y + self.offset)
    else
        imgui.SetCursorPosX(x + self.offset)
    end

    imgui.PushStyleColor(ImGuiCol.Button, 0, 0, 0, .7)
    imgui.PushStyleColor(ImGuiCol.ButtonActive, 0, 0, 0, .7)
    imgui.PushStyleColor(ImGuiCol.ButtonHovered, 0.6, 0.6, 0.6, 0.5)
    if self.horizontal then
        imgui.Button('##splitter'..self.ID, -1, self.thickness)
    else
        imgui.Button('##splitter'..self.ID, self.thickness, -1)
    end
    imgui.PopStyleColor(3)

    imgui.SetItemAllowOverlap()

    if imgui.IsItemActive() then
        local dragDelta = imgui.GetMouseDragDelta()
        local delta = self.horizontal and dragDelta.y or dragDelta.x

        if delta < self.min_size - self.offset then
            delta = self.min_size - self.offset
        end
        if delta > self.max_size - self.offset then
            delta = self.max_size - self.offset
        end

        self.tmp_offset = self.offset + delta
    else
        self.offset = self.tmp_offset
    end
    imgui.SetCursorPosX(x)
    imgui.SetCursorPosY(y)
end

return widgets

-- Example usage of all widgets
--[[
local mq = require 'mq'

local open, show = true, true
local comboByKey = {key1=true,key2=true,key3=true}
local comboByKeySetting = 'key1'
local comboByValue = {'value1','value2','value3'}
local comboByValueSetting = 'value1'
local locked = true
local checkbox1, checkbox2 = false, false
local inputintVal, leftinputintVal = 0, 0
local sliderintVal, leftsliderinvVal = 50, 15
local inputtextVal, leftinputtextVal = '', ''
local headerSplitter = widgets.splitter:new('header', 10, true, 75, 125)
local sideNavSplitter = widgets.splitter:new('sidenav', 10, false, 75, 125)

local function widgettest()
    if not open then return end
    open, show = imgui.Begin('widgettest', open)
    if show then
        local x = ImGui.GetCursorPosX()
        headerSplitter:draw(true)
        ImGui.Text('header area')
        ImGui.SetCursorPos(x, headerSplitter.offset + headerSplitter.thickness + 30)
        if ImGui.BeginChild('belowsplitter') then
            local y = ImGui.GetCursorPosY()
            sideNavSplitter:draw(true)
            ImGui.Text('left side nav')
            ImGui.SetCursorPos(sideNavSplitter.offset + sideNavSplitter.thickness + 10, y)
            if imgui.BeginChild('rightside') then
                locked = widgets.LockButton('lockbutton', locked)

                checkbox1 = widgets.CheckBox('checkbox', checkbox1, 'this is checkbox1')
                checkbox2 = widgets.CheckBoxLeftLabel('leftcheckbox', 'checkbox2', checkbox2, 'this is leftcheckbox')

                comboByKeySetting = widgets.ComboBox('comboByKey', comboByKeySetting, comboByKey, true, 'this is comboByKey', 150)
                comboByValueSetting = widgets.ComboBoxLeftText('comboByValue', 'comboByValue', comboByValueSetting, comboByValue, false, 'this is comboByValue', 150)

                inputintVal = widgets.InputInt('inputint', inputintVal, 'this is inputint', 150)
                leftinputintVal = widgets.InputIntLeftLabel('leftinputint', 'leftinputint', leftinputintVal, 'this is leftinputint', 150)

                sliderintVal = widgets.SliderInt('sliderint', sliderintVal, 'this is sliderint', 0, 100, 150)
                leftsliderinvVal = widgets.SliderIntLeftLabel('sliderint', 'sliderint', leftsliderinvVal, 'this is leftsliderint', 10, 20, 150)

                inputtextVal = widgets.InputText('inputtext', inputtextVal, 'this is inputtext', 150)
                leftinputtextVal = widgets.InputTextLeftLabel('leftinputtext', 'leftinputtext', leftinputtextVal, 'this is leftinputtext', 150)
            end
            ImGui.EndChild()
        end
        ImGui.EndChild()
    end
    imgui.End()
end

mq.imgui.init('widgettest', widgettest)
while open do
    mq.delay(1000)
end
]]