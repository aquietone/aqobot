--[[
lootutils.lua v0.1 - aquietone
This is a port of the RedGuides copy of ninjadvloot.inc
I may have glossed over some of the events or edge cases so it may have some issues
around things like:
- lore items
- full inventory
- not full inventory but no slot large enough for an item
- ...
Or those things might just work, I just haven't tested it very much using lvl 1 toons
on project lazarus.

Usage: Include this somewhere in your automation with:
    local lootutils = require 'lootutils'
    ...
    lootutils.lootMobs()

This script also exports a function, sellStuff, which can be called from your main automation:
    lootutils.sellStuff()

    To use this, one way may be to setup a bind which sets some flag, like doSell=true, which then
    triggers your main loop to call lootutils.sellStuff().

    The sellStuff routine can take some time and is best not to be called directly from a bind callback.

Optionally, configure settings using:
    Set the radius within which corpses should be looted (radius from you, not a camp location)
        lootutils.radius = number
    Set whether loot.ini should be updated based off of sell item events to add manually sold items.
        lootutils.addNewSales = boolean
    Set your own instance of Write.lua to configure a different prefix, log level, etc.
        lootutils.logger = Write

Similar binds are included to ninjadvloot:
    /lootutils [action] "${Cursor.Name}" - Set the loot rule for an item. Options:
                                            Keep, Sell, Ignore, Destroy, Quest|#

This script depends on having LIP.lua and Write.lua in your lua/lib folder.
    https://github.com/Dynodzzo/Lua_INI_Parser/blob/master/LIP.lua
    https://gitlab.com/Knightly1/knightlinc/-/blob/master/Write.lua 

This does not include the buy routines from ninjadvloot. It does include the sell routines
but lootly sell routines seem more robust than the code that was in ninjadvloot.inc.
The forage event handling also does not handle fishing events like ninjadvloot did.
There is also no flag for combat looting. It will only loot if no mobs are within the radius.
]]
---@type Mq
local mq = require 'mq'
local LIP = require 'lib.LIP'

local loot = {
    logger = require 'lib.Write',
    radius = 60,
    addNewSales = true,
}
loot.logger.prefix = 'lootutils'

local lootFile = mq.configDir .. '/Loot.ini'
local lootData = LIP.load(lootFile)

local shouldLootMobs = true

local keepActions = {Keep=true, Sell=true}
local destroyActions = {Destroy=true, Ignore=true}
local vendorTypes = {NPC=true,PET=true}
local validActions = {keep='Keep',sell='Sell',ignore='Ignore',destroy='Destroy'}

-- FORWARD DECLARATIONS

local eventForage, eventSell, eventCantLoot

-- UTILITIES

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

local function checkCursor()
    local currentItem = nil
    while mq.TLO.Cursor() do
        -- can't do anything if there's nowhere to put the item, either due to no free inventory space
        -- or no slot of appropriate size
        if mq.TLO.Me.FreeInventory() == 0 or mq.TLO.Cursor() == currentItem then
            shouldLootMobs = false
            return
        end
        currentItem = mq.TLO.Cursor()
        mq.cmd('/autoinv')
        mq.delay(100)
    end
end

local function navToID(spawnID)
    mq.cmdf('/nav id %d', spawnID)
    mq.delay(50)
    if mq.TLO.Navigation.Active() then
        local startTime = os.time()
        while mq.TLO.Navigation.Active() do
            mq.delay(100)
            if os.difftime(os.time(), startTime) > 5 then
                break
            end
        end
    end
end

local function addRule(itemName, section, rule)
    if not lootData[section] then
        lootData[section] = {}
    end
    lootData[section][itemName] = rule
    LIP.save(lootFile, lootData)
end

local function getRule(itemName)
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
        addRule(itemName, firstLetter, lootDecision)
    end
    return lootData[firstLetter][itemName]
end

-- EVENTS

local function eventInventoryFull()
    shouldLootMobs = false
end

local function setupEvents()
    mq.event("CantLoot", "#*#may not loot this corpse#*#", eventCantLoot)
    mq.event("InventoryFull", "#*#Your inventory appears full!#*#", eventInventoryFull)
    mq.event("Sell", "#*#You receive#*# for the #1#(s)#*#", eventSell)
    mq.event("Forage", "Your forage mastery has enabled you to find something else!", eventForage)
    mq.event("Forage", "You have scrounged up #*#", eventForage)
    --[[mq.event("Novalue", "#*#give you absolutely nothing for the #1#.#*#", eventHandler)
    mq.event("Lore", "#*#You cannot loot this Lore Item.#*#", eventHandler)]]--
end

-- BINDS

local function commandHandler(...)
    local args = {...}
    --if #args == 1 then
    --    if args[1] == 'sell' then
    --        loot.sellStuff()
    --    end
    if #args == 2 then
        if validActions[args[1]] then
            addRule(args[2], args[2]:sub(1,1), validActions[args[1]])
        end
    elseif #args == 3 then
        if args[1] == 'quest' then
            addRule(args[2], args[2]:sub(1,1), 'Quest|'..args[3])
        end
    end
