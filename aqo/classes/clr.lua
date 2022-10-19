--- @type Mq
local mq = require 'mq'
local class = require(AQO..'.classes.classbase')
local common = require(AQO..'.common')

class.class = 'clr'
class.classOrder = {'heal', 'assist', 'mash', 'burn', 'recover', 'buff', 'rest', 'rez'}

class.SPELLSETS = {standard=1}
class.addCommonOptions()
class.addOption('USEYAULP', 'Use Yaulp', false, nil, 'Toggle use of Yaulp', 'checkbox')
class.addOption('USEHAMMER', 'Use Hammer', false, nil, 'Toggle use of summoned hammer pet', 'checkbox')

--class.addSpell('heal', {'Healing Light', 'Superior Healing', 'Light Healing', 'Minor Healing'}, {me=70, mt=70, other=50})
class.addSpell('remedy', {'Supernal Remedy', 'Remedy'}, {me=75, mt=75, other=75, pet=60})
class.addSpell('aura', {'Aura of Divinity'}, {aura=true})
class.addSpell('yaulp', {'Yaulp VI'}, {combat=true, ooc=false, opt='USEYAULP'})
class.addSpell('armor', {'Armor of the Zealot'})
class.addSpell('hammerpet', {'Unswerving Hammer of Justice'}, {opt='USEHAMMER'})
class.addSpell('groupheal', {'Word of Replenishment', 'Word of Redemption'}, {threshold=3, group=true, pct=70})
--common.getAA('Celestial Regeneration')
--common.getAA('Divine Arbitration')

local standard = {}

class.spellRotations = {
    standard=standard
}

table.insert(class.DPSAbilities, class.spells.hammerpet)

--table.insert(class.healAbilities, class.spells.heal)
table.insert(class.healAbilities, common.getAA('Divine Arbitration', {me=30, mt=30, other=30}))
table.insert(class.healAbilities, class.spells.groupheal)
table.insert(class.healAbilities, class.spells.remedy)

-- Project Lazarus only
local aaAura = common.getAA('Spirit Mastery', {checkfor='Aura of Pious Divinity'})
if aaAura then
    table.insert(class.auras, aaAura)
else
    table.insert(class.auras, class.spells.aura)
end
table.insert(class.selfBuffs, class.spells.yaulp)
table.insert(class.selfBuffs, class.spells.armor)

local rez = common.getAA('Blessing of Resurrection')

class.rez = function()
    if mq.TLO.Me.AltAbilityReady(rez.name)() then
        local corpseCount = mq.TLO.SpawnCount('pc group corpse radius 100')()
        if corpseCount > 0 then
            mq.cmd('/mqt pccorpse group radius 100')
            mq.delay(100)
            if mq.TLO.Target.Type() == 'Corpse' then
                mq.cmd('/corpse')
                mq.delay(100)
                rez:use()
            end
        end
    end
end

return class