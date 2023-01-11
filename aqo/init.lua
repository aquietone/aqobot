--- @type Mq
local mq = require('mq')

local assist = require('routines.assist')
local camp = require('routines.camp')
local movement = require('routines.movement')
local logger = require('utils.logger')
local loot = require('utils.lootutils')
local common = require('common')
local config = require('configuration')
local mode = require('mode')
local state = require('state')
local ui = require('ui')
local aqoclass

--- The plugin table factory will instantiate a plugin object that is used to
--- define all the functionality of the plugin. A name and version is supplied
--- to the factory function and both are required strings.
---@class Plugin
---@field public name string the name of the plugin, specified in this factory
---@field public version string the version of the plugin, specified in this factory
---@field public addcommand fun(self:Plugin, command:string, func:fun(line:string))
---@field public removecommand fun(self:Plugin, command:string):boolean
---@field public addtype fun(self:Plugin, type:string, definition:table)
---@field public removetype fun(self:Plugin, type:string)
---@field public addtlo fun(self:Plugin, tlo:string, func:fun(index:string):any)
---@field public removetlo fun(self:Plugin, tlo:string):boolean
local plugin = mq.plugin("aqo", "1.0")

--plugin.is_open = true
--plugin.paused = true
plugin.suspended = false

---Check if the current game state is not INGAME, and exit the script if it is.
local function check_game_state()
    if mq.TLO.MacroQuest.GameState() ~= 'INGAME' then
        printf(logger.logLine('Not in game, stopping aqo.'))
        mq.exit()
    end
    state.loop = {
        PctHPs = mq.TLO.Me.PctHPs(),
        PctMana = mq.TLO.Me.PctMana(),
        PctEndurance = mq.TLO.Me.PctEndurance(),
        ID = mq.TLO.Me.ID(),
        Invis = mq.TLO.Me.Invis(),
        PetName = mq.TLO.Me.Pet.CleanName(),
        TargetID = mq.TLO.Target.ID(),
        TargetHP = mq.TLO.Target.PctHPs(),
    }
end

---Display help information for the script.
local function show_help()
    local output = logger.logLine('AQO Bot 1.0\n')
    --print(logger.logLine(('Commands:\n- /cls help\n- /cls burnnow\n- /cls pause on|1|off|0\n- /cls show|hide\n- /cls mode 0|manual|1|assist|2|chase|3|vorpal|4|tank|5|pullertank|6|puller|7|huntertank\n- /cls resetcamp'):gsub('cls', state.class)))
    output = output .. ('\ayCommands:\aw\n- /cls help\n- /cls burnnow\n- /cls pause on|1|off|0\n- /cls show|hide\n- /cls mode 0|manual|1|assist|2|chase|3|vorpal|4|tank|5|pullertank|6|puller|7|huntertank\n- /cls resetcamp'):gsub('cls', state.class)
    output = output .. ('\n- /%s addclicky <mash|burn|buff|heal> -- Adds the currently held item to the clicky group specified'):format(state.class)
    output = output .. ('\n- /%s removeclicky -- Removes the currently held item from clickies'):format(state.class)
    output = output .. ('\n- /%s ignore -- Adds the targeted mob to the ignore list for the current zone'):format(state.class)
    output = output .. ('\n- /%s unignore -- Removes the targeted mob from the ignore list for the current zone'):format(state.class)
    output = output .. ('\n- /%s sell -- Sells items marked to be sold to the targeted or already opened vendor'):format(state.class)
    output = output .. ('\n- /%s update -- Downloads the latest source zip'):format(state.class)
    output = output .. ('\n- /%s docs -- Launches the documentation site in a browser window'):format(state.class)
    local prefix = '\n- /'..state.class..' '
    output = output .. '\n\ayGeneric Configuration\aw'
    for key,value in pairs(config) do
        local valueType = type(value)
        if valueType == 'string' or valueType == 'number' or valueType == 'boolean' then
            output = output .. prefix .. key .. ' <' .. valueType .. '> -- '..config.tips[key]
        end
    end
    output = output .. '\n\ayClass Configuration\aw'
    for key,value in pairs(aqoclass.OPTS) do
        local valueType = type(value.value)
        if valueType == 'string' or valueType == 'number' or valueType == 'boolean' then
            output = output .. prefix .. key .. ' <' .. valueType .. '>'--' -- '..value.tip
            if value.tip then output = output .. ' -- '..value.tip end
        end
    end
    output = output .. '\n\ayGear Check:\aw /tell <name> gear <slotname> -- Slot Names: earrings, rings, leftear, rightear, leftfinger, rightfinger, face, head, neck, shoulder, chest, feet, arms, leftwrist, rightwrist, wrists, charm, powersource, mainhand, offhand, ranged, ammo, legs, waist, hands'
    output = output .. '\n\ayBuff Begging:\aw /tell <name> <alias> -- Aliases: '
    for alias,_ in pairs(aqoclass.requestAliases) do
        output = output .. alias .. ', '
    end
    output = output .. '\ax'
    print(output)
