-- Borrowed from e3next.. not really in use, just exploring some other flavors of casting code
local mq = require('mq')

local logger = require('utils.logger')
local abilities = require('ability')
local state = require('state')

local casting = {
    lastSuccessfulCast = nil
}

function casting.cast(spell, targetID, interruptCheck)
    if state.class == 'brd' and spell.MyCastTime <= 500 and spell.CastType == abilities.Types.Item then
        -- do nothing
    elseif state.class == 'brd' and spell.CastType == abilities.Types.Spell then
        -- sing(spell, target)
        return casting.CastReturn.CAST_SUCCESS
    else
        if mq.TLO.Me.Casting() then
            if state.paused then
                casting.interrupt()
                return casting.CastReturn.CAST_INTERRUPTED
            end
        end
    end
    local returnValue = casting.CastReturn.CAST_RESIST
    if mq.TLO.Cursor() then
        -- clear cursor
        while mq.TLO.Cursor() do
            mq.cmd('/autoinv')
            mq.delay(50)
        end
    end

    if not targetID or targetID == 0 then
        targetID = mq.TLO.Target.ID()
        if not targetID or targetID == 0 then
            if spell.TargetType == 'Single' and spell.SpellType == 'Detrimental' then
                return casting.CastReturn.CAST_UNKNOWN
            end
        end
        targetID = mq.TLO.Me.ID()
    end

    if not targetID or targetID == 0 then
        if not (spell.TargetType == 'Self' or spell.TargetType == 'Group v1' or spell.TargetType == 'Group v2' or spell.TargetType == 'PB AE') then
            logger.info('Invalid target for casting. %s', targetID)
            state.actionTaken = true
            return casting.CastReturn.CAST_NOTARGET
        end
    end

    local target = mq.TLO.Spawn('id '..targetID)
    if target() then
        local targetName = target.CleanName() or mq.TLO.Target.CleanName()
        if mq.TLO.Me.Invis() then
            state.actionTaken = true
            return casting.CastReturn.CAST_INVIS
        end

        if (spell.ReagentID or 0) > 0 then
            local itemCount = mq.TLO.FindItemCount(spell.ReagentID)()
            local requiredCount = spell.ReagentCount or 1
            if itemCount < requiredCount then
                spell.ReagentOutOfStock = true
                logger.info('Spell reagent out of stock %s %s', spell.SpellName, spell.ReagentID)
                return casting.CastReturn.CAST_REAGENT
            end
        end

        if state.currentZone ~= mq.TLO.Zone.ID() then
            logger.info('skip cast because zoning')
            return casting.CastReturn.CAST_ZONING
        end

        if mq.TLO.Me.Feigning() then
            logger.info('skipping cast because feigned')
            return casting.CastReturn.CAST_FEIGN
        end

        if mq.TLO.Window('SpellBookWnd').Open() then
            state.actionTaken = true
            logger.info('skip cast because spell book open')
            return casting.CastReturn.CAST_SPELLBOOKOPEN
        end

        if mq.TLO.Corpse.Open() then
            state.actionTaken = true
            logger.info('skip cast because corpse open')
            return casting.CastReturn.CAST_CORPSEOPEN
        end

        if not spell.SpellType:find('Beneficial') then
            if not (spell.CastType == abilities.Types.Disc and spell.TargetType == 'Self') then
                if not (spell.TargetType == 'PB AE' or spell.TargetType == 'Self') then
                    if not mq.TLO.Spawn('id '..targetID).LineOfSight() then
                        logger.info('SkipCast-LOS %s %s', spell.SpellName, targetName)
                        return casting.CastReturn.CAST_CANNOTSEE
                    end
                end
            end
        end

        if spell.TargetType ~= 'PB AE' and spell.TargetType ~= 'Self' then
            if casting.inCombat() and targetID ~= state.assistMobID and mq.TLO.Stick.Active() then
                mq.cmd('/stick pause')
            end
            casting.trueTarget(targetID)
        end

        if spell.BeforeEvent then
            mq.cmdf('/docommand %s', spell.BeforeEvent)
        end

        if spell.BeforeSpell then
            if not spell.BeforeSpellData then
                spell.BeforeSpellData = abilities:new(spell.BeforeSpell)
            end

            if casting.checkReady(spell.BeforeSpellData) and casting.checkMana(spell.BeforeSpellData) then
                casting.cast(spell.BeforeSpellData, targetID)
            end
        end

        if mq.TLO.Cursor() then
            while mq.TLO.Cursor() do
                mq.cmd('/autoinv')
                mq.delay(50)
            end
        end

        if spell.CastType == abilities.Types.Disc then
            if mq.TLO.Me.ActiveDisc.ID() and spell.TargetType == 'Self' then
                return casting.CastReturn.CAST_ACTIVEDISC
            else
                casting.trueTarget(targetID)
                state.actionTaken = true
                mq.cmdf('/disc %s', spell.CastName)
                mq.delay(300)
                returnValue = casting.CastReturn.CAST_SUCCESS
            end
        elseif spell.CastType == abilities.Types.Skill and mq.TLO.Me.AbilityReady(spell.CastName)() then
            -- handle alternate race skill names, slam, dragon punch, tail rake
            mq.cmdf('/doability "%s"', spell.CastName)
            mq.delay(300, function() return mq.TLO.Me.AltAbilityReady(spell.CastName)() end)
        else
            -- spell, aa, item
            if spell.MyCastTime > 500 then
                if mq.TLO.Navigation.Active() then
                    mq.cmd('/nav stop')
                    mq.delay(100, function() return not mq.TLO.Me.Moving() end)
                end
            end

            if spell.TargetType == 'Self' then
                if spell.CastType == abilities.Types.Spell then
                    mq.cmdf('/cast "%s"', spell.CastName)
                    if spell.MyCastTime > 500 then
                        mq.delay(1000)
                    end
                else
                    if spell.CastType == abilities.Types.AA then
                        mq.cmdf('/alt act %s', spell.CastID)
                        mq.delay(300)
                        if spell.MyCastTime > 500 then
                            mq.delay(700)
                        end
                    else
                        logger.info('casting item %s', spell.CastName)
                        mq.cmdf('/useitem "%s"', spell.CastName)
                        if spell.MyCastTime > 500 then
                            mq.delay(1000)
                        end
                    end
                end
            else
                if mq.TLO.Target.ID() ~= targetID then
                    mq.cmdf('/mqtarget id %s', targetID)
                end
                if spell.CastType == abilities.Types.Spell then
                    mq.cmdf('/cast "%s"', spell.CastName)
                    if spell.MyCastTime > 500 then
                        mq.delay(1000)
                    end
                else
                    if spell.CastType == abilities.Types.AA then
                        mq.cmdf('/alt act %s', spell.CastID)
                        mq.delay(300)
                        if spell.MyCastTime > 500 then
                            mq.delay(700)
                        end
                    else
                        mq.cmdf('/useitem "%s"', spell.CastName)
                        if spell.MyCastTime > 500 then
                            mq.delay(1000)
                        end
                    end
                end
            end
        end

        local currentMana = 0
        local pctMana = 0
        if interruptCheck then
            currentMana = mq.TLO.Me.CurrentMana()
            pctMana = mq.TLO.Me.PctMana()
        end
        while casting.isCasting() do
            if not spell.NoInterrupt then
                if interruptCheck and interruptCheck(currentMana, pctMana) then
                    casting.interrupt()
                    state.actionTaken = true
                    return casting.CastReturn.CAST_INTERRUPTFORHEAL
                end
            end
            if spell.SpellType == 'Detrimental' and spell.TargetType ~= 'PB AE' then
                local isCorpse = mq.TLO.Target.Type() == 'Corpse'
                if isCorpse then
                    casting.interrupt()
                    return casting.CastReturn.CAST_INTERRUPTED
                end
            end
            mq.delay(50)
            --if state.paused then
            --    casting.interrupt()
            --    return casting.CastReturn.CAST_INTERRUPTED
            --end
            if mq.TLO.Me.Invis() then
                return casting.CastReturn.CAST_INVIS
            end
        end

        mq.doevents()
        logger.info('done casting %s', spell.CastName)
        if spell.RemoveBuff then
            mq.cmdf('/removebuff "%s"', spell.RemoveBuff)
        end
        if spell.RemoveFamiliar and mq.TLO.Pet.Name():find('familiar') then
            mq.cmdf('/pet get lost')
        end
    end
