local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local package = ReplicatedStorage:WaitForChild("Azazel")
local Settings = require(package.Config.Settings)
local Accuracy = require(package.Shared.Accuracy)
local Animations = require(package.Shared.Animations)
local Damage = require(package.Shared.Damage)
local Remotes = require(package.Shared.Remotes)
local Rig = require(package.Shared.Rig)
local WeaponModel = require(package.Shared.WeaponModel)
local Signal = require(package.Packages.Signal)

local CharacterRig = require(script.Parent.CharacterRig)
local Inventory = require(script.Parent.Inventory)
local Ragdoll = require(script.Parent.Ragdoll)

local Combat = {}

Combat.Shot = Signal.new()
Combat.Hit = Signal.new()
Combat.Kill = Signal.new()

local ATTACKER_ATTRIBUTE = "AzazelLastAttackerUserId"
local WEAPON_ATTRIBUTE = "AzazelLastWeapon"
local ATTACKED_AT_ATTRIBUTE = "AzazelLastAttackedAt"
local CREATOR_TAG_LIFETIME = 2
local WINDOW_SECONDS = 1
local MAX_YAW_ALLOWANCE = 170

local rngByPlayer: { [Player]: Random } = {}
local lastLook: { [Player]: Vector3 } = {}
local turnRate: { [Player]: number } = {}

local function rngFor(player: Player): Random
    local rng = rngByPlayer[player]
    if not rng then
        rng = Random.new()
        rngByPlayer[player] = rng
    end
    return rng
end

local function reject(player: Player, reason: string)
    Remotes.LogRejection(player, "Fire", reason)
    Inventory.PushStateDeferred(player)
end

-- On a flick the body lags the camera; widen the yaw cone by the measured turn rate.
local function sampleTurnRates(dt: number)
    if dt <= 0 then
        return
    end
    local keep = math.exp(-dt / math.max(Settings.Server.YawCatchUp, 0.01))
    for _, player in Players:GetPlayers() do
        local character = player.Character
        local rig = character and Rig.Get(character)
        local root = rig and character:FindFirstChild(rig.Root)
        local look = if root and root:IsA("BasePart") then Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z) else nil
        local previous = lastLook[player]
        lastLook[player] = look
        if not look or look.Magnitude < 0.05 then
            turnRate[player] = nil
            continue
        end
        local decayed = (turnRate[player] or 0) * keep
        if previous and previous.Magnitude >= 0.05 then
            local turned = math.deg(math.acos(math.clamp(previous.Unit:Dot(look.Unit), -1, 1)))
            decayed = math.max(decayed, turned / dt)
        end
        turnRate[player] = if decayed > 1 then decayed else nil
    end
end

local function yawAllowance(player: Player): number
    local lead = (turnRate[player] or 0) * Settings.Server.YawCatchUp
    return math.min(Settings.Server.MaxYawDelta + math.min(lead, Settings.Server.MaxYawCatchUp), MAX_YAW_ALLOWANCE)
end

local function isFinite(vector: Vector3): boolean
    local x, y, z = vector.X, vector.Y, vector.Z
    return x == x and y == y and z == z and math.abs(x) ~= math.huge and math.abs(y) ~= math.huge and math.abs(z) ~= math.huge
end

local function withinWindow(state, rpm: number, now: number): boolean
    local times = state.ShotTimes
    local cutoff = now - WINDOW_SECONDS
    while times[1] and times[1] < cutoff do
        table.remove(times, 1)
    end
    local allowed = rpm / 60 * 1.15 + Settings.Server.WindowSlack
    return #times < allowed
end

local function tagAttacker(humanoid: Humanoid, attacker: Player, weaponName: string)
    humanoid:SetAttribute(ATTACKER_ATTRIBUTE, attacker.UserId)
    humanoid:SetAttribute(WEAPON_ATTRIBUTE, weaponName)
    humanoid:SetAttribute(ATTACKED_AT_ATTRIBUTE, workspace:GetServerTimeNow())
    local existing = humanoid:FindFirstChild("creator")
    if existing then
        existing:Destroy()
    end
    local creator = Instance.new("ObjectValue")
    creator.Name = "creator"
    creator.Value = attacker
    creator.Parent = humanoid
    Debris:AddItem(creator, CREATOR_TAG_LIFETIME)
end

local function resolveVictim(part: BasePart): (Humanoid?, Model?)
    local model = part:FindFirstAncestorOfClass("Model")
    while model do
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid then
            return humanoid, model
        end
        model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
    end
    return nil, nil
end

