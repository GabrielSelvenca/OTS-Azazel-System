local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Client = require(script.Parent.Parent)
local package = script.Parent.Parent.Parent
local Settings = require(package.Config.Settings)
local Rig = require(package.Shared.Rig)
local Spring = require(package.Shared.Spring)
local WeaponModel = require(package.Shared.WeaponModel)
local Trove = require(package.Packages.Trove)
local Spr = require(package.Packages.Spr)
local Observers = require(package.Packages.Observers)

local ViewmodelController = {}

local Signals = Client.Signals
local ViewmodelSettings = Settings.Viewmodel
local CameraSettings = Settings.Camera

local RENDER_NAME = "AzazelViewmodel"
local RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 1
local MODEL_NAME = "AzazelViewmodel"
local KEEP_CLASSES = { Shirt = true, BodyColors = true }

local character: Model? = nil
local characterRoot: BasePart? = nil
local characterTrove = nil
local viewmodel: Model? = nil
local viewmodelRoot: BasePart? = nil
local viewmodelWeapon: Model? = nil
local sightPoint: Instance? = nil
local weaponConfig = nil
local mouseDelta = Vector2.zero
local bobTime = 0

local warnedNoSight: { [string]: boolean } = {}

local swaySpring = Spring.new(ViewmodelSettings.Sway.Damping, ViewmodelSettings.Sway.Frequency)
local bobSpring = Spring.new(1, 8)
local adsValue = Instance.new("NumberValue")

local function camera(): Camera
    return workspace.CurrentCamera
end

-- The clone stands where the real body stands, turned with the camera about the eye, so a clip
-- lands in first person exactly as it does on the character.
local function bodyCFrame(root: BasePart, rotation: CFrame): CFrame
    local eye = root.Position + CameraSettings.FirstPersonOffset
    return CFrame.new(eye) * rotation * CFrame.new(-CameraSettings.FirstPersonOffset)
end

-- In root space, so it depends on the pose only, not on where the clone stands this frame.
local function publishSight(root: BasePart)
    if sightPoint then
        Client.SightOffset = root.CFrame:PointToObjectSpace(WeaponModel.PointPosition(sightPoint)) - CameraSettings.FirstPersonOffset
    end
end

local function isFirstPerson(): boolean
    return Client.View == "First"
end

local function isAlive(): boolean
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health > 0
end

local function shouldShow(): boolean
    return isFirstPerson() and character ~= nil and isAlive() and Client.Config ~= nil
end

local function preparePart(part: BasePart, isRoot: boolean, hidden: boolean)
    part.Anchored = isRoot
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Massless = true
    part.CastShadow = false
    part.LocalTransparencyModifier = if hidden then 1 else 0
end

-- Only the arms are drawn; the root and torso stay to carry the shoulder joints.
local function stripClone(clone: Model, rig)
    local keepParts = {}
    for _, name in rig.ViewmodelKeep do
        keepParts[name] = true
    end
    local keepJoints = {}
    for _, name in rig.ViewmodelJoints do
        keepJoints[name] = true
    end
    local shownParts = {}
    for _, name in rig.ViewmodelShown do
        shownParts[name] = true
    end
    for _, child in clone:GetChildren() do
        local keep = (child:IsA("BasePart") and keepParts[child.Name]) or KEEP_CLASSES[child.ClassName]
        if not keep then
            child:Destroy()
        end
    end
    for _, descendant in clone:GetDescendants() do
        local staleJoint = descendant:IsA("JointInstance") and not keepJoints[descendant.Name]
        if descendant:IsA("LuaSourceContainer") or staleJoint then
            descendant:Destroy()
        elseif descendant:IsA("BasePart") then
            local isRoot = descendant.Name == rig.Root
            preparePart(descendant, isRoot, isRoot or not shownParts[descendant.Name])
        end
    end
end

local function destroyWeapon()
    if viewmodel then
        WeaponModel.Detach(viewmodel)
    end
    viewmodelWeapon = nil
    sightPoint = nil
    Client.ViewmodelWeapon = nil
    Client.SightOffset = nil
end

local function attachWeapon()
    destroyWeapon()
    if not viewmodel or not weaponConfig then
        return
    end
    local model = WeaponModel.Clone(weaponConfig)
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.CastShadow = false
        end
    end
    WeaponModel.Attach(viewmodel, model, weaponConfig)
    viewmodelWeapon = model
    sightPoint = WeaponModel.FindPoint(model, "Sight")
    Client.ViewmodelWeapon = model
end

local function destroyViewmodel()
    destroyWeapon()
    if viewmodel then
        viewmodel:Destroy()
    end
    viewmodel = nil
    viewmodelRoot = nil
end

