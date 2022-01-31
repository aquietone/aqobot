# aqobot

EverQuest class automation Lua scripts for MacroQuest.

## Description
Provides a CWTN-like interface for bard, necro, ranger and warrior (so far) class automation with assist and chase modes, pre-configured spells, discs, AAs and abilities to use, and a UI to control a handful of settings.

Each of the class files, `brd.lua`, `nec.lua`, `rng.lua` and `war.lua` includes a number of tables for spells, AAs, discs and items. Hopefully its clear from the naming which are for burns, which are standard rotations, mash abilities, etc.

### Common Settings

- *Mode*: Manual, Assist or Chase. (Other modes still a work in progress.. pullertank sort of works on warrior as of writing). Ex. `/docommand /${Me.Class.ShortName} mode 0`

- *Camp Radius*: The radius within which you will assist on mobs. Ex. `/docommand /${Me.Class.ShortName} campradius 60`

- *Chase Target*: Type in a `PC` name of the person to chase in chase mode. Its using an exact match spawn search for `PC`'s only. Ex. `/docommand /${Me.Class.ShortName} chasetarget ${Group.MainAssist}`
- *Chase Distance*: Distance threshold to trigger chasing the chase target. Ex. `/docommand /${Me.Class.ShortName} chasedistance 30`

- *Assist*: Who to assist. Group MA, Raid MA 1, 2 or 3. Ex. `/docommand /${Me.Class.ShortName} assist group`
- *Auto Assist At*: Mob Percent HP to begin assisting. Ex. `/docommand /${Me.Class.ShortName} autoassistat 98`
- *Switch With MA*: Swap targets if the MA swaps targets. A bit odd, but this will also trigger manual mode to assist... makes it a bit like a vorpal mode? assists without chasing or setting a camp. Ex. `/docommand /${Me.Class.ShortName} switchwithma on`

- *Burn Always*: Burn routine is always entered and burn abilities are used as available. Its not great, it doesn't attempt to line up CDs or anything. Ex. `/docommand /${Me.Class.ShortName} burnalways off`
- *Burn All Named*: Enter burn routine when `${Target.Named}` is `true`. Kinda sucks with ToL zones since so many akhevan trash mobs return `true`. Ex. `/docommand /${Me.Class.ShortName} burnallnamed on`
- *Burn Count*: Enter burn routine when greater than or equal to this number of mobs are within camp radius. Ex. `/docommand /${Me.Class.ShortName} burncount 5`
- *Burn Percent*: Same as `Burn Always`, but only after mob HP is below this percent. Ex. `/docommand /${Me.Class.ShortName} burnpercent 95`

- *Spell Set*: Set the spell set to be loaded, different classes have different options. Ex. `/docommand /${Me.Class.ShortName} spellset standard`

- *Use Alliance*: Toggle whether to attempt using alliance spells. Ex. `/docommand /${Me.Class.ShortName} usealliance on`

### Pull Settings

- *Pull Radius*: The radius within which you will pull mobs when in a puller role. Ex. `/docommand /${Me.Class.ShortName} radius 250`
- *Pull Z Low*: The lower Z radius for pulling mobs when in a puller role. Ex. `/docommand /${Me.Class.ShortName} zlow 10`, `/docommand /${Me.Class.ShortName} zradius 50`
- *Pull Z High*: The upper Z radius for pulling mobs when in a puller role. Ex. `/docommand /${Me.Class.ShortName} zhigh 25`, `/docommand /${Me.Class.ShortName} zradius 50`
- *Pull Min Level*: The minimum level mob to pull when in a puller role. Ex. `/docommand /${Me.Class.ShortName} levelmin 115`
- *Pull Max Level*: The maxmimum level mob to pull when in a puller role. Ex. `/docommand /${Me.Class.ShortName} levelmax 124`

### Bard Settings

- *Spell Set*: Refer to common settings Spell Set. Available options for bard: melee, caster, melee dot. Ex. `/brd spellset meleedot`

- *Mez ST*: Use single target mez on adds within camp radius. Ex. `/brd mezst off`
- *Mez AE*: Use AE Mez if 3 or more mobs are within camp radius. Ex. `/brd mezae on`

- *Use Epic*: Options: `always`, `burn`, `shm` or `never`. Will always use epic and fierce eye together. `shm` means only use when `Prophet's Gift of the Ruchu` is up. Ex. `/brd useepic always`

- *Use Fade*: Fades if you are on ToT or Percent HP below 50 or aggro above 70% on target. Not really tested this one at all. Ex. `/brd usefade on`
- *Rally Group*: Not implemented

- *BYOS*: Disables attempts to mem the currently selected spell set, but currently will only try to play the songs listed in the currently selected spell set. Mostly just put this in atm so I can swap some gems on Shei mission. Ex. `/brd byos on`

