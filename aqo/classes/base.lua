--- @type Mq
local mq = require 'mq'
local assist = require(AQO..'.routines.assist')
local camp = require(AQO..'.routines.camp')
local mez = require(AQO..'.routines.mez')
local pull = require(AQO..'.routines.pull')
local tank = require(AQO..'.routines.tank')
local logger = require(AQO..'.utils.logger')
local persistence = require(AQO..'.utils.persistence')
local timer = require(AQO..'.utils.timer')
local Abilities = require(AQO..'.ability')
local common = require(AQO..'.common')
local config = require(AQO..'.configuration')
local state = require(AQO..'.state')
local ui = require(AQO..'.ui')
local base = {}

base.ROUTINES = {heal=1,assist=1,mash=1,burn=1,cast=1,cure=1,buff=1,rest=1,ae=1,mez=1,aggro=1,ohshit=1,rez=1,recover=1,managepet=1}
base.OPTS = {}
-- collection of all spell id/name pairs that may be used for the class
base.spells = {}
-- collection of ordered spell rotations which may be loaded for the class and used in base.cast
base.spellRotations = {}
-- collection of Spell/AA/Disc/Ability/Item used in base.mash in any modes
-- Options: opt=string, delay=number
base.DPSAbilities = {}
-- collection of Spell/AA/Disc/Ability/Item used in base.mash in tank modes
-- Options: opt=string, delay=number
base.tankAbilities = {}
-- collection of Spell/AA/Disc/Ability/Item used in base.burn in any modes
-- Options: opt=string, delay=number
base.burnAbilities = {}
-- collection of Spell/AA/Disc/Ability/Item used in base.burn in tank modes
-- Options: opt=string, delay=number
base.tankBurnAbilities = {}
-- collection of Spell/AA/Disc/Ability/Item used in base.heal
-- Options: me=number, mt=number, other=number
base.healAbilities = {}
-- collection of Spell/AA/Disc/Ability/Item used in base.ae in any mode
-- Options: opt=string, delay=number, threshold=number
base.AEDPSAbilities = {}
-- collection of Spell/AA/Disc/Ability/Item used in base.ae in tank modes
-- Options: opt=string, delay=number, threshold=number
base.AETankAbilities = {}
-- collection of Spell/AA/Disc/Ability/Item used in base.aggro in non-tank modes
-- Options: opt=string, delay=number, threshold=number
base.defensiveAbilities = {}
-- collection of Spell/AA/Disc/Ability/Item used in base.recover
-- Options: mana=boolean, endurance=boolean, combat=boolean, ooc=boolean, threshold=number, minhp=number
base.recoverAbilities = {}
-- collection of Spell/AA/Disc/Ability/Item used in base.
-- Options: target=self|group|classlist
base.buffs = {}
base.petBuffs = {}
base.cures = {}

--base.slow
--base.aeslow
--base.snare
--base.debuff
--base.dispel
--base.nuketimer
--base.drop_aggro
--base.pet
--

-- Options added by key/value as well as by index/key so that settings can be displayed
-- in the skills tab in the order in which they are defined.
--- @param key string # The configuration key
--- @param label string # The text label that appears in the UI
--- @param value string|boolean|number # The default value for the setting
--- @param options table|nil # List of available options for combobox settings
--- @param tip string|nil # Hover  help message for the setting
--- @param type string # The UI element type (combobox, checkbox, inputint)
--- @param exclusive string|nil # The key of another option which is mutually exclusive with this option
base.addOption = function(key, label, value, options, tip, type, exclusive)
    base.OPTS[key] = {
        label=label,
        value=value,
        options=options,
        tip=tip,
        type=type,
        exclusive=exclusive,
    }
    table.insert(base.OPTS, key)
end

-- Return true only if the option is both defined and true
-- For cases where something should only be done by a class who has the option
-- Ex. USEMEZ logic should only ever be entered for classes who can mez.
base.isEnabled = function(key)
    return base.OPTS[key] and base.OPTS[key].value
end

-- Return true if the option is not defined or if it is defined and true
-- For cases where everyone should do something except some who can toggle it
-- Ex. USEMELEE setting doesn't exist on melees, so they always melee. But for others
--     the use of melee can be toggled.
base.isEnabledOrDNE = function(key)
    return not base.OPTS[key] or base.OPTS[key].value
