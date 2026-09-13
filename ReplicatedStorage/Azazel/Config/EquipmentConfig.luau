--[[
    Equipment configuration (helmet, vest, ...).

    A piece is a module under Config/Equipment that returns:
      Name, DisplayName
      Zone              "Head" | "Torso": which hit zone it protects
      DamageMultiplier  damage taken on that zone is multiplied by this (0.6 = blocks 40%)
      Durability        optional { Max, LossPerHit }; LossPerHit is a number per hit or "Blocked"
                        to lose the damage it absorbed. Omit it for a piece that never breaks.
      Modifiers         optional { MagazineSize = { Add, Mul }, Reserve, Accuracy, RecoilCamera,
                        ReloadTime, WalkSpeed }; StackModifiers sums Add and multiplies Mul
                        across every equipped piece
      Model             optional asset name under Assets/Equipment
]]

local EquipmentConfig = {}

EquipmentConfig.Zones = { "Head", "Torso" }

local MODIFIER_KEYS = { "MagazineSize", "Reserve", "Accuracy", "RecoilCamera", "ReloadTime", "WalkSpeed" }

local modules = {}
local cache = {}

local function scan()
    table.clear(modules)
    for _, module in script.Parent.Equipment:GetChildren() do
        if module:IsA("ModuleScript") then
            modules[module.Name] = module
        end
    end
end

local function ensureScanned()
    if next(modules) == nil then
        scan()
    end
end

function EquipmentConfig.Exists(name: string): boolean
    ensureScanned()
    return modules[name] ~= nil
end

function EquipmentConfig.Get(name: string)
    local cached = cache[name]
    if cached then
        return cached
    end
    ensureScanned()
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
        Model = raw.Model,
    }
    cache[name] = table.freeze(cfg)
    return cfg
end

function EquipmentConfig.All(): { string }
    ensureScanned()
    local names = {}
    for name in modules do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function EquipmentConfig.StackModifiers(list: { any })
    local stacked = {}
    for _, cfg in list do
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
