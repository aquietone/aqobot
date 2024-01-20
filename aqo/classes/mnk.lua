--- @type Mq
local mq = require('mq')
local class = require('classes.classbase')
local conditions = require('routines.conditions')
local common = require('common')

local Monk = class:new()

--[[
    http://forums.eqfreelance.net/index.php?topic=17466.0

    -- Kick abilities
    table.insert(self.combatBuffs, common.getAA('Zan Fi\'s Whistle')) -- always up combat buff
    table.insert(self.DPSAbilities, common.getBestDisc({'Fatewalker\'s Synergy', 'Bloodwalker\'s Synergy', 'Icewalker\'s Synergy', 'Firewalker\'s Synergy', 'Doomwalker\'s Synergy'})) -- strong kick + inc kick dmg
    table.insert(self.DPSAbilities, common.getBestDisc({'Flurry of Fists', 'Buffeting of Fists', 'Barrage of Fists', 'Firestorm of Fists', 'Torrent of Fists'})) -- 3x tiger claw + monk synergy proc
    table.insert(self.DPSAbilities, common.getBestDisc({'Curse of Sixteen Shadows', 'Curse of Fifteen Strikes', 'Curse of Fourteen Fists', 'Curse of the Thirteen Fingers'})) -- inc dmg from DS
    table.insert(self.DPSAbilities, common.getBestDisc({'Uncia\'s Fang', 'Zlexak\'s Fang', 'Hoshkar\'s Fang', 'Zalikor\'s Fang'})) -- a nuke?
    table.insert(self.DPSAbilities, common.getAA('Stunning Kick')) -- free flying kick + a stun
    table.insert(self.DPSAbilities, common.getSkill('Flying Kick'))
    table.insert(self.DPSAbilities, common.getSkill('Tiger Claw'))
    table.insert(self.DPSAbilities, common.getBestDisc({'Bloodwalker\'s Precision Strike', 'Icewalker\'s Precision Strike', 'Firewalker\'s Precision Strike', 'Doomwalker\'s Precision Strike'})) -- shuriken attack + buffs shuriken dmg
    
    table.insert(self.DPSAbilities, common.getBestDisc({'Bloodwalker\'s Conjunction', 'Icewalker\'s Coalition', 'Firewalker\'s Covenant', 'Doomwalker\'s Alliance'}))
    --common.getAA('Five Point Palm') -- has +500 hate, fd after using

    table.insert(self.fadeAbilities, common.getAA('Imitate Death'))

    common.getBestDisc({'Convalesce', 'Night\'s Calming', 'Relax', 'Hiatus', 'Breather'})

    table.insert(self.auras, common.getBestDisc({'Master\'s Aura'}))

    -- Burns
    -- Instant activations for start of burn
    -- bp click -- add dmg to next x kicks
    table.insert(self.burnAbilities, common.getAA('Two-Finger Wasp Touch', {first=true})) -- double dmg taken from special punches, doesn't stack across monks
    --Zan Fi's Whistle -- big melee dmg bonus, combat buff
    table.insert(self.burnAbilities, common.getBestDisc({'Disciplined Reflexes', 'Decisive Reflexes', 'Rapid Reflexes', 'Nimble Reflexes'}, {first=true})) -- defensive
    table.insert(self.burnAbilities, common.getBestDisc({'Ironfist'}, {first=true})) -- inc melee dmg
    table.insert(self.burnAbilities, common.getAA('Spire of the Sensei', {first=true}))  -- inc chance for wep procs
    table.insert(self.burnAbilities, common.getBestDisc({'Tiger\'s Symmetry', 'Dragon\'s Poise', 'Eagle\'s Poise', 'Tiger\'s Poise', 'Dragon\'s Balance'}, {first=true})) -- adds extra attacks
    table.insert(self.burnAbilities, common.getBestDisc({'Ecliptic Form', 'Composite Form', 'Dissident Form', 'Dichotomic Form'}, {first=true})) -- large bonus dmg
    table.insert(self.burnAbilities, common.getAA('Infusion of Thunder', {first=true})) -- chance to inc melee dmg + nuke

    -- Burn spam
    table.insert(self.burnAbilities, common.getBestDisc({'Crane Stance'}, {first=true})) -- 2 big kicks
    table.insert(self.burnAbilities, common.getAA('Five Point Palm', {first=true})) -- big dragon punch with nuke
    -- click off ironfist?
    -- click bp here?
    table.insert(self.burnAbilities, common.getBestDisc({'Heel of Zagali'}, {first=true}))
    -- spam kick abilities

    -- 2nd Burn
    table.insert(self.burnAbilities, common.getBestDisc({'Speed Focus'}, {second=true})) -- doubles attack speed
    table.insert(self.burnAbilities, common.getAA('Focused Destructive Force', {second=true})) -- doubles number of primary hand attacks

    -- 3rd Burn
    table.insert(self.burnAbilities, common.getAA('Two-Finger Wasp Touch', {third=true})) -- if another monks has faded
    table.insert(self.burnAbilities, common.getBestDisc({'Terrorpalm'}, {third=true})) -- inc dmg from melee, inc min dmg

    -- 4th Burn
    --table.insert(self.burnAbilities, common.getBestDisc({'Ironfist'})) -- if not used yet
    table.insert(self.burnAbilities, common.getBestDisc({'Eye of the Storm'}, {third=true})) -- inc dmg, inc min dmg

    -- 5th Burn
    table.insert(self.burnAbilities, common.getBestDisc({'Earthforce'})) -- defensive, adds heroic str

]]
--[[
common.getAA('Distant Strike') -- pull ability
common.getAA('Magnanimous Force') -- knockback + memblur
common.getAA('Moving Mountains') -- fling mob to you
common.getAA('Purify Body') -- self remove detrimental affects, 4min cd
common.getAA('Swift Tails\' Chant') -- restore 6000 end to group, 10 min cd, timer 8
common.getAA('Ton Po\'s Stance') -- extra crits + attacks, 5 min cd, timer 9
common.getAA('Devastating Assault') -- 2 minutes of aoe melee, 5 min cd, timer 30
common.getAA('Dragon Force') -- knockback
common.getAA('Focused Destructive Force') -- 42 seconds of extra melee attacks on target, 15 min cd, timer 2
common.getAA('Grappling Strike') -- pulls target towards you
common.getAA('Neshika\'s Blink') -- leap
common.getAA('Vehement Rage') -- inc base dmg and minimum dmg, 5 min cd, timer 61
]]
function Monk:init()
    self.classOrder = {'assist', 'aggro', 'heal', 'mash', 'burn', 'recover', 'buff', 'rest', 'rez'}
    self:initBase('MNK')

    self:initClassOptions()
    self:loadSettings()
    self:initDPSAbilities()
    self:initBurns()
    self:initBuffs()
    self:initDefensiveAbilities()
    self:initHeals()
    self:addCommonAbilities()

    self.useCommonListProcessor = true
