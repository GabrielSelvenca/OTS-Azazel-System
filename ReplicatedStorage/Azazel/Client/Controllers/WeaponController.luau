local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Client = require(script.Parent.Parent)
local package = script.Parent.Parent.Parent
local WeaponConfig = require(package.Config.WeaponConfig)
local EquipmentConfig = require(package.Config.EquipmentConfig)
local Accuracy = require(package.Shared.Accuracy)
local Animations = require(package.Shared.Animations)
local Remotes = require(package.Shared.Remotes)
local Rig = require(package.Shared.Rig)
local CameraController = require(script.Parent.CameraController)
local ViewmodelController = require(script.Parent.ViewmodelController)

local WeaponController = {}

local Signals = Client.Signals
local localPlayer = Players.LocalPlayer

local AIM_DOT_MIN = 0.5
local RELOAD_REQUEST_TIMEOUT = 1
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

-- The viewmodel and the character are rebuilt on their own schedule; follow whichever Animators exist now.
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
        set:StopStance()
    end
end

local function playReload(state)
    local set = animationSet
    if not set then
        return
    end
    set:Play(if state.Ammo <= 0 then set:Pick("ReloadEmpty", "Reload") else set:Pick("Reload"))
end

local function requestReload()
    local state = Client.State
    if not state or not Client.IsHolding() or not isAlive() then
        return
    end
    if ammo >= state.Magazine or reserve <= 0 then
        return
    end
    -- Lock the trigger until the server answers, so no shot is sent behind the reload request.
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

local function available(): boolean
    return Client.IsReady() and ammo > 0 and isAlive() and not reloadRequested
end

local function shoot()
    local config = cfg()
    local model = character()
    local rig = Rig.Get(model)
    local head = rig and (model :: Model):FindFirstChild(rig.Head)
    if not config or not head or not head:IsA("BasePart") then
        return
    end
    local params = raycastParams()
    local origin = head.Position
    local cameraPosition, look = CameraController.GetAimRay()
    local aimHit = workspace:Raycast(cameraPosition, look * config.Range, params)
    local direction = (if aimHit then aimHit.Position else cameraPosition + look * config.Range) - origin
    -- The crosshair is on something between the camera and the head: fire along the camera.
    if direction.Magnitude < 0.1 or direction.Unit:Dot(look) < AIM_DOT_MIN then
        direction = look
    end
    direction = direction.Unit

    local cone = Accuracy.Shoot(accuracyState, config, os.clock())
    ammo -= 1
    seq += 1
    Signals.AmmoChanged:Fire(ammo, reserve, config.Magazine)

    local ends = {}
    for pellet = 1, math.max(1, config.Pellets.Count) do
        local aimed = Accuracy.Pellet(direction, cone, config, rng)
        local result = workspace:Raycast(origin, aimed * config.Range, params)
        ends[pellet] = if result then result.Position else origin + aimed * config.Range
    end
    Signals.LocalShot:Fire(origin, ends, config)
    Signals.Recoil:Fire(config.Recoil.Camera.Pitch, config.Recoil.Camera.Yaw * rng:NextNumber(-1, 1))
    Remotes.FireServer("Fire", origin, direction, seq)
end

-- Carries the frame's lateness into the next shot so the real rate matches Rpm.
local function scheduleNext(now: number, interval: number)
    -- no remainder carry: the server rejects shots closer than interval * RateGrace
    nextShotAt = now + interval
end

local function heartbeat()
    syncAnimators()
    refreshStance()
    local config = cfg()
    if not config then
        return
    end
    local now = os.clock()
    local cone = Accuracy.Cone(accuracyState, config, now)
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
    if now < nextShotAt then
        return
    end
    local mode = currentFireMode()
    if mode == "Auto" then
        if firing then
            shoot()
            scheduleNext(now, config.ShotInterval)
        end
    elseif mode == "Semi" then
        if semiLatch then
            semiLatch = false
            shoot()
            scheduleNext(now, config.ShotInterval)
        end
    elseif mode == "Burst" then
        if burstRemaining > 0 then
            burstRemaining -= 1
            shoot()
            scheduleNext(now, if burstRemaining > 0 then config.BurstInterval else config.ShotInterval)
        end
    end
end

local function applyState(state)
    local previous = Client.State
    local previousEquipState = previous and previous.EquipState
    local weaponChanged = previous == nil or state.Weapon ~= previous.Weapon or state.Slot ~= previous.Slot
    Client.State = state
    reloadRequested = false
    local config = if state.Weapon then WeaponConfig.Resolve(state.Weapon, EquipmentConfig.StackModifiers(state.Equipment)) else nil
    Client.Config = config
    -- Shots still in flight are not in the snapshot yet.
    ammo = if weaponChanged then state.Ammo else math.max(state.Ammo - math.max(0, seq - state.LastSeq), 0)
    reserve = state.Reserve
    if weaponChanged then
        accuracyState = Accuracy.NewState()
        burstRemaining = 0
        semiLatch = false
        buildAnimations(config)
        Signals.WeaponChanged:Fire(config)
    end
    if state.EquipState ~= "Ready" and Client.Aiming then
        setAiming(false)
    end
    syncAnimators()
    if weaponChanged and state.EquipState == "Relaxed" and animationSet then
        animationSet:Play("Equip")
    end
    if state.EquipState == "Reloading" and previousEquipState ~= "Reloading" then
        reloadStance = if previousEquipState == "Relaxed" then "Relaxed" else "Idle"
        playReload(state)
    end
    refreshStance()
    Signals.AmmoChanged:Fire(ammo, reserve, state.Magazine)
    Signals.StateChanged:Fire(state)
end

function WeaponController.Start()
    Remotes.OnClient("State", applyState)

    Remotes.OnClient("HitConfirmed", function(zone, damage, killed)
        Signals.HitConfirmed:Fire(zone, damage, killed)
    end)

    Signals.FireInput:Connect(function(pressed)
        if not pressed then
            firing = false
            return
        end
        if not available() then
            if ammo <= 0 and Client.IsReady() then
                requestReload()
            end
            return
        end
        firing = true
        semiLatch = true
        if currentFireMode() == "Burst" and burstRemaining == 0 then
            burstRemaining = cfg().Burst.Count
        end
    end)

    Signals.AimInput:Connect(function(pressed)
        if pressed and not Client.IsReady() then
            return
        end
        setAiming(pressed)
    end)

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
        if not state or not isAlive() or slot == state.Slot then
            return
        end
        if slot ~= 0 and not state.Slots[slot] then
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
        Remotes.FireServer("SetFireMode", state.FireMode % #config.FireModes + 1)
    end)

    RunService.Heartbeat:Connect(heartbeat)
    task.spawn(Animations.Preload)
    task.defer(Remotes.FireServer, "RequestState")
end

return WeaponController
