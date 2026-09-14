local ReplicatedStorage = game:GetService("ReplicatedStorage")

local package = ReplicatedStorage:WaitForChild("Azazel")
local Settings = require(package.Config.Settings)
local Remotes = require(package.Shared.Remotes)

local Ragdoll = {}

local RagdollSettings = Settings.Ragdoll

function Ragdoll.Prepare(humanoid: Humanoid): boolean
    local previous = humanoid.BreakJointsOnDeath
    if RagdollSettings.Enabled then
        humanoid.BreakJointsOnDeath = false
    end
    return previous
end

function Ragdoll.Restore(humanoid: Humanoid, previous: boolean)
    humanoid.BreakJointsOnDeath = previous
end

local function freeze(character: Model)
    for _, descendant in character:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanQuery = false
            descendant.CanTouch = false
        end
    end
end

function Ragdoll.Kill(character: Model, hitPart: BasePart, direction: Vector3)
    if not RagdollSettings.Enabled then
        return
    end
    freeze(character)
    Remotes.FireAllClients("Ragdoll", character, hitPart.Name, direction)
end

return Ragdoll
