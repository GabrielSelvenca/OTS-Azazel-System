local Signal = require(script.Parent.Packages.Signal)

local SIGNAL_NAMES = {
    "FireInput",
    "AimInput",
    "ReloadInput",
    "SlotInput",
    "ToggleViewInput",
    "SwapShoulderInput",
    "ZoomInput",
    "FireModeInput",
    "SprintInput",
    "ReadyInput",
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
    SightOffset = nil, -- Vector3: the held weapon's Sight relative to the first person eye, in its axes; nil without one
    ViewmodelWeapon = nil, -- Model: the weapon drawn on the first person arms, the one effects should start from; nil in third person
}

for _, name in SIGNAL_NAMES do
    Client.Signals[name] = Signal.new()
end

-- Ready is the armed weapon: the only state that fires and aims. Holding also covers Relaxed,
-- the weapon drawn but lowered, where the reload still works.
function Client.IsReady(): boolean
    local state = Client.State
    return state ~= nil and state.EquipState == "Ready" and Client.Config ~= nil
end

function Client.IsHolding(): boolean
    local state = Client.State
    local equipState = state and state.EquipState
    return Client.Config ~= nil and (equipState == "Ready" or equipState == "Relaxed")
end

-- Armed is Ready or a reload started from Ready: the camera lock and the look pitch follow
-- it, so a reload never drops them.
function Client.IsArmed(): boolean
    local state = Client.State
    return state ~= nil and state.Armed == true and Client.Config ~= nil
end

return Client
