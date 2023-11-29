---@type Mq
local mq = require('mq')
local class = require('classes.classbase')
local helpers = require('utils.helpers')
local logger = require('utils.logger')
local movement = require('utils.movement')
local timer = require('utils.timer')
local abilities = require('ability')
local castUtils = require('cast')
local common = require('common')
local state = require('state')

local Magician = class:new()

--[[
    https://docs.google.com/document/d/1NHtWfaS6WJFurbzzWbzBOZdJ3cKn3F34m1TL5ZO3Vg0/edit#heading=h.5l4x9nc7jc3n
    http://forums.eqfreelance.net/index.php?topic=16654.0

    Sustained:
    1. self:addSpell('servant', {'Ravening Servant', 'Roiling Servant', 'Riotous Servant', 'Reckless Servant', 'Remorseless Servant'})
    2. self:addSpell('many', {'Fusillade of Many', 'Barrage of Many', 'Shockwave of Many', 'Volley of Many', 'Storm of Many'})
    3. self:addSpell('chaotic', {'Chaotic Magma', 'Chaotic Calamity', 'Chaotic Pyroclasm', 'Chaotic Inferno', 'Chaotic Fire'})
    4. self:addSpell('spear', {'Spear of Molten Dacite', 'Spear of Molten Luclinite', 'Spear of Molten Komatiite', 'Spear of Molten Arcronite', 'Spear of Molten Shieldstone'})

    Imp Twincast Burn:
    1. Riotous Servant
    2. Shockwave of Many
    3. Spear of Molten Komatiite
    4. Spear of Molten Arcronite
    (5. Chaotic Pyroclasm)

    Spell Twincast:
    1. Chaotic Pyroclasm
    2. Riotous Servant
    3. Shockwave of Many
    4. Spear of Molten Komatiite

    Sustained additional
    table.insert(self.DPSAbilities, common.getAA('Force of Elements'))
    table.insert(self.DPSAbilities, common.getItem('Molten Komatiite Orb'))
    self:addSpell('twincast', {'Twincast'})
    self:addSpell('alliance', {'Firebound Conjunction', 'Firebound Coalition', 'Firebound Covenant', 'Firebound Alliance'})
    self:addSpell('composite', {'Ecliptic Companion', 'Composite Companion', 'Dichotomic Companion'})

    self:addSpell('malo', {'Malosinera', 'Malosinetra', 'Malosinara', 'Malosinata', 'Malosinete'})

    Burns
    table.insert(self.burnAbilities, common.getAA('Heart of Skyfire')) --Glyph of Destruction
    table.insert(self.burnAbilities, common.getAA('Focus of Arcanum'))
    
    table.insert(self.burnAbilities, common.getAA('Host of the Elements'))
    table.insert(self.burnAbilities, common.getAA('Servant of Ro'))

    Host of the Elements, Servant of Ro -- cast after RS
    Imperative Minion, Imperative Servant -- clicky pets
    self:addSpell('servantclicky', {'Summon Valorous Servant', 'Summon Forbearing Servant', 'Summon Imperative Servant', 'Summon Insurgent Servant', 'Summon Mutinous Servant'})

    table.insert(self.burnAbilities, common.getAA('Spire of the Elements')) -- if no crit buff
    Thaumaturge\'s Focus -- if casting any magic spells'

    Burn AE
    Silent casting

    Firebound Coalition or Chaotic Pyroclasm -> RS -> Host of Elements -> Twincast -> Of Many
    Imp Twincast after spell Twincast
    Forceful Rejuv during ITC

    Pet
    table.insert(self.burnAbilities, common.getAA('Frenzied Burnout'))
    Zeal of the Elements
    Thaumaturgist\'s Infusion after burnout fades

    Buffs
    Elemental Form
    Burnout, Iceflame Rampart, Thaumaturge\'s Unity

    ModRods
    Radiant Modulation Shard, Wand of Freezing Modulation, Elemental Conversion
    Monster Summoning + Reclaim Energy

    Survival
    Shield of Destiny, Shield of Elements, Shared Health, Heart of Frostone

    Fade
    Drape of Shadows, Arcane Whisper

    Pets
    'air', {'Recruitment of Air', 'Conscription of Air', 'Manifestation of Air', 'Embodiment of Air', 'Convocation of Air'}
    'earth', {'Recruitment of Earth', 'Conscription of Earth', 'Manifestation of Earth', 'Embodiment of Earth', 'Convocation of Earth'}
    'fire', {'Recruitment of Fire', 'Conscription of Fire', 'Manifestation of Fire', 'Embodiment of Fire', 'Convocation of Fire'}
    'water', {'Recruitment of Water', 'Conscription of Water', 'Manifestation of Water', 'Embodiment of Water', 'Convocation of Water'}
    'monster', {'Monster Summoning XV', 'Monster Summoning XIV', 'Monster Summoning XIII', 'Monster Summoning XII', 'Monster Summoning XI'}
]]
function Magician:init()
    self.classOrder = {'assist', 'mash', 'debuff', 'cast', 'burn', 'heal', 'recover', 'buff', 'rest', 'managepet', 'rez'}
    self.spellRotations = {standard={}}
    self:initBase('mag')

    self:initClassOptions()
    self:loadSettings()
    self:initSpellLines()
    self:initSpellRotations()
    self:initHeals()
    self:initBuffs()
    self:initBurns()
    self:initDPSAbilities()
    self:initDebuffs()
    self:initDefensiveAbilities()
    self:addCommonAbilities()
