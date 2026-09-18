--[[
    Damage by distance. Pure math shared by the server (the only one that applies it) and by
    anything that wants to draw the curve (Damage.Curve).

    Fields read from cfg.Damage:
      Base                damage of one bullet or pellet at point blank
      Zones[zone]         multiplier per hit zone (Head, Torso, Limb)
      FalloffStart        full damage up to this distance
      FalloffEnd          from here on the damage sits at Base * FalloffMultiplier
      FalloffMultiplier   fraction of Base kept at FalloffEnd and beyond (0.2 = keeps 20%)
      FalloffCurve        shape between Start and End: 1 linear, > 1 holds full damage longer and
                          drops late, < 1 drops early and levels out
      Min, Max            absolute clamp on the final damage of one hit, whatever the distance

    Range (cfg.Range) is the raycast length: past it the bullet does not exist, so the curve
    ends there.
]]

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
    local eased = alpha ^ math.max(damage.FalloffCurve or 1, 0.01)
    return 1 + (damage.FalloffMultiplier - 1) * eased
end

function Damage.For(cfg, distance: number, zone: string?): number
    local damage = cfg.Damage
    local zoneMultiplier = if zone then (damage.Zones[zone] or 1) else 1
    local raw = damage.Base * zoneMultiplier * Damage.Multiplier(damage, distance)
    return math.clamp(raw, damage.Min or 0, damage.Max or math.huge)
end

function Damage.Curve(cfg, step: number?, zone: string?): { { Distance: number, Multiplier: number, Damage: number } }
    local points = {}
    local stride = math.max(step or 10, 1)
    local distance = 0
    while distance <= cfg.Range do
        table.insert(points, {
            Distance = distance,
            Multiplier = Damage.Multiplier(cfg.Damage, distance),
            Damage = Damage.For(cfg, distance, zone),
        })
        distance += stride
    end
    if points[#points].Distance < cfg.Range then
        table.insert(points, {
            Distance = cfg.Range,
            Multiplier = Damage.Multiplier(cfg.Damage, cfg.Range),
            Damage = Damage.For(cfg, cfg.Range, zone),
        })
    end
    return points
end

return Damage
