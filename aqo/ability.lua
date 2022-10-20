---@type Mq
local mq = require('mq')
local logger = require(AQO..'.utils.logger')
local state = require(AQO..'.state')

---@class Ability
---@field id number|nil #
---@field name string #
---@field type Ability.Type #
---@field opt string|nil #
---@field delay number|nil #
---@field threshold number|nil #
---@field combat boolean|nil #
---@field ooc boolean|nil #
---@field minhp number|nil #
---@field mana boolean|nil #
---@field endurance boolean|nil #
---@field me number|nil #
---@field mt number|nil #
---@field other number|nil #
local Ability = {
    id=0,
    name = '',
    type = 1,
    opt = nil,

    delay = nil,

    -- AE number or start recovery percent
    threshold = nil,

    -- recovery conditions
    combat = nil,
    ooc = nil,
    minhp = nil,
    mana = nil,
    endurance = nil,

    -- healing percents
    me = nil,
    mt = nil,
    other = nil,

    -- name of summoned item like Ethereal Arrows
    summons = nil,
}

---@enum Ability.Types
Ability.Types = {
    Spell = 1,
    Disc = 2,
    AA = 3,
    Item = 4,
    Skill = 5,
}

---Initialize a new ability istance.
---@param ID number|nil #
---@param name string|nil #
---@param type Ability.Type #
---@param options table|nil #
---@return Ability #
function Ability:new(ID, name, type, options)
    local ability = {}
    setmetatable(ability, self)
    self.__index = self
    ability.id = ID
    ability.name = name
    ability.type = type
    if options then
        for key,value in pairs(options) do
            ability[key] = value
        end
    end
    return ability
end

-- what was skipSelfStack
function Ability.shouldUseSpell(spell, skipSelfStack)
    local result = false
    local requireTarget = false
    local dist = mq.TLO.Target.Distance3D()
    if spell.Beneficial() then
        if spell.TargetType() == 'Group v1' and not spell.Stacks() then return false end
        -- duration is number of ticks, so it tostring'd
        if spell.Duration() ~= '0' then
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
        if spell.Duration() ~= '0' then
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
    logger.debug(logger.log_flags.common.cast, 'Should use spell: \ag%s\ax=%s', spell.Name(), result)
    return result, requireTarget
end

---Determine whether currently in control of the character, i.e. not CC'd, stunned, mezzed, etc.
---@return boolean @Returns true if not under any loss of control effects, false otherwise.
local function in_control()
    return not (mq.TLO.Me.Dead() or mq.TLO.Me.Ducking() or mq.TLO.Me.Charmed() or
            mq.TLO.Me.Stunned() or mq.TLO.Me.Silenced() or mq.TLO.Me.Feigning() or
            mq.TLO.Me.Mezzed() or mq.TLO.Me.Invulnerable() or mq.TLO.Me.Hovering())
end

function Ability.canUseSpell(spell, abilityType, skipReagentCheck)
    if abilityType == Ability.Types.Spell and not mq.TLO.Me.SpellReady(spell.Name())() then
        if logger.log_flags.common.cast then
            logger.debug(logger.log_flags.common.cast, ('Spell not ready (id=%s, name=%s, type=%s)'):format(spell.ID(), spell.Name(), abilityType))
        end
        return false
    end
    if not in_control() or (state.class ~= 'brd' and (mq.TLO.Me.Casting() or mq.TLO.Me.Moving())) then
        if logger.log_flags.common.cast then
            logger.debug(logger.log_flags.common.cast, ('Not in control or moving (id=%s, name=%s, type=%s)'):format(spell.ID(), spell.Name(), abilityType))
        end
        return false
    end
    if abilityType ~= Ability.Types.Item and (spell.Mana() > mq.TLO.Me.CurrentMana() or spell.EnduranceCost() > mq.TLO.Me.CurrentEndurance()) then
        if logger.log_flags.common.cast then
            logger.debug(logger.log_flags.common.cast, ('Not enough mana or endurance (id=%s, name=%s, type=%s)'):format(spell.ID(), spell.Name(), abilityType))
        end
        return false
    end
    -- emu hack for bard for the time being, songs requiring an instrument are triggering reagent logic?
    if state.class ~= 'brd' and not skipReagentCheck then
        for i=1,3 do
            local reagentid = spell.ReagentID(i)()
            if reagentid ~= -1 then
                local reagent_count = spell.ReagentCount(i)()
                if mq.TLO.FindItemCount(reagentid)() < reagent_count then
                    if logger.log_flags.common.cast then
                        logger.debug(logger.log_flags.common.cast, 'Missing Reagent for (id=%d, name=%s, type=%s, reagentid=%s)', spell.ID(), spell.Name(), abilityType, reagentid)
                    end
                    return false
                end
            else
                break
            end
        end
    end
    logger.debug(logger.log_flags.common.cast, ('Can use spell: \ag%s\ax=%s'):format(spell.Name(), 'true'))
    return true