end

function casting.Sing(spell, targetID)
    if state.class ~= 'brd' then return end

    if targetID and targetID > 0 then
        casting.trueTarget(targetID)
    end

    if spell.CastType == abilities.Types.Spell then
        mq.cmd('/stopsong')

        if spell.BeforeEvent then
            mq.cmdf('/docommand %s', spell.BeforeEvent)
        end

        mq.cmdf('/cast "%s"', spell.CastName)
        mq.delay(300, casting.isCasting)
        if not casting.isCasting() then
            mq.cmd('/stopcast')
            mq.delay(100)
            mq.cmdf('/cast "%s"', spell.CastName)
            if spell.MyCastTime > 500 then
                mq.delay(1000)
            end
        end

        if spell.AfterEvent then
            mq.cmdf('/docommand %s', spell.AfterEvent)
        end
    elseif spell.CastType == abilities.Types.Item then
        if spell.MyCastTime > 500 then
            mq.cmd('/stopsong')
            mq.delay(100)
        end

        if spell.BeforeEvent then
            mq.cmdf('/docommand %s', spell.BeforeEvent)
        end

        mq.cmdf('/useitem "%s"', spell.CastName)

        if spell.AfterEvent then
            mq.cmdf('/docommand %s', spell.AfterEvent)
        end
    elseif spell.CastType == abilities.Types.AA then
        if spell.MyCastTime > 500 then
            mq.cmd('/stopsong')
            mq.delay(100)
        end

        if spell.BeforeEvent then
            mq.cmdf('/docommand %s', spell.BeforeEvent)
        end

        mq.cmdf('/alt act %s', spell.CastID)

        if spell.AfterEvent then
            mq.cmdf('/docommand %s', spell.AfterEvent)
        end
    end
