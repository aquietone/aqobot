---@type Mq
local mq = require('mq')
local logger = require('utils.logger')
local timer = require('utils.timer')
local state = require('state')

---@enum AbilityTypes
AbilityTypes = {
    Spell = 1,
    AA = 2,
    Disc = 3,
    Item = 4,
    Skill = 5,
    None = 6,
}

---@class Ability
---@field ID number # the ID of this ability
---@field Name string # the name of this ability
---@field CastName string # the name of the spell/item/disc/aa/skill to use
---@field SpellName string # the name of the spell which is cast by the spell/item/disc/aa/skill
---@field CastType AbilityTypes # spell, aa, disc, item, skill
---@field TargetType? string # The target type for the ability
---@field MyCastTime? number # The cast time of the spell or clicky
---@field Duration? number # The duration in seconds of the spell or clicky
---@field opt? string # configuration option to check is enabled before using this ability
---@field delay? number # time in MS to delay after using an ability, primarily for swarm pets that take time to spawn after activation
---@field threshold? number # number of mobs to be on aggro before using an AE ability, or % mana/end to begin using recover abilities
---@field combat? boolean # flag to indicate whether to use recover ability in combat. e.g. don't canni when we should be healing
---@field ooc? boolean # flag to indicate whether to use recover ability in ooc. e.g. don't canni if OOC
---@field minhp? number # minimum HP % threshold to use recover ability. e.g. don't canni below 50% HP
---@field mana? boolean # flag to indicate ability recovers mana
---@field endurance? boolean # flag to indicate ability recovers endurance
---@field quick? boolean # flag the ability as used for quick burns
---@field long? boolean # flag the ability as used for long burns
---@field me? number # ignored currently. should be % hp to use self heal abilities since non-heal classes don't expose healer options
---@field pet? number # percent HP to begin casting pet heal
---@field self? boolean # indicates the heal ability is a self heal, like monk mend
---@field regular? boolean # flag to indicate heal should be used as a regular heal
---@field panic? boolean # flag to indicate heal should be used as a panic heal
---@field group? boolean # flag to indicate heal should be used as a group heal
---@field pct? number # group heal injured percent
---@field classes? table # list of classes which a buff should be cast on
---@field CheckFor? string # other name to check for presence of a buff, primarily when the buff name doesn't match the spell name
---@field skipifbuff? string # do not use this ability if the buff indicated by this string is already present
---@field SummonID? string # name of item summoned by this ability
---@field summonMinimum? number # minimum amount of summoned item to keep
---@field ReagentID? number # reagent ID required for summon ability to function
---@field ReagentCount? number # number of ReagentID item required to cast the spell
---@field precast? function # function to call prior to using an ability
---@field postcast? function # function to call after to using an ability
---@field usebelowpct? number # percent hp to begin using an ability, like executes
---@field maxdistance? number # distance within which an ability should be used, like don't leap from a mile away
---@field overwritedisc? string # name of disc which is acceptable to overwrite
---@field aggro? boolean # flag to indicate if the ability is for getting aggro, like taunt
---@field stand? boolean # flag to indicate if should stand after use, for FD dropping agro
---@field tot? boolean # flag to indicate if spell is target-of-target
---@field RemoveBuff? string # name of buff / song to remove after cast
---@field nodmz? boolean #flag to indicate if this ability should be used in DMZ list zones
---@field condition? function # function to evaluate to determine whether to use the ability
---@field overwrite? string # name of disc which may be overwritten by this disc
local Ability = {
    ID=0,
    Name = '',
    CastType = AbilityTypes.Spell,
}

local aqo
function Ability.init(_aqo)
    aqo = _aqo
end

    ---Initialize a new ability istance.
---@param spellData table #
---@param type AbilityTypes #
---@return Ability #
function Ability:new(spellData, type)
    local ability = {
        SpellName = spellData.Name,
        CastName = spellData.Name,
        CastType = type,
        timer = timer:new(2000)
    }
    ability.timer:reset(0)
    setmetatable(ability, self)
    self.__index = self
    for key,value in pairs(spellData) do
        ability[key] = value
    end
    ability:setSpellType()
    ability:setSpellData()
    return ability
