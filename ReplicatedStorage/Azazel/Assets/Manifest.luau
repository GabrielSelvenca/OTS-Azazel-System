-- Animation slots under Assets/Animations/<Class>/ and Assets/Animations/Weapons/<Name>/, with the
-- priority and loop applied to each KeyframeSequence by its name.
return {
    AnimationSlots = { "Relaxed", "Idle", "Aim", "Reload", "ReloadEmpty", "Equip", "Sprint" },
    SlotPriority = {
        Idle = Enum.AnimationPriority.Idle,
        Relaxed = Enum.AnimationPriority.Idle,
        Aim = Enum.AnimationPriority.Movement,
        Sprint = Enum.AnimationPriority.Movement,
        Reload = Enum.AnimationPriority.Action,
        ReloadEmpty = Enum.AnimationPriority.Action,
        Equip = Enum.AnimationPriority.Action3,
    },
    SlotLoop = { Idle = true, Aim = true, Sprint = true, Relaxed = true },
}
