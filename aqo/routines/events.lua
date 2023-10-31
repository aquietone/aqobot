--- @type Mq
local mq = require('mq')
local config = require('interface.configuration')
local debuff = require('routines.debuff')
local mez = require('routines.mez')
local camp = require('routines.camp')
local logger = require('utils.logger')
local movement = require('utils.movement')
local timer = require('utils.timer')
local mode = require('mode')
local state = require('state')

local aqo
local events = {}

---Initialize common event handlers.
function events.init(_aqo)
    aqo = _aqo

    mq.event('zoned', 'You have entered #*#', events.zoned)
    mq.event('cannotSee', '#*#cannot see your target#*#', events.movecloser)
    mq.event('tooFar', '#*#Your target is too far away#*#', events.movecloser)
    mq.event('eventDeadReleased', '#*#Returning to Bind Location#*#', events.eventDead)
    mq.event('eventDead', 'You died.', events.eventDead)
    mq.event('eventDeadSlain', 'You have been slain by#*#', events.eventDead)
    mq.event('eventResist', 'Your target resisted the #1# spell#*#', events.eventResist)
    mq.event('eventOMMMask', '#*#You feel a gaze of deadly power focusing on you#*#', events.eventOMMMask)
    mq.event('eventCannotRez', '#*#This corpse cannot be resurrected#*#', events.cannotRez)
    mq.event('eventFizzles', 'Your #*#spell fizzles#*#', events.fizzled)
    mq.event('eventMissedNote', 'You miss a note, bringing your song to a close#*#', events.fizzled)
    mq.event('eventInterrupt', 'Your spell is interrupted#*#', events.interrupted)
    mq.event('eventInterruptedB', 'Your casting has been interrupted#*#', events.interrupted)
end

function events.initClassBasedEvents()
    -- setup events based on whether certain options are defined, not whether they are enabled.
    debuff.setupEvents()
    if aqo.class.OPTS.MEZST or aqo.class.OPTS.MEZAE then
        mez.setupEvents()
    end
    if mq.TLO.Me.AltAbility('Tranquil Blessings')() then
        mq.event('eventTranquil', '#*# tells #*#,#*#\'tranquil\'', events.eventTranquil)
    end
    if aqo.class.OPTS.SERVEBUFFREQUESTS then
        mq.event('eventRequests', '#1# tells #*#,#*#\'#2#\'', events.eventRequest)
    else
        mq.event('eventGearrequest', '#1# tells #*#,#*#\'gear #2#\'', events.eventGear)
    end
    mq.event('eventepic', '#*# tells #*#,#*#\'epicburn\'', events.epicburn)
end

function events.zoned()
    state.resetCombatState()
    if state.currentZone == mq.TLO.Zone.ID() then
        -- evac'd
        camp.setCamp()
        movement.stop()
    end
    state.currentZone = mq.TLO.Zone.ID()
    mq.cmd('/pet ghold on')
    if not state.paused and mode.currentMode:isPullMode() then
        config.MODE.value = 'manual'
        mode.currentMode = mode.fromString('manual')
        camp.setCamp()
        movement.stop()
    end
    state.justZonedTimer:reset()
    mq.cmd('/stopcast')
end

function events.movecloser()
    if mode.currentMode:isAssistMode() and not state.paused then
        movement.navToTarget(nil, 1000)
    end
end

---Event callback for handling spell resists from mobs
---@param line any
---@param spell_name any
function events.eventResist(line, spell_name)
    local target = mq.TLO.Target.CleanName()
    if target then
        state.resists[spell_name] = (state.resists[spell_name] or 0) + 1
        logger.print(logger.logLine('\at%s\ax resisted spell \ag%s\ax, resist count = \ay%s\ax', target, spell_name, state.resists[spell_name]))
    end
end

---Reset combat state in the event of death.
function events.eventDead()
    logger.print(logger.logLine('HP hit 0. what do!'))
    state.resetCombatState()
    movement.stop()
end

