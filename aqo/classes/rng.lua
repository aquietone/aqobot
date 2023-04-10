--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local assist = require('routines.assist')
local camp = require('routines.camp')
local movement = require('routines.movement')
local logger = require('utils.logger')
local timer = require('utils.timer')
local common = require('common')
local config = require('configuration')
local state = require('state')

function class.init(_aqo)
    class.classOrder = {'assist', 'aggro', 'debuff', 'cast', 'mash', 'burn', 'heal', 'recover', 'buff', 'rest', 'rez'}
    class.spellRotations = {standard={}}
    class.initBase(_aqo, 'rng')

    mq.cmd('/squelch /stick mod 0')

    class.initClassOptions()
    class.loadSettings()
    class.initSpellLines(_aqo)
    class.initSpellRotations(_aqo)
    class.initBurns(_aqo)
    class.initDPSAbilities(_aqo)
    class.initBuffs(_aqo)
    class.initDebuffs(_aqo)
    class.initDefensiveAbilities(_aqo)
end

function class.initClassOptions()
    class.addOption('USEUNITYAZIA', 'Use Unity (Azia)', true, nil, 'Use Azia Unity Buff', 'checkbox', 'USEUNITYBEZA')
    class.addOption('USEUNITYBEZA', 'Use Unity (Beza)', false, nil, 'Use Beza Unity Buff', 'checkbox', 'USEUNITYAZIA')
    class.addOption('USERANGE', 'Use Ranged', true, nil, 'Ranged DPS if possible', 'checkbox')
    class.addOption('USEMELEE', 'Use Melee', true, nil, 'Melee DPS if ranged is disabled or not enough room', 'checkbox')
    class.addOption('USEDOTS', 'Use DoTs', false, nil, 'Cast expensive DoT on all mobs', 'checkbox')
    class.addOption('USEPOISONARROW', 'Use Poison Arrow', true, nil, 'Use Poison Arrows AA', 'checkbox', 'USEFIREARROW')
    class.addOption('USEFIREARROW', 'Use Fire Arrow', false, nil, 'Use Fire Arrows AA', 'checkbox', 'USEPOISONARROW')
    class.addOption('BUFFGROUP', 'Buff Group', false, nil, 'Buff group members', 'checkbox')
    class.addOption('DSTANK', 'DS Tank', false, nil, 'DS Tank', 'checkbox')
    class.addOption('USENUKES', 'Use Nukes', false, nil, 'Cast nukes on all mobs', 'checkbox')
    class.addOption('USEDISPEL', 'Use Dispel', true, nil, 'Dispel mobs with Entropy AA', 'checkbox')
    class.addOption('USEREGEN', 'Use Regen', false, nil, 'Buff regen on self', 'checkbox')
    class.addOption('USECOMPOSITE', 'Use Composite', true, nil, 'Cast composite as its available', 'checkbox')
    class.addOption('USESNARE', 'Use Snare', true, nil, 'Cast snare on mobs', 'checkbox')
end

