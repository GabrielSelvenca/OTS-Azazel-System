--[[
    Weapon configuration.

    A weapon is a module under Config/Weapons that returns a table with at least Name and Class.
    WeaponConfig.Get(name) merges three layers, later ones winning field by field:
    Defaults <- Classes[Class] <- the weapon module. So a weapon only lists what differs from
    its class, and a class only what differs from Defaults. The result is frozen; ShotInterval
    and BurstInterval are derived from Rpm.

    Fields (Defaults below shows every one with its default value):
      Grip            C1 of the Motor6D that holds the Handle (the hand seen from the Handle, same
                      meaning as Tool.Grip); copy it from a rig's Motor6D or tune with Dev.PrintGrip
      Pose            rest pose of the arms while no animation plays (first person): per arm,
                      degrees in torso space; Pitch raises the arm forward, Yaw swings it toward
                      the center (positive for the right arm, negative for the left), Roll twists
      FireModes       list of "Auto" | "Semi" | "Burst"; the first is the default
      Rpm, Burst      rounds per minute; Burst.Count shots per press at Burst.Rpm
      Magazine, Reserve, Reload{Time, EmptyTime}, EquipTime   seconds
      Range           raycast length in studs (capped by Settings.Server.MaxRange)
      Damage          Base * Zones[zone] * falloff, clamped to [Min, Max]; falloff is 1 until
                      FalloffStart, eases with FalloffCurve to FalloffMultiplier at FalloffEnd
                      (see Shared/Damage). Dev.Commands.PrintFalloff() prints the curve
      Accuracy        cone in degrees: Base * stance * (aim or hip multiplier) + spray;
                      spray grows PerShot up to Max and drains after RecoveryDelay over RecoveryTime
      Pellets         Count per shot and extra Spread per pellet (shotguns)
      Recoil          Camera kick in degrees, Viewmodel kick for first person
      Ads             aim down sights: Fov, camera Distance, Shoulder, Time to settle, AimTime
                      before the accuracy bonus applies, Scope overlay
      Effects         MuzzleFlash / Impact / Casing asset names and Tracer overrides
                      (defaults in Settings.Effects.Tracer)
      Sounds          slot -> sound asset name; Animations slot -> published animation id
]]

local Settings = require(script.Parent.Settings)

local WeaponConfig = {}

local TracerDefaults = Settings.Effects.Tracer
local DEFAULT_GRIP = CFrame.Angles(math.pi / 2, 0, 0)

WeaponConfig.ClassOrder = { "Pistol", "SMG", "Rifle", "Shotgun", "Sniper" }
WeaponConfig.FireModes = { "Auto", "Semi", "Burst" }

