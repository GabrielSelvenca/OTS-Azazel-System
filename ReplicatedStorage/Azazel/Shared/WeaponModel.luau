local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rig = require(script.Parent.Rig)

local WeaponModel = {}

local MOTOR_NAME = "Handle"
local HANDLE_NAME = "Handle"
local WEAPON_ATTRIBUTE = "AzazelWeapon"
local PLACEHOLDER_SIZE = Vector3.new(0.35, 0.3, 2.2)

local function assetsFolder(): Instance?
    local package = ReplicatedStorage:FindFirstChild("Azazel")
    local assets = package and package:FindFirstChild("Assets")
    return assets and assets:FindFirstChild("Weapons")
end

local function preparePart(part: BasePart)
    part.Anchored = false
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Massless = true
    part.CastShadow = false
end

local function partsInside(model: Model): { [BasePart]: boolean }
    local set = {}
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") then
            set[descendant] = true
        end
    end
    return set
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

    local jointed = {}
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("LuaSourceContainer") then
            descendant:Destroy()
        elseif descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
            local part0, part1 = descendant.Part0, descendant.Part1
            if part0 and part1 and inside[part0] and inside[part1] then
                jointed[part0] = true
                jointed[part1] = true
            else
                descendant:Destroy()
            end
        end
    end

    for part in inside do
        preparePart(part)
        if part ~= handle and not jointed[part] then
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = handle
            weld.Part1 = part
            weld.Parent = handle
        end
    end

    if not handle:FindFirstChild("Muzzle") then
        local muzzle = Instance.new("Attachment")
        muzzle.Name = "Muzzle"
        muzzle.Position = Vector3.new(0, 0, -handle.Size.Z / 2)
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
    local folder = assetsFolder()
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

function WeaponModel.FindAttachment(model: Model?, name: string): Attachment?
    if not model then
        return nil
    end
    local attachment = model:FindFirstChild(name, true)
    return if attachment and attachment:IsA("Attachment") then attachment else nil
end

function WeaponModel.MuzzlePosition(model: Model?): Vector3?
    local muzzle = WeaponModel.FindAttachment(model, "Muzzle")
    if muzzle then
        return muzzle.WorldPosition
    end
    local handle = model and model:FindFirstChild(HANDLE_NAME)
    return if handle and handle:IsA("BasePart") then handle.Position else nil
end

function WeaponModel.Attach(character: Model, model: Model, cfg): Motor6D?
    local rig = Rig.Get(character)
    local hand = Rig.GetHand(character)
    local handle = model:FindFirstChild(HANDLE_NAME)
    if not rig or not hand or not handle or not handle:IsA("BasePart") then
        return nil
    end
    WeaponModel.Detach(character)

    model:PivotTo(hand.CFrame * rig.HandOffset * cfg.Grip:Inverse())
    model.Parent = character
    local motor = Instance.new("Motor6D")
    motor.Name = MOTOR_NAME
    motor.Part0 = hand
    motor.Part1 = handle
    motor.C0 = rig.HandOffset
    motor.C1 = cfg.Grip
    motor.Parent = hand
    return motor
end

function WeaponModel.Detach(character: Model)
    local hand = Rig.GetHand(character)
    if hand then
        local motor = hand:FindFirstChild(MOTOR_NAME)
        if motor and motor:IsA("Motor6D") then
            motor:Destroy()
        end
    end
    local existing = WeaponModel.Find(character)
    if existing then
        existing:Destroy()
    end
end

WeaponModel.MotorName = MOTOR_NAME
WeaponModel.HandleName = HANDLE_NAME
WeaponModel.Attribute = WEAPON_ATTRIBUTE

return WeaponModel
