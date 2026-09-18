local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Client = require(script.Parent.Parent)
local package = script.Parent.Parent.Parent
local Settings = require(package.Config.Settings)
local Rig = require(package.Shared.Rig)
local WeaponModel = require(package.Shared.WeaponModel)
local Trove = require(package.Packages.Trove)
local Spr = require(package.Packages.Spr)
local Observers = require(package.Packages.Observers)

local CameraController = {}

local Signals = Client.Signals
local CameraSettings = Settings.Camera
local ViewmodelSettings = Settings.Viewmodel

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
local hiddenNames: { [string]: boolean } = {}
local visibilityPending = false
local controlling = false
local preferredView = CameraSettings.DefaultView

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

local function setHidden(part: Instance, hidden: boolean)
    if part:IsA("BasePart") then
        part.LocalTransparencyModifier = if hidden then 1 else 0
    elseif part:IsA("Decal") then
        part.Transparency = if hidden then 1 else 0
    end
end

-- The body part an accessory hangs from: its weld when it exists, else the part that carries
-- the attachment of the same name as the one in the handle.
local function accessoryPart(accessory: Accessory): BasePart?
    local handle = accessory:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") or not character then
        return nil
    end
    local weld = handle:FindFirstChildOfClass("Weld")
    local welded = weld and (if weld.Part0 == handle then weld.Part1 else weld.Part0)
    if welded then
        return welded
    end
    local attachment = handle:FindFirstChildOfClass("Attachment")
    if attachment then
        for _, child in character:GetChildren() do
            if child:IsA("BasePart") and child:FindFirstChild(attachment.Name) then
                return child
            end
        end
    end
    return nil
end

-- With ShowBody the real body stays; only the head, the arms, what hangs from them and the
-- held weapon go, and the viewmodel draws the arms. Without it the whole character goes.
local function hiddenInFirstPerson(instance: Instance, weapon: Model?): boolean
    if not ViewmodelSettings.ShowBody then
        return true
    end
    if weapon and instance:IsDescendantOf(weapon) then
        return true
    end
    local accessory = instance:FindFirstAncestorOfClass("Accessory")
    if accessory then
        local part = accessoryPart(accessory)
        return part == nil or hiddenNames[part.Name] == true
    end
    if instance:IsA("Decal") then
        local parent = instance.Parent
        return parent ~= nil and hiddenNames[parent.Name] == true
    end
    return hiddenNames[instance.Name] == true
end

local function applyCharacterVisibility()
    if not character then
        return
    end
    local hide = isFirstPerson()
    local weapon = WeaponModel.Find(character)
    for _, descendant in character:GetDescendants() do
        if descendant:IsA("BasePart") or descendant:IsA("Decal") then
            setHidden(descendant, hide and hiddenInFirstPerson(descendant, weapon))
        end
    end
end

-- Accessories and the weapon arrive piece by piece (handle, then its weld); one deferred pass
-- sees them whole.
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

-- The package owns the camera only while the weapon is armed (Ready, or a reload started
-- there). Relaxed and Holstered are plain Roblox: its camera, its cursor, its own zoom and the
-- character free to face where it walks.
local function armed(): boolean
    return Client.IsArmed()
end

local function releaseControl()
    if not controlling then
        return
    end
    controlling = false
    local cam = camera()
    cam.CameraType = Enum.CameraType.Custom
    cam.FieldOfView = CameraSettings.FovDefault
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true
    if humanoid then
        humanoid.AutoRotate = true
    end
    if isFirstPerson() then
        Client.View = "Third"
        applyCharacterVisibility()
        Signals.ViewChanged:Fire(Client.View)
    end
end

-- Picks up where the Roblox camera was looking, so arming never snaps the view, and comes
-- back in the view the player last chose with V.
local function takeControl()
    if controlling then
        return
    end
    controlling = true
    local x, y = camera().CFrame:ToEulerAnglesYXZ()
    pitch = math.clamp(math.deg(x), CameraSettings.PitchLimits.Min, CameraSettings.PitchLimits.Max)
    yaw = math.deg(y)
    recoilPitch = 0
    recoilYaw = 0
    mouseDelta = Vector2.zero
    if preferredView == "First" and not isFirstPerson() then
        Client.View = "First"
        applyCharacterVisibility()
        Signals.ViewChanged:Fire(Client.View)
    end
end

local function step(dt: number)
    if not armed() then
        releaseControl()
        return
    end
    takeControl()
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
        -- The eye is the head at rest and the weapon's Sight while aiming: the camera goes to
        -- the weapon, the arms stay where the clip holds them.
        position = rootPart.Position + CameraSettings.FirstPersonOffset
        local sight = Client.SightOffset
        if sight then
            position += rotation:VectorToWorldSpace(sight * aimValue.Value)
        end
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
    hiddenNames = {}
    if not newCharacter then
        return
    end
    local trove = Trove.new()
    humanoid = newCharacter:WaitForChild("Humanoid", 10) :: Humanoid?
    local rig = Rig.Get(newCharacter)
    if not rig then
        return trove
    end
    for _, name in rig.FirstPersonHidden do
        hiddenNames[name] = true
    end
    rootPart = newCharacter:WaitForChild(rig.Root, 10) :: BasePart?
    yaw = select(2, camera().CFrame:ToEulerAnglesYXZ())
    yaw = math.deg(yaw)
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
        if not armed() then
            return
        end
        Client.View = if isFirstPerson() then "Third" else "First"
        preferredView = Client.View
        applyCharacterVisibility()
        Signals.ViewChanged:Fire(Client.View)
    end)

    Signals.SwapShoulderInput:Connect(function()
        shoulderSide = -shoulderSide
    end)

    Signals.ZoomInput:Connect(function(direction: number)
        if isFirstPerson() or not armed() then
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
