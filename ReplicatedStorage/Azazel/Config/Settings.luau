--[[
    Azazel global settings.

    Everything tunable that is not specific to one weapon or one piece of equipment lives here,
    one table per area. Weapons are in Config/Weapons, equipment in Config/Equipment, animation
    ids in Config/AnimationIds. Edit values in place; the game can also overwrite fields at
    runtime before the controllers start (require this module and assign).

    Units: studs for distances, seconds for times, degrees for angles.
]]

local Settings = {}

-- Third person camera, first person switch, ADS transitions and how the character follows the
-- camera. Shoulder and offsets are in character space (X right, Y up, Z back).
Settings.Camera = {
    DefaultView = "Third",                      -- "Third" | "First"
    Distance = 6,                               -- default over the shoulder distance
    MinDistance = 2,
    MaxDistance = 12,
    Shoulder = Vector3.new(1.6, 0.6, 0),        -- pivot offset; X flips when the shoulder swaps
    PivotOffset = Vector3.new(0, 1.5, 0),       -- pivot above the root, third person
    FirstPersonOffset = Vector3.new(0, 1.5, 0), -- camera position above the root, first person
    Sensitivity = 0.25,                         -- degrees per pixel of mouse delta
    PitchLimits = { Min = -80, Max = 80 },
    CollisionRadius = 0.3,                      -- sphere cast radius that keeps the camera out of walls
    FovDefault = 70,
    FovDamping = 1,                             -- spring towards the weapon ADS FOV
    FovFrequency = 6,
    DistanceDamping = 1,                        -- spring towards the weapon ADS distance
    DistanceFrequency = 6,
    RotateCharacter = true,                     -- character yaw follows the camera
    TurnSmoothing = 0.06,                       -- seconds to catch up the camera yaw
    RecoilRecovery = 0.4,                       -- seconds for the camera recoil to settle
}

-- First person arms: the viewmodel is a clone of the player's own rig parented to the camera.
Settings.Viewmodel = {
    Offset = CFrame.new(0, -1.55, -0.35),                                -- arms relative to the camera
    Sway = { Amount = 0.06, Clamp = 0.25, Damping = 0.7, Frequency = 6 }, -- mouse sway spring
    Bob = { X = 0.04, Y = 0.03, Speed = 9 },                              -- walk bob amplitude and speed
    HideCharacterInFirstPerson = true,
    ShowLegs = false,
}

-- Input bindings. Keyboard and mouse use UserInputType or KeyCode; the Gamepad table mirrors
-- the same actions with controller buttons. AdsHold = false makes aim a toggle.
Settings.Keys = {
    Fire = Enum.UserInputType.MouseButton1,
    Aim = Enum.UserInputType.MouseButton2,
    Reload = Enum.KeyCode.R,
    Slots = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five },
    Holster = Enum.KeyCode.Zero,
    ToggleView = Enum.KeyCode.V,
    SwapShoulder = Enum.KeyCode.Q,
    FireMode = Enum.KeyCode.B,
    Sprint = Enum.KeyCode.LeftShift,
    Inspect = Enum.KeyCode.F,
    Gamepad = {
        Fire = Enum.KeyCode.ButtonR2,
        Aim = Enum.KeyCode.ButtonL2,
        Reload = Enum.KeyCode.ButtonX,
        NextWeapon = Enum.KeyCode.ButtonY,
        ToggleView = Enum.KeyCode.ButtonR3,
        FireMode = Enum.KeyCode.DPadDown,
    },
    AdsHold = true,
}

-- HUD drawn in code by Client/Controllers/HudController. Crosshair sizes are in pixels; the gap
-- grows with the accuracy cone so it always shows the real spread.
Settings.Hud = {
    Crosshair = {
        BaseGap = 6,
        Thickness = 2,
        Length = 10,
        Dot = true,
        Color = Color3.fromRGB(255, 255, 255),
        HideWhenScoped = true,
    },
    HitmarkerTime = 0.12,
    HitmarkerColor = Color3.fromRGB(255, 255, 255),
    HitmarkerKillColor = Color3.fromRGB(255, 70, 70),
    Font = Enum.Font.GothamBold,
}

-- Server rules. The shot validation limits define how much a client may deviate before its
-- request is discarded; loosen them only if you see honest rejections in the Output.
Settings.Server = {
    MaxOriginDistance = 8,   -- shot origin must be within this many studs of the head
    MaxYawDelta = 75,        -- shot direction vs. character facing, degrees
    MaxPitch = 85,           -- shot pitch limit, degrees
    RateGrace = 0.9,         -- fraction of the shot interval accepted early (latency grace)
    WindowSlack = 2,         -- extra shots allowed per second over the fire rate
    MaxRange = 2500,         -- hard cap for every weapon raycast
    InfiniteAmmo = true,     -- reserve never drains (development default; turn off for release)
    FriendlyFire = true,     -- when false, players on the same Team take no damage from each other
    KickOnAbuse = false,     -- kick after AbuseThreshold remote violations
    AbuseThreshold = 30,
    FireRateLimit = 45,      -- Fire remote calls per second per player, on top of the weapon rate
    DefaultLoadout = {       -- given on spawn when GiveDefaultLoadoutOnSpawn is true
        Weapons = { "AutoRifle", "Pistol", "SubmachineGun", "Shotgun", "SniperRifle" },
        Equipment = { "HelmetLight", "VestLight" },
    },
    GiveDefaultLoadoutOnSpawn = true,
    AutoEquipSlot = 1,       -- slot equipped after the loadout is given; 0 keeps the player unarmed
    MaxSlots = 5,
}

