--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local config = require('interface.configuration')
local assist = require('routines.assist')
local camp = require('routines.camp')
local helpers = require('utils.helpers')
local logger = require('utils.logger')
local movement = require('utils.movement')
local timer = require('utils.timer')
local abilities = require('ability')
local common = require('common')
local mode = require('mode')
local state = require('state')

local Ranger = class:new()

--[[
    https://forums.eqfreelance.net/index.php?topic=16647.0
]]
function Ranger:init()
    self.classOrder = {'assist', 'aggro', 'debuff', 'cast', 'mash', 'burn', 'heal', 'recover', 'buff', 'rest', 'rez'}
    self.spellRotations = {standard={}}
    self:initBase('rng')

    mq.cmd('/squelch /stick mod 0')

    self:initClassOptions()
    self:loadSettings()
    self:initSpellLines()
    self:initSpellRotations()
    self:initBurns()
    self:initDPSAbilities()
    self:initBuffs()
    self:initDebuffs()
    self:initDefensiveAbilities()
    self:addCommonAbilities()
end

function Ranger:initClassOptions()
    self:addOption('USEUNITYAZIA', 'Use Unity (Azia)', true, nil, 'Use Azia Unity Buff', 'checkbox', 'USEUNITYBEZA', 'UseUnityAzia', 'bool')
    self:addOption('USEUNITYBEZA', 'Use Unity (Beza)', false, nil, 'Use Beza Unity Buff', 'checkbox', 'USEUNITYAZIA', 'UseUnityBeza', 'bool')
    self:addOption('USERANGE', 'Use Ranged', true, nil, 'Ranged DPS if possible', 'checkbox', nil, 'UseRange', 'bool')
    -- self:addOption('USEMELEE', 'Use Melee', true, nil, 'Melee DPS if ranged is disabled or not enough room', 'checkbox', nil, 'UseMelee', 'bool')
    self:addOption('USEDOTS', 'Use DoTs', false, nil, 'Cast expensive DoT on all mobs', 'checkbox', nil, 'UseDoTs', 'bool')
    self:addOption('USEPOISONARROW', 'Use Poison Arrow', true, nil, 'Use Poison Arrows AA', 'checkbox', 'USEFIREARROW', 'UsePoisonArrow', 'bool')
    self:addOption('USEFIREARROW', 'Use Fire Arrow', false, nil, 'Use Fire Arrows AA', 'checkbox', 'USEPOISONARROW', 'UseFireArrow', 'bool')
    self:addOption('BUFFGROUP', 'Buff Group', false, nil, 'Buff group members', 'checkbox', nil, 'BuffGroup', 'bool')
    self:addOption('DSTANK', 'DS Tank', false, nil, 'DS Tank', 'checkbox', nil, 'DSTank', 'bool')
    self:addOption('USENUKES', 'Use Nukes', false, nil, 'Cast nukes on all mobs', 'checkbox', nil, 'UseNukes', 'bool')
    self:addOption('USEARROWSPELLS', 'Use Arrow Spells', true, nil, 'Cast arrow spells', 'checkbox', nil, 'UseArrowSpells', 'bool')
    self:addOption('USEDISPEL', 'Use Dispel', true, nil, 'Dispel mobs with Entropy AA', 'checkbox', nil, 'UseDispel', 'bool')
    self:addOption('USEREGEN', 'Use Regen', false, nil, 'Buff regen on self', 'checkbox', nil, 'UseRegen', 'bool')
    self:addOption('USECOMPOSITE', 'Use Composite', true, nil, 'Cast composite as its available', 'checkbox', nil, 'UseComposite', 'bool')
    self:addOption('USESNARE', 'Use Snare', true, nil, 'Cast snare on mobs', 'checkbox', nil, 'UseSnare', 'bool')
    self:addOption('USEFADE', 'Use Fade', true, nil, 'Use Cover Tracks AA to reduce aggro', 'checkbox', nil, 'UseFade', 'bool')
end

