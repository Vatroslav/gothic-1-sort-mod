// Inventory Sort: keeps the hero's backpack sorted by item type, then by value.
//
// The game lists backpack items in the order of its own item list (new items
// go to the end), and every inventory action (use, equip, drop) picks the item
// by its place in that list. A mod that only reorders the view therefore makes
// those actions hit the wrong item. This mod reorders the list itself, so the
// view and the actions stay in step.
//
// Every entry's id is its place in the list (the game keeps it that way in
// every inventory of the hero), so ids are renumbered after a reorder.
// Equipped items and the hotbar live in their own inventories and are not
// touched.

// Settings > Game > Inventory Sort. The Options menu edits and saves the
// default object, so the extension reads the current value from there.
UCLASS(Config=GameUserSettings)
class UInventorySortSettings : UGothicModExt_UserSettings
{
    default CategoryName = FText::FromString("Inventory Sort");

    UPROPERTY(Config)
    FModUserSettingsBool Enabled = FModUserSettingsBool(
        Value = true,
        DefaultValue = true,
        DisplayText = FText::FromString("Sort the inventory by type, then by value"));
}

UCLASS(Abstract)
class UInventorySortBase : UGothicModExt_WidgetExtension
{
    // How often the open inventory is checked, in seconds.
    const float32 CheckInterval = 0.2f;

    // Item types in the order of the game's inventory tabs and of the types
    // listed inside each tab. An item goes to the first type it matches.
    TArray<FGameplayTag> TypeOrder;

    // Place in TypeOrder per item kind, so the tag checks run once per kind.
    TMap<TSubclassOf<UItemDefinition>, int> GroupByKind;

    float32 SinceCheck = 1.0f;

    UFUNCTION(BlueprintOverride)
    bool RequiresTick() const
    {
        return true;
    }

    UFUNCTION(BlueprintOverride)
    void Tick(FGeometry MyGeometry, float32 InDeltaTime)
    {
        SinceCheck += InDeltaTime;
        if (SinceCheck < CheckInterval)
            return;
        SinceCheck = 0.0f;

        if (!UInventorySortSettings.DefaultObject.Enabled.bValue)
            return;

        auto Inventory = Cast<UInventoryMain>(GetWidget());
        if (!IsValid(Inventory) || !Inventory.IsVisible())
            return;

        // Only the hero's own inventory screen. Trade, loot and crafting lists
        // show the same items but keep their own positions while open.
        EInventoryOpenedStates State = Inventory.GetInventoryOpenedState();
        if (State == EInventoryOpenedStates::Looting
            || State == EInventoryOpenedStates::TradingInventoryPlayer
            || State == EInventoryOpenedStates::TradingInventoryTrader
            || State == EInventoryOpenedStates::Crafting)
            return;
        // Picking a ring or armor slot works with item positions too.
        if (Inventory.IsWearableEquipmentMode())
            return;

        UDataModule_Container Container = DataModule::GetContainerDataModule(Gameplay::GetPlayerCharacter(0));
        if (!IsValid(Container))
            return;

        if (SortBackpack(Container))
            Inventory.RefreshInventory(true);
    }

    UFUNCTION(BlueprintOverride)
    void Destruct()
    {
        GroupByKind.Empty();
    }

    // Reorders the backpack list when it is not sorted. Returns true when it
    // changed anything. Empty entries (left when a stack is used up) do not
    // count as unsorted and go to the end when the list is reordered.
    bool SortBackpack(UDataModule_Container Container)
    {
        TArray<FItemVirtualData>& Items = Container.GetItemsIn(EInventoryTypes::MainContainer);
        int Count = Items.Num();
        if (Count < 2)
            return false;

        if (TypeOrder.Num() == 0)
            BuildTypeOrder();

        const int EmptyGroup = 1000000;
        TArray<int> Group;
        TArray<int> Value;
        // First place of the same kind in the current list, so stacks of one
        // kind stay together and keep their relative order.
        TArray<int> KindPlace;
        TArray<bool> Filled;
        TMap<TSubclassOf<UItemDefinition>, int> FirstPlace;

        for (int I = 0; I < Count; ++I)
        {
            TSubclassOf<UItemDefinition> Kind = Items[I].m_SlotData.m_ItemDefinition;
            bool bFilled = Kind.IsValid() && Items[I].m_SlotData.m_ItemCount > 0;
            Filled.Add(bFilled);
            if (!bFilled)
            {
                Group.Add(EmptyGroup);
                Value.Add(0);
                KindPlace.Add(I);
                continue;
            }
            UItemDefinition Item = Kind.GetDefaultObject();
            Group.Add(GroupOf(Kind, Item));
            Value.Add(IsValid(Item) ? Item.m_Value : 0);
            int Place = I;
            if (!FirstPlace.Find(Kind, Place))
            {
                Place = I;
                FirstPlace.Add(Kind, I);
            }
            KindPlace.Add(Place);
        }

        // Insertion sort: stable, and close to one pass when the list is
        // already sorted except for a few new items at the end.
        TArray<int> Order;
        for (int I = 0; I < Count; ++I)
        {
            int J = Order.Num();
            while (J > 0 && Comes(I, Order[J - 1], Group, Value, KindPlace))
                --J;
            Order.Insert(I, J);
        }

        // Sorted already, apart from where the empty entries sit?
        bool bSorted = true;
        int Previous = -1;
        for (int I = 0; I < Count && bSorted; ++I)
        {
            int Index = Order[I];
            if (!Filled[Index])
                continue;
            if (Index < Previous)
                bSorted = false;
            Previous = Index;
        }
        if (bSorted)
            return false;

        TArray<FItemVirtualData> Before = Items;
        for (int I = 0; I < Count; ++I)
        {
            Items[I] = Before[Order[I]];
            Items[I].m_Id = I;
        }
        return true;
    }

