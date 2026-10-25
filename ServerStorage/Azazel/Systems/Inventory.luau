local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local package = ReplicatedStorage:WaitForChild("Azazel")
local Settings = require(package.Config.Settings)
local WeaponConfig = require(package.Config.WeaponConfig)
local EquipmentConfig = require(package.Config.EquipmentConfig)
local Accuracy = require(package.Shared.Accuracy)
local Remotes = require(package.Shared.Remotes)
local Signal = require(package.Packages.Signal)

local CharacterRig = require(script.Parent.CharacterRig)

local Inventory = {}

Inventory.WeaponEquipped = Signal.new()
Inventory.EquipmentChanged = Signal.new()

local states = {}
local pushQueued: { [Player]: boolean } = {}

local function log(message: string)
    if Settings.Debug.Enabled and Settings.Debug.LogInventory then
        print(`[Azazel] Inventory: {message}`)
    end
end

local function newSlot(cfg)
    return {
        Name = cfg.Name,
        Ammo = cfg.Magazine,
        Reserve = cfg.Reserve,
        FireModeIndex = 1,
        Accuracy = Accuracy.NewState(),
    }
end

local function newState(player: Player)
    return {
        Player = player,
        Slots = {},
        EquippedSlot = 0,
        EquipState = "Holstered",
        Config = nil,
        Generation = 0,
        LastShotAt = -math.huge,
        ShotTimes = {},
        LastSeq = 0,
        BurstShots = 0,
        BurstStartedAt = -math.huge,
        Equipment = {},
        Modifiers = {},
    }
end

function Inventory.Get(player: Player)
    return states[player]
end

function Inventory.GetSlot(state)
    return state.Slots[state.EquippedSlot]
end

local function equipmentSnapshot(state)
    local snapshot = {}
    for zone, piece in state.Equipment do
        local cfg = EquipmentConfig.Get(piece.Name)
        snapshot[zone] = {
            Name = piece.Name,
            DisplayName = cfg and cfg.DisplayName or piece.Name,
            Durability = piece.Durability,
            MaxDurability = piece.MaxDurability,
        }
    end
    return snapshot
end

function Inventory.Snapshot(player: Player)
    local state = states[player]
    if not state then
        return nil
    end
    local slotNames = {}
    for index = 1, Settings.Server.MaxSlots do
        local slot = state.Slots[index]
        slotNames[index] = if slot then slot.Name else false
    end
    local slot = Inventory.GetSlot(state)
    local cfg = state.Config
    return {
        Weapon = slot and slot.Name or nil,
        Slot = state.EquippedSlot,
        Slots = slotNames,
        Ammo = slot and slot.Ammo or 0,
        Reserve = if Settings.Server.InfiniteAmmo then math.huge else (slot and slot.Reserve or 0),
        Magazine = cfg and cfg.Magazine or 0,
        FireMode = slot and slot.FireModeIndex or 1,
        EquipState = state.EquipState,
        Armed = state.EquipState == "Ready" or (state.EquipState == "Reloading" and state.ReloadFrom == "Ready"),
        Equipment = equipmentSnapshot(state),
        LastSeq = state.LastSeq,
    }
end

function Inventory.PushState(player: Player)
    local snapshot = Inventory.Snapshot(player)
    if snapshot then
        Remotes.FireClient("State", player, snapshot)
    end
end

-- One push at the end of the frame, however many things asked for it.
function Inventory.PushStateDeferred(player: Player)
    if pushQueued[player] then
        return
    end
    pushQueued[player] = true
    task.defer(function()
        pushQueued[player] = nil
        Inventory.PushState(player)
    end)
end

function Inventory.Bump(state): number
    state.Generation += 1
    return state.Generation
end

local function setEquipState(state, equipState: string)
    state.EquipState = equipState
    Inventory.PushState(state.Player)
end

