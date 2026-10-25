local Players = game:GetService("Players")

local Settings = require(script.Parent.Parent.Config.Settings)

local UIKit = {}

UIKit.Theme = {
    Text = Color3.fromRGB(235, 235, 235),
    Muted = Color3.fromRGB(160, 160, 160),
    Panel = Color3.fromRGB(10, 10, 12),
    PanelTransparency = 0.35,
    Accent = Color3.fromRGB(255, 200, 80),
    Danger = Color3.fromRGB(255, 70, 70),
}

-- Corner and Padding (pixels) add a UICorner / UIPadding; every other key is a property.
function UIKit.New(className: string, props: { [string]: any }): Instance
    local instance = Instance.new(className)
    if instance:IsA("GuiObject") then
        instance.BorderSizePixel = 0
    end
    if instance:IsA("TextLabel") then
        instance.BackgroundTransparency = 1
        instance.Font = Settings.Hud.Font
        instance.TextColor3 = UIKit.Theme.Text
        instance.TextSize = 16
    end
    local parent = nil
    for key, value in props do
        if key == "Parent" then
            parent = value
        elseif key == "Corner" then
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, value)
            corner.Parent = instance
        elseif key == "Padding" then
            local padding = Instance.new("UIPadding")
            local dim = UDim.new(0, value)
            padding.PaddingTop, padding.PaddingBottom, padding.PaddingLeft, padding.PaddingRight = dim, dim, dim, dim
            padding.Parent = instance
        else
            (instance :: any)[key] = value
        end
    end
    instance.Parent = parent
    return instance
end

function UIKit.Text(props: { [string]: any }): TextLabel
    return UIKit.New("TextLabel", props) :: TextLabel
end

function UIKit.Screen(name: string, props: { [string]: any }): ScreenGui
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local existing = playerGui:FindFirstChild(name)
    if existing then
        existing:Destroy()
    end
    props.Name = name
    props.ResetOnSpawn = false
    props.IgnoreGuiInset = true
    props.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    props.Parent = playerGui
    return UIKit.New("ScreenGui", props) :: ScreenGui
end

return UIKit
