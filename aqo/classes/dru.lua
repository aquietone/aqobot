---@type Mq
local mq = require 'mq'
local class = require(AQO..'.classes.classbase')
local timer = require(AQO..'.utils.timer')
local common = require(AQO..'.common')

class.class = 'dru'
class.classOrder = {'heal', 'assist', 'cast', 'burn', 'recover', 'buff', 'rest', 'managepet'}

class.SPELLSETS = {standard=1}
class.addCommonOptions()
class.addOption('USENUKES', 'Use Nukes', false, nil, 'Toggle use of nuke spells', 'checkbox')
class.addOption('USESNARE', 'Use Snare', true, nil, 'Cast snare on mobs', 'checkbox')

class.addSpell('heal', {'Nature\'s Infusion', 'Chloroblast', 'Superior Healing', 'Nature\'s Renewal', 'Light Healing', 'Minor Healing'}, {panic=true, regular=true, me=75, mt=75, other=75, pet=60})
class.addSpell('groupheal', {'Moonshadow', 'Word of Restoration'}, {group=true})
class.addSpell('firenuke', {'Dawnstrike', 'Sylvan Fire', 'Wildfire', 'Scoriae', 'Firestrike'}, {opt='USENUKES'})
class.addSpell('dot', {'Winged Death'})
class.addSpell('snare', {'Ensnare', 'Snare'})
class.addSpell('aura', {'Aura of Life', 'Aura of the Grove'}, {aura=true})
class.addSpell('pet', {'Nature Wanderer\'s Behest'})
class.addSpell('reptile', {'Skin of the Reptile'})

class.snare = class.spells.snare

-- Aura of the Grove, Aura of the Grove Effect

local standard = {}
table.insert(standard, class.spells.firenuke)

class.spellRotations = {
    standard=standard
}

table.insert(class.healAbilities, class.spells.heal)
table.insert(class.healAbilities, class.spells.groupheal)

table.insert(class.auras, class.spells.aura)

class.nuketimer = timer:new(5)

local melees = {MNK=true,WAR=true,PAL=true,SHD=true}
class.buff_class = function()
    if common.am_i_dead() then return end

    if class.spells.reptile and mq.TLO.Me.SpellReady(class.spells.reptile.name)() and mq.TLO.Group.GroupSize() then
        for i=1,mq.TLO.Group.GroupSize()-1 do
            local member = mq.TLO.Group.Member(i)
            local distance = member.Distance3D() or 300
            if melees[member.Class.ShortName()] and not member.Dead() and not member.Buff(class.spells.reptile.name)() and distance < 100 then
                member.DoTarget()
                mq.delay(100, function() return mq.TLO.Target.ID() == member.ID() end)
                mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end)
                if not mq.TLO.Target.Buff(class.spells.reptile.name)() then
                    if class.spells.reptile:use() then return end
                end
            end
        end
    end
end

return class