# Gothic 1 Remake: Inventory Sort

Script-only ModKit mod. `InventorySort/` is the mod package; only that folder goes to `G1R/Mods`.

## Rules

- **No spoilers.** Vatra is playing the game for the first time. Game scripts, docs and sample mods contain character, quest, place, item and chapter names. Never write those in chat, commits or files unless Vatra mentioned them first. Use UI names and general words ("herb", "potion", "food").
- Repo content (code, README, commits) is in English. Chat with Vatra is in Croatian.
- Writing outside `~/github` needs Vatra's explicit yes each time. This includes copying to `G1R\Mods`, launch options, `Mods.ini` and other mods in Vortex.
- Don't publish the mod to Nexus or Steam Workshop.
- Only Vatra can confirm the mod works, by seeing it in his game.
- Scope (agreed 2026-11-23, changed the same day after the first test): sort the hero's inventory within each tab by item type (order of the game's tabs and of the types inside each tab), then strength (weapons by damage, armor by protection, highest first), then name. Vatra's minimum is by name. The game's own view has to show the order, not a reordered copy of the view, so use, equip and drop keep acting on the item shown. One on/off setting. Vatra asked for the trade screen's sell list too (2026-11-24, 0.3.0). The trader's goods, loot and crafting lists are not sorted unless Vatra asks.
- The inventory view is ordered by each item's `m_TimeLastAdded`, newest first (matched item for item against a save and a screenshot, 2026-11-23). The order of the game's backpack list is not the inventory view order, so version 0.1.0 (which reordered that list) changed nothing visible. Whether 0.1.0 compiled and ran was not checked.
- The trade screen's sell list is ordered differently: hotbar items first, then the backpack in list order (34 of 34 places after the hotbar matched save G1R-005 against Vatra's screenshot, 2026-11-24). `m_Id` equals the list place in every backpack entry (423 of 423 in G1R-005).
- **Never move the backpack list while a trade screen is shown.** The trade screen copies the list when it opens and after each trade, and a sale takes one unit from the live list at the place the copy gives the clicked item. 0.3.0 moved the list while the screen was open: Vatra's screenshot matched the unmoved list (34 of 34, save G1R-062), and in the saves after two trades the emptied or reduced places held other items before the move than the ones that left (2026-11-24). Since 0.3.1 the list is moved only during a conversation (trading is started only from conversation scripts, `StartTradingWith`), with the hero's `IsInConversation()` and no trade screen tick in the last 30 frames.
- Other mods' code is a reference only: don't copy it without checking its license.
- Game behavior claims come from the shipped scripts (`G1R/Script`, also in the official `AlkimiaInteractive/G1R-Modkit` repo), `G1R/Script/Binds.Cache` (signatures of everything scripts can call), the cooked UI assets (read with gaming `scripts/g1r-level.py`), save files or the ModKit docs, not from memory.

## Shared how-to

How Gothic 1 Remake mods are built here (ModKit, hooks, settings, GAS patterns, UI, checks, install), in Croatian: `~/github/game-development/knowledge-base/gothic-1-remake-modovi.md`. Read it before changing this mod or starting a new one, and add new lessons there, not here.