end

function Magician:initClassOptions()
    self:addOption('EARTHFORM', 'Elemental Form: Earth', false, nil, 'Toggle use of Elemental Form: Earth', 'checkbox', 'FIREFORM', 'EarthForm', 'bool')
    self:addOption('FIREFORM', 'Elemental Form: Fire', true, nil, 'Toggle use of Elemental Form: Fire', 'checkbox', 'EARTHFORM', 'FireForm', 'bool')
    self:addOption('USEFIRENUKES', 'Use Fire Nukes', true, nil, 'Toggle use of fire nuke line', 'checkbox', nil, 'UseFireNukes', 'bool')
    self:addOption('USEMAGICNUKES', 'Use Magic Nukes', false, nil, 'Toggle use of magic nuke line', 'checkbox', nil, 'UseMagicNukes', 'bool')
    self:addOption('USEDEBUFF', 'Use Malo', false, nil, 'Toggle use of Malo', 'checkbox', nil, 'UseDebuff', 'bool')
    self:addOption('SUMMONMODROD', 'Summon Mod Rods', false, nil, 'Toggle summoning of mod rods', 'checkbox', nil, 'SummonModRod', 'bool')
    self:addOption('USEDS', 'Use Group DS', true, nil, 'Toggle casting of group damage shield', 'checkbox', nil, 'UseDS', 'bool')
    self:addOption('USETEMPDS', 'Use Temp DS', true, nil, 'Toggle casting of temporary damage shield', 'checkbox', nil, 'UseTempDS', 'bool')
end

