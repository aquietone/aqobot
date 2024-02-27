local mq = require('mq')
local imgui = require('ImGui')

local CustomAbilityUI = {
    open = false,
    show = false,
    selectedAbilityIdx = 0,
    selectedOptionIdx = 0,
    showView = true,
    showEdit = false,
    currentTab = 'Options',
}

local AbilityInput
local OptionInput

function CustomAbilityUI:render(class)
    if imgui.BeginTabBar('CustomOptsAbilities') then
        if imgui.BeginTabItem('Options') then
            if self.currentTab ~= 'Options' then
                self.currentTab = 'Options'
                self.selectedAbilityIdx = 0
                self.selectedOptionIdx = 0
                self.showView = false
                self.showEdit = false
            end
            if imgui.Button('Add') then
                self.showEdit, self.showView = true, false
                self.selectedOptionIdx = 0
                self:resetOptionInput()
            end
            imgui.SameLine()
            if imgui.Button('Remove') and self.selectedOptionIdx > 0 then
                
            end
            imgui.SameLine()
            if imgui.Button('Edit') and self.selectedOptionIdx > 0 then
                self.showEdit, self.showView = true, false
                local option = class.customOptions[self.selectedOptionIdx]
                self:toOptionInput(option)
            end
            imgui.Separator()
            if imgui.BeginListBox('##CustomOptionList', ImVec2(130, -1)) then
                for i,option in ipairs(class.customOptions) do
                    if imgui.Selectable(option.Key, self.selectedOptionIdx == i) then
                        if  self.selectedOptionIdx ~= i then
                            self.showEdit, self.showView = false, true
                            self.selectedOptionIdx = i
                        end
                    end
                end
                imgui.EndListBox()
            end
            imgui.SameLine()
            if self.selectedOptionIdx > 0 then
                if self.showView then
                    self:renderOptionViewer(class)
                elseif self.showEdit then
                    self:renderOptionEditor(class)
                end
            elseif self.showEdit then
                self:renderOptionEditor(class)
            end
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem('Abilities') then
            if self.currentTab ~= 'Abilities' then
                self.currentTab = 'Abilities'
                self.selectedAbilityIdx = 0
                self.selectedOptionIdx = 0
                self.showView = false
                self.showEdit = false
            end
            if imgui.Button('Add') then
                self.showEdit, self.showView = true, false
                self.selectedAbilityIdx = 0
                self:resetAbilityInput()
            end
            imgui.SameLine()
            if imgui.Button('Remove') and self.selectedAbilityIdx > 0 then
                
            end
            imgui.SameLine()
            if imgui.Button('Edit') and self.selectedAbilityIdx > 0 then
                self.showEdit, self.showView = true, false
                local ability = class.customAbilities[self.selectedAbilityIdx]
                self:toAbilityInput(ability)
            end
            imgui.Separator()
            if imgui.BeginListBox('##CustomAbilityList', ImVec2(130, -1)) then
                for i,ability in ipairs(class.customAbilities) do
                    if imgui.Selectable(ability.Group or ability.Key or ability.Name, self.selectedAbilityIdx == i) then
                        if  self.selectedAbilityIdx ~= i then
                            self.showEdit, self.showView = false, true
                            self.selectedAbilityIdx = i
                        end
                    end
                end
                imgui.EndListBox()
            end
            imgui.SameLine()
            if self.selectedAbilityIdx > 0 then
                if self.showView then
                    self:renderAbilityViewer(class)
                elseif self.showEdit then
                    self:renderAbilityEditor(class)
                end
            elseif self.showEdit then
                self:renderAbilityEditor(class)
            end
            imgui.EndTabItem()
        end
        imgui.EndTabBar()
    end
end

