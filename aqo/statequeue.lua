
state.queue = {}

-- return false if queue entry was processed and loop should take no further action
-- return true if no entry was processed and loop should proceed
function state.handleQueue()
    local entry = state.queue[1]
    -- entry in queue, try to process it
    if entry then
        -- entry is not stale, try to process it
        if mq.gettime() - entry.timestamp < 5000 then
            -- skip entry if in combat
            if entry.skipInCombat and mq.TLO.Me.CombatState() == 'COMBAT' then return true end
            -- process the entry
            if entry.process() then
                -- success, pop from queue
                table.remove(state.queue, 1)
            end
            return false
        else
            -- entry is stale, pop from queue
            table.remove(state.queue, 1)
            return true
        end
    else
        -- queue empty
        return true
    end
end
