-- JustClownThings v4
-- by MassCraxx

-- CONFIG
local DEBUG = true
local CheckDelaySeconds = 2

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
ForbiddenItems[2] = {"divingmask"}
ForbiddenItems[4] = {"divingsuit","combatdivingsuit","abyssdivingsuit","slipsuit","pucs"}

-- these talents can not be picked
local ForbiddenTalents = {"slapstickexpert"}

-- if true, will drop items that are moved to active fabricator to the ground before reequipping them to stop the craft
local CancelFabricator = false

-- if true, attempt to attach a clown diving mask if a clown mask is removed from the game
local ForceAttachCraftedMask = true

-- if not nil, true clowns (that used !clown) will be moved into this team
local ClownTeam = CharacterTeamType.Team2

local checkTime = -1
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

JustClownThings.Fabricators = {}
JustClownThings.GetFabricators = function()
    if #JustClownThings.Fabricators > 0 then
        return JustClownThings.Fabricators
    elseif Game.RoundStarted and #JustClownThings.Fabricators == 0 then
        for item in Submarine.MainSub.GetItems(false) do
            local isFabricator = item.GetComponentString("Fabricator")
            if isFabricator ~= nil and item.Prefab.Identifier == "fabricator" then
                table.insert(JustClownThings.Fabricators, isFabricator)
            end
        end
    end

    return JustClownThings.Fabricators
end

Hook.Add("roundStart", "JustClownThings.RoundStart", function ()
    JustClownThings.Clowns = {}
    JustClownThings.EquippedClownItems = {}
    JustClownThings.DropItems = {}
    JustClownThings.Fabricators = {}
end)

if #ForbiddenTalents > 0 then
    Hook.Add("character.updateTalent", "JustClownThings.updateTalent", function(character, talent)
        for forbiddenTalent in ForbiddenTalents do
            if talent.Identifier == forbiddenTalent then
                local client = JustClownThings.FindClientCharacter(character)
                if client then
                    Game.SendDirectChatMessage("", "The picked talent '".. talent.Name .."' is forbidden and will have no effect.", nil, ChatMessageType.Error, client)
                end
                return true
            end
        end
    end)
end

Hook.Add("inventoryPutItem", "JustClownThings.inventoryPutItem", function (inventory, item, character, slot, removeItem)
    if character ~= nil and (character.IsBot or not character.IsHuman or character.IsDead) then return nil end

    local clownItem = clownItems[item.Prefab.Identifier.Value]
    if clownItem then
        -- if valid character and moved slot is relevant and item is moved into characters inventory and not attached to clown already
        if character and validSlots[slot] and inventory == character.Inventory and not JustClownThings.EquippedClownItems[item] then
            if character.IsAssistant then
                -- clown item equipped (lock for further handling)
                JustClownThings.EquippedClownItems[item] = true 

                if not JustClownThings.Clowns[character] then
                    JustClownThings.Clowns[character] = {}
                else
                    -- if player was clown before, unlock previous clown item in same slot (if exists)
                    local alreadyEquippedInSlot = JustClownThings.Clowns[character][slot]
                    if alreadyEquippedInSlot then
                        JustClownThings.EquippedClownItems[alreadyEquippedInSlot] = nil
                    end
                end

                if not JustClownThings.Clowns[character][slot] then
                    -- if user had no clown item on this slot, send message
                    Timer.Wait(function ()
                        local client = JustClownThings.FindClientCharacter(character)
                        if client then
                            local message = item.Name.." is now attached to you."
                            if JustClownThings.Clowns[character][2] and JustClownThings.Clowns[character][3] then
                                message = message .. "\nType '!clown' in chat to become a true clown.\n\nA true clown may be seen hostile by the crew but is allowed to grief."
                            end

                            Game.SendDirectChatMessage("", message, nil, ChatMessageType.Error, client)
                        end
                    end, 100)
                end

                JustClownThings.Log(character.Name .. " equipped a clown item " .. item.Name)
                
                JustClownThings.Clowns[character][slot] = item
            else
                -- non-assistants drop
                JustClownThings.DropItems[item] = character
            end
        end
    end

    return nil
end)

