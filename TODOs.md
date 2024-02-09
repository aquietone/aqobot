# Abilities

- [x] Move all AA, disc, skill into loop based initialization more similar to spells
  - [x] ber
  - [x] brd
  - [x] bst
  - [x] clr
  - [x] dru
  - [x] enc
  - [x] mag
  - [x] mnk
  - [x] nec
  - [x] pal
  - [x] rng
  - [x] rog
  - [x] shd
  - [x] shm
  - [x] war
  - [x] wiz

- [x] Handle re-initializing abilities and lists when new ability learned

- [ ] Cleanup old keys on abilities
  - [ ] Consolidate Name and CastName?
  - [ ] Get rid of pet heal pct value?
  - [ ] Consolidate Group and Key?
  - [ ] Consolidate CheckFor and SkipIfBuff?

- [x] Rename requestAliases and use for any typical self.abilityname like self.aliases.attraction (bard stuff)

- [ ] Some abilities where we want to pick AAs over spells might need fixing. ranger debuffs, enc/shm slows, dmf, etc.

- [ ] Common alliance class count handling

- [ ] Common epic handling

- [ ] Make rezAbility and pullSpell not singular things

- [ ] Handle spells whose mana cost is based on triggered spells?

- [ ] User defined abilities stored in config

# Buffing

- [x] Remove initBuffs from all classes
  - [x] ber
  - [x] brd
  - [x] bst
  - [x] clr
  - [x] dru
  - [x] enc
  - [x] mag
  - [x] mnk
  - [x] nec
  - [x] pal
  - [x] rng
  - [x] rog
  - [x] shd
  - [x] shm
  - [x] war
  - [x] wiz

- [ ] Cleanup leftovers

- [ ] More dynamic buff begging - currently its fixed, classes ask for specific buffs. classes broadcast specific buffs available. those buffs may or may not be enabled. cleric symbol/aego.

- [ ] Haven't looked at buffs with many parts in a while like unity AA self buffs

# Casting

- [ ] Remove class specific findNextSpell functions

# Cures

- [ ] Still never really implemented curing.. or at least never tried what is implemented

# List Processing

- [ ] Move remaining classes to common list processor
  - [ ] ber
  - [ ] brd
  - [x] bst
  - [ ] clr
  - [ ] dru
  - [ ] enc
  - [ ] mag
  - [x] mnk
  - [ ] nec
  - [x] pal
  - [ ] rng
  - [x] rog
  - [x] shd
  - [ ] shm
  - [x] war
  - [ ] wiz

- [ ] Move more routines with lists to using common list processor
  - [ ] buffing
  - [ ] ...