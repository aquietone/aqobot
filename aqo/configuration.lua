--- @type Mq
local mq = require 'mq'
local lists = require('data.lists')
local logger = require('utils.logger')
local persistence = require('utils.persistence')
local modes = require('mode')

local config = {
    SETTINGS_FILE = ('%s/aqobot_%s_%s.lua'):format(mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me.CleanName()),

    -- General settings
    MODE = {
        value = modes.fromString('manual'),
        tip = 'The mode to run as: 0|manual|1|assist|2|chase|3|vorpal|4|tank|5|pullertank|6|puller|7|huntertank',
        alias = 'mode',
    },
    CHASETARGET = {
        value = '',
        tip = 'Name of the person to chase in chase mode. Its using an exact match spawn search for PC\'s only',
        alias = 'chasetarget',
    },
    CHASEDISTANCE = {
        value = 30,
        tip = 'Distance threshold to trigger chasing the chase target',
        alias = 'chasedistance',
    },
    CAMPRADIUS = {
        value = 60,
        tip = 'The radius within which you will assist on mobs',
        alias = 'campradius',
    },
    ASSIST = {
        value = 'group',
        tip = 'Who to assist. Group MA, Raid MA 1, 2 or 3',
        alias = 'mode',
    },
    AUTOASSISTAT = {
        value = 98,
        tip = 'Mob Percent HP to begin assisting',
        alias = 'autoassistat',
    },
    ASSISTNAMES = {
        value = '',
        tip = 'Comma separated, ordered list of names to assist, mainly for manual assist mode in raids.',
        alias = 'assistnames',
    },
    SWITCHWITHMA = {
        value = true,
        tip = 'Swap targets if the MA swaps targets',
        alias = 'switchwithma',
    },
    RECOVERPCT = {
        value = 70,
        tip = 'Percent mana or endurance to trigger recover abilities',
        alias = 'recoverpct',
    },
    MEDCOMBAT = {
        value = false,
        tip = 'Toggle whether to med during combat. If on, character will still heal, tank, cc, debuff and buff, just not assist.',
        alias = 'medcombat',
    },

    -- Heal settings
    HEALPCT = {
        value = 75,
        tip = 'The Percent HP to begin casting normal heals on a character',
        alias = 'healpct',
    },
    PANICHEALPCT = {
        value = 30,
        tip = 'The Percent HP to begin casting panic heals on a character',
        alias = 'panichealpct',
        classes = lists.healClasses,
    },
    GROUPHEALPCT = {
        value = 75,
        tip = 'The Percent HP to begin casting group heals',
        alias = 'grouphealpct',
        classes = lists.healClasses,
    },
    GROUPHEALMIN = {
        value = 3,
        tip = 'The number of group members which must be injured to begin casting group heals',
        alias = 'grouphealmin',
        classes = lists.healClasses,
    },
    HOTHEALPCT = {
        value = 90,
        tip = 'The Percent HP to begin casting HoTs on a character',
        alias = 'hothealpct',
        classes = lists.healClasses,
    },
    REZGROUP = {
        value = false,
        tip = 'Toggle rezzing of group members',
        alias = 'rezgroup',
    },
    REZRAID = {
        value = false,
        tip = 'Toggle rezzing of raid members',
        alias = 'rezraid',
    },
    REZINCOMBAT = {
        value = false,
        tip = 'Toggle use of rez abilities during combat',
        alias = 'rezincombat',
    },
    PRIORITYTARGET = {
        value = '',
        tip = 'For EMU, where group main tank role is unreliable, assign a character name to treat like the main tank',
        alias = 'prioritytarget',
        classes = lists.healClasses,
    },
    XTARGETHEAL = {
        value = false,
        tip = 'Toggle healing of PCs on XTarget',
        alias = 'xtargetheal',
        classes = lists.healClasses,
    },

    -- Burn settings
    BURNALWAYS = {
        value = false,
        tip = 'Burn routine is always entered and burn abilities are used as available. Its not great, it doesn\'t attempt to line up CDs or anything',
        alias = 'burnalways',
    },
    BURNPCT = {
        value = 0,
        tip = 'Same as Burn Always, but only after mob HP is below this percent',
        alias = 'burnpercent',
    },
    BURNALLNAMED = {
        value = false,
        tip = 'Enter burn routine when ${Target.Named} is true. Kinda sucks with ToL zones since so many akhevan trash mobs return true',
        alias = 'burnallnamed',
    },
    BURNCOUNT = {
        value = 5,
        tip = 'Enter burn routine when greater than or equal to this number of mobs are within camp radius',
        alias = 'burncount',
    },
    USEGLYPH = {
        value = false,
        tip = 'Toggle use of Glyph of Destruction on burns',
        alias = 'useglyph',
    },
    USEINTENSITY = {
        value = false,
        tip = 'Toggle use of Intensity of the Resolute Veteran AA on burns',
        alias = 'useintensity',
    },

    -- Pull settings
    PULLWITH = {
        value = 'melee',
        tip = 'How to pull mobs. May be one of melee, ranged, spell',
        alias = 'pullwith',
    },
    PULLRADIUS = {
        value = 100,
        tip = 'The radius within which you will pull mobs when in a puller role',
        alias = 'radius',
    },
    PULLHIGH = {
        value = 25,
        tip = 'The upper Z radius for pulling mobs when in a puller role',
        alias = 'zhigh',
    },
    PULLLOW = {
        value = 25,
        tip = 'The lower Z radius for pulling mobs when in a puller role',
        alias = 'zlow',
    },
    PULLARC = {
        value = 360,
        tip = 'The pull arc, centered around the direction the character is currently facing, to pull mobs from',
        alias = 'pullarc',
    },
    PULLMINLEVEL = {
        value = 0,
        tip = 'The minimum level mob to pull when in a puller role',
        alias = 'levelmin',
    },
    PULLMAXLEVEL = {
        value = 0,
        tip = 'The maxmimum level mob to pull when in a puller role',
        alias = 'levelmax',
    },
    GROUPWATCHWHO = {
        value = 'healer',
        tip = 'Who to watch mana/endurance for, to decide whether to hold pulls and med',
        alias = 'groupwatch',
    },
    MEDMANASTART = {
        value = 5,
        tip = 'The Percent Mana to begin medding at',
        alias = 'medmanastart',
    },
    MEDMANASTOP = {
        value = 30,
        tip = 'The Percent Mana to stop medding at',
        alias = 'medmanastop',
    },
    MEDENDSTART = {
        value = 5,
        tip = 'The Percent Endurance to begin medding at',
        alias = 'medendstart',
    },
    MEDENDSTOP = {
        value = 30,
        tip = 'The Percent Endurance to stop medding at',
        alias = 'medendstop',
    },

    -- Other settings
    LOOTMOBS = {
        value = true,
        tip = 'Toggle looting of mob corpses on or off for emu',
        alias = 'lootmobs',
    },

    MAINTANK = {
        value = false,
        tip = 'Toggle use of tanking abilities in case main tank role doesn\'t work, like on emu',
        alias = 'maintank',
    },
    AUTODETECTRAID = {
        value = false,
        tip = 'Toggle auto-detecting when in raid and setting appropriate assist settings',
        alias = 'autodetectraid',
    },
    RESISTSTOPCOUNT = {
        value = 3,
        tip = 'The number of resists after which to stop trying casting a spell on a mob',
        alias = 'resiststopcount',
    },

    TIMESTAMPS = {
        value = false,
        tip = 'Enable timestamps on log messages',
        alias = 'timestamps'
    }
}