end

-- Return true if the option is nil or the option is true
-- Ex. Kick has no option to toggle it, so should always be true. Intimidate has a toggle
-- so should evaluate the option.
base.isAbilityEnabled = function(key)
    return not key or base.OPTS[key].value
end

base.addSpell = function(spellGroup, spellList, options)
    local foundSpell = common.getBestSpell(spellList, options)
    base.spells[spellGroup] = foundSpell
    if foundSpell then
        logger.printf('[%s] Found spell: %s (%s)', spellGroup, foundSpell.name, foundSpell.id)
    else
        logger.printf('[%s] Could not find spell!', spellGroup)
    end
end

local SETTINGS_FILE = ('%s/aqobot_%s_%s.lua'):format(mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me.CleanName())
base.load_settings = function()
    local settings = config.load_settings(SETTINGS_FILE)
    if not settings or not settings[base.class] then return end
    for setting,value in pairs(settings[base.class]) do
        base.OPTS[setting].value = value
    end
end

base.save_settings = function()
    local optValues = {}
    for name,options in pairs(base.OPTS) do optValues[name] = options.value end
    persistence.store(SETTINGS_FILE, {common=config.get_all(), [base.class]=optValues})
end

-- attempt to avoid trying to slow mobs that are slow immune. currently this table is never cleaned up unless restarted
local SLOW_IMMUNES = {}
local function event_slowimmune(line)
    local target_name = mq.TLO.Target.CleanName()
    if target_name and not SLOW_IMMUNES[target_name] then
        SLOW_IMMUNES[target_name] = 1
    end
end

-- attempt to avoid trying to snare mobs that are snare immune. currently this table is never cleaned up unless restarted
local SNARE_IMMUNES = {}
local function event_snareimmune()
    local target_name = mq.TLO.Target.CleanName()
    if target_name and not SNARE_IMMUNES[target_name] then
        SNARE_IMMUNES[target_name] = 1
    end
end

base.setup_events = function()
    -- setup events based on whether certain options are defined, not whether they are enabled.
    if base.OPTS.USESLOW or base.OPTS.USESLOWAOE then
        mq.event('event_slowimmune', 'Your target is immune to changes in its attack speed#*#', event_slowimmune)
    end
    if base.OPTS.MEZST or base.OPTS.MEZAE then
        mez.setup_events()
    end
    if base.OPTS.USESNARE then
        mq.event('event_snareimmune', 'Your target is immune to changes in its run speed#*#', event_snareimmune)
        mq.event('event_snareimmune', 'Your target is immune to snare spells#*#', event_snareimmune)
    end
end

base.assist = function()
    if mq.TLO.Navigation.Active() then return end
    if config.MODE:is_assist_mode() then
        assist.check_target(base.reset_class_timers)
        logger.debug(logger.log_flags.class.assist, "after check target "..tostring(state.assist_mob_id))
        if base.isEnabledOrDNE('USEMELEE') then
            assist.attack()
        end
        assist.send_pet()
    end
end

base.tank = function()
    tank.find_mob_to_tank()
    tank.tank_mob()
    assist.send_pet()
end

local tankClasses = {WAR=true,PAL=true,SHD=true}
local function getHurt()
    if mq.TLO.Me.PctHPs() < 30 then return mq.TLO.Me.ID(), 'panic' end
    local tank = mq.TLO.Group.MainTank
    if tank() then
        local tankHP = tank.PctHPs() or 100
        if tankHP < 30 then return tank.ID(), 'panic' end
    end
    local groupSize = mq.TLO.Group.GroupSize()
    if groupSize then
        local numHurt = 0
        local mostHurtID = 0
        local mostHurtPct = 100
        for i=1,groupSize-1 do
            local member = mq.TLO.Group.Member(i)
            local memberHP = member.PctHPs() or 100
            if memberHP < 80 then
                if memberHP < mostHurtPct then
                    mostHurtID = member.ID()
                    mostHurtPct = memberHP
                end
                numHurt = numHurt + 1
                if tankClasses[member.Class.ShortName()] and memberHP < 30 then
                    return member.ID(), 'panic'
                end
            end
        end
        if numHurt > 2 then
            return 'group','regular'
        else
            return mostHurtID, 'regular'
        end
    elseif mq.TLO.Me.PctHPs() < 80 then  return 'self', 'regular' end