Ranger.SpellLines = {
    {Group='shots', Spells={'Inevitable Shots', 'Claimed Shots'}, Options={opt='USEARROWSPELLS'}}, -- 4x archery attacks + dmg buff to archery attacks for 18s, Marked Shots
    {Group='focused', Spells={'Focused Frenzy of Arrows', 'Focused Whirlwind of Arrows', 'Focused Hail of Arrows', 'Focused Storm of Arrows'}, Options={opt='USEARROWSPELLS'}},--, 'Hail of Arrows'}) -- 4x archery attacks, Focused Blizzard of Arrows
    {Group='composite', Spells={'Composite Fusillade'}}, -- double bow shot and fire+ice nuke
    {Group='heart', Spells={'Heartbreak', 'Heartruin', 'Heartslit', 'Heartshot'}, Options={opt='USEARROWSPELLS'}}, -- consume class 3 wood silver tip arrow, strong vs animal/humanoid, magic bow shot, Heartruin
    {Group='opener', Spells={'Stealthy Shot'}, Options={opt='USEARROWSPELLS'}}, -- consume class 3 wood silver tip arrow, strong bow shot opener, OOC only
    -- summers == 2x nuke, fire and ice. flash boon == buff fire nuke, frost boon == buff ice nuke. laurion ash == normal fire nuke. gelid wind == normal ice nuke
    {Group='firenuke1', Spells={'Summer\'s Deluge', 'Summer\'s Torrent', 'Summer\'s Mist', 'Scorched Earth', 'Sylvan Burn', 'Icewind', 'Flaming Arrow'}}, -- fire + ice nuke, Summer's Sleet
    {Group='firenuke2', Spells={'Laurion Ash', 'Hearth Embers'}}, -- fire + ice nuke, Summer's Sleet
    {Group='coldnuke1', Spells={'Frostsquall Boon', 'Lunarflare boon', 'Ancient: North Wind'}}, -- 'Fernflash Boon', 
    {Group='coldnuke2', Spells={'Gelid Wind', 'Frost Wind'}}, -- 
    {Group='healtot', Spells={'Desperate Quenching', 'Desperate Geyser'}}, -- heal ToT, Desperate Meltwater, fast cast, long cd
    {Group='healtot2', Spells={'Elizerain Spring', 'Darkflow Spring'}}, -- heal ToT, Meltwater Spring, slow cast
    {Group='dot', Spells={'Hotaria Swarm', 'Bloodbeetle Swarm', 'Locust Swarm', 'Stinging Swarm', 'Flame Lick'}, Options={opt='USEDOTS'}}, -- main DoT
    {Group='dotds', Spells={'Swarm of Fernflies', 'Swarm of Bloodflies'}, Options={opt='USEDOTS'}}, -- DoT + reverse DS, Swarm of Hyperboreads
    {Group='dmgbuff', Spells={'Arbor Stalker\'s Enrichment'}}, -- inc base dmg of skill attacks, Arbor Stalker's Enrichment
    {Group='alliance', Spells={'Arbor Stalker\'s Coalition'}},
    {Group='buffs', Spells={'Shout of the Fernstalker', 'Shout of the Dusksage Stalker'}}, -- cloak of rimespurs, frostroar of the predator, strength of the arbor stalker, Shout of the Arbor Stalker
    -- Shout of the X Stalker Buffs
    {Group='cloak', Spells={'Cloak of Needlespikes', 'Cloak of Bloodbarbs'}}, -- Cloak of Rimespurs
    {Group='predator', Spells={'Shriek of the Predator', 'Bay of the Predator', 'Howl of the Predator', 'Spirit of the Predator'}}, -- Frostroar of the Predator
    {Group='strength', Spells={'Strength of the Fernstalker', 'Strength of the Dusksage Stalker', 'Strength of the Hunter', 'Strength of Tunare'}}, -- Strength of the Arbor Stalker
    -- Unity AA Buffs
    {Group='protection', Spells={'Protection of Pal\'Lomen', 'Protection of the Valley', 'Ward of the Hunter', 'Protection of the Wild'}}, -- Protection of the Wakening Land
    {Group='eyes', Spells={'Eyes of the Phoenix', 'Eyes of the Senshali', 'Eyes of the Hawk', 'Eyes of the Owl'}}, -- Eyes of the Visionary
    {Group='hunt', Spells={'Engulfed by the Hunt', 'Steeled by the Hunt'}}, -- Provoked by the Hunt
    {Group='coat', Spells={'Needlespike Coat', 'Moonthorn Coat'}}, -- Rimespur Coat
    -- Unity Azia only
    {Group='barrage', Spells={'Devastating Barrage'}}, -- Devastating Velium
    -- Unity Beza only
    {Group='blades', Spells={'Arcing Blades', 'Vociferous Blades', 'Call of Lightning', 'Sylvan Call'}}, -- Howling Blades
    {Group='ds', Spells={'Shield of Needlespikes', 'Shield of Shadethorns'}}, -- DS
    {Group='rune', Spells={'Shalowain\'s Crucible Cloak', 'Luclin\'s Darkfire Cloak'}}, -- self rune + debuff proc
    {Group='regen', Spells={'Dusksage Stalker\'s Vigor'}}, -- regen
    {Group='snare', Spells={'Ensnare', 'Snare'}, Options={opt='USESNARE'}},
    {Group='dispel', Spells={'Nature\'s Balance'}, Options={opt='USEDISPEL'}},
    -- Maelstrom of Blades, 4x 1h slash
    -- Jolting Emberquartz, add proc decrease hate
    -- Cloud of Guardian Fernflies, big ds
    -- Therapeutic Balm, cure/heal
    -- Devastating Spate, dd proc?
    {Group='heal', Spells={'Sylvan Water', 'Sylvan Light'}},
}

