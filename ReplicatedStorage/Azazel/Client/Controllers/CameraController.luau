local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Client = require(script.Parent.Parent)
local package = script.Parent.Parent.Parent
local Settings = require(package.Config.Settings)
local Rig = require(package.Shared.Rig)
local Trove = require(package.Packages.Trove)
local Spr = require(package.Packages.Spr)
local Observers = require(package.Packages.Observers)

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
local hiddenParts: { [BasePart]: boolean } = {}

local fovValue = Instance.new("NumberValue")
fovValue.Value = CameraSettings.FovDefault
local distanceValue = Instance.new("NumberValue")
distanceValue.Value = CameraSettings.Distance
local shoulderValue = Instance.new("Vector3Value")
shoulderValue.Value = CameraSettings.Shoulder

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

local function setHidden(part: Instance, hidden: boolean)
    if part:IsA("BasePart") then
        part.LocalTransparencyModifier = if hidden then 1 else 0
        hiddenParts[part] = hidden or nil
    elseif part:IsA("Decal") then
        part.Transparency = if hidden then 1 else 0
    end
end

local function applyCharacterVisibility()
    if not character then
        return
    end
    local hide = isFirstPerson() and Settings.Viewmodel.HideCharacterInFirstPerson
    for _, descendant in character:GetDescendants() do
        if descendant:IsA("BasePart") or descendant:IsA("Decal") then
            setHidden(descendant, hide)
        end
    end
end

local function retarget()
    local cfg = Client.Config
    local aiming = Client.Aiming and cfg ~= nil
    local targetFov = if aiming then cfg.Ads.Fov else CameraSettings.FovDefault
    local targetDistance = if aiming then cfg.Ads.Distance else zoomDistance
    local targetShoulder = if aiming then cfg.Ads.Shoulder else CameraSettings.Shoulder
    Spr.target(fovValue, CameraSettings.FovDamping, CameraSettings.FovFrequency, { Value = targetFov })
    Spr.target(distanceValue, CameraSettings.DistanceDamping, CameraSettings.DistanceFrequency, { Value = targetDistance })
    Spr.target(shoulderValue, CameraSettings.DistanceDamping, CameraSettings.DistanceFrequency, { Value = targetShoulder })
end

local function collide(from: Vector3, to: Vector3): Vector3
    if not character then
        return to
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character, camera() }
    local offset = to - from
    if offset.Magnitude < 0.01 then
        return to
    end
    local result = workspace:Raycast(from, offset, params)
    if result then
        return result.Position + result.Normal * CameraSettings.CollisionRadius
    end
    return to
end

local function step(dt: number)
    local cam = camera()
    cam.CameraType = Enum.CameraType.Scriptable
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    UserInputService.MouseIconEnabled = false

    local sensitivity = CameraSettings.Sensitivity * UserInputService.MouseDeltaSensitivity
    yaw -= mouseDelta.X * sensitivity
    pitch = math.clamp(pitch - mouseDelta.Y * sensitivity, CameraSettings.PitchLimits.Min, CameraSettings.PitchLimits.Max)
    mouseDelta = Vector2.zero

    local recovery = alphaFor(CameraSettings.RecoilRecovery, dt)
    recoilPitch -= recoilPitch * recovery
    recoilYaw -= recoilYaw * recovery

    local totalYaw = math.rad(yaw + recoilYaw)
    local totalPitch = math.rad(pitch + recoilPitch)
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
    local pivot = rootPart.Position + CameraSettings.PivotOffset
    local position
    if isFirstPerson() then
        position = rootPart.Position + CameraSettings.FirstPersonOffset
    else
        local shoulder = shoulderValue.Value
        local shoulderOffset = Vector3.new(shoulder.X * shoulderSide, shoulder.Y, shoulder.Z)
        local anchor = pivot + rotation:VectorToWorldSpace(shoulderOffset)
        local desired = anchor + rotation.LookVector * -distanceValue.Value
        position = collide(collide(pivot, anchor), desired)
    end
    cam.CFrame = CFrame.new(position) * rotation
end

local function onCharacter(newCharacter: Model?)
    character = newCharacter
    humanoid = nil
    rootPart = nil
    hiddenParts = {}
    if not newCharacter then
        return
    end
    local trove = Trove.new()
    humanoid = newCharacter:WaitForChild("Humanoid", 10) :: Humanoid?
    local rig = Rig.Get(newCharacter)
    if not rig then
        return trove
    end
    rootPart = newCharacter:WaitForChild(rig.Root, 10) :: BasePart?
    yaw = select(2, camera().CFrame:ToEulerAnglesYXZ())
    yaw = math.deg(yaw)
    pitch = 0
    applyCharacterVisibility()
    trove:Connect(newCharacter.DescendantAdded, function(descendant)
        if isFirstPerson() then
            setHidden(descendant, true)
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

function CameraController.GetYaw(): number
    return yaw
end

function CameraController.Kick(pitchDegrees: number, yawDegrees: number)
    recoilPitch += pitchDegrees
    recoilYaw += yawDegrees
end

function CameraController.Start()
    Client.View = CameraSettings.DefaultView

    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            mouseDelta += Vector2.new(input.Delta.X, input.Delta.Y)
        end
    end)

    Signals.ToggleViewInput:Connect(function()
        Client.View = if isFirstPerson() then "Third" else "First"
        applyCharacterVisibility()
        Signals.ViewChanged:Fire(Client.View)
    end)

    Signals.SwapShoulderInput:Connect(function()
        shoulderSide = -shoulderSide
    end)

    Signals.ZoomInput:Connect(function(direction: number)
        if isFirstPerson() then
            return
        end
        zoomDistance = math.clamp(zoomDistance - direction * CameraSettings.ZoomStep, CameraSettings.MinDistance, CameraSettings.MaxDistance)
        retarget()
    end)

    Signals.AimChanged:Connect(retarget)
    Signals.WeaponChanged:Connect(retarget)

    Signals.Recoil:Connect(function(pitchDegrees, yawDegrees)
        CameraController.Kick(pitchDegrees, yawDegrees)
    end)

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
