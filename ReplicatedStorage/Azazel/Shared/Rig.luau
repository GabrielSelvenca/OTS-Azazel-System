local Rig = {}

Rig.R6 = {
    Name = "R6",
    Root = "HumanoidRootPart",
    Torso = "Torso",
    Head = "Head",
    Hand = "Right Arm",
    OffHand = "Left Arm",
    HandOffset = CFrame.new(0, -1, 0),
    ViewmodelKeep = { "HumanoidRootPart", "Torso", "Left Arm", "Right Arm" },
    ViewmodelJoints = { "RootJoint", "Left Shoulder", "Right Shoulder" },
    Zones = {
        Head = "Head",
        Torso = "Torso",
        HumanoidRootPart = "Torso",
        ["Left Arm"] = "Limb",
        ["Right Arm"] = "Limb",
        ["Left Leg"] = "Limb",
        ["Right Leg"] = "Limb",
    },
}

Rig.R15 = {
    Name = "R15",
    Enabled = false,
    Root = "HumanoidRootPart",
    Torso = "UpperTorso",
    Head = "Head",
    Hand = "RightHand",
    OffHand = "LeftHand",
    HandOffset = CFrame.new(0, -0.15, 0),
    ViewmodelKeep = { "HumanoidRootPart", "UpperTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" },
    ViewmodelJoints = { "Root", "Waist", "LeftShoulder", "LeftElbow", "LeftWrist", "RightShoulder", "RightElbow", "RightWrist" },
    Zones = {
        Head = "Head",
        UpperTorso = "Torso",
        LowerTorso = "Torso",
        HumanoidRootPart = "Torso",
    },
}

function Rig.Detect(character: Model?): string?
    if not character then
        return nil
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return nil
    end
    return if humanoid.RigType == Enum.HumanoidRigType.R15 then "R15" else "R6"
end

function Rig.Get(character: Model?)
    local rigName = Rig.Detect(character)
    if not rigName then
        return nil
    end
    return Rig[rigName]
end

function Rig.GetHand(character: Model?): BasePart?
    local rig = Rig.Get(character)
    if not rig or not character then
        return nil
    end
    local hand = character:FindFirstChild(rig.Hand)
    return if hand and hand:IsA("BasePart") then hand else nil
end

function Rig.ZoneOf(part: BasePart): string
    local parent = part.Parent
    if parent and parent:IsA("Accessory") then
        return "Head"
    end
    local model = part:FindFirstAncestorOfClass("Model")
    local rig = Rig.Get(model)
    if rig then
        local zone = rig.Zones[part.Name]
        if zone then
            return zone
        end
    end
    return "Limb"
end

return Rig
