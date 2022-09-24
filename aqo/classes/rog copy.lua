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
local baseclass = require('aqo.classes.base')

local rog = baseclass

rog.OPTS['something'] = 'something'

rog.draw_skills_tab = function()
    --OPTS.USEBATTLELEAP = ui.draw_check_box('Use Battle Leap', '##useleap', OPTS.USEBATTLELEAP, 'Keep the Battle Leap AA Buff up')
end

return rog