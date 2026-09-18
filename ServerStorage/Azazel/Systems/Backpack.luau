--[[
    Weapons held as Roblox Tools, on when Settings.Server.UseBackpack is true.

    The package does not own the Backpack. It never creates, destroys, moves or edits a Tool and
    never equips or unequips anything: the Roblox hotbar does all of that. This only watches what
    the character holds. A Tool that names a weapon (attribute AzazelWeapon, or a Name equal to a
    config Name or DisplayName) puts that weapon in the player's hand while it is held and takes
    it away when it leaves; a Tool that names no weapon is none of its business.

    The slot is bookkeeping (ammo, fire mode, spray) and belongs to the Tool: it is kept while the
    Tool exists, so putting the weapon away and taking it out again keeps the magazine.

    A Tool with no Handle needs RequiresHandle off to be equipped at all; that is the Tool's own
    setting, not something the package touches.
]]

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
    if Settings.Debug.LogInventory then
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

-- The slot the Tool owns, taken the first time it reaches the hand and given back when the Tool
-- is destroyed (the Roblox death cleanup, or the game removing it).
local function slotFor(player: Player, tool: Tool, weaponName: string): number?
    local entry = entries[player]
    if not entry then
        return nil
    end
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
    entry.Trove:Add(tool.Destroying:Connect(function()
        if entries[player] ~= entry or entry.Slots[tool] ~= slot then
            return
        end
        entry.Slots[tool] = nil
        log(`{player.Name} gives slot {slot} back, {tool.Name} is gone`)
        Inventory.RemoveWeapon(player, slot)
    end))
    return slot
end

local function onToolHeld(player: Player, tool: Tool)
    local weaponName = weaponNameFor(tool)
    if not weaponName then
        return
    end
    local slot = slotFor(player, tool, weaponName)
    if slot then
        Inventory.Equip(player, slot)
    end
end

-- Swapping weapons unequips the old Tool before the new one arrives, so the hand is empty for a
-- moment; only a slot that is still the equipped one on the next step really left the hand.
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
    local entry = { Slots = {}, Trove = trove }
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
