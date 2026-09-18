local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Client = require(script.Parent.Parent)
local package = script.Parent.Parent.Parent
local Settings = require(package.Config.Settings)
local Remotes = require(package.Shared.Remotes)
local Rig = require(package.Shared.Rig)
local Observers = require(package.Packages.Observers)

-- The arms and head of an armed character follow the camera pitch, on top of whatever clip is
-- playing: the local character from its own camera, every other one from the pitch the server
-- relays (Look / LookUpdate). Motor6D transforms never replicate, so each client turns every
-- character itself.
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

-- Before the Animator writes this frame: put back the pose it wrote last frame, so a joint no
-- clip keys does not pile up the turn frame after frame.
local function restore()
    for _, entry in entries do
        for motor, pose in entry.Base do
            motor.Transform = pose
        end
        table.clear(entry.Base)
    end
end

-- After the Animator wrote: turn each joint about the torso's right axis, through the joint,
-- on top of the pose.
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

-- The local pitch, in whole degrees, at most SendRate times a second and only when it moved;
-- a keepalive well inside Timeout keeps a still aim from levelling out on the others.
local function send()
    if not Client.Config then
        return
    end
    local now = os.clock()
    if now - lastSentAt < 1 / LookSettings.SendRate then
        return
    end
    local pitch = if Client.IsArmed() then math.round(cameraPitch()) else 0
    if pitch == lastSent and now - lastSentAt < LookSettings.Timeout * 0.5 then
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
        local character = if typeof(player) == "Instance" and player:IsA("Player") then player.Character else nil
        local entry = character and entries[character]
        if entry and type(pitch) == "number" then
            entry.Target = pitch
            entry.LastAt = os.clock()
        end
    end)

    RunService.PreAnimation:Connect(restore)
    RunService.PreSimulation:Connect(apply)
    RunService.Heartbeat:Connect(send)
end

return LookController
