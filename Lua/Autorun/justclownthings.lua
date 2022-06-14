-- JustClownThings v1-SNAPSHOT
-- by MassCraxx

-- CONFIG
local DEBUG = true
local ValidMoveHandling = true -- if this code would work as expected, this could prevent item movement from happening in the first place
local CheckDelay = 3
local CheckTime = -1

local clownItems = {
    clowncostume = {
        InventorySlot = 3,
    },
    clownmask = {
        InventorySlot = 2,
    },
    clowndivingmask = {
        InventorySlot = 2,
    }
}

--TODO: add all diving suits
local ForbiddenItems = {"divingsuit"}



-- a list of all slots that can contain configured clown items
local validSlots = {}
for _, item in pairs(clownItems) do
    validSlots[item.InventorySlot] = true
end

local clowns = {}
local equippedClownItems = {}
local dropItems = {}

-- type: 6 = Server message, 7 = Console usage, 9 error
Log = function (message)
    if DEBUG then
        Game.Log("[JustClownThings] " .. message, 6)
    end
end

FindClientCharacter = function (character)
    for key, value in pairs(Client.ClientList) do
        if character == value.Character then return value end
    end

    return nil
end

DropItem = function (item, character)
    if item == nil or character == nil then return end
    Log(character.Name .. " dropped forbidden item ".. item.Name, 6)
    item.Drop(character)
end

Hook.Add("roundStart", "JustClownThings.RoundStart", function ()
    clowns = {}
    equippedClownItems = {}
    dropItems = {}
end)

Hook.Add("inventoryPutItem", "JustClownThings.inventoryPutItem", function (inventory, item, character, slot, removeItem)
    if character ~= nil and (character.IsBot or not character.IsHuman or character.IsDead) then return nil end

    local identifier = tostring(item.Prefab.Identifier)
    local clownItem = clownItems[identifier]
    print(clownItem)
    if clownItem then
        if character and validSlots[slot] and inventory == character.Inventory then
            -- clown item equipped
            if character.IsAssistant then
                equippedClownItems[slot] = {}
                equippedClownItems[slot].Item = item 
                equippedClownItems[slot].Character = character
            else
                -- non-assistants drop
                dropItems[item] = character
            end
        elseif ValidMoveHandling and equippedClownItems[clownItem.InventorySlot] and equippedClownItems[clownItem.InventorySlot].Item.ID == item.ID then
            print("bla")
            -- equipped item has been moved
            --local character = equippedClownItems[clownItem.InventorySlot].Character
            --print("inventoryPutItem: "..tostring(inventory) .. " item: " .. tostring(item) .. " character: ".. equippedClownItems[clownItem.InventorySlot].Character.Name .. " slot: " .. slot .. " remove: " .. tostring(removeItem))
            if DEBUG then
                character = equippedClownItems[clownItem.InventorySlot].Character
                Log("Clown " .. character.Name .. " unequipped clown item " .. item.Name)
            end
            return false
        end
    elseif clowns[character] then
        -- clowns drop forbiddenItems
        for forbiddenItem in ForbiddenItems do
            if identifier == forbiddenItem then
                dropItems[item] = character
            end
        end
    end

    return nil
end)

Hook.Add("think", "JustClownThings.think", function ()
    if Game.RoundStarted and #Client.ClientList > 0 then
        if CheckTime and Timer.GetTime() > CheckTime then
            CheckTime = Timer.GetTime() + CheckDelay

            -- drop all items marked for drop
            for item, character in pairs(dropItems) do
                Log("Dropping forbidden item " .. item.Name .. " for" .. character.Name)
                DropItem(item, character)
            end
            dropItems = {}

            -- check for reequip
            for slot, entry in pairs(equippedClownItems) do
                local item = entry.Item
                local character = entry.Character

                if not item.Removed then
                    -- if item is not equipped anymore
                    if item.ParentInventory == nil or item.ParentInventory ~= character.Inventory or item.ParentInventory.FindIndex(item) ~= slot then
                        character.Inventory.TryPutItem(item, slot, true, false, character, true, true)
                        Log("Reequipping clown item to clown "..character.Name)
                    elseif not clowns[character] then
                        -- if its the first item ever equipped inform user
                        clowns[character] = true

                        local client = FindClientCharacter(character)
                        if client then
                            Game.SendDirectChatMessage("", "PRAISE THE HONKMOTHER!", nil, ChatMessageType.Error, client)
                        end
                        Log(character.Name .. " equipped a clown item " .. item.Name .. " and is now a clown.")
                    end
                end
            end
        end
    end
end)