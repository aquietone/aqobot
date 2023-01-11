local mq = require('mq')
local logger = require('utils.logger')
local timer = require('utils.timer')

local state = {
    debug = false,
    paused = true,
    burn_now = false,
    burn_active = false,
    burn_active_timer = timer:new(30),
    min_mana = 15,
    min_end = 15,
    spellset_loaded = nil,
    i_am_dead = false,
    assist_mob_id = 0,
    tank_mob_id = 0,
    pull_mob_id = 0,
    pull_in_progress = nil,
    targets = {},
    mob_count = 0,
    mob_count_nopet = 0,
    mez_immunes = {},
    mez_target_name = nil,
    mez_target_id = 0,
    subscription = 'GOLD',
}

function state.reset_combat_state()
    state.burn_active = false
    state.burn_active_timer:reset(0)
    state.assist_mob_id = 0
    state.tank_mob_id = 0
    state.pull_mob_id = 0
    state.pull_in_progress = nil
    state.targets = {}
    state.mob_count = 0
    state.mob_count_nopet = 0
    state.mez_target_name = nil
    state.mez_target_id = 0
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

--for k,v in pairs(state.get_all()) do
--    printf(logger.logLine('%s: %s', k, v))
--end

return state