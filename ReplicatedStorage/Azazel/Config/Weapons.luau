-- Every weapon, keyed by name; an entry lists only what differs from its Class (Config/WeaponConfig).
-- Model is the name under Assets/Weapons (none: placeholder).
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
