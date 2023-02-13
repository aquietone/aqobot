---@type Mq
local mq = require('mq')
local logger = require('utils.logger')
local timer = require('utils.timer')

local state = {
    debug = false,
    paused = true,
    burnNow = false,
    burnActive = false,
    burnActiveTimer = timer:new(30),
    minMana = 15,
    minEndurance = 15,
    spellSetLoaded = nil,
    assistMobID = 0,
    tankMobID = 0,
    pullMobID = 0,
    pullStatus = nil,
    targets = {},
    mobCount = 0,
    mobCountNoPets = 0,
    mezImmunes = {},
    mezTargetName = nil,
    mezTargetID = 0,
    subscription = 'GOLD',
    resists = {},
    medding = false,
    buffs = {},
    sick = {},
    useStateMachine = true,
}

function state.resetCombatState(debug, caller)
    logger.debug(debug, 'Resetting combatState. pullState before=%s. caller=%s', state.pullState, caller)
    state.burnActive = false
    state.burnActiveTimer:reset(0)
    state.assistMobID = 0
    state.tankMobID = 0
    state.pullMobID = 0
    state.pullStatus = nil
    state.targets = {}
    state.mobCount = 0
    state.mobCountNoPets = 0
    state.mezTargetName = nil
    state.mezTargetID = 0
    state.resists = {}
end


state.actionTaken = false

state.acquireTarget = false
state.acquireTargetTimer = timer:new(1, true)

function state.handleTargetState()
    if state.acquireTarget then
        if state.acquireTarget == mq.TLO.Target.ID() then
            if state.queuedAction then state.queuedAction() end
            state.resetAcquireTargetState()
            return true
        elseif state.acquireTargetTimer:timer_expired() then
            -- timer expired, target not acquired, reset state
            state.resetAcquireTargetState()
            return true
        else
            -- spin
            return false
        end
    else
        return true
    end
end

function state.resetAcquireTargetState()
    state.acquireTarget = false
    state.actionTaken = false
    state.queuedAction = nil
end

state.positioning = false
state.positioningTimer = timer:new(5, true)

function state.handlePositioningState()
    if state.positioning then
        if state.positioningTimer:timer_expired() or not mq.TLO.Navigation.Active() then
            mq.cmd('/squelch /nav stop')
            state.resetPositioningState()
            return true
        else
            return false
        end
    else
        return true
    end
end

function state.resetPositioningState()
    state.positioning = nil
    state.actionTaken = false
end

state.queuedAction = nil

function state.handleQueuedAction()
    if state.queuedAction then
        local result =state.queuedAction()
        if type(result) ~= 'function' then
            state.queuedAction = nil
            state.actionTaken = false
            return true
        else
            state.queuedAction = result
            return false
        end
    else
        return true
    end
end

state.memSpell = false
state.memSpellTimer = timer:new(10, true)
state.restoreGem = nil

function state.handleMemSpell()
    if state.memSpell then
        if mq.TLO.Me.SpellReady(state.memSpell.name)() then
            printf(logger.logLine('Memorized spell is ready: %s', state.memSpell.name))
            state.resetMemSpellState()
            return true
        elseif state.memSpellTimer:timer_expired() then
            -- timer expired, spell not memorized, reset state
            state.resetMemSpellState()
            return true
            -- maybe re-mem old spell?
        else
            -- spin
            return false
        end
    else
        return true
    end
end

function state.resetMemSpellState()
    state.memSpell = nil
    state.actionTaken = false
end

state.casting = false

function state.handleCastingState()
    if state.casting then
        if not mq.TLO.Me.Casting() then
            if state.fizzled then
                printf(logger.logLine('Fizzled casting %s', state.casting.name))
            elseif state.interrupted then
                printf(logger.logLine('Interrupted casting %s', state.casting.name))
            --else
            --    printf(logger.logLine('Finished casting %s', state.casting.name))
            end
            state.resetCastingState()
            return true
        elseif state.casting.targettype == 'Single' and not mq.TLO.Target() then
            mq.cmd('/stopcast')
            state.resetCastingState()
            return true
        else
            return false
        end
    else
        return true
    end
end

function state.resetCastingState()
    state.casting = false
    state.fizzled = nil
    state.interrupted = nil
    state.restoreGem = nil
    state.actionTaken = false
end

state.corpseToLoot = nil

function state.handleMoveToCorpseState()

end

function state.handleOpenCorpseState()

end

function state.handleLootingState()

end

return state