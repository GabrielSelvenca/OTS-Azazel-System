return {
    Folders = {
        "Weapons",
        "Animations",
        "Animations/Weapons",
        "Effects",
        "Sounds",
    },
    AnimationClasses = { "Pistol", "SMG", "Rifle", "Shotgun", "Sniper" },
    AnimationSlots = { "Idle", "Fire", "Reload", "Equip", "Aim", "ReloadEmpty", "Sprint", "Inspect", "Unequip" },
    SlotPriority = {
        Idle = Enum.AnimationPriority.Idle,
        Aim = Enum.AnimationPriority.Movement,
        Sprint = Enum.AnimationPriority.Movement,
        Fire = Enum.AnimationPriority.Action2,
        Reload = Enum.AnimationPriority.Action,
        ReloadEmpty = Enum.AnimationPriority.Action,
        Inspect = Enum.AnimationPriority.Action,
        Equip = Enum.AnimationPriority.Action3,
        Unequip = Enum.AnimationPriority.Action3,
    },
    SlotLoop = { Idle = true, Aim = true, Sprint = true },
    Import = {
        MovingParts = { "Magazine", "Bolt", "Bolt2", "Slide", "Pump", "Lever", "Cylinder" },
        AttachmentParts = { Muzzle = "Muzzle", Casingg = "Eject", Casing = "Eject", Eject = "Eject", Handle1 = "LeftHand" },
        Discard = { "PanMuzzle", "BayonetHitBox", "BayonetBlade", "StockClips" },
    },
}
