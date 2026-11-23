# Gothic 1 Remake: Inventory Sort

A small script-only mod for Gothic 1 Remake: the inventory stays sorted. Items are grouped by type, in the order of the inventory tabs (melee weapons, ranged weapons, magic, wearables, food, potions, materials, documents, miscellaneous, artefacts) and of the item types inside each tab (for example food, then herbs). Within a type, the most valuable item comes first.

Turn it off in `Settings > Game > Inventory Sort`.

## How it works

The game shows backpack items in the order of its own item list, with new items added at the end, and every inventory action (use, equip, drop) picks the item by its place in that list. A mod that only reorders the view makes those actions hit the wrong item. This mod reorders the list itself, so what you see is what you use.

While the inventory screen is open, the mod checks the list a few times per second and reorders it when it is out of order (usually right after opening, when new items sit at the end). Equipped items and the hotbar are kept in separate lists by the game and are not touched. Trade, loot and crafting screens are not sorted while they are open; they show the order from the last time the inventory was opened.

The new order is the game's own list, so it is saved with the game. Removing the mod keeps the last order; new items go to the end again.

## Install

1. Copy the `InventorySort` folder to `G1R/Mods` in the game's install folder.
2. Enable the mod in the game's mod manager (launch option `-ModManagementUI`).

No UE4SS or other loader is needed. Loading an older save shows the game's different-modlist warning, as with any mod.

This is an unofficial modification. It is not made, endorsed or supported by THQ Nordic.
