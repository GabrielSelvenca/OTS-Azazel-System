local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local package = ReplicatedStorage:WaitForChild("Azazel")
local Settings = require(package.Config.Settings)
local WeaponConfig = require(package.Config.WeaponConfig)
local Accuracy = require(package.Shared.Accuracy)
local Remotes = require(package.Shared.Remotes)
local Signal = require(package.Packages.Signal)

local CharacterRig = require(script.Parent.CharacterRig)

local Inventory = {}

Inventory.WeaponEquipped = Signal.new()

local states = {}

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
        Ready = false,
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
        Equipment = state.Equipment,
    }
end

function Inventory.PushState(player: Player)
    local snapshot = Inventory.Snapshot(player)
    if snapshot then
        Remotes.FireClient("State", player, snapshot)
    end
end

function Inventory.Bump(state): number
    state.Generation += 1
    return state.Generation
end

local function setEquipState(state, equipState: string)
    state.EquipState = equipState
    Inventory.PushState(state.Player)
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

function Inventory.SetLoadout(player: Player, loadout)
    local state = states[player]
    if not state then
        return
    end
    table.clear(state.Slots)
    for index, weaponName in loadout.Weapons or {} do
        if index <= Settings.Server.MaxSlots then
            local cfg = WeaponConfig.Get(weaponName)
            if cfg then
                state.Slots[index] = newSlot(cfg)
            end
        end
    end
    state.Equipment = {}
    Inventory.Equip(player, 0)
end

function Inventory.Equip(player: Player, slot: number)
    local state = states[player]
    if not state then
        return
    end
    local character = player.Character
    local generation = Inventory.Bump(state)
    local target = state.Slots[slot]
    if slot ~= 0 and not target then
        Inventory.PushState(player)
        return
    end
    state.EquippedSlot = slot
    state.Config = nil
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
    if character and CharacterRig.IsAlive(character) then
        CharacterRig.Attach(character, cfg)
    end
    setEquipState(state, "Equipping")
    Inventory.WeaponEquipped:Fire(player, cfg)
    task.delay(cfg.EquipTime, function()
        if states[player] ~= state or state.Generation ~= generation then
            return
        end
        setEquipState(state, "Ready")
    end)
end

local function onCharacterAdded(player: Player)
    local state = states[player]
    if not state then
        return
    end
    local hasWeapons = next(state.Slots) ~= nil
    if not hasWeapons and Settings.Server.GiveDefaultLoadoutOnSpawn then
        for index, weaponName in Settings.Server.DefaultLoadout.Weapons do
            local cfg = WeaponConfig.Get(weaponName)
            if cfg and index <= Settings.Server.MaxSlots then
                state.Slots[index] = newSlot(cfg)
            end
        end
    end
    for _, slot in state.Slots do
        slot.Accuracy = Accuracy.NewState()
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

    Remotes.OnServer("Ready", function(player)
        local state = states[player]
        if state then
            state.Ready = true
            Inventory.PushState(player)
        end
    end)

    Remotes.OnServer("Equip", function(player, slot)
        local state = states[player]
        if not state or not CharacterRig.IsAlive(player.Character) then
            return
        end
        if slot ~= 0 and not state.Slots[slot] then
            Inventory.PushState(player)
            return
        end
        Inventory.Equip(player, slot)
    end)
end

return Inventory
