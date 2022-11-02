local mq = require('mq')

local STATES = {
    TRAVEL_TO_REQUEST = 'TRAVEL_TO_REQUEST',
    SELLING = 'SELLING',
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
    ALTERNATE = 'ALTERNATE',
}
local currentState = STATES.TRAVEL_TO_REQUEST

local LDON = {
    -- butcherblock
    [68] = {
        ADVENTURE_TYPE = 3, -- mob count
        RECRUITER = 'Xyzelauna_Tu`Valzir',
        ENTRANCE_ZONE_ID = 57,
        ENTRANCES = {
            ['unearthed grave'] = '/nav loc -111.31 3861.35 -39.73',
            ['find a crypt'] = '/nav loc -766.75 3824.95 1.84',
        },
        EXITS = {
            [233] = '/nav loc -365.54, -593.13, 8.076553',
            [248] = '/nav loc -644.42, -144.46, 1.7245864',
            [253] = '/nav loc 373.40, -599.27, 1.967324',
            [268] = '/nav loc -321.26, -362.32, 18.24032',
            [276] = '/nav loc 542.94, 256.44, 4.7169895', -- (MISTPRTL700E)
        },
        EXIT_COMMAND = nil,
        EXIT_COMMAND_DELAY = 1000,
        INSTANCE_ZONE_IDS = {233,238,243,248,253,258,263,268,272,276}, -- mmcx
        MAGUS_PHRASE = 'butcherblock',
        OTHER_RELATED_ZONES = {54,}, -- gfaydark
    },
    -- ecommons
    [22] = {
        ADVENTURE_TYPE = 3, -- mob count
        RECRUITER = 'Periac Windfell',
        ENTRANCE_ZONE_ID = 35,
        ENTRANCES = {
            ['through a cave'] = '/nav loc -2134.39 1347.20 -97.4'-- '/nav door RUJPORTAL701',-- '/nav loc 5 -222 129.58',
        },
        ENTRANCEDOOR = {
            ['through a cave'] = 'RUJPORTAL701',
        },
        EXITS = {
            [230] = '/nav door RUJPORTAL701E',
            [235] = '/nav door RUJPORTAL701E',
            [240] = '/nav door RUJPORTAL701E',
            [245] = '/nav door RUJPORTAL701E',
            [250] = '/nav door RUJPORTAL700BE',
            [255] = '/nav door RUJPORTAL700BE',
            [260] = '/nav door RUJPORTAL701E',
            [265] = '/nav door RUJPORTAL700BE',
            [269] = '/nav door RUJPORTAL700BE',
            [273] = '/nav door RUJPORTAL700BE',
        },
        EXIT_COMMAND = nil,
        EXIT_COMMAND_DELAY = 1000,
        INSTANCE_ZONE_IDS = {230,235,240,245,250,255,260,265,269,273}, -- rujx
        MAGUS_PHRASE = 'commonlands',
        AFTER_MAGUS_COMMAND = '/nav loc -1455.03 977.42 -26.69',
        OTHER_RELATED_ZONES = {},--34,}, -- nro
        DONE_THRESHOLD=20,
    },
    -- everfrost
    [30] = {
        ADVENTURE_TYPE = 3, -- mob count
        RECRUITER = 'Mannis McGuyett',
        ENTRANCE_ZONE_ID = 30,
        ENTRANCES = {
            ['snowy mine'] = '/nav loc 2739.42 -4684.45 -105.04', -- /nav loc 2772.21 -4726.54 -97.27
            ['glimmering portal of magic'] = '/nav loc -841.47 -5460 188',
        },
        EXITS = {
            [232] = '/nav door MPORTAL700E', --'/nav loc 547, 635, -89.311'
            [237] = '/nav door MPORTAL700E',
            [242] = '/nav door MPORTAL700E',
            [247] = '/nav door MPORTAL700E',
            [252] = '/nav door MPORTAL700E',
            [257] = '/nav door MPORTAL700E',
            [262] = '/nav door MPORTAL700E',
            [267] = '/nav door MPORTAL700E',
            [271] = '/nav door MPORTAL700E',
            [275] = '/nav door MPORTAL700E',
        },
        EXIT_COMMAND = nil,
        EXIT_COMMAND_DELAY = 1000,
        INSTANCE_ZONE_IDS = {232,237,242,247,252,257,262,267,271,275}, -- mirx
        MAGUS_PHRASE = 'everfrost',
        OTHER_RELATED_ZONES = {},
        DONE_THRESHOLD = 15,
    },
    -- north ro
    [34] = {
        ADVENTURE_TYPE = 3, -- mob count
        RECRUITER = 'Escon Quickbow',
        ENTRANCE_ZONE_ID = 34,
        ENTRANCES = {
            ['quicksand pit'] = '/nav loc -949.12 236.84 -47.76257',
        },
        EXITS = {
            [231] = '/nav door THPRTL700E',
            [236] = '/nav door THPRTL700E',
            [241] = '/nav door THPRTL700E',
            [246] = '/nav door THPRTL700E',
            [251] = '/nav door THPRTL700E',
            [256] = '/nav door THPRTL700E',
            [261] = '/nav door THPRTL700E',
            [266] = '/nav door THPRTL700E',
            [270] = '/nav door THPRTL700E',
            [274] = '/nav door THPRTL700E',
        },
        EXIT_COMMAND = '/dgga /multiline ; /keypress forward hold ; /timed 60 /keypress forward',
        EXIT_COMMAND_DELAY = 6000,
        INSTANCE_ZONE_IDS = {231,236,241,246,251,256,261,266,279,274}, -- takx
        MAGUS_PHRASE = 'North Ro',
        OTHER_RELATED_ZONES = {},
        DONE_THRESHOLD = 15,
    },
    -- south ro
    [35] = {
        ADVENTURE_TYPE = 2, -- single boss
        RECRUITER = 'Kallei Ribblok',
        ENTRANCE_ZONE_ID = 46, -- innothule only, ignore guk (boss type only ignores guk?)
        ENTRANCES = {
            ['rotting tree trunk'] = '/nav door GKPORTAL700'--'/nav loc 940.77 569.75 16.65',
            --['barricaded door'] = '/nav loc 440.64 223.66 -12.81', guktop (65)
        },
        ENTRANCEDOOR = {
            ['rotting tree trunk'] = 'GKPORTAL700',
        },
        EXITS = {
            [229] = '/nav door GKPORTAL701E',
            [234] = '/nav door GKPORTAL701E',
            [239] = '/nav door GKPORTAL701E',
            [244] = '/nav door GKPORTAL701E',
            [249] = '/nav door GKPORTAL701E',
            [254] = '/nav door GKPORTAL701E',
            [259] = '/nav door GKPORTAL701E',
            [264] = '/nav door GKPORTAL701E',
        },
        EXIT_COMMAND = nil,
        EXIT_COMMAND_DELAY = 1000,
        INSTANCE_ZONE_IDS = {229,234,239,244,249,254,259,264}, -- gukx
        MAGUS_PHRASE = 'South Ro',
        OTHER_RELATED_ZONES = {},
    }
}