end

function casting.inCombat()
    return state.assistMobID or mq.TLO.Me.Combat() or mq.TLO.Me.CombatState() == 'COMBAT'
end

function casting.isSpellMemmed(spell)
    return mq.TLO.Me.Gem(spell.SpellName)() ~= nil
end

function casting.memorizeSpell(spell)
    if not (spell.CastType == abilities.Types.Spell and spell.SpellInBook) then
        return true
    end

    if mq.TLO.Me.Gem(spell.SpellName)() then
        return true
    end
    if spell.SpellGem == 0 then spell.SpellGem = state.swapGem end

    -- gem recast lock time ...

    mq.cmdf('/memorize "%s" %s', spell.SpellName, spell.SpellGem)
    mq.delay(2000)
    mq.delay(30000, function() return not mq.TLO.Window('SpellBookWnd').Open() end)
    mq.delay(3000, function() return mq.TLO.Me.SpellReady(spell.SpellName)() end)

    -- gem recast lock time ...

    return true
end

function casting.checkMana(spell)
    local currentMana = mq.TLO.Me.CurrentMana()
    local pctMana = mq.TLO.Me.PctMana()
    if currentMana >= spell.Mana then
        if spell.MaxMana > 0 then
            if pctMana > spell.MaxMana then
                return false
            end
        end
        if pctMana >= spell.MinMana then
            return true
        end
    end
    return false
end

function casting.interrupt()
    if not casting.isCasting() then return end
    if mq.TLO.Me.Mount.ID() then
        mq.cmd('/dismount')
    end
    mq.cmd('/stopcast')
end

function casting.isCasting()
    return mq.TLO.Window('CastingWindow').Open()
end

function casting.isNotCasting()
    return not casting.isCasting()