end

---Process binding commands.
---@vararg string @The input given to the bind command.
function plugin:aqocmd(line)
    local args = {}
    for arg in line:gmatch("%w+") do table.insert(args, arg) end
    if not args[1] then
        show_help()
        return
    end

    local opt = args[1]:lower()
    local new_value = args[2] and args[2]:lower() or nil
    if opt == 'help' then
        show_help()
    elseif opt == 'restart' then
        mq.cmd('/multiline ; /lua stop aqo ; /timed 5 /lua run aqo')
    elseif opt == 'debug' then
        local section = args[2]
        local subsection = args[3]
        if logger.log_flags[section] and logger.log_flags[section][subsection] ~= nil then
            logger.log_flags[section][subsection] = not logger.log_flags[section][subsection]
        end
    elseif opt == 'sell' and not new_value then
        loot.sellStuff()
    elseif opt == 'bank' and not new_value then
        loot.bankStuff()
    elseif opt == 'burnnow' then
        state.burn_now = true
        if new_value == 'quick' or new_value == 'long' then
            state.burn_type = new_value
        end
    elseif opt == 'pause' then
        if not new_value then
            state.paused = not state.paused
            if state.paused then
                state.reset_combat_state()
                mq.cmd('/stopcast')
            end
        else
            if config.booleans[new_value] == nil then return end
            state.paused = config.booleans[new_value]
            if state.paused then
                state.reset_combat_state()
                mq.cmd('/stopcast')
            else
                camp.set_camp()
            end
        end
    elseif opt == 'show' then
        ui.toggle_gui(true)
    elseif opt == 'hide' then
        ui.toggle_gui(false)
    elseif opt == 'mode' then
        if new_value then
            config.MODE = mode.from_string(new_value) or config.MODE
            state.reset_combat_state()
        else
            printf(logger.logLine('Mode: %s', config.MODE:get_name()))
        end
        camp.set_camp()
    elseif opt == 'resetcamp' then
        camp.set_camp(true)
    elseif opt == 'campradius' or opt == 'radius' or opt == 'pullarc' then
        config.getOrSetOption(opt, config[config.aliases[opt]], new_value, config.aliases[opt])
        camp.set_camp()
    elseif config.aliases[opt] then
        config.getOrSetOption(opt, config[config.aliases[opt]], new_value, config.aliases[opt])
    elseif opt == 'groupwatch' and common.GROUP_WATCH_OPTS[new_value] then
        config.getOrSetOption(opt, config[config.aliases[opt]], new_value, config.aliases[opt])
    elseif opt == 'assist' then
        if new_value and common.ASSISTS[new_value] then
            config.ASSIST = new_value
        end
        printf(logger.logLine('assist: %s', config.ASSIST))
    elseif opt == 'ignore' then
        local zone = mq.TLO.Zone.ShortName()
        if new_value then
            config.add_ignore(zone, arg[2]) -- use not lowercased value
        else
            local target_name = mq.TLO.Target.CleanName()
            if target_name then config.add_ignore(zone, target_name) end
        end
    elseif opt == 'unignore' then
        local zone = mq.TLO.Zone.ShortName()
        if new_value then
            config.remove_ignore(zone, arg[2]) -- use not lowercased value
        else
            local target_name = mq.TLO.Target.CleanName()
            if target_name then config.remove_ignore(zone, target_name) end
        end
    elseif opt == 'addclicky' then
        local clickyType = new_value
        local itemName = mq.TLO.Cursor()
        if itemName then
            local clicky = {name=itemName, clickyType=clickyType}
            aqoclass.addClicky(clicky)
            aqoclass.save_settings()
        else
            printf(logger.logLine('addclicky Usage:\n\tPlace clicky item on cursor\n\t/%s addclicky category\n\tCategories: burn, mash, heal, buff', state.class))
        end
    elseif opt == 'removeclicky' then
        local itemName = mq.TLO.Cursor()
        if itemName then
            aqoclass.removeClicky(itemName)
            aqoclass.save_settings()
        else
            printf(logger.logLine('removeclicky Usage:\n\tPlace clicky item on cursor\n\t/%s removeclicky', state.class))
        end
    elseif opt == 'tribute' then
        common.toggleTribute()
    elseif opt == 'bark' then
        local repeatstring = ''
        for i=2,#args do
            repeatstring = repeatstring .. ' ' .. args[i]
        end
        mq.cmdf('/dgga /say %s', repeatstring)
    elseif opt == 'force' then
        assist.force_assist(new_value)
    elseif opt == 'nowcast' then
        aqoclass.nowCast(args)
    elseif opt == 'update' then
        os.execute('start https://github.com/aquietone/aqobot/archive/refs/heads/emu.zip')
    elseif opt == 'docs' then
        os.execute('start https://aquietone.github.io/docs/aqobot/classes/'..state.class)
    else
        aqoclass.process_cmd(opt:upper(), new_value)
    end
