local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Client = require(script.Parent.Parent)
local package = script.Parent.Parent.Parent
local Settings = require(package.Config.Settings)
local Rig = require(package.Shared.Rig)
local Trove = require(package.Packages.Trove)
local Spr = require(package.Packages.Spr)
local Observers = require(package.Packages.Observers)

-- Owns the camera only while armed (Client.IsArmed); otherwise the Roblox camera runs as usual.
local CameraController = {}

local Signals = Client.Signals
local CameraSettings = Settings.Camera

local RENDER_NAME = "AzazelCamera"
local RENDER_PRIORITY = Enum.RenderPriority.Camera.Value

local yaw = 0
local pitch = 0
local shoulderSide = 1
local zoomDistance = CameraSettings.Distance
local recoilPitch = 0
local recoilYaw = 0
local mouseDelta = Vector2.zero
local character: Model? = nil
local humanoid: Humanoid? = nil
local rootPart: BasePart? = nil
local visibilityPending = false
local controlling = false
local preferredView = CameraSettings.DefaultView
local released = { FieldOfView = CameraSettings.FovDefault, MouseBehavior = Enum.MouseBehavior.Default, MouseIconEnabled = true }

local collisionParams = RaycastParams.new()
collisionParams.FilterType = Enum.RaycastFilterType.Exclude

local fovValue = Instance.new("NumberValue")
fovValue.Value = CameraSettings.FovDefault
local distanceValue = Instance.new("NumberValue")
distanceValue.Value = CameraSettings.Distance
local shoulderValue = Instance.new("Vector3Value")
shoulderValue.Value = CameraSettings.Shoulder
local aimValue = Instance.new("NumberValue")
aimValue.Value = 0

local function camera(): Camera
    return workspace.CurrentCamera
end

local function alphaFor(seconds: number, dt: number): number
    if seconds <= 0 then
        return 1
    end
    return 1 - math.exp(-dt / seconds)
end

local function isFirstPerson(): boolean
    return Client.View == "First"
end

-- First person hides the whole character; the viewmodel draws the arms and the weapon.
local function applyCharacterVisibility()
    if not character then
        return
    end
    local hidden = if isFirstPerson() then 1 else 0
    for _, descendant in character:GetDescendants() do
        if descendant:IsA("BasePart") or descendant:IsA("Decal") then
            descendant.LocalTransparencyModifier = hidden
        end
    end
end

-- Accessories and the weapon arrive piece by piece; one deferred pass sees them whole.
local function scheduleVisibility()
    if visibilityPending then
        return
    end
    visibilityPending = true
    task.defer(function()
        visibilityPending = false
        applyCharacterVisibility()
    end)
end

local function setView(view: string)
    Client.View = view
    applyCharacterVisibility()
    Signals.ViewChanged:Fire(view)
end

local function retarget()
    local cfg = Client.Config
    local aiming = Client.Aiming and cfg ~= nil
    local targetFov = if aiming then cfg.Ads.Fov else CameraSettings.FovDefault
    local targetDistance = if aiming then cfg.Ads.Distance else zoomDistance
    local targetShoulder = if aiming then cfg.Ads.Shoulder else CameraSettings.Shoulder
    local seconds = if cfg then cfg.Ads.Time else 0.15
    Spr.target(fovValue, CameraSettings.FovDamping, CameraSettings.FovFrequency, { Value = targetFov })
    Spr.target(distanceValue, CameraSettings.DistanceDamping, CameraSettings.DistanceFrequency, { Value = targetDistance })
    Spr.target(shoulderValue, CameraSettings.DistanceDamping, CameraSettings.DistanceFrequency, { Value = targetShoulder })
    Spr.target(aimValue, 1, 1 / math.max(seconds, 0.05), { Value = if aiming then 1 else 0 })
end

local function collide(from: Vector3, to: Vector3): Vector3
    local offset = to - from
    if offset.Magnitude < 0.01 then
        return to
    end
    local result = workspace:Spherecast(from, CameraSettings.CollisionRadius, offset, collisionParams)
    return if result then from + offset.Unit * result.Distance else to
end

local function releaseControl()
    if not controlling then
        return
    end
    controlling = false
    local cam = camera()
    cam.CameraType = Enum.CameraType.Custom
    cam.FieldOfView = released.FieldOfView
    UserInputService.MouseBehavior = released.MouseBehavior
    UserInputService.MouseIconEnabled = released.MouseIconEnabled
    if humanoid then
        humanoid.AutoRotate = true
    end
    if isFirstPerson() then
        setView("Third")
    end
end

-- Starts from the Roblox camera's angles so arming never snaps the view.
local function takeControl()
    if controlling then
        return
    end
    controlling = true
    local cam = camera()
    released = {
        FieldOfView = cam.FieldOfView,
        MouseBehavior = UserInputService.MouseBehavior,
        MouseIconEnabled = UserInputService.MouseIconEnabled,
    }
    local x, y = cam.CFrame:ToEulerAnglesYXZ()
    pitch = math.clamp(math.deg(x), CameraSettings.PitchLimits.Min, CameraSettings.PitchLimits.Max)
    yaw = math.deg(y)
    recoilPitch = 0
    recoilYaw = 0
    mouseDelta = Vector2.zero
    if preferredView == "First" and not isFirstPerson() then
        setView("First")
    end
