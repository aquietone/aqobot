--- @type Mq
local mq = require('mq')
--- @type ImGui
local imgui = require 'ImGui'

AQO='aqo'
local assist = require(AQO..'.routines.assist')
local camp = require(AQO..'.routines.camp')
local logger = require(AQO..'.utils.logger')
local loot = require(AQO..'.utils.lootutils')
local common = require(AQO..'.common')
local config = require(AQO..'.configuration')
local mode = require(AQO..'.mode')
local state = require(AQO..'.state')
local ui = require(AQO..'.ui')
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
        logger.printf('Not in game, stopping aqo.')
        mq.exit()
    end
end

---Display help information for the script.
local function show_help()
    logger.printf('AQO Bot 1.0')
    logger.printf(('Commands:\n- /cls burnnow\n- /cls pause on|1|off|0\n- /cls show|hide\n- /cls mode 0|1|2\n- /cls resetcamp\n- /cls help'):gsub('cls', state.class))
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
    local new_value = args[2]
    if opt == 'help' then
        show_help()
    elseif opt == 'debug' then
        local section = args[2]
        local subsection = args[3]
        if logger.log_flags[section] and logger.log_flags[section][subsection] ~= nil then
            logger.log_flags[section][subsection] = not logger.log_flags[section][subsection]
        end
    elseif opt == 'sell' and not new_value then
        loot.sellStuff()
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
            if config.BOOL.TRUE[new_value] then
                state.paused = true
                state.reset_combat_state()
                mq.cmd('/stopcast')
            elseif config.BOOL.FALSE[new_value] then
                camp.set_camp()
                state.paused = false
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
            logger.printf('Mode: %s', config.MODE:get_name())
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
        logger.printf('assist: %s', config.ASSIST)
    elseif opt == 'ignore' then
        local zone = mq.TLO.Zone.ShortName()
        if new_value then
            config.add_ignore(zone, new_value)
        else
            local target_name = mq.TLO.Target.CleanName()
            if target_name then config.add_ignore(zone, target_name) end
        end
    elseif opt == 'unignore' then
        local zone = mq.TLO.Zone.ShortName()
        if new_value then
            config.remove_ignore(zone, new_value)
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
            logger.printf('addclicky Usage:\n\tPlace clicky item on cursor\n\t/%s addclicky category\n\tCategories: burn, mash, heal, buff', state.class)
        end
    elseif opt == 'removeclicky' then
        local itemName = mq.TLO.Cursor()
        if itemName then
            aqoclass.removeClicky(itemName)
            aqoclass.save_settings()
        else
            logger.printf('removeclicky Usage:\n\tPlace clicky item on cursor\n\t/%s removeclicky', state.class)
        end
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

    aqoclass = require(AQO..'.classes.'..state.class)

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
    --mq.event('zoned', 'You have entered #*#', zoned)
    if state.emu then
        mq.event('rezzed', 'You regain #*# experience from resurrection', rezzed)
    end
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
    if os.clock() > self.PulseTimer then
        -- Wait 5 seconds before running again
        self.PulseTimer = os.clock() + 5
        printf("%s::OnPulse()", self.name)
    end

    if state.targetForAssist then
        if state.targetForAssist() then
            state.queuedAction()
            state.targetForAssist = nil
            state.queuedAction = nil
            state.actionTaken = false
        elseif not state.targetTimer:timer_expired() then
            return
        else
            state.targetForAssist = nil
            state.queuedAction = nil
            state.actionTaken = false
            state.targetTimer = nil
        end
    elseif state.positioning then
        if state.positioningTimer:timer_expired() or not mq.TLO.Navigation.Active() then
            state.positioning = nil
            state.positioningTimer = nil
        else
            return
        end
    elseif state.queuedAction then
        state.queuedAction()
        state.queuedAction = nil
    elseif state.memSpell then
        --if mq.TLO.Me.Gem(state.memSpell.name)() then
        if mq.TLO.Me.SpellReady(state.memSpell.name)() then
            printf('spell ready %s', state.memSpell.name)
            if state.castAfterMem then
                printf('going to cast mem\'d spell %s', state.memSpell.name)
                state.memSpell:use()
                state.casting = state.memSpell
                state.memSpell = nil
                state.memSpellTimer = nil
                return
            else
                printf('not going to cast mem\'d spell %s', state.memSpell.name)
                state.memSpell = nil
                state.memSpellTimer = nil
                state.castAfterMem = nil
                state.actionTaken = false
                state.restore_gem = nil
            end
        elseif state.memSpellTimer:timer_expired() then
            state.memSpell = nil
            state.memSpellTimer = nil
            state.actionTaken = false
        else
            return
        end
    elseif state.actionTaken then
        if state.casting then
            if not mq.TLO.Me.Casting() then
                if state.fizzled then
                    state.fizzled = nil
                    printf('Fizzled casting %s', state.casting.name)
                    --state.casting:use()
                    --return
                elseif state.interrupted then
                    state.interrupted = nil
                    printf('Interrupted casting %s', state.casting.name)
                else
                    printf('Finished casting %s', state.casting.name)
                end
                if state.restore_gem and state.restore_gem.name then
                    printf('going to restore gem %s', state.restore_gem.name)
                    common.swap_spell(state.restore_gem,state.restore_gem.gem)
                    state.casting = nil
                    state.castAfterMem = nil
                    return
                else
                    state.actionTaken = false
                    state.casting = nil
                end
            elseif state.casting.targettype == 'Single' and not mq.TLO.Target() then
                mq.cmd('/stopcast')
                state.casting = nil
                state.actionTaken = false
            else
                return
            end
        end
    end

    mq.doevents()
    state.actionTaken = false
    check_game_state()

    if not mq.TLO.Target() and (mq.TLO.Me.Combat() or mq.TLO.Me.AutoFire()) then
        state.assist_mob_id = 0
        state.tank_mob_id = 0
        state.pull_mob_id = 0
        mq.cmd('/multiline ; /attack off; /autofire off;')
    end

    if not state.paused then
        camp.clean_targets()
        if mq.TLO.Target() and mq.TLO.Target.Type() == 'Corpse' then
            state.tank_mob_id = 0
            state.assist_mob_id = 0
            state.pull_mob_id = 0
            mq.cmd('/squelch /mqtarget clear')
        end
        if mq.TLO.Me.Hovering() then

        elseif not mq.TLO.Me.Invis() and not common.blocking_window_open() then
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
        if mq.TLO.Me.Invis() then
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
        aqoclass.event_request('', 'nimco', 'di')
    end
	return false
end

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
    end
    state.currentZone = mq.TLO.Zone.ID()
    mq.cmd('/pet ghold on')
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
    --[[if not self.is_open or mq.TLO.MacroQuest.GameState() ~= 'INGAME' then
        return
    end
    local is_drawn = false
    self.is_open, is_drawn = imgui.Begin('AQO##testing', self.is_open)
    if is_drawn then

    end
    ImGui.End()]]
    ui.main()
end

--- The script must return the constructed plugin object
return plugin
