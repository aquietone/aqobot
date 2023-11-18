local mq = require('mq')
local actors = require('actors')

local testmb = actors.register("testactor", function (message)
    -- receives nothing
end)

-- Test publishing a status message to aqo mailbox
mq.bind('/testaqo', function() 
    local header = {mailbox = 'aqo', script='aqo'}
    local buffs = {}
    for i=1,42 do
        local aBuff = mq.TLO.Me.Buff(i)
        if aBuff() then
            local buffData = {Name=aBuff.Name(),Duration=aBuff.Duration.TotalSeconds()}
            if aBuff.CounterNumber() > 0 then
                buffData.CounterNumber=aBuff.CounterNumber()
                buffData.CounterType=aBuff.CounterType()
            end
            table.insert(buffs, buffData)
        end
    end
    local songs = {}
    for i=1,20 do
        local aSong = mq.TLO.Me.Song(i)
        if aSong() then
            local songData = {Name=aSong.Name(),Duration=aSong.Duration.TotalSeconds()}
            if aSong.CounterNumber() > 0 then
                songData.CounterNumber=aSong.CounterNumber()
                songData.CounterType=aSong.CounterType()
            end
            table.insert(songs, songData)
        end
    end
    local status = {
        id = 'status',
        Name = mq.TLO.Me.CleanName(),
        Buffs = buffs,
        Songs = songs,
        General = {
            PctHPs = mq.TLO.Me.PctHPs(),
        },
        LastSent = mq.gettime(),
    }
    testmb:send(header, status)
end)

local function dumpTable(t, prefix)
    for k,v in pairs(t) do
        if type(v) == 'table' then dumpTable(v, (prefix or '')..k..'.')
        else
            printf('%s%s -- %s', prefix or '', k, v)
        end
    end
end

while true do
    mq.delay(1000)
    local aqoActorState = mq.TLO.AQO.Actors('toonname')()
    if aqoActorState then
        dumpTable(aqoActorState)
        print('\n\n')
    end
end