end

function Ability:tostring()
    local s = 'Spell['
    for k,v in pairs(self) do
        s = s .. k .. '=' .. tostring(v) .. ', '
    end
    s = s .. ']'
    logger.info(s)
end

-- what was skipSelfStack
function Ability.shouldUseSpell(spell, skipSelfStack)
    logger.debug(logger.flags.ability.validation, 'ENTER shouldUseSpell \ag%s\ax', spell.Name())
    local result = false
    local requireTarget = false
    local dist = mq.TLO.Target.Distance3D()
    if spell.Beneficial() then
        if spell.TargetType() == 'Group v1' and not spell.Stacks() then return false end
        -- duration is number of ticks, so it tostring'd
        if spell.Duration.TotalSeconds() ~= 0 then
            if spell.TargetType() == 'Self' then
                -- skipselfstack == true when its a disc, so that a defensive disc can still replace a always up sort of disc
                -- like war resolute stand should be able to replace primal defense
                result = ((skipSelfStack or spell.Stacks()) and not mq.TLO.Me.Buff(spell.Name())() and not mq.TLO.Me.Song(spell.Name())()) == true
            elseif spell.TargetType() == 'Single' then
                result = (dist and dist <= spell.MyRange() and spell.StacksTarget() and not mq.TLO.Target.Buff(spell.Name())()) == true
                requireTarget = true
            else
                -- no one to check stacking on, sure
                result = true
            end
        else
            if spell.TargetType() == 'Single' then
                result = (dist and dist <= spell.MyRange()) == true
                requireTarget = true
            else
                -- instant beneficial spell, sure
                result = true
            end
        end
    else
        -- duration is number of ticks, so it tostring'd
        if spell.Duration.TotalSeconds() ~= 0 then
            if spell.TargetType() == 'Single' or spell.TargetType() == 'Targeted AE' then
                result = (dist and dist <= spell.MyRange() and mq.TLO.Target.LineOfSight() and spell.StacksTarget() and not mq.TLO.Target.MyBuff(spell.Name())()) == true
                requireTarget = true
            else
                -- no one to check stacking on, sure
                result = true
            end
        else
            if spell.TargetType() == 'Single' or spell.TargetType() == 'LifeTap' or spell.TargetType() == 'Line of Sight' then
                result = (dist and dist <= spell.MyRange() and mq.TLO.Target.LineOfSight()) == true
                requireTarget = true
            else
                -- instant detrimental spell that requires no target, sure
                result = true
            end
        end
    end
    logger.debug(logger.flags.ability.validation, 'EXIT shouldUseSpell: \ag%s\ax=%s', spell.Name(), result)
    return result, requireTarget
end

function Ability.canUseSpell(spell, abilityType, skipReagentCheck)
    logger.debug(logger.flags.ability.validation, 'ENTER canUseSpell \ag%s\ax', spell.Name())
    if abilityType == AbilityTypes.Spell and not mq.TLO.Me.SpellReady(spell.Name())() then
        if logger.flags.common.cast then
            logger.debug(logger.flags.ability.validation, 'Spell not ready (id=%s, name=%s, type=%s)', spell.ID(), spell.Name(), abilityType)
        end
        return false
    end
    if state.class ~= 'brd' and (mq.TLO.Me.Casting() or mq.TLO.Me.Moving()) then
        if logger.flags.common.cast then
            logger.debug(logger.flags.ability.validation, 'Not in control or moving (id=%s, name=%s, type=%s)', spell.ID(), spell.Name(), abilityType)
        end
        return false
    end
    if abilityType ~= AbilityTypes.Item and (spell.Mana() > mq.TLO.Me.CurrentMana() or spell.EnduranceCost() > mq.TLO.Me.CurrentEndurance()) then
        if logger.flags.common.cast then
            logger.debug(logger.flags.ability.validation, 'Not enough mana or endurance (id=%s, name=%s, type=%s)', spell.ID(), spell.Name(), abilityType)
        end
        return false
    end
    -- emu hack for bard for the time being, songs requiring an instrument are triggering reagent logic?
    if not skipReagentCheck then
        for i=1,3 do
            local reagentid = spell.ReagentID(i)()
            if reagentid ~= -1 then
                local reagent_count = spell.ReagentCount(i)()
                if mq.TLO.FindItemCount(reagentid)() < reagent_count then
                    if logger.flags.ability.validation then
                        logger.debug(logger.flags.ability.validation, 'Missing Reagent for (id=%d, name=%s, type=%s, reagentid=%s)', spell.ID(), spell.Name(), abilityType, reagentid)
                    end
                    return false
                end
            else
                break
            end
        end
    end
    logger.debug(logger.flags.ability.validation, 'EXIT canUseSpell: \ag%s\ax=%s', spell.Name(), 'true')
    return true