local currentZoneID = 0
local ldonRequestZoneID = 0
local ldonEntranceZoneID = 0
local ldonEntranceText = nil
local lastRequestTime = nil
local endOnSuccess = false

local doAlternate = false
local alternate = nil
local currentAlternate = nil

local args = {...}
if #args < 1 then
    print('Usage: /lua run ldon tankname')
    return
end
local tankname = args[1]
if #args == 2 then
    ldonRequestZoneID = tonumber(args[2])
end

local function printf(...)
    print('\ay[\ax\atLDON\ax\ay]\ax ' .. string.format(...))
end

local function allPresent(zoneonly)
    mq.delay(5000)
    local groupSize = mq.TLO.Group.GroupSize()
    if not groupSize then return false end
    for i=1,mq.TLO.Group.GroupSize()-1 do
        local member = mq.TLO.Group.Member(i)
        if zoneonly then
            if not member.Spawn() then return false end
        else
            local distance = member.Distance3D() or 100
            if distance > 15 then return false end
        end
    end
    return true
end

local function goToMagus(who)
    -- wait a few seconds to see the spawn incase this is called before totally done zoning
    -- or something weird like that
    local magusSpawn = mq.TLO.Spawn('npc magus')
    mq.delay(5000, function() return magusSpawn() end)
    local command = '/nav spawn npc magus | dist=10'
    if who == 'all' then
        command = '/dgga ' .. command
    end
    if not mq.TLO.Navigation.Active() then
        mq.cmd(command)
    end
    mq.delay(120000, function() return magusSpawn.Distance3D() < 15 end)
    command = '/mqt npc magus'
    if who == 'all' then
        command = '/dgga ' .. command
    end
    mq.cmd(command)
    mq.delay(200, function() return mq.TLO.Target.ID() == magusSpawn.ID() end)
end

