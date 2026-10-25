-- Damped spring on a Vector3, stepped by hand. Damping is the ratio (1 = no overshoot), Frequency in Hz.

local Spring = {}
Spring.__index = Spring

local MAX_SUBSTEP = 1 / 240

function Spring.new(damping: number, frequency: number, initial: Vector3?)
    return setmetatable({
        Position = initial or Vector3.zero,
        Velocity = Vector3.zero,
        Target = initial or Vector3.zero,
        Damping = damping,
        Frequency = frequency,
    }, Spring)
end

function Spring:Step(dt: number): Vector3
    local omega = 2 * math.pi * self.Frequency
    local steps = math.max(1, math.ceil(dt / MAX_SUBSTEP))
    local h = dt / steps
    local position, velocity = self.Position, self.Velocity
    for _ = 1, steps do
        local acceleration = -omega * omega * (position - self.Target) - 2 * self.Damping * omega * velocity
        velocity += acceleration * h
        position += velocity * h
    end
    self.Position, self.Velocity = position, velocity
    return position
end

return Spring
