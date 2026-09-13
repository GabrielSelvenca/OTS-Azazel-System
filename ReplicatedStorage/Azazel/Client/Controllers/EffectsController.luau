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
    light.Color = TracerSettings.Color
    light.Parent = part
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
    local tailDistance = math.max(tracer.Traveled - tracer.Length, 0)
    local tail = tracer.From + tracer.Direction * tailDistance
    local rod = math.max(tracer.Traveled - tailDistance, 0.05)
    tracer.Part.Size = Vector3.new(tracer.Width, tracer.Width, rod)
    tracer.Part.CFrame = CFrame.lookAt(tail, tail + tracer.Direction) * CFrame.new(0, 0, -rod / 2)
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
    local cameraPosition = workspace.CurrentCamera.CFrame.Position
    if (from - cameraPosition).Magnitude > quality.TracerMaxDistance and (to - cameraPosition).Magnitude > quality.TracerMaxDistance then
        return
    end
    local direction = offset / distance
    local part = cache:GetPart()
    part.Size = Vector3.new(tracer.Width, tracer.Width, tracer.Length)
    part.Color = tracer.Color
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
    if light then
        local wanted = quality.TracerLight and lightConfig ~= nil and lightConfig.Enabled == true
        if wanted then
            light.Brightness = lightConfig.Brightness
            light.Range = lightConfig.Range
            light.Shadows = lightConfig.Shadows == true
            light.Color = tracer.Color
        end
        light.Enabled = wanted
    end
    local live = {
        Part = part,
        From = from,
        Direction = direction,
        Distance = distance,
        Traveled = math.min(tracer.Length, distance),
        Speed = tracer.Speed,
        Length = tracer.Length,
        Trail = trail,
        TrailPending = quality.TracerTrail and trail ~= nil,
        Light = light,
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
