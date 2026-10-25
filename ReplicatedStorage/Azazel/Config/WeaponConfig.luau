-- Get(name) merges Defaults <- Classes[Class] <- Weapons[name], derives ShotInterval/BurstInterval and freezes.
local Settings = require(script.Parent.Settings)
local Weapons = require(script.Parent.Weapons)

local WeaponConfig = {}

WeaponConfig.Defaults = {
    FireModes = { "Semi" },                     -- "Auto" | "Semi" | "Burst"; the first is the default
    Rpm = 400,
    Burst = { Count = 3, Rpm = 900 },
    Magazine = 12,
    Reserve = 48,
    Reload = { Time = 2.0, EmptyTime = 2.4 },   -- only without a Reload clip: the clip is the timer
    Range = 800,                                -- capped by Settings.Server.MaxRange
    Damage = {                                  -- see Shared/Damage
        Base = 25,
        FalloffStart = 150,
        FalloffEnd = 600,
        FalloffMultiplier = 0.6,
        FalloffCurve = 1,
        Min = 1,
        Max = 300,
        Zones = { Head = 3, Torso = 1, Limb = 0.75 },
    },
    Accuracy = {                                -- cone: Base * (Aim or Hip multiplier) + spray
        Base = 0.5,
        AimMultiplier = 0.5,
        HipMultiplier = 1,
        PerShot = 0.25,
        Max = 3,
        RecoveryDelay = 0.08,
        RecoveryTime = 0.5,
    },
    Pellets = { Count = 1, Spread = 0 },
    Recoil = {
        Camera = { Pitch = 1, Yaw = 0.3 },
    },
    Ads = {
        Fov = 60,
        Distance = 2.5,                         -- third person camera distance while aiming
        Shoulder = Vector3.new(1.2, 0.3, 0),
        Time = 0.15,
        AimTime = 0.12,                         -- aiming this long before the accuracy bonus applies
        Scope = false,
    },
    Effects = {
        Tracer = { Enabled = true, Every = 1 }, -- plus every field of Settings.Effects.Tracer
    },
    Sounds = {},                                -- slot -> child of Assets/Sounds
    Animations = {},                            -- slot -> published animation id
}

WeaponConfig.Classes = {
    Pistol = {
        FireModes = { "Semi" },
        Rpm = 420,
        Magazine = 15,
        Reserve = 60,
        Reload = { Time = 1.6, EmptyTime = 1.9 },
        Range = 400,
        Damage = { Base = 26, FalloffStart = 40, FalloffEnd = 220, FalloffMultiplier = 0.45, FalloffCurve = 1, Zones = { Head = 3.5 } },
        Accuracy = { Base = 0.35, PerShot = 0.35, Max = 2.5, RecoveryTime = 0.35 },
        Recoil = { Camera = { Pitch = 1.4, Yaw = 0.4 } },
        Ads = { Fov = 65, Distance = 3 },
    },
    SMG = {
        FireModes = { "Auto", "Semi" },
        Rpm = 800,
        Magazine = 30,
        Reserve = 120,
        Reload = { Time = 2.1, EmptyTime = 2.5 },
        Range = 550,
        Damage = { Base = 20, FalloffStart = 60, FalloffEnd = 320, FalloffMultiplier = 0.5, FalloffCurve = 1.2 },
        Accuracy = { Base = 0.6, PerShot = 0.18, Max = 3.0, RecoveryTime = 0.4 },
        Recoil = { Camera = { Pitch = 0.7, Yaw = 0.35 } },
        Ads = { Fov = 62 },
    },
    Rifle = {
        FireModes = { "Auto", "Semi" },
        Rpm = 600,
        Magazine = 30,
        Reserve = 90,
        Reload = { Time = 2.4, EmptyTime = 3.0 },
        Range = 1100,
        Damage = { Base = 33, FalloffStart = 180, FalloffEnd = 750, FalloffMultiplier = 0.65, FalloffCurve = 1.5, Zones = { Head = 4 } },
        Accuracy = { Base = 0.3, PerShot = 0.28, Max = 3.2, RecoveryTime = 0.45 },
        Recoil = { Camera = { Pitch = 1.1, Yaw = 0.3 } },
        Ads = { Fov = 55 },
    },
    Shotgun = {
        FireModes = { "Semi" },
        Rpm = 70,
        Magazine = 6,
        Reserve = 24,
        Reload = { Time = 3.2, EmptyTime = 3.6 },
        Range = 150,
        Damage = { Base = 12, FalloffStart = 15, FalloffEnd = 90, FalloffMultiplier = 0.2, FalloffCurve = 0.8, Zones = { Head = 2 } },
        Accuracy = { Base = 1.0, PerShot = 0.5, Max = 2, RecoveryTime = 0.6 },
        Pellets = { Count = 8, Spread = 3.0 },
        Recoil = { Camera = { Pitch = 3, Yaw = 0.8 } },
        Ads = { Fov = 65, Distance = 3 },
        Effects = { Tracer = { Every = 2, Length = 3 } },
    },
    Sniper = {
        FireModes = { "Semi" },
        Rpm = 40,
        Magazine = 5,
        Reserve = 20,
        Reload = { Time = 3.5, EmptyTime = 3.9 },
        Range = 2500,
        Damage = { Base = 95, FalloffStart = 600, FalloffEnd = 2000, FalloffMultiplier = 0.85, FalloffCurve = 2, Zones = { Head = 2.5 } },
        Accuracy = { Base = 0.02, HipMultiplier = 40, AimMultiplier = 1, PerShot = 1.0, Max = 3, RecoveryTime = 0.8 },
        Recoil = { Camera = { Pitch = 4, Yaw = 0.5 } },
        Ads = { Fov = 20, Distance = 0, Scope = true, Time = 0.25, AimTime = 0.3 },
        Effects = { Tracer = { Speed = 2000, Length = 10 } },
    },
}