function class.initSpellLines(_aqo)
    class.addSpell('shots', {'Claimed Shots'}) -- 4x archery attacks + dmg buff to archery attacks for 18s, Marked Shots
    class.addSpell('focused', {'Focused Whirlwind of Arrows', 'Focused Hail of Arrows'})--, 'Hail of Arrows'}) -- 4x archery attacks, Focused Blizzard of Arrows
    class.addSpell('composite', {'Composite Fusillade'}) -- double bow shot and fire+ice nuke
    class.addSpell('heart', {'Heartruin', 'Heartslit', 'Heartshot'}) -- consume class 3 wood silver tip arrow, strong vs animal/humanoid, magic bow shot, Heartruin
    class.addSpell('opener', {'Stealthy Shot'}) -- consume class 3 wood silver tip arrow, strong bow shot opener, OOC only
    class.addSpell('firenuke1', {'Summer\'s Torrent', 'Scorched Earth', 'Sylvan Burn', 'Icewind'}) -- fire + ice nuke, Summer's Sleet
    class.addSpell('firenuke2', {'Hearth Embers'}) -- fire + ice nuke, Summer's Sleet
    class.addSpell('coldnuke1', {'Lunarflare boon', 'Ancient: North Wind'}) -- 
    class.addSpell('coldnuke2', {'Frost Wind'}) -- 
    class.addSpell('healtot', {'Desperate Geyser'}) -- heal ToT, Desperate Meltwater, fast cast, long cd
    class.addSpell('healtot2', {'Darkflow Spring'}) -- heal ToT, Meltwater Spring, slow cast
    class.addSpell('dot', {'Bloodbeetle Swarm', 'Locust Swarm', 'Flame Lick'}, {opt='USEDOTS'}) -- main DoT
    class.addSpell('dotds', {'Swarm of Bloodflies'}, {opt='USEDOTS'}) -- DoT + reverse DS, Swarm of Hyperboreads
    class.addSpell('dmgbuff', {'Arbor Stalker\'s Enrichment'}) -- inc base dmg of skill attacks, Arbor Stalker's Enrichment
    class.addSpell('alliance', {'Arbor Stalker\'s Coalition'})
    class.addSpell('buffs', {'Shout of the Dusksage Stalker'}) -- cloak of rimespurs, frostroar of the predator, strength of the arbor stalker, Shout of the Arbor Stalker
    -- Shout of the X Stalker Buffs
    class.addSpell('cloak', {'Cloak of Bloodbarbs'}) -- Cloak of Rimespurs
    class.addSpell('predator', {'Bay of the Predator', 'Howl of the Predator', 'Spirit of the Predator'}) -- Frostroar of the Predator
    class.addSpell('strength', {'Strength of the Dusksage Stalker', 'Strength of the Hunter', 'Strength of Tunare'}) -- Strength of the Arbor Stalker
    -- Unity AA Buffs
    class.addSpell('protection', {'Protection of the Valley', 'Ward of the Hunter', 'Protection of the Wild'}) -- Protection of the Wakening Land
    class.addSpell('eyes', {'Eyes of the Senshali', 'Eyes of the Hawk', 'Eyes of the Owl'}) -- Eyes of the Visionary
    class.addSpell('hunt', {'Steeled by the Hunt'}) -- Provoked by the Hunt
    class.addSpell('coat', {'Moonthorn Coat'}) -- Rimespur Coat
    -- Unity Azia only
    class.addSpell('barrage', {'Devastating Barrage'}) -- Devastating Velium
    -- Unity Beza only
    class.addSpell('blades', {'Vociferous Blades', 'Call of Lightning', 'Sylvan Call'}) -- Howling Blades
    class.addSpell('ds', {'Shield of Shadethorns'}) -- DS
    class.addSpell('rune', {'Luclin\'s Darkfire Cloak'}) -- self rune + debuff proc
    class.addSpell('regen', {'Dusksage Stalker\'s Vigor'}) -- regen
    class.addSpell('snare', {'Ensnare', 'Snare'}, {opt='USESNARE'})
    class.addSpell('dispel', {'Nature\'s Balance'}, {opt='USEDISPEL'})
end

function class.initSpellRotations(_aqo)
    -- entries in the dd_spells table are pairs of {spell id, spell name} in priority order
    class.arrow_spells = {}
    table.insert(class.arrow_spells, class.spells.shots)
    table.insert(class.arrow_spells, class.spells.focused)
    table.insert(class.arrow_spells, class.spells.composite)
    table.insert(class.arrow_spells, class.spells.heart)
    class.dd_spells = {}
    table.insert(class.dd_spells, class.spells.firenuke1)
    table.insert(class.dd_spells, class.spells.coldnuke1)
    table.insert(class.dd_spells, class.spells.firenuke2)
    table.insert(class.dd_spells, class.spells.coldnuke2)

    -- entries in the dot_spells table are pairs of {spell id, spell name} in priority order
    class.dot_spells = {}
    table.insert(class.dot_spells, class.spells.dot)
    table.insert(class.dot_spells, class.spells.dotds)

    -- entries in the combat_heal_spells table are pairs of {spell id, spell name} in priority order
    class.combat_heal_spells = {}
    table.insert(class.combat_heal_spells, class.spells.healtot)
    --table.insert(combat_heal_spells, spells.healtot2) -- replacing in main spell lineup with self rune buff
end

