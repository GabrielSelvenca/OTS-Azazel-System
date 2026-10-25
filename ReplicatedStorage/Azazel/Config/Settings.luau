-- Units: studs, seconds, degrees. A game can overwrite fields before the systems start.
local Settings = {}

-- Offsets are in character space (X right, Y up, Z back). The wheel zooms in third person only.
Settings.Camera = {
    DefaultView = "Third",                      -- "Third" | "First", the view the first arming uses
    Distance = 6,
    MinDistance = 2,
    MaxDistance = 30,
    ZoomStep = 1.5,                             -- studs per wheel notch
    Shoulder = Vector3.new(1.6, 0.6, 0),        -- X flips when the shoulder swaps
    PivotOffset = Vector3.new(0, 1.5, 0),       -- pivot above the root, third person
    FirstPersonOffset = Vector3.new(0, 1.5, 0), -- the eye above the root (the R6 head)
    Sensitivity = 0.25,                         -- degrees per pixel of mouse delta
    PitchLimits = { Min = -80, Max = 80 },
    CollisionRadius = 0.3,
    FovDefault = 70,
    FovDamping = 1,
    FovFrequency = 6,
    DistanceDamping = 1,
    DistanceFrequency = 6,
    RotateCharacter = true,                     -- character yaw follows the camera
    TurnSmoothing = 0.06,
    RecoilRecovery = 0.4,
}

Settings.Viewmodel = {
    Sway = { Amount = 0.06, Clamp = 0.25, Damping = 0.7, Frequency = 6 }, -- radians per 10 px of mouse movement
    Bob = { X = 0.04, Y = 0.03, Speed = 9 },
    AimSwayMultiplier = 0.3,
    AimBobMultiplier = 0.2,
}

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
    Ready = Enum.KeyCode.F,                     -- toggles Relaxed <-> Ready
    Gamepad = {
        Fire = Enum.KeyCode.ButtonR2,
        Aim = Enum.KeyCode.ButtonL2,
        Reload = Enum.KeyCode.ButtonX,
        NextWeapon = Enum.KeyCode.ButtonY,
        ToggleView = Enum.KeyCode.ButtonR3,
        FireMode = Enum.KeyCode.DPadDown,
    },
    AdsHold = true,                             -- false: the aim key toggles
}

-- Crosshair sizes are in pixels; the gap grows with the accuracy cone.
Settings.Hud = {
    Crosshair = {
        BaseGap = 6,
        Thickness = 2,
        Length = 10,
        Dot = true,
        Color = Color3.fromRGB(255, 255, 255),
        HideWhenScoped = true,
        HideWhenAimingFirstPerson = true,
    },
    HitmarkerTime = 0.12,
    HitmarkerColor = Color3.fromRGB(255, 255, 255),
    HitmarkerKillColor = Color3.fromRGB(255, 70, 70),
    Font = Enum.Font.GothamBold,
}

-- Shot validation limits: loosen them only if honest shots get rejected.
Settings.Server = {
    MaxOriginDistance = 8,   -- shot origin within this many studs of the head
    MaxYawDelta = 75,        -- shot direction vs. character facing
    YawCatchUp = 0.25,       -- seconds of turning forgiven while the body catches up with the camera; 0 disables
    MaxYawCatchUp = 120,
    MaxPitch = 85,
    RateGrace = 0.9,         -- fraction of the shot interval accepted early (latency)
    WindowSlack = 2,         -- extra shots per second over the fire rate
    MaxRange = 2500,
    InfiniteAmmo = false,    -- reserve never drains
    FriendlyFire = true,     -- false: players on the same Team take no damage from each other
    KickOnAbuse = false,     -- kick after AbuseThreshold remote violations (the count halves every minute)
    AbuseThreshold = 30,
    FireRateLimit = 45,      -- Fire remote calls per second per player
    UseBackpack = true,      -- the held Tool decides the weapon; slot keys and the loadout below are off
    DefaultLoadout = {       -- UseBackpack off only
        Weapons = { "FNFNC" },
        Equipment = { "HelmetLight", "VestLight" },
    },
    GiveDefaultLoadoutOnSpawn = false,
    AutoEquipSlot = 1,       -- 0 keeps the player unarmed
    MaxSlots = 5,
}