function Magician:initSpellLines()
    self:addSpell('prenuke', {'Fickle Fire'}, {opt='USEFIRENUKES'})
    self:addSpell('firenuke', {'Spear of Ro', 'Sun Vortex', 'Seeking Flame of Seukor', 'Char', 'Bolt of Flame'}, {opt='USEFIRENUKES'})
    self:addSpell('fastfire', {'Burning Earth'}, {opt='USEFIRENUKES'})
    self:addSpell('magicnuke', {'Rock of Taelosia'}, {opt='USEMAGICNUKES'})
    self:addSpell('pet', {'Child of Water', 'Servant of Marr', 'Greater Vocaration: Water', 'Vocarate: Water', 'Conjuration: Water',
                        'Lesser Conjuration: Water', 'Minor Conjuration: Water', 'Greater Summoning: Water',
                        'Summoning: Water', 'Lesser Summoning: Water', 'Minor Summoning: Water', 'Elementalkin: Water'})
    self:addSpell('petbuff', {'Elemental Fury', 'Burnout V', 'Burnout IV', 'Burnout III', 'Burnout II', 'Burnout'})
    self:addSpell('petstrbuff', {'Rathe\'s Strength', 'Earthen Strength'}, {skipifbuff='Champion'})
    self:addSpell('orb', {'Summon: Molten Orb', 'Summon: Lava Orb'}, {summonMinimum=1, nodmz=true, pause=true})
    self:addSpell('petds', {'Iceflame Guard'})
    self:addSpell('servant', {'Raging Servant', 'Rampaging Servant'})
    self:addSpell('ds', {'Circle of Fireskin'}, {opt='USEDS'})
    self:addSpell('bigds', {'Frantic Flames', 'Pyrilen Skin', 'Burning Aura'}, {opt='USETEMPDS', classes={WAR=true,SHD=true,PAL=true}})
    self:addSpell('shield', {'Elemental Aura'})

    --self:addSpell('manaregen', {'Elemental Simulacrum', 'Elemental Siphon'}) -- self mana regen
    self:addSpell('acregen', {'Phantom Shield', 'Xegony\'s Phantasmal Guard'}) -- self regen/ac buff
    self:addSpell('petheal', {'Planar Renewal'}, {opt='HEALPET', pet=50}) -- pet heal

    self:addSpell('armor', {'Grant Spectral Plate'}) -- targeted, Summon Folded Pack of Spectral Plate
    self:addSpell('weapons', {'Grant Spectral Armaments'}) -- targeted, Summons Folded Pack of Spectral Armaments
    self:addSpell('jewelry', {'Grant Enibik\'s Heirlooms'}) -- targeted, Summons Folded Pack of Enibik's Heirlooms, includes muzzle
    self:addSpell('belt', {'Summon Crystal Belt'}) -- Summoned: Crystal Belt
end

function Magician:initSpellRotations()
    table.insert(self.spellRotations.standard, self.spells.servant)
    --table.insert(self.spellRotations.standard, self.spells.prenuke)
    table.insert(self.spellRotations.standard, self.spells.fastfire)
    table.insert(self.spellRotations.standard, self.spells.firenuke)
    table.insert(self.spellRotations.standard, self.spells.magicnuke)
end

function Magician:initDPSAbilities()
    table.insert(self.DPSAbilities, common.getAA('Force of Elements'))

    self.summonCompanion = common.getAA('Summon Companion')
end

function Magician:initBurns()
    table.insert(self.burnAbilities, common.getAA('Fundament: First Spire of the Elements'))
    table.insert(self.burnAbilities, common.getAA('Host of the Elements', {delay=1500}))
    table.insert(self.burnAbilities, common.getAA('Servant of Ro', {delay=500}))
    table.insert(self.burnAbilities, common.getAA('Frenzied Burnout'))
    table.insert(self.burnAbilities, common.getAA('Improved Twincast'))
end

function Magician:initHeals()
    table.insert(self.healAbilities, self.spells.petheal)
end

function Magician:initBuffs()
    table.insert(self.selfBuffs, common.getAA('Elemental Form: Earth', {opt='EARTHFORM'}))
    table.insert(self.selfBuffs, common.getAA('Elemental Form: Fire', {opt='FIREFORM'}))
    --table.insert(self.selfBuffs, self.spells.manaregen)
    if state.emu and not mq.TLO.FindItem('Glyphwielder\'s Sleeves of the Summoner')() then
        table.insert(self.selfBuffs, self.spells.shield)
    end
    table.insert(self.selfBuffs, self.spells.acregen)
    table.insert(self.selfBuffs, self.spells.orb)
    table.insert(self.selfBuffs, self.spells.ds)
    table.insert(self.selfBuffs, common.getAA('Large Modulation Shard', {opt='SUMMONMODROD', summonMinimum=1, nodmz=true}))
    table.insert(self.combatBuffs, common.getAA('Fire Core'))
    table.insert(self.singleBuffs, self.spells.bigds)

    table.insert(self.petBuffs, common.getItem('Focus of Primal Elements') or common.getItem('Staff of Elemental Essence', {CheckFor='Elemental Conjunction'}))
    table.insert(self.petBuffs, self.spells.petbuff)
    table.insert(self.petBuffs, self.spells.petstrbuff)
    table.insert(self.petBuffs, self.spells.petds)
    table.insert(self.petBuffs, common.getAA('Aegis of Kildrukaun'))
    table.insert(self.petBuffs, common.getAA('Fortify Companion'))

    self:addRequestAlias(self.spells.orb, 'orb')
    self:addRequestAlias(self.spells.ds, 'ds')
    self:addRequestAlias(self.spells.weapons, 'arm')
    self:addRequestAlias(self.spells.jewelry, 'jewelry')
    self:addRequestAlias(self.spells.armor, 'armor')