end

local function getHeal(healType)
    for _,heal in ipairs(base.healAbilities) do
        if heal[healType] and common.is_spell_ready(heal) then return heal end
    end
end

--[[
    1. Determine who to heal:
        a. self very hurt -- self,panic
        b. tank very hurt -- tank,panic
        c. multiple hurt -- group,regular
        d. self hurt -- self,regular
        e. tank hurt -- tank,regular
        f. other hurt -- other,regular
    2. Determine heal to use
        a. panic
        b. group
        c. regular
]]
base.heal = function()
    if common.am_i_dead() then return end
    for _,heal in ipairs(base.healAbilities) do
        local groupSize = mq.TLO.Group.GroupSize()
        if common.is_spell_ready(heal) then
            if mq.TLO.Me.PctHPs() < heal.me then
                mq.cmdf('/mqt myself')
                mq.delay(100, function() return mq.TLO.Target.ID() == mq.TLO.Me.ID() end)
                heal:use()
                return
            elseif (mq.TLO.Group.MainTank.PctHPs() or 100) < heal.mt then
                mq.cmdf('/mqt id %d', mq.TLO.Group.MainTank.ID())
                mq.delay(100, function() return mq.TLO.Target.ID() == mq.TLO.Group.MainTank.ID() end)
                heal:use()
                return
            elseif groupSize then
                for i=1,groupSize-1 do
                    local member = mq.TLO.Group.Member(i)
                    if (member.PctHPs() or 100) < heal.other then
                        member.DoTarget()
                        mq.delay(100, function() return mq.TLO.Target.ID() == member.ID() end)
                        heal:use()
                        return
                    end
                end
            end
        end
    end
end

base.cure = function()

end

local function doCombatLoop(list)
    local target = mq.TLO.Target
    local dist = target.Distance3D() or 0
    local maxdist = target.MaxRangeTo() or 0
    for _,ability in ipairs(list) do
        if (ability.name or ability.id) and (base.isAbilityEnabled(ability.opt)) and
                (ability.threshold == nil or ability.threshold >= state.mob_count_nopet) and
                (ability.type ~= 'ability' or dist < maxdist) then
            if ability:use() and ability.delay then mq.delay(ability.delay) end
        end
    end
end

base.mash = function()
    local cur_mode = config.MODE
    if (cur_mode:is_tank_mode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:is_assist_mode() and assist.should_assist()) or (cur_mode:is_manual_mode() and mq.TLO.Me.Combat()) then
        if base.mash_class then base.mash_class() end
        if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() then
            doCombatLoop(base.tankAbilities)
        end
        doCombatLoop(base.DPSAbilities)
    end
end

base.ae = function()
    local cur_mode = config.MODE
    if (cur_mode:is_tank_mode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:is_assist_mode() and assist.should_assist()) or (cur_mode:is_manual_mode() and mq.TLO.Me.Combat()) then
        if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() then
            if base.ae_class then base.ae_class() end
            doCombatLoop(base.AETankAbilities)
        end
        doCombatLoop(base.AEDPSAbilities)
    end
end

base.burn = function()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag.
    -- Test them both for each item, and see which one(s) actually work.
    if base.can_i_sing and not base.can_i_sing() then return end
    if common.is_burn_condition_met() then
        if base.burn_class then base.burn_class() end

        if config.MODE:is_tank_mode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() then
            doCombatLoop(base.tankBurnAbilities)
        end
        doCombatLoop(base.burnAbilities)
    end
end

base.find_next_spell = function()
    -- alliance
    -- synergy
    for _,spell in ipairs(base.spellRotations[base.OPTS.SPELLSET.value]) do
        if common.is_spell_ready(spell) and (base.isAbilityEnabled(spell.opt)) then return spell end
    end
end