local function buildViewmodel()
    destroyViewmodel()
    local source = character
    local rig = Rig.Get(source)
    if not source or not rig then
        return
    end
    local wasArchivable = source.Archivable
    source.Archivable = true
    local clone = source:Clone()
    source.Archivable = wasArchivable
    if not clone then
        return
    end
    clone.Name = MODEL_NAME
    clone:SetAttribute(Rig.Attribute, rig.Name)
    stripClone(clone, rig)
    local root = clone:FindFirstChild(rig.Root)
    if not root or not root:IsA("BasePart") then
        clone:Destroy()
        return
    end
    clone.PrimaryPart = root

    local animationController = Instance.new("AnimationController")
    local animator = Instance.new("Animator")
    animator.Parent = animationController
    animationController.Parent = clone

    clone.Parent = camera()
    viewmodel = clone
    viewmodelRoot = root
    attachWeapon()
end

local function refresh()
    if shouldShow() then
        if not viewmodel then
            buildViewmodel()
        end
    else
        destroyViewmodel()
    end
end

local function retargetAds()
    local cfg = Client.Config
    local aiming = Client.Aiming and cfg ~= nil
    local seconds = if cfg then cfg.Ads.Time else 0.15
    Spr.target(adsValue, 1, 1 / math.max(seconds, 0.05), { Value = if aiming then 1 else 0 })
    if aiming and viewmodelWeapon and not sightPoint and not warnedNoSight[cfg.Name] then
        warnedNoSight[cfg.Name] = true
        warn(`[Azazel] {cfg.Name}: the model has no Sight (an Attachment or a Part named Sight); the camera stays at the head while aiming`)
    end
end

local function step(dt: number)
    local root = viewmodelRoot
    local body = characterRoot
    local cfg = Client.Config
    if not viewmodel or not root or not body or not cfg then
        return
    end
    local rotation = camera().CFrame.Rotation
    local aim = adsValue.Value

    local sway = ViewmodelSettings.Sway
    local swayTarget = Vector3.new(-mouseDelta.X, -mouseDelta.Y, 0) * (sway.Amount * 0.1)
    swayTarget = Vector3.new(
        math.clamp(swayTarget.X, -sway.Clamp, sway.Clamp),
        math.clamp(swayTarget.Y, -sway.Clamp, sway.Clamp),
        0
    ) * (1 - aim * (1 - ViewmodelSettings.AimSwayMultiplier))
    mouseDelta = Vector2.zero
    swaySpring.Target = swayTarget
    local swayNow = swaySpring:Step(dt)

    local bob = ViewmodelSettings.Bob
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local moving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1 and humanoid.FloorMaterial ~= Enum.Material.Air
    if moving then
        bobTime += dt * bob.Speed
        bobSpring.Target = Vector3.new(math.sin(bobTime) * bob.X, math.sin(bobTime * 2) * bob.Y, 0)
            * (1 - aim * (1 - ViewmodelSettings.AimBobMultiplier))
    else
        bobSpring.Target = Vector3.zero
    end
    local bobNow = bobSpring:Step(dt)

    publishSight(root)
    root.CFrame = bodyCFrame(body, rotation)
        * CFrame.Angles(swayNow.Y, swayNow.X, swayNow.X * 0.5)
        * CFrame.new(bobNow.X, bobNow.Y, 0)
end

local function onCharacter(newCharacter: Model?)
    if characterTrove then
        characterTrove:Destroy()
        characterTrove = nil
    end
    character = newCharacter
    characterRoot = nil
    destroyViewmodel()
    if not newCharacter then
        return
    end
    local trove = Trove.new()
    characterTrove = trove
    local humanoid = newCharacter:WaitForChild("Humanoid", 10)
    if humanoid and humanoid:IsA("Humanoid") then
        trove:Connect(humanoid.Died, destroyViewmodel)
    end
    local rig = Rig.Get(newCharacter)
    if rig then
        characterRoot = newCharacter:WaitForChild(rig.Root, 10) :: BasePart?
    end
    refresh()
end

function ViewmodelController.GetAnimator(): Animator?
    local controller = viewmodel and viewmodel:FindFirstChildOfClass("AnimationController")
    return controller and controller:FindFirstChildOfClass("Animator")
end

function ViewmodelController.Start()
    weaponConfig = Client.Config
    adsValue.Value = 0

    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            mouseDelta += Vector2.new(input.Delta.X, input.Delta.Y)
        end
    end)

    Signals.ViewChanged:Connect(refresh)
    Signals.WeaponChanged:Connect(function(cfg)
        weaponConfig = cfg
        local existed = viewmodel ~= nil
        refresh()
        if existed and viewmodel then
            attachWeapon()
        end
        retargetAds()
    end)
    Signals.AimChanged:Connect(retargetAds)

    Observers.observeLocalCharacter(function(newCharacter)
        onCharacter(newCharacter)
        return function()
            if character == newCharacter then
                onCharacter(nil)
            end
        end
    end)

    retargetAds()
    RunService:BindToRenderStep(RENDER_NAME, RENDER_PRIORITY, step)
end

return ViewmodelController