end

function Magician:initDebuffs()
    table.insert(self.debuffs, common.getAA('Malosinete', {opt='USEDEBUFF'}))
end

function Magician:initDefensiveAbilities()
    table.insert(self.fadeAbilities, common.getAA('Companion of Necessity'))
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

function Magician:pullCustom()
    movement.stop()
    mq.cmd('/pet attack')
    mq.cmd('/pet swarm')
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
local EnchanterPetPrimaryWeaponId = 10702

-- Checks pets for items and re-equips if necessary.
local armPetTimer = timer:new(60000)
function Magician:autoArmPets()
    if common.hostileXTargets() then return end
    if not self:isEnabled('ARMPETS') or not self.spells.weapons then return end
    if not armPetTimer:timerExpired() then return end
    armPetTimer:reset()

    self:armPets()
end

function Magician:clearCursor()
    while mq.TLO.Cursor() do
        mq.cmd('/autoinv')
        mq.delay(100)
    end
end

local armPetStates = {
    MOVETO='MOVETO',
    MAKEROOM='MAKEROOM',
    CASTWEAPONS='CASTWEAPONS',UNFOLDWEAPONS='UNFOLDWEAPONS',TRADEWEAPONS='TRADEWEAPONS',
    CASTARMOR='CASTARMOR',UNFOLDARMOR='UNFOLDARMOR',TRADEARMOR='TRADEARMOR',
    CASTJEWELRY='CASTJEWELRY',UNFOLDJEWELRY='UNFOLDJEWELRY',TRADEJEWELRY='TRADEJEWELRY',
    MOVEBACK='MOVEBACK',
}
function Magician:armPetsStateMachine()
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
function Magician:armPets()
    if mq.TLO.Cursor() then self:clearCursor() end
    if mq.TLO.Cursor() then
        logger.info('Unable to clear cursor, not summoning pet toys.')
        return
    end
    if not self.petWeapons then return end
    logger.info('Begin arming pets')
    state.paused = true
    local restoreGem1 = {Name=mq.TLO.Me.Gem(12)()}
    local restoreGem2 = {Name=mq.TLO.Me.Gem(11)()}
    local restoreGem3 = {Name=mq.TLO.Me.Gem(10)()}
    local restoreGem4 = {Name=mq.TLO.Me.Gem(9)()}

    local petPrimary = mq.TLO.Pet.Primary()
    local petID = mq.TLO.Pet.ID()
    if petID > 0 and petPrimary == 0 then
        state.armPet = petID
        state.armPetOwner = mq.TLO.Me.CleanName()
        local weapons = self.petWeapons.Self
        if weapons then
            self.armPet(petID, weapons, 'Me')
        end
    end

    for owner,weapons in pairs(self.petWeapons) do
        if owner ~= mq.TLO.Me.CleanName() then
            local ownerSpawn = mq.TLO.Spawn('pc ='..owner)
            if ownerSpawn() then
                local ownerPetID = ownerSpawn.Pet.ID()
                local ownerPetDistance = ownerSpawn.Pet.Distance3D() or 300
                local ownerPetLevel = ownerSpawn.Pet.Level() or 0
                local ownerPetPrimary = ownerSpawn.Pet.Primary() or -1
                if ownerPetID > 0 and ownerPetDistance < 50 and ownerPetLevel > 0 and (ownerPetPrimary == 0 or ownerPetPrimary == EnchanterPetPrimaryWeaponId) then
                    state.armPet = ownerPetID
                    state.armPetOwner = owner
                    mq.delay(2000, function() return self.spells.weapons:isReady() end)
                    self.armPet(ownerPetID, weapons, owner)
                end
            end
        end
    end
    if mq.TLO.Me.Gem(12)() ~= restoreGem1.Name then abilities.swapSpell(restoreGem1, 12) end
    if mq.TLO.Me.Gem(11)() ~= restoreGem2.Name then abilities.swapSpell(restoreGem2, 11) end
    if mq.TLO.Me.Gem(10)() ~= restoreGem3.Name then abilities.swapSpell(restoreGem3, 10) end
    if mq.TLO.Me.Gem(9)() ~= restoreGem4.Name then abilities.swapSpell(restoreGem4, 9) end
    state.paused = false
