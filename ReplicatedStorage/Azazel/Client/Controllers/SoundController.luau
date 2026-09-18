local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local Client = require(script.Parent.Parent)
local package = script.Parent.Parent.Parent
local Settings = require(package.Config.Settings)
local WeaponConfig = require(package.Config.WeaponConfig)
local Remotes = require(package.Shared.Remotes)
local WeaponModel = require(package.Shared.WeaponModel)

-- Weapon sounds, placed by hand under Assets/Sounds. A slot is a Sound, or a Folder of Sounds
-- played together as layers, found by the weapon override (cfg.Sounds[slot] names a child of
-- Assets/Sounds), then the weapon's own folder (Assets/Sounds/<Model>/<Slot>, also by Name or
-- DisplayName), then the shared one right under Assets/Sounds/<Slot>. Fire is per weapon;
-- ModeSelect, RemoveMag and InsertMag are shared. Everything plays at the weapon's Handle and
-- a missing slot is silence.
local SoundController = {}

local Signals = Client.Signals
local SoundSettings = Settings.Sounds

local SAFETY_SECONDS = 10

local localPlayer = Players.LocalPlayer
local lastWeapon: string? = nil
local lastFireMode: number? = nil
local reloading = false

local function soundsFolder(): Instance?
    local assets = package:FindFirstChild("Assets")
    return assets and assets:FindFirstChild("Sounds")
end

local function isSlot(instance: Instance?): boolean
    return instance ~= nil and (instance:IsA("Sound") or instance:IsA("Folder"))
end

local function weaponFolders(cfg): { string }
    local names = {}
    for _, name in { cfg.Model, cfg.Name, cfg.DisplayName } do
        if type(name) == "string" and name ~= "" then
            table.insert(names, name)
        end
    end
    return names
end

local function resolve(cfg, slot: string): Instance?
    local root = soundsFolder()
    if not root or not cfg then
        return nil
    end
    local override = cfg.Sounds and cfg.Sounds[slot]
    if type(override) == "string" and override ~= "" then
        local named = root:FindFirstChild(override)
        if isSlot(named) then
            return named
        end
    end
    for _, folderName in weaponFolders(cfg) do
        local folder = root:FindFirstChild(folderName)
        local child = folder and folder:FindFirstChild(slot)
        if isSlot(child) then
            return child
        end
    end
    local shared = root:FindFirstChild(slot)
    return if isSlot(shared) then shared else nil
end

local function handleOf(character: Model?): Instance?
    local model = WeaponModel.Find(character)
    return model and model:FindFirstChild(WeaponModel.HandleName)
end

-- Plays a slot at a part (2D from SoundService without one) and returns the first Sound, so a
-- caller can chain on its Ended.
local function play(cfg, slot: string, parent: Instance?): Sound?
    if not SoundSettings.Enabled then
        return nil
    end
    local source = resolve(cfg, slot)
    if not source then
        return nil
    end
    local templates = if source:IsA("Sound") then { source } else source:GetChildren()
    local first: Sound? = nil
    for _, template in templates do
        if template:IsA("Sound") then
            local sound = template:Clone()
            sound.Parent = parent or SoundService
            sound:Play()
            sound.Ended:Once(function()
                sound:Destroy()
            end)
            Debris:AddItem(sound, SAFETY_SECONDS)
            first = first or sound
        end
    end
    return first
end

local function onState(state)
    local cfg = Client.Config
    local handle = handleOf(localPlayer.Character)
    if cfg and state.Weapon == lastWeapon and lastFireMode ~= nil and state.FireMode ~= lastFireMode then
        play(cfg, "ModeSelect", handle)
    end
    local isReloading = state.EquipState == "Reloading"
    if cfg and isReloading and not reloading then
        -- Two sounds in a row for now, the magazine out then in; animation markers come later.
        local weapon = state.Weapon
        local function insert()
            if Client.State and Client.State.Weapon == weapon then
                play(cfg, "InsertMag", handleOf(localPlayer.Character))
            end
        end
        local remove = play(cfg, "RemoveMag", handle)
        if remove then
            remove.Ended:Once(insert)
        else
            insert()
        end
    end
    reloading = isReloading
    lastWeapon = state.Weapon
    lastFireMode = state.FireMode
end

function SoundController.Start()
    Signals.LocalShot:Connect(function(_, _, cfg)
        play(cfg, "Fire", handleOf(localPlayer.Character))
    end)

    Remotes.OnClient("ShotFired", function(shooter, weaponName)
        if shooter == localPlayer or typeof(shooter) ~= "Instance" or type(weaponName) ~= "string" then
            return
        end
        local cfg = WeaponConfig.Get(weaponName)
        if cfg then
            play(cfg, "Fire", handleOf(shooter.Character))
        end
    end)

    Signals.StateChanged:Connect(onState)
    if Client.State then
        onState(Client.State)
    end
end

return SoundController
