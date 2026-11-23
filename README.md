# Gothic 1 Remake: Inventory Sort

A small script-only mod for Gothic 1 Remake: the inventory stays sorted. Items are grouped by type, in the order of the inventory tabs (melee weapons, ranged weapons, magic, wearables, food, potions, materials, documents, miscellaneous, artefacts) and of the item types inside each tab (for example one-handed swords, then two-handed swords; food, then herbs). Within a type, weapons go by damage and armor by protection, strongest first; then items go by name.

Turn it off in `Settings > Game > Inventory Sort`.

## How it works

The game shows backpack items newest first, ordered by the time each item was last added. The mod gives every backpack item a made-up "last added" time that puts it in the wanted place, so the game's own list shows the sorted order and using, equipping and dropping still act on the item you see. A newly picked-up item shows at the top until the open inventory sorts it in, a moment later.

Items on the hotbar and equipped items are kept in separate lists by the game, are not touched and stay at the top of their tab. Trade, loot and crafting screens are not sorted while they are open; they show the order from the last time the inventory was open.

The times are saved with the game. After removing the mod the last order stays, and new items show at the top again.

## Install

1. Copy the `InventorySort` folder to `G1R/Mods` in the game's install folder.
2. Enable the mod in the game's mod manager (launch option `-ModManagementUI`).

No UE4SS or other loader is needed. Loading an older save shows the game's different-modlist warning, as with any mod.

This is an unofficial modification. It is not made, endorsed or supported by THQ Nordic.
