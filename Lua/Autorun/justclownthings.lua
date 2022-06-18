-- JustClownThings v1-SNAPSHOT
-- by MassCraxx

-- CONFIG
local DEBUG = true
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

-- these items will be dropped as clown. Key is InventorySlot index, value is the item id
local ForbiddenItems = {}
ForbiddenItems[4] = {"divingsuit","combatdivingsuit","abyssdivingsuit","slipsuit","pucs"}

-- if true, will drop items that are moved to active fabricator to the ground before reequipping them to stop the craft
local CancelFabricator = true

-- EXPERIMENTAL: this takes more performance, but could potentially prevent attached items from moving in the first place
local ValidMoveHandling = false 


-- a list of all slots that can contain configured clown items
local validSlots = {}
for _, item in pairs(clownItems) do
    validSlots[item.InventorySlot] = true
end

JustClownThings = {}
JustClownThings.Clowns = {}
JustClownThings.EquippedClownItems = {}
JustClownThings.DropItems = {}

-- type: 6 = Server message, 7 = Console usage, 9 error
JustClownThings.Log = function (message)
    if DEBUG then
        Game.Log("[JustClownThings] " .. message, 6)
    end
end

JustClownThings.FindClientCharacter = function (character)
    for key, value in pairs(Client.ClientList) do
        if character == value.Character then return value end
    end

    return nil
end

JustClownThings.DropItem = function (item, character)
    if item == nil or character == nil then return end
    JustClownThings.Log(character.Name .. " dropped forbidden item ".. item.Name, 6)
    item.Drop(character)
end

Hook.Add("roundStart", "JustClownThings.RoundStart", function ()
    JustClownThings.Clowns = {}
    JustClownThings.EquippedClownItems = {}
    JustClownThings.DropItems = {}
end)

Hook.Add("inventoryPutItem", "JustClownThings.inventoryPutItem", function (inventory, item, character, slot, removeItem)
    if character ~= nil and (character.IsBot or not character.IsHuman or character.IsDead) then return nil end

    local clownItem = clownItems[item.Prefab.Identifier.Value]
    if clownItem then
        if character and validSlots[slot] and inventory == character.Inventory then
            -- clown item equipped
            if character.IsAssistant then
                if not JustClownThings.EquippedClownItems[character] then 
                    JustClownThings.EquippedClownItems[character] = {}
                end
                JustClownThings.EquippedClownItems[character][slot] = item 
            else
                -- non-assistants drop
                JustClownThings.DropItems[item] = character
            end
        elseif ValidMoveHandling then 
            for user, entry in pairs(JustClownThings.EquippedClownItems) do
                for oldSlot, equippedItem in pairs(entry) do
                    if equippedItem.ID == item.ID then
                        if DEBUG then
                            character = user
                            JustClownThings.Log("Clown " .. character.Name .. " unequipped clown item " .. item.Name)
                        end
                        return false
                    end
                end
                
            end
        end
    end

    return nil
end)

Hook.Add("think", "JustClownThings.think", function ()
    if Game.RoundStarted and #Client.ClientList > 0 then
        if CheckTime and Timer.GetTime() > CheckTime then
            CheckTime = Timer.GetTime() + CheckDelay

            -- check clowns for reequip
            for character, entry in pairs(JustClownThings.EquippedClownItems) do
                for slot, item in pairs(entry) do
                    if not item.Removed then
                        if item.ParentInventory == nil or item.ParentInventory ~= character.Inventory or item.ParentInventory.FindIndex(item) ~= slot then
                            -- if item is not equipped anymore
                            JustClownThings.Log("Reequipping clown item to clown "..character.Name)
                            if CancelFabricator and item.ParentInventory and item.ParentInventory.Locked then
                                -- if item is in an active/locked fabricator, drop it before re-equip to stop the craft
                                JustClownThings.DropItems[item] = character
                            else
                                -- otherwise reequip
                                character.Inventory.TryPutItem(item, slot, true, false, character, true, true)
                            end
                        elseif not JustClownThings.Clowns[character] then
                            -- if its the first clown item equipped inform user
                            JustClownThings.Clowns[character] = true

                            local client = JustClownThings.FindClientCharacter(character)
                            if client then
                                Game.SendDirectChatMessage("", "PRAISE THE HONKMOTHER!", nil, ChatMessageType.Error, client)
                            end
                            JustClownThings.Log(character.Name .. " equipped a clown item " .. item.Name .. " and is now a clown.")
                        end
                    end
                end

                -- check forbidden items for this clown
                for slot, identifiers in pairs(ForbiddenItems) do
                    local wornItem = character.Inventory.GetItemAt(slot)
                    for identifier in identifiers do
                        if wornItem and wornItem.Prefab.Identifier == identifier then
                            JustClownThings.DropItems[wornItem] = character
                            break
                        end
                    end
                end
            end
        
            -- drop all items marked for drop
            for item, character in pairs(JustClownThings.DropItems) do
                JustClownThings.Log("Dropping forbidden item " .. item.Name .. " for" .. character.Name)
                JustClownThings.DropItem(item, character)
            end
            JustClownThings.DropItems = {}
        end
    end
end)