end

local lootMyBody = false
local function rezzed()
    print('events')
    lootMyBody = true
end

local function init()
    state.suspended = mq.TLO.EverQuest.GameState() == 5
    state.class = mq.TLO.Me.Class.ShortName():lower()
    state.currentZone = mq.TLO.Zone.ID()
    state.subscription = mq.TLO.Me.Subscription()
    if mq.TLO.EverQuest.Server() == 'Project Lazarus' or mq.TLO.EverQuest.Server() == 'EZ (Linux) x4 Exp' then state.emu = true end
    common.set_swap_gem()

    aqoclass = require('classes.'..state.class)

    aqoclass.load_settings()
    aqoclass.setup_events()
    ui.set_class_funcs(aqoclass)
    common.setup_events()
    config.load_ignores()

    if state.emu then
        mq.cmd('/hidecorpse looted')
    else
        mq.cmd('/hidecorpse alwaysnpc')
    end
    mq.cmd('/multiline ; /pet ghold on')
    mq.cmd('/squelch /stick set verbflags 0')
    mq.cmd('/squelch /plugin melee unload noauto')
    mq.cmd('/squelch rez accept on')
    mq.cmd('/squelch rez pct 90')
    mq.cmdf('/setwintitle %s (Level %s %s)', mq.TLO.Me.CleanName(), mq.TLO.Me.Level(), state.class)
    --loot.logger.loglevel = 'debug'
end

-- datatypes are defined by tables with 5 (all optional) members: Members, Methods,
-- ToString, FromData, and FromString.
---@class Datatype
---@field public Members table
---@field public Methods table
---@field public ToString fun(self:Plugin, val:any):any
---@field public FromData fun(self:Plugin, source:any):any
---@field public FromString fun(self:Plugin, source:string):any
plugin.aqotype = {
    Members = {
        Paused = function(val, index) return 'bool', state.paused end,
    },
    ToString = function(val) return tostring(not state.paused) end,
}


-- tlo functions return a tuple of typename (which can be any valid MQ typename
-- like 'string' or 'spawn' and then the data required to assign the value)
function plugin:AQO(Index)
	return "aqo", self
end

--- InitializePlugin
---
--- This is called once on plugin initialization and can be considered the startup
--- routine for the plugin.
---
---@param self Plugin optionally specify a self plugin
function plugin:InitializePlugin()
    printf("%s::Initializing version %f", self.name, self.version)

    self:addcommand("/aqo", self.aqocmd)
    self:addcommand("/"..mq.TLO.Me.Class.ShortName():lower(), self.aqocmd)
    self:addtype("aqo", self.aqotype)
    self:addtlo("AQO", self.AQO)

    init()
end

--- ShutdownPlugin
---
--- This is called once when the plugin has been asked to shutdown. The plugin has
--- not actually shut down until this completes.
---
---@param self Plugin optionally specify a self plugin
function plugin:ShutdownPlugin()
    printf("%s::Shutting down", self.name)

    self:removecommand("/"..mq.TLO.Me.Class.ShortName():lower())
    self:removetype("aqo")
    self:removetlo("AQO")
end

