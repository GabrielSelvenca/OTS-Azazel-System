-- Spread math shared by the server (the real roll) and the client (crosshair and predicted tracers).
local Accuracy = {}

export type State = {
    Spray: number,
    LastShotAt: number,
    EvaluatedAt: number,
    AimStartedAt: number?,
}

function Accuracy.NewState(now: number?): State
    return {
        Spray = 0,
        LastShotAt = -math.huge,
        EvaluatedAt = now or os.clock(),
        AimStartedAt = nil,
    }
end

local function step(state: State, cfg, now: number)
    local elapsed = now - state.EvaluatedAt
    state.EvaluatedAt = now
    if elapsed <= 0 or state.Spray <= 0 then
        return
    end
    local accuracy = cfg.Accuracy
    local idle = now - state.LastShotAt - accuracy.RecoveryDelay
    if idle <= 0 then
        return
    end
    local decay = (accuracy.Max / math.max(accuracy.RecoveryTime, 0.01)) * math.min(idle, elapsed)
    state.Spray = math.max(0, state.Spray - decay)
end

local function sample(direction: Vector3, coneDegrees: number, rng: Random): Vector3
    if coneDegrees <= 0 then
        return direction.Unit
    end
    local theta = math.rad(coneDegrees) * math.sqrt(rng:NextNumber())
    local phi = rng:NextNumber() * math.pi * 2
    local basis = CFrame.lookAt(Vector3.zero, direction.Unit)
    return (basis * CFrame.Angles(0, 0, phi) * CFrame.Angles(theta, 0, 0)).LookVector
end

-- The cone in degrees right now; aiming counts once it has lasted Ads.AimTime.
function Accuracy.Cone(state: State, cfg, now: number): number
    step(state, cfg, now)
    local accuracy = cfg.Accuracy
    local startedAt = state.AimStartedAt
    local aiming = startedAt ~= nil and now - startedAt >= cfg.Ads.AimTime
    return accuracy.Base * (if aiming then accuracy.AimMultiplier else accuracy.HipMultiplier) + state.Spray
end

-- The cone this shot fires with; the shot then adds its spray.
function Accuracy.Shoot(state: State, cfg, now: number): number
    local cone = Accuracy.Cone(state, cfg, now)
    state.Spray = math.min(state.Spray + cfg.Accuracy.PerShot, cfg.Accuracy.Max)
    state.LastShotAt = now
    return cone
end

function Accuracy.Pellet(direction: Vector3, cone: number, cfg, rng: Random): Vector3
    local aimed = sample(direction, cone, rng)
    if cfg.Pellets.Spread > 0 then
        aimed = sample(aimed, cfg.Pellets.Spread, rng)
    end
    return aimed
end

function Accuracy.PixelsFor(coneDegrees: number, fovDegrees: number, viewportHeight: number): number
    local halfFov = math.rad(math.max(fovDegrees, 1) / 2)
    return math.tan(math.rad(coneDegrees)) / math.tan(halfFov) * (viewportHeight / 2)
end

return Accuracy