local abilityLists = {'dps', 'aedps', 'tanking', 'aetank', 'heal', 'burn', 'tankburn', 'first', 'second', 'third', 'selfbuff', 'singlebuff', 'aurabuff', 'petbuff', 'combatbuff', 'recover', 'cure', 'debuff'}
local flags = {
    {'aggro', 'threshold'},
    {'combat', 'ooc', 'minhp', 'mana', 'endurance'},
    {'pet', 'self', 'regular', 'panic', 'group'},
    {'classes', 'CheckFor', 'skipifbuff', 'usebelowpct', 'maxdistance', 'tot', 'nodmz', 'summonMinimum'}
}
local actions = {
    'precast', 'postcast', 'RemoveBuff', 'stand', 'swap',
}
function CustomAbilityUI:renderAbilityViewer(class)
    local ability = class.customAbilities[self.selectedAbilityIdx]
    if imgui.BeginChild('abilityviewer', ImVec2(-1,-1), ImGuiChildFlags.Border, ImGuiChildFlags.None) then
        if ability.Options.CastType == 'Spell' then
            CustomAbilityUI:renderSpellHeader(ability)
        elseif ability.Options.CastType == 'AA' then
            CustomAbilityUI:renderAAHeader(ability)
        elseif ability.Options.CastType == 'Disc' then
            CustomAbilityUI:renderDiscHeader(ability)
        -- Item, Skill
        end
        imgui.Separator()
        if imgui.CollapsingHeader('Ability Lists') then
            local idx = 1
            for i,listName in ipairs(abilityLists) do
                if ability.Options[listName] then
                    imgui.Text('%s: %s', idx, listName)
                    idx = idx + 1
                end
            end
        end
        if imgui.CollapsingHeader('When to use') then
            if ability.Options.opt then
                imgui.Text('Option: %s', ability.Options.opt)
                imgui.Separator()
            end
            if ability.Options.conditionstring then
                imgui.Text('Condition: %s', ability.Options.conditionstring)
                imgui.Separator()
            end
            for i,flagGroup in ipairs(flags) do
                local idx = 1
                for _,flagName in ipairs(flagGroup) do
                    if ability.Options[flagName] then
                        if type(ability.Options[flagName]) == 'boolean' then
                            imgui.Text('%s: %s', idx, flagName)
                        else
                            imgui.Text('%s: %s = %s', idx, flagName, ability.Options[flagName])
                        end
                        idx = idx + 1
                    end
                end
                if idx > 1 and i < #flags then imgui.Separator() end
            end

        end
        if imgui.CollapsingHeader('Actions') then
            for _,action in ipairs(actions) do
                if ability.Options[action] then
                    imgui.Text('%s: %s', ability.Options[action])
                end
            end
        end
    end
    imgui.EndChild()
end

function CustomAbilityUI:renderSpellHeader(ability)
    imgui.Text('Group: %s', ability.Group)
    ImGui.Text('Type: %s', ability.Options.CastType)
    for i,spellName in ipairs(ability.Spells) do
        imgui.Text('%s: %s', i, spellName)
    end
end

function CustomAbilityUI:renderAAHeader(ability)
    imgui.Text('Name: %s', ability.Name)
    ImGui.Text('Type: %s', ability.Options.CastType)
end

function CustomAbilityUI:renderDiscHeader(ability)
    imgui.Text('Group: %s', ability.Group)
    ImGui.Text('Type: %s', ability.Options.CastType)
    for i,discName in ipairs(ability.Names) do
        imgui.Text('%s: %s', i, discName)
    end
end

