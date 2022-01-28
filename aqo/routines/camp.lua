--- @type mq
local mq = require 'mq'
local common = require('aqo.common')
local config = require('aqo.configuration')
local logger = require('aqo.utils.logger')
local state = require('aqo.state')

local camp = {}

local xtar_corpse_count = 'xtarhater npccorpse radius %d zradius 50'
local xtar_count = 'xtarhater radius %d zradius 50'
local xtar_spawn = '%d, xtarhater radius %d zradius 50'
---Determine the number of mobs within the camp radius.
---Sets common.MOB_COUNT to the total number of mobs on xtarget within the camp radius.
---Adds the mob ID of each mob found to the common.TARGETS table.
camp.mob_radar = function()
    local num_corpses = 0
    local targets = state.get_targets()
    num_corpses = mq.TLO.SpawnCount(xtar_corpse_count:format(config.get_camp_radius()))()
    local mob_count = mq.TLO.SpawnCount(xtar_count:format(config.get_camp_radius()))() - num_corpses
    if mob_count > 0 then
        for i=1,mob_count do
            if i > 13 then break end
            local mob = mq.TLO.NearestSpawn(xtar_spawn:format(i, config.get_camp_radius()))
            local mob_id = mob.ID()
            if mob_id and mob_id > 0 then
                if not mob() or mob.Type() == 'Corpse' then
                    targets[mob_id] = nil
                    num_corpses = num_corpses+1
                elseif not targets[mob_id] then
                    logger.debug(state.get_debug(), 'Adding mob_id %d', mob_id)
                    targets[mob_id] = {meztimer=0}
                end
            end
        end
        state.set_mob_count(mob_count - num_corpses)
    end
    state.set_targets(targets) -- is this necessary if targets is by ref
end

---Checks for any mobs in common.TARGETS which are no longer valid and removes them from the table.
camp.clean_targets = function()
    local targets = state.get_targets()
    for mobid,_ in pairs(targets) do
        local spawn = mq.TLO.Spawn(string.format('id %s', mobid))
        if not spawn() or spawn.Type() == 'Corpse' then
            targets[mobid] = nil
        end
    end
    state.set_targets(targets) -- is this necessary if targets is by ref
end

---Return to camp if alive and in a camp mode and not currently fighting and more than 15ft from the camp center location.
camp.check_camp = function()
    if not config.get_mode():is_camp_mode() then return end
    if common.am_i_dead() then return end
    if common.is_fighting() or not state.get_camp() then return end
    if mq.TLO.Zone.ID() ~= state.get_camp().ZoneID then
        logger.printf('Clearing camp due to zoning.')
        state.set_camp(nil)
        return
    end
    local my_camp = state.get_camp()
    if common.check_distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), my_camp.X, my_camp.Y) > 15 then
        if not mq.TLO.Nav.Active() then
            mq.cmdf('/nav locyxz %d %d %d log=off', my_camp.Y, my_camp.X, my_camp.Z)
        end
    end
end

---Draw a maploc at the given heading on the pull radius circle.
---@param heading number @The MQ heading degrees pointing to where to draw the maploc.
---@param color string @The color input to the /maploc command.
local function draw_maploc(heading, color)
    local my_x = mq.TLO.Me.X()
    local my_y = mq.TLO.Me.Y()
    if heading < 0 then
        heading = 360 - heading
    elseif heading > 360 then
        heading = heading - 360
    end
    local x_move = math.cos(math.rad(common.convert_heading(heading)))
    if x_move > 0 and heading > 0 and heading < 180 then
        x_move = x_move * -1
    elseif x_move < 0 and heading >= 180 then
        x_move = math.abs(x_move)
    end
    local y_move = math.sin(math.rad(common.convert_heading(heading)))
    if y_move > 0 and heading > 90 and heading < 270 then
        y_move = y_move * -1
    elseif y_move < 0 and (heading <= 90 or heading >= 270) then
        y_move = math.abs(y_move)
    end
    local x_off = my_x + config.get_pull_radius() * x_move
    local y_off = my_y + config.get_pull_radius() * y_move
    mq.cmdf('/squelch /maploc size 10 width 2 color %s radius 5 rcolor 0 0 0 %s %s', color, y_off, x_off)
end

---Set the left and right pull arc values based on the configured PULLARC option.
local function set_pull_angles(my_camp)
    local pull_arc = config.get_pull_arc()
    if not pull_arc or pull_arc == 0 then return end
    if not my_camp.HEADING then my_camp.HEADING = 0 end
    if my_camp.HEADING-(pull_arc*.5) < 0 then
        my_camp.PULL_ARC_LEFT = 360-((pull_arc*.5)-my_camp.HEADING)
    else
        my_camp.PULL_ARC_LEFT = my_camp.HEADING-(pull_arc*.5)
    end
    if my_camp.HEADING + (pull_arc*.5) > 360 then
        my_camp.PULL_ARC_RIGHT = (pull_arc*.5)+my_camp.HEADING-360
    else
        my_camp.PULL_ARC_RIGHT = (pull_arc*.5)+my_camp.HEADING
    end
    logger.debug(state.get_debug(), 'arcleft: %s, arcright: %s', my_camp.PULL_ARC_LEFT, my_camp.PULL_ARC_RIGHT)
    return my_camp
end

---Set, update or clear the CAMP values depending on whether currently in a camp mode or not.
---@param reset boolean @If true, then reset the camp to pickup the latest options.
camp.set_camp = function(reset)
    if (config.get_mode():is_camp_mode() and not state.get_camp()) or reset then
        mq.cmd('/squelch /maploc remove')
        local my_camp = {
            ['X']=mq.TLO.Me.X(),
            ['Y']=mq.TLO.Me.Y(),
            ['Z']=mq.TLO.Me.Z(),
            ['HEADING']=mq.TLO.Me.Heading.Degrees(),
            ['ZoneID']=mq.TLO.Zone.ID()
        }
        logger.printf('Camp set to X: %s Y: %s Z: %s R: %s H: %s', my_camp.X, my_camp.Y, my_camp.Z, config.get_camp_radius(), my_camp.HEADING)
        mq.cmdf('/squelch /maploc size 10 width 1 color 255 0 0 radius %s rcolor 255 0 0 %s %s', config.get_camp_radius(), my_camp.Y+1, my_camp.X+1)
        if config.get_mode():is_pull_mode() then
            if config.get_pull_arc() > 0 and config.get_pull_arc() < 360 then
                my_camp = set_pull_angles(my_camp)
                draw_maploc(my_camp.PULL_ARC_LEFT, '0 0 255')
                draw_maploc(my_camp.PULL_ARC_RIGHT, '0 0 255')
                draw_maploc(my_camp.HEADING, '255 0 0')
            end
            mq.cmdf('/squelch /maploc size 10 width 1 color 0 0 255 radius %s rcolor 0 0 255 %s %s', config.get_pull_radius(), my_camp.Y, my_camp.X)
        end
        state.set_camp(my_camp)
    elseif not config.get_mode():is_camp_mode() and state.get_camp() then
        state.set_camp(nil)
        mq.cmd('/squelch /mapf campradius 0')
        mq.cmd('/squelch /mapf pullradius 0')
        mq.cmd('/squelch /maploc remove')
    end
end

return camp