---@type Mq
local mq = require('mq')
local logger = require('utils.logger')
local timer = require('utils.timer')
local state = require('state')

---@class Ability
---@field id number # the ID of this ability
---@field name string # the name of this ability
---@field type Ability.Type # spell, aa, disc, item, skill
---@field targettype? string # The target type for the ability
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
---@field checkfor? string # other name to check for presence of a buff, primarily when the buff name doesn't match the spell name
---@field skipifbuff? string # do not use this ability if the buff indicated by this string is already present
---@field summons? string # name of item summoned by this ability
---@field summonMinimum? number # minimum amount of summoned item to keep
---@field summonComponent? string # reagent required for summon ability to function
---@field precast? string # function to call prior to using an ability
---@field postcast? string # function to call after to using an ability
---@field usebelowpct? number # percent hp to begin using an ability, like executes
---@field maxdistance? number # distance within which an ability should be used, like don't leap from a mile away
---@field overwritedisc? string # name of disc which is acceptable to overwrite
---@field aggro? boolean # flag to indicate if the ability is for getting aggro, like taunt
---@field stand? boolean # flag to indicate if should stand after use, for FD dropping agro
---@field tot? boolean # flag to indicate if spell is target-of-target
---@field removesong? string # name of buff / song to remove after cast
local Ability = {
    id=0,
    name = '',
    type = 1,
    targettype = nil,
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

    quick = nil,
    long = nil,

    -- healing percents
    me = nil,
    pet = nil,
    self = nil,
    group = nil,
    pct = nil,
    regular = nil,
    panic = nil,

    classes = nil,
    checkfor = nil,
    skipifbuff = nil,

    -- name of summoned item like Ethereal Arrows
    summons = nil,
    summonMinimum = nil,
    summonComponent = nil,

    precast = nil,
    postcast = nil,

    usebelowpct = nil,
    maxdistance = nil,
    aggro = nil,

    stand = nil,

    tot = nil,
    removesong = nil,
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
---@param targettype string|nil #
---@param options table|nil #
---@return Ability #
function Ability:new(ID, name, type, targettype, options)
    local ability = {}
    setmetatable(ability, self)
    self.__index = self
    ability.id = ID
    ability.name = name
    ability.type = type
    ability.targettype = targettype
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

function Ability.canUseSpell(spell, abilityType, skipReagentCheck)
    if abilityType == Ability.Types.Spell and not mq.TLO.Me.SpellReady(spell.Name())() then
        if logger.log_flags.common.cast then
            logger.debug(logger.log_flags.common.cast, ('Spell not ready (id=%s, name=%s, type=%s)'):format(spell.ID(), spell.Name(), abilityType))
        end
        return false
    end
    if state.class ~= 'brd' and (mq.TLO.Me.Casting() or mq.TLO.Me.Moving()) then
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

---@class Spell : Ability
local Spell = {}

function Spell:isReady()
    return Ability.canUseSpell(mq.TLO.Spell(self.name), self.type)
end

---Initialize a new Spell instance
---@param ID number|nil #
---@param name string|nil #
---@param targettype string|nil #
---@param options table|nil #
---@return Ability #
function Spell:new(ID, name, targettype, options)
    local spell = Ability:new(ID, name, Ability.Types.Spell, targettype, options)
    setmetatable(spell, self)
    self.__index = self
    return spell
end

function Spell:use()
    local spell = mq.TLO.Spell(self.name)
    if (not state[self.name] or state[self.name]:timer_expired()) and Ability.canUseSpell(spell, self.type) then
        local result, requiresTarget =  Ability.shouldUseSpell(spell)
        if not result then return false end
        if state.class == 'brd' then mq.cmd('/stopsong') end
        if requiresTarget then
            printf(logger.logLine('Casting \ag%s\ax on \at%s\ax', self.name, mq.TLO.Target.CleanName()))
        else
            printf(logger.logLine('Casting \ag%s\ax', self.name))
        end
        mq.cmdf('/cast "%s"', self.name)
        state.resetCastingState()
        state.casting = self
        state.actionTaken = true
        state[self.name] = timer:new(2)
        state[self.name]:reset()
        return true
    end
end

---@class Disc : Ability
local Disc = {}

---Initialize a new Disc instance
---@param ID number|nil #
---@param name string|nil #
---@param options table|nil #
---@return Ability #
function Disc:new(ID, name, options)
    local disc = Ability:new(ID, name, Ability.Types.Disc, nil, options)
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
    if (not state[self.name] or state[self.name]:timer_expired()) and self:isReady() then
        if not self:isActive() or not mq.TLO.Me.ActiveDisc.ID() then
            printf(logger.logLine('Use Disc: \ag%s\ax', self.name))
            if self.name:find('Composite') then
                mq.cmdf('/disc %s', self.id)
            else
                mq.cmdf('/disc %s', self.name)
            end
            if spell.CastTime() > 0 then
                state.resetCastingState()
                state.casting = self
                state.actionTaken = true
            end
            state[self.name] = timer:new(2)
            state[self.name]:reset()
            return true
            --mq.delay(250+spell.CastTime())
            --mq.delay(250, function() return not mq.TLO.Me.CombatAbilityReady(self.name)() end)
            --logger.debug(logger.log_flags.common.cast, "Delayed for use_disc "..self.name)
            --return not mq.TLO.Me.CombatAbilityReady(self.name)()
        elseif overwrite == mq.TLO.Me.ActiveDisc.Name() then
            mq.cmd('/stopdisc')
            mq.delay(50)
            printf(logger.logLine('Use Disc: \ag%s\ax', self.name))
            mq.cmdf('/disc %s', self.name)
            state.resetCastingState()
            state.casting = self
            state.actionTaken = true
            state[self.name] = timer:new(2)
            state[self.name]:reset()
            return true
            --mq.delay(250+spell.CastTime())
            --mq.delay(250, function() return not mq.TLO.Me.CombatAbilityReady(self.name)() end)
            --logger.debug(logger.log_flags.common.cast, "Delayed for use_disc "..self.name)
            --return not mq.TLO.Me.CombatAbilityReady(self.name)()
        else
            logger.debug(logger.log_flags.common.cast, ('Not casting due to conflicting active disc (%s)'):format(self.name))
        end
    end
    return false
end

---@class AA : Ability
local AA = {}

---Initialize a new AA instance
---@param ID number|nil #
---@param name string|nil #
---@param targettype string|nil #
---@param options table|nil #
---@return Ability #
function AA:new(ID, name, targettype, options)
    local aa = Ability:new(ID, name, Ability.Types.AA, targettype, options)
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
    if (not state[self.name] or state[self.name]:timer_expired()) and self:isReady() then
        printf(logger.logLine('Use AA: \ag%s\ax', self.name))
        mq.cmdf('/alt activate %d', self.id)
        if mq.TLO.AltAbility(self.name).Spell.CastTime() > 0 then
            state.resetCastingState()
            state.casting = self
            state.actionTaken = true
        end
        state[self.name] = timer:new(2)
        state[self.name]:reset()
        return true
    end
    return false
end

---@class Item : Ability
local Item = {}

---Initialize a new Item instance
---@param ID number|nil #
---@param name string|nil #
---@param targettype string|nil #
---@param options table|nil #
---@return Ability #
function Item:new(ID, name, targettype, options)
    local item = Ability:new(ID, name, Ability.Types.Item, targettype, options)
    setmetatable(item, self)
    self.__index = self
    return item
end

function Item:isReady(item)
    if state.subscription ~= 'GOLD' and item.Prestige() then return false end
    local spell = item() and item.Clicky.Spell
    if spell and spell() and item.Timer() == '0' then
        return Ability.canUseSpell(spell, self.type) and Ability.shouldUseSpell(spell)
    else
        return false
    end
end

---Use the item specified by item.
---@return boolean @Returns true if the item was fired, otherwise false.
function Item:use()
    local theItem = mq.TLO.FindItem(self.id)
    if (not state[self.name] or state[self.name]:timer_expired()) and self:isReady(theItem) then
        local castTime = theItem.Clicky.Spell.CastTime()
        if state.class == 'brd' and mq.TLO.Me.Casting() then mq.cmd('/stopcast') mq.delay(1) end
        printf(logger.logLine('Use Item: \ag%s\ax', theItem))
        mq.cmdf('/useitem "%s"', theItem)
        if castTime > 0 then
            state.resetCastingState()
            state.casting = self
            state.actionTaken = true
        end
        state[self.name] = timer:new(2)
        state[self.name]:reset()
        return true
    end
    return false
end

---@class Skill : Ability
local Skill = {}

---Initialize a new Skill instance
---@param name string|nil #
---@param options table|nil #
---@return Ability #
function Skill:new(name, options)
    local skill = Ability:new(nil, name, Ability.Types.Skill, nil, options)
    setmetatable(skill, self)
    self.__index = self
    return skill
end

function Skill:isReady()
    return (not state[self.name] or state[self.name]:timer_expired()) and mq.TLO.Me.AbilityReady(self.name)() and mq.TLO.Me.Skill(self.name)() > 0
end

---Use the ability specified by name. These are basic abilities like taunt or kick.
function Skill:use()
    if self:isReady() then
        printf(logger.logLine('Use Ability: \ag%s\ax', self.name))
        mq.cmdf('/doability "%s"', self.name)
        --state.casting = self
        --state.actionTaken = true
        state[self.name] = timer:new(2)
        state[self.name]:reset()
        return true
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