function CustomAbilityUI:renderAbilityEditor(class)
    if imgui.BeginChild('abilityeditor', ImVec2(-1,-1), ImGuiChildFlags.Border, ImGuiChildFlags.None) then
        AbilityInput.CastType = imgui.Combo('CastType', AbilityInput.CastType, 'Spell\0AA\0Disc\0Item\0Skill\0')
        if AbilityInput.CastType == 1 or AbilityInput.CastType == 3 then
            AbilityInput.Group = imgui.InputText('Group', AbilityInput.Group)
            if AbilityInput.CastType == 1 then
                -- add Spells
            else
                -- add Names
            end
        elseif AbilityInput.CastType == 2 then
            AbilityInput.Key = imgui.InputText('Key', AbilityInput.Key)
        else
            AbilityInput.Name = imgui.InputText('Name', AbilityInput.Name)
        end
        imgui.Separator()
        if imgui.CollapsingHeader('Ability Lists') then
            local idx = 1
            for i,listName in ipairs(abilityLists) do
                if AbilityInput.Options[listName] then
                    AbilityInput.Options[listName] = imgui.Checkbox(listName, AbilityInput.Options[listName])
                    idx = idx + 1
                end
            end
        end
        if imgui.CollapsingHeader('When to use') then
            if AbilityInput.Options.opt then
                AbilityInput.Options.opt = imgui.InputText('Option', AbilityInput.Options.opt)
                imgui.Separator()
            end
            -- if ability.Options.conditionstring then
            --     imgui.Text('Condition: %s', ability.Options.conditionstring)
            --     imgui.Separator()
            -- end
            -- local idx = 1
            -- for i,flagName in ipairs(aeFlags) do
            --     if ability.Options[flagName] then
            --         imgui.Text('%s: %s', idx, flagName)
            --         idx = idx + 1
            --     end
            -- end
            -- if idx > 1 then imgui.Separator() end
            -- idx = 1
            -- for i,flagName in ipairs(recoverFlags) do
            --     if ability.Options[flagName] then
            --         imgui.Text('%s: %s', idx, flagName)
            --         idx = idx + 1
            --     end
            -- end
            -- if idx > 1 then imgui.Separator() end
            -- idx = 1
            -- for i,flagName in ipairs(healFlags) do
            --     if ability.Options[flagName] then
            --         imgui.Text('%s: %s', idx, flagName)
            --         idx = idx + 1
            --     end
            -- end
            -- if idx > 1 then imgui.Separator() end
            -- idx = 1
            -- for i,flagName in ipairs(otherFlags) do
            --     if ability.Options[flagName] then
            --         if idx == 1 then imgui.Separator() end
            --         imgui.Text('%s: %s', idx, flagName)
            --         idx = idx + 1
            --     end
            -- end
        end
        -- if imgui.CollapsingHeader('Actions') then
        --     if ability.Options.precast then
        --         imgui.Text('precast: %s', ability.Options.precast)
        --     end
        --     if ability.Options.postcast then
        --         imgui.Text('postcast: %s', ability.Options.postcast)
        --     end
        --     if ability.Options.RemoveBuff then
        --         imgui.Text('RemoveBuff: %s', ability.Options.RemoveBuff)
        --     end
        --     if ability.Options.stand then
        --         imgui.Text('stand: %s', ability.Options.stand)
        --     end
        --     if ability.Options.swap then
        --         imgui.Text('swap: %s', ability.Options.swap)
        --     end
        -- end
    end
    imgui.EndChild()
end

function CustomAbilityUI:toAbilityInput(ability)
    self:resetAbilityInput()
    AbilityInput.CastType = (ability.Options.CastType == 'Spell' and 1) or (ability.Options.CastType == 'AA' and 2) or (ability.Options.CastType == 'Disc' and 3) or (ability.Options.CastType == 'Item' and 4) or (ability.Options.CastType == 'Skill' and 5)
    AbilityInput.Name = ability.Name
    AbilityInput.Group = ability.Group
    AbilityInput.Key = ability.Options.Key
    for k,v in pairs(ability.Options) do
        AbilityInput.Options[k] = v
    end
end

function CustomAbilityUI:toAbility(abilityInput)
    -- common.getBestSpell(spells, options, spellGroup)
    -- common.getAA(name, options)
    -- common.getBestDisc(discs, options)
    -- common.getItem(name, options)
    -- common.getSkill(name, options)
