local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Client = require(script.Parent.Parent)
local package = script.Parent.Parent.Parent
local WeaponConfig = require(package.Config.WeaponConfig)
local Accuracy = require(package.Shared.Accuracy)
local Animations = require(package.Shared.Animations)
local Remotes = require(package.Shared.Remotes)
local Rig = require(package.Shared.Rig)
local WeaponModel = require(package.Shared.WeaponModel)
local ShotDebug = require(script.Parent.Parent.ShotDebug)
local CameraController = require(script.Parent.CameraController)
local ViewmodelController = require(script.Parent.ViewmodelController)

local WeaponController = {}

local Signals = Client.Signals
local localPlayer = Players.LocalPlayer

local AIM_DOT_MIN = 0.5
local RELOAD_REQUEST_TIMEOUT = 1 -- seconds the trigger stays locked waiting for the server to answer a reload
local SPRAY_EPSILON = 0.005

local ammo = 0
local reserve = 0
local accuracyState = Accuracy.NewState()
local firing = false
local semiLatch = false
local burstRemaining = 0
local nextShotAt = 0
local reloadRequested = false
local reloadRequestId = 0
local seq = 0
local lastCone = -1
local rng = Random.new()
local animationSet = nil
local boundCharacterAnimator: Animator? = nil
local boundViewmodelAnimator: Animator? = nil
local reloadStance = "Idle"
local sprinting = false

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

local function characterAnimator(): Animator?
    local model = character()
    local humanoid = model and model:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

local function destroyAnimations()
    if animationSet then
        animationSet:Destroy()
        animationSet = nil
    end
    boundCharacterAnimator = nil
    boundViewmodelAnimator = nil
end

local function buildAnimations(config)
    destroyAnimations()
    if config then
        animationSet = Animations.NewSet(config)
    end
end

-- The viewmodel is rebuilt on every view and weapon change and the character on every spawn,
-- so the set follows whatever Animator is there now instead of trusting a start order.
local function syncAnimators()
    if not animationSet then
        return
    end
    local own = characterAnimator()
    if own ~= boundCharacterAnimator then
        animationSet:Unbind(boundCharacterAnimator)
        animationSet:Bind(own)
        boundCharacterAnimator = own
    end
    local viewmodel = ViewmodelController.GetAnimator()
    if viewmodel ~= boundViewmodelAnimator then
        animationSet:Unbind(boundViewmodelAnimator)
        animationSet:Bind(viewmodel)
        boundViewmodelAnimator = viewmodel
    end
end

local function desiredStance(): string?
    local state = Client.State
    local set = animationSet
    if not set or not state or not isAlive() then
        return nil
    end
    local equipState = state.EquipState
    if equipState == "Holstered" then
        return nil
    elseif equipState == "Reloading" then
        return reloadStance
    elseif equipState ~= "Ready" then
        return "Relaxed"
    elseif Client.Aiming then
        return set:Pick("Aim", "Idle")
    elseif sprinting then
        return set:Pick("Sprint", "Idle")
    end
    return "Idle"
end

local function refreshStance()
    local set = animationSet
    if not set then
        return
    end
    local stance = desiredStance()
    if stance and set:Has(stance) then
        set:Play(stance)
    elseif set.Stance then
        set:StopAll()
    end
end

local function playReload(state)
    local set = animationSet
    local config = cfg()
    if not set or not config then
        return
    end
    local empty = state.Ammo <= 0
    set:Play(if empty then set:Pick("ReloadEmpty", "Reload") else set:Pick("Reload"))
end

-- Asks for a reload when one makes sense: something missing and somewhere to take it from.
local function requestReload()
    local config = cfg()
    if not config or not Client.IsHolding() or not isAlive() then
        return
    end
    if ammo >= config.Magazine or reserve <= 0 then
        return
    end
    -- The shots already sent count; from here on the trigger does nothing until the server
    -- answers, so no shot leaves after the reload request and gets rejected behind it.
    reloadRequested = true
    firing = false
    burstRemaining = 0
    semiLatch = false
    reloadRequestId += 1
    local id = reloadRequestId
    task.delay(RELOAD_REQUEST_TIMEOUT, function()
        if reloadRequestId == id then
            reloadRequested = false
        end
    end)
    Remotes.FireServer("Reload")
