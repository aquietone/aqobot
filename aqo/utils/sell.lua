---@type Mq
local mq = require 'mq'
local LIP = require 'lib.LIP'

local lootFile = mq.configDir .. '/Loot.ini'
local lootData = LIP.load(lootFile)
local addNewSales = true

local function eventSell(line, itemName)
    local firstLetter = itemName:sub(1,1):upper()
    if lootData[firstLetter] and lootData[firstLetter][itemName] == 'Sell' then return end
    if addNewSales then
        print(string.format('Setting %s to Sell', itemName))
        if not lootData[firstLetter] then lootData[firstLetter] = {} end
        lootData[firstLetter][itemName] = 'Sell'
        LIP.save(lootFile, lootData)
    end
end

local function setupEvents()
    mq.event("Sell", "#*#You receive#*# for the #1#(s)#*#", eventSell)
    --[[
    mq.event("EditIniItem", "LootIniItem #1# #2#", eventHandler)
    mq.event("SellStuff", "NinjadvLoot selling items to vendor", eventHandler)
    mq.event("Broke", "#*#you cannot afford#*#", eventHandler)
    mq.event("Broke", "#*#you can't afford#*#", eventHandler)
    mq.event("Forage", "Your forage mastery has enabled you to find something else!", eventHandler)
    mq.event("Forage", "You have scrounged up #*#", eventHandler)
    mq.event("Forage", "You caught #*#", eventHandler)
    mq.event("InventoryFull", "#*#Your inventory appears full!#*#", eventHandler)
    mq.event("Novalue", "#*#give you absolutely nothing for the #1#.#*#", eventHandler)
    mq.event("NullSlot", "#*#Invalid item slot 'null#*#", eventHandler)
    mq.event("Lore", "#*#You cannot loot this Lore Item.#*#", eventHandler)]]--
end
setupEvents()

local vendorTypes = {NPC=true,PET=true}
local function NPC(npcName)
    if not npcName and mq.TLO.Target.Type() == 'npc' then npcName = mq.TLO.Target.CleanName() end
    mq.cmdf('/mqtar npc %s', npcName)
    mq.delay(100)
    if not vendorTypes[mq.TLO.Target.Type()] or (mq.TLO.Target.Type() == 'pet' and not mq.TLO.Target.CleanName():find('familiar')) then
        print('Please target a vendor')
        return
    end
    mq.delay(1000)
    print('Doing business with '..npcName)
    if mq.TLO.Target.Distance() > 15 then
        mq.cmd('/nav target')
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
    print('Opening merchant window')
    mq.cmd('/nomodkey /click right target')
    print('Waiting for merchant window to populate')
    mq.delay(5000, function() return mq.TLO.Merchant.ItemsReceived() end)
end

--[[ **************** Sell Loot Section ******************** ]]--

local function sellToVendor(itemToSell)
    while mq.TLO.FindItemCount('='..itemToSell)() > 0 do
        if mq.TLO.Window('MerchantWnd').Open() then
            print('Selling '..itemToSell)
            mq.cmdf('/nomodkey /itemnotify "%s" leftmouseup', itemToSell)
            mq.delay(50)
            mq.cmd('/nomodkey /shiftkey /notify merchantwnd MW_Sell_Button leftmouseup')
            mq.doevents()
            mq.delay(50)
        end
    end
end

local function addSellRule(itemName, section, rule)
    if not lootData[section] then
        lootData[section] = {}
    end
    lootData[section][itemName] = rule
    LIP.save(lootFile, lootData)
end

local function getSellRule(itemName)
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
        addSellRule(itemName, firstLetter, lootDecision)
    end
    return lootData[firstLetter][itemName]
end

local function sellStuff()
    NPC(mq.TLO.Target.CleanName())
    -- sell any top level inventory items that are marked as well, which aren't bags
    for i=1,10 do
        local bagSlot = mq.TLO.InvSlot('pack'..i).Item
        if bagSlot.Container() == 0 then
            if bagSlot.ID() then
                local itemToSell = bagSlot.Name()
                local sellRule = getSellRule(itemToSell)
                print(itemToSell, sellRule)
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
                    local sellRule = getSellRule(itemToSell)
                    print(itemToSell, sellRule)
                    if sellRule == 'Sell' then sellToVendor(itemToSell) end
                end
            end
        end
    end
    mq.flushevents('Sell')
    if mq.TLO.Window('MerchantWnd').Open() then mq.cmd('/nomodkey /notify MerchantWnd MW_Done_Button leftmouseup') end
end

sellStuff()

return {
    sellStuff=sellStuff
}