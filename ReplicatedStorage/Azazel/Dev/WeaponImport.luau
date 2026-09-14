--[[
    Turns a free model into the shape Azazel expects, before WeaponModel.Sanitize welds it.
    Studio only, called by Dev.Commands.ImportWeapon. Name tables live in Assets/Manifest.Import.

    - Scale: Model:ScaleTo, one factor for a whole pack keeps the guns proportional.
    - Marker parts (Muzzle) become Attachments on the Handle.
    - Moving parts (Magazine) get a Motor6D from the Handle instead of a weld, so the Animation
      Editor sees them as joints. A part named <Name>Attachment is used as the pivot (the
      Viethin rig convention); <Name>Rotation helpers are dropped.
    - Sounds leave the model: a Sound named Fire* is the weapon's own and goes to
      Assets/Sounds/<Weapon>/Fire; any other name is shared by every weapon and goes to
      Assets/Sounds/<Name>, the first imported copy wins.
    - Everything else that is not geometry or a joint is destroyed. The weapon keeps only what
      Azazel reads; the name lists above are the whole contract.
]]

local package = script.Parent.Parent
local Manifest = require(package.Assets.Manifest)
local WeaponModel = require(package.Shared.WeaponModel)

local WeaponImport = {}

local Import = Manifest.Import

local KEEP_CLASSES = {
    "BasePart", "Attachment", "JointInstance", "WeldConstraint",
    "SurfaceAppearance", "Texture", "Decal", "DataModelMesh",
}

export type Options = {
    Scale: number?,
    Material: string?,
}

export type Report = {
    Attachments: { string },
    Motors: { string },
    Sounds: { string },
    Discarded: number,
}

local function isKept(instance: Instance): boolean
    for _, className in KEEP_CLASSES do
        if instance:IsA(className) then
            return true
        end
    end
    return false
end

local function isHelperPart(name: string): boolean
    return string.sub(name, -8) == "Rotation" or string.sub(name, -10) == "Attachment"
end

local function findHandle(model: Model): BasePart?
    local handle = model:FindFirstChild(WeaponModel.HandleName, true)
    return if handle and handle:IsA("BasePart") then handle else nil
end

local FIRE_PREFIX = "fire"
local FIRE_NAME = "Fire"

local function soundsFolder(weaponName: string?): Folder
    local sounds = package.Assets:FindFirstChild("Sounds")
    assert(sounds, "[Azazel] Assets/Sounds missing; run Setup()")
    if not weaponName then
        return sounds
    end
    local folder = sounds:FindFirstChild(weaponName)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = weaponName
        folder.Parent = sounds
    end
    return folder
end

local function isFireSound(sound: Sound): boolean
    return string.sub(string.lower(sound.Name), 1, #FIRE_PREFIX) == FIRE_PREFIX
end

local function harvestSounds(model: Model, weaponName: string, report: Report)
    local fire, shared = {}, {}
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("Sound") then
            table.insert(if isFireSound(descendant) then fire else shared, descendant)
        end
    end
    if #fire > 0 then
        local folder = soundsFolder(weaponName)
        for _, sound in fire do
            if #fire == 1 then
                sound.Name = FIRE_NAME
            end
            local existing = folder:FindFirstChild(sound.Name)
            if existing then
                existing:Destroy()
            end
            sound.Parent = folder
            table.insert(report.Sounds, `{weaponName}/{sound.Name}`)
        end
    end
    if #shared > 0 then
        local folder = soundsFolder(nil)
        for _, sound in shared do
            if folder:FindFirstChild(sound.Name) then
                sound:Destroy()
                table.insert(report.Sounds, `{sound.Name} (already shared, dropped)`)
            else
                sound.Parent = folder
                table.insert(report.Sounds, `{sound.Name} (shared)`)
            end
        end
    end
end

local function convertAttachmentParts(model: Model, handle: BasePart, report: Report)
    for partName, attachmentName in Import.AttachmentParts do
        local part = model:FindFirstChild(partName, true)
        if not part or not part:IsA("BasePart") or part == handle then
            continue
        end
        local existing = handle:FindFirstChild(attachmentName)
        if existing then
            existing:Destroy()
        end
        local attachment = Instance.new("Attachment")
        attachment.Name = attachmentName
        attachment.CFrame = handle.CFrame:ToObjectSpace(part.CFrame)
        attachment.Parent = handle
        part:Destroy()
        table.insert(report.Attachments, attachmentName)
    end
end

local function motorizeMovingParts(model: Model, handle: BasePart, report: Report)
    for _, partName in Import.MovingParts do
        local part = model:FindFirstChild(partName, true)
        if not part or not part:IsA("BasePart") or part == handle then
            continue
        end
        for _, descendant in model:GetDescendants() do
            local joint = descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint")
            if joint and (descendant.Part0 == part or descendant.Part1 == part) then
                descendant:Destroy()
            end
        end
        local pivotPart = model:FindFirstChild(partName .. "Attachment", true)
        local pivot = if pivotPart and pivotPart:IsA("BasePart") then pivotPart.CFrame else part.CFrame
        local motor = Instance.new("Motor6D")
        motor.Name = partName
        motor.Part0 = handle
        motor.Part1 = part
        motor.C0 = handle.CFrame:ToObjectSpace(pivot)
        motor.C1 = part.CFrame:ToObjectSpace(pivot)
        motor.Parent = handle
        table.insert(report.Motors, partName)
    end
end

local function discardJunk(model: Model, handle: BasePart, report: Report)
    local discard = {}
    for _, name in Import.Discard do
        discard[name] = true
    end
    for _, descendant in model:GetDescendants() do
        if descendant.Parent == nil or descendant == handle then
            continue
        end
        local junkPart = descendant:IsA("BasePart") and (discard[descendant.Name] or isHelperPart(descendant.Name))
        local container = descendant:IsA("Folder") or descendant:IsA("Model") or descendant:IsA("Configuration")
        if junkPart or (not container and not isKept(descendant)) then
            descendant:Destroy()
            report.Discarded += 1
        end
    end
end

local function applyMaterial(model: Model, materialName: string)
    local material = Enum.Material[materialName]
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.Material = material
        end
    end
end

function WeaponImport.Prepare(model: Model, weaponName: string, options: Options?): (BasePart?, Report)
    local opts: Options = options or {}
    local report: Report = { Attachments = {}, Motors = {}, Sounds = {}, Discarded = 0 }
    if opts.Scale and opts.Scale > 0 then
        model:ScaleTo(opts.Scale)
    end
    harvestSounds(model, weaponName, report)
    local handle = findHandle(model)
    if handle then
        convertAttachmentParts(model, handle, report)
        motorizeMovingParts(model, handle, report)
        discardJunk(model, handle, report)
    end
    if opts.Material then
        applyMaterial(model, opts.Material)
    end
    return WeaponModel.Sanitize(model), report
end

return WeaponImport
