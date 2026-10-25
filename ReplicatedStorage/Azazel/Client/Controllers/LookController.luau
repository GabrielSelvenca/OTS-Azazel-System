local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Client = require(script.Parent.Parent)
local package = script.Parent.Parent.Parent
local Settings = require(package.Config.Settings)
local Remotes = require(package.Shared.Remotes)
local Rig = require(package.Shared.Rig)
local Observers = require(package.Packages.Observers)

-- Motor6D transforms never replicate, so each client turns every armed character's arms and
-- head itself: its own from the camera, the others from the pitch the server relays.
local LookController = {}

local LookSettings = Settings.Look

type Entry = {
    Joints: { Motor6D },
    Base: { [Motor6D]: CFrame },
    Pitch: number,
    Target: number,
    LastAt: number,
    Local: boolean,
}

local entries: { [Model]: Entry } = {}
local lastSentAt = 0
local lastSent = 0

local function alphaFor(seconds: number, dt: number): number
    if seconds <= 0 then
        return 1
    end
    return 1 - math.exp(-dt / seconds)
end

local function cameraPitch(): number
    local look = workspace.CurrentCamera.CFrame.LookVector
    return math.deg(math.asin(math.clamp(look.Y, -1, 1)))
end

local function findJoints(character: Model): { Motor6D }
    local rig = Rig.Get(character)
    local found = {}
    if rig then
        for _, name in rig.LookJoints do
            local motor = character:FindFirstChild(name, true)
            if motor and motor:IsA("Motor6D") then
                table.insert(found, motor)
            end
        end
    end
    return found
end

-- Put back last frame's pose first, so a joint no clip keys does not accumulate the turn.
local function restore()
    for _, entry in entries do
        for motor, pose in entry.Base do
            motor.Transform = pose
        end
        table.clear(entry.Base)
    end
end

-- After the Animator: turn each joint about the torso's right axis, on top of the pose.
local function apply(dt: number)
    local now = os.clock()
    for character, entry in entries do
        if entry.Local then
            entry.Pitch = if Client.IsArmed() then cameraPitch() else 0
        else
            if now - entry.LastAt > LookSettings.Timeout then
                entry.Target = 0
            end
            entry.Pitch += (entry.Target - entry.Pitch) * alphaFor(LookSettings.Smoothing, dt)
        end
        if math.abs(entry.Pitch) < 0.01 then
            continue
        end
        if #entry.Joints == 0 then
            entry.Joints = findJoints(character)
        end
        local turn = CFrame.Angles(math.rad(entry.Pitch), 0, 0)
        for _, motor in entry.Joints do
            if motor.Parent then
                local pose = motor.Transform
                entry.Base[motor] = pose
                local joint = motor.C0.Rotation
                motor.Transform = joint:Inverse() * turn * joint * pose
            end
        end
    end
end

-- Whole degrees, only when it moved, plus a keepalive inside Timeout while armed; disarming
-- sends one final 0.
local function send()
    local now = os.clock()
    if now - lastSentAt < 1 / LookSettings.SendRate then
        return
    end
    local armed = Client.IsArmed()
    local pitch = if armed then math.round(cameraPitch()) else 0
    if pitch == lastSent and (not armed or now - lastSentAt < LookSettings.Timeout * 0.5) then
        return
    end
    lastSentAt = now
    lastSent = pitch
    Remotes.FireServer("Look", pitch)
end

function LookController.Start()
    if not LookSettings.Enabled then
        return
    end
    local localPlayer = Players.LocalPlayer

    Observers.observeCharacter(function(player, character)
        entries[character] = {
            Joints = findJoints(character),
            Base = {},
            Pitch = 0,
            Target = 0,
            LastAt = 0,
            Local = player == localPlayer,
        }
        return function()
            entries[character] = nil
        end
    end)

    Remotes.OnClient("LookUpdate", function(player, pitch)
        local entry = player.Character and entries[player.Character]
        if entry then
            entry.Target = pitch
            entry.LastAt = os.clock()
        end
    end)

    RunService.PreAnimation:Connect(restore)
    RunService.PreSimulation:Connect(apply)
    RunService.Heartbeat:Connect(send)
end

return LookController