--- SetGameState
---
--- This is called when the GameState changes. It is also called once after the
--- plugin is initialized.
---
--- For a list of known GameState values, see the constants that begin with
--- GAMESTATE_. The most commonly used of these is GAMESTATE_INGAME.
---
--- When zoning, this is called once after OnBeginZone OnRemoveSpawn
--- and OnRemoveGroundItem are all done and then called once again after
--- OnEndZone and OnAddSpawn are done but prior to OnAddGroundItem
--- and OnZoned
---
--- 1 == CHARSELECT
--- 5 == INGAME
--- 253 == loading screen?
---@param self Plugin optionally specify a self plugin
---@param GameState number The integer value of GameState at the time of the call
function plugin:SetGameState(GameState)
    printf("%s::SetGameState(%d)", self.name, GameState)
    if GameState ~= 5 then plugin.suspended = true end
end

local frameCount = 0
--- OnPulse
---
--- This is called each time MQ2 goes through its heartbeat (pulse) function.
---
--- Because this happens very frequently, it is recommended to have a timer or
--- counter at the start of this call to limit the amount of times the code in
--- this section is executed.
---
---@param self Plugin optionally specify a self plugin
function plugin:OnPulse()
    if self.suspended then return end
    if not self.PulseTimer then
        self.PulseTimer = os.clock()
    end
    --[[if os.clock() > self.PulseTimer then
        -- Wait 5 seconds before running again
        self.PulseTimer = os.clock() + 5
        printf("%s::OnPulse()", self.name)
    end]]

    -- Async state handling
    if loot.state.looting then loot.lootMobs() return end
    if loot.state.selling then loot.sellStuff() return end
    if loot.state.banking then loot.bankStuff() return end
    if not state.handleTargetState() then return end
    if not state.handlePositioningState() then return end
    if not state.handleMemSpell() then return end
    if not state.handleCastingState() then return end
    if not state.handleQueuedAction() then return end
    if frameCount == 0 then
        frameCount = frameCount + 1
    elseif frameCount == 10 then
        frameCount = 0
        return
    else
        frameCount = frameCount + 1
        return
    end
    --mq.doevents()
    state.actionTaken = false
    check_game_state()

    if not mq.TLO.Target() then
        state.assist_mob_id = 0
        state.tank_mob_id = 0
        if (mq.TLO.Me.Combat() or mq.TLO.Me.AutoFire()) then
            mq.cmd('/multiline ; /attack off; /autofire off;')
        end
    end
    if state.class == 'nec' and state.loop.PctHPs < 40 and aqoclass.spells.lich then
        mq.cmdf('/removebuff %s', aqoclass.spells.lich.name)
    end
    if not state.paused and common.in_control() and not common.am_i_dead() then
        camp.clean_targets()
        if mq.TLO.Target() and mq.TLO.Target.Type() == 'Corpse' and not common.HEALER_CLASSES[state.class] then
            state.tank_mob_id = 0
            state.assist_mob_id = 0
            if not common.HEALER_CLASSES[state.class] then
                mq.cmd('/squelch /mqtarget clear')
            end
        end
        if mq.TLO.Me.Hovering() then

        elseif not state.loop.Invis and not common.blocking_window_open() then
            -- do active combat assist things when not paused and not invis
            if mq.TLO.Me.Feigning() and not common.FD_CLASSES[state.class] then
                mq.cmd('/stand')
            end
            common.check_cursor()
            if state.emu then
                if lootMyBody and mq.TLO.Me.Buff('Resurrection Sickness')() then
                    loot.lootMyCorpse()
                    lootMyBody = false
                    state.actionTaken = true
                end
                if config.LOOTMOBS and mq.TLO.Me.CombatState() ~= 'COMBAT' and not state.pull_in_progress then
                    state.actionTaken = loot.lootMobs()
                end
            end
            if not state.actionTaken then
                aqoclass.main_loop()
            end
        else
            -- stay in camp or stay chasing chase target if not paused but invis
            local pet_target_id = mq.TLO.Pet.Target.ID() or 0
            if mq.TLO.Pet.ID() > 0 and pet_target_id > 0 then mq.cmd('/pet back') end
            camp.mob_radar()
            if (mode:is_tank_mode() and state.mob_count > 0) or (mode:is_assist_mode() and assist.should_assist()) then mq.cmd('/makemevis') end
            camp.check_camp()
            common.check_chase()
            common.rest()
        end
    else
        if state.loop.Invis then
            -- if paused and invis, back pet off, otherwise let it keep doing its thing if we just paused mid-combat for something
            local pet_target_id = mq.TLO.Pet.Target.ID() or 0
            if mq.TLO.Pet.ID() > 0 and pet_target_id > 0 then mq.cmd('/pet back') end
        end
    end
