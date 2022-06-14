-- JustClownThings v1-SNAPSHOT
-- by MassCraxx

-- CONFIG
local checkDelay = 3
local checkTime = -1

local clownItems = {
    clowncostume = {
        InventorySlot = 3,
        LimbSlot = InvSlotType.InnerClothes,
    },
    clownmask = {
        InventorySlot = 2,
        LimbSlot = InvSlotType.Head,
    },
    clowndivingmask = {
        InventorySlot = 2,
        LimbSlot = InvSlotType.Head,
    }

    --TODO: add all diving suits
    --TODO: sticky for all clown items
}

local forbiddenItems = {"divingsuit"}

local clowns = {}
local equippedClownItems = {}

-- type: 6 = Server message, 7 = Console usage, 9 error
Log = function (message)
    Game.Log("[JustClownThings] " .. message, 6)
end

LimbToInventorySlot = function(limbSlot)
    if limbSlot == InvSlotType.Head then
        return 2
    elseif limbSlot == InvSlotType.InnerClothes then
        return 3
    elseif limbSlot == InvSlotType.OuterClothes then
        return 4
    elseif limbSlot == InvSlotType.LeftHand then
        return 5
    elseif limbSlot == InvSlotType.RightHand then
        return 6
    end
end

WearsAnyItem = function (character, itemIds)
    local head = character.Inventory.GetItemInLimbSlot(InvSlotType.Head)
    local inner = character.Inventory.GetItemInLimbSlot(InvSlotType.InnerClothes)
    local outer = character.Inventory.GetItemInLimbSlot(InvSlotType.OuterClothes)

    for _, itemId in pairs(itemIds) do
        if (head and head.Prefab.Identifier == itemId) or
        (inner and inner.Prefab.Identifier == itemId) or
        (outer and outer.Prefab.Identifier == itemId) then
            return true
        end
    end

    return false
end

DropItem = function (item, character)
    if item == nil or character == nil then return end
    Log(character.Name .. " dropped forbidden item ".. item.Name, 6)
    item.Drop(character)
end

--FindClientCharacter = function (character)
--    for key, value in pairs(Client.ClientList) do
--        if character == value.Character then return value end
--    end
--
--    return nil
--end

Hook.Add("roundStart", "JustClownThings.RoundStart", function ()
    --stickyItems = {}
    clowns = {}
    equippedClownItems = {}
end)

Hook.Add("item.drop", "JustClownThings.item.drop", function (item)
    --print("drop" .. tostring(item))
    --if equippedClownItems[item.ID] then
    --    local character = equippedClownItems[item.ID]
    --    -- clown has unequipped a clownitem -> put back on
    --    print("unequipped")
    --    --character.Inventory.TryPutItem(item, equippedClownItems[item.ID], {clownItem.LimbSlot}, true, true)
    --    Timer.Wait(function ()
    --        local clownItem = clownItems[tostring(item.Prefab.Identifier)]
    --        local wornItem = character.Inventory.GetItemInLimbSlot(clownItem.LimbSlot)
    --        -- if clown did not put on another clown item -> swap
    --        if wornItem == nil or not clownItems[wornItem.Prefab.Identifier] then
    --            character.Inventory.TryPutItem(item, equippedClownItems[item.ID], {clownItem.LimbSlot}, true, true)
    --        end
    --    end, 500)
    --    return false
    --end

    return false
end)

Hook.Add("item.combine", "JustClownThings.item.drop", function (item, item2,user)
    print("combine" .. tostring(item) .. tostring(item2))

    return false
end)


Hook.Add("inventoryPutItem", "JustClownThings.inventoryPutItem", function (inventory, item, character, slot, removeItem)
    if character ~= nil and (character.IsBot or not character.IsHuman or character.IsDead) then return nil end

    local clownItem = clownItems[tostring(item.Prefab.Identifier)]
    if clownItem then
        print(tostring(equippedClownItems[item.ID]) .. " " .. slot)
        print(inventory)
        if character and (slot == 2 or slot == 3) then
            -- player has equipped a clownitem
            if not equippedClownItems[item.ID] and character.HasJob("assistant") then
                -- assistant is clown now
                if not clowns[character] then
                    clowns[character] = {}
                    print("player is clown")
                end
                
                equippedClownItems[item.ID] = character
                
            else 
                -- non-assistant -> drop
                DropItem(item, character)
                return false
            end
        elseif equippedClownItems[item.ID] then
            -- clown has unequipped a clownitem -> put back on
            print("unequipped")
            --character.Inventory.TryPutItem(item, equippedClownItems[item.ID], {clownItem.LimbSlot}, true, true)
            Timer.Wait(function ()
                local character = equippedClownItems[item.ID]
                local wornItem = character.Inventory.GetItemInLimbSlot(clownItem.LimbSlot)
                -- if clown did not put on another clown item -> swap
                if character and (wornItem == nil or not clownItems[wornItem.Prefab.Identifier]) then
                    character.Inventory.TryPutItem(item, equippedClownItems[item.ID], {clownItem.LimbSlot}, true, true)
                end
            end, 500)
            print("false")
            return false
        end
    elseif clowns[character] then
        -- clown has equipped forbiddenItem
        for forbiddenItem in forbiddenItems do
            if forbiddenItem == item.Prefab.Identifier then
                DropItem(item, character)
                return false
            end
        end
    end

    return nil
end)