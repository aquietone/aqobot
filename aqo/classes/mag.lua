---@type Mq
local mq = require('mq')
local class = require('classes.classbase')
local movement = require('routines.movement')
local timer = require('utils.timer')
local common = require('common')
local state = require('state')

function class.init(_aqo)
    class.classOrder = {'assist', 'mash', 'debuff', 'cast', 'burn', 'heal', 'recover', 'buff', 'rest', 'managepet', 'rez'}
    class.spellRotations = {standard={}}
    class.initBase(_aqo, 'mag')

    class.initClassOptions()
    class.loadSettings()
    class.initSpellLines(_aqo)
    class.initSpellRotations(_aqo)
    class.initHeals(_aqo)
    class.initBuffs(_aqo)
    class.initBurns(_aqo)
    class.initDPSAbilities(_aqo)
    class.initDebuffs(_aqo)
    class.initDefensiveAbilities(_aqo)
end

function class.initClassOptions()
    class.addOption('EARTHFORM', 'Elemental Form: Earth', false, nil, 'Toggle use of Elemental Form: Earth', 'checkbox', 'FIREFORM')
    class.addOption('FIREFORM', 'Elemental Form: Fire', true, nil, 'Toggle use of Elemental Form: Fire', 'checkbox', 'EARTHFORM')
    class.addOption('USEFIRENUKES', 'Use Fire Nukes', true, nil, 'Toggle use of fire nuke line', 'checkbox')
    class.addOption('USEMAGICNUKES', 'Use Magic Nukes', false, nil, 'Toggle use of magic nuke line', 'checkbox')
    class.addOption('USEDEBUFF', 'Use Malo', false, nil, 'Toggle use of Malo', 'checkbox')
    class.addOption('SUMMONMODROD', 'Summon Mod Rods', false, nil, 'Toggle summoning of mod rods', 'checkbox')
    class.addOption('USEDS', 'Use Group DS', true, nil, 'Toggle casting of group damage shield', 'checkbox')
    class.addOption('USETEMPDS', 'Use Temp DS', true, nil, 'Toggle casting of temporary damage shield', 'checkbox')
end

function class.initSpellLines(_aqo)
    class.addSpell('prenuke', {'Fickle Fire'}, {opt='USEFIRENUKES'})
    class.addSpell('firenuke', {'Spear of Ro', 'Sun Vortex', 'Seeking Flame of Seukor', 'Char', 'Bolt of Flame'}, {opt='USEFIRENUKES'})
    class.addSpell('fastfire', {'Burning Earth'}, {opt='USEFIRENUKES'})
    class.addSpell('magicnuke', {'Rock of Taelosia'}, {opt='USEMAGICNUKES'})
    class.addSpell('pet', {'Child of Water', 'Servant of Marr', 'Greater Vocaration: Water', 'Vocarate: Water', 'Conjuration: Water',
                        'Lesser Conjuration: Water', 'Minor Conjuration: Water', 'Greater Summoning: Water',
                        'Summoning: Water', 'Lesser Summoning: Water', 'Minor Summoning: Water', 'Elementalkin: Water'})
    class.addSpell('petbuff', {'Burnout V', 'Burnout IV', 'Burnout III', 'Burnout II', 'Burnout'})
    class.addSpell('petstrbuff', {'Rathe\'s Strength', 'Earthen Strength'}, {skipifbuff='Champion'})
    class.addSpell('orb', {'Summon: Molten Orb', 'Summon: Lava Orb'}, {summons={'Molten Orb','Lava Orb'}, summonMinimum=1, nodmz=true})
    class.addSpell('petds', {'Iceflame Guard'})
    class.addSpell('servant', {'Rampaging Servant'})
    class.addSpell('ds', {'Circle of Fireskin'}, {opt='USEDS'})
    class.addSpell('bigds', {'Frantic Flames', 'Pyrilen Skin', 'Burning Aura'}, {opt='USETEMPDS', classes={WAR=true,SHD=true,PAL=true}})

    class.addSpell('manaregen', {'Elemental Simulacrum', 'Elemental Siphon'}) -- self mana regen
    class.addSpell('acregen', {'Phantom Shield', 'Xegony\'s Phantasmal Guard'}) -- self regen/ac buff
    class.addSpell('petheal', {'Planar Renewal'}, {opt='HEALPET', pet=50}) -- pet heal

    class.addSpell('armor', {'Grant Spectral Plate'}) -- targeted, Summon Folded Pack of Spectral Plate
    class.addSpell('weapons', {'Grant Spectral Armaments'}) -- targeted, Summons Folded Pack of Spectral Armaments
    class.addSpell('jewelry', {'Grant Enibik\'s Heirlooms'}) -- targeted, Summons Folded Pack of Enibik's Heirlooms, includes muzzle
    class.addSpell('belt', {'Summon Crystal Belt'}) -- Summoned: Crystal Belt