end

local function setupBinds()
    mq.bind('/lootutils', commandHandler)
end

-- LOOTING

local cantLootList = {}
local cantLootID = 0
eventCantLoot = function()
    cantLootID = mq.TLO.Target.ID()
end

local function lootItem(index, doWhat, button)
    loot.logger.Debug('Enter lootItem')
    if destroyActions[doWhat] then return end
    local corpseItemID = mq.TLO.Corpse.Item(index).ID()
    mq.cmdf('/nomodkey /shift /itemnotify loot%s %s', index, button)
    mq.delay(5000, function() return mq.TLO.Window('ConfirmationDialogBox').Open() or not mq.TLO.Corpse.Item(index).NoDrop() end)
    if mq.TLO.Window('ConfirmationDialogBox').Open() then mq.cmd('/nomodkey /notify ConfirmationDialogBox Yes_Button leftmouseup') end
    mq.delay(5000, function() return mq.TLO.Cursor() end)
    mq.delay(500)
    if doWhat == 'Destroy' and mq.TLO.Cursor.ID() == corpseItemID then mq.cmd('/destroy') end
    if mq.TLO.Cursor() then checkCursor() end
end

local function lootCorpse(corpseID)
    loot.logger.Debug('Enter lootCorpse')
    if mq.TLO.Cursor() then checkCursor() end
    mq.cmd('/loot')
    mq.delay(3000, function() return mq.TLO.Window('LootWnd').Open() end)
    mq.doevents('CantLoot')
    mq.delay(3000, function() return cantLootID > 0 or mq.TLO.Window('LootWnd').Open() end)
    if not mq.TLO.Window('LootWnd').Open() then
        loot.logger.Warn(('Can\'t loot %s right now'):format(mq.TLO.Target.CleanName()))
        cantLootList[corpseID] = os.time()
        return
    end
    mq.delay(3000, function() return mq.TLO.Corpse.Items() and mq.TLO.Corpse.Items() > 0 end)
    loot.logger.Debug(('Loot window open. Items: %d'):format(mq.TLO.Corpse.Items()))
    if mq.TLO.Window('LootWnd').Open() and mq.TLO.Corpse.Items() > 0 then
        for i=1,mq.TLO.Corpse.Items() do
            local corpseItem = mq.TLO.Corpse.Item(i)
            if corpseItem.Lore() and mq.TLO.FindItem(('=%s'):format(corpseItem.Name()))() then
                loot.logger.Warn('Cannot loot lore item')
            else
                lootItem(i, getRule(corpseItem.Name()), 'leftmouseup')
            end
        end
    end
    mq.cmd('/nomodkey /notify LootWnd LW_DoneButton leftmouseup')
    mq.delay(3000, function() return not mq.TLO.Window('LootWnd').Open() end)
    -- if the corpse doesn't poof after looting, there may have been something we weren't able to loot or ignored
    -- mark the corpse as not lootable for a bit so we don't keep trying
    if mq.TLO.Spawn(('corpse id %s'):format(corpseID))() then
        cantLootList[corpseID] = os.time()
    end
end

local function corpseLocked(corpseID)
    if not cantLootList[corpseID] then return false end
    if os.difftime(os.time(), cantLootList[corpseID]) > 60 then
        cantLootList[corpseID] = nil
        return false
    end
    return true
end