function Ranger:initSpellRotations()
    -- entries in the dd_spells table are pairs of {spell id, spell name} in priority order
    self.arrow_spells = {}
    table.insert(self.arrow_spells, self.spells.shots)
    table.insert(self.arrow_spells, self.spells.focused)
    table.insert(self.arrow_spells, self.spells.composite)
    table.insert(self.arrow_spells, self.spells.heart)
    self.dd_spells = {}
    table.insert(self.dd_spells, self.spells.firenuke1)
    table.insert(self.dd_spells, self.spells.coldnuke1)
    table.insert(self.dd_spells, self.spells.firenuke2)
    table.insert(self.dd_spells, self.spells.coldnuke2)

    -- entries in the dot_spells table are pairs of {spell id, spell name} in priority order
    self.dot_spells = {}
    table.insert(self.dot_spells, self.spells.dot)
    table.insert(self.dot_spells, self.spells.dotds)

    -- entries in the combat_heal_spells table are pairs of {spell id, spell name} in priority order
    self.combat_heal_spells = {}
    table.insert(self.combat_heal_spells, self.spells.healtot)
    --table.insert(combat_heal_spells, spells.healtot2) -- replacing in main spell lineup with self rune buff
end

function Ranger:initDPSAbilities()
    table.insert(self.DPSAbilities, common.getAA('Elemental Arrow')) -- inc dmg from fire+ice nukes, 1min CD

    table.insert(self.DPSAbilities, common.getBestDisc({'Focused Blizzard of Blades'})) -- 4x arrows, 12s CD, timer 6
    table.insert(self.DPSAbilities, common.getBestDisc({'Reflexive Rimespurs'})) -- 4x melee attacks + group HoT, 10min CD, timer 19
    -- table.insert(mashDiscs, common.getAA('Tempest of Blades')) -- frontal cone melee flurry, 12s CD
    -- Enraging Drop Kicks, increase hate?
    table.insert(self.DPSAbilities, common.getBestDisc({'Jolting Drop Kicks', 'Jolting Roundhouse Kicks', 'Jolting Snapkicks'})) -- agro reducer kick, timer 9, procs synergy, Jolting Roundhouse Kicks

    table.insert(self.DPSAbilities, common.getSkill('Kick'))
end

