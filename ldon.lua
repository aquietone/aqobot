local mq = require('mq')

local STATES = {
    TRAVEL_TO_REQUEST = 'TRAVEL_TO_REQUEST',
    REQUESTING = 'REQUESTING',
    TRAVEL_TO_ENTRANCE = 'TRAVEL_TO_ENTRANCE',
    MOVE_TO_ENTRANCE = 'MOVE_TO_ENTRANCE',
    ENTERING = 'ENTERING',
    BEGIN_CLEARING = 'BEGIN_CLEARING',
    CLEARING = 'CLEARING',
    STOP_CLEARING = 'STOP_CLEARING',
    RETURN_TO_ENTRANCE = 'RETURN_TO_ENTRANCE',
    EXITING = 'EXITING',
    ORIGIN = 'ORIGIN',
    TAKE_MAGUS = 'TAKE_MAGUS',
}
local currentState = STATES.TRAVEL_TO_REQUEST

local RECRUITERS = {
    butcher = 'Xyzelauna_Tu`Valzir',
    sro = 'Kallei Ribblok',
    commons = 'Periac Windfell',
    nro = 'Escon Quickbow',
    everfrost = 'Mannis McGuyett',
}

local ENTRANCES = {
    [57] = {
        ['unearthed grave'] = '/nav loc -111.31 3861.35 -39.73',
        ['find a crypt'] = '/nav loc -766.75 3824.95 1.84',
    },
    [413] = {
        ['rotting tree trunk'] = '/nav loc 940.77 569.75 16.65',
    },
    [65] = {
        ['barricaded door'] = '/nav loc -9.59 -1148.92 26.51',
    },
    [34] = {
        ['quicksand pit in northern ro.'] = '/nav loc -921.13, 125.62, -37.18640',
    },
    [393] = {
        ['through a cave'] = '/nav loc 5 -222 129.58',
    },
    [30] = {
        ['snowy mine'] = '/nav loc 2739.42 -4684.45 -105.04', -- /nav loc 2772.21 -4726.54 -97.27
        ['glimmering portal of magic'] = '/nav loc -841.47 -5460 188',
    }
}
local EXITS = {
    -- mistmoore
    [248] = '/nav loc -644.42, -144.46, 1.7245864',
    [253] = '/nav loc 373.40, -599.27, 1.967324',
    [233] = '/nav loc -365.54, -593.13, 8.076553',
    [268] = '/nav loc -321.26, -362.32, 18.24032',
    [276] = '/nav loc 542.94, 256.44, 4.7169895', -- (MISTPRTL700E)
    -- takish
    [231] = '/nav door THPRTL700E',
    [236] = '/nav door THPRTL700E',
    [246] = '/nav door THPRTL700E',
    [241] = '/nav door THPRTL700E',
    [251] = '/nav door THPRTL700E',
    [256] = '/nav door THPRTL700E',
    [261] = '/nav door THPRTL700E',
    [270] = '/nav door THPRTL700E',
    [274] = '/nav door THPRTL700E',
    -- rujarkian

    -- guk

    -- miraguls

}

local LDON_RELATED_ZONES = {
    butcher = { --  Mistmoore catacombs
        REQUEST_ZONE_ID = 68, -- butcher
        ENTRANCE_ZONE_ID = 57, -- lfaydark
        INSTANCE_ZONE_IDS = {233,238,243,248,253,258,263,268,272,276}, -- mmcx
        OTHER = {54,}, -- gfaydark
        MAGUS_PHRASE = 'butcherblock'
    },
    sro = { -- Guk
        REQUEST_ZONE_ID = 393, -- sro
        ENTRANCE_ZONE_ID = {413,65}, -- innothule, guktop
        INSTANCE_ZONE_IDS = {229,234,239,244,249,254,259,264}, -- gukx
        OTHER = {}, --
        MAGUS_PHRASE = 'south ro'
    },
    nro = { -- Takish
        REQUEST_ZONE_ID = 34, -- nro
        ENTRANCE_ZONE_ID = 34, -- nro
        INSTANCE_ZONE_IDS = {231,236,241,246,251,256,261,266,279,274}, -- takx
        OTHER = {}, --
        MAGUS_PHRASE = 'north ro'
    },
    commons = { -- Rujarkian
        REQUEST_ZONE_ID = 408, -- commonlands
        ENTRANCE_ZONE_ID = 393, -- sro
        INSTANCE_ZONE_IDS = {230,235,240,245,250,255,260,265,269,273}, -- rujx
        OTHER = {}, --
        MAGUS_PHRASE = 'commonlands'
    },
    everfrost = { -- Miraguls
        REQUEST_ZONE_ID = 30, -- everfrost
        ENTRANCE_ZONE_ID = 30, -- everfrost
        INSTANCE_ZONE_IDS = {257,252,275,262,247,237,267,232,242,271}, -- mirx
        OTHER = {}, --
        MAGUS_PHRASE = 'everfrost'
    }
}