function Inventory.SetRelaxed(player: Player, relaxed: boolean)
    local state = states[player]
    local slot = state and Inventory.GetSlot(state)
    if not slot then
        return
    end
    local current = state.EquipState
    if current ~= "Relaxed" and current ~= "Ready" then
        return
    end
    local target = if relaxed then "Relaxed" else "Ready"
    if current == target then
        return
    end
    if relaxed then
        slot.Accuracy.AimStartedAt = nil
    end
    setEquipState(state, target)
end

local function rebuildModifiers(state)
    state.Modifiers = EquipmentConfig.StackModifiers(state.Equipment)
    local slot = Inventory.GetSlot(state)
    if slot then
        state.Config = WeaponConfig.Resolve(slot.Name, state.Modifiers)
        slot.Ammo = math.min(slot.Ammo, state.Config.Magazine)
    end
end

function Inventory.GiveWeapon(player: Player, weaponName: string, slot: number?): number?
    local state = states[player]
    local cfg = WeaponConfig.Get(weaponName)
    if not state or not cfg then
        warn(`[Azazel] GiveWeapon failed for {player.Name}: unknown weapon {tostring(weaponName)}`)
        return nil
    end
    local index = slot
    if not index then
        for candidate = 1, Settings.Server.MaxSlots do
            if not state.Slots[candidate] then
                index = candidate
                break
            end
        end
    end
    if not index or index < 1 or index > Settings.Server.MaxSlots then
        return nil
    end
    state.Slots[index] = newSlot(cfg)
    if state.EquippedSlot == index then
        Inventory.Equip(player, index)
    else
        Inventory.PushState(player)
    end
    return index
end

function Inventory.RemoveWeapon(player: Player, slot: number)
    local state = states[player]
    if not state or not state.Slots[slot] then
        return
    end
    state.Slots[slot] = nil
    if state.EquippedSlot == slot then
        Inventory.Equip(player, 0)
    else
        Inventory.PushState(player)
    end
end

function Inventory.GiveEquipment(player: Player, equipmentName: string): boolean
    local state = states[player]
    local cfg = EquipmentConfig.Get(equipmentName)
    if not state or not cfg then
        warn(`[Azazel] GiveEquipment failed for {player.Name}: unknown equipment {tostring(equipmentName)}`)
        return false
    end
    local max = cfg.Durability and cfg.Durability.Max or nil
    state.Equipment[cfg.Zone] = {
        Name = cfg.Name,
        Durability = max,
        MaxDurability = max,
    }
    rebuildModifiers(state)
    Inventory.EquipmentChanged:Fire(player, cfg.Zone, cfg)
    Inventory.PushState(player)
    return true
end

function Inventory.RemoveEquipment(player: Player, zone: string)
    local state = states[player]
    if not state or not state.Equipment[zone] then
        return
    end
    state.Equipment[zone] = nil
    rebuildModifiers(state)
    Inventory.EquipmentChanged:Fire(player, zone, nil)
    Inventory.PushState(player)
end

function Inventory.ApplyArmor(player: Player?, zone: string, damage: number): number
    local state = player and states[player]
    local piece = state and state.Equipment[zone]
    if not piece then
        return damage
    end
    local cfg = EquipmentConfig.Get(piece.Name)
    if not cfg then
        return damage
    end
    local reduced = damage * cfg.DamageMultiplier
    if piece.Durability then
        local loss = cfg.Durability.LossPerHit
        if loss == "Blocked" then
            piece.Durability -= (damage - reduced)
        elseif type(loss) == "number" then
            piece.Durability -= loss
        end
        if piece.Durability <= 0 then
            Inventory.RemoveEquipment(player, zone)
        else
            Inventory.PushStateDeferred(player)
        end
    end
    return reduced
end