function Ranger:initBurns()
    -- entries in the AAs table are pairs of {aa name, aa id}
    if state.emu then
        table.insert(self.burnAbilities, common.getAA('Fundament: First Spire of the Pathfinders'))
    else
        table.insert(self.burnAbilities, common.getAA('Spire of the Pathfinders')) -- 7.5min CD
    end

    table.insert(self.burnAbilities, common.getAA('Auspice of the Hunter'))
    table.insert(self.burnAbilities, common.getAA('Pack Hunt')) -- swarm pets, 15min CD
    table.insert(self.burnAbilities, common.getAA('Empowered Blades')) -- melee dmg burn, 10min CD
    table.insert(self.burnAbilities, common.getAA('Guardian of the Forest')) -- base dmg, atk, overhaste, 6min CD
    table.insert(self.burnAbilities, common.getAA('Group Guardian of the Forest')) -- base dmg, atk, overhaste, 10min CD
    table.insert(self.burnAbilities, common.getAA('Outrider\'s Accuracy')) -- base dmg, accuracy, atk, crit dmg, 5min CD
    table.insert(self.burnAbilities, common.getAA('Imbued Ferocity')) -- 100% wep proc chance, 8min CD
    table.insert(self.burnAbilities, common.getAA('Silent Strikes')) -- silent casting
    table.insert(self.burnAbilities, common.getAA('Scarlet Cheetah\'s Fang')) -- does what?, 20min CD
    --table.insert(self.burnAbilities, common.getBestDisc({'Warder\'s Wrath'}))
    table.insert(self.burnAbilities, common.getAA('Poison Arrows', {nodmz=true}))--{opt='USEPOISONARROW', nodmz=true}))
    self.meleeBurnDiscs = {}
    table.insert(self.meleeBurnDiscs, common.getBestDisc({'Fernstalker\'s Discipline', 'Dusksage Stalker\'s Discipline'})) -- melee dmg buff, 19.5min CD, timer 2, Arbor Stalker's Discipline
    self.rangedBurnDiscs = {}
    table.insert(self.rangedBurnDiscs, common.getBestDisc({'Pureshot Discipline'})) -- bow dmg buff, 1hr7min CD, timer 2
end

function Ranger:initBuffs()
    table.insert(self.selfBuffs, common.getAA('Outrider\'s Evasion'))
    table.insert(self.selfBuffs, common.getAA('Bulwark of the Brownies')) -- 10m cd, 4min buff procs 100% parry below 50% HP
    table.insert(self.selfBuffs, common.getAA('Chameleon\'s Gift')) -- 5min cd, 3min buff procs hate reduction below 50% HP
    self.protection = common.getAA('Protection of the Spirit Wolf') -- 20min cd, large rune
    self.unity_azia = common.getAA('Wildstalker\'s Unity (Azia)')
    --Slot 1: 	Devastating Barrage
    --Slot 2: 	Steeled by the Hunt
    --Slot 3: 	Protection of the Valley
    --Slot 4: 	Eyes of the Senshali
    --Slot 5: 	Moonthorn Coat
    if state.emu then
        table.insert(self.selfBuffs, self.spells.eyes)
        --table.insert(self.selfBuffs, self.spells.protection)
        table.insert(self.selfBuffs, self.spells.blades)
        table.insert(self.selfBuffs, self.spells.predator)
        table.insert(self.selfBuffs, self.spells.strength)
        table.insert(self.combatBuffs, common.getBestDisc({'Trueshot Discipline'}))
        table.insert(self.healAbilities, self.spells.heal)
        table.insert(self.selfBuffs, self.spells.buffs)
    else
        table.insert(self.selfBuffs, common.getAA('Wildstalker\'s Unity (Azia)', {opt='USEUNITYAZIA', CheckFor='Devastating Barrage'}))
        table.insert(self.selfBuffs, common.getAA('Wildstalker\'s Unity (Beza)', {opt='USEUNITYBEZA', CheckFor='Vociferous Blades'}))
        table.insert(self.selfBuffs, self.spells.rune)
    end
    self.unity_beza = common.getAA('Wildstalker\'s Unity (Beza)')
    --Slot 1: 	Vociferous Blades
    --Slot 2: 	Steeled by the Hunt
    --Slot 3: 	Protection of the Valley
    --Slot 4: 	Eyes of the Senshali
    --Slot 5: 	Moonthorn Coat
    
    table.insert(self.selfBuffs, common.getAA('Poison Arrows', {opt='USEPOISONARROW', nodmz=true}))
    table.insert(self.selfBuffs, common.getAA('Flaming Arrows', {opt='USEFIREARROW', nodmz=true}))

    table.insert(self.selfBuffs, self.spells.dmgbuff)
    self.auspice = common.getAA('Auspice of the Hunter')

    self:addRequestAlias(self.spells.predator, 'SHOUT')
    self:addRequestAlias(self.spells.strength, 'STR')
    self:addRequestAlias(self.auspice, 'AUSPICE')
