local Settings = require(script.Parent.Config.Settings)
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
    SightOffset = nil, -- Vector3: the first person weapon's Sight relative to the eye; nil without one
    ViewmodelWeapon = nil, -- Model: the first person weapon; nil in third person
}

for _, name in SIGNAL_NAMES do
    Client.Signals[name] = Signal.new()
end

function Client.IsReady(): boolean
    local state = Client.State
    return state ~= nil and state.EquipState == "Ready" and Client.Config ~= nil
end

function Client.IsHolding(): boolean
    local state = Client.State
    local equipState = state and state.EquipState
    return Client.Config ~= nil and (equipState == "Ready" or equipState == "Relaxed")
end

-- Ready, or a reload started from Ready: the camera lock and the look pitch follow this.
function Client.IsArmed(): boolean
    local state = Client.State
    return state ~= nil and state.Armed == true and Client.Config ~= nil
end

function Client.EffectsFolder(): Folder
    local folder = workspace:FindFirstChild(Settings.Effects.FolderName)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = Settings.Effects.FolderName
        folder.Parent = workspace
    end
    return folder
end

return Client