    // True when entry A belongs before entry B.
    bool Comes(int A, int B, const TArray<int>& Group, const TArray<int>& Value, const TArray<int>& KindPlace) const
    {
        if (Group[A] != Group[B])
            return Group[A] < Group[B];
        if (Value[A] != Value[B])
            return Value[A] > Value[B];
        if (KindPlace[A] != KindPlace[B])
            return KindPlace[A] < KindPlace[B];
        return A < B;
    }

    int GroupOf(TSubclassOf<UItemDefinition> Kind, UItemDefinition Item)
    {
        int Group = 0;
        if (GroupByKind.Find(Kind, Group))
            return Group;
        // Types the game's tabs do not list go after all the others.
        Group = TypeOrder.Num();
        if (IsValid(Item))
        {
            for (int I = 0; I < TypeOrder.Num(); ++I)
            {
                if (Item.MatchesItemType(TypeOrder[I]) || Item.HasItemSpec(TypeOrder[I]))
                {
                    Group = I;
                    break;
                }
            }
        }
        GroupByKind.Add(Kind, Group);
        return Group;
    }

    // Same tabs and types as the game's UI/InventoryFilters.as, in its order.
    void BuildTypeOrder()
    {
        TypeOrder.Empty();
        // Melee
        TypeOrder.Add(GameplayTag::Item_Weapon_Sword_OneHand);
        TypeOrder.Add(GameplayTag::Item_Weapon_Sword_TwoHand);
        TypeOrder.Add(GameplayTag::Item_Weapon_Mace_OneHand);
        TypeOrder.Add(GameplayTag::Item_Weapon_Orc_TwoHand);
        TypeOrder.Add(GameplayTag::Item_Weapon_Axe_OneHand);
        TypeOrder.Add(GameplayTag::Item_Weapon_Axe_TwoHand);
        TypeOrder.Add(GameplayTag::Item_Weapon_Staff_TwoHand);
        TypeOrder.Add(GameplayTag::Item_Weapon_Fist);
        // Ranged
        TypeOrder.Add(GameplayTag::Item_Weapon_Bow);
        TypeOrder.Add(GameplayTag::Item_Weapon_Crossbow);
        TypeOrder.Add(GameplayTag::Item_Ammo);
        TypeOrder.Add(GameplayTag::Item_Projectile_Arrow);
        TypeOrder.Add(GameplayTag::Item_Projectile_Bolt);
        // Magic
        TypeOrder.Add(GameplayTag::Item_Weapon_Rune);
        TypeOrder.Add(GameplayTag::Item_Weapon_Scroll);
        // Wearables
        TypeOrder.Add(GameplayTag::Item_Armor);
        TypeOrder.Add(GameplayTag::Item_Ring);
        TypeOrder.Add(GameplayTag::Item_Amulet);
        // Food
        TypeOrder.Add(GameplayTag::Item_Food);
        TypeOrder.Add(GameplayTag::Item_Herb);
        TypeOrder.Add(GameplayTag::Item_Drug);
        // Potions
        TypeOrder.Add(GameplayTag::Item_Potion);
        // Materials
        TypeOrder.Add(GameplayTag::Item_Ore);
        TypeOrder.Add(GameplayTag::Item_Material);
        TypeOrder.Add(GameplayTag::Item_Trophy);
        TypeOrder.Add(GameplayTag::Item_Property_Forge);
        TypeOrder.Add(GameplayTag::Item_Recipe);
        // Documents
        TypeOrder.Add(GameplayTag::Item_Writing);
        // Miscellaneous
        TypeOrder.Add(GameplayTag::Item_Junk);
        TypeOrder.Add(GameplayTag::Item_Instrument);
        TypeOrder.Add(GameplayTag::Item_Lockpick);
        TypeOrder.Add(GameplayTag::Item_Weapon_Torch);
        // Artefacts
        TypeOrder.Add(GameplayTag::Item_Quest);
        TypeOrder.Add(GameplayTag::Item_Key);
        GroupByKind.Empty();
    }
}

class UInventorySortInventory : UInventorySortBase
{
    default AddToWidgetOfClass = n"/Game/UI/ManagementUI/Inventory/W_Inventory_Main.W_Inventory_Main_C";
}
