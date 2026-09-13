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

local RENDER_NAME = "AzazelViewmodel"
local RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 1
local MODEL_NAME = "AzazelViewmodel"
local KEEP_CLASSES = { Shirt = true, BodyColors = true }

local character: Model? = nil
local characterTrove = nil
local viewmodel: Model? = nil
local viewmodelRoot: BasePart? = nil
local viewmodelWeapon: Model? = nil
local weaponConfig = nil
local mouseDelta = Vector2.zero
local bobTime = 0

local swaySpring = Spring.new(ViewmodelSettings.Sway.Damping, ViewmodelSettings.Sway.Frequency)
local bobSpring = Spring.new(1, 8)
local recoilSpring = Spring.new(0.6, 12)
local adsValue = Instance.new("NumberValue")

local function camera(): Camera
    return workspace.CurrentCamera
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

local function preparePart(part: BasePart, isRoot: boolean)
    part.Anchored = isRoot
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Massless = true
    part.CastShadow = false
    part.LocalTransparencyModifier = 0
    if isRoot then
        part.Transparency = 1
    end
end

local function stripClone(clone: Model, rig)
    local keepParts = {}
    for _, name in rig.ViewmodelKeep do
        keepParts[name] = true
    end
    local keepJoints = {}
    for _, name in rig.ViewmodelJoints do
        keepJoints[name] = true
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
            preparePart(descendant, descendant.Name == rig.Root)
        end
    end
end

local function destroyWeapon()
    if viewmodel then
        WeaponModel.Detach(viewmodel)
    end
    viewmodelWeapon = nil
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
end

local function sightCFrame(cameraCFrame: CFrame, root: BasePart, cfg): CFrame
    local hip = cameraCFrame * ViewmodelSettings.Offset
    local sight = WeaponModel.FindAttachment(viewmodelWeapon, "Sight")
    if not sight then
        return hip * cfg.Ads.ViewmodelOffset
    end
    local sightOffset = root.CFrame:PointToObjectSpace(sight.WorldPosition)
    local sightTarget = cameraCFrame * CFrame.new(0, 0, -cfg.Ads.SightDistance)
    return CFrame.new(sightTarget.Position - cameraCFrame:VectorToWorldSpace(sightOffset)) * cameraCFrame.Rotation
end

local function step(dt: number)
    local root = viewmodelRoot
    local cfg = Client.Config
    if not viewmodel or not root or not cfg then
        return
    end
    local cameraCFrame = camera().CFrame
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
    local recoilNow = recoilSpring:Step(dt)

    local hip = cameraCFrame * ViewmodelSettings.Offset
    local base = if aim > 0.001 then hip:Lerp(sightCFrame(cameraCFrame, root, cfg), aim) else hip
    root.CFrame = base
        * CFrame.Angles(swayNow.Y, swayNow.X, swayNow.X * 0.5)
        * CFrame.new(bobNow.X, bobNow.Y, 0)
        * CFrame.new(0, 0, recoilNow.Z)
        * CFrame.Angles(math.rad(recoilNow.Y), 0, 0)
end

local function onCharacter(newCharacter: Model?)
    if characterTrove then
        characterTrove:Destroy()
        characterTrove = nil
    end
    character = newCharacter
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
    refresh()
end

function ViewmodelController.GetModel(): Model?
    return viewmodel
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
        recoilSpring.Position = Vector3.zero
        recoilSpring.Velocity = Vector3.zero
        local existed = viewmodel ~= nil
        refresh()
        if existed and viewmodel then
            attachWeapon()
        end
        retargetAds()
    end)
    Signals.AimChanged:Connect(retargetAds)
    Signals.Recoil:Connect(function()
        local cfg = Client.Config
        if not cfg or not viewmodel then
            return
        end
        local recoil = cfg.Recoil.Viewmodel
        recoilSpring.Damping = recoil.Damping
        recoilSpring.Frequency = recoil.Frequency
        recoilSpring:Nudge(Vector3.new(0, recoil.Rise, recoil.Kick))
    end)

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