-- try adding more players

local currentZoneID = 0
local ldonRequestZoneID = 0
local ldonEntranceZoneID = 0
local ldonEntranceText = nil
local didSell = false

local args = {...}
if #args ~= 1 then
    print('Usage: /lua run ldon tankname')
    return
end
local tankname = args[1]

local function printf(...)
    print('\ay[\ax\atLDON\ax\ay]\ax ' .. string.format(...))
end

local function allPresent()
    mq.delay(5000)
    for i=1,mq.TLO.Group.GroupSize()-1 do
        local member = mq.TLO.Group.Member(i)
        local distance = member.Distance3D() or 100
        if distance > 15 then return false end
    end
    return true
end

local function sell()
    mq.delay(10000, function() return mq.TLO.Spawn('npc magus')() end)
    mq.cmdf('/%s pause on', mq.TLO.Me.Class.ShortName())
    mq.cmd('/nav spawn magus')
    mq.delay(60000, function() return mq.TLO.Spawn('npc magus').Distance3D() < 15 end)
    mq.cmd('/mqt magus')
    mq.delay(500)
    mq.cmdf('/%s sell', mq.TLO.Me.Class.ShortName())
    mq.delay(1000)
    mq.delay(60000, function() return not mq.TLO.Window('MerchantWnd').Open() end)
    didSell = true
end

-- Click button to request new adventure
local function requestTask()
    mq.cmd('/notify AdventureRequestWnd AdvRqst_RiskCombobox ListSelect 2')
    mq.cmd('/notify AdventureRequestWnd AdvRqst_TypeCombobox ListSelect 3')
    mq.delay(100)
    mq.cmd('/notify AdventureRequestWnd AdvRqst_RequestButton leftmouseup')
    mq.delay(5000, function() return mq.TLO.Window('AdventureRequestWnd/AdvRqst_AcceptButton').Enabled() end)
    ldonEntranceText = mq.TLO.Window('AdventureRequestWnd/AdvRqst_NPCText').Text()
    mq.cmd('/notify AdventureRequestWnd AdvRqst_AcceptButton leftmouseup')
end

-- Move to LDON request NPC
local function goToTaskGiver()
    mq.delay(10000, function() return mq.TLO.Spawn(('npc %s'):format(RECRUITERS[mq.TLO.Zone.ShortName()]))() end)
    if not mq.TLO.Navigation.Active() and mq.TLO.Zone.ID() == ldonRequestZoneID and mq.TLO.Spawn(('npc %s'):format(RECRUITERS[mq.TLO.Zone.ShortName()])).Distance3D() > 10 then
        mq.cmdf('/nav spawn npc %s', RECRUITERS[mq.TLO.Zone.ShortName()])
        mq.delay(100)
        mq.delay(30000, function() return not mq.TLO.Navigation.Active() end)
    end
end

-- Get new adventure
local function getTask()
    if not didSell then sell() end
    mq.cmdf('/%s pause on', mq.TLO.Me.Class.ShortName())
    goToTaskGiver()
    mq.cmdf('/mqt npc %s', RECRUITERS[mq.TLO.Zone.ShortName()])
    mq.delay(100, function() return mq.TLO.Target.CleanName() == RECRUITERS[mq.TLO.Zone.ShortName()] end)
    mq.cmd('/click right target')
    mq.delay(1000, function() return mq.TLO.Window('AdventureRequestWnd').Open() end)
    requestTask()
    mq.cmdf('/%s pause off', mq.TLO.Me.Class.ShortName())
end

local function validateTask()
    if mq.TLO.Window('AdventureRequestWnd/AdvRqst_EnterTimeLeftLabel').Text():len() == 0 and mq.TLO.Window('AdventureRequestWnd/AdvRqst_CompleteTimeLeftLabel').Text():len() == 0 then
        return false
    end
    if mq.TLO.Window('AdventureRequestWnd/AdvRqst_NPCText').Text() == 'You are not currently assigned an adventure.' then
        return false
    end
    return true
end

-- Move group leader back to LDON request NPC
local function travelToRequestZone()
    -- try to move people away from non-meshed zone outs
    if not mq.TLO.Navigation.Active() then
        didSell = false
        printf('Traveling to request zone')
        mq.cmdf('/travelto %s', mq.TLO.Zone(ldonRequestZoneID).ShortName())
    end