end

function class.initSpellRotations(_aqo)
    table.insert(class.spellRotations.standard, class.spells.servant)
    --table.insert(class.spellRotations.standard, class.spells.prenuke)
    table.insert(class.spellRotations.standard, class.spells.fastfire)
    table.insert(class.spellRotations.standard, class.spells.firenuke)
    table.insert(class.spellRotations.standard, class.spells.magicnuke)
end

function class.initDPSAbilities(_aqo)
    table.insert(class.DPSAbilities, common.getAA('Force of Elements'))
end

function class.initBurns(_aqo)
    table.insert(class.burnAbilities, common.getAA('Fundament: First Spire of the Elements'))
    table.insert(class.burnAbilities, common.getAA('Host of the Elements', {delay=1500}))
    table.insert(class.burnAbilities, common.getAA('Servant of Ro', {delay=500}))
    table.insert(class.burnAbilities, common.getAA('Frenzied Burnout'))
    table.insert(class.burnAbilities, common.getAA('Improved Twincast'))
end

function class.initHeals(_aqo)
    table.insert(class.healAbilities, class.spells.petheal)
end

function class.initBuffs(_aqo)
    local arcanum1 = common.getAA('Focus of Arcanum')
    local arcanum2 = common.getAA('Acute Focus of Arcanum', {skipifbuff='Enlightened Focus of Arcanum'})
    local arcanum3 = common.getAA('Enlightened Focus of Arcanum', {skipifbuff='Acute Focus of Arcanum'})
    local arcanum4 = common.getAA('Empowered Focus of Arcanum')
    table.insert(class.combatBuffs, arcanum2)
    table.insert(class.combatBuffs, arcanum3)

    table.insert(class.selfBuffs, common.getAA('Elemental Form: Earth', {opt='EARTHFORM'}))
    table.insert(class.selfBuffs, common.getAA('Elemental Form: Fire', {opt='FIREFORM'}))
    table.insert(class.selfBuffs, class.spells.manaregen)
    table.insert(class.selfBuffs, class.spells.acregen)
    table.insert(class.selfBuffs, class.spells.orb)
    table.insert(class.selfBuffs, class.spells.ds)
    table.insert(class.selfBuffs, common.getAA('Large Modulation Shard', {opt='SUMMONMODROD', summons='Summoned: Large Modulation Shard', summonMinimum=1, nodmz=true}))
    table.insert(class.combatBuffs, common.getAA('Fire Core'))
    table.insert(class.singleBuffs, class.spells.bigds)

    table.insert(class.petBuffs, class.spells.petbuff)
    table.insert(class.petBuffs, class.spells.petstrbuff)
    table.insert(class.petBuffs, class.spells.petds)

    class.addRequestAlias(class.spells.orb, 'orb')
    class.addRequestAlias(class.spells.ds, 'ds')
    class.addRequestAlias(class.spells.weapons, 'arm')
    class.addRequestAlias(class.spells.jewelry, 'jewelry')
    class.addRequestAlias(class.spells.armor, 'armor')
end

function class.initDebuffs(_aqo)
    table.insert(class.debuffs, common.getAA('Malosinete', {opt='USEDEBUFF'}))
end

function class.initDefensiveAbilities(_aqo)
    table.insert(class.fadeAbilities, common.getAA('Companion of Necessity'))
end

--[[
    "Fire", "Summoned: Fist of Flame",
    "Water", "Summoned: Orb of Chilling Water",
    "Shield", "Summoned: Buckler of Draining Defense",
    "Taunt", "Summoned: Short Sword of Warding",
    "Slow", "Summoned: Mace of Temporal Distortion",
    "Malo", "Summoned: Spear of Maliciousness",
    "Dispel", "Summoned: Wand of Dismissal",
    "Snare", "Summoned: Tendon Carver",
]]