-- Animation playback. PreferManifestInStudio = true uses the published ids from AnimationIds
-- even in Studio, instead of the embedded KeyframeSequences under Assets/Animations.
Settings.Animations = {
    PreferManifestInStudio = false,
    FadeTime = 0.1,
}

-- Effect quality. Source "Auto" follows the player's Roblox graphics setting (SavedLevels maps
-- the 1..10 slider to Medium/High) and, when that is Automatic, the measured frame rate
-- (AutoFps with hysteresis). Set Source to "Low" | "Medium" | "High" to force a level.
-- Each level is a table the effect controllers read; add fields here and read them with
-- Quality.Get().
Settings.Quality = {
    Source = "Auto",
    SavedLevels = { Medium = 4, High = 8 },
    AutoFps = { Medium = 30, High = 50, Hysteresis = 6 },
    SampleSeconds = 4,
    Levels = {
        Low = { TracerEvery = 3, TracerTrail = false, TracerLight = false, TracerMaxDistance = 250, TracerMaxLive = 16, Casings = false, Impacts = false, MuzzleFlash = true, Shake = false },
        Medium = { TracerEvery = 1, TracerTrail = true, TracerLight = true, TracerMaxDistance = 600, TracerMaxLive = 32, Casings = true, Impacts = true, MuzzleFlash = true, Shake = true },
        High = { TracerEvery = 1, TracerTrail = true, TracerLight = true, TracerMaxDistance = 2500, TracerMaxLive = 64, Casings = true, Impacts = true, MuzzleFlash = true, Shake = true },
    },
}

-- Visual effects. Tracer is the default look of every bullet tracer; any weapon or class can
-- override the same fields under its Effects.Tracer. The light is a PointLight without shadows
-- and looks blocky with Lighting.Technology on Voxel or Compatibility; use ShadowMap or Future.
Settings.Effects = {
    FolderName = "AzazelEffects",                          -- workspace folder that holds pooled parts
    PoolSizes = { Tracer = 32, Casing = 24, Impact = 16 }, -- parts created up front per effect
    CasingLifetime = 2,
    Tracer = {
        Color = Color3.fromRGB(255, 200, 40),
        Width = 0.2,                                       -- studs
        Length = 5,                                        -- visible rod length, studs
        Speed = 1200,                                      -- studs per second
        Style = "Trail",                                   -- only "Trail" exists today
        Material = Enum.Material.Neon,
        Trail = {                                          -- streak behind the rod
            Lifetime = 0.06,                               -- seconds; long enough to bridge the muzzle and the first frames
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.2),
                NumberSequenceKeypoint.new(1, 1),
            }),
            WidthScale = NumberSequence.new(1, 0.3),
        },
        Light = {
            Enabled = true,
            Brightness = 1.5,
            Range = 10,
            Shadows = false,
        },
    },
}

-- Debug helpers. Enabled is the master switch for the visual ones (ServerTracers, ClientShots),
-- which only ever run in Studio. PrintBoot and LogRejections are independent and safe live.
Settings.Debug = {
    Enabled = false,
    PrintBoot = true,           -- "[Azazel] <version> N/M systems started" on boot
    LogRejections = true,       -- warn in the Output when the server discards a client request
    ServerTracers = {           -- one line per shot drawn by the server, visible in the Server view
        Enabled = true,
        Color = Color3.fromRGB(255, 80, 80),
        Width = 0.08,
        Lifetime = 0.15,
    },
    ClientShots = {             -- client side of every shot: lines, points and a detailed print
        Enabled = true,
        Print = true,           -- "[Azazel:Shot]" and "[Azazel:Tracer]" in the Output
        Draw = true,            -- parts in workspace.AzazelShotDebug
        Lifetime = 3,
        LineWidth = 0.05,
        PointSize = 0.35,
        Colors = {
            Camera = Color3.fromRGB(80, 255, 120),  -- camera ray and head origin
            Aim = Color3.fromRGB(255, 255, 255),    -- point the crosshair is on
            Shot = Color3.fromRGB(80, 160, 255),    -- each pellet path
            End = Color3.fromRGB(255, 220, 80),     -- where each pellet stopped
            Muzzle = Color3.fromRGB(255, 80, 80),   -- muzzle attachment
            Anomaly = Color3.fromRGB(255, 0, 255),  -- pellet outside the expected cone
        },
    },
}

-- Text shown to the player. Override from the game to translate.
Settings.Strings = {
    Reloading = "RELOADING",
    Equipping = "EQUIPPING",
    Empty = "EMPTY",
    Holstered = "UNARMED",
    FireModes = { Auto = "AUTO", Semi = "SEMI", Burst = "BURST" },
}

return Settings
