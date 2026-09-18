--[[
    Published animation ids, used outside Studio.

    In Studio the embedded KeyframeSequences under Assets/Animations play directly. In a live
    game Roblox only plays published animations, so after uploading each KeyframeSequence
    (right click > Save to Roblox) paste its "rbxassetid://..." here. Resolution order:
    weapon override (Weapons[Name][Slot]) -> class (Class[Slot]). R15 mirrors the same layout
    for the R15 rig.
]]

return {
    Pistol = { Relaxed = "", Idle = "", Aim = "", Reload = "" },
    SMG = { Relaxed = "", Idle = "", Aim = "", Reload = "" },
    Rifle = { Relaxed = "", Idle = "", Aim = "", Reload = "" },
    Shotgun = { Relaxed = "", Idle = "", Aim = "", Reload = "" },
    Sniper = { Relaxed = "", Idle = "", Aim = "", Reload = "" },
    Weapons = {},
    R15 = {},
}