end

function Monk:initClassOptions()
    self:addOption('USEFADE', 'Use Feign Death', true, nil, 'Toggle use of Feign Death in combat', 'checkbox', nil, 'UseFade', 'bool')
end

function Monk:initDPSAbilities()
    table.insert(self.DPSAbilities, common.getSkill('Flying Kick', {condition=conditions.withinMeleeDistance}))
    table.insert(self.DPSAbilities, common.getSkill('Tiger Claw', {condition=conditions.withinMeleeDistance}))
    table.insert(self.DPSAbilities, common.getBestDisc({'Dragon Fang', 'Clawstriker\'s Flurry', 'Leopard Claw'}, {condition=conditions.withinMeleeDistance}))
    table.insert(self.DPSAbilities, common.getAA('Five Point Palm', {condition=conditions.withinMeleeDistance}))
    --table.insert(self.DPSAbilities, common.getAA('Stunning Kick'))
    table.insert(self.DPSAbilities, common.getAA('Eye Gouge', {condition=conditions.withinMeleeDistance}))
end

function Monk:initBurns()
    table.insert(self.burnAbilities, common.getAA('Fundament: Second Spire of the Sensei'))
    local speedFocus = common.getBestDisc({'Speed Focus Discipline'})
    local crystalPalm = common.getBestDisc({'Crystalpalm Discipline', 'Innerflame Discipline'})
    local heel = common.getBestDisc({'Heel of Kai', 'Heel of Kanji'})
    if crystalPalm then
        crystalPalm.condition = function() return not speedFocus or not mq.TLO.Me.CombatAbilityReady(speedFocus.Name)() end
        table.insert(self.burnAbilities, speedFocus)
    end
    if heel then
        heel.condition = function() return not crystalPalm or not mq.TLO.Me.CombatAbilityReady(crystalPalm.Name)() end
        table.insert(self.burnAbilities, crystalPalm)
    end
    table.insert(self.burnAbilities, heel)
    table.insert(self.burnAbilities, common.getAA('Destructive Force', {opt='USEAOE'}))
end

function Monk:initBuffs()
    table.insert(self.auras, common.getBestDisc({'Master\'s Aura', 'Disciple\'s Aura'}, {CheckFor='Disciples Aura'}))
    table.insert(self.combatBuffs, common.getItem('Fistwraps of Celestial Discipline', {delay=1000}))
    table.insert(self.combatBuffs, common.getBestDisc({'Fists of Wu'}))
    table.insert(self.combatBuffs, common.getAA('Zan Fi\'s Whistle'))
    table.insert(self.combatBuffs, common.getAA('Infusion of Thunder'))
end

function Monk:initDefensiveAbilities()
    local postFD = function()
        mq.delay(1000)
        mq.cmd('/stand')
        mq.cmd('/makemevis')
    end
    table.insert(self.fadeAbilities, common.getAA('Imitate Death', {opt='USEFD', postcast=postFD}))
    table.insert(self.aggroReducers, common.getSkill('Feign Death', {opt='USEFD', postcast=postFD}))
end

function Monk:initHeals()
    table.insert(self.healAbilities, common.getSkill('Mend', {me=60, self=true}))
end

return Monk