end

function Ability.use(theAbility, doSwap)
    local result = false
    logger.debug(logger.flags.ability.all, 'ENTER Ability.use \ag%s\ax', theAbility.Name)
    if not theAbility.timer:timerExpired() then return result end
    if mq.TLO.Me.Casting() and (state.class ~= 'BRD' or theAbility.MyCastTime >= 500) then return result end
    if (theAbility:isReady() or (theAbility.CastType == AbilityTypes.Spell and doSwap)) and (not theAbility.condition or theAbility.condition(theAbility)) and aqo.class.isAbilityEnabled(theAbility.opt) then
        if theAbility.CastType == AbilityTypes.Spell and doSwap then
            result = Ability.swapAndCast(theAbility, state.swapGem)
        else
            --if theAbility.pause then mq.cmd('/squelch /dga aqo /squelch /aqo pauseforbuffs') end
            if theAbility.precast then theAbility.precast() end
            result = theAbility:execute()
            if theAbility.postcast then theAbility.postcast() end
            --if theAbility.pause then state.queuedAction = function() mq.cmd('/squelch /dga aqo /squelch /aqo resumeforbuffs') end end
        end
    end
    return result
end

---@class Spell : Ability
local Spell = {}

function Spell:isReady()
    local spellData = mq.TLO.Spell(self.Name)
    return Ability.canUseSpell(spellData, self.CastType)-- and Ability.shouldUseSpell(spellData)
end

---Initialize a new spell instance
---@param spellData table #
---@return Ability #
function Spell:new(spellData)
    local spell = Ability:new(spellData, AbilityTypes.Spell)
    setmetatable(spell, self)
    self.__index = self
    self.tostring = Ability.tostring
    return spell
end

function Spell:execute()
    logger.debug(logger.flags.ability.spell, 'ENTER Spell:execute \ag%s\ax', self.Name)
    if state.class == 'brd' then mq.cmd('/stopsong') mq.delay(1) end
    local requiresTarget = self.TargetType == 'Single'
    if logger.flags.announce.spell then logger.info('Casting \ag%s\ax%s', self.Name, requiresTarget and (' on \at%s\ax'):format(mq.TLO.Target.CleanName()) or '') end
    mq.cmdf('/cast "%s"', self.Name)
    state.setCastingState(self)
    return true
end

function Spell:use()
    logger.debug(logger.flags.ability.spell, 'ENTER spell:use \ag%s\ax', self.Name)
    local spell = mq.TLO.Spell(self.Name)
    if (state[self.Name] and not state[self.Name]:timerExpired()) or not Ability.canUseSpell(spell, self.CastType) then return end
    local result, requiresTarget =  Ability.shouldUseSpell(spell)
    if not result then return false end
    if state.class == 'brd' then mq.cmd('/stopsong') mq.delay(1) end
    if logger.flags.announce.spell then logger.info('Casting \ag%s\ax%s', self.Name, requiresTarget and (' on \at%s\ax'):format(mq.TLO.Target.CleanName()) or '') end
    mq.cmdf('/cast "%s"', self.Name)
    state.resetCastingState()
    state.casting = self
    state.actionTaken = true
    state[self.Name] = timer:new(2000)
    return true
end

---@class Disc : Ability
local Disc = {}

---Initialize a new Disc instance
---@param spellData table #
---@return Ability #
function Disc:new(spellData)
    local disc = Ability:new(spellData, AbilityTypes.Disc)
    setmetatable(disc, self)
    self.__index = self
    self.tostring = Ability.tostring
    return disc
