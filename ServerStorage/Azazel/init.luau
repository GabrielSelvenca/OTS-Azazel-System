local ReplicatedStorage = game:GetService("ReplicatedStorage")

local package = ReplicatedStorage:WaitForChild("Azazel")
local Version = require(package.Version)
local Settings = require(package.Config.Settings)
local WeaponConfig = require(package.Config.WeaponConfig)
local Remotes = require(package.Shared.Remotes)

local CharacterRig = require(script.Systems.CharacterRig)
local Inventory = require(script.Systems.Inventory)
local Combat = require(script.Systems.Combat)

local BOOT_ORDER = {
    { Name = "CharacterRig", System = CharacterRig },
    { Name = "Inventory", System = Inventory },
    { Name = "Combat", System = Combat },
}

local Azazel = {
    Version = Version,
    Settings = Settings,
    WeaponConfig = WeaponConfig,
    Inventory = Inventory,
    Combat = Combat,
    CharacterRig = CharacterRig,
    WeaponEquipped = Inventory.WeaponEquipped,
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
    for _, entry in BOOT_ORDER do
        local ok, err = pcall(entry.System.Start)
        if ok then
            count += 1
        else
            warn(`[Azazel] System {entry.Name} failed to start: {err}`)
        end
    end
    if Settings.Debug.PrintBoot then
        print(`[Azazel] {Version.ToString()} {count}/{#BOOT_ORDER} systems started`)
    end
end

function Azazel.GiveWeapon(player: Player, weaponName: string, slot: number?): number?
    return Inventory.GiveWeapon(player, weaponName, slot)
end

function Azazel.RemoveWeapon(player: Player, slot: number)
    Inventory.RemoveWeapon(player, slot)
end

function Azazel.SetLoadout(player: Player, loadout)
    Inventory.SetLoadout(player, loadout)
end

function Azazel.Equip(player: Player, slot: number)
    Inventory.Equip(player, slot)
end

function Azazel.GetState(player: Player)
    return Inventory.Snapshot(player)
end

return Azazel
