local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Client = require(script.Parent.Parent)
local package = script.Parent.Parent.Parent
local WeaponConfig = require(package.Config.WeaponConfig)
local Accuracy = require(package.Shared.Accuracy)
local Remotes = require(package.Shared.Remotes)
local Rig = require(package.Shared.Rig)
local WeaponModel = require(package.Shared.WeaponModel)
local ShotDebug = require(package.Dev.ShotDebug)
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

local function aimPoint(range: number, params: RaycastParams): (Vector3, RaycastResult?)
    local origin, look = CameraController.GetAimRay()
    local result = workspace:Raycast(origin, look * range, params)
    return (if result then result.Position else origin + look * range), result
end

local function debugShot(info)
    if not ShotDebug.Enabled() then
        return
    end
    local colors = ShotDebug.Colors
    local aimAngle = ShotDebug.AngleBetween(info.Direction, info.Look)
    local anomaly = false
    local pelletLines = {}
    for index, pellet in info.Pellets do
        local angle = ShotDebug.AngleBetween(pellet.Direction, info.Look)
        local off = angle > info.Cone + info.PelletSpread + 2
        anomaly = anomaly or off
        ShotDebug.Line(info.Origin, pellet.End, if off then colors.Anomaly else colors.Shot)
        ShotDebug.Point(pellet.End, if off then colors.Anomaly else colors.End)
        table.insert(pelletLines, string.format(
            "  pellet %d dir=%s angleFromLook=%.2f end=%s hit=%s dist=%.1f%s",
            index,
            ShotDebug.Vector(pellet.Direction),
            angle,
            ShotDebug.Vector(pellet.End),
            ShotDebug.Instance(pellet.Hit),
            (pellet.End - info.Origin).Magnitude,
            if off then "  <-- ANOMALY" else ""
        ))
    end
    ShotDebug.Line(info.CameraPosition, info.AimTarget, colors.Camera)
    ShotDebug.Point(info.AimTarget, colors.Aim, nil, 0.5)
    ShotDebug.Point(info.Origin, colors.Camera, nil, 0.25)
    if info.Muzzle then
        ShotDebug.Point(info.Muzzle, colors.Muzzle, nil, 0.25)
    end
    print(string.format(
        "[Azazel:Shot] #%d %s%s\n  camera=%s look=%s\n  aimHit=%s aimTarget=%s aimDist=%.1f\n  head=%s dir=%s dot=%.3f angleFromLook=%.2f fallback=%s cone=%.2f\n  muzzle=%s muzzleToHead=%.2f\n%s",
        info.Seq,
        info.Weapon,
        if anomaly then "  <-- ANOMALY" else "",
        ShotDebug.Vector(info.CameraPosition),
        ShotDebug.Vector(info.Look),
        ShotDebug.Instance(info.AimHit),
        ShotDebug.Vector(info.AimTarget),
        (info.AimTarget - info.CameraPosition).Magnitude,
        ShotDebug.Vector(info.Origin),
        ShotDebug.Vector(info.Direction),
        info.Dot,
        aimAngle,
        tostring(info.Fallback),
        info.Cone,
        if info.Muzzle then ShotDebug.Vector(info.Muzzle) else "none",
        if info.Muzzle then (info.Muzzle - info.Origin).Magnitude else -1,
        table.concat(pelletLines, "\n")
    ))
end

local function available(): boolean
    return Client.IsReady() and ammo > 0 and isAlive()
end

local function canFire(): boolean
    return available() and os.clock() >= nextShotAt
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
    local target, aimHit = aimPoint(config.Range, params)
    local direction = (target - origin)
    local cameraPosition, look = CameraController.GetAimRay()
    local dot = if direction.Magnitude < 0.1 then -1 else direction.Unit:Dot(look)
    local fallback = dot < AIM_DOT_MIN
    if fallback then
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
    local pellets = {}
    for pellet = 1, math.max(1, config.Pellets.Count) do
        local visual = Accuracy.Sample(direction, cone, rng)
        if config.Pellets.Spread > 0 then
            visual = Accuracy.Sample(visual, config.Pellets.Spread, rng)
        end
        local result = workspace:Raycast(origin, visual * config.Range, params)
        ends[pellet] = if result then result.Position else origin + visual * config.Range
        pellets[pellet] = { Direction = visual, End = ends[pellet], Hit = result and result.Instance }
    end
    debugShot({
        Seq = seq,
        Weapon = config.Name,
        CameraPosition = cameraPosition,
        Look = look,
        AimHit = aimHit and aimHit.Instance,
        AimTarget = target,
        Origin = origin,
        Direction = direction,
        Dot = dot,
        Fallback = fallback,
        Cone = cone,
        PelletSpread = config.Pellets.Spread,
        Muzzle = WeaponModel.MuzzlePosition(WeaponModel.Find(model)),
        Pellets = pellets,
    })
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

    if not available() then
        firing = false
        burstRemaining = 0
        semiLatch = false
        return
    end
    local mode = currentFireMode()
    if now < nextShotAt then
        semiLatch = false
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

function WeaponController.CanFire(): boolean
    return canFire()
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
        if not pressed then
            firing = false
            return
        end
        if not canFire() then
            return
        end
        firing = true
        semiLatch = true
        local config = cfg()
        if currentFireMode() == "Burst" and burstRemaining == 0 then
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