-- PreferManifestInStudio plays the published AnimationIds in Studio too.
Settings.Animations = {
    PreferManifestInStudio = false,
    FadeTime = 0.1,
    LogSlots = false,           -- print the clips found under Assets/Animations
    OverrideToolTrack = true,   -- stop the default Animate tool track while a stance plays
    ToolTracks = { "toolnone", "ToolNone", "ToolNoneAnim", "rbxassetid://182393478" },
}

-- An armed character's arms and head follow the camera pitch, for everyone.
Settings.Look = {
    Enabled = true,
    SendRate = 15,       -- pitch packets per second
    Smoothing = 0.08,
    Timeout = 1,         -- seconds without a packet before a character levels out
}

Settings.Sounds = {
    Enabled = true,
}

-- Source "Auto" follows the Roblox graphics level, or the measured FPS when that is Automatic.
Settings.Quality = {
    Source = "Auto",                            -- "Auto" | "Low" | "Medium" | "High"
    SavedLevels = { Medium = 4, High = 8 },     -- graphics slider value where each level starts
    AutoFps = { Medium = 30, High = 50, Hysteresis = 6 },
    SampleSeconds = 4,
    Levels = {
        Low = { TracerEvery = 3, TracerTrail = false, TracerLightDistance = 0, TracerMaxLive = 16, RagdollMaxLive = 4 },
        Medium = { TracerEvery = 1, TracerTrail = true, TracerLightDistance = 150, TracerMaxLive = 32, RagdollMaxLive = 8 },
        High = { TracerEvery = 1, TracerTrail = true, TracerLightDistance = 300, TracerMaxLive = 64, RagdollMaxLive = 16 },
    },
}

-- Tracer is the default look; a weapon or class overrides fields under Effects.Tracer.
Settings.Effects = {
    FolderName = "AzazelEffects",
    Tracer = {
        Color = Color3.fromRGB(255, 209, 117),
        Width = 0.2,
        Length = 5,
        Speed = 1200,
        MinPixelWidth = 2,                      -- never thinner than this on screen
        Material = Enum.Material.Neon,
        Trail = {
            Lifetime = 0.06,                    -- long enough to bridge the muzzle and the first frames
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.2),
                NumberSequenceKeypoint.new(1, 1),
            }),
            WidthScale = NumberSequence.new(1, 0.3),
        },
        Light = {
            Enabled = true,
            Color = Color3.fromRGB(255, 240, 184), -- fixed so a colored tracer never tints the map
            Brightness = 0.5,
            Range = 8,
            Shadows = false,
        },
    },
}

-- Joint limits are keyed by Motor6D name, with a Default.
Settings.Ragdoll = {
    Enabled = true,
    Lifetime = 8,
    FadeTime = 1,               -- fade during the last seconds of Lifetime
    BodyImpulse = 10,           -- velocity along the shot on every part
    Impulse = 15,               -- extra velocity on the part that took the killing hit
    ColliderScale = 0.85,
    Joints = {
        Default = { UpperAngle = 45, Twist = 30 },
        Neck = { UpperAngle = 30, Twist = 40 },
        ["Left Shoulder"] = { UpperAngle = 90, Twist = 45 },
        ["Right Shoulder"] = { UpperAngle = 90, Twist = 45 },
        ["Left Hip"] = { UpperAngle = 60, Twist = 20 },
        ["Right Hip"] = { UpperAngle = 60, Twist = 20 },
    },
}

-- Enabled gates everything here except PrintBoot. ServerTracers only runs in Studio.
Settings.Debug = {
    Enabled = false,
    PrintBoot = true,
    LogRejections = true,       -- warn when the server discards a request, once a second per player and remote
    LogInventory = true,        -- print who took which slot, from which Tool
    ServerTracers = {           -- one line per shot, visible in the Server view
        Enabled = false,
        Color = Color3.fromRGB(255, 80, 80),
        Width = 0.02,
        Lifetime = 0.15,
    },
}

-- Text shown to the player. Override from the game to translate.
Settings.Strings = {
    Reloading = "Reloading...",
    FireModes = { Auto = "AUTO", Semi = "SEMI", Burst = "BURST" },
}

return Settings