end

function Magician:armPetRequest(requester)
    if not self.petWeapons then return end
    local weapons = self.petWeapons[requester]
    if not weapons then return end
    local ownerSpawn = mq.TLO.Spawn('pc ='..requester)
    if ownerSpawn() then
        local ownerPetID = ownerSpawn.Pet.ID()
        local ownerPetDistance = ownerSpawn.Pet.Distance3D() or 300
        local ownerPetLevel = ownerSpawn.Pet.Level() or 0
        local ownerPetPrimary = ownerSpawn.Pet.Primary() or -1
        if ownerPetID > 0 and ownerPetDistance < 50 and ownerPetLevel > 0 and (ownerPetPrimary == 0 or ownerPetPrimary == EnchanterPetPrimaryWeaponId) then
            state.paused = true
            local restoreGem1 = {Name=mq.TLO.Me.Gem(12)()}
            local restoreGem2 = {Name=mq.TLO.Me.Gem(11)()}
            local restoreGem3 = {Name=mq.TLO.Me.Gem(10)()}
            local restoreGem4 = {Name=mq.TLO.Me.Gem(9)()}
            state.armPet = ownerPetID
            state.armPetOwner = requester
            mq.delay(2000, function() return self.spells.weapons:isReady() end)
            self.armPet(ownerPetID, weapons, requester)
            if mq.TLO.Me.Gem(12)() ~= restoreGem1.Name then abilities.swapSpell(restoreGem1, 12) end
            if mq.TLO.Me.Gem(11)() ~= restoreGem2.Name then abilities.swapSpell(restoreGem2, 12) end
            if mq.TLO.Me.Gem(10)() ~= restoreGem3.Name then abilities.swapSpell(restoreGem3, 12) end
            if mq.TLO.Me.Gem(9)() ~= restoreGem4.Name then abilities.swapSpell(restoreGem4, 12) end
            state.paused = false
        end
    end
end

function Magician:armPet(petID, weapons, owner)
    logger.info('Attempting to arm pet %s for %s', mq.TLO.Spawn('id '..petID).CleanName(), owner)

    local myX, myY, myZ = mq.TLO.Me.X(), mq.TLO.Me.Y(), mq.TLO.Me.Z()
    if not self.giveWeapons(petID, weapons or 'water|fire') then
        movement.navToLoc(myX, myY, myZ, nil, 2000)
        if state.isExternalRequest then
            logger.info('tell %s There was an error arming your pet', state.requester)
        else
            logger.info('there was an issue with arming a pet')
        end
        return
    end

    if self.spells.armor then
        mq.delay(3000, function() return self.spells.armor:isReady() end)
        if not self.giveOther(petID, self.spells.armor) then return end
    end
    if self.spells.jewelry then
        mq.delay(3000, function() return self.spells.jewelry:isReady() end)
        if not self.giveOther(petID, self.spells.jewelry) then return end
    end
    if mq.TLO.FindItemCount('=Gold')() >= 1 then
        logger.info('have gold to give!')
        mq.cmdf('/mqt id %s', petID)
        self.pickupWeapon('Gold')
        mq.delay(100)
        if mq.TLO.Cursor() == 'Gold' then
            self:giveCursorItemToTarget()
        else
            self:clearCursor()
        end
    end

    local petSpawn = mq.TLO.Spawn('id '..petID)
    if petSpawn() then
        logger.info('finished arming %s', petSpawn.CleanName())
    end

    movement.navToLoc(myX, myY, myZ, nil, 2000)
