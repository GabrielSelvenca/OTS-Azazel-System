local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Client = require(script.Parent.Parent)
local Quality = require(script.Parent.Parent.Quality)
local package = script.Parent.Parent.Parent
local Settings = require(package.Config.Settings)
local WeaponConfig = require(package.Config.WeaponConfig)
local Remotes = require(package.Shared.Remotes)
local WeaponModel = require(package.Shared.WeaponModel)
local PartCache = require(package.Packages.PartCache)

local EffectsController = {}

local Signals = Client.Signals
local TracerSettings = Settings.Effects.Tracer
local localPlayer = Players.LocalPlayer

local tracerCache = nil
local liveTracers = {}
local shotCounters: { [Player]: number } = {}

local function buildTracerTemplate(): BasePart
    local part = Instance.new("Part")
    part.Name = "Tracer"
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Material = TracerSettings.Material

    local front = Instance.new("Attachment")
    front.Name = "Front"
    front.Parent = part
    local back = Instance.new("Attachment")
    back.Name = "Back"
    back.Parent = part

    local trail = Instance.new("Trail")
    trail.Attachment0 = front
    trail.Attachment1 = back
    trail.Enabled = false
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
    light.Parent = part
    return part
end

local function poolSize(): number
    local size = 1
    for _, level in Settings.Quality.Levels do
        size = math.max(size, level.TracerMaxLive)
    end
    return size
end

local function studsPerPixel(camera: Camera, position: Vector3): number
    local distance = (position - camera.CFrame.Position).Magnitude
    return 2 * distance * math.tan(math.rad(camera.FieldOfView / 2)) / math.max(camera.ViewportSize.Y, 1)
end

local function placeTracer(tracer, camera: Camera, quality)
    local tailDistance = math.max(tracer.Traveled - tracer.Length, 0)
    local tail = tracer.From + tracer.Direction * tailDistance
    local rod = math.max(tracer.Traveled - tailDistance, 0.05)
    local center = tail + tracer.Direction * (rod / 2)
    local width = math.max(tracer.Width, studsPerPixel(camera, center) * tracer.MinPixelWidth)
    tracer.Part.Size = Vector3.new(width, width, rod)
    tracer.Part.CFrame = CFrame.lookAt(tail, tail + tracer.Direction) * CFrame.new(0, 0, -rod / 2)
    local lit = tracer.LightWanted and (center - camera.CFrame.Position).Magnitude <= quality.TracerLightDistance
    if tracer.Light.Enabled ~= lit then
        tracer.Light.Enabled = lit
    end
end

local function spawnTracer(from: Vector3, to: Vector3, tracer)
    local quality = Quality.Get()
    if #liveTracers >= quality.TracerMaxLive then
        return
    end
    local offset = to - from
    local distance = offset.Magnitude
    if distance < 1 then
        return
    end
    local part = tracerCache:GetPart()
    part.Size = Vector3.new(tracer.Width, tracer.Width, tracer.Length)
    part.Color = tracer.Color

    local trail = part.Trail :: Trail
    trail.Lifetime = tracer.Trail.Lifetime
    trail.Color = ColorSequence.new(tracer.Color)
    trail.Enabled = false
    part.Front.Position = Vector3.new(0, tracer.Width / 2, 0)
    part.Back.Position = Vector3.new(0, -tracer.Width / 2, 0)

    local light = part.Light :: PointLight
    local lightConfig = tracer.Light
    local lightWanted = quality.TracerLightDistance > 0 and lightConfig.Enabled
    light.Enabled = false
    if lightWanted then
        light.Brightness = lightConfig.Brightness
        light.Range = lightConfig.Range
        light.Shadows = lightConfig.Shadows
        light.Color = lightConfig.Color
    end

    local live = {
        Part = part,
        From = from,
        Direction = offset / distance,
        Distance = distance,
        Traveled = math.min(tracer.Length, distance),
        Speed = tracer.Speed,
        Length = tracer.Length,
        Width = tracer.Width,
        MinPixelWidth = tracer.MinPixelWidth,
        Trail = trail,
        TrailPending = quality.TracerTrail,
        Light = light,
        LightWanted = lightWanted,
    }
    placeTracer(live, workspace.CurrentCamera, quality)
    table.insert(liveTracers, live)
end

local function stepTracers(dt: number)
    local camera = workspace.CurrentCamera
    local quality = Quality.Get()
    for index = #liveTracers, 1, -1 do
        local tracer = liveTracers[index]
        -- The trail starts a frame late so it never streaks from where the pooled part was.
        if tracer.TrailPending then
            tracer.TrailPending = false
            tracer.Trail:Clear()
            tracer.Trail.Enabled = true
        end
        tracer.Traveled += tracer.Speed * dt
        if tracer.Traveled >= tracer.Distance then
            tracer.Trail.Enabled = false
            tracer.Trail:Clear()
            tracer.Light.Enabled = false
            tracerCache:ReturnPart(tracer.Part)
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
    if not tracer.Enabled or not shouldDraw(shooter, math.max(tracer.Every, Quality.Get().TracerEvery)) then
        return
    end
    for _, endPoint in ends do
        spawnTracer(muzzle, endPoint, tracer)
    end
end

function EffectsController.Start()
    tracerCache = PartCache.new(buildTracerTemplate(), poolSize(), Client.EffectsFolder())

    Signals.LocalShot:Connect(function(origin, ends, cfg)
        -- The gun on screen: the viewmodel's in first person, the character's in third.
        local model = Client.ViewmodelWeapon or WeaponModel.Find(localPlayer.Character)
        drawShot(localPlayer, cfg, WeaponModel.MuzzlePosition(model) or origin, ends)
    end)

    -- The shooter's weapon as this client renders it; the server's muzzle lags behind.
    Remotes.OnClient("ShotFired", function(shooter, weaponName, muzzle, ends)
        local localMuzzle = WeaponModel.MuzzlePosition(WeaponModel.Find(shooter.Character))
        drawShot(shooter, WeaponConfig.Get(weaponName), localMuzzle or muzzle, ends)
    end)

    Players.PlayerRemoving:Connect(function(player)
        shotCounters[player] = nil
    end)

    RunService.RenderStepped:Connect(stepTracers)
end

return EffectsController
