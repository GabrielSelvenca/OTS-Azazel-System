local Signal = require(script.Parent.Packages.Signal)

local SIGNAL_NAMES = {
    "FireInput",
    "AimInput",
    "ReloadInput",
    "SlotInput",
    "ToggleViewInput",
    "SwapShoulderInput",
    "FireModeInput",
    "SprintInput",
    "InspectInput",
    "StateChanged",
    "WeaponChanged",
    "AmmoChanged",
    "SprayChanged",
    "AimChanged",
    "ViewChanged",
    "LocalShot",
    "HitConfirmed",
    "Recoil",
}

local Client = {
    Signals = {},
    State = nil,
    Config = nil,
    View = "Third",
    Aiming = false,
}

for _, name in SIGNAL_NAMES do
    Client.Signals[name] = Signal.new()
end

function Client.IsReady(): boolean
    local state = Client.State
    return state ~= nil and state.EquipState == "Ready" and Client.Config ~= nil
end

return Client