end

function casting.inGlobalCooldown()
    if not mq.TLO.Me.Class.CanCast() then return false end
    if mq.TLO.Me.SpellReady(mq.TLO.Me.Gem(1).Name())() or mq.TLO.Me.SpellReady(mq.TLO.Me.Gem(3).Name())() or mq.TLO.Me.SpellReady(mq.TLO.Me.Gem(5).Name())() or mq.TLO.Me.SpellReady(mq.TLO.Me.Gem(7).Name())() then
        return false
    end
    return true
end

function casting.checkReady(spell)
    if spell.CastType == abilities.Types.None then return false end

    if not casting.memorizeSpell(spell) then
        return false
    end

    --if state.class == 'brd' and not mq.TLO.Twist.Twisting() then
    --end

    if spell.CastType == abilities.Types.Spell and spell.SpellInBook then
        if spell.SpellName == 'Focused Hail of Arrows' or spell.SpellName == 'Hail of Arrows' then
            if mq.TLO.Me.Gem('Focused Hail of Arrows')() and mq.TLO.Me.Gem('Hail of Arrows')() then
                if not mq.TLO.Me.SpellReady('Focused Hail of Arrows')() then return false end
                if not mq.TLO.Me.SpellReady('Hail of Arrows')() then return false end
            end
        end
        if spell.SpellName == 'Mana Flare' or spell.SpellName == 'Mana Recursion' then
            if mq.TLO.Me.Gem('Mana Flare')() and mq.TLO.Me.Gem('Mana Recursion')() then
                if not mq.TLO.Me.SpellReady('Mana Flare')() then return false end
                if not mq.TLO.Me.SpellReady('Mana Recursion')() then return false end
            end
        end

        if mq.TLO.Me.SpellReady(spell.SpellName)() then
            logger.info('checkReady success %s', spell.SpellName)
            return true
        end

        if casting.inGlobalCooldown() then
            logger.info('spells in cooldown')
            return false
        end
    elseif spell.CastType == abilities.Types.Item then
        return mq.TLO.Me.ItemReady(spell.SpellName)()
    elseif spell.CastType == abilities.Types.AA then
        return mq.TLO.Me.AltAbilityReady(spell.SpellName)()
    elseif spell.CastType == abilities.Types.Disc then
        return mq.TLO.Me.CombatAbilityReady(spell.SpellName)()
    elseif spell.CastType == abilities.Types.Skill then
        return mq.TLO.Me.AbilityReady(spell.SpellName)()
    end
    return false
end

function casting.inRange(spell, targetID)
    local targetSpawn = mq.TLO.Spawn('id '..targetID)
    if targetSpawn() then
        local targetDistance = targetSpawn.Distance() or 300
        return targetDistance <= spell.MyRange
    end
    return false
end

function casting.trueTarget(targetID, allowClear)
    if allowClear and targetID == 0 then
        mq.cmd('/nomodkey /keypress esc')
        return true
    elseif targetID == 0 then
        return false
    end

    if mq.TLO.Target.ID() == targetID then return true end

    local targetSpawn = mq.TLO.Spawn('id '..targetID)
    if targetSpawn() then
        targetSpawn.DoTarget()
        if mq.TLO.Me.AutoFire() then mq.cmd('/autofire') end
        if mq.TLO.Target.ID() == targetID then return true end
        return false
    else
        if allowClear then
            mq.cmd('/nomodkey /keypress esc')
        end
        return false
    end
end

function casting.timeLeftOnMySpell(spell)
    local myBuff = mq.TLO.Target.MyBuff(spell.SpellName)
    if myBuff() then
        return myBuff.Duration()
    end
    return 0
end

function casting.timeLeftOnTargetBuff(spell)
    local remaining = mq.TLO.Target.Buff(spell.SpellName).Duration()
    if not remaining or remaining == 0 then
        local eqSpell = mq.TLO.Spell(spell.SpellName)
        if eqSpell() then
            local duration = eqSpell.Duration()
            if duration < 0 then
                remaining = -1
            end
        end
    end
    return remaining
