---@type Mq
local mq = require('mq')
local class = require(AQO..'.classes.classbase')
local common = require(AQO..'.common')

class.class = 'bst'
class.classOrder = {'assist', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest', 'managepet'}

class.SPELLSETS = {standard=1}
class.addCommonOptions()

class.addSpell('pethaste',{'Arag\'s Celerity'}) -- pet haste
class.addSpell('pet', {'Spirit of Sorsha, pet'}, {opt='SUMMONPET'}) -- pet
class.addSpell('petbuff', {'Spirit of Rellic'}) -- pet buff
class.addSpell('groupregen', {'Spiritual Vigor'}) -- group buff
class.addSpell('heal', {'Trushar\'s Mending'}, {me=75, self=true}) -- heal
class.addSpell('petheal', {'Healing of Sorsha'}) -- pet heal
class.addSpell('fero', {'Ferocity'}) -- like shm avatar

local standard = {}

class.spellRotations = {
    standard=standard
}

table.insert(class.DPSAbilities, common.getSkill('Kick'))
table.insert(class.DPSAbilities, common.getAA('Feral Swipe'))
table.insert(class.burnAbilities, common.getBestDisc({'Bestial Fury Discipline'})) -- burn disc

table.insert(class.petBuffs, class.spells.pethaste)
table.insert(class.petBuffs, class.spells.petbuff)

table.insert(class.healAbilities, class.spells.heal)

table.insert(class.selfBuffs, class.spells.groupregen)
table.insert(class.selfBuffs, class.spells.fero)
table.insert(class.selfBuffs, common.getAA('Gelid Rending'))

local melees = {MNK=true,BER=true,ROG=true}
class.buff_class = function()
    if common.am_i_dead() then return end

    if class.spells.fero and mq.TLO.Me.SpellReady(class.spells.fero.name)() and mq.TLO.Group.GroupSize() then
        for i=1,mq.TLO.Group.GroupSize()-1 do
            local member = mq.TLO.Group.Member(i)
            local distance = member.Distance3D() or 300
            if melees[member.Class.ShortName()] and not member.Buff(class.spells.fero.name)() and distance < 100 then
                member.DoTarget()
                mq.delay(100, function() return mq.TLO.Target.ID() == member.ID() end)
                mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end)
                if not mq.TLO.Target.Buff(class.spells.fero.name)() then
                    if class.spells.fero:use() then return end
                end
            end
        end
    end
end

return class