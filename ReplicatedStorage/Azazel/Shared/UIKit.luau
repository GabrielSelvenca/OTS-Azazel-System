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
    Stroke = Color3.fromRGB(255, 255, 255),
}

local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }

local function applyDefaults(instance: Instance, className: string)
    if TEXT_CLASSES[className] then
        local text = instance :: TextLabel
        text.BackgroundTransparency = 1
        text.BorderSizePixel = 0
        text.Font = Settings.Hud.Font
        text.TextColor3 = UIKit.Theme.Text
        text.TextSize = 16
    elseif className == "Frame" or className == "ImageLabel" or className == "ImageButton" then
        (instance :: Frame).BorderSizePixel = 0
    end
end

local function addPadding(parent: Instance, value)
    local padding = Instance.new("UIPadding")
    if type(value) == "number" then
        local dim = UDim.new(0, value)
        padding.PaddingTop, padding.PaddingBottom, padding.PaddingLeft, padding.PaddingRight = dim, dim, dim, dim
    else
        padding.PaddingTop = UDim.new(0, value.Top or 0)
        padding.PaddingBottom = UDim.new(0, value.Bottom or 0)
        padding.PaddingLeft = UDim.new(0, value.Left or 0)
        padding.PaddingRight = UDim.new(0, value.Right or 0)
    end
    padding.Parent = parent
end

local function addListLayout(parent: Instance, value)
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    if type(value) == "table" then
        layout.FillDirection = value.Direction or Enum.FillDirection.Vertical
        layout.Padding = UDim.new(0, value.Padding or 0)
        layout.HorizontalAlignment = value.HorizontalAlignment or Enum.HorizontalAlignment.Left
        layout.VerticalAlignment = value.VerticalAlignment or Enum.VerticalAlignment.Top
    else
        layout.Padding = UDim.new(0, tonumber(value) or 0)
    end
    layout.Parent = parent
end

function UIKit.New(className: string, props: { [string]: any }?): Instance
    local instance = Instance.new(className)
    applyDefaults(instance, className)
    local children, parent
    if props then
        for key, value in props do
            if key == "Parent" then
                parent = value
            elseif key == "Children" then
                children = value
            elseif key == "Corner" then
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, value)
                corner.Parent = instance
            elseif key == "Stroke" then
                local stroke = Instance.new("UIStroke")
                stroke.Color = value.Color or UIKit.Theme.Stroke
                stroke.Thickness = value.Thickness or 1
                stroke.Transparency = value.Transparency or 0
                stroke.Parent = instance
            elseif key == "Padding" then
                addPadding(instance, value)
            elseif key == "ListLayout" then
                addListLayout(instance, value)
            elseif key == "GridLayout" then
                local grid = Instance.new("UIGridLayout")
                grid.CellSize = value.CellSize
                grid.CellPadding = value.CellPadding or UDim2.new()
                grid.SortOrder = Enum.SortOrder.LayoutOrder
                grid.Parent = instance
            else
                (instance :: any)[key] = value
            end
        end
    end
    if children then
        for _, child in children do
            child.Parent = instance
        end
    end
    if parent then
        instance.Parent = parent
    end
    return instance
end

function UIKit.Text(props: { [string]: any }?): TextLabel
    return UIKit.New("TextLabel", props) :: TextLabel
end

function UIKit.Screen(name: string, props: { [string]: any }?): ScreenGui
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local existing = playerGui:FindFirstChild(name)
    if existing then
        existing:Destroy()
    end
    local merged = {
        Name = name,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = playerGui,
    }
    if props then
        for key, value in props do
            merged[key] = value
        end
    end
    return UIKit.New("ScreenGui", merged) :: ScreenGui
end

return UIKit
