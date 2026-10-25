-- A piece is a module under Config/Equipment: Name, DisplayName, Zone ("Head" | "Torso"),
-- DamageMultiplier, optional Durability { Max, LossPerHit = number | "Blocked" } and Modifiers.
local EquipmentConfig = {}

EquipmentConfig.Zones = { "Head", "Torso" }

local MODIFIER_KEYS = { "MagazineSize", "Reserve", "Accuracy", "RecoilCamera", "ReloadTime" }

local modules = {}
local cache = {}

for _, module in script.Parent.Equipment:GetChildren() do
    if module:IsA("ModuleScript") then
        modules[module.Name] = module
    end
end

function EquipmentConfig.Get(name: string)
    local cached = cache[name]
    if cached then
        return cached
    end
    local module = modules[name]
    if not module then
        return nil
    end
    local raw = require(module)
    assert(type(raw) == "table" and raw.Name == name, `[Azazel] Equipment module {name} must return a table with Name = "{name}"`)
    assert(table.find(EquipmentConfig.Zones, raw.Zone), `[Azazel] Equipment {name} has unknown Zone {tostring(raw.Zone)}`)
    local cfg = {
        Name = raw.Name,
        DisplayName = raw.DisplayName or raw.Name,
        Zone = raw.Zone,
        DamageMultiplier = raw.DamageMultiplier or 1,
        Durability = raw.Durability,
        Modifiers = raw.Modifiers or {},
    }
    cache[name] = table.freeze(cfg)
    return cfg
end

-- Sums Add and multiplies Mul across the worn pieces ({ [zone]: { Name } }, server state or snapshot).
function EquipmentConfig.StackModifiers(pieces: { [string]: { Name: string } })
    local stacked = {}
    for _, piece in pieces do
        local cfg = EquipmentConfig.Get(piece.Name)
        if not cfg then
            continue
        end
        for _, key in MODIFIER_KEYS do
            local modifier = cfg.Modifiers[key]
            if type(modifier) == "table" then
                local entry = stacked[key] or { Add = 0, Mul = 1 }
                entry.Add += modifier.Add or 0
                entry.Mul *= modifier.Mul or 1
                stacked[key] = entry
            end
        end
    end
    return stacked
end

return EquipmentConfig
