---@type Mq
local mq = require('mq')
local logger = require('utils.logger')
local timer = require('utils.timer')

local state = {
    class = string.lower(mq.TLO.Me.Class.ShortName() or ''),
    -- (ROF == 19, EMU stops at ROF)
    emu = not mq.TLO.Me.HaveExpansion(20)() and true or false,
    actors = {},
    debug = false,
    paused = true,
    burnNow = false,
    burnActive = false,
    burnActiveTimer = timer:new(30000),
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
    justZonedTimer = timer:new(2000)
}

state.fsm = {
    IDLE='IDLE',
    -- tank states
    TANK_SCAN='TANK_SCAN',
    TANK_ENGAGE='TANK_ENGAGE',
    -- pull states
    PULL_SCAN='PULL_SCAN',
    PULL_APPROACH='PULL_APPROACH',
    PULL_ENGAGE='PULL_ENGAGE',
    PULL_RETURN='PULL_RETURN',
    PULL_WAIT='PULL_WAIT',
    -- assist states
    ASSIST_SCAN='ASSIST_SCAN',
    ASSIST_ENGAGE='ASSIST_ENGAGE',
    -- heal states
    HEAL_SCAN='HEAL_SCAN',
    HEAL_CAST='HEAL_CAST',
    -- buff states
    BUFF_SCAN='BUFF_SCAN',
    BUFF_CAST='BUFF_CAST',
    -- spell states
    CASTING='CASTING',
    -- loot states
    LOOT_SCAN='LOOT_SCAN',
    LOOT_APPROACH='LOOT_APPROACH',
    LOOT_MOB='LOOT_MOB',
    LOOT_ITEM='LOOT_ITEM',
    -- mez, rest, rez, fade, pet, chasing, return to camp
}
state.currentState = state.fsm.IDLE

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
state.acquireTargetTimer = timer:new(1000)

function state.handleTargetState()
    if state.acquireTarget then
        if state.acquireTarget == mq.TLO.Target.ID() then
            if state.queuedAction then state.queuedAction() end
            state.resetAcquireTargetState()
            return true
        elseif state.acquireTargetTimer:timerExpired() then
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
state.positioningTimer = timer:new(5000)

function state.handlePositioningState()
    if state.positioning then
        if state.positioningTimer:timerExpired() or not mq.TLO.Navigation.Active() then
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
        local result = state.queuedAction()
        if type(result) ~= 'function' then
            state.queuedAction = nil
            state.actionTaken = false
            return false
        else
            state.queuedAction = result
            return false
        end
    else
        return true
    end
end

state.memSpell = false
state.memSpellTimer = timer:new(10000)
state.restoreGem = nil

function state.handleMemSpell()
    if state.memSpell then
        if mq.TLO.Me.SpellReady(state.memSpell.Name)() then
            logger.info('Memorized spell is ready: %s', state.memSpell.Name)
            state.resetMemSpellState()
            return true
        elseif state.memSpellTimer:timerExpired() then
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
        -- non-plugin mode needs time before it actually detects casting
        mq.delay(300)
        mq.doevents()
        if not mq.TLO.Me.Casting() then
            if state.fizzled then
                logger.info('Fizzled casting %s', state.casting.Name)
            elseif state.interrupted then
                logger.info('Interrupted casting %s', state.casting.Name)
            --else
            --    logger.info('Finished casting %s', state.casting.Name)
            end
            state.resetCastingState()
            return true
        elseif (state.casting.TargetType == 'Single' or state.casting.TargetType == 'Line of Sight') and not mq.TLO.Target() then
            mq.cmd('/stopcast')
            state.resetCastingState()
            return true
        else
            if state.class == 'brd' then
                if not mq.TLO.Me.Invis() and mq.TLO.Me.CastTimeLeft() > 4000 then
                    mq.cmd('/stopsong')
                else
                    return true
                end
            end
            return false
        end
    else
        return true
    end
end

function state.setCastingState(ability)
    state.resetCastingState()
    if (ability.MyCastTime or 0) > 0 then
        state.casting = ability
        state.actionTaken = true
    end
    --state[ability.Name] = timer:new(2000)
    ability.timer:reset()
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