end

function Ranger:initDebuffs()
    table.insert(self.debuffs, common.getAA('Entropy of Nature', {opt='USEDISPEL'}) or self.spells.dispel)
    table.insert(self.debuffs, common.getAA('Entrap', {opt='USESNARE'}) or self.spells.snare)
end

function Ranger:initDefensiveAbilities()
    local postCT = function()
        mq.delay(1000)
        mq.cmd('/makemevis')
    end
    table.insert(self.fadeAbilities, common.getAA('Cover Tracks', {opt='USEFADE', postcast=postCT}))
    table.insert(self.defensiveAbilities, common.getAA('Outrider\'s Evasion')) -- 7min cd, 85% avoidance, 10% absorb
end

local rangedTimer = timer:new(5000)
function Ranger:resetClassTimers()
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
        local x_move = math.cos(math.rad(helpers.convertHeading(base_radian * i + my_heading)))
        local y_move = math.sin(math.rad(helpers.convertHeading(base_radian * i + my_heading)))
        local x_off = mob_x + radius * x_move
        local y_off = mob_y + radius * y_move
        local z_off = mob_z
        if mq.TLO.Navigation.PathLength(string.format('loc yxz %d %d %d', y_off, x_off, z_off))() < 150 then
            if mq.TLO.LineOfSight(string.format('%d,%d,%d:%d,%d,%d', y_off, x_off, z_off, mob_y, mob_x, mob_z))() then
                if mq.TLO.EverQuest.ValidLoc(string.format('%d %d %d', x_off, y_off, z_off))() then
                    local xtars = mq.TLO.SpawnCount(string.format('npc xtarhater loc %d %d %d radius 75', y_off, x_off, z_off))()
                    local allmobs = mq.TLO.SpawnCount(string.format('npc loc %d %d %d radius 75', y_off, x_off, z_off))()
                    if allmobs - xtars == 0 then
                        logger.info('Found a valid location at %d %d %d', y_off, x_off, z_off)
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
    if mq.TLO.Me.CombatState() == 'COMBAT' or not Ranger.spells.opener then return end
    if assist.shouldAssist() and state.assistMobID > 0 and Ranger.spells.opener.Name and mq.TLO.Me.SpellReady(Ranger.spells.opener.Name)() then
        Ranger.spells.opener:use()
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
        for _,spell in ipairs(Ranger.combat_heal_spells) do
            if spell:isReady() == abilities.IsReady.SHOULD_CAST then
                return spell
            end
        end
    end
    local isNamed = common.isNamedMob(mq.TLO.Zone.ShortName(), mq.TLO.Target.CleanName())
    for _,spell in ipairs(Ranger.dot_spells) do
        if spell.Name ~= Ranger.spells.dot.Name or Ranger:isEnabled('USEDOTS')
                or (state.burnActive and isNamed)
                or (config.get('BURNALWAYS') and isNamed) then
            if spell:isReady() == abilities.IsReady.SHOULD_CAST then
                return spell
            end
        end
    end
    if Ranger:isEnabled('USEARROWSPELLS') then
        for _,spell in ipairs(Ranger.arrow_spells) do
            if not Ranger.spells.composite or spell.Name ~= Ranger.spells.composite.Name or Ranger:isEnabled('USECOMPOSITE') then
                if spell:isReady() == abilities.IsReady.SHOULD_CAST then
                    return spell
                end
            end
        end
    end
    if Ranger:isEnabled('USENUKES') then
        for _,spell in ipairs(Ranger.dd_spells) do
            if spell:isReady() == abilities.IsReady.SHOULD_CAST then
                return spell
            end
        end
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

