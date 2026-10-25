-- Base * Zones[zone] * falloff, clamped to [Min, Max]. Falloff is 1 until FalloffStart and eases
-- to FalloffMultiplier at FalloffEnd; FalloffCurve > 1 holds full damage longer.
local Damage = {}

function Damage.Multiplier(damage, distance: number): number
    if distance <= damage.FalloffStart then
        return 1
    end
    if distance >= damage.FalloffEnd then
        return damage.FalloffMultiplier
    end
    local span = math.max(damage.FalloffEnd - damage.FalloffStart, 0.01)
    local alpha = (distance - damage.FalloffStart) / span
    local eased = alpha ^ math.max(damage.FalloffCurve, 0.01)
    return 1 + (damage.FalloffMultiplier - 1) * eased
end

function Damage.For(cfg, distance: number, zone: string): number
    local damage = cfg.Damage
    local raw = damage.Base * damage.Zones[zone] * Damage.Multiplier(damage, distance)
    return math.clamp(raw, damage.Min, damage.Max)
end

return Damage