function class.pullCustom()
    movement.stop()
    mq.cmd('/multiline ; /pet attack ; /pet swarm')
    mq.delay(1000)
end

-- Below pet arming code shamelessly stolen from Rekka and E3Next

local weaponBag = 'Pouch of Quellious'
local disenchantedBag = 'Huge Disenchanted Backpack'
local weaponMap = {
    ['fire'] = 'Summoned: Fist of Flame',
    ['water'] = 'Summoned: Orb of Chilling Water',
    ['shield'] = 'Summoned: Buckler of Draining Defense',
    ['taunt'] = 'Summoned: Short Sword of Warding',
    ['slow'] = 'Summoned: Mace of Temporal Distortion',
    ['malo'] = 'Summoned: Spear of Maliciousness',
    ['dispel'] = 'Summoned: Wand of Dismissal',
    ['snare'] = 'Summoned: Tendon Carver',
}
local summonedItemMap = {
    ['Grant Spectral Armaments'] = 'Folded Pack of Spectral Armaments',
    ['Grant Spectral Plate'] = 'Folded Pack of Spectral Plate',
    ['Grant Enibik\'s Heirlooms'] = 'Folded Pack of Enibik\'s Heirlooms',
}

-- Checks pets for items and re-equips if necessary.
local armPetTimer = timer:new(60)
function class.autoArmPets()
    if common.hostileXTargets() then return end
    if not class.isEnabled('ARMPETS') or not class.spells.weapons then return end
    if not armPetTimer:timerExpired() then return end
    armPetTimer:reset()

    class.armPets()
end

function class.clearCursor()
    mq.cmd('/autoinv')
    mq.delay(100)
end

local armPetStates = {
    MOVETO='MOVETO',
    MAKEROOM='MAKEROOM',
    CASTWEAPONS='CASTWEAPONS',UNFOLDWEAPONS='UNFOLDWEAPONS',TRADEWEAPONS='TRADEWEAPONS',
    CASTARMOR='CASTARMOR',UNFOLDARMOR='UNFOLDARMOR',TRADEARMOR='TRADEARMOR',
    CASTJEWELRY='CASTJEWELRY',UNFOLDJEWELRY='UNFOLDJEWELRY',TRADEJEWELRY='TRADEJEWELRY',
    MOVEBACK='MOVEBACK',
}
function class.armPetsStateMachine()
    if state.armPetState == armPetStates.MOVETO then
        -- while not at pet return
        -- at pet, set state to makeroom
    elseif state.armPetState == armPetStates.MAKEROOM then
        -- shuffle bags, can this fit in a pulse?
        -- set state to castweapons
    elseif state.armPetState == armPetStates.CASTWEAPONS then
        -- start cast, set state to unfold weapons
    elseif state.armPetState == armPetStates.UNFOLDWEAPONS then
        -- while not folded bag, return
        -- unfold bag, set state to trade weapons
    elseif state.armPetState == armPetStates.TRADEWEAPONS then
        -- trade weapons
        -- set state to castarmor
    elseif state.armPetState == armPetStates.CASTARMOR then
        -- while not spell ready, return
        -- start cast, set state to unfoldarmor
    elseif state.armPetState == armPetStates.UNFOLDARMOR then
        -- while not folded bag, return
        -- unfold bag, set state to tradearmor
    elseif state.armPetState == armPetStates.TRADEARMOR then
        -- trade armor
        -- set state to castjewelry
    elseif state.armPetState == armPetStates.CASTJEWELRY then
        -- while not spell ready, return
        -- start cast, set state to unfoldjewelry
    elseif state.armPetState == armPetStates.UNFOLDJEWELRY then
        -- while not folded bag, return
        -- unfold bag, set state to tradejewelry
    elseif state.armPetState == armPetStates.TRADEJEWELRY then
        -- trade jewelry
        -- move back, set state to moveback
    elseif state.armPetState == armPetStates.MOVEBACK then
        -- clear state
    end
end