function class.initDPSAbilities(_aqo)
    table.insert(class.DPSAbilities, common.getAA('Elemental Arrow')) -- inc dmg from fire+ice nukes, 1min CD

    table.insert(class.DPSAbilities, common.getBestDisc({'Focused Blizzard of Blades'})) -- 4x arrows, 12s CD, timer 6
    table.insert(class.DPSAbilities, common.getBestDisc({'Reflexive Rimespurs'})) -- 4x melee attacks + group HoT, 10min CD, timer 19
    -- table.insert(mashDiscs, common.getAA('Tempest of Blades')) -- frontal cone melee flurry, 12s CD
    table.insert(class.DPSAbilities, common.getBestDisc({'Jolting Roundhouse Kicks', 'Jolting Snapkicks'})) -- agro reducer kick, timer 9, procs synergy, Jolting Roundhouse Kicks

    table.insert(class.DPSAbilities, common.getSkill('Kick'))
end

function class.initBurns(_aqo)
    -- entries in the AAs table are pairs of {aa name, aa id}
    if state.emu then
        table.insert(class.burnAbilities, common.getAA('Fundament: First Spire of the Pathfinders'))
    else
        table.insert(class.burnAbilities, common.getAA('Spire of the Pathfinders')) -- 7.5min CD
    end
    
    table.insert(class.burnAbilities, common.getAA('Pack Hunt')) -- swarm pets, 15min CD
    table.insert(class.burnAbilities, common.getAA('Empowered Blades')) -- melee dmg burn, 10min CD
    table.insert(class.burnAbilities, common.getAA('Guardian of the Forest')) -- base dmg, atk, overhaste, 6min CD
    table.insert(class.burnAbilities, common.getAA('Group Guardian of the Forest')) -- base dmg, atk, overhaste, 10min CD
    table.insert(class.burnAbilities, common.getAA('Outrider\'s Accuracy')) -- base dmg, accuracy, atk, crit dmg, 5min CD
    table.insert(class.burnAbilities, common.getAA('Imbued Ferocity')) -- 100% wep proc chance, 8min CD
    table.insert(class.burnAbilities, common.getAA('Silent Strikes')) -- silent casting
    table.insert(class.burnAbilities, common.getAA('Scarlet Cheetah\'s Fang')) -- does what?, 20min CD
    --table.insert(class.burnAbilities, common.getBestDisc({'Warder\'s Wrath'}))
    class.poison = common.getAA('Poison Arrows')
    table.insert(class.burnAbilities, common.getAA('Poison Arrows', {opt='USEPOISONARROW', nodmz=true}))
    class.meleeBurnDiscs = {}
    table.insert(class.meleeBurnDiscs, common.getBestDisc({'Dusksage Stalker\'s Discipline'})) -- melee dmg buff, 19.5min CD, timer 2, Arbor Stalker's Discipline
    class.rangedBurnDiscs = {}
    table.insert(class.rangedBurnDiscs, common.getBestDisc({'Pureshot Discipline'})) -- bow dmg buff, 1hr7min CD, timer 2
end

function class.initBuffs(_aqo)
    table.insert(class.selfBuffs, common.getAA('Outrider\'s Evasion'))
    table.insert(class.selfBuffs, common.getAA('Bulwark of the Brownies')) -- 10m cd, 4min buff procs 100% parry below 50% HP
    table.insert(class.selfBuffs, common.getAA('Chameleon\'s Gift')) -- 5min cd, 3min buff procs hate reduction below 50% HP
    class.protection = common.getAA('Protection of the Spirit Wolf') -- 20min cd, large rune
    class.unity_azia = common.getAA('Wildstalker\'s Unity (Azia)')
    --Slot 1: 	Devastating Barrage
    --Slot 2: 	Steeled by the Hunt
    --Slot 3: 	Protection of the Valley
    --Slot 4: 	Eyes of the Senshali
    --Slot 5: 	Moonthorn Coat
    if state.emu then
        class.addSpell('heal', {'Sylvan Water', 'Sylvan Light'})
        table.insert(class.selfBuffs, class.spells.eyes)
        --table.insert(class.selfBuffs, class.spells.protection)
        table.insert(class.selfBuffs, class.spells.blades)
        table.insert(class.selfBuffs, class.spells.predator)
        table.insert(class.selfBuffs, class.spells.strength)
        table.insert(class.combatBuffs, common.getBestDisc({'Trueshot Discipline'}))
        table.insert(class.healAbilities, class.spells.heal)
        table.insert(class.selfBuffs, class.spells.buffs)
    else
        table.insert(class.selfBuffs, common.getAA('Wildstalker\'s Unity (Azia)', {opt='USEUNITYAZIA', CheckFor='Devastating Barrage'}))
        table.insert(class.selfBuffs, common.getAA('Wildstalker\'s Unity (Beza)', {opt='USEUNITYBEZA', CheckFor='Vociferous Blades'}))
        table.insert(class.selfBuffs, class.spells.rune)
    end
    class.unity_beza = common.getAA('Wildstalker\'s Unity (Beza)')
    --Slot 1: 	Vociferous Blades
    --Slot 2: 	Steeled by the Hunt
    --Slot 3: 	Protection of the Valley
    --Slot 4: 	Eyes of the Senshali
    --Slot 5: 	Moonthorn Coat
    
    class.fire = common.getAA('Flaming Arrows')
    table.insert(class.selfBuffs, common.getAA('Flaming Arrows', {opt='USEFIREARROW', nodmz=true}))

    table.insert(class.selfBuffs, class.spells.dmgbuff)
    class.auspice = common.getAA('Auspice of the Hunter')

    class.addRequestAlias(class.spells.predator, 'predator')
    class.addRequestAlias(class.spells.strength, 'strength')
    class.addRequestAlias(class.auspice, 'auspice')
