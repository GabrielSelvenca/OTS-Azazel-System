--[[
    Weapons as plain Roblox Tools, on when Settings.Server.UseBackpack is true.

    The player's Backpack is the source of truth: any Tool that names a weapon (attribute
    AzazelWeapon, or its Name equal to a config Name or DisplayName) takes a slot while it is in
    the Backpack or held by the character, and gives the slot back when it leaves. The Roblox
    hotbar equips and unequips; Tool.Equipped and Tool.Unequipped drive Inventory.Equip. The
    Tool never needs a Handle: the weapon the player sees is still the Model on the Motor6D.
    GiveWeapon, RemoveWeapon, SetLoadout and Equip from the server API go through here so the
    hotbar always agrees with the state.
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

local function aliveHumanoid(player: Player): Humanoid?
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return if humanoid and humanoid.Health > 0 then humanoid else nil
end

local function stillOwned(player: Player, tool: Tool): boolean
    local parent = tool.Parent
    if parent == nil then
        return false
    end
    if parent == player:FindFirstChildOfClass("Backpack") then
        return true
    end
    return parent == player.Character and parent.Parent ~= nil
end

local function release(player: Player, tool: Tool)
    local entry = entries[player]
    local slot = entry and entry.Tools[tool]
    if not slot then
        return
    end
    entry.Tools[tool] = nil
    entry.Slots[slot] = nil
    Inventory.RemoveWeapon(player, slot)
end

local function accept(player: Player, tool: Tool, slot: number?)
    local entry = entries[player]
    if not entry or entry.Tools[tool] then
        return
    end
    local weaponName = weaponNameFor(tool)
    if not weaponName then
        return
    end
    local index = Inventory.GiveWeapon(player, weaponName, slot)
    if not index then
        warn(`[Azazel] No free slot for {weaponName}; {tool:GetFullName()} ignored`)
        return
    end
    local cfg = WeaponConfig.Get(weaponName)
    tool:SetAttribute(WEAPON_ATTRIBUTE, weaponName)
    tool.RequiresHandle = false
    tool.CanBeDropped = false
    if tool.ToolTip == "" then
        tool.ToolTip = cfg.DisplayName
    end
    entry.Tools[tool] = index
    entry.Slots[index] = tool

    local trove = entry.Trove:Extend()
    trove:Connect(tool.Equipped, function()
        Inventory.Equip(player, index)
    end)
    trove:Connect(tool.Unequipped, function()
        task.defer(function()
            local character = player.Character
            local holding = character and character:FindFirstChildOfClass("Tool")
            if entry.Tools[tool] and Inventory.Get(player) and not holding then
                Inventory.Equip(player, 0)
            end
        end)
    end)
    trove:Connect(tool.AncestryChanged, function()
        if not stillOwned(player, tool) then
            release(player, tool)
            entry.Trove:Remove(trove)
        end
    end)
    if tool.Parent == player.Character then
        Inventory.Equip(player, index)
    end
end

local function createTool(cfg): Tool
    local tool = Instance.new("Tool")
    tool.Name = cfg.DisplayName
    tool.ToolTip = cfg.DisplayName
    tool.RequiresHandle = false
    tool.CanBeDropped = false
    tool:SetAttribute(WEAPON_ATTRIBUTE, cfg.Name)
    return tool
end

function Backpack.GiveWeapon(player: Player, weaponName: string, slot: number?): number?
    local entry = entries[player]
    local cfg = WeaponConfig.Get(weaponName)
    local container = player:FindFirstChildOfClass("Backpack")
    if not entry or not cfg or not container then
        return nil
    end
    local tool = createTool(cfg)
    accept(player, tool, slot)
    local index = entry.Tools[tool]
    if not index then
        tool:Destroy()
        return nil
    end
    tool.Parent = container
    return index
end

function Backpack.RemoveWeapon(player: Player, slot: number)
    local entry = entries[player]
    local tool = entry and entry.Slots[slot]
    if tool then
        release(player, tool)
        tool:Destroy()
    end
end

function Backpack.SetLoadout(player: Player, loadout)
    local entry = entries[player]
    if not entry then
        return
    end
    for tool in entry.Tools do
        release(player, tool)
        tool:Destroy()
    end
    Inventory.SetLoadout(player, { Weapons = {}, Equipment = loadout.Equipment })
    for _, weaponName in loadout.Weapons or {} do
        Backpack.GiveWeapon(player, weaponName)
    end
end

function Backpack.Equip(player: Player, slot: number)
    local entry = entries[player]
    local humanoid = aliveHumanoid(player)
    if not entry or not humanoid then
        Inventory.Equip(player, slot)
        return
    end
    if slot == 0 then
        humanoid:UnequipTools()
        return
    end
    local tool = entry.Slots[slot]
    if tool then
        humanoid:EquipTool(tool)
    else
        Inventory.PushState(player)
    end
end

local function watch(player: Player, container: Instance, trove)
    for _, child in container:GetChildren() do
        if child:IsA("Tool") then
            accept(player, child)
        end
    end
    trove:Connect(container.ChildAdded, function(child)
        if child:IsA("Tool") then
            accept(player, child)
        end
    end)
end

local function swapTrove(entry, key: string)
    if entry[key] then
        entry.Trove:Remove(entry[key])
    end
    entry[key] = entry.Trove:Extend()
    return entry[key]
end

local function onCharacterAdded(player: Player, character: Model)
    local entry = entries[player]
    if not entry then
        return
    end
    watch(player, character, swapTrove(entry, "CharacterTrove"))
    task.defer(function()
        if entries[player] ~= entry then
            return
        end
        if Settings.Server.GiveDefaultLoadoutOnSpawn and next(entry.Tools) == nil then
            Backpack.SetLoadout(player, Settings.Server.DefaultLoadout)
        end
        local autoSlot = Settings.Server.AutoEquipSlot
        local tool = autoSlot and entry.Slots[autoSlot]
        local humanoid = aliveHumanoid(player)
        if tool and humanoid then
            humanoid:EquipTool(tool)
        end
    end)
end

local function addPlayer(player: Player)
    local trove = Trove.new()
    local entry = { Tools = {}, Slots = {}, Trove = trove }
    entries[player] = entry
    local container = player:FindFirstChildOfClass("Backpack")
    if container then
        watch(player, container, swapTrove(entry, "BackpackTrove"))
    end
    trove:Connect(player.ChildAdded, function(child)
        if child:IsA("Backpack") then
            watch(player, child, swapTrove(entry, "BackpackTrove"))
        end
    end)
    trove:Connect(player.CharacterAdded, function(character)
        onCharacterAdded(player, character)
    end)
    trove:Connect(player.CharacterRemoving, function(character)
        for tool in entry.Tools do
            if tool.Parent == character then
                release(player, tool)
            end
        end
        if entry.CharacterTrove then
            entry.Trove:Remove(entry.CharacterTrove)
            entry.CharacterTrove = nil
        end
    end)
    if player.Character then
        onCharacterAdded(player, player.Character)
    end
end

function Backpack.Start()
    if not Settings.Server.UseBackpack then
        return
    end
    Inventory.EquipRouter = Backpack.Equip
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