end

---Determine whether the disc specified by name is an "active" disc that appears in ${Me.ActiveDisc}.
---@return boolean @Returns true if the disc is an active disc, otherwise false.
function Disc:isActive()
    local spell = mq.TLO.Spell(self.Name)
    return spell.IsSkill() and (tonumber(spell.Duration()) or 0) > 0 and spell.TargetType() == 'Self' and not spell.StacksWithDiscs()
end

---Determine whether an disc is ready, including checking whether the character is currently capable.
---@return boolean @Returns true if the disc is ready to be used, otherwise false.
function Disc:isReady()
    if mq.TLO.Me.CombatAbilityReady(self.Name)() then
        local spell = mq.TLO.Spell(self.Name)
        return Ability.canUseSpell(spell, self.CastType) and Ability.shouldUseSpell(spell)--true
    else
        return false
    end
end

function Disc:execute()
    logger.debug(logger.flags.ability.disc, 'ENTER disc:execute \ag%s\ax', self.Name)
    if self.overwrite and mq.TLO.Me.ActiveDisc() == self.overwrite then mq.cmd('/stopdisc') end
    if not self:isActive() or not mq.TLO.Me.ActiveDisc.ID() then
        if logger.flags.announce.skill then logger.info('Use Disc: \ag%s\ax%s', self.Name, self.TargetType == 'Single' and (' on \at%s\ax'):format(mq.TLO.Target.CleanName()) or '') end
        if self.Name:find('Composite') then
            mq.cmdf('/disc %s', self.ID)
        else
            mq.cmdf('/disc %s', self.Name)
        end
        state.setCastingState(self)
        return true
    end
end

---Use the disc specified in the passed in table disc.
---@param overwrite string|nil @The name of a disc which should be stopped in order to run this disc.
function Disc:use(overwrite)
    logger.debug(logger.flags.ability.disc, 'ENTER disc:use \ag%s\ax', self.Name)
    local spell = mq.TLO.Spell(self.Name)
    if (state[self.Name] and not state[self.Name]:timerExpired()) or not self:isReady() then return end
    if not self:isActive() or not mq.TLO.Me.ActiveDisc.ID() then
        if logger.flags.announce.skill then logger.info('Use Disc: \ag%s\ax%s', self.Name, self.TargetType == 'Single' and (' on \at%s\ax'):format(mq.TLO.Target.CleanName()) or '') end
        if self.Name:find('Composite') then
            mq.cmdf('/disc %s', self.ID)
        else
            mq.cmdf('/disc %s', self.Name)
        end
        if spell.CastTime() > 0 then
            state.resetCastingState()
            state.casting = self
            state.actionTaken = true
        end
        state[self.Name] = timer:new(2000)
    elseif overwrite == mq.TLO.Me.ActiveDisc.Name() then
        mq.cmd('/stopdisc')
        mq.delay(50)
        if logger.flags.announce.disc then logger.info('Use Disc: \ag%s\ax%s', self.Name, self.TargetType == 'Single' and (' on \at%s\ax'):format(mq.TLO.Target.CleanName()) or '') end
        mq.cmdf('/disc %s', self.Name)
        state.resetCastingState()
        state.casting = self
        state.actionTaken = true
        state[self.Name] = timer:new(2000)
        return true
    else
        logger.debug(logger.flags.ability.disc, 'Not casting due to conflicting active disc (%s)', self.Name)
    end
end

---@class AA : Ability
local AA = {}

---Initialize a new AA instance
---@param spellData table #
---@return Ability #
function AA:new(spellData)
    local aa = Ability:new(spellData, AbilityTypes.AA)
    setmetatable(aa, self)
    self.__index = self
    self.tostring = Ability.tostring
    return aa
end

---Determine whether an AA is ready, including checking whether the character is currently capable.
---@return boolean @Returns true if the AA is ready to be used, otherwise false.
function AA:isReady()
    if mq.TLO.Me.AltAbilityReady(self.Name)() then
        local spell = mq.TLO.AltAbility(self.Name).Spell
        return Ability.canUseSpell(spell, self.CastType) and Ability.shouldUseSpell(spell)
    else
        return false
    end