end

-- Move to LDON instance
local function travelToEntranceZone()
    if not mq.TLO.Navigation.Active() then
        printf('Traveling to entrance zone')
        -- todo: make everyone travel there
        mq.cmdf('/travelto %s', mq.TLO.Zone(ldonEntranceZoneID).ShortName())
    end
end

-- Zone into LDON instance
local function enterTask()
    -- todo: wait for whole group travel
    mq.delay(5000)
    mq.cmd('/travelto stop')
    -- nav group to spot
    for text,loc in pairs(ENTRANCES[currentZoneID]) do
        if ldonEntranceText:lower():find(text) then
            mq.cmdf('/dgga %s', loc)
        end
    end
    mq.delay(100)
    -- wait for nav
    mq.delay(120000, function() return not mq.TLO.Navigation.Active() end)
    -- wait for group
    mq.delay(60000, function() return allPresent() end)
    if allPresent() then
        mq.cmd('/dgga /multiline ; /doortarget ; /timed 5 /click left door')
        mq.delay(10000, function() return mq.TLO.Zone.ID() ~= ldonEntranceZoneID end)
        return true
    else
        return false
    end
end

-- Start huntermode in LDON instance once group has entered
local function beginClearing()
    if currentZoneID == ldonEntranceZoneID then return end
    -- wait for group
    mq.delay(60000, function() return allPresent() end)
    if not EXITS[currentZoneID] then
        mq.cmdf('/g [LDON] Zone missing from list, copy/paste this! ID=%s cmd=/nav loc %s, %s, %s', currentZoneID, mq.TLO.Me.Y(), mq.TLO.Me.X(), mq.TLO.Me.Z())
        mq.cmd('/beep')
        EXITS[currentZoneID] = ('/nav loc %s, %s, %s'):format(mq.TLO.Me.Y(), mq.TLO.Me.X(), mq.TLO.Me.Z())
    end
    mq.cmd('/cwtna mode chase')
    mq.delay(100)
    mq.cmd('/cwtna pause off')
    mq.delay(100)
    local tankclass = mq.TLO.Spawn('pc '..tankname).Class.ShortName()
    mq.cmdf('/dex %s /%s mode huntertank', tankname, tankclass)
end

-- Get all toons to zone out of the LDON instance
local function leaveTask()
    mq.cmdf('/dgga %s', EXITS[currentZoneID])
    mq.delay(100)
    mq.delay(120000, function() return not mq.TLO.Navigation.Active() end)
    -- wait for group
    mq.delay(60000, function() return allPresent() end)
    if allPresent() then
        mq.cmd('/dgga /multiline ; /doortarget ; /timed 5 /click left door')
        mq.delay(10000, function() return mq.TLO.Zone.ID() == ldonEntranceZoneID end)
        return true
    end
end

local function inLDONRelatedZone()
    for _,relatedZones in pairs(LDON_RELATED_ZONES) do
        if currentZoneID == relatedZones.REQUEST_ZONE_ID or currentZoneID == relatedZones.ENTRANCE_ZONE_ID then
            ldonRequestZoneID = relatedZones.REQUEST_ZONE_ID
            ldonEntranceZoneID = relatedZones.ENTRANCE_ZONE_ID
            return true
        end
        for _,zoneid in ipairs(relatedZones.INSTANCE_ZONE_IDS) do
            if currentZoneID == zoneid then
                ldonRequestZoneID = relatedZones.REQUEST_ZONE_ID
                ldonEntranceZoneID = relatedZones.ENTRANCE_ZONE_ID
                return true
            end
        end
        for _,zoneid in ipairs(relatedZones.OTHER) do
            if currentZoneID == zoneid then
                ldonRequestZoneID = relatedZones.REQUEST_ZONE_ID
                ldonEntranceZoneID = relatedZones.ENTRANCE_ZONE_ID
                return true
            end
        end
    end
    return false
end

local function zoned()
    currentZoneID = mq.TLO.Zone.ID()
end

mq.event('zoned', 'You have entered #*#', zoned)

local function success()
    --taskComplete = true
end

mq.event('success', '#*#You have successfully completed your adventure.#*#', success)

local function cmdLDON(state)
    if state == 'help' then
        printf('Valid States:')
        for _,state in pairs(STATES) do
            printf(' - ' .. state)
        end
    elseif STATES[state] then
        currentState = STATES[state]
    else
        printf('Current State: ' .. currentState)
    end
end

mq.bind('/ldon', cmdLDON)