WeaponConfig.Defaults = {
    Grip = DEFAULT_GRIP,
    Pose = {
        RightArm = { Pitch = 80, Yaw = 12, Roll = 0 },
        LeftArm = { Pitch = 84, Yaw = -42, Roll = 0 },
    },
    FireModes = { "Semi" },
    Rpm = 400,
    Burst = { Count = 3, Rpm = 900 },
    Magazine = 12,
    Reserve = 48,
    Reload = { Mode = "Magazine", Time = 2.0, EmptyTime = 2.4 },
    EquipTime = 0.5,
    Range = 800,
    Damage = {
        Base = 25,
        FalloffStart = 150,
        FalloffEnd = 600,
        FalloffMultiplier = 0.6,
        FalloffCurve = 1,
        Min = 1,
        Max = 300,
        Zones = { Head = 3, Torso = 1, Limb = 0.75 },
    },
    Accuracy = {
        Base = 0.5,
        AimMultiplier = 0.5,
        HipMultiplier = 1,
        PerShot = 0.25,
        Max = 3,
        RecoveryDelay = 0.08,
        RecoveryTime = 0.5,
        Movement = { Stand = 1, Walk = 1, Run = 1, Air = 1, Crouch = 1 },
    },
    Pellets = { Count = 1, Spread = 0 },
    Recoil = {
        Camera = { Pitch = 1, Yaw = 0.3, Recovery = 0.5 },
        Viewmodel = { Kick = 0.1, Rise = 3, Damping = 0.6, Frequency = 12 },
    },
    Ads = {
        Fov = 60,
        Distance = 2.5,
        Shoulder = Vector3.new(1.2, 0.3, 0),
        Time = 0.15,
        AimTime = 0.12,
        Scope = false,
        SightDistance = 0.3,
        ViewmodelOffset = CFrame.new(-0.6, 0.45, 0),
    },
    Sprint = { Allowed = true, AccuracyMultiplier = 1 },
    Effects = {
        MuzzleFlash = "Default",
        Impact = "Default",
        Casing = "Default",
        Tracer = {
            Enabled = true,
            Every = 1,
            Speed = TracerDefaults.Speed,
            Length = TracerDefaults.Length,
            Width = TracerDefaults.Width,
            Color = TracerDefaults.Color,
            Style = TracerDefaults.Style,
            Beam = TracerDefaults.Beam,
            Trail = TracerDefaults.Trail,
            Light = TracerDefaults.Light,
        },
    },
    Sounds = {},
    Animations = {},
}

