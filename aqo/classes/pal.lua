local class = require('classes.classbase')
local common = require('common')

local Paladin = class:new()

--[[
    https://forums.daybreakgames.com/eq/index.php?threads/paladin-pro-tips.239287/ worst guide ever
    Burst
    Grief
    Burst
    Splash
    BV
    -adjustable / undead nuke-
    Valiant deflection
    Crush
    -adjustable / heal proc-
    -adjustable / harmonious-
    Preservation
    Staunch

    -- Defensives
    Skalber Mantle
    Armor of Ardency
    Holy Guardian Discipline

    -- Aggro Spam
    Crush of the Darkened Sea
    Crush of Povar
    Valiant Defense
    Ardent Force
    Force of Disruption

    Radiant Cure
    Splash of Purification

    Dicho - debatable usefulness?
    Aurora
    Wave

    Brilliant Vindication

    Stance
]]
function Paladin:init()
    self.classOrder = {'assist', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest'}
    self.spellRotations = {standard={}}
    self:initBase('pal')

    self:loadSettings()
    self:initDPSAbilities()
    self:addCommonAbilities()

    self.rezStick = common.getItem('Staff of Forbidden Rites')
end

function Paladin:initDPSAbilities()
    table.insert(self.DPSAbilities, common.getSkill('Kick'))
end

function Paladin:availableBuffs()
    self.spells.BRELLS = self.spells.brells
    return {BRELLS=self.spells.brells}
end

return Paladin