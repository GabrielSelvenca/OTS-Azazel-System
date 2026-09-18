local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rig = require(script.Parent.Rig)

local WeaponModel = {}

local HANDLE_NAME = "Handle"
local WEAPON_ATTRIBUTE = "AzazelWeapon"
local PLACEHOLDER_SIZE = Vector3.new(0.35, 0.3, 2.2)
local DEFAULT_GRIP = CFrame.Angles(math.pi / 2, 0, 0)

local function assetsFolder(name: string): Instance?
    local package = ReplicatedStorage:FindFirstChild("Azazel")
    local assets = package and package:FindFirstChild("Assets")
    return assets and assets:FindFirstChild(name)
end

local DEFAULT_ATTRIBUTE = "AzazelDefault"

local function preparePart(part: BasePart)
    part.Anchored = false
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Massless = true
    part.CastShadow = false
end

local function partsInside(model: Instance): { [BasePart]: boolean }
    local set = {}
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") then
            set[descendant] = true
        end
    end
    return set
end

-- A Motor6D that reaches out of the model (Part1 inside, Part0 empty or foreign) is a joint
-- the animation rig had to a body part: the grip on the Handle, a reload magazine on the left
-- arm. It ships with the model, C0 and C1 included, so the clips made on the rig land the same
-- way on every character; Attach only fills Part0.
local function isRigJoint(joint: Instance, inside: { [BasePart]: boolean }): boolean
    if not joint:IsA("Motor6D") then
        return false
    end
    local part0, part1 = joint.Part0, joint.Part1
    return part1 ~= nil and inside[part1] == true and (part0 == nil or not inside[part0])
end

local function weldToHandle(handle: BasePart, part: BasePart)
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = handle
    weld.Part1 = part
    weld.Parent = handle
end

local function pickHandle(model: Model, inside: { [BasePart]: boolean }): BasePart?
    local named = model:FindFirstChild(HANDLE_NAME, true)
    if named and named:IsA("BasePart") then
        return named
    end
    if model.PrimaryPart then
        return model.PrimaryPart
    end
    local largest, largestVolume = nil, 0
    for part in inside do
        local size = part.Size
        local volume = size.X * size.Y * size.Z
        if volume > largestVolume then
            largest, largestVolume = part, volume
        end
    end
    return largest
end

-- Drops scripts and sorts the joints: internal ones stay, Motor6Ds out to a body part stay
-- for Attach, anything else that leaves the model is dropped with a warning. Returns the parts
-- that have a joint.
local function dropReason(joint: Instance, inside: { [BasePart]: boolean }): string?
    local part0, part1 = (joint :: any).Part0, (joint :: any).Part1
    if not joint:IsA("Motor6D") then
        local foreign = if part0 and inside[part0] then part1 else part0
        return if foreign
            then `{joint.ClassName} {joint.Name} reaches {foreign.Name}: only a Motor6D can join the weapon to the character`
            else nil
    end
    if part0 and part1 and inside[part0] then
        return `Motor6D {joint.Name} points from {part0.Name} to {part1.Name}: Part1 has to be the weapon part, Part0 the body part`
    end
    if not part1 then
        return `Motor6D {joint.Name} has no Part1`
    end
    return `Motor6D {joint.Name} has Part1 = {part1:GetFullName()}, which is not in this model: `
        .. `point Part1 at this model's own part (the joint belongs to the model it holds), or duplicate the model the joint was built on`
end

local function keepJoints(model: Instance, inside: { [BasePart]: boolean }): { [BasePart]: boolean }
    local jointed = {}
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("LuaSourceContainer") then
            descendant:Destroy()
        elseif descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
            local part0, part1 = descendant.Part0, descendant.Part1
            if part0 and part1 and inside[part0] and inside[part1] then
                jointed[part0] = true
                jointed[part1] = true
            elseif isRigJoint(descendant, inside) then
                jointed[part1] = true
            else
                local reason = dropReason(descendant, inside)
                if reason then
                    warn(`[Azazel] {model.Name}: {reason}, dropped`)
                end
                descendant:Destroy()
            end
        end
    end
    return jointed