local function castDebuffs()
    if base.isEnabled('USEDISPEL') and mq.TLO.Target.Beneficial() and base.dispel then
        base.dispel:use()
        if base.dispel.type == Abilities.Types.Spell then return true end
    end
    -- debuff too generic to be checking Tashed TLO...
    if base.isEnabled('USEDEBUFFAOE') and (base.class ~= 'enc' or not mq.TLO.Target.Tashed()) and (base.class ~= 'shm' or not mq.TLO.Target.Maloed()) and base.debuff then
        base.debuff:use()
        if base.dispel.type == Abilities.Types.Spell then return true end
    end
    if base.isEnabled('USESNARE') and not mq.TLO.Target.Snared() and not SNARE_IMMUNES[mq.TLO.Target.CleanName()] and (mq.TLO.Target.PctHPs() or 100) < 40 then
        base.snare:use()
        mq.doevents('event_snareimmune')
        if base.dispel.type == Abilities.Types.Spell then return true end
    end
    if base.isEnabled('USESLOW') or base.isEnabled('USESLOWAOE') then
        local target = mq.TLO.Target
        if target.Named() and not target.Slowed() and not SLOW_IMMUNES[target.CleanName()] then
            local abilityType
            if base.isEnabled('USESLOWAOE') and base.aeslow then
                base.aeslow:use()
                abilityType = base.aeslow.type
            elseif base.slow then
                base.slow:use()
                abilityType = base.slow.type
            end
            mq.doevents('event_slowimmune')
            if abilityType == Abilities.Types.Spell then return true end
        end
    end
end

base.nuketimer = timer:new(0)
base.cast = function()
    if mq.TLO.Me.SpellInCooldown() then return false end
    if assist.is_fighting() then
        if castDebuffs() then return true end
        if base.nuketimer:timer_expired() then
            local spell = base.find_next_spell()
            if spell then -- if a dot was found
                -- spell.precast
                --if spell.name == nec.spells.pyreshort.name and not mq.TLO.Me.Buff('Heretic\'s Twincast')() then
                --    tcclick:use()
                --end
                spell:use() -- then cast the dot
                base.nuketimer:reset()
            end
        end
        -- nec multi dot stuff
    end
end

local function buff_combat()
    -- common clicky buffs like geomantra and ... just geomantra
    common.check_combat_buffs()
    -- typically instant disc buffs like war field champion, etc. or summoning arrows
    for _,buff in ipairs(base.buffs) do
        if (buff.type == Abilities.Types.Disc or buff.type == Abilities.Types.AA) and buff.combat and not mq.TLO.Me.Buff(buff.name)() and not mq.TLO.Me.Song(buff.name)() then
            buff:use()
        elseif buff.summons then
            if mq.TLO.FindItemCount(buff.summons)() < 30 and not mq.TLO.Me.Moving() then
                buff:use()
                if mq.TLO.Cursor() then
                    mq.delay(50)
                    mq.cmd('/autoinv')
                end
            end
        end
    end
end

local function buff_ooc()
    -- call class specific buff routine for any special cases
    if base.buff_class then base.buff_class() end
    -- find an actual buff spell that takes time to cast
    for _,buff in ipairs(base.buffs) do
        if buff.type == Abilities.Types.Spell and buff.aura then
            local buffName = buff.name
            if state.subscription ~= 'GOLD' then buffName = buff.name:gsub(' Rk%..*', '') end
            if not mq.TLO.Me.Aura(buffName)() then
                local restore_gem = nil
                if not mq.TLO.Me.Gem(buff.name)() then
                    restore_gem = {name=mq.TLO.Me.Gem(state.swapGem)()}
                    common.swap_spell(buff, state.swapGem)
                end
                mq.delay(3000, function() return mq.TLO.Me.Gem(buff.name)() and mq.TLO.Me.GemTimer(buff.name)() == 0 end)
                buff:use()
                -- project lazarus super long cast time special bard aura stupidity
                if state.class == 'brd' then mq.delay(100) mq.delay(6000, function() return not mq.TLO.Window('CastingWindow').Open() end) end
                if restore_gem then
                    common.swap_spell(restore_gem, state.swapGem)
                end
                return true
            end
        elseif buff.type == Abilities.Types.Spell then
            local buffName = buff.name
            if state.subscription ~= 'GOLD' then buffName = buff.name:gsub(' Rk%..*', '') end
            if (not buff.opt or base.isEnabled(buff.opt)) and not mq.TLO.Me.Buff(buffName)() then
                local restore_gem = nil
                if not mq.TLO.Me.Gem(buff.name)() then
                    restore_gem = {name=mq.TLO.Me.Gem(state.swapGem)()}
                    common.swap_spell(buff, state.swapGem)
                end
                mq.delay(3000, function() return mq.TLO.Me.Gem(buff.name)() and mq.TLO.Me.GemTimer(buff.name)() == 0 end)
                buff:use()
                if restore_gem and restore_gem.name then
                    common.swap_spell(restore_gem, state.swapGem)
                end
                return true
            end
        elseif buff.type == Abilities.Types.Disc then
            if buff.aura and not mq.TLO.Me.Aura(buff.checkfor)() and not mq.TLO.Me.Aura(buff.name)() then
                if buff:use() then mq.delay(3000, function() return mq.TLO.Me.Casting() end) end
                return true
            elseif not buff.aura and not mq.TLO.Me.Buff(buff.name)() and not mq.TLO.Me.Song(buff.name)() then
                if buff:use() then mq.delay(3000, function() return mq.TLO.Me.Casting() end) end
                return true
            end
        elseif buff.type == Abilities.Types.AA then
            buff:use()
            if buff.removesong then mq.cmdf('/removebuff %s', buff.removesong) end
        elseif buff.type == Abilities.Types.Item then
            local item = mq.TLO.FindItem(buff.id)
            if not mq.TLO.Me.Buff(item.Spell.Name())() then
                buff:use()
            end
        end
    end

    common.check_item_buffs()
