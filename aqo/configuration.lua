--- @type Mq
local mq = require 'mq'
local logger = require('utils.logger')
local persistence = require('utils.persistence')
local modes = require('mode')

local config = {
    MODE = modes.from_string('manual'),
    CHASETARGET = '',
    CHASEDISTANCE = 30,
    CAMPRADIUS = 60,
    ASSIST = 'group',
    AUTOASSISTAT = 98,
    SWITCHWITHMA = true,

    RECOVERPCT = 70,

    HEALPCT = 75,
    PANICHEALPCT = 30,
    GROUPHEALPCT = 75,
    GROUPHEALMIN = 3,
    HOTHEALPCT = 90,
    REZGROUP = true,
    REZRAID = true,
    REZINCOMBAT = false,
    PRIORITYTARGET = '',

    BURNALWAYS = false,
    BURNPCT = 0,
    BURNALLNAMED = false,
    BURNCOUNT = 5,
    USEGLYPH = false,
    USEINTENSITY = false,

    PULLRADIUS = 100,
    PULLHIGH = 25,
    PULLLOW = 25,
    PULLARC = 360,
    PULLMINLEVEL = 0,
    PULLMAXLEVEL = 0,
    GROUPWATCHWHO = 'healer',
    MEDMANASTART = 5,
    MEDMANASTOP = 30,
    MEDENDSTART = 5,
    MEDENDSTOP = 30,

    LOOTMOBS = true,

    MAINTANK = false,
}

config.tips = {
    MODE = '',
    CHASETARGET = '',
    CHASEDISTANCE = '',
    CAMPRADIUS = '',
    ASSIST = '',
    AUTOASSISTAT = '',
    SWITCHWITHMA = '',

    RECOVERPCT = '',

    HEALPCT = '',
    PANICHEALPCT = '',
    GROUPHEALPCT = '',
    GROUPHEALMIN = '',
    HOTHEALPCT = '',
    REZGROUP = '',
    REZRAID = '',
    REZINCOMBAT = '',
    PRIORITYTARGET = '',

    BURNALWAYS = '',
    BURNPCT = '',
    BURNALLNAMED = '',
    BURNCOUNT = '',
    USEGLYPH = '',
    USEINTENSITY = '',

    PULLRADIUS = '',
    PULLHIGH = '',
    PULLLOW = '',
    PULLARC = '',
    PULLMINLEVEL = '',
    PULLMAXLEVEL = '',
    GROUPWATCHWHO = '',
    MEDMANASTART = '',
    MEDMANASTOP = '',
    MEDENDSTART = '',
    MEDENDSTOP = '',

    LOOTMOBS = '',

    MAINTANK = '',
}

local ignores = {}

function config.get_all()
    return {
        MODE = config.MODE:get_name(),
        CHASETARGET = config.CHASETARGET,
        CHASEDISTANCE = config.CHASEDISTANCE,
        CAMPRADIUS = config.CAMPRADIUS,
        ASSIST = config.ASSIST,
        AUTOASSISTAT = config.AUTOASSISTAT,
        SWITCHWITHMA = config.SWITCHWITHMA,

        RECOVERPCT = config.RECOVERPCT,

        HEALPCT = config.HEALPCT,
        PANICHEALPCT = config.PANICHEALPCT,
        GROUPHEALPCT = config.GROUPHEALPCT,
        GROUPHEALMIN = config.GROUPHEALMIN,
        HOTHEALPCT = config.HOTHEALPCT,
        REZGROUP = config.REZGROUP,
        REZRAID = config.REZRAID,
        REZINCOMBAT = config.REZINCOMBAT,
        PRIORITYTARGET = config.PRIORITYTARGET,

        BURNALWAYS = config.BURNALWAYS,
        BURNPCT = config.BURNPCT,
        BURNALLNAMED = config.BURNALLNAMED,
        BURNCOUNT = config.BURNCOUNT,
        USEGLYPH = config.USEGLYPH,
        USEINTENSITY = config.USEINTENSITY,

        PULLRADIUS = config.PULLRADIUS,
        PULLHIGH = config.PULLHIGH,
        PULLLOW = config.PULLLOW,
        PULLARC = config.PULLARC,
        PULLMINLEVEL = config.PULLMINLEVEL,
        PULLMAXLEVEL = config.PULLMAXLEVEL,
        GROUPWATCHWHO = config.GROUPWATCHWHO,
        MEDMANASTART = config.MEDMANASTART,
        MEDMANASTOP = config.MEDMANASTOP,
        MEDENDSTART = config.MEDENDSTART,
        MEDENDSTOP = config.MEDENDSTOP,

        LOOTMOBS = config.LOOTMOBS,

        MAINTANK = config.MAINTANK,
    }
end

config.booleans = {
    ['1']=true, ['true']=true,['on']=true,
    ['0']=false, ['false']=false,['off']=false,
}

