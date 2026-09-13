local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Client = require(script.Parent.Parent)
local package = script.Parent.Parent.Parent
local Settings = require(package.Config.Settings)
local WeaponConfig = require(package.Config.WeaponConfig)
local Remotes = require(package.Shared.Remotes)
local WeaponModel = require(package.Shared.WeaponModel)
local PartCache = require(package.Packages.PartCache)

local EffectsController = {}

local Signals = Client.Signals
local EffectSettings = Settings.Effects
local localPlayer = Players.LocalPlayer

local TRAIL_LIFETIME = 0.08

local folder: Folder? = nil
local tracerCache = nil
local liveTracers = {}
local shotCounters: { [Player]: number } = {}

local function effectsFolder(): Folder
    if folder and folder.Parent then
        return folder
    end
    local existing = workspace:FindFirstChild(EffectSettings.FolderName)
    if not existing then
        existing = Instance.new("Folder")
        existing.Name = EffectSettings.FolderName
        existing.Parent = workspace
    end
    folder = existing
    return existing
end

local function buildTracerTemplate(): BasePart
    local part = Instance.new("Part")
    part.Name = "Tracer"
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Material = Enum.Material.Neon
    part.Size = Vector3.new(0.06, 0.06, 6)
    part.Transparency = 0.1

    local front = Instance.new("Attachment")
    front.Name = "Front"
    front.Position = Vector3.new(0, 0.03, 0)
    front.Parent = part
    local back = Instance.new("Attachment")
    back.Name = "Back"
    back.Position = Vector3.new(0, -0.03, 0)
    back.Parent = part

    local trail = Instance.new("Trail")
    trail.Attachment0 = front
    trail.Attachment1 = back
    trail.Lifetime = TRAIL_LIFETIME
    trail.LightEmission = 1
    trail.LightInfluence = 0
    trail.MinLength = 0
    trail.FaceCamera = true
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.WidthScale = NumberSequence.new(1, 0.3)
    trail.Parent = part
    return part
end

local function ensureCache()
    if tracerCache then
        return tracerCache
    end
    local ok, result = pcall(function()
        return PartCache.new(buildTracerTemplate(), EffectSettings.PoolSizes.Tracer, effectsFolder())
    end)
    if not ok then
        warn(`[Azazel] Tracer cache failed, tracers disabled: {result}`)
        return nil
    end
    tracerCache = result
    return result
end

local function placeTracer(tracer)
    local head = tracer.From + tracer.Direction * tracer.Traveled
    local tailDistance = math.max(tracer.Traveled - tracer.Length, 0)
    local tail = tracer.From + tracer.Direction * tailDistance
    local rod = math.max(tracer.Traveled - tailDistance, 0.05)
    tracer.Part.Size = Vector3.new(tracer.Width, tracer.Width, rod)
    tracer.Part.CFrame = CFrame.lookAt(tail, tail + tracer.Direction) * CFrame.new(0, 0, -rod / 2)
end

local function spawnTracer(from: Vector3, to: Vector3, tracer)
    local cache = ensureCache()
    if not cache or #liveTracers >= EffectSettings.TracerMaxLive then
        return
    end
    local offset = to - from
    local distance = offset.Magnitude
    if distance < 1 then
        return
    end
    local direction = offset / distance
    local part = cache:GetPart()
    part.Size = Vector3.new(tracer.Width, tracer.Width, tracer.Length)
    part.Color = tracer.Color
    local trail = part:FindFirstChildOfClass("Trail")
    if trail then
        trail.Lifetime = tracer.Length / math.max(tracer.Speed, 1)
        local front = part:FindFirstChild("Front")
        local back = part:FindFirstChild("Back")
        if front and back then
            front.Position = Vector3.new(0, tracer.Width / 2, 0)
            back.Position = Vector3.new(0, -tracer.Width / 2, 0)
        end
        trail.Color = ColorSequence.new(tracer.Color)
        trail.Enabled = true
    end
    local live = {
        Part = part,
        From = from,
        Direction = direction,
        Distance = distance,
        Traveled = 0,
        Speed = tracer.Speed,
        Length = tracer.Length,
    }
    placeTracer(live)
    table.insert(liveTracers, live)
end

local function stepTracers(dt: number)
    local cache = tracerCache
    if not cache then
        return
    end
    for index = #liveTracers, 1, -1 do
        local tracer = liveTracers[index]
        tracer.Traveled += tracer.Speed * dt
        if tracer.Traveled >= tracer.Distance then
            local trail = tracer.Part:FindFirstChildOfClass("Trail")
            if trail then
                trail.Enabled = false
            end
            cache:ReturnPart(tracer.Part)
            table.remove(liveTracers, index)
        else
            placeTracer(tracer)
        end
    end
end

local function shouldDraw(shooter: Player, every: number): boolean
    local count = (shotCounters[shooter] or 0) + 1
    shotCounters[shooter] = count
    return every <= 1 or count % every == 1
end

local function drawShot(shooter: Player, cfg, muzzle: Vector3, ends: { Vector3 })
    local tracer = cfg.Effects.Tracer
    if not tracer.Enabled or not shouldDraw(shooter, tracer.Every) then
        return
    end
    for _, endPoint in ends do
        if typeof(endPoint) == "Vector3" then
            spawnTracer(muzzle, endPoint, tracer)
        end
    end
end

function EffectsController.Start()
    Signals.LocalShot:Connect(function(origin, ends, cfg)
        local model = WeaponModel.Find(localPlayer.Character)
        local muzzle = WeaponModel.MuzzlePosition(model) or origin
        drawShot(localPlayer, cfg, muzzle, ends)
    end)

    Remotes.OnClient("ShotFired", function(shooter, weaponName, muzzle, ends)
        if shooter == localPlayer or typeof(muzzle) ~= "Vector3" or type(ends) ~= "table" then
            return
        end
        local cfg = WeaponConfig.Get(weaponName)
        if not cfg then
            return
        end
        drawShot(shooter, cfg, muzzle, ends)
    end)

    Players.PlayerRemoving:Connect(function(player)
        shotCounters[player] = nil
    end)

    RunService.RenderStepped:Connect(stepTracers)
end

return EffectsController
