--- @type Mq
local mq = require 'mq'
local assist = require('aqo.routines.assist')
local camp = require('aqo.routines.camp')
local mez = require('aqo.routines.mez')
local pull = require('aqo.routines.pull')
local tank = require('aqo.routines.tank')
local logger = require('aqo.utils.logger')
local persistence = require('aqo.utils.persistence')
local timer = require('aqo.utils.timer')
local common = require('aqo.common')
local config = require('aqo.configuration')
local state = require('aqo.state')
local ui = require('aqo.ui')
local baseclass = {}

baseclass.ROUTINES = {heal=1,assist=1,mash=1,burn=1,cast=1,buff=1,rest=1,ae=1,mez=1,aggro=1,ohshit=1,rez=1,recover=1,managepet=1}
baseclass.OPTS = {}
-- array of {id=#,name=string} covering all spells that may be used
baseclass.spells = {}
-- array of {id=#,name=string,type=AA|item|spell|disc}
baseclass.DPSAbilities = {}
-- array of {id=#,name=string,type=AA|item|spell|disc}
baseclass.tankAbilities = {}
-- array of {id=#,name=string,type=AA|item|spell|disc}
baseclass.burnAbilities = {}
-- array of {id=#,name=string,type=AA|item|spell|disc}
baseclass.tankBurnAbilities = {}
-- array of {id=#,name=string,type=AA|item|spell|disc}
baseclass.healAbilities = {}
-- array of {id=#,name=string,type=AA|item|spell|disc,threshold=#}
baseclass.AEDPSAbilities = {}
-- array of {id=#,name=string,type=AA|item|spell|disc,threshold=#}
baseclass.AETankAbilities = {}
-- array of {id=#,name=string,type=AA|item|spell|disc}
baseclass.defensiveAbilities = {}
-- array of {id=#,name=string,type=AA|item|spell|disc}
baseclass.recoverAbilities = {}
-- array of {id=#,name=string,type=AA|item|spell|disc,target=self|group|classlist}
baseclass.buffs = {}

-- Options added by key/value as well as by index/key so that settings can be displayed
-- in the skills tab in the order in which they are defined.
baseclass.addOption = function(key, label, value, options, tip, type)
    baseclass.OPTS[key] = {
        label=label,
        value=value,
        options=options,
        tip=tip,
        type=type,
    }
    table.insert(baseclass.OPTS, key)
end

baseclass.addSpell = function(spellGroup, spellList, options)
    local foundSpell = common.get_best_spell(spellList, options)
    baseclass.spells[spellGroup] = foundSpell
    if foundSpell.name then
        logger.printf('[%s] Found spell: %s (%s)', spellGroup, foundSpell.name, foundSpell.id)
    else
        logger.printf('[%s] Could not find spell!', spellGroup)
    end
end

local SETTINGS_FILE = ('%s/aqobot_%s_%s.lua'):format(mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me.CleanName())
baseclass.load_settings = function()
    local settings = config.load_settings(SETTINGS_FILE)
    if not settings or not settings[baseclass.class] then return end
    for setting,value in pairs(settings[baseclass.class]) do
        baseclass.OPTS[setting].value = value
    end
end

baseclass.save_settings = function()
    local optValues = {}
    for name,options in pairs(baseclass.OPTS) do optValues[name] = options.value end
    persistence.store(SETTINGS_FILE, {common=config.get_all(), [baseclass.class]=optValues})
end

baseclass.setup_events = function()
    -- no-op
end

baseclass.assist = function()
    local mob_x = mq.TLO.Target.X()
    local mob_y = mq.TLO.Target.Y()
    if mob_x and mob_y and common.check_distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), mob_x, mob_y) > config.CAMPRADIUS then return end
    if config.MODE:is_assist_mode() then
        assist.check_target(baseclass.reset_class_timers)
        -- if we should be assisting but aren't in los, try to be?
        assist.check_los()
        assist.attack()
        assist.send_pet()
    end
end

baseclass.tank = function()
    tank.find_mob_to_tank()
    tank.tank_mob()
    assist.send_pet()
end

baseclass.heal = function()

end

local function doCombatLoop(list)
    local target = mq.TLO.Target
    local dist = target.Distance3D()
    local maxdist = target.MaxRangeTo()
    for _,ability in ipairs(list) do
        if (ability.opt == nil or baseclass.OPTS[ability.opt]) and
            (ability.threshold == nil or ability.threshold >= state.mob_count_nopet) and
            (ability.type ~= 'ability' or dist < maxdist) then
                common.use[ability.type](ability)
                if ability.delay then mq.delay(ability.delay) end
        end
    end
end

baseclass.mash = function()
    local cur_mode = config.MODE
    if (cur_mode:is_tank_mode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:is_assist_mode() and assist.should_assist()) or (cur_mode:is_manual_mode() and mq.TLO.Me.Combat()) then
        if baseclass.mash_class then baseclass.mash_class() end
        if config.MODE:is_tank_mode() then
            doCombatLoop(baseclass.tankAbilities)
        end
        doCombatLoop(baseclass.DPSAbilities)
    end
end

baseclass.ae = function()
    local cur_mode = config.MODE
    if (cur_mode:is_tank_mode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:is_assist_mode() and assist.should_assist()) or (cur_mode:is_manual_mode() and mq.TLO.Me.Combat()) then
        if config.MODE:is_tank_mode() then
            if baseclass.ae_class then baseclass.ae_class() end
            doCombatLoop(baseclass.AETankAbilities)
        end
        doCombatLoop(baseclass.AEDPSAbilities)
    end
end

baseclass.burn = function()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag.
    -- Test them both for each item, and see which one(s) actually work.
    if baseclass.can_i_sing and not baseclass.can_i_sing() then return end
    if common.is_burn_condition_met() then
        if baseclass.burn_class then baseclass.burn_class() end

        if config.MODE:is_tank_mode() then
            doCombatLoop(baseclass.tankBurnAbilities)
        end
        doCombatLoop(baseclass.burnAbilities)
    end
end

baseclass.cast = function()

end

baseclass.buff = function()
    if common.am_i_dead() then return end
    if baseclass.can_i_sing and not baseclass.can_i_sing() then return end
    common.check_combat_buffs()
    for _,buff in ipairs(baseclass.buffs) do
        if buff.type == 'disc' or buff.type == 'aa' then
            common.use[buff.type](buff)
        elseif buff.type == 'summonitem' then
            if mq.TLO.FindItemCount(buff.summons)() < 30 and not mq.TLO.Me.Moving() then
                local item = mq.TLO.FindItem(buff)
                common.use_item(item)
                if item() then
                    mq.delay(50)
                    mq.cmd('/autoinv')
                end
            end
        end
    end
    if not common.clear_to_buff() then return end
    if baseclass.buff_class then baseclass.buff_class() end
    for _,buff in ipairs(baseclass.buffs) do
        if buff.type == 'spellaura' then
            local buffName = buff.name
            if state.subscription ~= 'GOLD' then buffName = buff.name:gsub(' Rk%..*', '') end
            if not mq.TLO.Me.Aura(buffName)() then
                local restore_gem = nil
                if not mq.TLO.Me.Gem(buff.name)() then
                    restore_gem = {name=mq.TLO.Me.Gem(1)()}
                    common.swap_spell(buff, 1)
                end
                mq.delay(3000, function() return mq.TLO.Me.Gem(buff.name)() and mq.TLO.Me.GemTimer(buff.name)() == 0 end)
                common.cast(buff.name)
                if restore_gem then
                    common.swap_spell(restore_gem, 1)
                end
            end
        elseif buff.type == 'discaura' then
            common.use_disc(buff)
            mq.delay(3000)
        elseif buff.type == 'item' then
            local item = mq.TLO.FindItem(buff.id)
            if not mq.TLO.Me.Buff(item.Spell.Name())() then
                common.use_item(item)
            end
        end
    end

    common.check_item_buffs()
end

baseclass.rest = function()
    common.rest()
end

baseclass.mez = function()
    -- don't try to mez in manual mode
    if config.MODE:is_manual_mode() or config.MODE:is_tank_mode() then return end
    if baseclass.OPTS.MEZAE.value and baseclass.spells.mezae.name then
        mez.do_ae(baseclass.spells.mezae.name)
    end
    if baseclass.OPTS.MEZST.value and baseclass.spells.mezst.name then
        mez.do_single(baseclass.spells.mezst.name)
    end
end

local check_aggro_timer = timer:new(5)
baseclass.aggro = function()
    if common.am_i_dead() or config.MODE:is_tank_mode() then return end
    if mq.TLO.Me.CombatState() == 'COMBAT' and mq.TLO.Me.PctHPs() < 50 then
        for _,ability in ipairs(baseclass.defensiveAbilities) do
            common.use(ability)
        end
    end
    if baseclass.drop_aggro and config.MODE:get_name() ~= 'manual' and baseclass.OPTS.USEFADE.value and state.mob_count > 0 and check_aggro_timer:timer_expired() then
        if ((mq.TLO.Target() and mq.TLO.Me.PctAggro() >= 70) or mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID()) and mq.TLO.Me.PctHPs() < 50 then
            common.use_aa(baseclass.drop_aggro)
            check_aggro_timer:reset()
            mq.delay(1000)
            mq.cmd('/makemevis')
        end
    end
end

baseclass.ohshit = function()
    if baseclass.ohshitclass then baseclass.ohshit_class() end
end

baseclass.recover = function()
    -- modrods
    common.check_mana()
    local pct_mana = mq.TLO.Me.PctMana()
    local pct_end = mq.TLO.Me.PctEndurance()
    local combat_state = mq.TLO.Me.CombatState()
    local useAbility = nil
    for _,ability in ipairs(baseclass.recoverAbilities) do
        if ability.mana and pct_mana < ability.threshold and (ability.combat or combat_state ~= 'COMBAT') then
            useAbility = ability
            break
        elseif ability.endurance and pct_end < ability.threshold and (ability.combat or combat_state ~= 'COMBAT') then
            useAbility = ability
            break
        end
    end
    if useAbility then
        common.use[useAbility.type](useAbility)
    end
end

baseclass.rez = function()

end

baseclass.managepet = function()

end

baseclass.hold = function()

end

baseclass.process_cmd = function(opt, new_value)
    if new_value then
        if opt == 'SPELLSET' and baseclass.OPTS.SPELLSET ~= nil then
            if baseclass.SPELLSETS[new_value] then
                logger.printf('Setting %s to: %s', opt, new_value)
                baseclass.OPTS.SPELLSET.value = new_value
            end
        elseif opt == 'USEEPIC' and baseclass.OPTS.USEEPIC ~= nil then
            if baseclass.EPIC_OPTS[new_value] then
                logger.printf('Setting %s to: %s', opt, new_value)
                baseclass.OPTS[opt].value = new_value
            end
        elseif type(baseclass.OPTS[opt].value) == 'boolean' then
            if common.BOOL.FALSE[new_value] then
                logger.printf('Setting %s to: false', opt)
                if baseclass.OPTS[opt].value ~= nil then baseclass.OPTS[opt].value = false end
            elseif common.BOOL.TRUE[new_value] then
                logger.printf('Setting %s to: true', opt)
                if baseclass.OPTS[opt].value ~= nil then baseclass.OPTS[opt].value = true end
            end
        elseif type(baseclass.OPTS[opt].value) == 'number' then
            if tonumber(new_value) then
                logger.printf('Setting %s to: %s', opt, tonumber(new_value))
                if baseclass.OPTS[opt].value ~= nil then baseclass.OPTS[opt].value = tonumber(new_value) end
            end
        else
            logger.printf('Unsupported command line option: %s %s', opt, new_value)
        end
    else
        if baseclass.OPTS[opt] ~= nil then
            logger.printf('%s: %s', opt:lower(), baseclass.OPTS[opt].value)
        else
            logger.printf('Unrecognized option: %s', opt)
        end
    end
end

baseclass.main_loop = function()
    if not mq.TLO.Target() and not mq.TLO.Me.Combat() then
        state.tank_mob_id = 0
    end
    if not state.pull_in_progress then
        -- get mobs in camp
        camp.mob_radar()
        if config.MODE:is_tank_mode() then
            baseclass.tank()
        end
        -- check whether we need to return to camp
        camp.check_camp()
        -- check whether we need to go chasing after the chase target
        common.check_chase()
        if baseclass.check_spell_set then baseclass.check_spell_set() end
        if not baseclass.hold() then
            for _,routine in ipairs(baseclass.classOrder) do
                baseclass[routine]()
            end
        end
    end
    if config.MODE:is_pull_mode() and not baseclass.hold() then
        pull.pull_mob(baseclass.pull_func)
    end
end

baseclass.draw_skills_tab = function()
    for _,key in ipairs(baseclass.OPTS) do
        local option = baseclass.OPTS[key]
        if option.type == 'checkbox' then
            option.value = ui.draw_check_box(option.label, '##'..key, option.value, option.tip)
        elseif option.type == 'combobox' then
            option.value = ui.draw_combo_box(option.label, option.value, option.options, true)
        elseif option.type == 'inputint' then
            option.value = ui.draw_input_int(option.label, '##'..key, option.value, option.tip)
        end
    end
end

return baseclass