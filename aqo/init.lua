--- @type Mq
local mq = require('mq')
--- @type ImGui
require 'ImGui'

local aqo = {}

local routines = {'assist','buff','camp','cure','events','heal','mez','movement','pull','tank'}
for _,routine in ipairs(routines) do
    aqo[routine] = require('routines.'..routine)
    aqo[routine].init(aqo)
end

aqo.lists = require('data.lists')
aqo.logger = require('utils.logger')
aqo.loot = require('utils.lootutils')
aqo.timer = require('utils.timer')
aqo.ability = require('ability')
aqo.commands = require('commands')
aqo.common = require('common')
aqo.config = require('configuration')
aqo.mode = require('mode')
aqo.state = require('state')
aqo.ui = require('ui')

local function init()
    -- Set emu state before anything else, things initialize differently depending if its emu or not
    if mq.TLO.EverQuest.Server() == 'Project Lazarus' or mq.TLO.EverQuest.Server() == 'EZ (Linux) x4 Exp' then aqo.state.emu = true end
    aqo.state.class = mq.TLO.Me.Class.ShortName():lower()
    -- Initialize class specific functions
    aqo.class = require('classes.'..aqo.state.class)
    aqo.class.init(aqo)

    -- Initialize binds
    aqo.commands.init(aqo)

    -- Initialize UI
    aqo.ui.init(aqo)

    aqo.state.currentZone = mq.TLO.Zone.ID()
    aqo.state.subscription = mq.TLO.Me.Subscription()
    aqo.common.set_swap_gem()
    aqo.config.load_ignores()

    if aqo.state.emu then
        mq.cmd('/hidecorpse looted')
    else
        mq.cmd('/hidecorpse alwaysnpc')
    end
    mq.cmd('/multiline ; /pet ghold on')
    mq.cmd('/squelch /stick set verbflags 0')
    mq.cmd('/squelch /plugin melee unload noauto')
    mq.cmd('/squelch /rez accept on')
    mq.cmd('/squelch /rez pct 90')
    mq.cmdf('/setwintitle %s (Level %s %s)', mq.TLO.Me.CleanName(), mq.TLO.Me.Level(), aqo.state.class)
end

---Check if the current game state is not INGAME, and exit the script if it is.
---Otherwise, update state for the current loop so we don't have to go to the TLOs every time.
local function updateLoopState()
    if mq.TLO.MacroQuest.GameState() ~= 'INGAME' then
        print(aqo.logger.logLine('Not in game, stopping aqo.'))
        mq.exit()
    end
    aqo.state.actionTaken = false
    aqo.state.loop = {
        PctHPs = mq.TLO.Me.PctHPs(),
        PctMana = mq.TLO.Me.PctMana(),
        PctEndurance = mq.TLO.Me.PctEndurance(),
        ID = mq.TLO.Me.ID(),
        Invis = mq.TLO.Me.Invis(),
        PetName = mq.TLO.Me.Pet.CleanName(),
        TargetID = mq.TLO.Target.ID(),
        TargetHP = mq.TLO.Target.PctHPs(),
        PetID = mq.TLO.Pet.ID()
    }
end

---For EMU servers, detect if in a raid and set assist mode to manual as raid and group MA roles do Not
---work in a raid. Also disable automatic burns.
local function detectRaidOrGroup()
    if not aqo.config.AUTODETECTRAID.value then return end
    if mq.TLO.Raid.Members() > 0 then
        local leader = mq.TLO.Group.Leader() or nil
        if aqo.config.ASSIST.value == 'group' and leader and leader ~= mq.TLO.Me.CleanName() then
            aqo.config.ASSIST.value = 'manual'
            aqo.config.CHASETARGET.value = mq.TLO.Group.Leader()
            aqo.config.BURNALWAYS.value = false
            aqo.config.BURNCOUNT.value = 100
        end
    else
        if aqo.config.ASSIST.value == 'manual' then
            aqo.config.ASSIST.value = 'group'
        end
    end
end