end

function CustomAbilityUI:resetAbilityInput()
    AbilityInput = {
        Name = '',
        CastType = 1,
        Group = '',
        Key = '',
        Options={},
        threshold = 0,
        pet = 0,
        CheckFor = '',
        skipifbuff = '',
        usebelowpct = 0,
        maxdistance = 0,
        summonMinimum = 0,
        minhp = 0,
    }
end

function CustomAbilityUI:renderOptionViewer(class)
    local option = class.customOptions[self.selectedOptionIdx]
    if imgui.BeginChild('optionviewer', ImVec2(-1,-1), ImGuiChildFlags.Border, ImGuiChildFlags.None) then
        imgui.Text('Key: %s', option.Key)
        imgui.Text('Label: %s', option.Label)
        imgui.Text('Default: %s', option.Default)
        if option.Options then
            imgui.Text('Options:')
            for i,opt in ipairs(option.Options) do
                imgui.Text('%s: %s', i, opt)
            end
        else
            imgui.Text('Options: None')
        end
        imgui.Text('InputType: %s', option.InputType)
        imgui.Text('Tooltip: %s', option.Tooltip)
        imgui.Text('InverseOption: %s', option.InverseOption)
        imgui.Text('TLO: %s', option.TLO)
        imgui.Text('TLOType: %s', option.TLOType)
    end
    imgui.EndChild()
end

function CustomAbilityUI:renderOptionEditor(class)
    if imgui.BeginChild('optioneditor', ImVec2(-1,-1), ImGuiChildFlags.Border, ImGuiChildFlags.None) then
        OptionInput.Key = imgui.InputText('Key', OptionInput.Key)
        OptionInput.Label = imgui.InputText('Label', OptionInput.Label)
        OptionInput.Default = imgui.InputText('Default',OptionInput.Default)
        --imgui.Text('Options: %s', option.)
        -- if option.Options then
        --     imgui.Text('Options:')
        --     for i,opt in ipairs(option.Options) do
        --         imgui.Text('%s: %s', i, opt)
        --     end
        -- else
        --     imgui.Text('Options: None')
        -- end
        OptionInput.InputType = imgui.Combo('InputType', OptionInput.InputType, 'checkbox\0inputint\0inputtext\0')
        OptionInput.Tooltip = imgui.InputText('Tooltip', OptionInput.Tooltip)
        OptionInput.InverseOption = imgui.InputText('InverseOption', OptionInput.InverseOption)
        OptionInput.TLO = imgui.InputText('TLO', OptionInput.TLO)
        OptionInput.TLOType = imgui.Combo('TLOType', OptionInput.TLOType, 'bool\0int\0string\0')
    end
    imgui.EndChild()
end

function CustomAbilityUI:toOptionInput(option)
    OptionInput = {
        Key = option.Key,
        Label = option.Label,
        Default = option.Default,
        Tooltip = option.Tooltip,
        InverseOption = option.InverseOption,
        TLO = option.TLO,
    }
    if option.options then
        for _,opt in ipairs(option.options) do
            OptionInput.Options = OptionInput.Options or {}
            table.insert(OptionInput.Options, opt)
        end
    end
    OptionInput.InputType = (option.InputType == 'checkbox' and 1) or (option.OptionType == 'inputint' and 2) or (option.OptionType == 'inputtext' and 3)
    OptionInput.TLOType = (option.TLOType == 'bool' and 1) or (option.OptionType == 'int' and 2) or (option.OptionType == 'string' and 3)
end

function CustomAbilityUI:toOption(optionInput)

end

function CustomAbilityUI:resetOptionInput()
    OptionInput = {
        Key = '',
        Label = '',
        Default = nil,
        Options = nil,
        Tooltip = '',
        InputType = 1,
        InverseOption = nil,
        TLO = '',
        TLOType = 1,
    }
end

return CustomAbilityUI