end

local function buff_pet()
    if base.isEnabled('BUFFPET') and mq.TLO.Pet.ID() > 0 then
        for _,buff in ipairs(base.petBuffs) do
            local tempName = buff.name
            if state.subscription ~= 'GOLD' then tempName = tempName:gsub(' Rk%..*', '') end
            if not mq.TLO.Pet.Buff(tempName)() and mq.TLO.Spell(buff.name).StacksPet() and mq.TLO.Spell(buff.name).Mana() < mq.TLO.Me.CurrentMana() then
                if common.swap_and_cast(buff, state.swapGem) then return true end
            end
        end
    end
end

base.buff = function()
    if common.am_i_dead() then return end
    if base.can_i_sing and not base.can_i_sing() then return end

    if buff_combat() then return true end

    if not common.clear_to_buff() then return end

    if buff_ooc() then return end

    buff_pet()
end

base.rest = function()
    common.rest()
end

base.mez = function()
    -- don't try to mez in manual mode
    if config.MODE:is_manual_mode() or config.MODE:is_tank_mode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() then return end
    if base.OPTS.MEZAE.value and base.spells.mezae then
        mez.do_ae(base.spells.mezae, base.OPTS.MEZAECOUNT.value)
    end
    if base.OPTS.MEZST.value and base.spells.mezst then
        mez.do_single(base.spells.mezst)
    end
end

local check_aggro_timer = timer:new(5)
base.aggro = function()
    if common.am_i_dead() or config.MODE:is_tank_mode() or mq.TLO.Group.MainTank() == mq.TLO.Me.CleanName() then return end
    if mq.TLO.Me.CombatState() == 'COMBAT' and mq.TLO.Me.PctHPs() < 50 then
        for _,ability in ipairs(base.defensiveAbilities) do
            ability:use()
        end
    end
    if base.drop_aggro and config.MODE:get_name() ~= 'manual' and base.OPTS.USEFADE.value and state.mob_count > 0 and check_aggro_timer:timer_expired() then
        if ((mq.TLO.Target() and mq.TLO.Me.PctAggro() >= 70) or mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID()) and mq.TLO.Me.PctHPs() < 50 then
            base.drop_aggro:use()
            check_aggro_timer:reset()
            mq.delay(1000)
            mq.cmd('/makemevis')
        end
    end
end

base.ohshit = function()
    if base.ohshitclass then base.ohshit_class() end
end

base.recover = function()
    -- modrods
    common.check_mana()
    local pct_mana = mq.TLO.Me.PctMana()
    local pct_end = mq.TLO.Me.PctEndurance()
    local combat_state = mq.TLO.Me.CombatState()
    local useAbility = nil
    for _,ability in ipairs(base.recoverAbilities) do
        if ability.mana and pct_mana < ability.threshold and (ability.combat or combat_state ~= 'COMBAT') and (not ability.minhp or mq.TLO.Me.PctHPs() > ability.minhp) and (ability.ooc or mq.TLO.Me.CombatState() ~= 'ACTIVE') then
            useAbility = ability
            break
        elseif ability.endurance and pct_end < ability.threshold and (ability.combat or combat_state ~= 'COMBAT') then
            useAbility = ability
            break
        end
    end
    if useAbility then
        useAbility:use()
    end