local spawnSearch = '%s radius %d zradius 50'
loot.lootMobs = function()
    loot.logger.Debug('Enter lootMobs')
    if not shouldLootMobs then return end
    local deadCount = mq.TLO.SpawnCount(spawnSearch:format('npccorpse', loot.radius))()
    loot.logger.Debug(string.format('There are %s corpses in range.', deadCount))
    local mobsNearby = mq.TLO.SpawnCount(spawnSearch:format('npc', loot.radius))()
    -- options for combat looting or looting disabled
    if deadCount == 0 or mobsNearby > 0 or mq.TLO.Me.Combat() or mq.TLO.Me.FreeInventory() == 0 then return end
    local corpseList = {}
    for i=1,deadCount do
        local corpse = mq.TLO.NearestSpawn(('%d,'..spawnSearch):format(i, 'npccorpse', loot.radius))
        table.insert(corpseList, corpse)
        -- why is there a deity check?
    end
    loot.logger.Debug(string.format('Trying to loot %d corpses.', #corpseList))
    for i=1,#corpseList do
        local corpse = corpseList[i]
        local corpseID = corpse.ID()
        if corpseID and corpseID > 0 and not corpseLocked(corpseID) then
            loot.logger.Debug('Moving to corpse ID='..tostring(corpseID))
            navToID(corpseID)
            corpse.DoTarget()
            mq.delay(100, function() return mq.TLO.Target.ID() == corpseID end)
            lootCorpse(corpseID)
            mq.doevents()
            if not shouldLootMobs then break end
        end
    end
    loot.logger.Debug('Done with corpse list.')
end

-- SELLING

eventSell = function(line, itemName)
    local firstLetter = itemName:sub(1,1):upper()
    if lootData[firstLetter] and lootData[firstLetter][itemName] == 'Sell' then return end
    if loot.addNewSales then
        loot.logger.Info(string.format('Setting %s to Sell', itemName))
        if not lootData[firstLetter] then lootData[firstLetter] = {} end
        lootData[firstLetter][itemName] = 'Sell'
        LIP.save(lootFile, lootData)
    end
end

local function goToVendor()
    if not mq.TLO.Target() then
        loot.logger.Warn('Please target a vendor')
        return false
    end
    local vendorName = mq.TLO.Target.CleanName()
    local vendorType = mq.TLO.Target.Type()
    if not vendorTypes[vendorType] or (vendorType == 'PET' and not vendorName:lower():find('familiar')) then
        loot.logger.Warn('Please target a vendor')
        return false
    end
    mq.delay(1000)
    loot.logger.Info('Doing business with '..vendorName)
    if mq.TLO.Target.Distance() > 15 then
        navToID(mq.TLO.Target.ID())
    end
    return true
end

local function openVendor()
    loot.logger.Debug('Opening merchant window')
    mq.cmd('/nomodkey /click right target')
    loot.logger.Debug('Waiting for merchant window to populate')
    mq.delay(5000, function() return mq.TLO.Merchant.ItemsReceived() end)
    return mq.TLO.Merchant.ItemsReceived()
end

local function sellToVendor(itemToSell)
    while mq.TLO.FindItemCount('='..itemToSell)() > 0 do
        if mq.TLO.Window('MerchantWnd').Open() then
            loot.logger.Info('Selling '..itemToSell)
            mq.cmdf('/nomodkey /itemnotify "%s" leftmouseup', itemToSell)
            mq.delay(1000, function() return mq.TLO.Window('MerchantWnd/MW_SelectedItemLabel').Text() == itemToSell end)
            mq.cmd('/nomodkey /shiftkey /notify merchantwnd MW_Sell_Button leftmouseup')
            mq.doevents()
            -- TODO: handle vendor not wanting item / item can't be sold
            mq.delay(1000, function() return mq.TLO.Window('MerchantWnd/MW_SelectedItemLabel').Text() == '' end)
        end
    end
end

loot.sellStuff = function()
    if not goToVendor() then return end
    if not openVendor() then return end
    -- sell any top level inventory items that are marked as well, which aren't bags
    for i=1,10 do
        local bagSlot = mq.TLO.InvSlot('pack'..i).Item
        if bagSlot.Container() == 0 then
            if bagSlot.ID() then
                local itemToSell = bagSlot.Name()
                local sellRule = getRule(itemToSell)
                if sellRule == 'Sell' then sellToVendor(itemToSell) end
            end
        end
    end
    -- sell any items in bags which are marked as sell
    for i=1,10 do
        local bagSlot = mq.TLO.InvSlot('pack'..i).Item
        local containerSize = bagSlot.Container()
        if containerSize and containerSize > 0 then
            for j=1,containerSize do
                local itemToSell = bagSlot.Item(j).Name()
                if itemToSell then
                    local sellRule = getRule(itemToSell)
                    if sellRule == 'Sell' then sellToVendor(itemToSell) end
                end
            end
        end
    end
    mq.flushevents('Sell')
    if mq.TLO.Window('MerchantWnd').Open() then mq.cmd('/nomodkey /notify MerchantWnd MW_Done_Button leftmouseup') end
end

-- FORAGING

eventForage = function()
    loot.logger.Debug('Enter eventForage')
    -- allow time for item to be on cursor incase message is faster or something?
    mq.delay(1000, function() return mq.TLO.Cursor() end)
    -- there may be more than one item on cursor so go until its cleared
    while mq.TLO.Cursor() do
        local cursorItem = mq.TLO.Cursor
        local foragedItem = cursorItem.Name()
        local forageRule = split(getRule(foragedItem))
        local ruleAction = forageRule[1] -- what to do with the item
        local ruleAmount = forageRule[2] -- how many of the item should be kept
        local currentItemAmount = mq.TLO.FindItemCount('='..foragedItem)()
        -- >= because .. does finditemcount not count the item on the cursor?
        if destroyActions[ruleAction] or (ruleAction == 'Quest' and currentItemAmount >= ruleAmount) then
            if mq.TLO.Cursor.Name() == foragedItem then
                loot.logger.Info('Destroying foraged item '..foragedItem)
                mq.cmd('/destroy')
                mq.delay(500)
            end
        -- will a lore item we already have even show up on cursor?
        -- free inventory check won't cover an item too big for any container so may need some extra check related to that?
        elseif (keepActions[ruleAction] or currentItemAmount < ruleAmount) and (not cursorItem.Lore() or currentItemAmount == 0) and (mq.TLO.Me.FreeInventory() or (cursorItem.Stackable() and cursorItem.FreeStack())) then
            loot.logger.Info('Keeping foraged item '..foragedItem)
            mq.cmd('/autoinv')
        else
            loot.logger.Warn('Unable to process item '..foragedItem)
            break
        end
        mq.delay(50)
    end
end

--

setupEvents()
setupBinds()

return loot