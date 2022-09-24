---@type Mq
local mq = require 'mq'
local LIP = require 'lib.LIP'

local lootFile = mq.configDir .. '/Loot.ini'
local lootData = LIP.load(lootFile)
local debugLoot = false

local function split(input, sep)
    if sep == nil then
        sep = "|"
    end
    local t={}
    for str in string.gmatch(input, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

local function addForageRule(itemName, section, rule)
    if not lootData[section] then
        lootData[section] = {}
    end
    lootData[section][itemName] = rule
    LIP.save(lootFile, lootData)
end

local function getForageRule(itemName)
    local lootDecision = 'Keep'
    if not lootData then return lootDecision end
    local firstLetter = itemName:sub(1,1):upper()
    if lootData['Global'] then
        for _,rule in pairs(lootData['Global']) do
            if rule:find(itemName) then
                lootDecision,_ = rule:gsub(itemName..'|','')
                return lootDecision
            end
        end
    end
    if not lootData[firstLetter] or not lootData[firstLetter][itemName] then
        print(itemName, firstLetter)
        addForageRule(itemName, firstLetter, lootDecision)
    end
    return lootData[firstLetter][itemName]
end

local keepActions = {Keep=true, Sell=true}
local destroyActions = {Destroy=true,Ignore=true}
local function eventForage()
    if debugLoot then print('Entered eventForage') end
    mq.delay(1000, function() return mq.TLO.Cursor() end)
    while mq.TLO.Cursor() do
        local cursorItem = mq.TLO.Cursor
        local foragedItem = cursorItem.Name()
        local forageRule = split(getForageRule(foragedItem))
        local ruleAction = forageRule[1]
        local ruleAmount = forageRule[2]
        local currentItemAmount = mq.TLO.FindItemCount('='..foragedItem)()
        if destroyActions[ruleAction] or (ruleAction == 'Quest' and currentItemAmount >= ruleAmount) then
            if mq.TLO.Cursor.Name() == foragedItem then
                print('Destroying foraged item '..foragedItem)
                mq.cmd('/destroy')
                mq.delay(500)
            end
        elseif (keepActions[ruleAction] or currentItemAmount < ruleAmount) and (!cursorItem.Lore() or currentItemAmount == 0) and (mq.TLO.Me.FreeInventory() or (cursorItem.Stackable() and cursorItem.FreeStack())) then
            print('Keeping foraged item '..foragedItem)
            mq.cmd('/autoinv')
        else
            print('Unable to process item '..foragedItem)
        end
        mq.delay(50)
    end
end

local function eventInventoryFull()
    --lootMobs = false
    --inventoryFull = 1
end

local function setupEvents()
    mq.event("Forage", "Your forage mastery has enabled you to find something else!", eventForage)
    mq.event("Forage", "You have scrounged up #*#", eventForage)
    mq.event("InventoryFull", "#*#Your inventory appears full!#*#", eventInventoryFull)
    --[[
    mq.event("Forage", "You caught #*#", eventHandler)
    mq.event("EditIniItem", "LootIniItem #1# #2#", eventHandler)
    mq.event("NullSlot", "#*#Invalid item slot 'null#*#", eventHandler)
    mq.event("Lore", "#*#You cannot loot this Lore Item.#*#", eventHandler)]]--
end
setupEvents()