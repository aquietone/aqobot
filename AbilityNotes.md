# Notes

Call static Ability.use to perform checks before casting (can use, should use, condition, option) and handle swapping, precast, postcast. (use when )

Call instance ability:execute to cast with zero checks. (just used by static Ability.Use after checks are performed)

Call instance ability:use to cast with timer and readiness checks. (use when condition, option already checked prior such as findNextSpell loops)

## Ability

Defines characteristics and use of:

- Spells
- Combat Abilities
- Alternate Abilities
- Item Clickies
- Skills

### Should Use Spell

Checks whether it makes sense to use an ability.
If beneficial and has duration, check the spell stacks and target is in range.
If beneficial and is instant, check target is in range if target is required.

If detrimental and has duration, check target in range and LoS and not debuffed or debuff about to fade and not corpse.
If detrimental and is instant, check target is in range and LOS and not corpse.

### Can Use Spell

Checks whether you have the resources to use an ability.
Is the spell ready?
Is the character moving or already casting? (If not a bard)
Does the character have enough mana or endurance?
Does the character have the proper reagents?

### Use

Static method for using an ability.
If the ability's timer is not expired, do not use it.
If already casting, do not use it. (unless cast time < 500 and class is bard)
If isReady is true or the ability is a spell which can be swapped in and the condition is met and the ability is enabled, proceed.
If the ability requires swapping, do so.
Use precast if defined.
Execute the ability.
Use postcast if defined.

## Spell

Defines an Ability of type Spell.
Spell timer is set to ${Spell[].RecastTime}

### Execute

Stopsong if bard.
Cast the spell.
Set casting state.

### Use

If the spell's timer is not expired or isReady is false, do not cast.
Stopsong if bard.
Cast the spell.
Set casting state.

### isReady

Return CanUseSpell and ShouldUseSpell

## Disc

Defines an Ability of type Disc.
Disc timer is set to ${Spell[].RecastTime}

### Execute

If current disc matches disc to overwrite, /stopdisc.
If not an active disc or no active disc is running, proceed.
Use the disc.
Set casting state.

### Use

If the disc's timer is not expired or isReady is false, do not use.
if current disc matches disc to overwrite, /stopdisc and proceed.
if not an active disc or no active disc is running, proceed.
Use the disc.
Set casting state.

### isReady

Return CombatAbilityReady and CanUseSpell and ShouldUseSpell.

### isActive

Return IsSkill and Duration > 0 TargetType == Self and not StacksWithDiscs.

## AA

Defines an Ability of type AA.
AA timer is set to ${AltAbility[].ReuseTimer}

### Execute

Use the AA.
Set casting state.

### Use

If the AA's timer is not expired or isReady is false, do not use.
Use the AA.
Set casting state.

### isReady

Return AltAbilityReady and CanUseSpell and ShouldUseSpell.

## Item

Defines an Ability of type Item.
Item timer is set to ${FindItem[].Clicky.TimerID}*1000

### Execute

Stopsong if bard and cast time > 500.
Use the item.
Set casting state.

### Use

If the Item's timer is not expired or isReady is false, do not use.
Stopsong if bard and cast time > 500.
Use the item.
Set casting state.

### isReady

If prestige item and not gold status, do not use.
Return item.Timer == 0 and CanUseSpell and ShouldUseSpell

## Skill

Defines an Ability of type Skill.
Skill timer is set to 2000.

### Execute

Use the skill.
Set casting state.

### Use

If isReady and timer expired, proceed.
Use the skill.
Set casting state.

### isReady

Return AbilityReady() and Me.Skill() > 0

## Spell Swapping

### Swap Spell

If casting or cursor not empty, return.
If spell already mem'd, return.
If spell matching other name (composites), return.
Mem the spell.
Set mem spell state.

### Swap and Cast

If spell not mem'd, call SwapSpell and queue action to Ability.Use spell and swap to original spell.
If spell is mem'd, Ability.Use

## Uses of Ability.Use

common.lua
- checkCombatBuffs
- checkItemBuffs
- checkMana
- processList

enc.lua
- recover

buff.lua
- summonItem
- buffCombat
- buffAuras
- buffSelf
- buffSingle
- buffPet

debuff.lua
- findNextDebuff

heal.lua
- heal
- healPetOrSelf
- healSelf
- doRezFor

mez.lua
- doAE
- doSingle

pull.lua
- pullEngage

## Uses of ability:Use

brd.lua
- tryAlliance
- castSynergy
- cast
- useEpic
- mashClass
- pullCustom
- doneSinging

bst.lua
- recoverClass

classbase.lua
- cure
- doCombatLoop
- burn
- cast
- aggro
- recover
- handleRequests

enc.lua
- castSynergy
- recover

nec.lua
- burnClass
- preBurn
- recover
- aggroOld

rng.lua
- useOpener
- cast
- burnClass

shd.lua
- mashClass
- burnClass
- ohshit

war.lua
- ohShitClass

assist.lua
- sendPet use summonCompanion

cure.lua
- singleCure
- groupCure

events.lua
- eventTranquil use tranquil