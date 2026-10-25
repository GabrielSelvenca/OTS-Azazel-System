local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Client = require(script.Parent.Parent)
local Settings = require(script.Parent.Parent.Parent.Config.Settings)

local InputController = {}

local Signals = Client.Signals
local Keys = Settings.Keys

local function bind(actionName: string, onBegin: () -> ()?, onEnd: () -> ()?, ...: Enum.KeyCode | Enum.UserInputType)
    ContextActionService:BindAction(actionName, function(_, inputState)
        if inputState == Enum.UserInputState.Begin then
            if onBegin then
                onBegin()
            end
        elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
            if onEnd then
                onEnd()
            end
        end
        return Enum.ContextActionResult.Pass
    end, false, ...)
end

function InputController.Start()
    local gamepad = Keys.Gamepad

    bind("AzazelFire", function()
        Signals.FireInput:Fire(true)
    end, function()
        Signals.FireInput:Fire(false)
    end, Keys.Fire, gamepad.Fire)

    bind("AzazelAim", function()
        Signals.AimInput:Fire(if Keys.AdsHold then true else not Client.Aiming)
    end, function()
        if Keys.AdsHold then
            Signals.AimInput:Fire(false)
        end
    end, Keys.Aim, gamepad.Aim)

    bind("AzazelReload", function()
        Signals.ReloadInput:Fire()
    end, nil, Keys.Reload, gamepad.Reload)

    bind("AzazelToggleView", function()
        Signals.ToggleViewInput:Fire()
    end, nil, Keys.ToggleView, gamepad.ToggleView)

    bind("AzazelSwapShoulder", function()
        Signals.SwapShoulderInput:Fire()
    end, nil, Keys.SwapShoulder)

    bind("AzazelFireMode", function()
        Signals.FireModeInput:Fire()
    end, nil, Keys.FireMode, gamepad.FireMode)

    bind("AzazelSprint", function()
        Signals.SprintInput:Fire(true)
    end, function()
        Signals.SprintInput:Fire(false)
    end, Keys.Sprint)

    bind("AzazelReady", function()
        Signals.ReadyInput:Fire()
    end, nil, Keys.Ready)

    -- With UseBackpack the Roblox hotbar picks the weapon.
    if not Settings.Server.UseBackpack then
        bind("AzazelHolster", function()
            Signals.SlotInput:Fire(0)
        end, nil, Keys.Holster)

        for index, key in Keys.Slots do
            bind(`AzazelSlot{index}`, function()
                Signals.SlotInput:Fire(index)
            end, nil, key)
        end

        bind("AzazelNextWeapon", function()
            local state = Client.State
            if not state then
                return
            end
            local total = #state.Slots
            for step = 1, total do
                local candidate = (state.Slot + step - 1) % total + 1
                if state.Slots[candidate] then
                    Signals.SlotInput:Fire(candidate)
                    return
                end
            end
        end, nil, gamepad.NextWeapon)
    end

    UserInputService.InputChanged:Connect(function(input, processed)
        if processed or input.UserInputType ~= Enum.UserInputType.MouseWheel then
            return
        end
        Signals.ZoomInput:Fire(input.Position.Z)
    end)
end

return InputController
