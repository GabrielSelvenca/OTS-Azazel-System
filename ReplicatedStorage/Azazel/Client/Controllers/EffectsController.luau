local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Client = require(script.Parent.Parent)
local Quality = require(script.Parent.Parent.Quality)
local package = script.Parent.Parent.Parent
local Settings = require(package.Config.Settings)
local WeaponConfig = require(package.Config.WeaponConfig)
local Remotes = require(package.Shared.Remotes)
local WeaponModel = require(package.Shared.WeaponModel)
local ShotDebug = require(package.Dev.ShotDebug)
local PartCache = require(package.Packages.PartCache)

local EffectsController = {}

local Signals = Client.Signals
local EffectSettings = Settings.Effects
local TracerSettings = EffectSettings.Tracer
local localPlayer = Players.LocalPlayer

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
    part.Material = TracerSettings.Material
    part.Color = TracerSettings.Color
    part.Size = Vector3.new(TracerSettings.Width, TracerSettings.Width, TracerSettings.Length)
    part.Transparency = 0

    local front = Instance.new("Attachment")
    front.Name = "Front"
    front.Position = Vector3.new(0, TracerSettings.Width / 2, 0)
    front.Parent = part
    local back = Instance.new("Attachment")
    back.Name = "Back"
    back.Position = Vector3.new(0, -TracerSettings.Width / 2, 0)
    back.Parent = part

    local trail = Instance.new("Trail")
    trail.Attachment0 = front
    trail.Attachment1 = back
    trail.Enabled = false
    trail.Lifetime = TracerSettings.Trail.Lifetime
    trail.LightEmission = 1
    trail.LightInfluence = 0
    trail.MinLength = 0
    trail.FaceCamera = true
    trail.Transparency = TracerSettings.Trail.Transparency
    trail.WidthScale = TracerSettings.Trail.WidthScale
    trail.Parent = part

    local light = Instance.new("PointLight")
    light.Name = "Light"
    light.Enabled = false
    light.Shadows = TracerSettings.Light.Shadows
    light.Brightness = TracerSettings.Light.Brightness
    light.Range = TracerSettings.Light.Range
    light.Color = TracerSettings.Light.Color
    light.Parent = part

    local tail = Instance.new("Attachment")
    tail.Name = "Tail"
    tail.Position = Vector3.new(0, 0, TracerSettings.Length / 2)
    tail.Parent = part
    local head = Instance.new("Attachment")
    head.Name = "Head"
    head.Position = Vector3.new(0, 0, -TracerSettings.Length / 2)
    head.Parent = part

    local beam = Instance.new("Beam")
    beam.Name = "Beam"
    beam.Attachment0 = tail
    beam.Attachment1 = head
    beam.Enabled = false
    beam.FaceCamera = true
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.Segments = 1
    beam.Width0 = TracerSettings.Width
    beam.Width1 = TracerSettings.Width
    beam.Texture = TracerSettings.Beam.Texture
    beam.TextureLength = TracerSettings.Beam.TextureLength
    beam.Color = ColorSequence.new(TracerSettings.Color)
    beam.Parent = part
    return part
end

local function studsPerPixel(camera: Camera, position: Vector3): number
    local distance = (position - camera.CFrame.Position).Magnitude
    return 2 * distance * math.tan(math.rad(camera.FieldOfView / 2)) / math.max(camera.ViewportSize.Y, 1)
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

local function placeTracer(tracer, camera: Camera, quality)
    local tailDistance = math.max(tracer.Traveled - tracer.Length, 0)
    local tail = tracer.From + tracer.Direction * tailDistance
    local rod = math.max(tracer.Traveled - tailDistance, 0.05)
    local center = tail + tracer.Direction * (rod / 2)
    local width = math.max(tracer.Width, studsPerPixel(camera, center) * tracer.MinPixelWidth)
    tracer.Part.Size = Vector3.new(width, width, rod)
    tracer.Part.CFrame = CFrame.lookAt(tail, tail + tracer.Direction) * CFrame.new(0, 0, -rod / 2)
    if tracer.Beam then
        tracer.Tail.Position = Vector3.new(0, 0, rod / 2)
        tracer.Head.Position = Vector3.new(0, 0, -rod / 2)
        tracer.Beam.Width0 = width
        tracer.Beam.Width1 = width
    end
    if tracer.Light then
        local lit = tracer.LightWanted and (center - camera.CFrame.Position).Magnitude <= quality.TracerLightDistance
        if tracer.Light.Enabled ~= lit then
            tracer.Light.Enabled = lit
        end
    end
end