end

--- OnIncomingChat
---
--- This is called each time a line of chat is shown. It occurs after MQ filters
--- and chat events have been handled. If you need to know when MQ2 has sent chat,
--- consider using OnWriteChatColor instead.
---
--- For a list of Color values, see the constants for USERCOLOR_. The default is
--- USERCOLOR_DEFAULT.
---
---@param self Plugin optionally specify a self plugin
---@param Line string The line of text that was shown
---@param Color number The type of chat text this was sent as
---
---@return boolean Whether to filter this chat from display
function plugin:OnIncomingChat(Line, Color)
	--printf("%s::OnIncomingChat(%s, %d)", self.name, Line, Color)
    if Line:find("Your spell fizzles!") then
        state.fizzled = true
    elseif Line:find("Your spell is interrupted") then
        state.interrupted = true
    elseif Line:find('You regain .* experience from resurrection') then
        print('rez message')
    elseif Line:find(".* tells the .*, 'di'") then
        aqoclass.event_request('', '', 'di')
    end
	return false
end
--[[
    elseif Line:find('.*Returning to Bind Location.*') then
    elseif Line:find('You died.') then
    elseif Line:find('You have been slain by.*') then
    elseif Line:find('(.*) resisted your (.*)!') then
    elseif Line:find('You have entered .*') then
    elseif Line:find('You regain .* experience from resurrection') then
    elseif Line:find('Your target is immune to changes in its attack speed.*') then
    elseif Line:find('Your target is immune to changes in its run speed.*') then
    elseif Line:find('Your target is immune to snare spells.*') then
    elseif Line:find('(.*) tells you, \'(.*)\'') then
    elseif Line:find('(.*) tells the group, \'(.*)\'') then
    elseif Line:find('(.*) tells the .*, \'tranquil\'') then
    elseif Line:find('(.*) has become ENRAGED.') then
    elseif Line:find('(.*) is no longer enraged.') then
    elseif Line:find('(.*) .*, \'Cure Please!\'') then
    elseif Line:find('(.*) has been awakened by (.*).') then
    elseif Line:find('Your target cannot be mesmerized.*') then
    elseif Line:find('.*may not loot this corpse.*') then
    elseif Line:find('.*Your inventory appears full!.*') then
    elseif Line:find('.*You receive.* for the (.*)(s).*') then
    elseif Line:find('.*give you absolutely nothing for the (.*)..*') then
    elseif Line:find('.*You cannot loot this Lore Item..*') then

    elseif Line:find('(.*) says, \'Buffs Please!\'') then
    elseif Line:find('(.*) tells the group, \'Buffs Please!\'') then
    elseif Line:find('(.*) tells the raid, \'Buffs Please!\'') then
    elseif Line:find('(.*) tells you, \'Buffs Please!\'') then
    elseif Line:find('Your forage mastery has enabled you to find something else!') then
    elseif Line:find('You have scrounged up #*#') then
]]

--- OnBeginZone
---
--- This is called just after entering a zone line and as the loading screen appears.
---
---@param self Plugin optionally specify a self plugin
function plugin:OnBeginZone()
    printf("%s::OnBeginZone()", self.name)
    plugin.suspended = true
end

--- OnZoned
---
--- This is called after entering a new zone and the zone is considered "loaded."
---
--- It occurs after OnEndZone OnAddSpawn and OnAddGroundItem have
--- been called.
---
---@param self Plugin optionally specify a self plugin
function plugin:OnZoned()
    printf("%s::OnZoned()", self.name)
    state.reset_combat_state()
    if state.currentZone == mq.TLO.Zone.ID() then
        -- evac'd
        camp.set_camp()
        movement.stop()
    end
    state.currentZone = mq.TLO.Zone.ID()
    mq.cmd('/pet ghold on')
    if not state.paused and config.MODE:is_pull_mode() then
        config.MODE = mode.from_string('manual')
        camp.set_camp()
        movement.stop()
    end
    plugin.suspended = false
end

--- OnUpdateImGui
---
--- This is called each time that the ImGui Overlay is rendered. Use this to render
--- and update plugin specific widgets.
---
--- Because this happens extremely frequently, it is recommended to move any actual
--- work to a separate call and use this only for updating the display.
---
---@param self Plugin optionally specify a self plugin
function plugin:OnUpdateImGui()
    ui.main()
end

--- The script must return the constructed plugin object
return plugin