function Inventory.SetLoadout(player: Player, loadout)
    local state = states[player]
    if not state then
        return
    end
    table.clear(state.Slots)
    for index, weaponName in loadout.Weapons or {} do
        if type(index) == "number" and index >= 1 and index <= Settings.Server.MaxSlots then
            local cfg = WeaponConfig.Get(weaponName)
            if cfg then
                state.Slots[index] = newSlot(cfg)
            end
        end
    end
    table.clear(state.Equipment)
    for _, equipmentName in loadout.Equipment or {} do
        local cfg = EquipmentConfig.Get(equipmentName)
        if cfg then
            local max = cfg.Durability and cfg.Durability.Max or nil
            state.Equipment[cfg.Zone] = { Name = cfg.Name, Durability = max, MaxDurability = max }
        end
    end
    rebuildModifiers(state)
    Inventory.Equip(player, 0)
end

-- A drawn weapon comes out Relaxed; slot 0 holsters.
function Inventory.Equip(player: Player, slot: number)
    local state = states[player]
    if not state then
        return
    end
    local character = player.Character
    Inventory.Bump(state)
    local target = state.Slots[slot]
    if slot ~= 0 and not target then
        Inventory.PushState(player)
        return
    end
    state.EquippedSlot = slot
    state.Config = nil
    log(`{player.Name} equip slot {slot} ({if target then target.Name else "nothing"})`)
    if not target then
        if character then
            CharacterRig.Detach(character)
        end
        setEquipState(state, "Holstered")
        Inventory.WeaponEquipped:Fire(player, nil)
        return
    end
    local cfg = WeaponConfig.Resolve(target.Name, state.Modifiers)
    state.Config = cfg
    target.Ammo = math.min(target.Ammo, cfg.Magazine)
    target.Accuracy.AimStartedAt = nil
    if character and CharacterRig.IsAlive(character) then
        CharacterRig.Attach(character, cfg)
    end
    setEquipState(state, "Relaxed")
    Inventory.WeaponEquipped:Fire(player, cfg)
end

local function onCharacterAdded(player: Player)
    local state = states[player]
    if not state then
        return
    end
    for _, slot in state.Slots do
        slot.Accuracy = Accuracy.NewState()
    end
    -- With UseBackpack the held Tool decides the weapon (Systems/Backpack); no spawn loadout.
    if Settings.Server.UseBackpack then
        local character = player.Character
        if character and character:FindFirstChildOfClass("Tool") then
            Inventory.PushState(player)
        else
            Inventory.Equip(player, 0)
        end
        return
    end
    if next(state.Slots) == nil and Settings.Server.GiveDefaultLoadoutOnSpawn then
        Inventory.SetLoadout(player, Settings.Server.DefaultLoadout)
    end
    local autoSlot = Settings.Server.AutoEquipSlot
    if autoSlot and state.Slots[autoSlot] then
        Inventory.Equip(player, autoSlot)
    else
        Inventory.Equip(player, 0)
    end
end

local function onDied(player: Player)
    local state = states[player]
    if not state then
        return
    end
    Inventory.Bump(state)
    state.EquippedSlot = 0
    state.Config = nil
    setEquipState(state, "Holstered")
end

function Inventory.Start()
    local function addPlayer(player: Player)
        states[player] = newState(player)
    end
    Players.PlayerAdded:Connect(addPlayer)
    for _, player in Players:GetPlayers() do
        addPlayer(player)
    end
    Players.PlayerRemoving:Connect(function(player)
        states[player] = nil
    end)

    CharacterRig.CharacterAdded:Connect(onCharacterAdded)
    CharacterRig.Died:Connect(onDied)

    Remotes.OnServer("RequestState", Inventory.PushState)

    Remotes.OnServer("Relax", function(player, relaxed)
        if not CharacterRig.IsAlive(player.Character) then
            return
        end
        Inventory.SetRelaxed(player, relaxed)
    end)

    Remotes.OnServer("Equip", function(player, slot)
        if Settings.Server.UseBackpack or not CharacterRig.IsAlive(player.Character) then
            return
        end
        Inventory.Equip(player, slot)
    end)
end

return Inventory
