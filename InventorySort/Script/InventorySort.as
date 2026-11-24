// Inventory Sort: sorts the hero's inventory by item type, then strength,
// then name, in the inventory screen and in the sell list of the trade screen.
//
// The inventory screen shows backpack items newest first: it orders them by
// the time each item was last added (checked against a save: the inventory
// screen matched that order item for item). Item positions in the game's own
// list do not change that view. So this mod gives every backpack item a
// made-up "last added" time that puts it in the wanted place: the first item
// gets the latest time. Use, equip and drop keep working, because the game
// itself builds the list it shows. A newly picked-up item gets the current
// time and shows at the top until the open inventory is sorted again (a few
// times per second).
//
// The trade screen's sell list ignores those times: after the hotbar it shows
// the backpack items in the order of the game's backpack list (checked against
// a save and a screenshot). The trade screen copies that list when it opens
// and again after each trade, and a sale takes the item from the place the
// copy gives it. Moving the list while the screen is open makes the game take
// a different item than the one clicked (version 0.3.0 did that, checked
// against saves). So the mod moves the items themselves into the sorted places
// of the list only during a conversation, before the trade screen opens, and
// never while a trade screen is shown.
//
// Equipped items and the hotbar live in their own lists and are not touched.

// Shared between the extensions: the frame in which a trade screen last ticked.
class UInventorySortState : UObject
{
    int64 LastTradeFrame = -1000;
}

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
        DisplayText = FText::FromString("Sort the inventory by type, strength and name"));
}

UCLASS(Abstract)
class UInventorySortBase : UGothicModExt_WidgetExtension
{
    // Item types in the order of the game's inventory tabs and of the types
    // listed inside each tab. An item goes to the first type it matches.
    TArray<FGameplayTag> TypeOrder;

    // Per item kind, so the checks run once per kind.
    TMap<TSubclassOf<UItemDefinition>, int> GroupByKind;
    TMap<TSubclassOf<UItemDefinition>, float32> StrengthByKind;

    // Every item kind seen so far, sorted by lower-case name, and each kind's
    // place in that order.
    TArray<FString> SortedNames;
    TArray<TSubclassOf<UItemDefinition>> SortedKinds;
    TMap<TSubclassOf<UItemDefinition>, int> NameRank;

    UFUNCTION(BlueprintOverride)
    bool RequiresTick() const
    {
        return true;
    }

    // Sorts the backpack: sets the "last added" times of its items (the order
    // of the inventory screen) and, with bMoveEntries, also moves the items
    // into the sorted places of the backpack list (the order of the trade
    // screen). Returns true when it changed anything.
    bool SortBackpack(UDataModule_Container Container, bool bMoveEntries)
    {
        TArray<FItemVirtualData>& Items = Container.GetItemsIn(EInventoryTypes::MainContainer);
        int Count = Items.Num();
        if (Count < 1)
            return false;

        if (TypeOrder.Num() == 0)
            BuildTypeOrder();

        // Entries with an item; empty ones (left when a stack is used up) are
        // not shown and keep their time.
        TArray<int> Entries;
        for (int I = 0; I < Count; ++I)
        {
            TSubclassOf<UItemDefinition> Kind = Items[I].m_SlotData.m_ItemDefinition;
            if (Kind.IsValid() && Items[I].m_SlotData.m_ItemCount > 0)
                Entries.Add(I);
        }
        if (Entries.Num() == 0)
            return false;

        // Register new kinds first: adding a name moves the ranks of others.
        for (int Entry : Entries)
            RegisterName(Items[Entry].m_SlotData.m_ItemDefinition);

        TArray<int> Group;
        TArray<float32> Strength;
        TArray<int> Rank;
        // First place of the same kind in the list, so stacks of one kind stay
        // together even when another kind has the same name.
        TArray<int> KindPlace;
        TMap<TSubclassOf<UItemDefinition>, int> FirstPlace;
        for (int K = 0; K < Entries.Num(); ++K)
        {
            TSubclassOf<UItemDefinition> Kind = Items[Entries[K]].m_SlotData.m_ItemDefinition;
            UItemDefinition Item = Kind.GetDefaultObject();
            Group.Add(GroupOf(Kind, Item));
            Strength.Add(StrengthOf(Kind, Item));
            int Place = 0;
            NameRank.Find(Kind, Place);
            Rank.Add(Place);
            Place = K;
            if (!FirstPlace.Find(Kind, Place))
            {
                Place = K;
                FirstPlace.Add(Kind, K);
            }
            KindPlace.Add(Place);
        }

        // Wanted order (indexes into Entries). Insertion sort: stable, and
        // close to one pass when only a few items are out of place.
        TArray<int> Order;
        for (int K = 0; K < Entries.Num(); ++K)
        {
            int J = Order.Num();
            while (J > 0 && Comes(K, Order[J - 1], Group, Strength, Rank, KindPlace))
                --J;
            Order.Insert(K, J);
        }

        // List place of each item, in the wanted order.
        TArray<int> Wanted;
        for (int K = 0; K < Order.Num(); ++K)
            Wanted.Add(Entries[Order[K]]);

        bool bChanged = false;
        if (bMoveEntries && MoveEntries(Items, Entries, Group, Wanted))
            bChanged = true;

        // Already in this order by time? Times must fall strictly along it.
        bool bSorted = true;
        for (int K = 1; K < Wanted.Num() && bSorted; ++K)
        {
            float Earlier = Items[Wanted[K - 1]].m_TimeLastAdded.TotalSeconds;
            float Later = Items[Wanted[K]].m_TimeLastAdded.TotalSeconds;
            if (Later >= Earlier)
                bSorted = false;
        }
        if (bSorted)
            return bChanged;

        // First item gets the latest time. Small values (seconds after the
        // start of the game) keep every item older than anything picked up
        // later, and they stay the same on every sort.
        int Total = Wanted.Num();
        for (int K = 0; K < Total; ++K)
            Items[Wanted[K]].m_TimeLastAdded = FInGameTime::FromSeconds(float(Total - K));
        return true;
    }