function config.getNameForAlias(alias)
    for key,cfg in pairs(config) do
        if type(cfg) == 'table' and cfg.alias == alias then return key end
    end
end

function config.getAll()
    local configMap = {}
    for key,cfg in pairs(config) do
        if type(config[key]) == 'table' then
            if key == 'MODE' then
                configMap[key] = cfg.value:getName()
            else
                configMap[key] = cfg.value
            end
        end
    end
    return configMap
end

local categories = {'Assist', 'Camp', 'Burn', 'Heal', 'Pull'}
function config.categories()
    return categories
end

local configByCategory = {
    Assist={'AUTOASSISTAT','ASSIST','ASSISTNAMES','SWITCHWITHMA','MEDCOMBAT','RESISTSTOPCOUNT'},
    Camp={'MODE','CAMPRADIUS','CHASETARGET','CHASEDISTANCE','MAINTANK','LOOTMOBS','AUTODETECTRAID'},
    Burn={'BURNALWAYS','BURNALLNAMED','BURNCOUNT','BURNPCT','USEGLYPH','USEINTENSITY','RECOVERPCT'},
    Pull={'PULLRADIUS','PULLLOW','PULLHIGH','PULLMINLEVEL','PULLMAXLEVEL','PULLARC','GROUPWATCHWHO','MEDMANASTART','MEDMANASTOP','MEDENDSTART','MEDENDSTOP','PULLWITH'},
    Heal={'HEALPCT','PANICHEALPCT','HOTHEALPCT','GROUPHEALPCT','GROUPHEALMIN','REZGROUP','REZRAID','REZINCOMBAT','PRIORITYTARGET'},
    Debug={'TIMESTAMPS'}
}
function config.getByCategory(category)
    local configMap = {}
    for _,key in ipairs(configByCategory[category]) do
        configMap[key] = config[key]
    end
    return configMap
