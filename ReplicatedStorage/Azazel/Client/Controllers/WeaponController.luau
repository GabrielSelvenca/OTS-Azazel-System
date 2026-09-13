local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Client = require(script.Parent.Parent)
local package = script.Parent.Parent.Parent
local WeaponConfig = require(package.Config.WeaponConfig)
local Accuracy = require(package.Shared.Accuracy)
local Remotes = require(package.Shared.Remotes)
local Rig = require(package.Shared.Rig)
local CameraController = require(script.Parent.CameraController)

local WeaponController = {}

local Signals = Client.Signals
local localPlayer = Players.LocalPlayer

local AIM_DOT_MIN = 0.5
local SPRAY_EPSILON = 0.005

local ammo = 0
local reserve = 0
local accuracyState = Accuracy.NewState()
local firing = false
local semiLatch = false
local burstRemaining = 0
local nextShotAt = 0
local seq = 0
local lastCone = -1
local rng = Random.new()

local function cfg()
    return Client.Config
end

local function character(): Model?
    return localPlayer.Character
end

local function isAlive(): boolean
    local model = character()
    local humanoid = model and model:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health > 0
end

local function currentFireMode(): string?
    local config = cfg()
    local state = Client.State
    if not config or not state then
        return nil
    end
    return config.FireModes[state.FireMode] or config.FireModes[1]
end

local function raycastParams(): RaycastParams
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character(), workspace.CurrentCamera }
    params.IgnoreWater = true
    return params
end

local function aimPoint(range: number, params: RaycastParams): Vector3
    local origin, look = CameraController.GetAimRay()
    local result = workspace:Raycast(origin, look * range, params)
    return if result then result.Position else origin + look * range
end

local function canFire(): boolean
    return Client.IsReady() and ammo > 0 and isAlive()
end

local function shoot()
    local config = cfg()
    local model = character()
    if not config or not model then
        return
    end
    local rig = Rig.Get(model)
    local head = rig and model:FindFirstChild(rig.Head)
    if not head or not head:IsA("BasePart") then
        return
    end
    local params = raycastParams()
    local origin = head.Position
    local target = aimPoint(config.Range, params)
    local direction = (target - origin)
    local _, look = CameraController.GetAimRay()
    if direction.Magnitude < 0.1 or direction.Unit:Dot(look) < AIM_DOT_MIN then
        direction = look
    end
    direction = direction.Unit

    local now = os.clock()
    Accuracy.Step(accuracyState, config, now)
    local cone = Accuracy.Cone(config, accuracyState, Client.Aiming, "Stand")
    Accuracy.RegisterShot(accuracyState, config, now)

    ammo -= 1
    seq += 1
    Signals.AmmoChanged:Fire(ammo, reserve, config.Magazine)

    local ends = {}
    for pellet = 1, math.max(1, config.Pellets.Count) do
        local visual = Accuracy.Sample(direction, cone, rng)
        if config.Pellets.Spread > 0 then
            visual = Accuracy.Sample(visual, config.Pellets.Spread, rng)
        end
        local result = workspace:Raycast(origin, visual * config.Range, params)
        ends[pellet] = if result then result.Position else origin + visual * config.Range
    end
    Signals.LocalShot:Fire(origin, ends, config)
    Signals.Recoil:Fire(config.Recoil.Camera.Pitch, config.Recoil.Camera.Yaw * rng:NextNumber(-1, 1))
    Remotes.FireServer("Fire", origin, direction, seq)
end

local function heartbeat()
    local config = cfg()
    if not config then
        return
    end
    local now = os.clock()
    Accuracy.Step(accuracyState, config, now)
    local cone = Accuracy.Cone(config, accuracyState, Client.Aiming, "Stand")
    if math.abs(cone - lastCone) > SPRAY_EPSILON then
        lastCone = cone
        Signals.SprayChanged:Fire(cone)
    end

    if not canFire() then
        burstRemaining = 0
        return
    end
    local mode = currentFireMode()
    if now < nextShotAt then
        return
    end
    if mode == "Auto" then
        if firing then
            shoot()
            nextShotAt = now + config.ShotInterval
        end
    elseif mode == "Semi" then
        if semiLatch then
            semiLatch = false
            shoot()
            nextShotAt = now + config.ShotInterval
        end
    elseif mode == "Burst" then
        if burstRemaining > 0 then
            burstRemaining -= 1
            shoot()
            nextShotAt = now + (if burstRemaining > 0 then config.BurstInterval else config.ShotInterval)
        end
    end
end

local function applyState(state)
    local previous = Client.State
    local previousWeapon = previous and previous.Weapon
    Client.State = state
    local config = if state.Weapon then WeaponConfig.Get(state.Weapon) else nil
    Client.Config = config
    ammo = state.Ammo
    reserve = state.Reserve
    if state.Weapon ~= previousWeapon or state.Slot ~= (previous and previous.Slot) then
        accuracyState = Accuracy.NewState()
        burstRemaining = 0
        semiLatch = false
        Signals.WeaponChanged:Fire(config)
    end
    Signals.AmmoChanged:Fire(ammo, reserve, state.Magazine)
    Signals.StateChanged:Fire(state)
end

function WeaponController.GetAmmo(): (number, number)
    return ammo, reserve
end

function WeaponController.Start()
    Remotes.OnClient("State", function(state)
        if type(state) ~= "table" then
            return
        end
        applyState(state)
    end)

    Remotes.OnClient("HitConfirmed", function(zone, damage, killed)
        Signals.HitConfirmed:Fire(zone, damage, killed)
    end)

    Signals.FireInput:Connect(function(pressed)
        firing = pressed
        if not pressed then
            return
        end
        semiLatch = true
        local config = cfg()
        if config and currentFireMode() == "Burst" and burstRemaining == 0 and os.clock() >= nextShotAt then
            burstRemaining = config.Burst.Count
        end
    end)

    Signals.AimInput:Connect(function(pressed)
        if Client.Aiming == pressed then
            return
        end
        Client.Aiming = pressed
        if pressed then
            accuracyState.AimStartedAt = os.clock()
        else
            accuracyState.AimStartedAt = nil
        end
        Signals.AimChanged:Fire(pressed)
        Remotes.FireServer("Aim", pressed)
    end)

    Signals.ReloadInput:Connect(function()
        local config = cfg()
        if not config or not Client.IsReady() then
            return
        end
        if ammo >= config.Magazine or reserve <= 0 then
            return
        end
        Remotes.FireServer("Reload")
    end)

    Signals.SlotInput:Connect(function(slot)
        local state = Client.State
        if not state or not isAlive() then
            return
        end
        if slot ~= 0 and not state.Slots[slot] then
            return
        end
        if slot == state.Slot then
            return
        end
        Remotes.FireServer("Equip", slot)
    end)

    Signals.FireModeInput:Connect(function()
        local config = cfg()
        local state = Client.State
        if not config or not state or #config.FireModes < 2 then
            return
        end
        local nextIndex = state.FireMode % #config.FireModes + 1
        Remotes.FireServer("SetFireMode", nextIndex)
    end)

    RunService.Heartbeat:Connect(heartbeat)
    task.defer(Remotes.FireServer, "Ready")
end

return WeaponController