local function takeMagus(destination, who)
    if who ~= 'all' or allPresent() then
        local prefix = ''
        if who == 'all' then prefix = '/dgga ' end
        mq.cmd('/aqoa pause on')
        mq.delay(500)
        mq.cmdf('%s/mqt npc magus', prefix)
        mq.delay(1000)
        if not destination then
            ldonEntranceZoneID = LDON[alternate[currentAlternate]].ENTRANCE_ZONE_ID
            ldonRequestZoneID = alternate[currentAlternate]
            if currentAlternate == 1 then
                currentAlternate = 2
            else
                currentAlternate = 1
            end
            destination = LDON[ldonRequestZoneID].MAGUS_PHRASE
        end
        if who == 'all' then
            for i=1,mq.TLO.Group.GroupSize() do
                local member = mq.TLO.Group.Member(i)
                mq.cmdf('/dex %s /say %s', member.CleanName(), destination)
                mq.delay(1000)
            end
        end
        mq.cmdf('/say %s', destination)
        mq.delay(30000, function() return mq.TLO.Zone.ID() == ldonRequestZoneID end)
        if who == 'all' then
            mq.delay(30000, function() return allPresent() end)
            if allPresent() then
                currentState = STATES.TRAVEL_TO_REQUEST
            else
                mq.cmd('/beep')
                mq.cmd('toons are missing, fixit')
                mq.cmd('/popcustom 5 toons are missing, fixit')
            end
        end
        mq.cmd('/aqoa pause off')
    end
end

local function sell()
    goToMagus()
    mq.cmdf('/%s sell', mq.TLO.Me.Class.ShortName())
    mq.delay(1000)
    mq.delay(60000, function() return not mq.TLO.Window('MerchantWnd').Open() end)
end

-- Click button to request new adventure
local function requestTask()
    mq.cmd('/notify AdventureRequestWnd AdvRqst_RiskCombobox ListSelect 2')
    mq.cmdf('/notify AdventureRequestWnd AdvRqst_TypeCombobox ListSelect %s', LDON[ldonRequestZoneID].ADVENTURE_TYPE)
    mq.delay(100)
    mq.cmd('/notify AdventureRequestWnd AdvRqst_RequestButton leftmouseup')
    mq.delay(5000, function() return mq.TLO.Window('AdventureRequestWnd/AdvRqst_AcceptButton').Enabled() end)
    ldonEntranceText = mq.TLO.Window('AdventureRequestWnd/AdvRqst_NPCText').Text()
    mq.cmd('/notify AdventureRequestWnd AdvRqst_AcceptButton leftmouseup')
end

-- Move to LDON request NPC
local function goToTaskGiver()
    -- wait a few seconds to see the spawn incase this is called before totally done zoning
    -- or something weird like that
    mq.delay(5000, function() return mq.TLO.Spawn(('npc %s'):format(LDON[currentZoneID].RECRUITER))() end)
    if not mq.TLO.Navigation.Active() and mq.TLO.Zone.ID() == ldonRequestZoneID and mq.TLO.Spawn(('npc %s'):format(LDON[currentZoneID].RECRUITER)).Distance3D() > 15 then
        mq.cmdf('/nav spawn npc %s | dist=10', LDON[currentZoneID].RECRUITER)
        mq.delay(100)
        mq.delay(30000, function() return not mq.TLO.Navigation.Active() end)
    end
end

-- Get new adventure
local function getTask()
    mq.cmdf('/%s pause on', mq.TLO.Me.Class.ShortName())
    goToTaskGiver()
    mq.cmdf('/mqt npc %s', LDON[currentZoneID].RECRUITER)
    mq.delay(100, function() return mq.TLO.Target.CleanName() == LDON[currentZoneID].RECRUITER end)
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
    local newRequestTime = os.date('%I:%M %p')
    printf('New adventure requested at: \ag%s\ax, previous: \ag%s\ax', newRequestTime, lastRequestTime)
    lastRequestTime = newRequestTime
    return true
end

-- Move group leader back to LDON request NPC
local function travelToRequestZone()
    if ldonRequestZoneID == 22 then
        if currentZoneID == 46 then
            -- innothule to sro to take magus
            if not mq.TLO.Navigation.Active() then
                mq.cmd('/travelto sro')
            end
        elseif currentZoneID == 35 then
            -- take magus to commonlands
            goToMagus('all')
            takeMagus('commonlands')
        end
    else
        -- try to move people away from non-meshed zone outs
        if not mq.TLO.Navigation.Active() then
            printf('Traveling to request zone')
            mq.cmdf('/travelto %s', mq.TLO.Zone(ldonRequestZoneID).ShortName())
        end
    end
end