WeaponConfig.Classes = {
    Pistol = {
        FireModes = { "Semi" },
        Rpm = 420,
        Magazine = 15,
        Reserve = 60,
        Reload = { Time = 1.6, EmptyTime = 1.9 },
        EquipTime = 0.35,
        Range = 400,
        Damage = { Base = 26, FalloffStart = 40, FalloffEnd = 220, FalloffMultiplier = 0.45, FalloffCurve = 1, Zones = { Head = 3.5 } },
        Accuracy = { Base = 0.35, PerShot = 0.35, Max = 2.5, RecoveryTime = 0.35 },
        Recoil = { Camera = { Pitch = 1.4, Yaw = 0.4 } },
        Ads = { Fov = 65, Distance = 3 },
        Effects = { Casing = "Pistol" },
    },
    SMG = {
        FireModes = { "Auto", "Semi" },
        Rpm = 800,
        Magazine = 30,
        Reserve = 120,
        Reload = { Time = 2.1, EmptyTime = 2.5 },
        EquipTime = 0.45,
        Range = 550,
        Damage = { Base = 20, FalloffStart = 60, FalloffEnd = 320, FalloffMultiplier = 0.5, FalloffCurve = 1.2 },
        Accuracy = { Base = 0.6, PerShot = 0.18, Max = 3.0, RecoveryTime = 0.4 },
        Recoil = { Camera = { Pitch = 0.7, Yaw = 0.35 } },
        Ads = { Fov = 62 },
        Effects = { Casing = "Pistol" },
    },
    Rifle = {
        FireModes = { "Auto", "Semi" },
        Rpm = 600,
        Magazine = 30,
        Reserve = 90,
        Reload = { Time = 2.4, EmptyTime = 3.0 },
        EquipTime = 0.6,
        Range = 1100,
        Damage = { Base = 33, FalloffStart = 180, FalloffEnd = 750, FalloffMultiplier = 0.65, FalloffCurve = 1.5, Zones = { Head = 4 } },
        Accuracy = { Base = 0.3, PerShot = 0.28, Max = 3.2, RecoveryTime = 0.45 },
        Recoil = { Camera = { Pitch = 1.1, Yaw = 0.3 } },
        Ads = { Fov = 55 },
        Effects = { Casing = "Rifle" },
    },
    Shotgun = {
        FireModes = { "Semi" },
        Rpm = 70,
        Magazine = 6,
        Reserve = 24,
        Reload = { Time = 3.2, EmptyTime = 3.6 },
        EquipTime = 0.7,
        Range = 150,
        Damage = { Base = 12, FalloffStart = 15, FalloffEnd = 90, FalloffMultiplier = 0.2, FalloffCurve = 0.8, Zones = { Head = 2 } },
        Accuracy = { Base = 1.0, PerShot = 0.5, Max = 2, RecoveryTime = 0.6 },
        Pellets = { Count = 8, Spread = 3.0 },
        Recoil = { Camera = { Pitch = 3, Yaw = 0.8, Recovery = 0.7 } },
        Ads = { Fov = 65, Distance = 3 },
        Effects = { Casing = "Shell", Tracer = { Every = 2, Length = 3 } },
    },
    Sniper = {
        FireModes = { "Semi" },
        Rpm = 40,
        Magazine = 5,
        Reserve = 20,
        Reload = { Time = 3.5, EmptyTime = 3.9 },
        EquipTime = 0.8,
        Range = 2500,
        Damage = { Base = 95, FalloffStart = 600, FalloffEnd = 2000, FalloffMultiplier = 0.85, FalloffCurve = 2, Zones = { Head = 2.5 } },
        Accuracy = { Base = 0.02, HipMultiplier = 40, AimMultiplier = 1, PerShot = 1.0, Max = 3, RecoveryTime = 0.8 },
        Recoil = { Camera = { Pitch = 4, Yaw = 0.5, Recovery = 0.8 } },
        Ads = { Fov = 20, Distance = 0, Scope = true, Time = 0.25, AimTime = 0.3 },
        Effects = { Casing = "Rifle", Tracer = { Speed = 2000, Length = 10 } },
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

local weaponModules = {}
local cache = {}

local function scanWeapons()
    table.clear(weaponModules)
    for _, module in script.Parent.Weapons:GetChildren() do
        if module:IsA("ModuleScript") then
            weaponModules[module.Name] = module
        end
    end
end

local function ensureScanned()
    if next(weaponModules) == nil then
        scanWeapons()
    end
end

local function derive(cfg)
    cfg.ShotInterval = 60 / math.max(cfg.Rpm, 1)
    cfg.BurstInterval = 60 / math.max(cfg.Burst.Rpm, 1)
    cfg.DisplayName = cfg.DisplayName or cfg.Name
    cfg.Reload.EmptyTime = cfg.Reload.EmptyTime or cfg.Reload.Time
    return cfg
end

function WeaponConfig.Exists(name: string): boolean
    ensureScanned()
    return weaponModules[name] ~= nil
end

function WeaponConfig.Get(name: string)
    local cached = cache[name]
    if cached then
        return cached
    end
    ensureScanned()
    local module = weaponModules[name]
    if not module then
        return nil
    end
    local raw = require(module)
    assert(type(raw) == "table" and raw.Name == name, `[Azazel] Weapon module {name} must return a table with Name = "{name}"`)
    local classDefaults = WeaponConfig.Classes[raw.Class]
    assert(classDefaults, `[Azazel] Weapon {name} has unknown Class {tostring(raw.Class)}`)
    local merged = deepMerge(deepMerge(WeaponConfig.Defaults, classDefaults), raw)
    cache[name] = deepFreeze(derive(merged))
    return cache[name]
end

function WeaponConfig.All(): { string }
    ensureScanned()
    local names = {}
    for name in weaponModules do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function WeaponConfig.MaxRpm(): number
    local maxRpm = 0
    for _, name in WeaponConfig.All() do
        local cfg = WeaponConfig.Get(name)
        maxRpm = math.max(maxRpm, cfg.Rpm, cfg.Burst.Rpm)
    end
    return maxRpm
end

local function applyModifier(value: number, modifier)
    if type(modifier) ~= "table" then
        return value
    end
    return (value + (modifier.Add or 0)) * (modifier.Mul or 1)
end

function WeaponConfig.Resolve(name: string, modifiers)
    local cfg = WeaponConfig.Get(name)
    if not cfg then
        return nil
    end
    if type(modifiers) ~= "table" or next(modifiers) == nil then
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
