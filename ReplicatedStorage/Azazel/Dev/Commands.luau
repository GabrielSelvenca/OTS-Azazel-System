local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

if not RunService:IsStudio() then
    return {}
end

local package = script.Parent.Parent
local Manifest = require(package.Assets.Manifest)
local WeaponConfig = require(package.Config.WeaponConfig)
local WeaponModel = require(package.Shared.WeaponModel)

local Commands = {}

local DUMMY_NAME = "AzazelDummy"

local function ensureFolder(parent: Instance, name: string): Folder
    local existing = parent:FindFirstChild(name)
    if existing then
        return existing :: Folder
    end
    local folder = Instance.new("Folder")
    folder.Name = name
    folder.Parent = parent
    return folder
end

local function server()
    assert(RunService:IsServer(), "[Azazel] This command runs on the server (Play mode, server view or command bar in edit mode)")
    return require(ServerStorage:WaitForChild("Azazel"))
end

function Commands.Setup()
    local assets = package.Assets
    for _, path in Manifest.Folders do
        local current: Instance = assets
        for segment in string.gmatch(path, "[^/]+") do
            current = ensureFolder(current, segment)
        end
    end
    local animations = assets.Animations
    for _, class in Manifest.AnimationClasses do
        ensureFolder(animations, class)
    end
    print("[Azazel] Assets folders ready")
end

function Commands.SpawnDummy(count: number?, distance: number?)
    server()
    local total = count or 1
    local spacing = 4
    local anchorPlayer = Players:GetPlayers()[1]
    local root = anchorPlayer and anchorPlayer.Character and anchorPlayer.Character:FindFirstChild("HumanoidRootPart")
    local base = if root then root.CFrame * CFrame.new(0, 0, -(distance or 20)) else CFrame.new(0, 5, -20)
    for index = 1, total do
        local description = Instance.new("HumanoidDescription")
        local dummy = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
        dummy.Name = `{DUMMY_NAME}{index}`
        local humanoid = dummy:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.DisplayName = `Dummy {index}`
            humanoid.BreakJointsOnDeath = false
            humanoid.Died:Once(function()
                task.delay(3, function()
                    dummy:Destroy()
                end)
            end)
        end
        dummy:PivotTo(base * CFrame.new((index - (total + 1) / 2) * spacing, 0, 0) * CFrame.Angles(0, math.pi, 0))
        dummy.Parent = workspace
    end
    print(`[Azazel] Spawned {total} dummy(ies)`)
end

function Commands.Give(weaponName: string, player: Player?)
    local api = server()
    local target = player or Players:GetPlayers()[1]
    assert(target, "[Azazel] No player to give the weapon to")
    assert(WeaponConfig.Exists(weaponName), `[Azazel] Unknown weapon {weaponName}`)
    local slot = api.GiveWeapon(target, weaponName)
    if slot then
        api.Equip(target, slot)
    end
    print(`[Azazel] Gave {weaponName} to {target.Name} in slot {tostring(slot)}`)
end

function Commands.ImportWeapon(model: Model, name: string?)
    assert(typeof(model) == "Instance" and model:IsA("Model"), "[Azazel] ImportWeapon expects a Model")
    local weaponName = name or model.Name
    Commands.Setup()
    local copy = model:Clone()
    copy.Name = weaponName
    local handle = WeaponModel.Sanitize(copy)
    assert(handle, "[Azazel] Model has no BasePart to use as Handle")
    local folder = package.Assets.Weapons
    local existing = folder:FindFirstChild(weaponName)
    if existing then
        existing:Destroy()
    end
    copy.Parent = folder
    print(`[Azazel] Imported {weaponName} into Assets/Weapons. Config stub:`)
    print(table.concat({ "return {", `    Name = "{weaponName}",`, `    DisplayName = "{weaponName}",`, `    Class = "Rifle",`, `    Model = "{weaponName}",`, "}" }, string.char(10)))
    return copy
end

function Commands.Weapons()
    for _, name in WeaponConfig.All() do
        local cfg = WeaponConfig.Get(name)
        print(`{name} ({cfg.Class}) rpm={cfg.Rpm} mag={cfg.Magazine} model={tostring(cfg.Model)}`)
    end
end

return Commands