-- Move to LDON instance
local function travelToEntranceZone()
    if ldonRequestZoneID == 22 then
        goToMagus()
        takeMagus('south ro')
    else
        if not mq.TLO.Navigation.Active() then
            printf('Traveling to entrance zone')
            -- todo: make everyone travel there
            mq.cmdf('/dgga /travelto %s', mq.TLO.Zone(ldonEntranceZoneID).ShortName())
        end
    end
end

-- Zone into LDON instance
local function enterTask()
    -- todo: wait for whole group travel
    mq.delay(5000)
    mq.cmd('/travelto stop')
    -- nav group to spot
    printf('Adventure description: %s', ldonEntranceText)
    local entranceDoor = ''
    for text,loc in pairs(LDON[ldonRequestZoneID].ENTRANCES) do
        printf('%s : %s', text, loc)
        if ldonEntranceText:lower():find(text) then
            mq.cmdf('/dgga %s', loc)
            if LDON[ldonRequestZoneID].ENTRANCEDOOR then
                entranceDoor = LDON[ldonRequestZoneID].ENTRANCEDOOR[text]
            end
        end
    end
    mq.delay(100)
    -- wait for nav
    mq.delay(120000, function() return not mq.TLO.Navigation.Active() end)
    -- wait for group
    mq.delay(60000, function() return allPresent() end)
    if allPresent() then
        mq.cmdf('/dgga /multiline ; /doortarget %s; /timed 5 /click left door', entranceDoor)
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
    if not LDON[ldonRequestZoneID].EXITS[currentZoneID] then
        mq.cmdf('/g [LDON] Zone missing from list, copy/paste this! ID=%s cmd=/nav loc %s, %s, %s', currentZoneID, mq.TLO.Me.Y(), mq.TLO.Me.X(), mq.TLO.Me.Z())
        mq.cmd('/beep')
        LDON[ldonRequestZoneID].EXITS[currentZoneID] = ('/nav loc %s, %s, %s'):format(mq.TLO.Me.Y(), mq.TLO.Me.X(), mq.TLO.Me.Z())
    end
    mq.cmd('/aqoa mode chase')
    mq.delay(100)
    mq.cmd('/aqoa pause off')
    mq.delay(100)
    local tankclass = mq.TLO.Spawn('pc '..tankname).Class.ShortName()
    mq.cmdf('/dex %s /%s mode huntertank', tankname, tankclass)
end

-- Get all toons to zone out of the LDON instance
local function leaveTask()
    mq.delay(1000)
    mq.cmdf('/dgga %s', LDON[ldonRequestZoneID].EXITS[currentZoneID])
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
    if ldonRequestZoneID then
        ldonEntranceZoneID = LDON[ldonRequestZoneID].ENTRANCE_ZONE_ID
        return true
    end
    for requestZoneID,relatedZones in pairs(LDON) do
        if currentZoneID == requestZoneID or currentZoneID == relatedZones.ENTRANCE_ZONE_ID then
            ldonRequestZoneID = requestZoneID
            ldonEntranceZoneID = relatedZones.ENTRANCE_ZONE_ID
            return true
        end
        for _,zoneid in ipairs(relatedZones.INSTANCE_ZONE_IDS) do
            if currentZoneID == zoneid then
                ldonRequestZoneID = requestZoneID
                ldonEntranceZoneID = relatedZones.ENTRANCE_ZONE_ID
                return true
            end
        end
        for _,zoneid in ipairs(relatedZones.OTHER_RELATED_ZONES) do
            if currentZoneID == zoneid then
                ldonRequestZoneID = requestZoneID
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
    if endOnSuccess then
        printf('Dungeon completed successfully. Stop clearing the dungeon')
        mq.cmd('/aqoa mode manual')
        currentState = STATES.RETURN_TO_ENTRANCE
    end
end

mq.event('success', '#*#You have successfully completed your adventure.#*#', success)