end

function AA:execute()
    logger.debug(logger.flags.ability.aa, 'ENTER AA:execute \ag%s\ax', self.Name)
    if logger.flags.announce.aa then
        logger.info('Use AA: \ag%s\ax%s', self.Name, self.TargetType == 'Single' and (' on \at%s\ax'):format(mq.TLO.Target.CleanName()) or '')
    end
    mq.cmdf('/alt activate %d', self.ID)
    state.setCastingState(self)
    return true
end

---Use the AA specified in the passed in table aa.
---@return boolean @Returns true if the ability was fired, otherwise false.
function AA:use()
    logger.debug(logger.flags.ability.aa, 'ENTER AA:use \ag%s\ax', self.Name)
    if (state[self.Name] and not state[self.Name]:timerExpired()) or not self:isReady() then return false end
    if logger.flags.announce.aa then logger.info('Use AA: \ag%s\ax%s', self.Name, self.TargetType == 'Single' and (' on \at%s\ax'):format(mq.TLO.Target.CleanName()) or '') end
    mq.cmdf('/alt activate %d', self.ID)
    if mq.TLO.AltAbility(self.Name).Spell.CastTime() > 0 then
        state.resetCastingState()
        state.casting = self
        state.actionTaken = true
    end
    state[self.Name] = timer:new(2000)
    return true
end

---@class Item : Ability
local Item = {}

---Initialize a new Item instance
---@param spellData table #
---@return Ability #
function Item:new(spellData)
    local item = Ability:new(spellData, AbilityTypes.Item)
    setmetatable(item, self)
    self.__index = self
    self.tostring = Ability.tostring
    return item
end

function Item:isReady(item)
    if not item then
        item = mq.TLO.FindItem(self.ID)
    end
    if state.subscription ~= 'GOLD' and item.Prestige() then return false end
    local spell = item() and item.Clicky.Spell
    if spell and spell() and item.Timer.TotalSeconds() == 0 then
        return Ability.canUseSpell(spell, self.CastType) and Ability.shouldUseSpell(spell)
    else
        return false
    end
end

function Item:execute()
    logger.debug(logger.flags.ability.item, 'ENTER item:execute \ag%s\ax', self.Name)
    if state.class == 'brd' and mq.TLO.Me.Casting() and self.MyCastTime > 500 then mq.cmd('/stopcast') mq.delay(250) end
    if logger.flags.announce.item then logger.info('Use Item: \ag%s\ax%s', self.Name, self.TargetType == 'Single' and (' on \at%s\ax'):format(mq.TLO.Target.CleanName()) or '') end
    mq.cmdf('/useitem "%s"', self.Name)
    state.setCastingState(self)
    return true
end

---Use the item specified by item.
---@return boolean @Returns true if the item was fired, otherwise false.
function Item:use()
    logger.debug(logger.flags.ability.item, 'ENTER item:use \ag%s\ax', self.Name)
    local theItem = mq.TLO.FindItem(self.ID)
    if (state[self.Name] and not state[self.Name]:timerExpired()) or not self:isReady(theItem) then return false end
    if state.class == 'brd' and mq.TLO.Me.Casting() and self.MyCastTime > 500 then mq.cmd('/stopcast') mq.delay(250) end
    if logger.flags.announce.item then logger.info('Use Item: \ag%s\ax%s', theItem, self.TargetType == 'Single' and (' on \at%s\ax'):format(mq.TLO.Target.CleanName()) or '') end
    mq.cmdf('/useitem "%s"', theItem)
    if self.MyCastTime > 0 then
        state.resetCastingState()
        state.casting = self
        state.actionTaken = true
    end
    state[self.Name] = timer:new(2000)
    return true
end

---@class Skill : Ability
local Skill = {}

---Initialize a new Skill instance
---@param spellData table #
---@return Ability #
function Skill:new(spellData)
    local skill = Ability:new(spellData, AbilityTypes.Skill)
    setmetatable(skill, self)
    self.__index = self
    self.tostring = Ability.tostring
    return skill