local function damageVictim(player: Player, cfg, hitPart: BasePart, origin: Vector3, hitPosition: Vector3)
    local humanoid, victimModel = resolveVictim(hitPart)
    if not humanoid or humanoid.Health <= 0 or victimModel == player.Character then
        return
    end
    local victimPlayer = Players:GetPlayerFromCharacter(victimModel)
    if victimPlayer and not Settings.Server.FriendlyFire and player.Team ~= nil and player.Team == victimPlayer.Team then
        return
    end
    local zone = Rig.ZoneOf(hitPart)
    local distance = (hitPosition - origin).Magnitude
    local damage = Damage.For(cfg, distance, zone)
    damage = Inventory.ApplyArmor(victimPlayer, zone, damage)
    damage = math.max(1, math.floor(damage + 0.5))

    local healthBefore = humanoid.Health
    tagAttacker(humanoid, player, cfg.Name)
    local lethal = healthBefore <= damage
    local breakJoints = if lethal then Ragdoll.Prepare(humanoid) else nil
    humanoid:TakeDamage(damage)
    local killed = healthBefore > 0 and humanoid.Health <= 0
    if breakJoints ~= nil and not killed then
        Ragdoll.Restore(humanoid, breakJoints)
    end

    Combat.Hit:Fire(player, humanoid, damage, zone, cfg)
    if killed then
        Ragdoll.Kill(victimModel, hitPart, (hitPosition - origin).Unit)
        Combat.Kill:Fire(player, victimPlayer, humanoid, cfg)
    end
    Remotes.FireClient("HitConfirmed", player, zone, damage, killed)
end

local DEBUG_FOLDER = "AzazelServerDebug"

local function debugTracers(origin: Vector3, ends: { Vector3 })
    local debugSettings = Settings.Debug
    local tracers = debugSettings.ServerTracers
    if not debugSettings.Enabled or not tracers.Enabled or not RunService:IsStudio() then
        return
    end
    local folder = workspace:FindFirstChild(DEBUG_FOLDER)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = DEBUG_FOLDER
        folder.Parent = workspace
    end
    for _, endPoint in ends do
        local distance = (endPoint - origin).Magnitude
        if distance < 0.5 then
            continue
        end
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.CastShadow = false
        part.Material = Enum.Material.Neon
        part.Color = tracers.Color
        part.Size = Vector3.new(tracers.Width, tracers.Width, distance)
        part.CFrame = CFrame.lookAt(origin, endPoint) * CFrame.new(0, 0, -distance / 2)
        part.Parent = folder
        Debris:AddItem(part, tracers.Lifetime)
    end
end

local function raycastParamsFor(character: Model): RaycastParams
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }
    params.IgnoreWater = true
    return params
end

local function onFire(player: Player, origin: Vector3, direction: Vector3, seq: number)
    local state = Inventory.Get(player)
    if not state then
        return
    end
    local slot = Inventory.GetSlot(state)
    local cfg = state.Config
    if not slot or not cfg or state.EquipState ~= "Ready" then
        return reject(player, "weapon not ready")
    end
    local character = player.Character
    if not CharacterRig.IsAlive(character) then
        return reject(player, "character dead")
    end
    if seq <= state.LastSeq then
        return reject(player, "stale sequence")
    end
    state.LastSeq = seq

    local now = os.clock()
    local grace = Settings.Server.RateGrace
    local interval = cfg.ShotInterval
    local fireMode = cfg.FireModes[slot.FireModeIndex]
    local newBurst = false
    if fireMode == "Burst" then
        interval = cfg.BurstInterval
        newBurst = state.BurstShots >= cfg.Burst.Count or now - state.BurstStartedAt >= cfg.ShotInterval
        if newBurst and now - state.BurstStartedAt < cfg.ShotInterval * grace then
            return reject(player, "burst rate")
        end
    end
    if now - state.LastShotAt < interval * grace then
        return reject(player, "fire rate")
    end
    if not withinWindow(state, if fireMode == "Burst" then math.max(cfg.Rpm, cfg.Burst.Rpm) else cfg.Rpm, now) then
        return reject(player, "fire window")
    end
    if slot.Ammo <= 0 then
        return reject(player, "no ammo")
    end

    local rig = Rig.Get(character)
    local head = character:FindFirstChild(rig.Head)
    local root = character:FindFirstChild(rig.Root)
    if not head or not root or not head:IsA("BasePart") or not root:IsA("BasePart") then
        return reject(player, "rig incomplete")
    end
    if not isFinite(origin) or not isFinite(direction) then
        return reject(player, "non finite vector")
    end
    if (origin - head.Position).Magnitude > Settings.Server.MaxOriginDistance then
        return reject(player, "origin too far")
    end
    local params = raycastParamsFor(character)
    if workspace:Raycast(head.Position, origin - head.Position, params) then
        return reject(player, "origin behind a wall")
    end
    if math.abs(direction.Magnitude - 1) > 0.01 then
        return reject(player, "direction not unit")
    end
    if math.abs(direction.Y) > math.sin(math.rad(Settings.Server.MaxPitch)) then
        return reject(player, "pitch out of range")
    end
    local flatDirection = Vector3.new(direction.X, 0, direction.Z)
    local flatLook = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
    if flatDirection.Magnitude > 0.05 and flatLook.Magnitude > 0.05 then
        local angle = math.deg(math.acos(math.clamp(flatDirection.Unit:Dot(flatLook.Unit), -1, 1)))
        if angle > yawAllowance(player) then
            return reject(player, "yaw out of range")
        end
    end

    slot.Ammo -= 1
    state.LastShotAt = now
    table.insert(state.ShotTimes, now)
    if newBurst then
        state.BurstStartedAt = now
        state.BurstShots = 0
    end
    state.BurstShots += 1

    local cone = Accuracy.Shoot(slot.Accuracy, cfg, now)
    local rng = rngFor(player)
    local range = math.min(cfg.Range, Settings.Server.MaxRange)
    local ends, hits = {}, {}
    local pelletCount = math.max(1, cfg.Pellets.Count)
    for pellet = 1, pelletCount do
        local aimed = Accuracy.Pellet(direction, cone, cfg, rng)
        local result = workspace:Raycast(origin, aimed * range, params)
        local endPoint = if result then result.Position else origin + aimed * range
        ends[pellet] = endPoint
        hits[pellet] = if result then result.Instance else false
        if result and result.Instance then
            damageVictim(player, cfg, result.Instance, origin, result.Position)
        end
    end

    local weaponModel = WeaponModel.Find(character)
    local muzzle = WeaponModel.MuzzlePosition(weaponModel) or origin
    Remotes.FireAllExcept("ShotFired", player, player, cfg.Name, muzzle, ends)
    Combat.Shot:Fire(player, cfg, origin, ends, hits)
    debugTracers(muzzle, ends)

    if slot.Ammo <= 0 then
        Inventory.PushState(player)
    end
