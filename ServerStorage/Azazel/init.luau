local ReplicatedStorage = game:GetService("ReplicatedStorage")

local package = ReplicatedStorage:WaitForChild("Azazel")
local Version = require(package.Version)
local Settings = require(package.Config.Settings)
local Remotes = require(package.Shared.Remotes)

local BOOT_ORDER = { "CharacterRig", "Inventory", "Backpack", "Combat" }

-- A system whose module fails to load is left out; the rest of the API still works.
local systems = {}
for _, name in BOOT_ORDER do
    local ok, result = pcall(require, script.Systems[name])
    if ok then
        systems[name] = result
    else
        warn(`[Azazel] System {name} failed to load: {result}`)
    end
end

local Inventory = systems.Inventory or {}
local Combat = systems.Combat or {}

local Azazel = {
    Version = Version,
    Settings = Settings,
    WeaponConfig = require(package.Config.WeaponConfig),
    EquipmentConfig = require(package.Config.EquipmentConfig),

    GiveWeapon = Inventory.GiveWeapon,
    RemoveWeapon = Inventory.RemoveWeapon,
    GiveEquipment = Inventory.GiveEquipment,
    RemoveEquipment = Inventory.RemoveEquipment,
    SetLoadout = Inventory.SetLoadout,
    Equip = Inventory.Equip,
    SetRelaxed = Inventory.SetRelaxed,
    GetState = Inventory.Snapshot,

    WeaponEquipped = Inventory.WeaponEquipped,
    EquipmentChanged = Inventory.EquipmentChanged,
    Shot = Combat.Shot,
    Hit = Combat.Hit,
    Kill = Combat.Kill,
}

local started = false

function Azazel.Start()
    if started then
        return
    end
    started = true
    Remotes.EnsureAll()
    local count = 0
    for _, name in BOOT_ORDER do
        local system = systems[name]
        local ok, err = pcall(function()
            system.Start()
        end)
        if ok then
            count += 1
        else
            warn(`[Azazel] System {name} failed to start: {err}`)
        end
    end
    if Settings.Debug.PrintBoot then
        print(`[Azazel] {Version.ToString()} {count}/{#BOOT_ORDER} systems started`)
    end
end

return Azazel