end

base.rez = function()

end

base.managepet = function()
    if not base.isEnabled('SUMMONPET') or not base.spells.pet then return end
    if not common.clear_to_buff() or mq.TLO.Pet.ID() > 0 or mq.TLO.Me.Moving() then return end
    if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.CAMPRADIUS))() > 0 then return end
    if (mq.TLO.Spell(base.spells.pet.name).Mana() or 0) > mq.TLO.Me.CurrentMana() then return end
    common.swap_and_cast(base.spells.pet, state.swapGem)
end

base.hold = function()

end

base.process_cmd = function(opt, new_value)
    if new_value then
        if opt == 'SPELLSET' and base.OPTS.SPELLSET ~= nil then
            if base.SPELLSETS[new_value] then
                logger.printf('Setting %s to: %s', opt, new_value)
                base.OPTS.SPELLSET.value = new_value
            end
        elseif opt == 'USEEPIC' and base.OPTS.USEEPIC ~= nil then
            if base.EPIC_OPTS[new_value] then
                logger.printf('Setting %s to: %s', opt, new_value)
                base.OPTS.USEEPIC.value = new_value
            end
        elseif opt == 'AURA1' and base.OPTS.AURA1 ~= nil then
            if base.AURAS[new_value] then
                logger.printf('Setting %s to: %s', opt, new_value)
                base.OPTS.AURA1.value = new_value
            end
        elseif opt == 'AURA2' and base.OPTS.AURA2 ~= nil then
            if base.AURAS[new_value] then
                logger.printf('Setting %s to: %s', opt, new_value)
                base.OPTS.AURA2.value = new_value
            end
        elseif type(base.OPTS[opt].value) == 'boolean' then
            if common.BOOL.FALSE[new_value] then
                logger.printf('Setting %s to: false', opt)
                if base.OPTS[opt].value ~= nil then base.OPTS[opt].value = false end
            elseif common.BOOL.TRUE[new_value] then
                logger.printf('Setting %s to: true', opt)
                if base.OPTS[opt].value ~= nil then base.OPTS[opt].value = true end
            end
        elseif type(base.OPTS[opt].value) == 'number' then
            if tonumber(new_value) then
                logger.printf('Setting %s to: %s', opt, tonumber(new_value))
                if base.OPTS[opt].value ~= nil then base.OPTS[opt].value = tonumber(new_value) end
            end
        else
            logger.printf('Unsupported command line option: %s %s', opt, new_value)
        end
    else
        if base.OPTS[opt] ~= nil then
            logger.printf('%s: %s', opt:lower(), base.OPTS[opt].value)
        else
            logger.printf('Unrecognized option: %s', opt)
        end
    end
end

base.main_loop = function()
    if not mq.TLO.Target() and not mq.TLO.Me.Combat() then
        state.tank_mob_id = 0
        state.assist_mob_id = 0
    end
    if not state.pull_in_progress then
        -- get mobs in camp
        camp.mob_radar()
        if config.MODE:is_tank_mode() then
            base.tank()
        end
        -- check whether we need to return to camp
        camp.check_camp()
        -- check whether we need to go chasing after the chase target
        common.check_chase()
        if base.check_spell_set then base.check_spell_set() end
        if not base.hold() then
            for _,routine in ipairs(base.classOrder) do
                base[routine]()
            end
        end
    end
    if config.MODE:is_pull_mode() and not base.hold() then
        pull.pull_mob(base.pull_func)
    end
end

base.draw_skills_tab = function()
    for _,key in ipairs(base.OPTS) do
        local option = base.OPTS[key]
        if option.type == 'checkbox' then
            option.value = ui.draw_check_box(option.label, '##'..key, option.value, option.tip)
            if option.value and option.exclusive then base.OPTS[option.exclusive].value = false end
        elseif option.type == 'combobox' then
            option.value = ui.draw_combo_box(option.label, option.value, option.options, true)
        elseif option.type == 'inputint' then
            option.value = ui.draw_input_int(option.label, '##'..key, option.value, option.tip)
        end
    end
end

return base