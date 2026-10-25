local Client = require(script.Parent.Parent)
local package = script.Parent.Parent.Parent
local Settings = require(package.Config.Settings)
local Accuracy = require(package.Shared.Accuracy)
local UIKit = require(package.Shared.UIKit)

local HudController = {}

local Signals = Client.Signals
local HudSettings = Settings.Hud
local Strings = Settings.Strings
local Theme = UIKit.Theme

local CROSSHAIR_DIRECTIONS = { Vector2.new(0, -1), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(1, 0) }
local AMMO_TEXT_SIZE = 34
local RELOADING_TEXT_SIZE = 22

local crosshairLines: { Frame } = {}
local crosshairFrame: Frame
local hitmarker: Frame
local ammoPanel: Frame
local weaponLabel: TextLabel
local ammoLabel: TextLabel
local reserveLabel: TextLabel
local modeLabel: TextLabel
local hitmarkerToken = 0
local lastAmmo = 0
local lastReserve = 0
local lastCone = 0

local function buildCrosshair(parent: Instance)
    local thickness = HudSettings.Crosshair.Thickness
    local length = HudSettings.Crosshair.Length
    crosshairFrame = UIKit.New("Frame", {
        Name = "Crosshair",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(2, 2),
        Parent = parent,
    }) :: Frame
    for index, direction in CROSSHAIR_DIRECTIONS do
        local vertical = direction.X == 0
        local frame = UIKit.New("Frame", {
            Name = `Line{index}`,
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = HudSettings.Crosshair.Color,
            Size = UDim2.fromOffset(if vertical then thickness else length, if vertical then length else thickness),
            Position = UDim2.fromScale(0.5, 0.5),
            Parent = crosshairFrame,
        }) :: Frame
        frame:SetAttribute("DirX", direction.X)
        frame:SetAttribute("DirY", direction.Y)
        crosshairLines[index] = frame
    end
    if HudSettings.Crosshair.Dot then
        UIKit.New("Frame", {
            Name = "Dot",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = HudSettings.Crosshair.Color,
            Size = UDim2.fromOffset(thickness, thickness),
            Position = UDim2.fromScale(0.5, 0.5),
            Parent = crosshairFrame,
        })
    end
end

local function setGap(gapPixels: number)
    local offset = gapPixels + HudSettings.Crosshair.Length / 2
    for _, frame in crosshairLines do
        local dirX = frame:GetAttribute("DirX") :: number
        local dirY = frame:GetAttribute("DirY") :: number
        frame.Position = UDim2.new(0.5, dirX * offset, 0.5, dirY * offset)
    end
end

local function refreshGap()
    local camera = workspace.CurrentCamera
    local pixels = Accuracy.PixelsFor(lastCone, camera.FieldOfView, camera.ViewportSize.Y)
    setGap(HudSettings.Crosshair.BaseGap + pixels)
end

local function buildHitmarker(parent: Instance)
    hitmarker = UIKit.New("Frame", {
        Name = "Hitmarker",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(24, 24),
        Visible = false,
        Parent = parent,
    }) :: Frame
    for _, angle in { 45, -45 } do
        for _, side in { -1, 1 } do
            local signX = if angle > 0 then 1 else -1
            UIKit.New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = HudSettings.HitmarkerColor,
                Size = UDim2.fromOffset(8, 2),
                Position = UDim2.new(0.5, side * 7 * signX, 0.5, side * 7),
                Rotation = angle,
                Parent = hitmarker,
            })
        end
    end
end