end

function Magician:giveWeapons(petID, weaponString)
    local weapons = helpers.split(weaponString, '|')
    local primary = weaponMap[weapons[1]]
    local secondary = weaponMap[weapons[2]]

    if not self.checkForWeapons(primary, secondary) then
        return false
    end

    mq.cmdf('/mqt id %s', petID)
    mq.delay(100)
    if mq.TLO.Target.ID() == petID then
        logger.info('Give primary weapon %s to pet %s', primary, petID)
        self.pickupWeapon(primary)
        if mq.TLO.Cursor() == primary then
            self:giveCursorItemToTarget()
        else
            self:clearCursor()
        end
        if not self.checkForWeapons(primary, secondary) then
            return false
        end
        logger.info('Give secondary weapon %s to pet %s', secondary, petID)
        self.pickupWeapon(secondary)
        mq.cmdf('/mqt id %s', petID)
        mq.delay(100)
        if mq.TLO.Cursor() == secondary then
            self:giveCursorItemToTarget()
        else
            self:clearCursor()
        end
        self:giveCursorItemToTarget()
    else
        return false
    end
    return true
end

-- If specifying 2 different weapons where only 1 of each is in the bag, this
-- will end up summoning two bags
function Magician:checkForWeapons(primary, secondary)
    local foundPrimary = mq.TLO.FindItem('='..primary)
    local foundSecondary = mq.TLO.FindItem('='..secondary)
    logger.info('Check inventory for weapons %s %s', primary, secondary)
    if not foundPrimary() or not foundSecondary() then
        local foundWeaponBag = mq.TLO.FindItem('='..weaponBag)
        if foundWeaponBag() then
            if not self.safeToDestroy(foundWeaponBag) then return false end
            mq.cmdf('/nomodkey /itemnotify "%s" leftmouseup', weaponBag)
            mq.delay(1000, function() return mq.TLO.Cursor() end)
            if mq.TLO.Cursor.ID() == foundWeaponBag.ID() then
                mq.cmd('/destroy')
            else
                logger.info('Unexpected item on cursor when trying to destroy %s', weaponBag)
                return false
            end
        else
            if not self:checkInventory() then
                if state.isExternalRequest then
                    logger.info('tell %s i was unable to free up inventory space', state.requester)
                else
                    logger.info('Unable to free up inventory space')
                end
                return false
            end
        end
        local summonResult = self.summonItem(self.spells.weapons, mq.TLO.Me.ID(), true, true)
        if not summonResult then
            logger.info('Error occurred summoning items')
            return false
        end
    end
    return true
end

function Magician:pickupWeapon(weaponName)
    local item = mq.TLO.FindItem('='..weaponName)
    local itemSlot = item.ItemSlot()
    local itemSlot2 = item.ItemSlot2()
    local packSlot = itemSlot - 22
    local inPackSlot = itemSlot2 + 1
    mq.cmdf('/nomodkey /ctrlkey /itemnotify in pack%s %s leftmouseup', packSlot, inPackSlot)
end

function Magician:giveOther(petID, spell)
    local itemName = summonedItemMap[spell.Name]
    local item = mq.TLO.FindItem('='..itemName)
    --if not item() then
        mq.cmdf('/mqt id %s', petID)
        local summonResult = self.summonItem(spell, petID, false, false)
        if not summonResult then
            logger.info('Error occurred summoning items')
            return false
        end
    --else
    --    mq.cmdf('/nomodkey /itemnotify "%s" rightmouseup')
    --    mq.delay(3000, function() return mq.TLO.Cursor() end)
    --end

    --mq.cmdf('/mqt id %s', petID)
    --self.giveCursorItemToTarget()
    return true
