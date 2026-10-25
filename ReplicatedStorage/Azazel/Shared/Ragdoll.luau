-- A local ragdoll copy of a character: limb Motor6Ds become BallSocketConstraints. The dead
-- Humanoid stays so clothing renders.

local Settings = require(script.Parent.Parent.Config.Settings)

local Ragdoll = {}

Ragdoll.ModelName = "AzazelRagdoll"

local RagdollSettings = Settings.Ragdoll

local function limitsFor(jointName: string)
    return RagdollSettings.Joints[jointName] or RagdollSettings.Joints.Default
end

local function isLimbJoint(joint: Instance, clone: Model): boolean
    if not joint:IsA("Motor6D") then
        return false
    end
    local part0, part1 = joint.Part0, joint.Part1
    return part0 ~= nil and part1 ~= nil and part0.Parent == clone and part1.Parent == clone
end

local function noCollision(a: BasePart?, b: BasePart?, parent: Instance)
    if not a or not b then
        return
    end
    local constraint = Instance.new("NoCollisionConstraint")
    constraint.Part0 = a
    constraint.Part1 = b
    constraint.Parent = parent
end

local function socketFor(motor: Motor6D, colliders: { [BasePart]: BasePart })
    local part0 = motor.Part0 :: BasePart
    local part1 = motor.Part1 :: BasePart
    local limits = limitsFor(motor.Name)

    local attachment0 = Instance.new("Attachment")
    attachment0.Name = motor.Name .. "Socket0"
    attachment0.CFrame = motor.C0
    attachment0.Parent = part0
    local attachment1 = Instance.new("Attachment")
    attachment1.Name = motor.Name .. "Socket1"
    attachment1.CFrame = motor.C1
    attachment1.Parent = part1

    local socket = Instance.new("BallSocketConstraint")
    socket.Name = motor.Name
    socket.Attachment0 = attachment0
    socket.Attachment1 = attachment1
    socket.LimitsEnabled = true
    socket.UpperAngle = limits.UpperAngle
    socket.TwistLimitsEnabled = true
    socket.TwistLowerAngle = -limits.Twist
    socket.TwistUpperAngle = limits.Twist
    socket.Parent = part1

    noCollision(part0, part1, part1)
    noCollision(colliders[part0], colliders[part1], part1)
    noCollision(colliders[part0], part1, part1)
    noCollision(part0, colliders[part1], part1)
end

local function preparePart(part: BasePart)
    part.Anchored = false
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Massless = false
    part.LocalTransparencyModifier = 0
end

-- A Humanoid's limbs never collide, even dead; this welded collider does.
local function colliderFor(part: BasePart): BasePart
    local collider = Instance.new("Part")
    collider.Name = part.Name .. "Collider"
    collider.Size = part.Size * RagdollSettings.ColliderScale
    collider.CFrame = part.CFrame
    collider.Transparency = 1
    collider.CanCollide = true
    collider.CanQuery = false
    collider.CanTouch = false
    collider.CastShadow = false
    collider.Massless = true
    collider.Parent = part
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = part
    weld.Part1 = collider
    weld.Parent = collider
    return collider
end

local function prepareHumanoid(humanoid: Humanoid)
    humanoid.BreakJointsOnDeath = false
    humanoid.RequiresNeck = false
    humanoid.AutoRotate = false
    humanoid.PlatformStand = true
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    humanoid.Health = 0
end

function Ragdoll.Build(character: Model, rig): Model?
    local wasArchivable = character.Archivable
    character.Archivable = true
    local clone = character:Clone()
    character.Archivable = wasArchivable
    if not clone then
        return nil
    end
    clone.Name = Ragdoll.ModelName

    local root = clone:FindFirstChild(rig.Root)
    if root then
        root:Destroy()
    end
    for _, descendant in clone:GetDescendants() do
        local looseMotor = descendant:IsA("Motor6D") and (descendant.Part0 == nil or descendant.Part1 == nil)
        if descendant:IsA("LuaSourceContainer") or descendant:IsA("ForceField") or looseMotor then
            descendant:Destroy()
        end
    end

    local colliders: { [BasePart]: BasePart } = {}
    for _, child in clone:GetChildren() do
        if child:IsA("BasePart") then
            preparePart(child)
            colliders[child] = colliderFor(child)
        end
    end

    local motors = {}
    for _, descendant in clone:GetDescendants() do
        if isLimbJoint(descendant, clone) then
            table.insert(motors, descendant)
        end
    end
    for _, motor in motors do
        socketFor(motor, colliders)
        motor:Destroy()
    end
    local humanoid = clone:FindFirstChildOfClass("Humanoid")
    if humanoid then
        prepareHumanoid(humanoid)
    end
    local torso = clone:FindFirstChild(rig.Torso)
    if torso and torso:IsA("BasePart") then
        clone.PrimaryPart = torso
    end
    return clone
end

return Ragdoll