---Reset assist/tank ID and turn off attack if we have no target or are targeting a corpse
---If targeting a corpse, also clear target unless its a healer
local function checkTarget()
    local targetType = mq.TLO.Target.Type()
    if not targetType or targetType == 'Corpse' then
        aqo.state.assist_mob_id = 0
        aqo.state.tank_mob_id = 0
        if mq.TLO.Me.Combat() or mq.TLO.Me.AutoFire() then
            mq.cmd('/multiline ; /attack off; /autofire off;')
        end
        if targetType == 'Corpse' and not aqo.lists.healClasses[aqo.state.class] then
            mq.cmd('/squelch /mqtarget clear')
        end
    elseif targetType == 'Pet' or targetType == 'PC' then
        aqo.state.assist_mob_id = 0
        aqo.state.tank_mob_id = 0
        if mq.TLO.Stick.Active() then
            mq.cmd('/squelch /stick off')
        end
    end
end

local function checkFD()
    if mq.TLO.Me.Feigning() and (not aqo.lists.fdClasses[aqo.state.class] or not aqo.state.didFD) then
        mq.cmd('/stand')
    end
end

---Remove harmful buffs such as lich if HP is getting low, regardless of paused state
local function buffSafetyCheck()
    if aqo.state.class == 'nec' and aqo.state.loop.PctHPs < 40 and aqo.class.spells.lich then
        mq.cmdf('/removebuff %s', aqo.class.spells.lich.name)
    end
end

local function doLooting()
    if mq.TLO.Spawn('pccorpse ='..mq.TLO.Me.CleanName()..'\'s corpse')() then
        aqo.loot.lootMyCorpse()
        aqo.state.actionTaken = true
    end
    if aqo.config.LOOTMOBS.value and mq.TLO.Me.CombatState() ~= 'COMBAT' and not aqo.state.pull_in_progress then
        aqo.state.actionTaken = aqo.loot.lootMobs()
        if aqo.state.lootBeforePull then aqo.state.lootBeforePull = false end
    end
end

local function main()
    init()

    local debug_timer = aqo.timer:new(3)
    -- Main Loop
    while true do
        if aqo.state.debug and debug_timer:timer_expired() then
            aqo.logger.debug(aqo.logger.log_flags.aqo.main, 'Start Main Loop')
            debug_timer:reset()
        end
        mq.doevents()
        updateLoopState()
        detectRaidOrGroup()
        buffSafetyCheck()
        if not aqo.state.paused and aqo.common.in_control() and not aqo.common.am_i_dead() then
            aqo.camp.clean_targets()
            checkTarget()
            if mq.TLO.Me.Hovering() then
                mq.delay(50)
            elseif not aqo.state.loop.Invis and not aqo.common.blocking_window_open() then
                -- do active combat assist things when not paused and not invis
                checkFD()
                aqo.common.check_cursor()
                if aqo.state.emu then
                    doLooting()
                end
                if not aqo.state.actionTaken then
                    aqo.class.main_loop()
                end
                mq.delay(50)
            else
                -- stay in camp or stay chasing chase target if not paused but invis
                local pet_target_id = mq.TLO.Pet.Target.ID() or 0
                if mq.TLO.Pet.ID() > 0 and pet_target_id > 0 then mq.cmd('/pet back') end
                aqo.camp.mob_radar()
                if (aqo.mode:is_tank_mode() and aqo.state.mob_count > 0) or (aqo.mode:is_assist_mode() and aqo.assist.should_assist()) then mq.cmd('/makemevis') end
                aqo.camp.check_camp()
                aqo.common.check_chase()
                aqo.common.rest()
                mq.delay(50)
            end
        else
            if aqo.state.loop.Invis then
                -- if paused and invis, back pet off, otherwise let it keep doing its thing if we just paused mid-combat for something
                local pet_target_id = mq.TLO.Pet.Target.ID() or 0
                if mq.TLO.Pet.ID() > 0 and pet_target_id > 0 then mq.cmd('/pet back') end
            end
            mq.delay(500)
        end
    end
end

main()