local Write = { _version = '1.0' }

Write.usecolors = true
Write.loglevel = 'info'
Write.prefix = ''
local mq = 'notnil'

local loglevels = {
    ['debug'] = { level = 1, color = '\27[95m',  mqcolor = '\am', abbreviation = 'DEBUG', },
    ['info']  = { level = 2, color = '\27[92m',  mqcolor = '\ag', abbreviation = 'INFO', },
    ['warn']  = { level = 3, color = '\27[93m',  mqcolor = '\ay', abbreviation = 'WARN', },
    ['error'] = { level = 4, color = '\27[31m',  mqcolor = '\ao', abbreviation = 'ERROR', },
    ['fatal'] = { level = 5, color = '\27[91m',  mqcolor = '\ar', abbreviation = 'FATAL', },
}

local function Terminate()
    if mq then mq.exit() end
    os.exit()
end

local function GetColorStart(paramLogLevel)
    if Write.usecolors then
        if mq then return loglevels[paramLogLevel].mqcolor end
        return loglevels[paramLogLevel].color
    end
    return ''
end

local function GetColorEnd()
    if Write.usecolors then
        if mq then
            return '\ax'
        end
        return '\27[0m'
    end
    return ''
end

local function GetCallerString()
    if Write.loglevel:lower() ~= 'debug' then
        return ''
    end

    local callString = 'unknown'
    local callerInfo = debug.getinfo(4,'Sl')
    if callerInfo and callerInfo.short_src ~= nil and callerInfo.short_src ~= '=[C]' then
        callString = string.format('%s::%s', callerInfo.short_src:match("[^\\^/]*.lua$"), callerInfo.currentline)
    end

    return string.format('(%s) ', callString)
end

local function Output(paramLogLevel, message)
    if loglevels[Write.loglevel:lower()].level <= loglevels[paramLogLevel].level then
        if type(Write.prefix) == 'function' then
            print(string.format('%s%s%s[%s]%s :: %s', Write.prefix(), GetCallerString(), GetColorStart(paramLogLevel), loglevels[paramLogLevel].abbreviation, GetColorEnd(), message))
        else
            print(string.format('%s%s%s[%s]%s :: %s', Write.prefix, GetCallerString(), GetColorStart(paramLogLevel), loglevels[paramLogLevel].abbreviation, GetColorEnd(), message))
        end
    end
end

function Write.Debug(message)
    Output('debug', message)
end

function Write.Info(message)
    Output('info', message)
end

function Write.Warn(message)
    Output('warn', message)
end

function Write.Error(message)
    Output('error', message)
end

function Write.Fatal(message)
    Output('fatal', message)
    Terminate()
end

return Write