end

function WeaponModel.Sanitize(model: Model): BasePart?
    local inside = partsInside(model)
    local handle = pickHandle(model, inside)
    if not handle then
        return nil
    end
    handle.Name = HANDLE_NAME
    if handle.Parent ~= model then
        handle.Parent = model
    end
    model.PrimaryPart = handle

    local jointed = keepJoints(model, inside)
    for part in inside do
        preparePart(part)
        if part ~= handle and not jointed[part] then
            weldToHandle(handle, part)
        end
    end

    if not model:FindFirstChild("Muzzle", true) then
        local muzzle = Instance.new("Attachment")
        muzzle.Name = "Muzzle"
        muzzle.Position = Vector3.new(0, 0, -handle.Size.Z / 2)
        muzzle:SetAttribute(DEFAULT_ATTRIBUTE, true)
        muzzle.Parent = handle
    end
    return handle
end

function WeaponModel.Placeholder(cfg): Model
    local model = Instance.new("Model")
    model.Name = cfg.Name

    local handle = Instance.new("Part")
    handle.Name = HANDLE_NAME
    handle.Size = PLACEHOLDER_SIZE
    handle.Color = Color3.fromRGB(60, 60, 65)
    handle.Material = Enum.Material.Metal
    handle.Parent = model

    local barrel = Instance.new("Part")
    barrel.Name = "Barrel"
    barrel.Size = Vector3.new(0.12, 0.12, 0.5)
    barrel.Color = Color3.fromRGB(230, 180, 40)
    barrel.Material = Enum.Material.Neon
    barrel.CFrame = handle.CFrame * CFrame.new(0, 0.05, -PLACEHOLDER_SIZE.Z / 2 - 0.2)
    barrel.Parent = model

    WeaponModel.Sanitize(model)
    return model
end

function WeaponModel.Clone(cfg): Model
    local folder = assetsFolder("Weapons")
    local source = cfg.Model and folder and folder:FindFirstChild(cfg.Model)
    local model
    if source and source:IsA("Model") then
        model = source:Clone()
        model.Name = cfg.Name
        if not WeaponModel.Sanitize(model) then
            warn(`[Azazel] Weapon model {cfg.Model} has no BasePart, using placeholder`)
            model:Destroy()
            model = WeaponModel.Placeholder(cfg)
        end
    else
        if cfg.Model then
            warn(`[Azazel] Weapon model {cfg.Model} not found in Assets/Weapons, using placeholder`)
        end
        model = WeaponModel.Placeholder(cfg)
    end
    model:SetAttribute(WEAPON_ATTRIBUTE, cfg.Name)
    return model
end

function WeaponModel.Find(character: Instance?): Model?
    if not character then
        return nil
    end
    for _, child in character:GetChildren() do
        if child:IsA("Model") and child:GetAttribute(WEAPON_ATTRIBUTE) ~= nil then
            return child
        end
    end
    return nil
end

-- A named point of the model (Muzzle, Sight), placed by hand as an Attachment or as a
-- BasePart, whichever the model brought: its world CFrame and the instance, or nil when there
-- is none. With more than one of the name, a Part wins over an Attachment and anything wins
-- over the Muzzle Sanitize made up, so a stale default saved into the asset never hides the
-- real one.
function WeaponModel.FindPoint(model: Model?, name: string): (CFrame?, Instance?)
    if not model then
        return nil, nil
    end
    local best: Instance? = nil
    local bestRank = 0
    for _, descendant in model:GetDescendants() do
        if descendant.Name ~= name then
            continue
        end
        local rank = if descendant:IsA("BasePart") then 3
            elseif descendant:IsA("Attachment") and descendant:GetAttribute(DEFAULT_ATTRIBUTE) == nil then 2
            elseif descendant:IsA("Attachment") then 1
            else 0
        if rank > bestRank then
            best = descendant
            bestRank = rank
        end
    end
    if best and best:IsA("Attachment") then
        return best.WorldCFrame, best
    elseif best and best:IsA("BasePart") then
        return best.CFrame, best
    end
    return nil, nil
