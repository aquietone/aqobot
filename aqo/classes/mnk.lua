--- @type Mq
local mq = require('mq')
local class = require('classes.classbase')
local conditions = require('routines.conditions')
local sharedabilities = require('utils.sharedabilities')
local common = require('common')
local state = require('state')

local Monk = class:new()

--[[
    http://forums.eqfreelance.net/index.php?topic=17466.0
]]
--[[
self:addAA('Distant Strike') -- pull ability
self:addAA('Magnanimous Force') -- knockback + memblur
self:addAA('Moving Mountains') -- fling mob to you
self:addAA('Purify Body') -- self remove detrimental affects, 4min cd
self:addAA('Swift Tails\' Chant') -- restore 6000 end to group, 10 min cd, timer 8
self:addAA('Ton Po\'s Stance') -- extra crits + attacks, 5 min cd, timer 9
self:addAA('Devastating Assault') -- 2 minutes of aoe melee, 5 min cd, timer 30
self:addAA('Dragon Force') -- knockback
self:addAA('Focused Destructive Force') -- 42 seconds of extra melee attacks on target, 15 min cd, timer 2
self:addAA('Grappling Strike') -- pulls target towards you
self:addAA('Neshika\'s Blink') -- leap
self:addAA('Vehement Rage') -- inc base dmg and minimum dmg, 5 min cd, timer 61
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
    -- Kick abilities
    table.insert(self.DPSAbilities, common.getBestDisc({'Fatewalker\'s Synergy', 'Bloodwalker\'s Synergy', 'Icewalker\'s Synergy', 'Firewalker\'s Synergy', 'Doomwalker\'s Synergy'}, {condition=conditions.withinMeleeDistance})) -- strong kick + inc kick dmg
    table.insert(self.DPSAbilities, common.getBestDisc({'Flurry of Fists', 'Buffeting of Fists', 'Barrage of Fists', 'Firestorm of Fists', 'Torrent of Fists'}, {condition=conditions.withinMeleeDistance})) -- 3x tiger claw + monk synergy proc
    table.insert(self.DPSAbilities, common.getBestDisc({'Curse of Sixteen Shadows', 'Curse of Fifteen Strikes', 'Curse of Fourteen Fists', 'Curse of the Thirteen Fingers'}, {condition=conditions.withinMeleeDistance})) -- inc dmg from DS
    table.insert(self.DPSAbilities, common.getBestDisc({'Uncia\'s Fang', 'Zlexak\'s Fang', 'Hoshkar\'s Fang', 'Zalikor\'s Fang', 'Dragon Fang', 'Clawstriker\'s Flurry', 'Leopard Claw'}, {condition=conditions.withinMeleeDistance})) -- a nuke?
    table.insert(self.DPSAbilities, self:addAA('Stunning Kick', {condition=conditions.withinMeleeDistance})) -- free flying kick + a stun, emu only?
    if mq.TLO.Me.Skill('Flying Kick')() > 0 then
        table.insert(self.DPSAbilities, common.getSkill('Flying Kick', {condition=conditions.withinMeleeDistance}))
    elseif mq.TLO.Me.Skill('Round Kick')() > 0 then
        table.insert(self.DPSAbilities, sharedabilities.getRoundKick())
    elseif mq.TLO.Me.Skill('Kick')() > 0 then
        table.insert(self.DPSAbilities, sharedabilities.getKick())
    end
    table.insert(self.DPSAbilities, common.getSkill('Tiger Claw', {condition=conditions.withinMeleeDistance}))
    table.insert(self.DPSAbilities, common.getBestDisc({'Bloodwalker\'s Precision Strike', 'Icewalker\'s Precision Strike', 'Firewalker\'s Precision Strike', 'Doomwalker\'s Precision Strike'})) -- shuriken attack + buffs shuriken dmg
    table.insert(self.DPSAbilities, common.getBestDisc({'Bloodwalker\'s Conjunction', 'Icewalker\'s Coalition', 'Firewalker\'s Covenant', 'Doomwalker\'s Alliance'}))
    table.insert(self.DPSAbilities, self:addAA('Five Point Palm', {condition=conditions.withinMeleeDistance})) -- large nuke, 5 min cd, should FD after
    table.insert(self.DPSAbilities, self:addAA('Eye Gouge', {condition=conditions.withinMeleeDistance})) -- emu only?
end

--[[
        -- Burns
    -- Instant activations for start of burn
    -- bp click -- add dmg to next x kicks
    table.insert(self.burnAbilities, self:addAA('Two-Finger Wasp Touch', {first=true})) -- double dmg taken from special punches, doesn't stack across monks
    --Zan Fi's Whistle -- big melee dmg bonus, combat buff
    table.insert(self.burnAbilities, common.getBestDisc({'Disciplined Reflexes', 'Decisive Reflexes', 'Rapid Reflexes', 'Nimble Reflexes'}, {first=true})) -- defensive
    table.insert(self.burnAbilities, common.getBestDisc({'Ironfist'}, {first=true})) -- inc melee dmg
    table.insert(self.burnAbilities, self:addAA('Spire of the Sensei', {first=true}))  -- inc chance for wep procs
    table.insert(self.burnAbilities, common.getBestDisc({'Tiger\'s Symmetry', 'Dragon\'s Poise', 'Eagle\'s Poise', 'Tiger\'s Poise', 'Dragon\'s Balance'}, {first=true})) -- adds extra attacks
    table.insert(self.burnAbilities, self:addAA('Infusion of Thunder', {first=true})) -- chance to inc melee dmg + nuke

    -- Burn spam
    table.insert(self.burnAbilities, common.getBestDisc({'Crane Stance'}, {first=true})) -- 2 big kicks
    table.insert(self.burnAbilities, self:addAA('Five Point Palm', {first=true})) -- big dragon punch with nuke
    -- click off ironfist?
    -- click bp here?
    table.insert(self.burnAbilities, common.getBestDisc({'Heel of Zagali'}, {first=true}))
    -- spam kick abilities

    -- 2nd Burn
    table.insert(self.burnAbilities, common.getBestDisc({'Speed Focus'}, {second=true})) -- doubles attack speed
    table.insert(self.burnAbilities, self:addAA('Focused Destructive Force', {second=true})) -- doubles number of primary hand attacks

    -- 3rd Burn
    table.insert(self.burnAbilities, self:addAA('Two-Finger Wasp Touch', {third=true})) -- if another monks has faded
    table.insert(self.burnAbilities, common.getBestDisc({'Terrorpalm'}, {third=true})) -- inc dmg from melee, inc min dmg

    -- 4th Burn
    --table.insert(self.burnAbilities, common.getBestDisc({'Ironfist'})) -- if not used yet
    table.insert(self.burnAbilities, common.getBestDisc({'Eye of the Storm'}, {third=true})) -- inc dmg, inc min dmg

    -- 5th Burn
    table.insert(self.burnAbilities, common.getBestDisc({'Earthforce'})) -- defensive, adds heroic str
]]
function Monk:initBurns()
    if state.emu then
        table.insert(self.burnAbilities, self:addAA('Fundament: Second Spire of the Sensei'))
        local speedFocus = common.getBestDisc({'Speed Focus Discipline'})
        local crystalPalm = common.getBestDisc({'Crystalpalm Discipline', 'Innerflame Discipline'}, {condition=function() return not speedFocus or not mq.TLO.Me.CombatAbilityReady(speedFocus.Name)() end})
        local heel = common.getBestDisc({'Heel of Kai', 'Heel of Kanji'}, {condition=function() return not crystalPalm or not mq.TLO.Me.CombatAbilityReady(crystalPalm.Name)() end})
        table.insert(self.burnAbilities, speedFocus)
        table.insert(self.burnAbilities, crystalPalm)
        table.insert(self.burnAbilities, heel)
        table.insert(self.burnAbilities, self:addAA('Destructive Force', {opt='USEAOE'}))
    else
        -- Instant activations for start of burn
        -- bp click -- add dmg to next x kicks
        table.insert(self.burnAbilities, self:addAA('Two-Finger Wasp Touch', {first=true})) -- double dmg taken from special punches, doesn't stack across monks
        --Zan Fi's Whistle -- big melee dmg bonus, combat buff
        table.insert(self.burnAbilities, common.getBestDisc({'Disciplined Reflexes', 'Decisive Reflexes', 'Rapid Reflexes', 'Nimble Reflexes'}, {first=true})) -- defensive
        table.insert(self.burnAbilities, common.getBestDisc({'Ironfist'}, {first=true})) -- inc melee dmg
        table.insert(self.burnAbilities, self:addAA('Spire of the Sensei', {first=true}))  -- inc chance for wep procs
        table.insert(self.burnAbilities, common.getBestDisc({'Tiger\'s Symmetry', 'Dragon\'s Poise', 'Eagle\'s Poise', 'Tiger\'s Poise', 'Dragon\'s Balance'}, {first=true})) -- adds extra attacks
        table.insert(self.burnAbilities, self:addAA('Infusion of Thunder', {first=true})) -- chance to inc melee dmg + nuke
        table.insert(self.burnAbilities, common.getBestDisc({'Crane Stance'}, {first=true})) -- 2 big kicks

        -- click off ironfist?
        -- click bp here?
        table.insert(self.burnAbilities, common.getBestDisc({'Heel of Zagali'}, {first=true}))
        -- spam kick abilities

        -- 2nd Burn
        table.insert(self.burnAbilities, common.getBestDisc({'Speed Focus Discipline'}, {second=true})) -- doubles attack speed
        table.insert(self.burnAbilities, self:addAA('Focused Destructive Force', {second=true})) -- doubles number of primary hand attacks

        -- 3rd Burn
        table.insert(self.burnAbilities, self:addAA('Two-Finger Wasp Touch', {third=true})) -- if another monks has faded
        table.insert(self.burnAbilities, common.getBestDisc({'Terrorpalm Discipline'}, {third=true})) -- inc dmg from melee, inc min dmg

        -- 4th Burn
        --table.insert(self.burnAbilities, common.getBestDisc({'Ironfist'})) -- if not used yet
        table.insert(self.burnAbilities, common.getBestDisc({'Eye of the Storm'}, {third=true})) -- inc dmg, inc min dmg
    end
end

function Monk:initBuffs()
    table.insert(self.auras, common.getBestDisc({'Master\'s Aura', 'Disciple\'s Aura'}, {CheckFor='Disciples Aura', aurabuff=true}))
    table.insert(self.combatBuffs, common.getItem('Fistwraps of Celestial Discipline', {delay=1000, combatbuff=true}))
    table.insert(self.combatBuffs, common.getBestDisc({'Fists of Wu'}, {combatbuff=true}))
    table.insert(self.combatBuffs, self:addAA('Zan Fi\'s Whistle', {combatbuff=true}))
    table.insert(self.combatBuffs, self:addAA('Infusion of Thunder', {combatbuff=true}))
    table.insert(self.combatBuffs, common.getBestDisc({'Ecliptic Form', 'Composite Form', 'Dissident Form', 'Dichotomic Form'}, {combatbuff=true})) -- large bonus dmg
end

function Monk:initDefensiveAbilities()
    local postFD = function()
        mq.delay(1000)
        mq.cmd('/stand')
        mq.cmd('/makemevis')
    end
    table.insert(self.fadeAbilities, self:addAA('Imitate Death', {opt='USEFD', postcast=postFD}))
    table.insert(self.aggroReducers, common.getSkill('Feign Death', {opt='USEFD', postcast=postFD}))
    table.insert(self.defensiveAbilities, common.getBestDisc({'Earthforce Discipline'})) -- defensive, adds heroic str
end

function Monk:initHeals()
    table.insert(self.healAbilities, common.getSkill('Mend', {me=60, self=true}))
end

return Monk
