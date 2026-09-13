local Azazel = {
    Version = require(script.Version),
    Settings = require(script.Config.Settings),
    WeaponConfig = require(script.Config.WeaponConfig),
    EquipmentConfig = require(script.Config.EquipmentConfig),
}

Azazel.Strings = Azazel.Settings.Strings

return Azazel