end

function class.initDebuffs(_aqo)
    table.insert(class.debuffs, common.getAA('Entropy of Nature', {opt='USEDISPEL'}) or class.spells.dispel)
    table.insert(class.debuffs, common.getAA('Entrap', {opt='USESNARE'}) or class.spells.snare)
end

function class.initDefensiveAbilities(_aqo)
    table.insert(class.fadeAbilities, common.getAA('Cover Tracks'))
    table.insert(class.defensiveAbilities, common.getAA('Outrider\'s Evasion')) -- 7min cd, 85% avoidance, 10% absorb
end

local rangedTimer = timer:new(5000)
function class.resetClassTimers()
    rangedTimer:reset(0)
end

local function getRangedCombatPosition(radius)
    if not rangedTimer:timerExpired() then return false end
    rangedTimer:reset()
    local assistMobID = state.assistMobID
    local mob_x = mq.TLO.Spawn('id '..assistMobID).X()
    local mob_y = mq.TLO.Spawn('id '..assistMobID).Y()
    local mob_z = mq.TLO.Spawn('id '..assistMobID).Z()
    local degrees = mq.TLO.Spawn('id '..assistMobID).Heading.Degrees()
    if not mob_x or not mob_y or not mob_z or not degrees then return false end
    local my_heading = degrees
    local base_radian = 10
    for i=1,36 do
        local x_move = math.cos(math.rad(common.convertHeading(base_radian * i + my_heading)))
        local y_move = math.sin(math.rad(common.convertHeading(base_radian * i + my_heading)))
        local x_off = mob_x + radius * x_move
        local y_off = mob_y + radius * y_move
        local z_off = mob_z
        if mq.TLO.Navigation.PathLength(string.format('loc yxz %d %d %d', y_off, x_off, z_off))() < 150 then
            if mq.TLO.LineOfSight(string.format('%d,%d,%d:%d,%d,%d', y_off, x_off, z_off, mob_y, mob_x, mob_z))() then
                if mq.TLO.EverQuest.ValidLoc(string.format('%d %d %d', x_off, y_off, z_off))() then
                    local xtars = mq.TLO.SpawnCount(string.format('npc xtarhater loc %d %d %d radius 75', y_off, x_off, z_off))()
                    local allmobs = mq.TLO.SpawnCount(string.format('npc loc %d %d %d radius 75', y_off, x_off, z_off))()
                    if allmobs - xtars == 0 then
                        print(logger.logLine('Found a valid location at %d %d %d', y_off, x_off, z_off))
                        movement.navToLoc(x_off, y_off, z_off, nil, 5000)
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- false invalid, true valid
---Determine whether the target is in front.
---@return boolean @Returns true if the spawn is in front, otherwise false.
local function checkMobAngle()
    local left = mq.TLO.Me.Heading.Degrees() - 45
    local right = mq.TLO.Me.Heading.Degrees() + 45
    local mob_heading = mq.TLO.Target.HeadingTo
    local direction_to_mob = nil
    if mob_heading then direction_to_mob = mob_heading.Degrees() end
    if not direction_to_mob then return false end
    -- switching from non-puller mode to puller mode, the camp may not be updated yet
    if left >= right then
        if direction_to_mob < left and direction_to_mob > right then return false end
    else
        if direction_to_mob < left or direction_to_mob > right then return false end
    end
    return true
