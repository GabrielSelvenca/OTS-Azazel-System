-- Every weapon, one entry keyed by its name. An entry lists only what differs from
-- WeaponConfig.Defaults and its Class; the header of Config/WeaponConfig describes every field.
-- Model is the name under Assets/Weapons (none: placeholder cube). A weapon gets its own tracer
-- color and light with, for example,
--     Effects = { Tracer = { Color = Color3.fromRGB(80, 200, 255), Light = { Color = Color3.fromRGB(80, 200, 255), Brightness = 0.8 } } },
-- and its first person aim point from the Sight attachment on the model (the camera goes there).
return {
    FNFNC = {
        DisplayName = "FN FNC",
        Class = "Rifle",
        Model = "FN FNC",
        Magazine = 20,
    },
    HK = {
        DisplayName = "H&K",
        Class = "Rifle",
        Model = "H&K",
        Rpm = 750,
        Magazine = 37,
        Damage = { Base = 28 },
    },
}
