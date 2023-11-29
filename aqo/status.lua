local mq = require('mq')
local state = require('state')
local actor = require('interface.actor')
local Timer = require('utils.timer')

local status = {}

function status.init()
    actor.register('status', status.callback)
end

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

function status.callback(message)
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

local statusTimer = Timer:new(1000)
function status.send()
    if not statusTimer:timerExpired() then return end
    statusTimer:reset()
    local header = {mailbox = 'aqo'}
    local buffs = {}
    for i=1,42 do
        local aBuff = mq.TLO.Me.Buff(i)
        if aBuff() then
            local buffData = {Name=aBuff.Name(),Duration=aBuff.Duration.TotalSeconds()}
            if aBuff.CounterNumber() and aBuff.CounterNumber() > 0 then
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
            if aSong.CounterNumber() and aSong.CounterNumber() > 0 then
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
    actor.actor:send(header, status)
end

return status