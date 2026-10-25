local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Settings = require(script.Parent.Parent.Config.Settings)
local T = require(script.Parent.Parent.Packages.T)

local Remotes = {}

local FOLDER_NAME = "AzazelRemotes"
local WAIT_TIMEOUT = 15
local VIOLATION_HALF_LIFE = 60
local LOG_INTERVAL = 1

local slotCheck = T.intersection(T.integer, T.numberConstrained(0, Settings.Server.MaxSlots))
local fireModeCheck = T.intersection(T.integer, T.numberConstrained(1, 8))

local DEFINITIONS = {
    RequestState = { Kind = "RemoteEvent", Direction = "ClientToServer", Schema = T.tuple(), Rate = 2 },
    Equip = { Kind = "RemoteEvent", Direction = "ClientToServer", Schema = T.tuple(slotCheck), Rate = 8 },
    Reload = { Kind = "RemoteEvent", Direction = "ClientToServer", Schema = T.tuple(), Rate = 6 },
    Aim = { Kind = "RemoteEvent", Direction = "ClientToServer", Schema = T.tuple(T.boolean), Rate = 10 },
    Relax = { Kind = "RemoteEvent", Direction = "ClientToServer", Schema = T.tuple(T.boolean), Rate = 8 },
    SetFireMode = { Kind = "RemoteEvent", Direction = "ClientToServer", Schema = T.tuple(fireModeCheck), Rate = 5 },
    Fire = { Kind = "RemoteEvent", Direction = "ClientToServer", Schema = T.tuple(T.Vector3, T.Vector3, T.integer), Rate = Settings.Server.FireRateLimit },
    Look = { Kind = "UnreliableRemoteEvent", Direction = "ClientToServer", Schema = T.tuple(T.number), Rate = Settings.Look.SendRate * 2 },
    State = { Kind = "RemoteEvent", Direction = "ServerToClient" },
    ShotFired = { Kind = "UnreliableRemoteEvent", Direction = "ServerToClient" },
    HitConfirmed = { Kind = "RemoteEvent", Direction = "ServerToClient" },
    Ragdoll = { Kind = "RemoteEvent", Direction = "ServerToClient" },
    LookUpdate = { Kind = "UnreliableRemoteEvent", Direction = "ServerToClient" },
}

local folder: Folder? = nil
local buckets: { [Player]: { [string]: { Tokens: number, Last: number } } } = {}
local violations: { [Player]: { Count: number, At: number } } = {}
local lastLogged: { [Player]: { [string]: number } } = {}

local function definition(name: string)
    local def = DEFINITIONS[name]
    assert(def, `[Azazel] Remote "{tostring(name)}" is not declared in Remotes`)
    return def
end

local function getFolder(): Folder
    if folder then
        return folder
    end
    if RunService:IsServer() then
        local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
        if not existing then
            existing = Instance.new("Folder")
            existing.Name = FOLDER_NAME
            existing.Parent = ReplicatedStorage
        end
        folder = existing
    else
        folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, WAIT_TIMEOUT)
        assert(folder, "[Azazel] Remotes folder never replicated; is the server bootstrap running?")
    end
    return folder
end

function Remotes.EnsureAll()
    assert(RunService:IsServer(), "[Azazel] Remotes.EnsureAll is server-only")
    local container = getFolder()
    for name, def in DEFINITIONS do
        if not container:FindFirstChild(name) then
            local remote = Instance.new(def.Kind)
            remote.Name = name
            remote.Parent = container
        end
    end
end

function Remotes.Get(name: string): RemoteEvent | UnreliableRemoteEvent
    definition(name)
    local container = getFolder()
    local remote = container:FindFirstChild(name)
    if not remote and RunService:IsClient() then
        remote = container:WaitForChild(name, WAIT_TIMEOUT)
    end
    assert(remote, `[Azazel] Remote {name} missing; call Remotes.EnsureAll on the server first`)
    return remote :: RemoteEvent | UnreliableRemoteEvent
end

local function allow(player: Player, name: string, rate: number): boolean
    if not player.Parent then
        return false
    end
    local now = os.clock()
    local playerBuckets = buckets[player]
    if not playerBuckets then
        playerBuckets = {}
        buckets[player] = playerBuckets
    end
    local bucket = playerBuckets[name]
    if not bucket then
        bucket = { Tokens = rate, Last = now }
        playerBuckets[name] = bucket
    end
    bucket.Tokens = math.min(rate, bucket.Tokens + (now - bucket.Last) * rate)
    bucket.Last = now
    if bucket.Tokens < 1 then
        return false
    end
    bucket.Tokens -= 1
    return true
end

-- At most one warn per player per remote per second, and only with Settings.Debug.Enabled.
function Remotes.LogRejection(player: Player, name: string, reason: string)
    local debugSettings = Settings.Debug
    if not debugSettings.Enabled or not debugSettings.LogRejections or not player.Parent then
        return
    end
    local now = os.clock()
    local logged = lastLogged[player] or {}
    lastLogged[player] = logged
    if now - (logged[name] or -math.huge) < LOG_INTERVAL then
        return
    end
    logged[name] = now
    warn(`[Azazel] {name} rejected from {player.Name}: {reason}`)
end

-- The count halves every VIOLATION_HALF_LIFE seconds, so only a burst of abuse reaches the threshold.
local function violation(player: Player, name: string, reason: string)
    if not player.Parent then
        return
    end
    local now = os.clock()
    local record = violations[player] or { Count = 0, At = now }
    record.Count = record.Count * 0.5 ^ ((now - record.At) / VIOLATION_HALF_LIFE) + 1
    record.At = now
    violations[player] = record
    Remotes.LogRejection(player, name, reason)
    if Settings.Server.KickOnAbuse and record.Count >= Settings.Server.AbuseThreshold then
        player:Kick("Azazel: too many invalid requests")
    end
end

function Remotes.OnServer(name: string, handler: (Player, ...any) -> ()): RBXScriptConnection
    assert(RunService:IsServer(), "[Azazel] Remotes.OnServer is server-only")
    local def = definition(name)
    assert(def.Direction == "ClientToServer", `[Azazel] Remote {name} is not client-to-server`)
    local remote = Remotes.Get(name)
    return remote.OnServerEvent:Connect(function(player, ...)
        if not allow(player, name, def.Rate) then
            violation(player, name, "rate limit")
            return
        end
        local ok, err = def.Schema(...)
        if not ok then
            violation(player, name, tostring(err))
            return
        end
        handler(player, ...)
    end)
end

function Remotes.OnClient(name: string, handler: (...any) -> ()): RBXScriptConnection
    assert(RunService:IsClient(), "[Azazel] Remotes.OnClient is client-only")
    local def = definition(name)
    assert(def.Direction == "ServerToClient", `[Azazel] Remote {name} is not server-to-client`)
    return Remotes.Get(name).OnClientEvent:Connect(handler)
end

function Remotes.FireServer(name: string, ...)
    Remotes.Get(name):FireServer(...)
end

function Remotes.FireClient(name: string, player: Player, ...)
    Remotes.Get(name):FireClient(player, ...)
end

function Remotes.FireAllClients(name: string, ...)
    Remotes.Get(name):FireAllClients(...)
end

function Remotes.FireAllExcept(name: string, except: Player, ...)
    local remote = Remotes.Get(name)
    for _, player in Players:GetPlayers() do
        if player ~= except then
            remote:FireClient(player, ...)
        end
    end
end

if RunService:IsServer() then
    Players.PlayerRemoving:Connect(function(player)
        buckets[player] = nil
        violations[player] = nil
        lastLogged[player] = nil
    end)
end

return Remotes