end

local function setAiming(aiming: boolean)
    if Client.Aiming == aiming then
        return
    end
    Client.Aiming = aiming
    accuracyState.AimStartedAt = if aiming then os.clock() else nil
    Signals.AimChanged:Fire(aiming)
    Remotes.FireServer("Aim", aiming)
    refreshStance()
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
    ShotDebug.Log(string.format(
        "[Azazel:Shot] #%d %s%s\n  camera=%s look=%s\n  aimHit=%s aimTarget=%s aimDist=%.1f\n  head=%s dir=%s dot=%.3f angleFromLook=%.2f fallback=%s cone=%.2f\n  muzzle=%s muzzleToHead=%.2f muzzleSource=%s\n%s",
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
        info.MuzzleSource,
        table.concat(pelletLines, "\n")
    ))
end

local function available(): boolean
    return Client.IsReady() and ammo > 0 and isAlive() and not reloadRequested
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
    local muzzlePoint, muzzleSource = WeaponModel.FindPoint(Client.ViewmodelWeapon or WeaponModel.Find(model), "Muzzle")
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
        Muzzle = muzzlePoint and muzzlePoint.Position or nil,
        MuzzleSource = if muzzleSource then `{muzzleSource.ClassName} {muzzleSource:GetFullName()}` else "none (Handle center fallback)",
        Pellets = pellets,
    })
    Signals.LocalShot:Fire(origin, ends, config)
    Signals.Recoil:Fire(config.Recoil.Camera.Pitch, config.Recoil.Camera.Yaw * rng:NextNumber(-1, 1))
    Remotes.FireServer("Fire", origin, direction, seq)
end

local function heartbeat()
    syncAnimators()
    refreshStance()
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
    local previousEquipState = previous and previous.EquipState
    Client.State = state
    reloadRequested = false
    local config = if state.Weapon then WeaponConfig.Get(state.Weapon) else nil
    Client.Config = config
    ammo = state.Ammo
    reserve = state.Reserve
    if state.Weapon ~= previousWeapon or state.Slot ~= (previous and previous.Slot) then
        accuracyState = Accuracy.NewState()
        burstRemaining = 0
        semiLatch = false
        buildAnimations(config)
        Signals.WeaponChanged:Fire(config)
    end
    if state.EquipState ~= "Ready" and Client.Aiming then
        setAiming(false)
    end
    -- Drawing is instant; the optional Equip clip plays over the Relaxed stance it lands on.
    if state.EquipState == "Relaxed" and previousEquipState ~= "Relaxed" and previousEquipState ~= "Reloading" and animationSet then
        syncAnimators()
        animationSet:Play("Equip")
    end
    if state.EquipState == "Reloading" and previousEquipState ~= "Reloading" then
        reloadStance = if previousEquipState == "Relaxed" then "Relaxed" else "Idle"
        syncAnimators()
        playReload(state)
    end
    syncAnimators()
    refreshStance()
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
            -- The trigger on a dry magazine is the reload.
            if ammo <= 0 and Client.IsReady() then
                requestReload()
            end
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
        if pressed and not Client.IsReady() then
            return
        end
        setAiming(pressed)
    end)

    -- The ready key arms the weapon and lowers it again. Relaxed holds no aim and no shot;
    -- the server is the one that changes the state, this only asks.
    Signals.ReadyInput:Connect(function()
        local state = Client.State
        if not state or not isAlive() or not Client.IsHolding() then
            return
        end
        local relaxed = state.EquipState == "Ready"
        if relaxed then
            setAiming(false)
        end
        Remotes.FireServer("Relax", relaxed)
    end)

    Signals.SprintInput:Connect(function(pressed)
        sprinting = pressed
        refreshStance()
    end)

    Signals.ReloadInput:Connect(requestReload)

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
    task.spawn(Animations.Preload)
    task.defer(Remotes.FireServer, "Ready")
end

return WeaponController