end

local Spell = {}

---Initialize a new spell instance
---@param options table|nil #
function Spell:new(ID, name, options)
    local spell = Ability:new(ID, name, Ability.Types.Spell, options)
    setmetatable(spell, self)
    self.__index = self
    return spell
end

function Spell:use()
    local spell = mq.TLO.Spell(self.name)
    if Ability.canUseSpell(spell, self.type) then
        local result, requiresTarget =  Ability.shouldUseSpell(spell)
        if not result then return false end
        if state.class == 'brd' then mq.cmd('/stopsong') end
        if requiresTarget then
            logger.printf('Casting \ag%s\ax on \at%s\ax', self.name, mq.TLO.Target.CleanName())
        else
            logger.printf('Casting \ag%s\ax', self.name)
        end
        mq.cmdf('/cast "%s"', self.name)
        if state.class ~= 'brd' then
            mq.delay(20)
            if not mq.TLO.Me.Casting() then mq.cmdf('/cast "%s"', self.name) end
            mq.delay(20)
            if not mq.TLO.Me.Casting() then mq.cmdf('/cast "%s"', self.name) end
            mq.delay(20)
            while mq.TLO.Me.Casting() do
                if requiresTarget and not mq.TLO.Target() then
                    mq.cmd('/stopcast')
                    break
                end
                mq.delay(10)
            end
        else
            mq.delay(1000)
        end
        return not mq.TLO.Me.SpellReady(self.name)()
    end
end

local Disc = {}

---Initialize a new spell instance
---@param options table|nil #
function Disc:new(ID, name, options)
    local disc = Ability:new(ID, name, Ability.Types.Disc, options)
    setmetatable(disc, self)
    self.__index = self
    return disc
end

---Determine whether the disc specified by name is an "active" disc that appears in ${Me.ActiveDisc}.
---@return boolean @Returns true if the disc is an active disc, otherwise false.
function Disc:isActive()
    local spell = mq.TLO.Spell(self.name)
    return spell.IsSkill() and (tonumber(spell.Duration()) or 0) > 0 and spell.TargetType() == 'Self' and not spell.StacksWithDiscs()
end

---Determine whether an disc is ready, including checking whether the character is currently capable.
---@return boolean @Returns true if the disc is ready to be used, otherwise false.
function Disc:isReady()
    if mq.TLO.Me.CombatAbility(self.name)() and mq.TLO.Me.CombatAbilityTimer(self.name)() == '0' and mq.TLO.Me.CombatAbilityReady(self.name)() then
        local spell = mq.TLO.Spell(self.name)
        return Ability.canUseSpell(spell, self.type) and Ability.shouldUseSpell(spell)--true
    else
        return false
    end
end

