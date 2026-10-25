local TweenService = game:GetService("TweenService")

local Client = require(script.Parent.Parent)
local Quality = require(script.Parent.Parent.Quality)
local package = script.Parent.Parent.Parent
local Settings = require(package.Config.Settings)
local Remotes = require(package.Shared.Remotes)
local Rig = require(package.Shared.Rig)
local Ragdoll = require(package.Shared.Ragdoll)

local RagdollController = {}

local RagdollSettings = Settings.Ragdoll

local live: { Model } = {}

local function hideCharacter(character: Model)
    for _, descendant in character:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.Transparency = 1
            descendant.CanCollide = false
            descendant.CanQuery = false
            descendant.CanTouch = false
        elseif descendant:IsA("Decal") then
            descendant.Transparency = 1
        elseif descendant:IsA("BillboardGui") or descendant:IsA("SurfaceGui") then
            descendant.Enabled = false
        end
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    end
end

local function trimLive()
    local maxLive = Quality.Get().RagdollMaxLive
    while #live > 0 and #live >= maxLive do
        local oldest = table.remove(live, 1)
        if oldest then
            oldest:Destroy()
        end
    end
end

local function forget(ragdoll: Model)
    local index = table.find(live, ragdoll)
    if index then
        table.remove(live, index)
    end
end

local function fadeOut(ragdoll: Model)
    local info = TweenInfo.new(RagdollSettings.FadeTime, Enum.EasingStyle.Linear)
    for _, descendant in ragdoll:GetDescendants() do
        local fades = (descendant:IsA("BasePart") and descendant.Transparency < 1) or descendant:IsA("Decal")
        if fades then
            TweenService:Create(descendant, info, { Transparency = 1 }):Play()
        end
    end
end

local function scheduleRemoval(ragdoll: Model)
    local fadeAt = math.max(RagdollSettings.Lifetime - RagdollSettings.FadeTime, 0)
    task.delay(fadeAt, function()
        if ragdoll.Parent then
            fadeOut(ragdoll)
        end
    end)
    task.delay(RagdollSettings.Lifetime, function()
        forget(ragdoll)
        ragdoll:Destroy()
    end)
end

local function onRagdoll(character: Model?, hitPartName: string, direction: Vector3)
    if not RagdollSettings.Enabled or Quality.Get().RagdollMaxLive == 0 then
        return
    end
    -- A streamed out character arrives as nil.
    if not character or not character.Parent then
        return
    end
    local rig = Rig.Get(character)
    if not rig then
        return
    end
    local root = character:FindFirstChild(rig.Root)
    local inherited = if root and root:IsA("BasePart") then root.AssemblyLinearVelocity else Vector3.zero

    local ragdoll = Ragdoll.Build(character, rig)
    hideCharacter(character)
    if not ragdoll then
        return
    end
    trimLive()
    table.insert(live, ragdoll)
    ragdoll.Parent = Client.EffectsFolder()

    -- Every part gets the push, or the torso slides out from under the head and the body tips toward the shooter.
    local push = if direction.Magnitude > 0 then direction.Unit else Vector3.zero
    local body = inherited + push * RagdollSettings.BodyImpulse
    for _, child in ragdoll:GetChildren() do
        if child:IsA("BasePart") then
            child.AssemblyLinearVelocity = body
        end
    end
    local hitPart = ragdoll:FindFirstChild(hitPartName) or ragdoll.PrimaryPart
    if hitPart and hitPart:IsA("BasePart") then
        hitPart.AssemblyLinearVelocity = body + push * RagdollSettings.Impulse
    end
    scheduleRemoval(ragdoll)
end

function RagdollController.Start()
    Remotes.OnClient("Ragdoll", onRagdoll)
end

return RagdollController