    // Moves the items of the tab types into the sorted order within the list
    // places those items already hold. Empty entries and items of types the
    // tabs do not list keep their place. Every item keeps its id equal to its
    // place in the list, as the game keeps it. Wanted (list places in the
    // wanted order) is updated to the new places. Returns true when it moved
    // anything.
    bool MoveEntries(TArray<FItemVirtualData>& Items, const TArray<int>& Entries,
                     const TArray<int>& Group, TArray<int>& Wanted)
    {
        // List places of the tab-type items, in list order. Types the tabs do
        // not list sort last, so these items are the first ones in Wanted.
        TArray<int> Spots;
        for (int K = 0; K < Entries.Num(); ++K)
        {
            if (Group[K] < TypeOrder.Num())
                Spots.Add(Entries[K]);
        }

        bool bInPlace = true;
        for (int K = 0; K < Spots.Num(); ++K)
        {
            if (Wanted[K] != Spots[K])
            {
                bInPlace = false;
                break;
            }
        }
        if (bInPlace)
            return false;

        TArray<FItemVirtualData> Before = Items;
        for (int K = 0; K < Spots.Num(); ++K)
        {
            Items[Spots[K]] = Before[Wanted[K]];
            Items[Spots[K]].m_Id = Spots[K];
            Wanted[K] = Spots[K];
        }
        return true;
    }

    // True when entry A belongs before entry B: type, then strength (highest
    // first), then name, then kind and list position.
    bool Comes(int A, int B, const TArray<int>& Group, const TArray<float32>& Strength,
               const TArray<int>& Rank, const TArray<int>& KindPlace) const
    {
        if (Group[A] != Group[B])
            return Group[A] < Group[B];
        if (Strength[A] != Strength[B])
            return Strength[A] > Strength[B];
        if (Rank[A] != Rank[B])
            return Rank[A] < Rank[B];
        if (KindPlace[A] != KindPlace[B])
            return KindPlace[A] < KindPlace[B];
        return A < B;
    }

    int GroupOf(TSubclassOf<UItemDefinition> Kind, UItemDefinition Item)
    {
        int Found = 0;
        if (GroupByKind.Find(Kind, Found))
            return Found;
        // Types the game's tabs do not list go after all the others.
        Found = TypeOrder.Num();
        if (IsValid(Item))
        {
            for (int I = 0; I < TypeOrder.Num(); ++I)
            {
                if (Item.MatchesItemType(TypeOrder[I]) || Item.HasItemSpec(TypeOrder[I]))
                {
                    Found = I;
                    break;
                }
            }
        }
        GroupByKind.Add(Kind, Found);
        return Found;
    }

    // Weapons: sum of base damage over all damage types. Armor: sum of all
    // protections. Everything else: 0, so it goes by name.
    float32 StrengthOf(TSubclassOf<UItemDefinition> Kind, UItemDefinition Item)
    {
        float32 Found = 0.0f;
        if (StrengthByKind.Find(Kind, Found))
            return Found;
        Found = 0.0f;
        auto Weapon = Cast<UWeaponDefinition>(Item);
        if (IsValid(Weapon))
        {
            for (auto DamageEntry : Weapon.m_DamageBase)
                Found += DamageEntry.Value;
        }
        auto Armor = Cast<UArmorDefinition>(Item);
        if (IsValid(Armor))
        {
            Found = float32(Armor.GetEdgeProtection() + Armor.GetBluntProtection() + Armor.GetPointProtection()
                + Armor.GetFireProtection() + Armor.GetEnergyProtection() + Armor.GetIceProtection()
                + Armor.GetWindProtection());
        }
        StrengthByKind.Add(Kind, Found);
        return Found;
    }

