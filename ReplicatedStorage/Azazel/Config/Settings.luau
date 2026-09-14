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
-- camera. Shoulder and offsets are in character space (X right, Y up, Z back). The mouse wheel
-- zooms between MinDistance and MaxDistance in third person; it never enters first person
-- (that is the V key) and never goes as far as the Roblox default camera.
Settings.Camera = {
    DefaultView = "Third",                      -- "Third" | "First"
    Distance = 6,                               -- over the shoulder distance on spawn
    MinDistance = 2,                            -- closest the wheel zooms in
    MaxDistance = 30,                           -- farthest the wheel zooms out
    ZoomStep = 1.5,                             -- studs per wheel notch
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

-- First person arms: the viewmodel is a clone of the player's own rig (torso, arms, weapon)
-- parented to the camera. Offset places the rig root relative to the camera; aiming moves the
-- weapon's Sight attachment to the screen center (Ads.SightDistance per weapon), or uses
-- Ads.ViewmodelOffset when the model has no Sight.
Settings.Viewmodel = {
    Offset = CFrame.new(0, -1.9, -0.5),                                  -- rig root relative to the camera
    Sway = { Amount = 0.06, Clamp = 0.25, Damping = 0.7, Frequency = 6 }, -- radians per 10 px of mouse movement, clamp in radians
    Bob = { X = 0.04, Y = 0.03, Speed = 9 },                              -- walk bob amplitude (studs) and speed
    AimSwayMultiplier = 0.3,                                             -- sway kept while aiming
    AimBobMultiplier = 0.2,                                              -- bob kept while aiming
    HideCharacterInFirstPerson = true,
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
    UseBackpack = true,      -- weapons are Tools in the Backpack; the Roblox hotbar equips them, slot keys are off
    DefaultLoadout = {       -- given on spawn when GiveDefaultLoadoutOnSpawn is true
        Weapons = { "FAL", "MP5A3", "Beretta", "Remington700", "BFG50" },
        Equipment = { "HelmetLight", "VestLight" },
    },
    GiveDefaultLoadoutOnSpawn = false,
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
        Low = { TracerEvery = 3, TracerTrail = false, TracerLightDistance = 0, TracerMaxLive = 16, RagdollMaxLive = 4, Casings = false, Impacts = false, MuzzleFlash = true, Shake = false },
        Medium = { TracerEvery = 1, TracerTrail = true, TracerLightDistance = 150, TracerMaxLive = 32, RagdollMaxLive = 8, Casings = true, Impacts = true, MuzzleFlash = true, Shake = true },
        High = { TracerEvery = 1, TracerTrail = true, TracerLightDistance = 300, TracerMaxLive = 64, RagdollMaxLive = 16, Casings = true, Impacts = true, MuzzleFlash = true, Shake = true },
    },
}

-- Visual effects. Tracer is the default look of every bullet tracer; any weapon or class can
-- override the same fields under its Effects.Tracer. Tracers are drawn at any distance (only
-- the live cap and TracerEvery per quality level limit them); MinPixelWidth keeps a far one
-- visible on screen. The light is a PointLight without shadows, only within TracerLightDistance
-- of the camera, with a fixed color so it never reads as the tracer color. It looks blocky with
-- Lighting.Technology on Voxel or Compatibility; use ShadowMap or Future.
Settings.Effects = {
    FolderName = "AzazelEffects",                          -- workspace folder that holds pooled parts
    PoolSizes = { Tracer = 32, Casing = 24, Impact = 16 }, -- parts created up front per effect
    CasingLifetime = 2,
    Tracer = {
        Color = Color3.fromRGB(255, 200, 40),
        Width = 0.2,                                       -- studs
        Length = 5,                                        -- visible rod length, studs
        Speed = 1200,                                      -- studs per second
        MinPixelWidth = 2,                                 -- never thinner than this on screen
        Style = "Rod",                                     -- "Rod" (Neon part) | "Beam" (flat strip, can carry a texture)
        Material = Enum.Material.Neon,                     -- Rod style
        Beam = {                                           -- Beam style
            Texture = "",                                  -- "rbxassetid://..." bullet texture, empty for a plain strip
            TextureLength = 1,
        },
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
            Color = Color3.fromRGB(255, 225, 170),        -- fixed, independent of the tracer color
            Brightness = 0.5,
            Range = 8,
            Shadows = false,
        },
    },
}

-- Ragdoll on death by an Azazel weapon; any other death keeps the Roblox default. The server
-- stops the joints from breaking, freezes the real character out of the way (anchored, no
-- collision, hidden by every client) and tells all clients where the killing shot came from.
-- Each client then builds its own local copy (Shared/Ragdoll) with BallSocketConstraints and
-- simulates it, so nothing is replicated; RagdollMaxLive per quality level caps how many
-- exist at once. Joint limits are in degrees, keyed by the Motor6D name with a Default.
Settings.Ragdoll = {
    Enabled = true,
    Lifetime = 8,               -- seconds the ragdoll stays before it is removed
    FadeTime = 1,               -- fade out during the last seconds of Lifetime
    Impulse = 30,               -- velocity (studs/s) added along the shot to the part that took the killing hit
    Joints = {
        Default = { UpperAngle = 45, Twist = 30 },
        Neck = { UpperAngle = 30, Twist = 40 },
        ["Left Shoulder"] = { UpperAngle = 90, Twist = 45 },
        ["Right Shoulder"] = { UpperAngle = 90, Twist = 45 },
        ["Left Hip"] = { UpperAngle = 60, Twist = 20 },
        ["Right Hip"] = { UpperAngle = 60, Twist = 20 },
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