end

local function attackRanged()
    if state.assistMobID == 0 or mq.TLO.Target.ID() ~= state.assistMobID or not assist.shouldAssist() then
        if mq.TLO.Me.AutoFire() then mq.cmd('/autofire off') end
        return
    end
    local dist3d = mq.TLO.Target.Distance3D()
    if mq.TLO.Navigation.Active() then mq.cmd('/squelch /nav stop') end
    if not state.emu then
        if not mq.TLO.Target.LineOfSight() or (dist3d and dist3d < 35) then
            if not getRangedCombatPosition(40) then
                return false
            end
        end
    else
        local maxRangeTo = mq.TLO.Target.MaxRangeTo() or 0
        --mq.cmdf('/squelch /stick hold moveback behind %s uw', math.min(maxRangeTo*.75, 25))
        mq.cmdf('/squelch /stick snaproll moveback behind %s uw', math.min(maxRangeTo*.75, 25))
    end
    --movement.stop()
    if mq.TLO.Target() then
        if not checkMobAngle() then
            mq.cmd('/squelch /face fast')
        end
        if not mq.TLO.Me.AutoFire() then
            mq.cmd('/autofire on')
        end
    end
    return true
end

local function useOpener()
    if mq.TLO.Me.CombatState() == 'COMBAT' or not class.spells.opener then return end
    if assist.shouldAssist() and state.assistMobID > 0 and class.spells.opener.Name and mq.TLO.Me.SpellReady(class.spells.opener.Name)() then
        class.spells.opener:use()
    end
end

--[[
    1. marked shot -- apply debuff
    2. focused shot -- strongest arrow spell
    3. dicho -- strong arrow spell
    4. wildfire spam
]]--
local function findNextSpell()
    local tothp = mq.TLO.Me.TargetOfTarget.PctHPs()
    if tothp and mq.TLO.Target() and mq.TLO.Target.Type() == 'NPC' and mq.TLO.Me.TargetOfTarget() and tothp < 65 then
        for _,spell in ipairs(class.combat_heal_spells) do
            if common.isSpellReady(spell) then
                return spell
            end
        end
    end
    for _,spell in ipairs(class.dot_spells) do
        if spell.Name ~= class.spells.dot.Name or class.isEnabled('USEDOTS')
                or (state.burnActive and common.isNamedMob(mq.TLO.Zone.ShortName(), mq.TLO.Target.CleanName()))
                or (config.get('BURNALWAYS') and common.isNamedMob(mq.TLO.Zone.ShortName(), mq.TLO.Target.CleanName())) then
            if common.isSpellReady(spell) then
                return spell
            end
        end
    end
    for _,spell in ipairs(class.arrow_spells) do
        if not class.spells.composite or spell.Name ~= class.spells.composite.Name or class.isEnabled('USECOMPOSITE') then
            if common.isSpellReady(spell) then
                return spell
            end
        end
    end
    if class.isEnabled('USENUKES') then
        for _,spell in ipairs(class.dd_spells) do
            if common.isSpellReady(spell) then
                return spell
            end
        end
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

local snared_id = 0
function class.cast()
    if not state.loop.Invis and mq.TLO.Me.CombatState() == 'COMBAT' then
        if assist.isFighting() then
            if mq.TLO.Target.ID() ~= snared_id and not mq.TLO.Target.Snared() and class.OPTS.USESNARE.value then
                class.spells.snare:use()
                snared_id = mq.TLO.Target.ID()
                return true
            end
            for _,clicky in ipairs(class.castClickies) do
                if (clicky.DurationTotalSeconds > 0 and mq.TLO.Target.Buff(clicky.CheckFor)()) or
                        (clicky.MyCastTime >= 0 and mq.TLO.Me.Moving()) then
                    movement.stop()
                    if clicky:use() then return end
                end
            end
            local spell = findNextSpell()
            if spell then
                spell:use()
                return true
            end
        end
    end
end

