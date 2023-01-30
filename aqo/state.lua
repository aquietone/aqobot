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
    amDead = false,
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
}

function state.resetCombatState()
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

return state