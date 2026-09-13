--[[
    Published animation ids, used outside Studio.

    In Studio the embedded KeyframeSequences under Assets/Animations play directly. In a live
    game Roblox only plays published animations, so after uploading each KeyframeSequence
    (right click > Save to Roblox) paste its "rbxassetid://..." here. Resolution order:
    weapon override (Weapons[Name][Slot]) -> class (Class[Slot]). R15 mirrors the same layout
    for the R15 rig. Dev.Commands.ReportMissingAnimationIds() lists what is still empty.
]]

return {
    Pistol = { Idle = "", Fire = "", Reload = "", Equip = "" },
    SMG = { Idle = "", Fire = "", Reload = "", Equip = "" },
    Rifle = { Idle = "", Fire = "", Reload = "", Equip = "" },
    Shotgun = { Idle = "", Fire = "", Reload = "", Equip = "" },
    Sniper = { Idle = "", Fire = "", Reload = "", Equip = "" },
    Weapons = {},
    R15 = {},
}
