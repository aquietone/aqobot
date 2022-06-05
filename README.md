# aqobot

Lua class automation scripts for MQ.

## Description
Provides a CWTN-like interface for bard, necro and ranger class automation with assist and chase modes, pre-configured spells, discs, AAs and abilities to use, and a UI to control a handful of settings.

Each of the class files, `brd.lua`, `nec.lua` and `rng.lua` includes a number of tables for spells, AAs and discs. Hopefully its clear from the naming which are for burns, which are standard rotations, mash abilities, etc.

### Common Settings

- *Mode*: Manual, Assist or Chase.

- *Camp Radius*: The radius within which you will assist on mobs.

- *Chase Target*: Type in a `PC` name of the person to chase in chase mode. Its using an exact match spawn search for `PC`'s only.
- *Chase Distance*: Distance threshold to trigger chasing the chase target.

- *Assist*: Who to assist. Group MA, Raid MA 1, 2 or 3.
- *Auto Assist At*: Mob Percent HP to begin assisting.
- *Switch With MA*: Swap targets if the MA swaps targets. A bit odd, but this will also trigger manual mode to assist... makes it a bit like a vorpal mode? assists without chasing or setting a camp.

- *Burn Always*: Burn routine is always entered and burn abilities are used as available. Its not great, it doesn't attempt to line up CDs or anything.
- *Burn All Named*: Enter burn routine when `${Target.Named}` is `true`. Kinda sucks with ToL zones since so many akhevan trash mobs return `true`.
- *Burn Count*: Enter burn routine when greater than or equal to this number of mobs are within camp radius.
- *Burn Percent*: Same as `Burn Always`, but only after mob HP is below this percent.

- *Spell Set*: Set the spell set to be loaded, different classes have different options.

- *Use Alliance*: Toggle whether to attempt using alliance spells

### Bard Settings

- *Spell Set*: melee, caster, melee dot.

- *Mez ST*: Use single target mez on adds within camp radius.
- *Mez AE*: Use AE Mez if 3 or more mobs are within camp radius.

- *Use Epic*: Always, Burn, Shaman or None. Will always use epic and fierce eye together. `Shaman` means only use when `Prophet's Gift of the Ruchu` song is up.

- *Use Fade*: Fades if you are on ToT or Percent HP below 50 or aggro above 70% on target. Not really tested this one at all.
- *Rally Group*: Not implemented

- *BYOS*: Disables attempts to mem the currently selected spell set, but currently will only try to play the songs listed in the currently selected spell set. Mostly just put this in atm so I can swap some gems on Shei mission.

### Necro Settings

- *Spell Set*: standard, short

- *Stop Percent*: Stop casting DoTs on mobs when mob percent HP below this value.
- *Debuff*: Cast `Scent of Terris` AA on mobs.
- *Use Mana Drain DoT*: Cast `Mind Atrophy`.

- *Buff Shield of Fate*: Keep `Shield of Fate` up at all times.

- *Summon Pet*: Summon the level 120 pet if you have no pet.
- *Buff Pet*: Cast `Sigil of Undeath` buff on pet.
- *Use Inspire Ally*: Keep `Inspire Ally` buff up on pet.

- *Use Rez*: Use `Convergence` AA on dead group members within range. Prioritizes healer, then tank, then remaining group members.
- *Use FD*: Use `Death's Effigy` when you have agro or are above 90% aggro. Use `Death's Peace` when aggro is above 70%. Also use `Dying Grasp` before flopping if HP below 40%.

### Ranger Settings

- *Use Melee*: Control whether to melee mobs. If you only ever want to ranged, then leave this off.
- *Use Range*: Control whether to bow mobs. If you only ever want to melee, then leave this off. If ranged is enabled, ranged will always take precedence over melee.

- *Use Unity (Azia)*: Buff self with `Wildstalker's Unity (Azia)` AA. Cannot be enabled at the same time as Beza.
- *Use Unity (Beza)*: Buff self with `Wildstalker's Unity (Beza)` AA. Cannot be enabled at the same time as Azia.

- *Use Poison Arrows*: Buff self with `Poison Arrows` AA. Cannot be enabled at the same time as Flaming Arrows.
- *Use Flaming Arrows*: Buff self with `Flaming Arrows` AA. Cannot be enabled at the same time as Poison Arrows.
- *Use DoT*: Controls whether to cast the high mana cost DoT on mobs. My rangers gear is bad, so dotting all the things is expensive.

## Installation
Copy the `aqo.lua` file and `aqo` folder into your MQ Lua folder.

## Usage
Start the script: `/lua run aqo`

The script uses the same sort of command structure to the class plugins, using class shortname command bindings. For example:
- To set mode to manual: `/brd mode 0`
- To set mode to assist: `/brd mode 1`
- To set mode to chase: `/brd mode 2`
- To pause: `/nec pause on`
- To resume: `/nec pause off`
- To show the UI: `/rng show`
- To hide the UI: `/rng hide`
- To enable burns on demand: `/brd burnnow`

## Roadmap
Just filling in the missing stuff from my group, making things that work for me. No real plans.