---Use the disc specified in the passed in table disc.
---@param overwrite string|nil @The name of a disc which should be stopped in order to run this disc.
function Disc:use(overwrite)
    local spell = mq.TLO.Spell(self.name)
    if self:isReady() then
        if not self:isActive() or not mq.TLO.Me.ActiveDisc.ID() then
            logger.printf('Use Disc: \ag%s\ax', self.name)
            if self.name:find('Composite') then
                mq.cmdf('/disc %s', self.id)
            else
                mq.cmdf('/disc %s', self.name)
            end
            mq.delay(250+spell.CastTime())
            mq.delay(250, function() return not mq.TLO.Me.CombatAbilityReady(self.name)() end)
            logger.debug(logger.log_flags.common.cast, "Delayed for use_disc "..self.name)
            return not mq.TLO.Me.CombatAbilityReady(self.name)()
        elseif overwrite == mq.TLO.Me.ActiveDisc.Name() then
            mq.cmd('/stopdisc')
            mq.delay(50)
            logger.printf('Use Disc: \ag%s\ax', self.name)
            mq.cmdf('/disc %s', self.name)
            mq.delay(250+spell.CastTime())
            mq.delay(250, function() return not mq.TLO.Me.CombatAbilityReady(self.name)() end)
            logger.debug(logger.log_flags.common.cast, "Delayed for use_disc "..self.name)
            return not mq.TLO.Me.CombatAbilityReady(self.name)()
        else
            logger.debug(logger.log_flags.common.cast, ('Not casting due to conflicting active disc (%s)'):format(self.name))
        end
    end
    return false
end

local AA = {}

---Initialize a new spell instance
---@param options table|nil #
function AA:new(ID, name, options)
    local aa = Ability:new(ID, name, Ability.Types.AA, options)
    setmetatable(aa, self)
    self.__index = self
    return aa
end

---Determine whether an AA is ready, including checking whether the character is currently capable.
---@return boolean @Returns true if the AA is ready to be used, otherwise false.
function AA:isReady()
    if mq.TLO.Me.AltAbilityReady(self.name)() then
        local spell = mq.TLO.AltAbility(self.name).Spell
        return Ability.canUseSpell(spell, self.type) and Ability.shouldUseSpell(spell)
    else
        return false
    end
end

---Use the AA specified in the passed in table aa.
---@return boolean @Returns true if the ability was fired, otherwise false.
function AA:use()
    if self:isReady() then
        logger.printf('Use AA: \ag%s\ax', self.name)
        mq.cmdf('/alt activate %d', self.id)
        mq.delay(250+mq.TLO.Me.AltAbility(self.name).Spell.CastTime()) -- wait for cast time + some buffer so we don't skip over stuff
        mq.delay(250, function() return not mq.TLO.Me.AltAbilityReady(self.name)() end)
        logger.debug(logger.log_flags.common.cast, "Delayed for use_aa "..self.name)
        return not mq.TLO.Me.AltAbilityReady(self.name)()
    end
    return false
end

local Item = {}

---Initialize a new spell instance
function Item:new(ID, name, options)
    local item = Ability:new(ID, name, Ability.Types.Item, options)
    setmetatable(item, self)
    self.__index = self
    return item
end

function Item:isReady(item)
    if state.subscription ~= 'GOLD' and item.Prestige() then return false end
    local spell = item.Clicky.Spell
    if spell() and item.Timer() == '0' then
        return Ability.canUseSpell(spell, self.type) and Ability.shouldUseSpell(spell)
    else
        return false
    end
end

---Use the item specified by item.
---@return boolean @Returns true if the item was fired, otherwise false.
function Item:use()
    local theItem = mq.TLO.FindItem(self.id)
    if self:isReady(theItem) then
        logger.printf('Use Item: \ag%s\ax', theItem)
        mq.cmdf('/useitem "%s"', theItem)
        mq.delay(500+theItem.CastTime()) -- wait for cast time + some buffer so we don't skip over stuff
        return true
    end
    return false
end

local Skill = {}

---Initialize a new spell instance
---@param name string|nil #
---@param options table|nil #
function Skill:new(name, options)
    local skill = Ability:new(nil, name, Ability.Types.Skill, options)
    setmetatable(skill, self)
    self.__index = self
    return skill
end

function Skill:isReady()
    return mq.TLO.Me.AbilityReady(self.name)() and mq.TLO.Me.Skill(self.name)() > 0
end

---Use the ability specified by name. These are basic abilities like taunt or kick.
function Skill:use()
    if self:isReady() then
        mq.cmdf('/doability "%s"', self.name)
        mq.delay(500, function() return not mq.TLO.Me.AbilityReady(self.name)() end)
        logger.debug(logger.log_flags.common.cast, "Delayed for use_ability "..self.name)
    end
end

return {
    Types=Ability.Types,
    canUseSpell=Ability.canUseSpell,
    Spell=Spell,
    Disc=Disc,
    AA=AA,
    Item=Item,
    Skill=Skill,
}