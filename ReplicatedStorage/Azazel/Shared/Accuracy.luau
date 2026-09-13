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

function Accuracy.Step(state: State, cfg, now: number)
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

function Accuracy.IsAiming(state: State, cfg, now: number): boolean
    local startedAt = state.AimStartedAt
    return startedAt ~= nil and (now - startedAt) >= cfg.Ads.AimTime
end

function Accuracy.Cone(cfg, state: State, aiming: boolean, stance: string?): number
    local accuracy = cfg.Accuracy
    local stanceMultiplier = accuracy.Movement[stance or "Stand"] or 1
    local aimMultiplier = if aiming then accuracy.AimMultiplier else accuracy.HipMultiplier
    return accuracy.Base * stanceMultiplier * aimMultiplier + state.Spray
end

function Accuracy.RegisterShot(state: State, cfg, now: number)
    state.Spray = math.min(state.Spray + cfg.Accuracy.PerShot, cfg.Accuracy.Max)
    state.LastShotAt = now
end

function Accuracy.Sample(direction: Vector3, coneDegrees: number, rng: Random): Vector3
    if coneDegrees <= 0 then
        return direction.Unit
    end
    local theta = math.rad(coneDegrees) * math.sqrt(rng:NextNumber())
    local phi = rng:NextNumber() * math.pi * 2
    local basis = CFrame.lookAt(Vector3.zero, direction.Unit)
    return (basis * CFrame.Angles(0, 0, phi) * CFrame.Angles(theta, 0, 0)).LookVector
end

function Accuracy.PixelsFor(coneDegrees: number, fovDegrees: number, viewportHeight: number): number
    local halfFov = math.rad(math.max(fovDegrees, 1) / 2)
    return math.tan(math.rad(coneDegrees)) / math.tan(halfFov) * (viewportHeight / 2)
end

return Accuracy