local function spawnTracer(from: Vector3, to: Vector3, tracer)
    local cache = ensureCache()
    local quality = Quality.Get()
    if not cache or #liveTracers >= quality.TracerMaxLive then
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
    local useBeam = tracer.Style == "Beam"
    local beam = part:FindFirstChildOfClass("Beam")
    part.Transparency = if useBeam and beam then 1 else 0
    if beam then
        if useBeam then
            beam.Color = ColorSequence.new(tracer.Color)
            beam.Texture = if tracer.Beam then tracer.Beam.Texture else ""
            beam.TextureLength = if tracer.Beam then tracer.Beam.TextureLength else 1
        end
        beam.Enabled = useBeam
    end
    local trail = part:FindFirstChildOfClass("Trail")
    if trail then
        trail.Lifetime = if tracer.Trail then tracer.Trail.Lifetime else TracerSettings.Trail.Lifetime
        local front = part:FindFirstChild("Front")
        local back = part:FindFirstChild("Back")
        if front and back then
            front.Position = Vector3.new(0, tracer.Width / 2, 0)
            back.Position = Vector3.new(0, -tracer.Width / 2, 0)
        end
        trail.Color = ColorSequence.new(tracer.Color)
        trail.Enabled = false
    end
    local light = part:FindFirstChildOfClass("PointLight")
    local lightConfig = tracer.Light
    local lightWanted = light ~= nil and quality.TracerLightDistance > 0 and lightConfig ~= nil and lightConfig.Enabled == true
    if light then
        light.Enabled = false
        if lightWanted then
            light.Brightness = lightConfig.Brightness
            light.Range = lightConfig.Range
            light.Shadows = lightConfig.Shadows == true
            light.Color = lightConfig.Color or TracerSettings.Light.Color
        end
    end
    local live = {
        Part = part,
        From = from,
        Direction = direction,
        Distance = distance,
        Traveled = math.min(tracer.Length, distance),
        Speed = tracer.Speed,
        Length = tracer.Length,
        Width = tracer.Width,
        MinPixelWidth = tracer.MinPixelWidth or TracerSettings.MinPixelWidth,
        Trail = trail,
        TrailPending = quality.TracerTrail and trail ~= nil,
        Light = light,
        LightWanted = lightWanted,
        Beam = if useBeam then beam else nil,
        Tail = part:FindFirstChild("Tail"),
        Head = part:FindFirstChild("Head"),
    }
    placeTracer(live, workspace.CurrentCamera, quality)
    table.insert(liveTracers, live)
end

local function stepTracers(dt: number)
    local cache = tracerCache
    if not cache then
        return
    end
    local camera = workspace.CurrentCamera
    local quality = Quality.Get()
    for index = #liveTracers, 1, -1 do
        local tracer = liveTracers[index]
        if tracer.TrailPending then
            tracer.TrailPending = false
            tracer.Trail:Clear()
            tracer.Trail.Enabled = true
        end
        tracer.Traveled += tracer.Speed * dt
        if tracer.Traveled >= tracer.Distance then
            if tracer.Trail then
                tracer.Trail.Enabled = false
                tracer.Trail:Clear()
            end
            if tracer.Light then
                tracer.Light.Enabled = false
            end
            if tracer.Beam then
                tracer.Beam.Enabled = false
            end
            cache:ReturnPart(tracer.Part)
            table.remove(liveTracers, index)
        else
            placeTracer(tracer, camera, quality)
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
    local every = math.max(tracer.Every, Quality.Get().TracerEvery)
    if not tracer.Enabled or not shouldDraw(shooter, every) then
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
        if ShotDebug.Enabled() then
            for index, endPoint in ends do
                local fromMuzzle = endPoint - muzzle
                local fromHead = endPoint - origin
                local skew = if fromMuzzle.Magnitude > 0.01 and fromHead.Magnitude > 0.01
                    then ShotDebug.AngleBetween(fromMuzzle, fromHead)
                    else 0
                ShotDebug.Log(string.format(
                    "[Azazel:Tracer] pellet %d muzzle=%s end=%s tracerDist=%.2f tracerDir=%s skewFromShot=%.2f%s",
                    index,
                    ShotDebug.Vector(muzzle),
                    ShotDebug.Vector(endPoint),
                    fromMuzzle.Magnitude,
                    ShotDebug.Vector(if fromMuzzle.Magnitude > 0.01 then fromMuzzle.Unit else Vector3.zero),
                    skew,
                    if skew > 10 then "  <-- TRACER SKEW" else ""
                ))
            end
        end
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
        local localMuzzle = WeaponModel.MuzzlePosition(WeaponModel.Find(shooter.Character))
        if ShotDebug.Enabled() then
            ShotDebug.Log(string.format(
                "[Azazel:Remote] %s %s serverMuzzle=%s localMuzzle=%s gap=%.2f",
                shooter.Name,
                weaponName,
                ShotDebug.Vector(muzzle),
                if localMuzzle then ShotDebug.Vector(localMuzzle) else "none",
                if localMuzzle then (localMuzzle - muzzle).Magnitude else -1
            ))
            ShotDebug.Point(muzzle, ShotDebug.Colors.Muzzle, nil, 0.25)
            if localMuzzle then
                ShotDebug.Point(localMuzzle, ShotDebug.Colors.Camera, nil, 0.25)
            end
        end
        drawShot(shooter, cfg, localMuzzle or muzzle, ends)
    end)

    Players.PlayerRemoving:Connect(function(player)
        shotCounters[player] = nil
    end)

    RunService.RenderStepped:Connect(stepTracers)
end

return EffectsController