local snared_id = 0
function Ranger:cast()
    if not mq.TLO.Me.Invis() and mq.TLO.Me.CombatState() == 'COMBAT' then
        if assist.isFighting() then
            if self.spells.snare and mq.TLO.Target.ID() ~= snared_id and not mq.TLO.Target.Snared() and self.OPTS.USESNARE.value then
                self.spells.snare:use()
                snared_id = mq.TLO.Target.ID()
                return true
            end
            for _,clicky in ipairs(self.castClickies) do
                if clicky.enabled then
                    if (clicky.DurationTotalSeconds > 0 and mq.TLO.Target.Buff(clicky.CheckFor)()) or
                            (clicky.MyCastTime >= 0 and mq.TLO.Me.Moving()) then
                        movement.stop()
                        if clicky:use() then return end
                    end
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
function Ranger:burnClass()
    if mq.TLO.Me.Combat() then
        for _,disc in ipairs(self.meleeBurnDiscs) do
            disc:use()
        end
    elseif mq.TLO.Me.AutoFire() then
        for _,disc in ipairs(self.rangedBurnDiscs) do
            disc:use()
        end
    end
end

function Ranger:aggroClass()
    if (mq.TLO.Me.PctAggro() or 0) > 95 then
        -- Pause attacking if aggro is too high
        mq.cmd('/multiline ; /attack off ; /autofire off')
        mq.delay(5000, function() return mq.TLO.Me.PctAggro() <= 75 end)
        if self:isEnabled('USERANGE') then mq.cmd('/autofire on') else mq.cmd('/attack on') end
    end
    if mq.TLO.Me.PctHPs() < 50 and self:isEnabled('USERANGE') then
        -- If ranged, we might be in some bad position aggroing extra stuff, return to camp
        if mode.currentMode:isReturnToCampMode() then
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
function Ranger:checkSpellSet()
    if not common.clearToBuff() or mq.TLO.Me.Moving() or self:isEnabled('BYOS') then return end
    local spellSet = self.OPTS.SPELLSET.value
    if state.spellSetLoaded ~= spellSet or checkSpellTimer:timerExpired() then
        if spellSet == 'standard' then
            if abilities.swapSpell(self.spells.shots, 1) then return end
            if abilities.swapSpell(self.spells.focused, 2) then return end
            if abilities.swapSpell(self.spells.composite, 3, false, composite_names) then return end
            if abilities.swapSpell(self.spells.heart, 4) then return end
            if abilities.swapSpell(self.spells.opener, 5) then return end
            if abilities.swapSpell(self.spells.summer, 6) then return end
            if abilities.swapSpell(self.spells.healtot, 7) then return end
            if abilities.swapSpell(self.spells.rune, 8) then return end
            if abilities.swapSpell(self.spells.dot, 9) then return end
            if abilities.swapSpell(self.spells.dotds, 10) then return end
            if abilities.swapSpell(self.spells.dmgbuff, 12) then return end
            if abilities.swapSpell(self.spells.buffs, 13) then return end
            state.spellSetLoaded = spellSet
        end
        checkSpellTimer:reset()
    end
end

function Ranger:assist()
    if mq.TLO.Navigation.Active() then return end
    --[[if mode.currentMode:isAssistMode() then
        assist.fsm(self.resetClassTimers)
        useOpener()
        -- if we should be assisting but aren't in los, try to be?
        -- try to deal with ranger noobishness running out to ranged and dying
        if mq.TLO.Me.PctHPs() > 40 then
            if not self:isEnabled('USERANGE') or not attackRanged() then
                if self:isEnabled('USEMELEE') then assist.attack() end
            end
        end
        assist.sendPet()
    end]]
    if mode.currentMode:isAssistMode() then
        assist.doAssist(self.resetClassTimers, true)
        useOpener()
        -- if we should be assisting but aren't in los, try to be?
        -- try to deal with ranger noobishness running out to ranged and dying
        if mq.TLO.Me.PctHPs() > 40 then
            if not self:isEnabled('USERANGE') or not attackRanged() then
                if self:isEnabled('USEMELEE') then
                    assist.getCombatPosition()
                    assist.engage()
                end
            end
        end
        assist.sendPet()
    end
end

return Ranger
