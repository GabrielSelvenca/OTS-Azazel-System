-- UseBackpack: the held Tool that names a weapon decides the weapon in hand. Never creates, edits or equips Tools.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local package = ReplicatedStorage:WaitForChild("Azazel")
local Settings = require(package.Config.Settings)
local WeaponConfig = require(package.Config.WeaponConfig)
local Trove = require(package.Packages.Trove)

local Inventory = require(script.Parent.Inventory)

local Backpack = {}

local WEAPON_ATTRIBUTE = "AzazelWeapon"

local entries = {}

local function log(message: string)
    if Settings.Debug.Enabled and Settings.Debug.LogInventory then
        print(`[Azazel] Backpack: {message}`)
    end
end

local function weaponNameFor(tool: Tool): string?
    local tagged = tool:GetAttribute(WEAPON_ATTRIBUTE)
    if type(tagged) == "string" and WeaponConfig.Exists(tagged) then
        return tagged
    end
    if WeaponConfig.Exists(tool.Name) then
        return tool.Name
    end
    for _, name in WeaponConfig.All() do
        if WeaponConfig.Get(name).DisplayName == tool.Name then
            return name
        end
    end
    return nil
end

-- The slot belongs to the Tool from the first time it is held until it is destroyed or leaves
-- the player's Character and Backpack.
local function slotFor(player: Player, entry, tool: Tool, weaponName: string): number?
    local slot = entry.Slots[tool]
    if slot then
        return slot
    end
    slot = Inventory.GiveWeapon(player, weaponName)
    if not slot then
        warn(`[Azazel] No free slot for {weaponName}; {tool:GetFullName()} stays a plain Tool`)
        return nil
    end
    entry.Slots[tool] = slot
    log(`{player.Name} takes {weaponName} in slot {slot} from {tool:GetFullName()}`)

    local toolTrove = entry.Trove:Extend()
    local function release()
        if entries[player] ~= entry or entry.Slots[tool] ~= slot then
            return
        end
        entry.Slots[tool] = nil
        entry.Trove:Remove(toolTrove)
        log(`{player.Name} gives slot {slot} back, {tool.Name} is gone`)
        Inventory.RemoveWeapon(player, slot)
    end
    toolTrove:Connect(tool.Destroying, release)
    toolTrove:Connect(tool.AncestryChanged, function()
        local parent = tool.Parent
        if parent ~= player.Character and parent ~= player:FindFirstChildOfClass("Backpack") then
            release()
        end
    end)
    return slot
end

-- Several Tools can arrive in one frame; the last one held wins.
local function onToolHeld(player: Player, tool: Tool)
    local entry = entries[player]
    local weaponName = weaponNameFor(tool)
    if not entry or not weaponName then
        return
    end
    local pending = entry.PendingTool
    entry.PendingTool = tool
    if pending then
        return
    end
    task.defer(function()
        local held = entry.PendingTool
        entry.PendingTool = nil
        if entries[player] ~= entry or held.Parent ~= player.Character then
            return
        end
        local slot = slotFor(player, entry, held, weaponNameFor(held) :: string)
        local state = Inventory.Get(player)
        if slot and state and state.EquippedSlot ~= slot then
            Inventory.Equip(player, slot)
        end
    end)
end

-- Swapping weapons empties the hand for a moment; only a slot still equipped on the next step
-- really left the hand.
local function onToolDropped(player: Player, tool: Tool)
    local entry = entries[player]
    local slot = entry and entry.Slots[tool]
    if not slot then
        return
    end
    task.defer(function()
        local state = Inventory.Get(player)
        if entries[player] ~= entry or not state or state.EquippedSlot ~= slot then
            return
        end
        if tool.Parent == player.Character then
            return
        end
        Inventory.Equip(player, 0)
    end)
end

local function watchCharacter(player: Player, character: Model, trove)
    for _, child in character:GetChildren() do
        if child:IsA("Tool") then
            onToolHeld(player, child)
        end
    end
    trove:Connect(character.ChildAdded, function(child)
        if child:IsA("Tool") then
            onToolHeld(player, child)
        end
    end)
    trove:Connect(character.ChildRemoved, function(child)
        if child:IsA("Tool") then
            onToolDropped(player, child)
        end
    end)
end

local function addPlayer(player: Player)
    local trove = Trove.new()
    local entry = { Slots = {}, Trove = trove, PendingTool = nil, CharacterTrove = nil }
    entries[player] = entry

    local function onCharacter(character: Model)
        if entry.CharacterTrove then
            trove:Remove(entry.CharacterTrove)
        end
        entry.CharacterTrove = trove:Extend()
        watchCharacter(player, character, entry.CharacterTrove)
    end

    trove:Connect(player.CharacterAdded, onCharacter)
    if player.Character then
        onCharacter(player.Character)
    end
end

function Backpack.Start()
    if not Settings.Server.UseBackpack then
        return
    end
    log(`watching held Tools, {Settings.Server.MaxSlots} slots`)
    Players.PlayerAdded:Connect(addPlayer)
    for _, player in Players:GetPlayers() do
        addPlayer(player)
    end
    Players.PlayerRemoving:Connect(function(player)
        local entry = entries[player]
        entries[player] = nil
        if entry then
            entry.Trove:Destroy()
        end
    end)
end

return Backpack
