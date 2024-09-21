local mq = require('mq')
local config = require('interface.configuration')
local logger = require('utils.logger')
local timer = require('libaqo.timer')
local constants = require('constants')

local state = {
    class = mq.TLO.Me.Class.ShortName() or '',
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
    swapGem = 8,
    justZonedTimer = timer:new(2000),
    rotationUpdated = false,
    rotationRefreshTimer = timer:new(60000, true),
    nuketimer = timer:new(0),
    sitTimer = timer:new(10000),
    fadeTimer = timer:new(10000),
    -- ActAsLevel = 65
    -- testCures = true,
    -- ShowGettingStarted = true,
}

function state.resetCombatState(debug, caller)
    logger.debug(debug, 'Resetting combatState. pullState before=%s. caller=%s', state.pullState, caller)
    state.burnActive = false
    state.burnActiveTimer:reset(0)
    state.burnNow = false
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

state.positioning = false
state.positioningTimer = timer:new(5000)

function state.handlePositioningState()
    if state.positioning then
        if state.positioningTimer:expired() or not mq.TLO.Navigation.Active() then
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
state.queuedActionTimer = timer:new(20000)

function state.handleQueuedAction()
    if state.queuedAction and not state.queuedActionTimer:expired() then
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
state.memSpellTimer = timer:new(60000)
state.wait_for_spell_ready = false
state.restore_gem = nil
state.restoreGemTimer = timer:new(90000)

function state.handleMemSpell()
    if state.restore_gem and state.restoreGemTimer:expired() then state.restore_gem = nil end
    if state.memSpell then
        if (mq.TLO.Me.Gem(state.memSpell.Name)() and not state.wait_for_spell_ready) or mq.TLO.Me.SpellReady(state.memSpell.Name)() then
            logger.info('Finished memorizing: \ag%s\ax', state.memSpell.Name)
            state.resetMemSpellState()
            if mq.TLO.Window('SpellBookWnd').Open() then mq.TLO.Window('SpellBookWnd').DoClose() end
            return true
        elseif state.memSpellTimer:expired() then
            -- timer expired, spell not memorized, reset state
            state.resetMemSpellState()
            return true
            -- maybe re-mem old spell?
        elseif not mq.TLO.Me.Gem(state.memSpell.Name)() and not mq.TLO.Window('SpellBookWnd').Open() then
            -- cut off during mem spell?
            state.resetMemSpellState()
            return true
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
    state.wait_for_spell_ready = false
    state.actionTaken = false
end

state.casting = false
state.castAttempts = 0

function state.handleCastingState(class)
    if state.casting then
        -- non-plugin mode needs time before it actually detects casting
        mq.delay(300)
        mq.doevents()
        if not mq.TLO.Me.Casting() then
            mq.cmd('/stick unpause')
            if state.casting and state.casting.clickyType and mq.TLO.Me.ItemReady(state.casting.name)() and state.casting.timer then state.casting.timer:reset(0) end
            if state.fizzled or state.interrupted then
                logger.info('Casting \ag%s\ax failed (Attempt %s)', state.casting.Name, state.castAttempts + 1)
                local casting = state.casting
                if casting.timer then casting.timer:reset(0) end
                if state.castAttempts < 2 then
                    state.castAttempts = state.castAttempts + 1
                    local tmpQueuedAction = state.queuedAction
                    state.queuedAction = function()
                        mq.delay(1000, function() return not mq.TLO.Me.SpellInCooldown() end)
                        casting:use()
                        return tmpQueuedAction
                    end
                    state.queuedActionTimer:reset()
                    state.queuedActionTimer.expiration = 5000
                else
                    state.castAttempts = 0
                end
            else
                state.castAttempts = 0
            end
            state.resetCastingState()
            state.resetHealState()
            return true
        elseif (state.casting.TargetType == 'Single' or state.casting.TargetType == 'Line of Sight') and not mq.TLO.Target() then
            mq.cmd('/stopcast')
            state.resetCastingState()
            state.resetHealState()
            return true
        else
            if state.class == 'BRD' then
                if not mq.TLO.Me.Invis() and mq.TLO.Me.CastTimeLeft() > 4000 then
                    mq.cmd('/stopsong')
                else
                    return true
                end
            elseif constants.healClasses[state.class] then
                -- printf('%s %s %s', state.canInterrupt, state.casting.CastName, config.get('INTERRUPTFORHEALS'))
                if config.get('INTERRUPTFULLHP') and state.healTarget == mq.TLO.Target.ID() and (mq.TLO.Target.PctHPs() or 0) > 95 then
                    mq.cmd('/stopcast')
                    state.resetCastingState()
                    state.resetHealState()
                    return true
                end
                -- if not state.casting.cure and not state.casting.debuff then
                if state.canInterrupt and config.get('INTERRUPTFORHEALS') then
                    -- evaluate interrupting cast for a emergency heal
                    local panic = mq.TLO.Group.Injured(config.get('PANICHEALPCT'))() or 0
                    local regular = mq.TLO.Group.Injured(config.get('HEALPCT'))() or 0
                    if panic > 0 and (mq.TLO.Me.CastTimeLeft() > 750 or not state.healToUse) then
                        if class:emergencyHeal() then return false end
                    elseif regular > 0 and not state.healToUse then
                        if class:emergencyHeal() then return false end
                    end
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
    ability.timer:reset()
end

function state.resetCastingState()
    state.casting = false
    state.fizzled = nil
    state.interrupted = nil
    state.actionTaken = false
    state.canInterrupt = false
end

function state.setHealState(whoToHeal, healType, healToUse)
    if (healToUse.MyCastTime or 0) > 0 then
        state.healTarget = whoToHeal
        state.healType = healType
        state.healToUse = healToUse
    end
end

function state.resetHealState()
    state.healTarget = nil
    state.healType = nil
    state.healToUse = nil
end

state.corpseToLoot = nil

function state.handleMoveToCorpseState()

end

function state.handleOpenCorpseState()

end

function state.handleLootingState()

end

return state