end

local function step(dt: number)
    if not Client.IsArmed() then
        releaseControl()
        return
    end
    takeControl()
    local cam = camera()
    cam.CameraType = Enum.CameraType.Scriptable
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    UserInputService.MouseIconEnabled = false

    local limits = CameraSettings.PitchLimits
    local sensitivity = CameraSettings.Sensitivity * UserInputService.MouseDeltaSensitivity
    yaw -= mouseDelta.X * sensitivity
    pitch = math.clamp(pitch - mouseDelta.Y * sensitivity, limits.Min, limits.Max)
    mouseDelta = Vector2.zero

    local recovery = alphaFor(CameraSettings.RecoilRecovery, dt)
    recoilPitch -= recoilPitch * recovery
    recoilYaw -= recoilYaw * recovery

    local totalYaw = math.rad(yaw + recoilYaw)
    local totalPitch = math.rad(math.clamp(pitch + recoilPitch, limits.Min, limits.Max))
    local rotation = CFrame.fromEulerAnglesYXZ(totalPitch, totalYaw, 0)

    if not rootPart then
        return
    end

    if CameraSettings.RotateCharacter and humanoid and humanoid.Health > 0 and not humanoid.Sit then
        humanoid.AutoRotate = false
        local targetLook = CFrame.new(rootPart.Position) * CFrame.Angles(0, totalYaw, 0)
        rootPart.CFrame = rootPart.CFrame:Lerp(targetLook, alphaFor(CameraSettings.TurnSmoothing, dt))
    end

    cam.FieldOfView = fovValue.Value
    local position
    if isFirstPerson() then
        -- Aiming slides the eye onto the weapon's Sight; the arms stay where the clip holds them.
        position = rootPart.Position + CameraSettings.FirstPersonOffset
        local sight = Client.SightOffset
        if sight then
            position += rotation:VectorToWorldSpace(sight * aimValue.Value)
        end
    else
        local pivot = rootPart.Position + CameraSettings.PivotOffset
        local shoulder = shoulderValue.Value
        local anchor = pivot + rotation:VectorToWorldSpace(Vector3.new(shoulder.X * shoulderSide, shoulder.Y, shoulder.Z))
        local desired = anchor + rotation.LookVector * -distanceValue.Value
        position = collide(collide(pivot, anchor), desired)
    end
    cam.CFrame = CFrame.new(position) * rotation
end

local function onCharacter(newCharacter: Model?)
    character = newCharacter
    humanoid = nil
    rootPart = nil
    if not newCharacter then
        return
    end
    collisionParams.FilterDescendantsInstances = { newCharacter, camera() }
    local trove = Trove.new()
    humanoid = newCharacter:WaitForChild("Humanoid", 10) :: Humanoid?
    local rig = Rig.Get(newCharacter)
    if not rig then
        return trove
    end
    rootPart = newCharacter:WaitForChild(rig.Root, 10) :: BasePart?
    yaw = math.deg(select(2, camera().CFrame:ToEulerAnglesYXZ()))
    pitch = 0
    applyCharacterVisibility()
    trove:Connect(newCharacter.DescendantAdded, function()
        if isFirstPerson() then
            scheduleVisibility()
        end
    end)
    trove:Add(function()
        if humanoid then
            humanoid.AutoRotate = true
        end
    end)
    return trove
end

function CameraController.GetAimRay(): (Vector3, Vector3)
    local cf = camera().CFrame
    return cf.Position, cf.LookVector
end

function CameraController.Kick(pitchDegrees: number, yawDegrees: number)
    recoilPitch += pitchDegrees
    recoilYaw += yawDegrees
end

function CameraController.Start()
    Client.View = "Third"

    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            mouseDelta += Vector2.new(input.Delta.X, input.Delta.Y)
        end
    end)

    Signals.ToggleViewInput:Connect(function()
        if not Client.IsArmed() then
            return
        end
        preferredView = if isFirstPerson() then "Third" else "First"
        setView(preferredView)
    end)

    Signals.SwapShoulderInput:Connect(function()
        shoulderSide = -shoulderSide
    end)

    Signals.ZoomInput:Connect(function(direction: number)
        if isFirstPerson() or not Client.IsArmed() then
            return
        end
        zoomDistance = math.clamp(zoomDistance - direction * CameraSettings.ZoomStep, CameraSettings.MinDistance, CameraSettings.MaxDistance)
        retarget()
    end)

    Signals.AimChanged:Connect(retarget)
    Signals.WeaponChanged:Connect(retarget)
    Signals.Recoil:Connect(CameraController.Kick)

    Observers.observeLocalCharacter(function(newCharacter)
        local trove = onCharacter(newCharacter)
        return function()
            if trove then
                trove:Destroy()
            end
            if character == newCharacter then
                onCharacter(nil)
            end
        end
    end)

    retarget()
    RunService:BindToRenderStep(RENDER_NAME, RENDER_PRIORITY, step)
end

return CameraController