Hook.Add("think", "JustClownThings.think", function ()
    if Game.RoundStarted and #Client.ClientList > 0 then
        if checkTime and Timer.GetTime() > checkTime then
            checkTime = Timer.GetTime() + CheckDelaySeconds

            -- check clowns for reequip
            for character, entry in pairs(JustClownThings.Clowns) do
                for slot, item in pairs(entry) do
                    if item and not item.Removed then
                        -- if itemsInventory is not clowns inventory anymore or not on equipped slot
                        if item.ParentInventory == nil or item.ParentInventory ~= character.Inventory or item.ParentInventory.FindIndex(item) ~= slot then
                            JustClownThings.Log("Reequipping clown item ".. item.Name .." to clown "..character.Name)
                            if CancelFabricator and item.ParentInventory and item.ParentInventory.Locked then
                                -- if item is in an active/locked fabricator, drop it before re-equip to stop the craft
                                JustClownThings.DropItems[item] = character
                            else
                                -- otherwise reequip
                                character.Inventory.TryPutItem(item, slot, true, false, character, true, true)
                            end
                        end
                    elseif ForceAttachCraftedMask and item and JustClownThings.EquippedClownItems[item] then
                        if item.Prefab.Identifier == "clownmask" then
                        -- clown got his clownmask deleted from game, if there is a crafted clown diving mask somewhere, attach it instead
                            local clownDivingMask = nil

                            -- check player inventory
                            for item in character.Inventory.AllItems do
                                if item.Prefab.Identifier == "clowndivingmask" then
                                    clownDivingMask = item
                                    JustClownThings.Log("Clown "..character.Name.. " acquired a clown diving mask")
                                    break
                                end
                            end
                            
                            if clownDivingMask == nil then
                                -- check fabricators for diving masks
                                local fabricators = JustClownThings.GetFabricators()
                                for fabricator in fabricators do
                                    local outputItem = fabricator.OutputContainer.Inventory.GetItemAt(0)
                                    if outputItem and outputItem.Prefab.Identifier == "clowndivingmask" then
                                        -- found crafted diving mask
                                        clownDivingMask = outputItem
                                        JustClownThings.Log("Clown "..character.Name.. " crafted a clown diving mask")
                                        break
                                    end

                                    if clownDivingMask == nil then
                                        for item in fabricator.OutputContainer.Inventory.AllItems do
                                            if item.Prefab.Identifier == "clowndivingmask" then
                                                clownDivingMask = item
                                                JustClownThings.Log("Clown "..character.Name.. " crafted a clown diving mask")
                                                break
                                            end
                                        end

                                        if clownDivingMask == nil then
                                            JustClownThings.Log("!!! Clown "..character.Name.. " is a TRICKSTER and got rid of his clown mask... !!!")
                                        end
                                    end
                                end
                            end

                            -- reattach clown diving mask or nil if none found
                            JustClownThings.Clowns[character][slot] = clownDivingMask
                        end
                        
                        -- dont check again
                        JustClownThings.EquippedClownItems[item] = nil
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
                JustClownThings.DropItem(item, character)
            end
            JustClownThings.DropItems = {}
        end
    end
end)

-- Commands hook
Hook.Add("chatMessage", "JustClownThings.ChatMessage", function (message, client)

    if message == "!clown" then
        if JustClownThings.Clowns[client.Character] then
            -- if clown is wearing a full clown costume, switch teams and notify crew
            if JustClownThings.Clowns[client.Character][2] and JustClownThings.Clowns[client.Character][3] then
                if ClownTeam then
                    client.Character.SetOriginalTeam(ClownTeam)
                    client.Character.UpdateTeam()
                end

                Game.SendDirectChatMessage("", "PRAISE THE HONKMOTHER!", nil, ChatMessageType.Error, client)
                Game.SendMessage("WATCH OUT! " .. client.Name .. " is a servant of the Honkmother and may disobey orders.", ChatMessageType.Server)
            else
                Game.SendDirectChatMessage("", "You must equip a full clown outfit to become a true clown.", nil, ChatMessageType.Error, client)
            end
        else
            Game.SendDirectChatMessage("", "You must be an assistant and wear a full clown outfit to become a true clown.", nil, ChatMessageType.Error, client)
        end

        return true
    end
end)