### Necro Settings

- *Spell Set*: Refer to common settings Spell Set. Available options for necro: `standard`, `short`. Ex. `/nec spellset short`

- *Stop Percent*: Stop casting DoTs on mobs when mob percent HP below this value. Ex. `/nec stoppercent 5`
- *Debuff*: Cast `Scent of Terris` AA on mobs. Ex. `/nec debuff on`
- *Use Mana Drain DoT*: Cast `Mind Atrophy`. Ex. `/nec usemanatap on`

- *Buff Shield of Fate*: Keep `Shield of Fate` up at all times. Ex. `/nec usebuffshield on`

- *Summon Pet*: Summon the level 120 pet if you have no pet. Ex. `/nec summonpet on`
- *Buff Pet*: Cast `Sigil of Undeath` buff on pet. Ex. `/nec buffpet on`
- *Use Inspire Ally*: Keep `Inspire Ally` buff up on pet. Ex. `/nec useinspire on`

- *Use Rez*: Use `Convergence` AA on dead group members within range. Prioritizes healer, then tank, then remaining group members. Ex. `/nec userez on`
- *Use FD*: Use `Death's Effigy` when you have agro or are above 90% aggro. Use `Death's Peace` when aggro is above 70%. Also use `Dying Grasp` before flopping if HP below 40%. Ex. `/nec userez on`

### Ranger Settings

- *Use Melee*: Control whether to melee mobs. If you only ever want to ranged, then leave this off. Ex. `/rng usemelee on`
- *Use Range*: Control whether to bow mobs. If you only ever want to melee, then leave this off. If ranged is enabled, ranged will always take precedence over melee. Ex. `/rng userange on`

- *Use Unity (Azia)*: Buff self with `Wildstalker's Unity (Azia)` AA. Cannot be enabled at the same time as Beza. Ex. `/rng useunityazia on`
- *Use Unity (Beza)*: Buff self with `Wildstalker's Unity (Beza)` AA. Cannot be enabled at the same time as Azia. Ex. `/rng useunitybeza on`
- *Buff Group*: Cast shout and enrichment buffs on group. Does not cope well with blocked buffs but hopefully checks stacking properly otherwise. Ex. `/rng buffgroup on`
- *Use Regen*: Cast regen buff on self. Ex. `/rng useregen on`
- *DS Tank*:  Cast DS on the group main tank. Ex. `/rng dstank on`

- *Use Poison Arrows*: Buff self with `Poison Arrows` AA. Cannot be enabled at the same time as Flaming Arrows. Ex. `/rng usepoisonarrow on`
- *Use Flaming Arrows*: Buff self with `Flaming Arrows` AA. Cannot be enabled at the same time as Poison Arrows. Ex. `/rng usefirearrow on`
- *Use DoT*: Controls whether to cast the high mana cost DoT on mobs. My rangers gear is bad, so dotting all the things is expensive. Ex. `/rng usedot on`
- *Use Nukes*: Controls whether to cast nukes on mobs. Ex. `/rng nuke on`
- *Use Dispel*: Controls whether to dispel mobs. Will use `Entropy of Nature` AA on mobs above `90%` HP when enabled. Ex. `/rng usedispel on`

### Warrior Settings

- *Use Battle Leap*: Keep `Battle Leap Warcry` up by using `Battle Leap`. Ex. `/war usebattleleap on`
- *Use Fortitude*: Not Implemented. Ex. `/war usefortitude on`
- *Use Grapple*: Use `Grappling Strike` ability as available. Ex. `/war usegrapple on`
- *Use Grasp*: Use `Warlord's Grasp` ability as available. Ex. `/war usegrasp on`
- *Use Phantom*: Use `Phantom Aggressor` ability as available. Ex. `/war usephantom on`
- *Use Projection*: Use `Projection of Fury` ability as available. Ex. `/war useprojection on`
- *Use Snare*: Use `Call of Challenge` ability as available. Ex. `/war usesnare on`
- *Use Precision*: Use `Confluent Precision` ability as available. Cannot be enabled at the same time as `Expanse`. Ex. `/war useprecision on`
- *Use Expanse*: Use `Confluent Expanse` ability as available. This will be used when 2 or more mobs are on aggro. Cannot be enabled at the same time as `Precision`. Ex. `/war useexpanse on`

## Installation
Copy the `aqo.lua` file and `aqo` folder into your MQ `lua` folder.

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
Necro works pretty well atm.  
Bard works decent.  
Ranger is alright.  
Warrior still a work in progress.  
Missing a lot of functionality atm, such as: ignore lists, probably a lot of unhappy path issues not handled, probably does poorly in water, ...