end

function Skill:isReady()
    return mq.TLO.Me.AbilityReady(self.Name)() and mq.TLO.Me.Skill(self.Name)() > 0
end

function Skill:execute()
    logger.debug(logger.flags.ability.skill, 'ENTER skill:execute \ag%s\ax', self.Name)
    if logger.flags.announce.skill then logger.info('Use skill: \ag%s\ax%s', self.Name, mq.TLO.Target() and (' on \at%s\ax'):format(mq.TLO.Target.CleanName()) or '') end
    mq.cmdf('/doability "%s"', self.Name)
    state.setCastingState(self)
    return true
end

---Use the ability specified by name. These are basic abilities like taunt or kick.
function Skill:use()
    logger.debug(logger.flags.ability.skill, 'ENTER skill:use \ag%s\ax', self.Name)
    if self:isReady() then
        if logger.flags.announce.skill then logger.info('Use skill: \ag%s\ax%s', self.Name, mq.TLO.Target() and (' on \at%s\ax'):format(mq.TLO.Target.CleanName()) or '') end
        mq.cmdf('/doability "%s"', self.Name)
        state[self.Name] = timer:new(2000)
        return true
    end
end

---Swap the specified spell into the specified gem slot.
---@param spell table @The MQ Spell to memorize.
---@param gem number @The gem index to memorize the spell into.
---@param other_names table|nil @List of spell names to compare against, because of dissident,dichotomic,composite
function Ability.swapSpell(spell, gem, other_names)
    if not spell or not gem or mq.TLO.Me.Casting() or mq.TLO.Cursor() then return end
    if mq.TLO.Me.Gem(gem)() == spell.Name then return end
    if other_names and other_names[mq.TLO.Me.Gem(gem)()] then return end
    mq.cmdf('/memspell %d "%s"', gem, spell.Name)
    state.actionTaken = true
    state.memSpell = spell
    state.memSpellTimer:reset()
    return true
end

function Ability.swapAndCast(spell, gem)
    if not spell then return false end
    if not mq.TLO.Me.Gem(spell.Name)() then
        state.restore_gem = {Name=mq.TLO.Me.Gem(gem)(),gem=gem}
        if not Ability.swapSpell(spell, gem) then
            -- failed to mem?
            return false
        end
        state.queuedAction = function()
            Ability.use(spell)
            if state.restore_gem then
                return function()
                    Ability.swapSpell(state.restore_gem, gem)
                end
            end
        end
        return true
    else
        return Ability.use(spell)
    end
end

function Ability:setSpellType()
    if mq.TLO.Me.AltAbility(self.CastName).Spell() then
        self.CastType = AbilityTypes.AA
    elseif mq.TLO.Me.Book(self.CastName)() then
        self.CastType = AbilityTypes.Spell
        self.SpellInBook = true
    elseif mq.TLO.Me.CombatAbility(self.CastName)() then
        self.CastType = AbilityTypes.Disc
    elseif mq.TLO.Me.Ability(self.CastName)() then
        self.CastType = AbilityTypes.Skill
    elseif mq.TLO.FindItem('='..self.CastName)() then
        self.CastType = AbilityTypes.Item
    else
        self.CastType = AbilityTypes.None
    end
end