end

---Get or set the specified configuration option. Currently applies to pull settings only.
---@param name string @The name of the setting.
---@param current_value any @The current value of the specified setting.
---@param new_value string @The new value for the setting.
---@param key string @The configuration key to be set.
function config.getOrSetOption(name, current_value, new_value, key)
    if config[key] == nil then return end
    if new_value then
        if type(current_value) == 'number' then
            config[key].value = tonumber(new_value) or current_value
        elseif type(current_value) == 'boolean' then
            if lists.booleans[new_value] == nil then return end
            config[key].value = lists.booleans[new_value]
            print(logger.logLine('Setting %s to: %s', key, lists.booleans[new_value]))
        else
            config[key].value = new_value
        end
    else
        print(logger.logLine('%s: %s', name, current_value))
    end
end

---Check whether the specified file exists or not.
---@param file_name string @The name of the file to check existence of.
---@return boolean @Returns true if the file exists, false otherwise.
function config.fileExists(file_name)
    local f = io.open(file_name, "r")
    if f ~= nil then io.close(f) return true else return false end
end

---Load common settings from settings file
---@return table|nil @Returns a table containing the loaded settings file content.
function config.loadSettings()
    if not config.fileExists(config.SETTINGS_FILE) then return nil end
    local settings = assert(loadfile(config.SETTINGS_FILE))()
    if not settings or not settings.common then return settings end
    for setting,value in pairs(settings.common) do
        config[setting].value = value
    end
    if settings.common.MODE ~= nil then config.MODE.value = modes.fromString(settings.common.MODE) end
    logger.timestamps = config.TIMESTAMPS and config.TIMESTAMPS.value or false
    return settings
end

local ignores = {}

---Load mob ignore lists file
function config.loadIgnores()
    local ignore_file = ('%s/%s'):format(mq.configDir, 'aqo_ignore.lua')
    if config.fileExists(ignore_file) then
        ignores = assert(loadfile(ignore_file))()
    end
end

function config.saveIgnores()
    local ignore_file = ('%s/%s'):format(mq.configDir, 'aqo_ignore.lua')
    persistence.store(ignore_file, ignores)
end

function config.getIgnores(zone_short_name)
    if not zone_short_name then
        return ignores
    else
        return ignores[zone_short_name:lower()]
    end
end

function config.addIgnore(zone_short_name, mob_name)
    if ignores[zone_short_name:lower()] and ignores[zone_short_name:lower()][mob_name] then
        print(logger.logLine('\at%s\ax already in ignore list for zone \ay%s\az, skipping', mob_name, zone_short_name))
        return
    end
    if not ignores[zone_short_name:lower()] then ignores[zone_short_name:lower()] = {} end
    ignores[zone_short_name:lower()][mob_name] = true
    print(logger.logLine('Added pull ignore \at%s\ax for zone \ay%s\ax', mob_name, zone_short_name))
    config.saveIgnores()
end

function config.removeIgnore(zone_short_name, mob_name)
    if not ignores[zone_short_name:lower()] or not ignores[zone_short_name:lower()][mob_name] then
        print(logger.logLine('\at%s\ax not found in ignore list for zone \ay%s\az, skipping', mob_name, zone_short_name))
        return
    end
    ignores[zone_short_name:lower()][mob_name] = nil
    print(logger.logLine('Removed pull ignore \at%s\ax for zone \ay%s\ax', mob_name, zone_short_name))
    config.saveIgnores()
end

function config.ignoresContains(zone_short_name, mob_name)
    return ignores[zone_short_name:lower()] and ignores[zone_short_name:lower()][mob_name]
end

return config