end

function Magician:summonItem(spell, targetID, summonsItem, inventoryItem)
    logger.info('going to summon item %s', spell.Name)
    --mq.cmd('/mqt 0')
    if not mq.TLO.Me.Gem(spell.Name)() then
        abilities.swapSpell(spell, 12)
    end
    mq.delay(5000, function() return mq.TLO.Me.SpellReady(spell.Name)() end)
    if not spell:isReady() then logger.info('Spell %s was not ready', spell.Name) return false end
    castUtils.cast(spell, targetID)

    mq.delay(300)
    if summonsItem then
        if not mq.TLO.Cursor.ID() then
            logger.info('Cursor was empty after casting %s', spell.Name)
            return false
        end

        self:clearCursor()
        local summonedItem = summonedItemMap[spell.Name]
        mq.cmdf('/nomodkey /itemnotify "%s" rightmouseup', summonedItem)
        mq.delay(3000, function() return mq.TLO.Cursor() end)
        mq.delay(1)
        if inventoryItem then self:clearCursor() end
    end
    return true
end

function Magician:giveCursorItemToTarget(moveback, clearTarget)
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

function Magician:safeToDestroy(bag)
    for i = 1, bag.Container() do
        local bagSlot = bag.Item(i)
        if bagSlot() and not bagSlot.NoRent() then
            logger.info('DO NOT DESTROY: Found non-NoRent item: %s in summoned bag', bagSlot.Name())
            return false
        end
    end
    return true
end

function Magician:checkInventory()
    local pouch = 'Pouch of Quellious'
    local bag = mq.TLO.FindItem('='..pouch)
    local pouchID = bag.ID()
    local summonedItemCount = mq.TLO.FindItemCount('='..pouch)()
    logger.info('cleanup Pouch of Quellious')
    for i=1,summonedItemCount do
        if not self.safeToDestroy(bag) then return false end
        mq.cmdf('/nomodkey /itemnotify "%s" leftmouseup', pouch)
        mq.delay(1000, function() return mq.TLO.Cursor.ID() == pouchID end)
        if mq.TLO.Cursor.ID() ~= pouchID then
            return false
        end
        mq.cmd('/destroy')
    end

    logger.info('cleanup Disenchanted Bags')
    bag = mq.TLO.FindItem('='..disenchantedBag)
    local bagID = bag.ID()
    summonedItemCount = mq.TLO.FindItemCount('='..disenchantedBag)()
    for i=1,summonedItemCount do
        if not self.safeToDestroy(bag) then return false end
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
    logger.info('find bag slot')
    for i=1,10 do
        local currentSlot = i
        local containerSlots = mq.TLO.Me.Inventory('pack'..i).Container() or 0
        local containerItemCount = mq.TLO.InvSlot('pack'..i).Item.Items() or 0

        -- slots empty
        if not containerSlots then
            logger.info('empty slot! %s', currentSlot)
            slotToMoveFrom = -1
            hasOpenInventorySlot = true
            break
        end

        -- empty bag
        if containerItemCount == 0 then
            logger.info('found empty bag %s', currentSlot)
            slotToMoveFrom = i
            break
        end

        if containerSlots - containerItemCount > 0 then
            logger.info('found bag with room')
            containerWithOpenSpace = i
        end

        -- its not a container or its empty, may move it
        if containerSlots == 0 or (containerSlots > 0 and containerItemCount == 0) then
            logger.info('found a item or empty bag we can move')
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
                logger.info('/nomodkey /itemnotify in pack%s %s leftmouseup', containerWithOpenSpace, i)
                mq.cmdf('/nomodkey /itemnotify in pack%s %s leftmouseup', containerWithOpenSpace, i)
                mq.delay(1000, function() return not mq.TLO.Cursor() end)
                mq.delay(1)
                hasOpenInventorySlot = true
                break
            end
        end

        if mq.TLO.Cursor() then self:clearCursor() end
    end
    return hasOpenInventorySlot
end

return Magician