--[[
    states:
    move to pet
    make bag space
    cast weapon bag
    unfold weapon bag
    trade weapons
    cast armor
    unfold armor
    trade armor
    cast jewelry
    unfold jewelry
    trade jewelry
    move back
]]
function class.armPets()
    if mq.TLO.Cursor() then class.clearCursor() end
    if mq.TLO.Cursor() then
        print('Unable to clear cursor, not summoning pet toys.')
        return
    end
    print('Begin arming pets')
    state.useStateMachine = false

    local petPrimary = mq.TLO.Pet.Primary()
    local petID = mq.TLO.Pet.ID()
    if petID > 0 and petPrimary == 0 then
        state.armPet = petID
        state.armPetOwner = mq.TLO.Me.CleanName()
        local weapons = class.petWeapons.Self
        if weapons then
            class.armPet(petID, weapons, 'Me')
        end
    end

    for owner,weapons in pairs(class.petWeapons) do
        if owner ~= mq.TLO.Me.CleanName() then
            local ownerSpawn = mq.TLO.Spawn('pc ='..owner)
            if ownerSpawn() then
                local ownerPetID = ownerSpawn.Pet.ID()
                local ownerPetDistance = ownerSpawn.Pet.Distance3D() or 300
                local ownerPetLevel = ownerSpawn.Pet.Level() or 0
                local ownerPetPrimary = ownerSpawn.Pet.Primary() or -1
                if ownerPetID > 0 and ownerPetDistance < 50 and ownerPetLevel > 0 and ownerPetPrimary == 0 then -- or theirPetPrimary == EnchanterPetPrimaryWeaponId
                    state.armPet = ownerPetID
                    state.armPetOwner = owner
                    mq.delay(2000, function() return class.spells.weapons:isReady() end)
                    class.armPet(ownerPetID, weapons, owner)
                end
            end
        end
    end
    state.useStateMachine = true
end

function class.armPet(petID, weapons, owner)
    printf('Attempting to arm pet %s for %s', mq.TLO.Spawn('id '..petID).CleanName(), owner)

    local myX, myY, myZ = mq.TLO.Me.X(), mq.TLO.Me.Y(), mq.TLO.Me.Z()
    if not class.giveWeapons(petID, weapons or 'water|fire') then
        movement.navToLoc(myX, myY, myZ, nil, 2000)
        if state.isExternalRequest then
            printf('tell %s There was an error arming your pet', state.requester)
        else
            printf('there was an issue with arming a pet')
        end
        return
    end

    if class.spells.armor then
        mq.delay(3000, function() return class.spells.armor:isReady() end)
        if not class.giveOther(petID, class.spells.armor) then return end
    end
    if class.spells.jewelry then
        mq.delay(3000, function() return class.spells.jewelry:isReady() end)
        if not class.giveOther(petID, class.spells.jewelry) then return end
    end
    if mq.TLO.FindItemCount('=Gold')() >= 1 then
        print('have gold to give!')
        mq.cmdf('/mqt id %s', petID)
        class.pickupWeapon('Gold')
        mq.delay(100)
        if mq.TLO.Cursor() == 'Gold' then
            class.giveCursorItemToTarget()
        else
            class.clearCursor()
        end
    end

    local petSpawn = mq.TLO.Spawn('id '..petID)
    if petSpawn() then
        printf('finished arming %s', petSpawn.CleanName())
    end

    movement.navToLoc(myX, myY, myZ, nil, 2000)
end

function class.giveWeapons(petID, weaponString)
    local weapons = common.split(weaponString, '|')
    local primary = weaponMap[weapons[1]]
    local secondary = weaponMap[weapons[2]]

    if not class.checkForWeapons(primary, secondary) then
        return false
    end

    mq.cmdf('/mqt id %s', petID)
    mq.delay(100)
    if mq.TLO.Target.ID() == petID then
        printf('Give primary weapon %s to pet %s', primary, petID)
        class.pickupWeapon(primary)
        if mq.TLO.Cursor() == primary then
            class.giveCursorItemToTarget()
        else
            class.clearCursor()
        end
        if not class.checkForWeapons(primary, secondary) then
            return false
        end
        printf('Give secondary weapon %s to pet %s', secondary, petID)
        class.pickupWeapon(secondary)
        mq.cmdf('/mqt id %s', petID)
        mq.delay(100)
        if mq.TLO.Cursor() == secondary then
            class.giveCursorItemToTarget()
        else
            class.clearCursor()
        end
        class.giveCursorItemToTarget()
    else
        return false
    end
    return true
