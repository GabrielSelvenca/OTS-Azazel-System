-- Body part names per avatar rig. Only R6 is supported.
local Rig = {}

Rig.Attribute = "AzazelRig"

Rig.R6 = {
    Name = "R6",
    Root = "HumanoidRootPart",
    Torso = "Torso",
    Head = "Head",
    Hand = "Right Arm",
    HandOffset = CFrame.new(0, -1, 0), -- default grip, only for a model with no joint of its own
    WeaponJoints = { Handle = "Right Arm" }, -- last resort for a rig joint whose Part0 was lost
    ViewmodelKeep = { "HumanoidRootPart", "Torso", "Left Arm", "Right Arm" },
    ViewmodelJoints = { "RootJoint", "Left Shoulder", "Right Shoulder" },
    ViewmodelShown = { "Left Arm", "Right Arm" },
    LookJoints = { "Right Shoulder", "Left Shoulder", "Neck" },
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

-- The viewmodel has no Humanoid, so it carries the rig name as an attribute.
function Rig.Detect(character: Model?): string?
    if not character then
        return nil
    end
    if character:GetAttribute(Rig.Attribute) == "R6" then
        return "R6"
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    return if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then "R6" else nil
end

function Rig.Get(character: Model?)
    local rigName = Rig.Detect(character)
    return if rigName then Rig[rigName] else nil
end

function Rig.GetHand(character: Model?): BasePart?
    local rig = Rig.Get(character)
    local hand = rig and (character :: Model):FindFirstChild(rig.Hand)
    return if hand and hand:IsA("BasePart") then hand else nil
end

-- The body part an accessory handle is welded to.
function Rig.AccessoryPart(handle: BasePart): BasePart?
    local weld = handle:FindFirstChild("AccessoryWeld") or handle:FindFirstChildOfClass("Weld")
    if not weld or not weld:IsA("JointInstance") then
        return nil
    end
    return if weld.Part1 == handle then weld.Part0 else weld.Part1
end

function Rig.ZoneOf(part: BasePart): string
    local parent = part.Parent
    if parent and parent:IsA("Accessory") then
        local body = Rig.AccessoryPart(part)
        if not body then
            return "Torso"
        end
        part = body
    end
    local rig = Rig.Get(part:FindFirstAncestorOfClass("Model"))
    return rig and rig.Zones[part.Name] or "Limb"
end

return Rig