local function isArray(value)
    return type(value) == "table" and #value > 0
end

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, inner in value do
        copy[key] = deepCopy(inner)
    end
    return copy
end

local function deepMerge(base, overlay)
    local result = deepCopy(base)
    if type(overlay) ~= "table" then
        return result
    end
    for key, value in overlay do
        local existing = result[key]
        if type(value) == "table" and type(existing) == "table" and not isArray(value) and not isArray(existing) then
            result[key] = deepMerge(existing, value)
        else
            result[key] = deepCopy(value)
        end
    end
    return result
end

local function deepFreeze(value)
    if type(value) ~= "table" or table.isfrozen(value) then
        return value
    end
    for _, inner in value do
        deepFreeze(inner)
    end
    return table.freeze(value)
end

local cache = {}

function WeaponConfig.Exists(name: string): boolean
    return type(Weapons[name]) == "table"
end

function WeaponConfig.Get(name: string)
    local cached = cache[name]
    if cached then
        return cached
    end
    local raw = Weapons[name]
    if type(raw) ~= "table" then
        return nil
    end
    local classDefaults = WeaponConfig.Classes[raw.Class]
    assert(classDefaults, `[Azazel] Weapon {name} has unknown Class {tostring(raw.Class)}`)
    local base = deepMerge(WeaponConfig.Defaults, { Effects = { Tracer = Settings.Effects.Tracer } })
    base = deepMerge(base, classDefaults)
    local merged = deepMerge(base, raw)
    local reload = raw.Reload
    if reload and reload.Time and not reload.EmptyTime then
        -- Keep the class's empty/tactical ratio instead of its absolute EmptyTime.
        merged.Reload.EmptyTime = reload.Time * base.Reload.EmptyTime / base.Reload.Time
    end
    merged.Name = name
    merged.DisplayName = merged.DisplayName or name
    merged.ShotInterval = 60 / math.max(merged.Rpm, 1)
    merged.BurstInterval = 60 / math.max(merged.Burst.Rpm, 1)
    cache[name] = deepFreeze(merged)
    return cache[name]
end

function WeaponConfig.All(): { string }
    local names = {}
    for name, entry in Weapons do
        if type(entry) == "table" then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

local function applyModifier(value: number, modifier)
    if type(modifier) ~= "table" then
        return value
    end
    return (value + (modifier.Add or 0)) * (modifier.Mul or 1)
end

-- Equipment modifiers (EquipmentConfig.StackModifiers) on top of the weapon.
function WeaponConfig.Resolve(name: string, modifiers)
    local cfg = WeaponConfig.Get(name)
    if not cfg or next(modifiers) == nil then
        return cfg
    end
    local resolved = deepCopy(cfg)
    resolved.Magazine = math.max(1, math.floor(applyModifier(resolved.Magazine, modifiers.MagazineSize) + 0.5))
    resolved.Reserve = math.max(0, math.floor(applyModifier(resolved.Reserve, modifiers.Reserve) + 0.5))
    resolved.Accuracy.Base = applyModifier(resolved.Accuracy.Base, modifiers.Accuracy)
    resolved.Accuracy.PerShot = applyModifier(resolved.Accuracy.PerShot, modifiers.Accuracy)
    resolved.Recoil.Camera.Pitch = applyModifier(resolved.Recoil.Camera.Pitch, modifiers.RecoilCamera)
    resolved.Recoil.Camera.Yaw = applyModifier(resolved.Recoil.Camera.Yaw, modifiers.RecoilCamera)
    resolved.Reload.Time = applyModifier(resolved.Reload.Time, modifiers.ReloadTime)
    resolved.Reload.EmptyTime = applyModifier(resolved.Reload.EmptyTime, modifiers.ReloadTime)
    return deepFreeze(resolved)
end

return WeaponConfig