function Ability:setSpellData()
    if self.CastType == AbilityTypes.Item then
        local itemRef
        if tonumber(self.CastName) then
            itemRef = mq.TLO.FindItem(self.CastName)
        else
            itemRef = mq.TLO.FindItem('='..self.CastName)
        end

        local itemSpellRef = itemRef.Spell
        self:setCommonSpellData(itemSpellRef)

        self.MyCastTime = itemRef.CastTime()
        if itemRef.EffectType() == 'Click Worn' then
            self.MustEquip = true
        end

        self.SpellName = itemSpellRef.Name()
        self.CastID = itemRef.ID()
    elseif self.CastType == AbilityTypes.AA then
        local aaRef = mq.TLO.Me.AltAbility(self.CastName)
        local aaSpellRef = aaRef.Spell
        self:setCommonSpellData(aaSpellRef)

        self.RecastTime = aaRef.ReuseTime()
        self.SpellName = aaSpellRef.Name()
        self.CastID = aaRef.ID()
    elseif self.CastType == AbilityTypes.Spell then
        local spellRef = mq.TLO.Spell(self.CastName)
        self:setCommonSpellData(spellRef)

        self.Mana = spellRef.Mana()
        self.CastID = self.SpellID
    elseif self.CastType == AbilityTypes.Disc then
        local spellRef = mq.TLO.Spell(self.CastName)
        self:setCommonSpellData(spellRef)

        self.EnduranceCost = spellRef.EnduranceCost()
        self.CastID = self.SpellID
    elseif self.CastType == AbilityTypes.Skill then
        -- nothing to do
    end

    if self.CheckFor then
        if mq.TLO.Me.AltAbility(self.CheckFor).Spell() then
            self.CheckForID = mq.TLO.Me.AltAbility(self.CheckFor).Spell.ID()
        elseif mq.TLO.Spell(self.CheckFor).ID() then
            self.CheckForID = mq.TLO.Spell(self.CheckFor).ID()
        end
    end
end

function Ability:setCommonSpellData(spellRef)
    self.SpellID = spellRef.ID()
    self.TargetType = spellRef.TargetType()
    self.Duration = spellRef.Duration()
    self.DurationTotalSeconds = spellRef.Duration.TotalSeconds()
    self.MyCastTime = spellRef.MyCastTime()
    self.RecastTime = spellRef.RecastTime()
    self.RecoveryTime = spellRef.RecoveryTime()
    self.AERange = spellRef.AERange()
    self.MyRange = spellRef.MyRange()
    self.SpellType = spellRef.SpellType()

    if self.SpellType == 'Detrimental' then
        if self.AERange > 0 then
            if self.MyRange == 0 then
                self.MyRange = self.AERange
            end
        end
    else
        if self.AERange > 0 then
            self.MyRange = self.AERange
        end
    end

    if spellRef.HasSPA(374)() then
        for i=1,5 do
            if spellRef.Attrib(i)() == 374 then
                -- mount blessing buff
                if not spellRef.Trigger(i).Name():find('Illusion') and not spellRef.Trigger(i).Name():find('Effect') and not spellRef.Trigger(i).Name():find('Form') then
                    self.CheckFor = spellRef.Trigger(i).Name()
                    self.RemoveBuff = spellRef()
                else
                    self.CheckFor = spellRef()
                    self.RemoveBuff = spellRef.Trigger(i).Name()
                end
            elseif spellRef.Attrib(i)() == 113 then
                -- summon mount SPA
            end
        end
    elseif spellRef.HasSPA(470)() then
        self.CheckFor = spellRef.Trigger(1)()
    elseif spellRef.HasSPA(340)() then
        for i=1,5 do
            if spellRef.Attrib(i)() == 340 then
                self.CheckFor = spellRef.Trigger(i).Name()
                self.Duration = spellRef.Trigger(i).Duration()
            end
        end
    else
        self.CheckFor = spellRef()
    end
    if spellRef.HasSPA(32)() then
        self.SummonID = spellRef.Base(1)()
        self.SummonMinimum = 1
    end
    if spellRef.HasSPA(33)() or spellRef.HasSPA(108)() then
        -- familiar
        self.RemoveFamiliar = true
    end
    if spellRef.ReagentID(1)() > 0 then
        self.ReagentID = spellRef.ReagentID(1)()
        self.ReagentCount = spellRef.ReagentCount(1)()
    end
    if not self.ReagentID and spellRef.NoExpendReagentID(1)() > 0 then
        self.ReagentID = spellRef.NoExpendReagentID(1)()
        self.ReagentCount = spellRef.ReagentCount(1)()
    end
end

return {
    init=Ability.init,
    Types=AbilityTypes,
    canUseSpell=Ability.canUseSpell,
    use=Ability.use,
    swapAndCast=Ability.swapAndCast,
    swapSpell=Ability.swapSpell,
    Spell=Spell,
    Disc=Disc,
    AA=AA,
    Item=Item,
    Skill=Skill,
}