function events.eventGear(line, requester, requested)
    requested = requested:lower()
    local slot = requested:gsub('gear ', '')
    if slot == 'listslots' then
        mq.cmd('/gu earrings, rings, leftear, rightear, leftfinger, rightfinger, face, head, neck, shoulder, chest, feet, arms, leftwrist, rightwrist, wrists, charm, powersource, mainhand, offhand, ranged, ammo, legs, waist, hands')
    elseif slot == 'earrings' then
        local leftear = mq.TLO.Me.Inventory('leftear')
        local rightear = mq.TLO.Me.Inventory('rightear')
        mq.cmdf('/gu leftear: %s, rightear: %s', leftear.ItemLink('CLICKABLE')(), rightear.ItemLink('CLICKABLE')())
    elseif slot == 'rings' then
        local leftfinger = mq.TLO.Me.Inventory('leftfinger')
        local rightfinger = mq.TLO.Me.Inventory('rightfinger')
        mq.cmdf('/gu leftfinger: %s, rightfinger: %s', leftfinger.ItemLink('CLICKABLE')(), rightfinger.ItemLink('CLICKABLE')())
    elseif slot == 'wrists' then
        local leftwrist = mq.TLO.Me.Inventory('leftwrist')
        local rightwrist = mq.TLO.Me.Inventory('rightwrist')
        mq.cmdf('/gu leftwrist: %s, rightwrist: %s', leftwrist.ItemLink('CLICKABLE')(), rightwrist.ItemLink('CLICKABLE')())
    else
        if mq.TLO.Me.Inventory(slot)() then
            mq.cmdf('/gu %s: %s', slot, mq.TLO.Me.Inventory(slot).ItemLink('CLICKABLE')())
        end
    end
end

local function validateRequester(requester)
    return mq.TLO.Group.Member(requester)() or mq.TLO.Raid.Member(requester)() or mq.TLO.Spawn('='..requester).Guild() == mq.TLO.Me.Guild()
end

function events.eventRequest(line, requester, requested)
    requested = requested:lower()
    if requested:find('^gear .+') then
        return events.eventGear(line, requester, requested)
    end
    if aqo.class.isEnabled('SERVEBUFFREQUESTS') and validateRequester(requester) then
        local tranquil = false
        local mgb = false
        if requested:find('^tranquil') then
            requested = requested:gsub('tranquil','')
            tranquil = true
        end
        if requested:find('^mgb') then
            requested = requested:gsub('mgb','')
            mgb = true
        end
        if requested:find(' '..mq.TLO.Me.CleanName():lower()..'$') then
            requested = requested:gsub(' '..mq.TLO.Me.CleanName():lower(),'')
        end
        if requested:find(' pet$') then
            requested = requested:gsub(' pet', '')
            requester = mq.TLO.Spawn('pc '..requester).Pet.CleanName()
            print('Pet Name for request: ', requester)
        end
        if requested == 'list buffs' then
            local buffList = ''
            for alias,ability in pairs(aqo.class.requestAliases) do
                buffList = ('%s | %s : %s'):format(buffList, alias, ability.Name)
            end
            mq.cmdf('/t %s %s', requester, buffList)
            return
        end
        if requested == 'armpet' and state.class == 'mag' then
            table.insert(aqo.class.requests, {requester=requester, requested='armpet', expiration=timer:new(15000)})
            return
        end
        local requestedAbility = aqo.class.getAbilityForAlias(requested)
        if requestedAbility then
            local expiration = timer:new(15000)
            table.insert(aqo.class.requests, {requester=requester, requested=requestedAbility, expiration=expiration, tranquil=tranquil, mgb=mgb})
        end
    end
end

function events.eventTranquil()
    if mq.TLO.Me.CombatState() ~= 'COMBAT' and mq.TLO.Raid.Members() > 0 then
        mq.delay(5000, function() return not mq.TLO.Me.Casting() end)
        if aqo.class.tranquil:use() then mq.cmd('/rs Tranquil Blessings used') end
    end
end

local currentMask
function events.eventOMMMask()
    currentMask = mq.TLO.Me.Inventory('face').Name()
    if not mq.TLO.FindItem('=Mirrored Mask')() then
        mq.cmdf('i suck and have no mirrored mask')
        return
    else
        mq.cmd('/stopcast')
        mq.delay(1)
        if currentMask ~= 'Mirrored Mask' then
            mq.cmd('/exchange "Mirrored Mask" face')
            mq.delay(250)
        end
    end
    if mq.TLO.Me.Inventory('face').Name() == 'Mirrored Mask' then
        mq.cmd('/useitem "Mirrored Mask"')
        mq.delay(1000)
        if not mq.TLO.Me.Song('Reflective Skin')() then
            -- try again
            mq.cmd('/useitem "Mirrored Mask"')
            mq.delay(1000)
        end
        mq.cmdf('/exchange "%s" face', currentMask)
        mq.delay(250)
    end
end

function events.cannotRez()
    state.cannotRez = true
end

function events.fizzled()
    state.fizzled = true
end

function events.interrupted()
    state.interrupted = true
end

function events.epicburn()
    aqo.class.useEpic()
end

return events