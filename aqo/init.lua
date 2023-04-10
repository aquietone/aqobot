--- @type Mq
local mq = require('mq')
--- @type ImGui
require 'ImGui'

local aqo = {}

local routines = {'assist','buff','camp','conditions','cure','debuff','events','heal','mez','movement','pull','tank'}
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
local config = require('configuration')
aqo.mode = require('mode')
aqo.state = require('state')
aqo.ui = require('ui')

local function init()
    -- Set emu state before anything else, things initialize differently depending if its emu or not (ROF == 19, EMU stops at ROF)
    if not mq.TLO.Me.HaveExpansion(20)() then aqo.state.emu = true end
    aqo.state.class = mq.TLO.Me.Class.ShortName():lower()
    -- Initialize class specific functions
    aqo.class = require('classes.'..aqo.state.class)
    aqo.class.init(aqo)
    aqo.events.initClassBasedEvents()
    aqo.ability.init(aqo)

    -- Initialize binds
    mq.cmd('/squelch /djoin aqo')
    aqo.commands.init(aqo)

    -- Initialize UI
    aqo.ui.init(aqo)

    aqo.state.currentZone = mq.TLO.Zone.ID()
    aqo.state.subscription = mq.TLO.Me.Subscription()
    aqo.common.setSwapGem()
    config.loadIgnores()

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
    mq.cmd('/squelch /assist off')
    mq.cmd('/squelch /autofeed 5000')
    mq.cmd('/squelch /autodrink 5000')
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
    if not config.get('AUTODETECTRAID') then return end
    if mq.TLO.Raid.Members() > 0 then
        local leader = mq.TLO.Group.Leader() or nil
        if config.get('ASSIST') == 'group' and leader and leader ~= mq.TLO.Me.CleanName() then
            config.set('ASSIST', 'manual')
            config.set('CHASETARGET', mq.TLO.Group.Leader())
            config.set('BURNALWAYS', false)
            config.set('BURNCOUNT', 100)
        end
    else
        if config.get('ASSIST') == 'manual' then
            config.set('ASSIST', 'group')
        end
    end
end

---Reset assist/tank ID and turn off attack if we have no target or are targeting a corpse
---If targeting a corpse, also clear target unless its a healer
local function checkTarget()
    local targetType = mq.TLO.Target.Type()
    if not targetType or targetType == 'Corpse' then
        aqo.state.assistMobID = 0
        aqo.state.tankMobID = 0
        if mq.TLO.Me.Combat() or mq.TLO.Me.AutoFire() then
            mq.cmd('/multiline ; /attack off; /autofire off;')
        end
        if targetType == 'Corpse' and not aqo.lists.healClasses[aqo.state.class] then
            mq.cmd('/squelch /mqtarget clear')
        end
    elseif targetType == 'Pet' or targetType == 'PC' then
        aqo.state.assistMobID = 0
        aqo.state.tankMobID = 0
        if mq.TLO.Stick.Active() then
            mq.cmd('/squelch /stick off')
        end
        if mq.TLO.Me.Combat() then mq.cmd('/attack off') end
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

local lootMyCorpseTimer = aqo.timer:new(5)
local function doLooting()
    local myCorpse = mq.TLO.Spawn('pccorpse '..mq.TLO.Me.CleanName()..'\'s corpse radius 100')
    if myCorpse() and lootMyCorpseTimer:timerExpired() then
        lootMyCorpseTimer:reset()
        myCorpse.DoTarget()
        if mq.TLO.Target.Type() == 'Corpse' then
            mq.cmd('/keypress CONSIDER')
            mq.delay(500)
            mq.doevents('eventCannotRez')
            if aqo.state.cannotRez then
                aqo.state.cannotRez = nil
                mq.cmd('/corpse')
                aqo.movement.navToTarget(nil, 10000)
                if (mq.TLO.Target.Distance3D() or 100) > 10 then return end
                aqo.loot.lootMyCorpse()
                aqo.state.actionTaken = true
                return
            end
        end
    end
    if config.get('LOOTMOBS') and mq.TLO.Me.CombatState() ~= 'COMBAT' and not aqo.state.pullStatus then
        aqo.state.actionTaken = aqo.loot.lootMobs()
        if aqo.state.lootBeforePull then aqo.state.lootBeforePull = false end
    end
end

local function handleStates()
    -- Async state handling
    --if aqo.state.looting then aqo.loot.lootMobs() return true end
    --if aqo.state.selling then aqo.loot.sellStuff() return true end
    --if aqo.state.banking then aqo.loot.bankStuff() return true end
    if not aqo.state.handleTargetState() then return true end
    if not aqo.state.handlePositioningState() then return true end
    if not aqo.state.handleMemSpell() then return true end
    if not aqo.state.handleCastingState() then return true end
    if not aqo.state.handleQueuedAction() then return true end
end

local function main()
    init()

    local debugTimer = aqo.timer:new(3)
    -- Main Loop
    while true do
        if aqo.state.debug and debugTimer:timerExpired() then
            aqo.logger.debug(aqo.logger.flags.aqo.main, 'Start Main Loop')
            debugTimer:reset()
        end

        mq.doevents()
        updateLoopState()
        detectRaidOrGroup()
        buffSafetyCheck()
        if not aqo.state.paused and aqo.common.inControl() then
            if not aqo.state.useStateMachine or not handleStates() then
                aqo.camp.cleanTargets()
                checkTarget()
                if not aqo.state.loop.Invis and not aqo.common.isBlockingWindowOpen() then
                    -- do active combat assist things when not paused and not invis
                    checkFD()
                    aqo.common.checkCursor()
                    if aqo.state.emu then
                        doLooting()
                    end
                    if not aqo.state.actionTaken then
                        aqo.class.mainLoop()
                    end
                    mq.delay(50)
                else
                    -- stay in camp or stay chasing chase target if not paused but invis
                    local pet_target_id = mq.TLO.Pet.Target.ID() or 0
                    if mq.TLO.Pet.ID() > 0 and pet_target_id > 0 then mq.cmd('/pet back') end
                    aqo.camp.mobRadar()
                    if (aqo.mode:isTankMode() and aqo.state.mobCount > 0) or (aqo.mode:isAssistMode() and aqo.assist.shouldAssist()) then mq.cmd('/makemevis') end
                    aqo.camp.checkCamp()
                    aqo.common.checkChase()
                    aqo.common.rest()
                    mq.delay(50)
                end
            end
        else
            if aqo.state.loop.Invis then
                -- if paused and invis, back pet off, otherwise let it keep doing its thing if we just paused mid-combat for something
                local pet_target_id = mq.TLO.Pet.Target.ID() or 0
                if mq.TLO.Pet.ID() > 0 and pet_target_id > 0 then mq.cmd('/pet back') end
            end
            mq.delay(500)
        end
        -- broadcast some buff and poison/disease/curse state around netbots style
        aqo.buff.broadcast()
    end
end

main()