currentZoneID = mq.TLO.Zone.ID()
if not inLDONRelatedZone() then
    return
end

-- haveTask - starts false, becomes true once task requested, becomes false again once zoned out of task

if validateTask() then
    -- already have an active adventure
    ldonEntranceText = mq.TLO.Window('AdventureRequestWnd/AdvRqst_NPCText').Text()
    currentState = STATES.TRAVEL_TO_ENTRANCE
end
-- if already inside

while true do
    mq.doevents()

    if currentState == STATES.TRAVEL_TO_REQUEST then
        if currentZoneID ~= ldonRequestZoneID then
            travelToRequestZone()
        else
            printf('Reached request zone, moving on')
            mq.cmd('/travelto stop')
            currentState = STATES.REQUESTING
            mq.delay(1000)
        end
    elseif currentState == STATES.REQUESTING then
        if not validateTask() then
            printf('Selling and requesting an adventure')
            getTask()
        else
            printf('Adventure acquired, moving on')
            currentState = STATES.TRAVEL_TO_ENTRANCE
            mq.delay(1000)
        end
    elseif currentState == STATES.TRAVEL_TO_ENTRANCE then
        if currentZoneID ~= ldonEntranceZoneID then
            travelToEntranceZone()
        else
            printf('Reached entrance zone, moving on')
            mq.cmd('/travelto stop')
            currentState = STATES.MOVE_TO_ENTRANCE
            mq.delay(1000)
        end
    elseif currentState == STATES.MOVE_TO_ENTRANCE then
        printf('Moving to entrance')
        if enterTask() then
            mq.delay(10000, function() return mq.TLO.Zone.ID() ~= ldonEntranceZoneID end)
            currentState = STATES.ENTERING
        end
    elseif currentState == STATES.ENTERING then
        if currentZoneID ~= ldonEntranceZoneID and allPresent() then
            mq.delay(1000)
            currentState = STATES.BEGIN_CLEARING
        end
    elseif currentState == STATES.BEGIN_CLEARING then
        printf('Begin clearing the dungeon')
        beginClearing()
        currentState = STATES.CLEARING
    elseif currentState == STATES.CLEARING then
        local spawnCount = mq.TLO.SpawnCount('npc')()
        if spawnCount < 5 and mq.TLO.Me.XTarget() < 2 then
            printf('Stop clearing the dungeon')
            mq.cmd('/cwtna mode manual')
            currentState = STATES.RETURN_TO_ENTRANCE
        end
    elseif currentState == STATES.RETURN_TO_ENTRANCE then
        printf('Leaving the dungeon')
        if leaveTask() then
            currentState = STATES.EXITING
        end
    elseif currentState == STATES.EXITING then
        if currentZoneID == ldonEntranceZoneID then
            printf('Zoning out of the dungeon')
            mq.delay(1000)
            mq.cmd('/dgga /multiline ; /keypress forward hold ; /timed 60 /keypress forward')
            mq.delay(6000)
            --currentState = STATES.TRAVEL_TO_REQUEST
            currentState = STATES.ORIGIN
        end
    elseif currentState == STATES.ORIGIN then
        if currentZoneID ~= mq.TLO.Zone('poknowledge').ID() then
            if mq.TLO.Me.AltAbilityReady('Origin')() then
                didSell = false
                printf('Origin to POK')
                mq.cmdf('/%s pause on', mq.TLO.Me.Class.ShortName())
                mq.delay(100)
                mq.cmd('/alt act 331')
                mq.delay(30000, function() return mq.TLO.Zone.ShortName() == 'poknowledge' end)
            else
                currentState = STATES.TRAVEL_TO_REQUEST
            end
        else
            mq.delay(1000)
            currentState = STATES.TAKE_MAGUS
        end
    elseif currentState == STATES.TAKE_MAGUS then
        printf('Taking magus to adventure request zone')
        mq.cmd('/nav spawn Magus Alaria')
        mq.delay(100)
        mq.delay(60000, function() return not mq.TLO.Navigation.Active() end)
        if (mq.TLO.Spawn('Magus Alaria').Distance3D() or 100) < 15 then
            mq.cmd('/mqt npc magus alaria')
            mq.delay(1000)
            mq.cmdf('/say %s', LDON_RELATED_ZONES[mq.TLO.Zone(ldonRequestZoneID).ShortName()].MAGUS_PHRASE)
            mq.delay(30000, function() return mq.TLO.Zone.ID() ~= mq.TLO.Zone('poknowledge').ID() end)
            currentState = STATES.TRAVEL_TO_REQUEST
        end
    end

    mq.delay(1000)
end