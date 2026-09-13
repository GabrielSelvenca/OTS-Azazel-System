local Settings = {}

Settings.Camera = {
    DefaultView = "Third",
    Distance = 6,
    MinDistance = 2,
    MaxDistance = 12,
    Shoulder = Vector3.new(1.6, 0.6, 0),
    PivotOffset = Vector3.new(0, 1.5, 0),
    FirstPersonOffset = Vector3.new(0, 1.5, 0),
    Sensitivity = 0.25,
    PitchLimits = { Min = -80, Max = 80 },
    CollisionRadius = 0.3,
    FovDefault = 70,
    FovDamping = 1,
    FovFrequency = 6,
    DistanceDamping = 1,
    DistanceFrequency = 6,
    RotateCharacter = true,
    TurnSmoothing = 0.06,
    RecoilRecovery = 0.4,
}

Settings.Viewmodel = {
    Offset = CFrame.new(0, -1.55, -0.35),
    Sway = { Amount = 0.06, Clamp = 0.25, Damping = 0.7, Frequency = 6 },
    Bob = { X = 0.04, Y = 0.03, Speed = 9 },
    HideCharacterInFirstPerson = true,
    ShowLegs = false,
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

Settings.Server = {
    MaxOriginDistance = 8,
    MaxYawDelta = 75,
    MaxPitch = 85,
    RateGrace = 0.9,
    WindowSlack = 2,
    MaxRange = 2500,
    FriendlyFire = true,
    KickOnAbuse = false,
    AbuseThreshold = 30,
    FireRateLimit = 45,
    DefaultLoadout = {
        Weapons = { "DebugRifle" },
        Equipment = {},
    },
    GiveDefaultLoadoutOnSpawn = true,
    AutoEquipSlot = 1,
    MaxSlots = 5,
}

Settings.Animations = {
    PreferManifestInStudio = false,
    FadeTime = 0.1,
}

Settings.Effects = {
    TracerMaxLive = 64,
    CasingLifetime = 2,
    PoolSizes = { Tracer = 32, Casing = 24, Impact = 16 },
    FolderName = "AzazelEffects",
}

Settings.Debug = {
    LogRejections = true,
    PrintBoot = true,
}

Settings.Strings = {
    Reloading = "RELOADING",
    Equipping = "EQUIPPING",
    Empty = "EMPTY",
    Holstered = "UNARMED",
    FireModes = { Auto = "AUTO", Semi = "SEMI", Burst = "BURST" },
}

return Settings
