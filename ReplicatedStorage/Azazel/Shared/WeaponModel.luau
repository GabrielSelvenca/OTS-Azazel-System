local Rig = require(script.Parent.Rig)

local WeaponModel = {}

local HANDLE_NAME = "Handle"
local WEAPON_ATTRIBUTE = "AzazelWeapon"
local PLACEHOLDER_SIZE = Vector3.new(0.35, 0.3, 2.2)
local DEFAULT_GRIP = CFrame.Angles(math.pi / 2, 0, 0)

local assets = script.Parent.Parent.Assets

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

-- A Motor6D from a weapon part out to a body part (Part0 empty or foreign) is a rig joint:
-- it ships with its C0/C1 and Attach only fills Part0.
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

local function warnDropped(model: Model, joint: Instance, reason: string)
    warn(`[Azazel] {model.Name}: dropped {joint.ClassName} {joint.Name}, {reason}`)
end

local function dropReason(joint: Instance, inside: { [BasePart]: boolean }): string?
    local part0, part1 = (joint :: any).Part0, (joint :: any).Part1
    if not joint:IsA("Motor6D") then
        local foreign = if part0 and inside[part0] then part1 else part0
        return if foreign then `it reaches {foreign.Name}; only a Motor6D can join the weapon to the character` else nil
    end
    if not part1 then
        return "it has no Part1"
    end
    if part0 and inside[part0] then
        return `it points from {part0.Name} to {part1.Name}; Part0 has to be the body part, Part1 the weapon part`
    end
    return `its Part1 {part1:GetFullName()} is outside this model; point it at this model's own part`
end

-- Scripts go; joints inside the model and rig joints stay; anything else that leaves the model
-- is dropped. Returns the parts that have a joint.
local function keepJoints(model: Model, inside: { [BasePart]: boolean }): { [BasePart]: boolean }
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
                    warnDropped(model, descendant, reason)
                end
                descendant:Destroy()
            end
        end
    end
    return jointed
end

function WeaponModel.Sanitize(model: Model): BasePart?
    local handle = model:FindFirstChild(HANDLE_NAME, true)
    if not handle or not handle:IsA("BasePart") then
        return nil
    end
    handle.Parent = model
    model.PrimaryPart = handle

    local inside = partsInside(model)
    local jointed = keepJoints(model, inside)
    for part in inside do
        preparePart(part)
        if part ~= handle and not jointed[part] then
            weldToHandle(handle, part)
        end
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

    local muzzle = Instance.new("Attachment")
    muzzle.Name = "Muzzle"
    muzzle.Position = Vector3.new(0, 0.05, -PLACEHOLDER_SIZE.Z / 2 - 0.45)
    muzzle.Parent = handle

    WeaponModel.Sanitize(model)
    return model
end

function WeaponModel.Clone(cfg): Model
    local folder = assets:FindFirstChild("Weapons")
    local source = cfg.Model and folder and folder:FindFirstChild(cfg.Model)
    local model
    if source and source:IsA("Model") then
        model = source:Clone()
        model.Name = cfg.Name
        if not WeaponModel.Sanitize(model) then
            warn(`[Azazel] Weapon model {cfg.Model} has no BasePart named {HANDLE_NAME}, using placeholder`)
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

-- A named point of the model (Muzzle, Sight): an Attachment or an invisible BasePart.
function WeaponModel.FindPoint(model: Model?, name: string): Instance?
    local point = model and model:FindFirstChild(name, true)
    return if point and (point:IsA("Attachment") or point:IsA("BasePart")) then point else nil
end

function WeaponModel.PointPosition(point: Instance): Vector3
    return if point:IsA("Attachment") then point.WorldPosition else (point :: BasePart).Position
end

function WeaponModel.MuzzlePosition(model: Model?): Vector3?
    local muzzle = WeaponModel.FindPoint(model, "Muzzle")
    if muzzle then
        return WeaponModel.PointPosition(muzzle)
    end
    local handle = model and model:FindFirstChild(HANDLE_NAME)
    return if handle then (handle :: BasePart).Position else nil
end

-- The character part a rig joint plugs into, by name: the part its Part0 still points at, else
-- the Motor6D's own name, else Rig.WeaponJoints for its Part1.
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

-- Plugs every rig joint of the model into the character and parents the model. Returns the
-- joint that carries the weapon (the Handle one when there is one).
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
            warnDropped(model, joint, `no body part on this character for {part1.Name}; it is welded to the Handle`)
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
            warn(`[Azazel] {model.Name}: no Motor6D to the character inside the model, using the default grip`)
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

return WeaponModel