end

function casting.timeLeftOnMyPetBuff(spell)
    local remaining = 0
    local buff = mq.TLO.Pet.Buff(spell.SpellName)
    if buff() then
        remaining = buff.Duration()
        if remaining == 0 then
            local duration = mq.TLO.Spell(spell.SpellName).Duration()
            if duration < 0 then remaining = -1 end
        end
    end
    return remaining
end

function casting.timeLeftOnMyBuff(spell)
    local remaining = 0
    local buff = mq.TLO.Me.Buff(spell.SpellName)
    if not buff() then
        buff = mq.TLO.Me.Song(spell.SpellName)
    end
    if buff() then
        remaining = buff.Duration()
        if remaining == 0 then
            local duration = mq.TLO.Spell(spell.SpellName).Duration()
            if duration < 0 then remaining = -1 end
        end
    end
    return remaining
end

function casting.registerEvents()
    -- Your gate is too unstable, and collapses.

    -- You cannot see your target.

    -- You need to play a.+ for this song.

    -- You are too distracted to cast a spell now.
    -- You can't cast spells while invulnerable.
    -- You *CANNOT* cast spells, you have been silenced.

    mq.event('TargetNoMana', 'Your target has no mana to affect.', casting.castImmune)
    mq.event('TargetUnaffected', 'Your target looks unaffected.', casting.castImmune)
    mq.event('TargetSlowImmune', 'Your target is immune to changes in its attack speed.', casting.castImmune)
    mq.event('TargetSnareImmune', 'Your target is immune to snare spells.', casting.castImmune)
    mq.event('TargetRunSpeedImmune', 'Your target is immune to changes in its run speed.', casting.castImmune)
    mq.event('TargetMezImmune', 'Your target cannot be mesmerized.', casting.castImmune)

    -- Your .+ is interrupted.
    -- Your spell is interrupted.
    -- Your casting has been interrupted.

    -- You must first select a target for this spell.
    -- This spell only works on.
    -- You must first target a group member.

    -- This spell does not work here.
    -- You can only cast this spell in the outdoors.
    -- You can not summon a mount here.
    -- You must have both the Horse Models and your current Luclin Character Model enabled to summon a mount.

    -- Your target resisted the .+ spell\.
    -- .+ resisted your .+\!
    -- .+ avoided your .+!

    -- You can't cast spells while stunned.

    --  spell did not take hold. \(Blocked by
    --  did not take hold on .+ \(Blocked by
    -- Your spell did not take hold\.
    -- Your spell would not have taken hold\.
    -- Your spell is too powerful for your intended target\.

    --mq.event('', '', casting.)
end

casting.CastReturn = {
    CAST_CANCELLED = 1,
    CAST_CANNOTSEE = 2,
    CAST_IMMUNE = 3,
    CAST_INTERRUPTED = 4,
    CAST_INVIS = 5,
    CAST_NOTARGET = 6,
    CAST_NOTMEMMED = 7,
    CAST_NOTREADY = 8,
    CAST_OUTOFMANA = 9,
    CAST_OUTOFRANGE = 10,
    CAST_RESIST = 11,
    CAST_SUCCESS = 12,
    CAST_UNKNOWN = 13,
    CAST_COLLAPSE = 14,
    CAST_TAKEHOLD = 15,
    CAST_FIZZLE = 16,
    CAST_INVISIBLE = 17,
    CAST_RECOVER = 18,
    CAST_STUNNED = 19,
    CAST_STANDIG = 20,
    CAST_DISTRACTED = 21,
    CAST_COMPONENTS = 22,
    CAST_REAGENT = 23,
    CAST_ZONING = 24,
    CAST_FEIGN = 25,
    CAST_SPELLBOOKOPEN = 26,
    CAST_ACTIVEDISC = 27,
    CAST_INTERRUPTFORHEAL = 28,
    CAST_CORPSEOPEN = 29,
    CAST_INVALID = 30,
    CAST_IFFAILURE = 31
}

return casting