    // Adds a kind to the name order if it is new, and renumbers the ranks.
    void RegisterName(TSubclassOf<UItemDefinition> Kind)
    {
        int Existing = 0;
        if (NameRank.Find(Kind, Existing))
            return;
        UItemDefinition Item = Kind.GetDefaultObject();
        FString ItemName = "";
        if (IsValid(Item))
            ItemName = Item.m_Name.ToString().ToLower();
        int At = SortedNames.Num();
        for (int I = 0; I < SortedNames.Num(); ++I)
        {
            if (CompareNames(ItemName, SortedNames[I]) < 0)
            {
                At = I;
                break;
            }
        }
        SortedNames.Insert(ItemName, At);
        SortedKinds.Insert(Kind, At);
        NameRank.Empty();
        for (int I = 0; I < SortedKinds.Num(); ++I)
            NameRank.Add(SortedKinds[I], I);
    }

    // Negative when A sorts before B, by character codes of lower-case names.
    int CompareNames(const FString& A, const FString& B) const
    {
        int LenA = A.Len();
        int LenB = B.Len();
        int Shorter = LenA < LenB ? LenA : LenB;
        for (int I = 0; I < Shorter; ++I)
        {
            int CharA = String::GetCharacterAsNumber(A, I);
            int CharB = String::GetCharacterAsNumber(B, I);
            if (CharA != CharB)
                return CharA - CharB;
        }
        return LenA - LenB;
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

// The hero's inventory screen.
class UInventorySortInventory : UInventorySortBase
{
    default AddToWidgetOfClass = n"/Game/UI/ManagementUI/Inventory/W_Inventory_Main.W_Inventory_Main_C";

    // How often the open inventory is checked, in seconds.
    const float32 CheckInterval = 0.2f;

    float32 SinceCheck = 1.0f;

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

        // Only the hero's own inventory screen. The trade screen's lists are
        // this widget too, and show the list order that
        // UInventorySortConversation sorts. Loot and crafting lists show the
        // same items, but keep them still while those screens are open.
        EInventoryOpenedStates State = Inventory.GetInventoryOpenedState();
        if (State == EInventoryOpenedStates::Looting
            || State == EInventoryOpenedStates::TradingInventoryPlayer
            || State == EInventoryOpenedStates::TradingInventoryTrader
            || State == EInventoryOpenedStates::Crafting)
            return;
        // Picking a ring or armor slot works with item positions in the view.
        if (Inventory.IsWearableEquipmentMode())
            return;

        UDataModule_Container Container = DataModule::GetContainerDataModule(Gameplay::GetPlayerCharacter(0));
        if (!IsValid(Container))
            return;

        if (SortBackpack(Container, false))
            Inventory.RefreshInventory(true);
    }
}

// The conversation screen: moves the backpack items into their sorted places
// in the list, so a trade screen opened from the conversation copies a sorted
// list and its sell list shows the sorted order. Trading is only started from
// conversations in the game's scripts.
class UInventorySortConversation : UInventorySortBase
{
    default AddToWidgetOfClass = n"/Game/UI/Conversation/V2/W_ConversationMain.W_ConversationMain_C";

    // How often the open conversation is checked, in seconds.
    const float32 CheckInterval = 0.1f;

    // Frames after a trade screen last ticked in which the list stays still.
    const int64 TradeQuietFrames = 30;

    float32 SinceCheck = 1.0f;

    UFUNCTION(BlueprintOverride)
    void Tick(FGeometry MyGeometry, float32 InDeltaTime)
    {
        SinceCheck += InDeltaTime;
        if (SinceCheck < CheckInterval)
            return;
        SinceCheck = 0.0f;

        if (!UInventorySortSettings.DefaultObject.Enabled.bValue)
            return;

        UUserWidget Conversation = GetWidget();
        if (!IsValid(Conversation) || !Conversation.IsVisible())
            return;

        // A trade screen copies the list when it opens; moving the list
        // under that copy makes a sale take a different item.
        if (System::GetFrameCount() - UInventorySortState.DefaultObject.LastTradeFrame < TradeQuietFrames)
            return;

        auto Hero = Cast<AGothicCharacter>(Gameplay::GetPlayerCharacter(0));
        if (!IsValid(Hero) || !Hero.IsInConversation())
            return;

        UDataModule_Container Container = DataModule::GetContainerDataModule(Hero);
        if (!IsValid(Container))
            return;

        SortBackpack(Container, true);
    }
}

// The trade screen: does not sort, only tells the conversation screen to keep
// the list still while a trade screen is shown.
class UInventorySortTrading : UGothicModExt_WidgetExtension
{
    default AddToWidgetOfClass = n"/Game/UI/TradingNew/W_Trading_Main.W_Trading_Main_C";

    UFUNCTION(BlueprintOverride)
    bool RequiresTick() const
    {
        return true;
    }

    UFUNCTION(BlueprintOverride)
    void Construct()
    {
        MarkTradeShown();
    }

    UFUNCTION(BlueprintOverride)
    void Tick(FGeometry MyGeometry, float32 InDeltaTime)
    {
        MarkTradeShown();
    }

    void MarkTradeShown()
    {
        auto State = UInventorySortState.DefaultObject;
        State.LastTradeFrame = System::GetFrameCount();
    }
}