end

local function onReload(player: Player)
    local state = Inventory.Get(player)
    if not state then
        return
    end
    local slot = Inventory.GetSlot(state)
    local cfg = state.Config
    local from = state.EquipState
    if not slot or not cfg or (from ~= "Ready" and from ~= "Relaxed") then
        return
    end
    local infinite = Settings.Server.InfiniteAmmo
    if slot.Ammo >= cfg.Magazine or (slot.Reserve <= 0 and not infinite) then
        Inventory.PushState(player)
        return
    end
    if not CharacterRig.IsAlive(player.Character) then
        return
    end
    local generation = Inventory.Bump(state)
    local duration = Animations.ReloadTime(cfg, slot.Ammo <= 0)
    slot.Accuracy.AimStartedAt = nil
    state.ReloadFrom = from
    state.EquipState = "Reloading"
    Inventory.PushState(player)
    task.delay(duration, function()
        local current = state.Config
        if Inventory.Get(player) ~= state or state.Generation ~= generation or not current then
            return
        end
        local missing = current.Magazine - slot.Ammo
        local moved = if infinite then missing else math.min(missing, slot.Reserve)
        slot.Ammo += moved
        if not infinite then
            slot.Reserve -= moved
        end
        state.EquipState = from
        Inventory.PushState(player)
    end)
end

local function onAim(player: Player, aiming: boolean)
    local state = Inventory.Get(player)
    local slot = state and Inventory.GetSlot(state)
    if not slot or (aiming and state.EquipState ~= "Ready") then
        return
    end
    slot.Accuracy.AimStartedAt = if aiming then os.clock() else nil
end

-- Cosmetic only: clamped and relayed, never part of a shot. A holstered player may only level out.
local function onLook(player: Player, pitch: number)
    local state = Inventory.Get(player)
    if not state or (state.EquipState == "Holstered" and pitch ~= 0) or pitch ~= pitch or math.abs(pitch) == math.huge then
        return
    end
    local limits = Settings.Camera.PitchLimits
    Remotes.FireAllExcept("LookUpdate", player, player, math.clamp(pitch, limits.Min, limits.Max))
end

local function onSetFireMode(player: Player, index: number)
    local state = Inventory.Get(player)
    local slot = state and Inventory.GetSlot(state)
    local cfg = state and state.Config
    if not slot or not cfg or not cfg.FireModes[index] then
        return
    end
    slot.FireModeIndex = index
    Inventory.PushState(player)
end

function Combat.Start()
    Remotes.OnServer("Fire", onFire)
    Remotes.OnServer("Reload", onReload)
    Remotes.OnServer("Aim", onAim)
    Remotes.OnServer("SetFireMode", onSetFireMode)
    Remotes.OnServer("Look", onLook)
    Players.PlayerRemoving:Connect(function(player)
        rngByPlayer[player] = nil
        lastLook[player] = nil
        turnRate[player] = nil
    end)
    RunService.Heartbeat:Connect(sampleTurnRates)
end

return Combat