end

-- If specifying 2 different weapons where only 1 of each is in the bag, this
-- will end up summoning two bags
function class.checkForWeapons(primary, secondary)
    local foundPrimary = mq.TLO.FindItem('='..primary)
    local foundSecondary = mq.TLO.FindItem('='..secondary)
    printf('Check inventory for weapons %s %s', primary, secondary)
    if not foundPrimary() or not foundSecondary() then
        local foundWeaponBag = mq.TLO.FindItem('='..weaponBag)
        if foundWeaponBag() then
            mq.cmdf('/nomodkey /itemnotify "%s" leftmouseup', weaponBag)
            mq.delay(1000, function() return mq.TLO.Cursor() end)
            if mq.TLO.Cursor.ID() == foundWeaponBag.ID() then
                mq.cmd('/destroy')
            else
                printf('Unexpected item on cursor when trying to destroy %s', weaponBag)
                return false
            end
        else
            if not class.checkInventory() then
                if state.isExternalRequest then
                    printf('tell %s i was unable to free up inventory space', state.requester)
                else
                    printf('Unable to free up inventory space')
                end
                return false
            end
        end
        local summonResult = class.summonItem(class.spells.weapons, true)
        if not summonResult then
            print('Error occurred summoning items')
            return false
        end
    end
    return true
end

function class.pickupWeapon(weaponName)
    local item = mq.TLO.FindItem('='..weaponName)
    local itemSlot = item.ItemSlot()
    local itemSlot2 = item.ItemSlot2()
    local packSlot = itemSlot - 22
    local inPackSlot = itemSlot2 + 1
    mq.cmdf('/nomodkey /ctrlkey /itemnotify in pack%s %s leftmouseup', packSlot, inPackSlot)
end

function class.giveOther(petID, spell)
    local itemName = summonedItemMap[spell.name]
    local item = mq.TLO.FindItem('='..itemName)
    if not item() then
        local summonResult = class.summonItem(spell)
        if not summonResult then
            print('Error occurred summoning items')
            return false
        end
    else
        mq.cmdf('/nomodkey /itemnotify "%s" rightmouseup')
        mq.delay(3000, function() return mq.TLO.Cursor() end)
    end

    mq.cmdf('/mqt id %s', petID)
    class.giveCursorItemToTarget()
    return true
end

function class.summonItem(spell, inventoryItem)
    printf('going to summon item %s', spell.name)
    mq.cmd('/mqt 0')
    if not spell:isReady() then printf('Spell %s was not ready', spell.name) return false end
    if not spell:use() then
        printf('Failed to cast %s', spell.name)
        return false
    end
    mq.delay(100)
    if not mq.TLO.Cursor.ID() then
        printf('Cursor was empty after casting %s', spell.name)
        return false
    end

    mq.cmd('/autoinv')
    mq.delay(100)
    local summonedItem = summonedItemMap[spell.name]
    mq.cmdf('/nomodkey /itemnotify "%s" rightmouseup', summonedItem)
    mq.delay(3000, function() return mq.TLO.Cursor() end)
    mq.delay(1)
    if inventoryItem then class.clearCursor() end
    return true
end

function class.giveCursorItemToTarget(moveback, clearTarget)
    local meX, meY, meZ = mq.TLO.Me.X(), mq.TLO.Me.Y(), mq.TLO.Me.Z()
    movement.navToTarget('dist=10', 2000)
    mq.cmd('/click left target')
    local targetType = mq.TLO.Target.Type()
    local windowType = 'TradeWnd'
    local buttonType = 'TRDW_Trade_Button'
    if targetType ~= 'PC' then windowType = 'GiveWnd' buttonType = 'GVW_Give_Button' end
    mq.delay(3000, function() return mq.TLO.Window(windowType).Open() end)
    if not mq.TLO.Window(windowType).Open() then
        mq.cmd('/autoinv')
        return
    end
    mq.cmdf('/squelch /nomodkey /notify %s %s leftmouseup', windowType, buttonType)
    mq.delay(3000, function() return not mq.TLO.Window(windowType).Open() end)
    if mq.TLO.Window(windowType).Open() then
        -- wait a bit?
        mq.delay(10000)
    end
    if clearTarget then
        mq.cmd('/squelch /nomodkey /keypress esc')
    end
    -- move back
    if moveback then
        movement.navToLoc(meX, meY, meZ, nil, 2000)
    end