config.aliases = {
    campradius = 'CAMPRADIUS',
    autoassistat = 'AUTOASSISTAT',
    chasedistance = 'CHASEDISTANCE',
    chasetarget = 'CHASETARGET',
    switchwithma = 'SWITCHWITHMA',

    burnpercent = 'BURNPCT',
    burncount = 'BURNCOUNT',
    burnalways = 'BURNALWAYS',
    burnallnamed = 'BURNALLNAMED',
    useintensity = 'USEINTENSITY',
    useglyph = 'USEGLYPH',

    recoverpct = 'RECOVERPCT',

    healpct = 'HEALPCT',
    panichealpct = 'PANICHEALPCT',
    grouphealpct = 'GROUPHEALPCT',
    grouphealmin = 'GROUPHEALMIN',
    hothealpct = 'HOTHEALPCT',
    rezgroup = 'REZGROUP',
    rezraid = 'REZRAID',
    rezincombat = 'REZINCOMBAT',
    prioritytarget = 'PRIORITYTARGET',

    medmanastart = 'MEDMANASTART',
    medmanastop = 'MEDMANASTOP',
    medendstart = 'MEDENDSTART',
    medendstop = 'MEDENDSTOP',

    radius = 'PULLRADIUS',
    pullarc = 'PULLARC',
    levelmin = 'PULLMINLEVEL',
    levelmax = 'PULLMAXLEVEL',
    zlow = 'PULLLOW',
    zhigh = 'PULLHIGH',
    groupwatch = 'GROUPWATCHWHO',

    maintank = 'MAINTANK',

    lootmobs = 'LOOTMOBS',
}

---Get or set the specified configuration option. Currently applies to pull settings only.
---@param name string @The name of the setting.
---@param current_value any @The current value of the specified setting.
---@param new_value string @The new value for the setting.
---@param key string @The configuration key to be set.
config.getOrSetOption = function(name, current_value, new_value, key)
    if config[key] == nil then return end
    if new_value then
        if type(current_value) == 'number' then
            config[key] = tonumber(new_value) or current_value
        elseif type(current_value) == 'boolean' then
            if config.booleans[new_value] == nil then return end
            config[key] = config.booleans[new_value]
            print(logger.logLine('Setting %s to: %s', key, config.booleans[new_value]))
        else
            config[key] = new_value
        end
    else
        print(logger.logLine('%s: %s', name, current_value))
    end
end

---Check whether the specified file exists or not.
---@param file_name string @The name of the file to check existence of.
---@return boolean @Returns true if the file exists, false otherwise.
function config.file_exists(file_name)
    local f = io.open(file_name, "r")
    if f ~= nil then io.close(f) return true else return false end
end

---Load mob ignore lists file
function config.load_ignores()
    local ignore_file = ('%s/%s'):format(mq.configDir, 'aqo_ignore.lua')
    if config.file_exists(ignore_file) then
        ignores = assert(loadfile(ignore_file))()
    end
end

function config.save_ignores()
    local ignore_file = ('%s/%s'):format(mq.configDir, 'aqo_ignore.lua')
    persistence.store(ignore_file, ignores)
end

---Load common settings from settings file
---@param settings_file string @The name of the settings file to load.
---@return table|nil @Returns a table containing the loaded settings file content.
function config.load_settings(settings_file)
    if not config.file_exists(settings_file) then return nil end
    local settings = assert(loadfile(settings_file))()
    if not settings or not settings.common then return settings end
    for setting,value in pairs(settings.common) do
        config[setting] = value
    end
    if settings.common.MODE ~= nil then config.MODE = modes.from_string(settings.common.MODE) end
    return settings
end

function config.get_ignores(zone_short_name)
    if not zone_short_name then
        return ignores
    else
        return ignores[zone_short_name:lower()]
    end
end

function config.add_ignore(zone_short_name, mob_name)
    if ignores[zone_short_name:lower()] and ignores[zone_short_name:lower()][mob_name] then
        print(logger.logLine('\at%s\ax already in ignore list for zone \ay%s\az, skipping', mob_name, zone_short_name))
        return
    end
    if not ignores[zone_short_name:lower()] then ignores[zone_short_name:lower()] = {} end
    ignores[zone_short_name:lower()][mob_name] = true
    print(logger.logLine('Added pull ignore \at%s\ax for zone \ay%s\ax', mob_name, zone_short_name))
    config.save_ignores()
end

function config.remove_ignore(zone_short_name, mob_name)
    if not ignores[zone_short_name:lower()] or not ignores[zone_short_name:lower()][mob_name] then
        print(logger.logLine('\at%s\ax not found in ignore list for zone \ay%s\az, skipping', mob_name, zone_short_name))
        return
    end
    ignores[zone_short_name:lower()][mob_name] = nil
    print(logger.logLine('Removed pull ignore \at%s\ax for zone \ay%s\ax', mob_name, zone_short_name))
    config.save_ignores()
end

function config.ignores_contains(zone_short_name, mob_name)
    return ignores[zone_short_name:lower()] and ignores[zone_short_name:lower()][mob_name]
end

--for k,v in pairs(config.get_all()) do
--    print(logger.logLine('%s: %s', k, v))
--end

return config