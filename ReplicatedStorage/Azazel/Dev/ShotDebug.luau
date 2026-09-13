local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local package = script.Parent.Parent
local Settings = require(package.Config.Settings)

local ShotDebug = {}

local FOLDER_NAME = "AzazelShotDebug"
local ShotSettings = Settings.Debug.ClientShots

ShotDebug.Colors = ShotSettings.Colors

function ShotDebug.Enabled(): boolean
    return Settings.Debug.Enabled == true and ShotSettings.Enabled == true and RunService:IsStudio()
end

function ShotDebug.Log(text: string)
    if ShotDebug.Enabled() and ShotSettings.Print then
        print(text)
    end
end

local function folder(): Folder
    local existing = workspace:FindFirstChild(FOLDER_NAME)
    if not existing then
        existing = Instance.new("Folder")
        existing.Name = FOLDER_NAME
        existing.Parent = workspace
    end
    return existing
end

local function newPart(color: Color3, lifetime: number?): Part
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Parent = folder()
    Debris:AddItem(part, lifetime or ShotSettings.Lifetime)
    return part
end

function ShotDebug.Line(from: Vector3, to: Vector3, color: Color3, lifetime: number?)
    local distance = (to - from).Magnitude
    if not ShotSettings.Draw or distance < 0.05 then
        return
    end
    local part = newPart(color, lifetime)
    part.Size = Vector3.new(ShotSettings.LineWidth, ShotSettings.LineWidth, distance)
    part.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -distance / 2)
end

function ShotDebug.Point(position: Vector3, color: Color3, lifetime: number?, size: number?)
    if not ShotSettings.Draw then
        return
    end
    local part = newPart(color, lifetime)
    part.Shape = Enum.PartType.Ball
    part.Size = Vector3.one * (size or ShotSettings.PointSize)
    part.Position = position
end

function ShotDebug.Vector(vector: Vector3): string
    return string.format("(%.2f, %.2f, %.2f)", vector.X, vector.Y, vector.Z)
end

function ShotDebug.Instance(instance: Instance?): string
    if not instance then
        return "none"
    end
    local parent = instance.Parent
    return if parent then `{parent.Name}.{instance.Name}` else instance.Name
end

function ShotDebug.AngleBetween(a: Vector3, b: Vector3): number
    local dot = math.clamp(a.Unit:Dot(b.Unit), -1, 1)
    return math.deg(math.acos(dot))
end

return ShotDebug
