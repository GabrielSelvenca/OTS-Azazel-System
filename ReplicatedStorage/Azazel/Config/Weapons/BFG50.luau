-- One weapon. Only fields that differ from WeaponConfig.Defaults and the class need to be here;
-- see the header of Config/WeaponConfig for every field. Model is the name under Assets/Weapons.
return {
    Name = "BFG50",
    DisplayName = "BFG-50",
    Class = "Sniper",
    Model = "BFG50",
    Rpm = 25,
    Magazine = 1,
    Reserve = 12,
    Reload = { Time = 2.6, EmptyTime = 2.6 },
    Damage = { Base = 140 },
    Recoil = { Camera = { Pitch = 6, Yaw = 0.8, Recovery = 0.9 } },
}