local function cmdLDON(state, otherzone)
    if state == 'help' then
        printf('Valid States:')
        for _,state in pairs(STATES) do
            printf(' - ' .. state)
        end
    elseif state == 'endonsuccess' then
        endOnSuccess = not endOnSuccess
        printf('End On Success: %s', endOnSuccess)
    elseif state == 'alt' then
        if otherzone and LDON[tonumber(otherzone)] then
            doAlternate = true
            alternate = {ldonRequestZoneID, tonumber(otherzone)}
            currentAlternate = 2
            printf('Will alternate to %s', mq.TLO.Zone(otherzone)())
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
            currentState = STATES.SELLING
            mq.delay(1000)
        end
    elseif currentState == STATES.SELLING then
        printf('Selling')
        sell()
        currentState = STATES.REQUESTING
    elseif currentState == STATES.REQUESTING then
        if not validateTask() then
            printf('Requesting an adventure')
            getTask()
        else
            printf('Adventure acquired, moving on')
            currentState = STATES.TRAVEL_TO_ENTRANCE
            mq.delay(1000)
        end
    elseif currentState == STATES.TRAVEL_TO_ENTRANCE then
        if currentZoneID == 35 and ldonEntranceZoneID == 46 and not mq.TLO.Navigation.Active() then
            if LDON[ldonRequestZoneID].AFTER_MAGUS_COMMAND then
                mq.cmdf('/dgga %s', LDON[ldonRequestZoneID].AFTER_MAGUS_COMMAND)
                mq.delay(10000)
            end
        end
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
        if LDON[ldonRequestZoneID].AFTER_MAGUS_COMMAND then
            mq.cmdf('/dgga %s', LDON[ldonRequestZoneID].AFTER_MAGUS_COMMAND)
            mq.delay(10000)
        end
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
        if spawnCount < (LDON[ldonRequestZoneID].DONE_THRESHOLD or 5) then
            if mq.TLO.Me.XTarget() < 2 then
                printf('Stop clearing the dungeon')
                mq.cmd('/aqoa mode manual')
                mq.delay(500)
                currentState = STATES.RETURN_TO_ENTRANCE
            else
                printf('Done with mobs but still mobs on xtarget')
                for i=1,13 do
                    mq.cmdf('/xtarget remove %s', i)
                end
            end
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
            if LDON[ldonRequestZoneID].EXIT_COMMAND then
                mq.cmd(LDON[ldonRequestZoneID].EXIT_COMMAND)
                mq.delay(LDON[ldonRequestZoneID].EXIT_COMMAND_DELAY)
            end
            if doAlternate then
                currentState = STATES.ALTERNATE
            elseif currentZoneID == ldonRequestZoneID then
                currentState = STATES.TRAVEL_TO_REQUEST
            else
                currentState = STATES.ORIGIN
            end
        end
    elseif currentState == STATES.ORIGIN then
        if currentZoneID ~= mq.TLO.Zone('poknowledge').ID() then
            if mq.TLO.Me.AltAbilityReady('Origin')() then
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
            mq.cmdf('/say %s', LDON[ldonRequestZoneID].MAGUS_PHRASE)
            mq.delay(30000, function() return mq.TLO.Zone.ID() ~= mq.TLO.Zone('poknowledge').ID() end)
            currentState = STATES.TRAVEL_TO_REQUEST
        end
    elseif currentState == STATES.ALTERNATE then
        printf('Switching to next LDON zone')
        if allPresent(true) then
            if currentZoneID == 46 then
                mq.cmdf('/dgga /travelto sro')

            end
            mq.cmd('/dgga /nav spawn magus')
            mq.delay(100)
            mq.delay(120000, function() return not mq.TLO.Navigation.Active() end)
            if allPresent() then
                mq.cmd('/aqoa pause on')
                mq.delay(500)
                mq.cmd('/dgga /mqt magus')
                mq.delay(1000)
                ldonEntranceZoneID = LDON[alternate[currentAlternate]].ENTRANCE_ZONE_ID
                ldonRequestZoneID = alternate[currentAlternate]
                if currentAlternate == 1 then
                    currentAlternate = 2
                else
                    currentAlternate = 1
                end
                if ldonRequestZoneID ~= currentZoneID then
                    local MAGUS_PHRASE = LDON[ldonRequestZoneID].MAGUS_PHRASE
                    if ldonRequestZoneID == 22 then MAGUS_PHRASE = 'South Ro' end
                    for i=1,mq.TLO.Group.GroupSize() do
                        local member = mq.TLO.Group.Member(i)
                        mq.cmdf('/dex %s /say %s', member.CleanName(), MAGUS_PHRASE)
                        mq.delay(1000)
                    end
                    mq.cmdf('/say %s', LDON[ldonRequestZoneID].MAGUS_PHRASE)
                    --mq.cmdf('/dgga /say %s', LDON[ldonRequestZoneID].MAGUS_PHRASE)
                    mq.delay(30000, function() return mq.TLO.Zone.ID() == ldonRequestZoneID end)
                    mq.delay(30000, function() return allPresent() end)
                    if ldonRequestZoneID == 22 or allPresent() then
                        currentState = STATES.TRAVEL_TO_REQUEST
                    else
                        mq.cmd('/beep')
                        mq.cmd('toons are missing, fixit')
                        mq.cmd('/popcustom 5 toons are missing, fixit')
                    end
                end
                mq.cmd('/aqoa pause off')
            end
        end
    end

    mq.delay(1000)
end