--- @type Mq
local mq = require 'mq'
local assist = require('aqo.routines.assist')
local camp = require('aqo.routines.camp')
local pull = require('aqo.routines.pull')
local tank = require('aqo.routines.tank')
local logger = require('aqo.utils.logger')
local persistence = require('aqo.utils.persistence')
local common = require('aqo.common')
local config = require('aqo.configuration')
local mode = require('aqo.mode')
local state = require('aqo.state')
local ui = require('aqo.ui')

local clr = {}

local OPTS = {
    
}

local SETTINGS_FILE = ('%s/clrbot_%s_%s.lua'):format(mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me.CleanName())
clr.load_settings = function()
    local settings = config.load_settings(SETTINGS_FILE)
    if not settings or not settings.clr then return end
    for setting,value in pairs(settings.clr) do
        OPTS[setting] = value
    end
end

clr.save_settings = function()
    persistence.store(SETTINGS_FILE, {common=config.get_all(), clr=OPTS})
end

clr.setup_events = function()
    -- no-op
end


clr.process_cmd = function(opt, new_value)
    if new_value then
        if type(OPTS[opt]) == 'boolean' then
            if common.BOOL.FALSE[new_value] then
                logger.printf('Setting %s to: false', opt)
                if OPTS[opt] ~= nil then OPTS[opt] = false end
            elseif common.BOOL.TRUE[new_value] then
                logger.printf('Setting %s to: true', opt)
                if OPTS[opt] ~= nil then OPTS[opt] = true end
            end
        elseif type(OPTS[opt]) == 'number' then
            if tonumber(new_value) then
                logger.printf('Setting %s to: %s', opt, tonumber(new_value))
                if OPTS[opt] ~= nil then OPTS[opt] = tonumber(new_value) end
            end
        else
            logger.printf('Unsupported command line option: %s %s', opt, new_value)
        end
    else
        if OPTS[opt] ~= nil then
            logger.printf('%s: %s', opt:lower(), OPTS[opt])
        else
            logger.printf('Unrecognized option: %s', opt)
        end
    end
end

local heal = common.get_best_spell({'Minor Healing'})
local function check_heals()
    if mq.TLO.Me.PctHPs() < 80 then
        mq.cmdf('/mqtar myself')
        mq.delay(100, function() return mq.TLO.Target.ID() == mq.TLO.Me.ID() end)
        common.cast(heal.name)
    elseif mq.TLO.Group.MainTank.PctHPs() < 80 then
        mq.cmdf('/mqt id %d', mq.TLO.Group.MainTank.ID())
        mq.delay(100, function() return mq.TLO.Target.ID() == mq.TLO.Group.MainTank.ID() end)
        common.cast(heal.name)
    end
end

clr.main_loop = function()
    if not mq.TLO.Target() and not mq.TLO.Me.Combat() then
        state.tank_mob_id = 0
    end
    if not state.pull_in_progress then
        check_heals()
        --check_end()
        if config.MODE:is_tank_mode() then
            -- get mobs in camp
            camp.mob_radar()
            -- pick mob to tank if not tanking
            tank.find_mob_to_tank()
            tank.tank_mob()
        end
        -- check whether we need to return to camp
        camp.check_camp()
        -- check whether we need to go chasing after the chase target
        common.check_chase()
        -- ae aggro if multiples in camp -- do after return to camp to try to be in range when using
        --oh_shit()
        --if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
        --    check_ae()
        --end
        -- if in an assist mode
        if config.MODE:is_assist_mode() then
            assist.check_target(clr.reset_class_timers)
            assist.attack()
        end
        -- begin actual combat stuff
        assist.send_pet()
        --mash()
        -- pop a bunch of burn stuff if burn conditions are met
        --try_burn()
        --check_end()
        --check_buffs()
        common.rest()
    end
    if config.MODE:is_pull_mode() then
        pull.pull_mob()
    end
end

clr.draw_skills_tab = function()
    --OPTS.USEBATTLELEAP = ui.draw_check_box('Use Battle Leap', '##useleap', OPTS.USEBATTLELEAP, 'Keep the Battle Leap AA Buff up')
end

return clr