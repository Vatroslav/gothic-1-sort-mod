# Gothic 1 Remake: Inventory Sort

Script-only ModKit mod. `InventorySort/` is the mod package; only that folder goes to `G1R/Mods`.

## Rules

- **No spoilers.** Vatra is playing the game for the first time. Game scripts, docs and sample mods contain character, quest, place, item and chapter names. Never write those in chat, commits or files unless Vatra mentioned them first. Use UI names and general words ("herb", "potion", "food").
- Repo content (code, README, commits) is in English. Chat with Vatra is in Croatian.
- Writing outside `~/github` needs Vatra's explicit yes each time. This includes copying to `G1R\Mods`, launch options, `Mods.ini` and other mods in Vortex.
- Don't publish the mod to Nexus or Steam Workshop.
- Only Vatra can confirm the mod works, by seeing it in his game.
- Scope (agreed 2026-11-23): sort the hero's inventory within each tab by item type (order of the game's tabs and of the types inside each tab), then by value, highest first. The sort has to reorder the game's own item list, not only the view, so use, equip and drop keep acting on the item shown. One on/off setting. Trade, loot and crafting lists are not sorted while open unless Vatra asks.
- Other mods' code is a reference only: don't copy it without checking its license.
- Game behavior claims come from the shipped scripts (`G1R/Script`, also in the official `AlkimiaInteractive/G1R-Modkit` repo), `G1R/Script/Binds.Cache` (signatures of everything scripts can call), the cooked UI assets (read with gaming `scripts/g1r-level.py`), save files or the ModKit docs, not from memory.

## Shared how-to

How Gothic 1 Remake mods are built here (ModKit, hooks, settings, GAS patterns, UI, checks, install), in Croatian: `~/github/game-development/knowledge-base/gothic-1-remake-modovi.md`. Read it before changing this mod or starting a new one, and add new lessons there, not here.
