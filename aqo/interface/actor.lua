local mq = require('mq')
local actors = require('actors')
local state = require('state')

local export = {}

local function processTable(parent, tableName, tableValue)
    parent[tableName] = {}
    for key, value in pairs(tableValue) do
        if type('value') == 'table' then
            processTable(parent[tableName], key, value)
        else
            parent[tableName][key] = value
        end
    end
end

export.actor = actors.register("aqo", function (message)
    if message then
        if message.content.id == 'status' then
            state.actors[message.content.Name] = state.actors[message.content.Name] or {}
            for key, value in pairs(message.content) do
                if key ~= 'Name' and key ~= 'id' then
                    if type(value) == 'table' then
                        processTable(state.actors[message.content.Name], key, value)
                    else
                        state.actors[message.content.Name][key] = value
                    end
                end
            end
        end
    end

    -- example, unused
    if message.content.id == 'replytothismessage' then
        message:reply(0, {Name=mq.TLO.Me.CleanName()})
    end
end)

function export.sendStatus()
    local header = {mailbox = 'aqo'}
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
    export.actor:send(header, status)
end

return export