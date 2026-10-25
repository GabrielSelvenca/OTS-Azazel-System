local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local package = ReplicatedStorage:WaitForChild("Azazel")
local Rig = require(package.Shared.Rig)
local WeaponModel = require(package.Shared.WeaponModel)
local Signal = require(package.Packages.Signal)

local CharacterRig = {}

CharacterRig.CharacterAdded = Signal.new()
CharacterRig.Died = Signal.new()

local WAIT_TIMEOUT = 10

local function onCharacter(player: Player, character: Model)
    local humanoid = character:WaitForChild("Humanoid", WAIT_TIMEOUT)
    if player.Character ~= character or not humanoid or not humanoid:IsA("Humanoid") then
        return
    end
    local rig = Rig.Get(character)
    if not rig then
        warn(`[Azazel] {player.Name} is not R6; Azazel only supports R6 avatars`)
        return
    end
    character:WaitForChild(rig.Hand, WAIT_TIMEOUT)
    if player.Character ~= character then
        return
    end
    character:SetAttribute(Rig.Attribute, rig.Name)
    humanoid.Died:Once(function()
        CharacterRig.Died:Fire(player, character)
    end)
    CharacterRig.CharacterAdded:Fire(player, character)
end

function CharacterRig.Attach(character: Model, cfg): Model?
    local model = WeaponModel.Clone(cfg)
    if not WeaponModel.Attach(character, model, cfg) then
        model:Destroy()
        return nil
    end
    return model
end

function CharacterRig.Detach(character: Model)
    WeaponModel.Detach(character)
end

function CharacterRig.IsAlive(character: Model?): boolean
    if not character or not character.Parent then
        return false
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health > 0
end

function CharacterRig.Start()
    local function bindPlayer(player: Player)
        player.CharacterAdded:Connect(function(character)
            onCharacter(player, character)
        end)
        if player.Character then
            task.spawn(onCharacter, player, player.Character)
        end
    end
    Players.PlayerAdded:Connect(bindPlayer)
    for _, player in Players:GetPlayers() do
        bindPlayer(player)
    end
end

return CharacterRig