end

function WeaponModel.MuzzlePosition(model: Model?): Vector3?
    local muzzle = WeaponModel.FindPoint(model, "Muzzle")
    if muzzle then
        return muzzle.Position
    end
    local handle = model and model:FindFirstChild(HANDLE_NAME)
    return if handle and handle:IsA("BasePart") then handle.Position else nil
end

-- The body part a rig joint plugs into, by name: the part its Part0 still points at (a model
-- duplicated or dragged out of the rig keeps it), else the Motor6D's own name, else the
-- convention for its Part1 (Rig.WeaponJoints).
local function bodyPartFor(character: Model, rig, joint: Motor6D): BasePart?
    local names = { joint.Name }
    if joint.Part0 then
        table.insert(names, 1, joint.Part0.Name)
    end
    local conventional = rig.WeaponJoints[(joint.Part1 :: BasePart).Name]
    if conventional then
        table.insert(names, conventional)
    end
    for _, name in names do
        local part = character:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            return part
        end
    end
    return nil
end

-- Plugs every rig joint of the model into the character and parents the model. A model with no
-- joint to the character (the placeholder) gets one on the Handle with the default grip.
-- Returns the joint that carries the weapon (the Handle one when there is one).
function WeaponModel.Attach(character: Model, model: Model, cfg): Motor6D?
    local rig = Rig.Get(character)
    local handle = model:FindFirstChild(HANDLE_NAME)
    if not rig or not handle or not handle:IsA("BasePart") then
        return nil
    end
    WeaponModel.Detach(character)

    local inside = partsInside(model)
    local rootJoint: Motor6D? = nil
    for _, descendant in model:GetDescendants() do
        if not isRigJoint(descendant, inside) then
            continue
        end
        local joint = descendant :: Motor6D
        local part1 = joint.Part1 :: BasePart
        local target = bodyPartFor(character, rig, joint)
        if target then
            joint.Part0 = target
            if rootJoint == nil or part1 == handle then
                rootJoint = joint
            end
        else
            warn(`[Azazel] {model.Name}: no body part on this character for the Motor6D of {part1.Name} ({joint.Name}); welded to the Handle instead`)
            if part1 ~= handle then
                weldToHandle(handle, part1)
            end
            joint:Destroy()
        end
    end

    if not rootJoint then
        local hand = Rig.GetHand(character)
        if not hand then
            return nil
        end
        if cfg.Model then
            warn(`[Azazel] {model.Name}: no Motor6D to the character inside the model, using the default grip. Drag the rig's arm joint into the model (its Part0 or its name says which body part it belongs to) and copy the model again`)
        end
        local motor = Instance.new("Motor6D")
        motor.Name = HANDLE_NAME
        motor.Part0 = hand
        motor.Part1 = handle
        motor.C0 = rig.HandOffset
        motor.C1 = DEFAULT_GRIP
        motor.Parent = handle
        rootJoint = motor
    end

    local joint = rootJoint :: Motor6D
    local part0 = joint.Part0 :: BasePart
    local part1 = joint.Part1 :: BasePart
    local target = part0.CFrame * joint.C0 * joint.C1:Inverse()
    model:PivotTo(target * part1.CFrame:ToObjectSpace(model:GetPivot()))
    model.Parent = character
    return joint
end

-- The joints live inside the model, so destroying it frees the body parts.
function WeaponModel.Detach(character: Model)
    local existing = WeaponModel.Find(character)
    if existing then
        existing:Destroy()
    end
end

WeaponModel.HandleName = HANDLE_NAME
WeaponModel.Attribute = WEAPON_ATTRIBUTE

return WeaponModel
