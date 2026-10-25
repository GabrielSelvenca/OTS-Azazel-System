local RunService = game:GetService("RunService")

local UserGameSettings = UserSettings():GetService("UserGameSettings")

local Settings = require(script.Parent.Parent.Config.Settings)

local Quality = {}

Quality.Level = "High"

local RANK = { Low = 1, Medium = 2, High = 3 }

local override: string? = nil
local frames = 0
local elapsed = 0

local function fromSavedSetting(): string?
    local saved = UserGameSettings.SavedQualityLevel
    if saved == Enum.SavedQualitySetting.Automatic then
        return nil
    end
    local thresholds = Settings.Quality.SavedLevels
    if saved.Value >= thresholds.High then
        return "High"
    elseif saved.Value >= thresholds.Medium then
        return "Medium"
    end
    return "Low"
end

local function fromFps(fps: number, current: string): string
    local auto = Settings.Quality.AutoFps
    local target = "Low"
    if fps >= auto.High then
        target = "High"
    elseif fps >= auto.Medium then
        target = "Medium"
    end
    if RANK[target] > RANK[current] and fps < auto[target] + auto.Hysteresis then
        return current
    end
    if RANK[target] < RANK[current] and fps >= (auto[current] or 0) - auto.Hysteresis then
        return current
    end
    return target
end

local function apply(level: string)
    if not RANK[level] or level == Quality.Level then
        return
    end
    Quality.Level = level
end

local function evaluate()
    if override then
        apply(override)
        return
    end
    local source = Settings.Quality.Source
    if source ~= "Auto" then
        apply(source)
        return
    end
    local saved = fromSavedSetting()
    if saved then
        apply(saved)
    end
end

function Quality.Get()
    return Settings.Quality.Levels[Quality.Level]
end

function Quality.Set(level: string?)
    override = level
    evaluate()
end

function Quality.IsAutomatic(): boolean
    return override == nil and Settings.Quality.Source == "Auto" and fromSavedSetting() == nil
end

RunService.Heartbeat:Connect(function(dt)
    frames += 1
    elapsed += dt
    if elapsed < Settings.Quality.SampleSeconds then
        return
    end
    local fps = frames / elapsed
    frames, elapsed = 0, 0
    if Quality.IsAutomatic() then
        apply(fromFps(fps, Quality.Level))
    end
end)

UserGameSettings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(evaluate)
evaluate()

return Quality