--[[
    1. pureshot
    2. reflexive
    3. spire
    4. auspice
    5. pack hunt
    6. guardian of the forest (self)
    7. guardian of the forest (group) (after self fades)
    8. outrider's attack
    9. outrider's accuracy
    10. imbued ferocity
    11. chest clicky
    12. scout's mastery of the elements
    13. silent strikes
    14. bulwark of the brownies
    15. scarlet cheetah fang
]]--
function class.burnClass()
    if mq.TLO.Me.Combat() then
        for _,disc in ipairs(class.meleeBurnDiscs) do
            disc:use()
        end
    elseif mq.TLO.Me.AutoFire() then
        for _,disc in ipairs(class.rangedBurnDiscs) do
            disc:use()
        end
    end
end

function class.aggroClass()
    if (mq.TLO.Me.PctAggro() or 0) > 95 then
        -- Pause attacking if aggro is too high
        mq.cmd('/multiline ; /attack off ; /autofire off')
        mq.delay(5000, function() return mq.TLO.Me.PctAggro() <= 75 end)
        if class.isEnabled('USERANGE') then mq.cmd('/autofire on') else mq.cmd('/attack on') end
    end
    if state.loop.PctHPs < 50 and class.isEnabled('USERANGE') then
        -- If ranged, we might be in some bad position aggroing extra stuff, return to camp
        if config.get('MODE'):isReturnToCampMode() then
            movement.navToLoc(camp.X, camp.Y, camp.Z)
        end
    end
end

local function missing_unity_buffs(name)
    local spell = mq.TLO.Spell(name)
    for i=1,spell.NumEffects() do
        local trigger_spell = spell.Trigger(i)
        if not mq.TLO.Me.Buff(trigger_spell.Name())() then return true end
    end
    return false
end

local function spawn_missing_cachedbuff(spawn, name)
    local spell = mq.TLO.Spell(name)
    -- skip 470 for now
    if spell.HasSPA(374)() then
        for i=1,spell.NumEffects() do
            local trigger_spell = spell.Trigger(i)
            if not spawn.CachedBuff(trigger_spell.Name())() and spell.StacksSpawn(spawn.ID())() then return true end
        end
    else
        if not spawn.CachedBuff(name)() and spell.StacksSpawn(spawn.ID())() then return true end
    end
    return false
end

local function target_missing_buff(name)
    local spell = mq.TLO.Spell(name)
    if spell.HasSPA(374)() then
        for i=1,spell.NumEffects() do
            local trigger_spell = spell.Trigger(i)
            if not mq.TLO.Target.Buff(trigger_spell.Name())() and spell.StacksTarget() then return true end
        end
    else
        if not mq.TLO.Target.Buff(name)() and spell.StacksTarget() then return true end
    end
    return false
end

local composite_names = {['Composite Fusillade']=true, ['Dissident Fusillade']=true, ['Dichotomic Fusillade']=true}
local checkSpellTimer = timer:new(30000)
function class.checkSpellSet()
    if not common.clearToBuff() or mq.TLO.Me.Moving() or class.isEnabled('BYOS') then return end
    local spellSet = class.OPTS.SPELLSET.value
    if state.spellSetLoaded ~= spellSet or checkSpellTimer:timerExpired() then
        if spellSet == 'standard' then
            common.swapSpell(class.spells.shots, 1)
            common.swapSpell(class.spells.focused, 2)
            common.swapSpell(class.spells.composite, 3, composite_names)
            common.swapSpell(class.spells.heart, 4)
            common.swapSpell(class.spells.opener, 5)
            common.swapSpell(class.spells.summer, 6)
            common.swapSpell(class.spells.healtot, 7)
            common.swapSpell(class.spells.rune, 8)
            common.swapSpell(class.spells.dot, 9)
            common.swapSpell(class.spells.dotds, 10)
            common.swapSpell(class.spells.dmgbuff, 12)
            common.swapSpell(class.spells.buffs, 13)
            state.spellSetLoaded = spellSet
        end
        checkSpellTimer:reset()
    end
end

function class.assist()
    if mq.TLO.Navigation.Active() then return end
    if config.get('MODE'):isAssistMode() then
        assist.checkTarget(class.resetClassTimers)
        useOpener()
        -- if we should be assisting but aren't in los, try to be?
        -- try to deal with ranger noobishness running out to ranged and dying
        if state.loop.PctHPs > 40 then
            if not class.isEnabled('USERANGE') or not attackRanged() then
                if class.isEnabled('USEMELEE') then assist.attack() end
            end
        end
        assist.sendPet()
    end
end

return class