local function buildAmmoPanel(parent: Instance)
    local panel = UIKit.New("Frame", {
        Name = "AmmoPanel",
        Visible = false,
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = Theme.PanelTransparency,
        Position = UDim2.new(1, -24, 1, -24),
        Size = UDim2.fromOffset(220, 92),
        Corner = 8,
        Padding = 10,
        Parent = parent,
    })
    weaponLabel = UIKit.Text({
        Name = "Weapon",
        Size = UDim2.new(1, 0, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = Theme.Muted,
        TextSize = 14,
        Text = "",
        Parent = panel,
    })
    ammoLabel = UIKit.Text({
        Name = "Ammo",
        Position = UDim2.fromOffset(0, 20),
        Size = UDim2.new(0.6, 0, 0, 40),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextSize = AMMO_TEXT_SIZE,
        Text = "0",
        Parent = panel,
    })
    reserveLabel = UIKit.Text({
        Name = "Reserve",
        Position = UDim2.new(0.62, 0, 0, 30),
        Size = UDim2.new(0.38, 0, 0, 24),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Theme.Muted,
        TextSize = 18,
        Text = "/ 0",
        Parent = panel,
    })
    modeLabel = UIKit.Text({
        Name = "Mode",
        Position = UDim2.new(0, 0, 1, -16),
        Size = UDim2.new(1, 0, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = Theme.Accent,
        TextSize = 12,
        Text = "",
        Parent = panel,
    })
    ammoPanel = panel :: Frame
end

local function refreshAmmoPanel()
    local state = Client.State
    local reloading = state ~= nil and state.EquipState == "Reloading"
    if reloading then
        ammoLabel.Text = Strings.Reloading
        ammoLabel.TextColor3 = Theme.Accent
        ammoLabel.TextSize = RELOADING_TEXT_SIZE
        ammoLabel.Size = UDim2.new(1, 0, 0, 40)
    else
        ammoLabel.Text = tostring(lastAmmo)
        ammoLabel.TextColor3 = if lastAmmo <= 0 then Theme.Danger else Theme.Text
        ammoLabel.TextSize = AMMO_TEXT_SIZE
        ammoLabel.Size = UDim2.new(0.6, 0, 0, 40)
    end
    reserveLabel.Visible = not reloading
    reserveLabel.Text = if lastReserve == math.huge then "/ ∞" else `/ {lastReserve}`
end

-- Only Ready shows a crosshair; aiming a scope, or in first person, hides it for the sights.
local function refreshCrosshair()
    local state = Client.State
    local config = Client.Config
    local visible = config ~= nil and state ~= nil and state.EquipState == "Ready"
    if visible and Client.Aiming then
        local crosshair = HudSettings.Crosshair
        if (crosshair.HideWhenScoped and config.Ads.Scope) or (crosshair.HideWhenAimingFirstPerson and Client.View == "First") then
            visible = false
        end
    end
    crosshairFrame.Visible = visible
end

local function refreshState(state)
    local config = Client.Config
    local mode = config and config.FireModes[state.FireMode]
    ammoPanel.Visible = config ~= nil
    weaponLabel.Text = if config then config.DisplayName else ""
    modeLabel.Text = if mode then (Strings.FireModes[mode] or mode) else ""
    refreshCrosshair()
    refreshAmmoPanel()
end

local function refreshAmmo(current: number, reserve: number)
    lastAmmo = current
    lastReserve = reserve
    refreshAmmoPanel()
end

local function flashHitmarker(killed: boolean)
    hitmarkerToken += 1
    local token = hitmarkerToken
    local color = if killed then HudSettings.HitmarkerKillColor else HudSettings.HitmarkerColor
    for _, child in hitmarker:GetChildren() do
        if child:IsA("Frame") then
            child.BackgroundColor3 = color
        end
    end
    hitmarker.Visible = true
    task.delay(HudSettings.HitmarkerTime, function()
        if hitmarkerToken == token then
            hitmarker.Visible = false
        end
    end)
end

function HudController.Start()
    local screen = UIKit.Screen("AzazelHud", { DisplayOrder = 10 })
    buildCrosshair(screen)
    buildHitmarker(screen)
    buildAmmoPanel(screen)
    refreshGap()
    if Client.State then
        refreshState(Client.State)
        refreshAmmo(Client.State.Ammo, Client.State.Reserve)
    end

    Signals.StateChanged:Connect(refreshState)
    Signals.AmmoChanged:Connect(refreshAmmo)
    Signals.HitConfirmed:Connect(function(_, _, killed)
        flashHitmarker(killed)
    end)
    Signals.SprayChanged:Connect(function(coneDegrees)
        lastCone = coneDegrees
        refreshGap()
    end)
    workspace.CurrentCamera:GetPropertyChangedSignal("FieldOfView"):Connect(refreshGap)
    Signals.AimChanged:Connect(refreshCrosshair)
    Signals.ViewChanged:Connect(refreshCrosshair)
end

return HudController