end

function class.checkInventory()
    local pouch = 'Pouch of Quellious'
    local pouchID = mq.TLO.FindItem('='..pouch).ID()
    local summonedItemCount = mq.TLO.FindItemCount('='..pouch)()
    print('cleanup pouches')
    for i=1,summonedItemCount do
        mq.cmdf('/nomodkey /itemnotify "%s" leftmouseup', pouch)
        mq.delay(1000, function() return mq.TLO.Cursor.ID() == pouchID end)
        if mq.TLO.Cursor.ID() ~= pouchID then
            return false
        end
        mq.cmd('/destroy')
    end

    print('cleanup bags')
    local bagID = mq.TLO.FindItem('='..disenchantedBag).ID()
    summonedItemCount = mq.TLO.FindItemCount('='..disenchantedBag)()
    for i=1,summonedItemCount do
        mq.cmdf('/nomodkey /itemnotify "%s" leftmouseup', disenchantedBag)
        mq.delay(1000, function() return mq.TLO.Cursor.ID() == bagID end)
        if mq.TLO.Cursor.ID() ~= bagID then
            return false
        end
        mq.cmd('/destroy')
    end

    local containerWithOpenSpace = -1
    local slotToMoveFrom = -1
    local hasOpenInventorySlot = false

    -- if the first inventory slot is empty or an empty bag, this fails because it never sets containerWithOpenSpace
    print('find bag slot')
    for i=1,10 do
        local currentSlot = i
        local containerSlots = mq.TLO.Me.Inventory('pack'..i).Container()
        local containerItemCount = mq.TLO.InvSlot('pack'..i).Item.Items()

        -- slots empty
        if not containerSlots then
            printf('empty slot! %s', currentSlot)
            slotToMoveFrom = -1
            hasOpenInventorySlot = true
            break
        end

        -- empty bag
        if containerItemCount == 0 then
            printf('found empty bag %s', currentSlot)
            slotToMoveFrom = i
            break
        end

        if containerSlots - containerItemCount > 0 then
            print('found bag with room')
            containerWithOpenSpace = i
        end

        -- its not a container or its empty, may move it
        if containerSlots == 0 or (containerSlots > 0 and containerItemCount == 0) then
            print('found a item or empty bag we can move')
            slotToMoveFrom = currentSlot
        end
    end

    local freeInventory = mq.TLO.Me.FreeInventory()
    if freeInventory > 0 and containerWithOpenSpace > 0 and slotToMoveFrom > 0 then
        mq.cmdf('/nomodkey /itemnotify pack%s leftmouseup', slotToMoveFrom)
        mq.delay(250)

        if mq.TLO.Window('QuantityWnd').Open() then
            mq.cmd('/nomodkey /notify QuantityWnd QTYW_Accept_Button leftmouseup')
        end
        mq.delay(1000, function() return mq.TLO.Cursor() end)
        mq.delay(1)
    end

    freeInventory = mq.TLO.Me.FreeInventory()
    if freeInventory > 0 then
        hasOpenInventorySlot = true
    end

    if mq.TLO.Cursor.ID() and containerWithOpenSpace > 0 then
        local invslot = mq.TLO.Me.Inventory('pack'..containerWithOpenSpace)
        local slots = invslot.Container()
        for i=1,slots do
            local item = invslot.Item(i)
            if not item() then
                printf('/nomodkey /itemnotify in pack%s %s leftmouseup', containerWithOpenSpace, i)
                mq.cmdf('/nomodkey /itemnotify in pack%s %s leftmouseup', containerWithOpenSpace, i)
                mq.delay(1000, function() return not mq.TLO.Cursor() end)
                mq.delay(1)
                hasOpenInventorySlot = true
                break
            end
        end

        if mq.TLO.Cursor() then class.clearCursor() end
    end
    return hasOpenInventorySlot
end

return class