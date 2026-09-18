-- Animation slots: the names the loader looks for under Assets/Animations/<Class>/ and
-- Assets/Animations/Weapons/<Name>/, with the priority and loop flag it applies to each
-- KeyframeSequence by slot name. Everything under Assets is placed by hand in Studio.
return {
    AnimationClasses = { "Pistol", "SMG", "Rifle", "Shotgun", "Sniper" },
    AnimationSlots = { "Relaxed", "Idle", "Aim", "Reload", "ReloadEmpty", "Equip", "Sprint", "Inspect", "Unequip" },
    SlotPriority = {
        Idle = Enum.AnimationPriority.Idle,
        Relaxed = Enum.AnimationPriority.Idle,
        Aim = Enum.AnimationPriority.Movement,
        Sprint = Enum.AnimationPriority.Movement,
        Reload = Enum.AnimationPriority.Action,
        ReloadEmpty = Enum.AnimationPriority.Action,
        Inspect = Enum.AnimationPriority.Action,
        Equip = Enum.AnimationPriority.Action3,
        Unequip = Enum.AnimationPriority.Action3,
    },
    SlotLoop = { Idle = true, Aim = true, Sprint = true, Relaxed = true },
}
