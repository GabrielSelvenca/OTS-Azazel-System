local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")

if not RunService:IsStudio() then
    return {}
end

local package = script.Parent.Parent
local Manifest = require(package.Assets.Manifest)
local WeaponConfig = require(package.Config.WeaponConfig)
local EquipmentConfig = require(package.Config.EquipmentConfig)
local AnimationIds = require(package.Config.AnimationIds)
local Rig = require(package.Shared.Rig)
local WeaponModel = require(package.Shared.WeaponModel)

local Commands = {}

local DUMMY_NAME = "AzazelDummy"
local RIG_PREFIX = "AzazelAnimRig_"
local CLASS_ATTRIBUTE = "AzazelClass"

local function ensureFolder(parent: Instance, name: string): Folder
    local existing = parent:FindFirstChild(name)
    if existing then
        return existing :: Folder
    end
    local folder = Instance.new("Folder")
    folder.Name = name
    folder.Parent = parent
    return folder
end

local function server()
    assert(RunService:IsServer(), "[Azazel] This command runs on the server (Play mode server view, or the command bar in edit mode)")
    return require(ServerStorage:WaitForChild("Azazel"))
end

local function firstPlayer(player: Player?): Player
    local target = player or Players:GetPlayers()[1]
    assert(target, "[Azazel] No player in the game")
    return target
end

local function localCharacter(): Model
    local character
    if RunService:IsClient() then
        character = Players.LocalPlayer.Character
    else
        character = firstPlayer().Character
    end
    assert(character, "[Azazel] No character")
    return character
end

local function formatNumber(value: number): string
    local rounded = math.floor(value * 1000 + 0.5) / 1000
    if rounded == math.floor(rounded) then
        return string.format("%d", rounded)
    end
    return string.format("%.3f", rounded)
end

local function formatCFrame(cf: CFrame): string
    local rx, ry, rz = cf:ToEulerAnglesXYZ()
    local position = cf.Position
    return string.format(
        "CFrame.new(%s, %s, %s) * CFrame.Angles(math.rad(%s), math.rad(%s), math.rad(%s))",
        formatNumber(position.X), formatNumber(position.Y), formatNumber(position.Z),
        formatNumber(math.deg(rx)), formatNumber(math.deg(ry)), formatNumber(math.deg(rz))
    )
end

function Commands.Setup()
    local assets = package.Assets
    for _, path in Manifest.Folders do
        local current: Instance = assets
        for segment in string.gmatch(path, "[^/]+") do
            current = ensureFolder(current, segment)
        end
    end
    local animations = assets.Animations
    for _, class in Manifest.AnimationClasses do
        ensureFolder(animations, class)
    end
    print("[Azazel] Assets folders ready")
end

function Commands.Weapons()
    for _, name in WeaponConfig.All() do
        local cfg = WeaponConfig.Get(name)
        print(`{name} ({cfg.Class}) rpm={cfg.Rpm} mag={cfg.Magazine} model={tostring(cfg.Model)}`)
    end
end

local DUMMY_RESPAWN_SECONDS = 3

local function spawnDummy(index: number, cframe: CFrame)
    local dummy = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
    dummy.Name = `{DUMMY_NAME}{index}`
    local humanoid = dummy:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayName = `Dummy {index}`
        humanoid.BreakJointsOnDeath = false
        humanoid.Died:Once(function()
            task.delay(DUMMY_RESPAWN_SECONDS, function()
                local alive = dummy.Parent ~= nil
                dummy:Destroy()
                if alive then
                    spawnDummy(index, cframe)
                end
            end)
        end)
    end
    dummy:PivotTo(cframe)
    dummy.Parent = workspace
end

function Commands.SpawnDummy(count: number?, distance: number?)
    server()
    local total = count or 1
    local spacing = 4
    local anchorPlayer = Players:GetPlayers()[1]
    local root = anchorPlayer and anchorPlayer.Character and anchorPlayer.Character:FindFirstChild("HumanoidRootPart")
    local base = if root then root.CFrame * CFrame.new(0, 0, -(distance or 20)) else CFrame.new(0, 5, -20)
    for index = 1, total do
        spawnDummy(index, base * CFrame.new((index - (total + 1) / 2) * spacing, 0, 0) * CFrame.Angles(0, math.pi, 0))
    end
    print(`[Azazel] Spawned {total} dummy(ies), respawning {DUMMY_RESPAWN_SECONDS}s after death`)
end

function Commands.ClearDummies()
    server()
    for _, child in workspace:GetChildren() do
        if child:IsA("Model") and child.Name:sub(1, #DUMMY_NAME) == DUMMY_NAME then
            child:Destroy()
        end
    end
end

function Commands.Give(name: string, player: Player?)
    local api = server()
    local target = firstPlayer(player)
    if WeaponConfig.Exists(name) then
        local slot = api.GiveWeapon(target, name)
        if slot then
            api.Equip(target, slot)
        end
        print(`[Azazel] Gave weapon {name} to {target.Name} in slot {tostring(slot)}`)
    elseif EquipmentConfig.Exists(name) then
        api.GiveEquipment(target, name)
        print(`[Azazel] Gave equipment {name} to {target.Name}`)
    else
        error(`[Azazel] Unknown weapon or equipment {name}`)
    end
end

local function toModel(source: Instance): Model
    if source:IsA("Model") then
        return source:Clone()
    end
    assert(source:IsA("Tool"), "[Azazel] ImportWeapon expects a Model or a Tool")
    local model = Instance.new("Model")
    for _, child in source:Clone():GetChildren() do
        child.Parent = model
    end
    return model
end

function Commands.ImportWeapon(source: Instance?, name: string?)
    local instance = source or Selection:Get()[1]
    assert(typeof(instance) == "Instance", "[Azazel] Select a Model or Tool, or pass one as the first argument")
    local weaponName = name or instance.Name
    Commands.Setup()
    local copy = toModel(instance)
    copy.Name = weaponName
    local handle = WeaponModel.Sanitize(copy)
    assert(handle, "[Azazel] Model has no BasePart to use as Handle")
    local folder = package.Assets.Weapons
    local existing = folder:FindFirstChild(weaponName)
    if existing then
        existing:Destroy()
    end
    copy.Parent = folder
    print(`[Azazel] Imported {weaponName} into Assets/Weapons. Config stub for Config/Weapons/{weaponName}.luau:`)
    print(table.concat({ "return {", `    Name = "{weaponName}",`, `    DisplayName = "{weaponName}",`, `    Class = "Rifle",`, `    Model = "{weaponName}",`, "}" }, string.char(10)))
    return copy
end

local function findMotor(character: Model): Motor6D
    local hand = Rig.GetHand(character)
    local motor = hand and hand:FindFirstChild(WeaponModel.MotorName)
    assert(motor and motor:IsA("Motor6D"), "[Azazel] No weapon attached to this character")
    return motor
end

local function currentGrip(character: Model): CFrame
    return findMotor(character).C1:Inverse()
end

local function setGrip(character: Model, grip: CFrame)
    findMotor(character).C1 = grip:Inverse()
end

function Commands.GripMove(x: number, y: number, z: number, character: Model?)
    local target = character or localCharacter()
    setGrip(target, currentGrip(target) * CFrame.new(x or 0, y or 0, z or 0))
    Commands.PrintGrip(target)
end

function Commands.GripRotate(x: number, y: number, z: number, character: Model?)
    local target = character or localCharacter()
    setGrip(target, currentGrip(target) * CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0)))
    Commands.PrintGrip(target)
end

function Commands.GripSet(grip: CFrame, character: Model?)
    local target = character or localCharacter()
    setGrip(target, grip)
    Commands.PrintGrip(target)
end

function Commands.GripReset(character: Model?)
    local target = character or localCharacter()
    local model = WeaponModel.Find(target)
    local weaponName = model and model:GetAttribute(WeaponModel.Attribute)
    local cfg = weaponName and WeaponConfig.Get(weaponName)
    assert(cfg, "[Azazel] No weapon config for the attached weapon")
    setGrip(target, cfg.Grip)
    Commands.PrintGrip(target)
end

function Commands.PrintGrip(character: Model?)
    local target = character or localCharacter()
    print(`    Grip = {formatCFrame(currentGrip(target))},`)
end

function Commands.AttachToRig(rig: Model, weaponName: string)
    local cfg = WeaponConfig.Get(weaponName)
    assert(cfg, `[Azazel] Unknown weapon {weaponName}`)
    local model = WeaponModel.Clone(cfg)
    local motor = WeaponModel.Attach(rig, model, cfg)
    assert(motor, "[Azazel] Could not attach: rig needs a Humanoid and a Right Arm")
    rig:SetAttribute(CLASS_ATTRIBUTE, cfg.Class)
    rig:SetAttribute(WeaponModel.Attribute, cfg.Name)
    return model
end

function Commands.BuildAnimationRig(weaponName: string)
    local cfg = WeaponConfig.Get(weaponName)
    assert(cfg, `[Azazel] Unknown weapon {weaponName}`)
    local rig = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
    rig.Name = RIG_PREFIX .. weaponName
    local root = rig:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        root.Anchored = true
    end
    local animate = rig:FindFirstChild("Animate")
    if animate then
        animate:Destroy()
    end
    local camera = workspace.CurrentCamera
    local spot = if camera then camera.CFrame * CFrame.new(0, 0, -12) else CFrame.new(0, 5, 0)
    rig:PivotTo(CFrame.new(spot.Position) * CFrame.Angles(0, math.pi, 0))
    rig.Parent = workspace
    Commands.AttachToRig(rig, weaponName)
    Selection:Set({ rig })
    print(`[Azazel] Rig {rig.Name} ready (class {cfg.Class}). Open the Animation Editor, animate Right Arm, Left Arm and Handle, save each animation with its slot name.`)
    return rig
end

local function slotFor(name: string): string?
    local lowered = string.lower(name)
    for _, slot in Manifest.AnimationSlots do
        if string.lower(slot) == lowered then
            return slot
        end
    end
    return nil
end

function Commands.CollectAnimSaves(rig: Model?, perWeapon: boolean?)
    local rigs = {}
    if rig then
        table.insert(rigs, rig)
    else
        for _, child in workspace:GetChildren() do
            if child:IsA("Model") and string.sub(child.Name, 1, #RIG_PREFIX) == RIG_PREFIX then
                table.insert(rigs, child)
            end
        end
    end
    assert(#rigs > 0, "[Azazel] No animation rig found; run BuildAnimationRig first")
    Commands.Setup()
    local moved, skipped = 0, 0
    for _, current in rigs do
        local saves = current:FindFirstChild("AnimSaves")
        local class = current:GetAttribute(CLASS_ATTRIBUTE)
        local weaponName = current:GetAttribute(WeaponModel.Attribute)
        if not saves or not class then
            warn(`[Azazel] {current.Name}: nothing saved yet (no AnimSaves)`)
            continue
        end
        local destination
        if perWeapon and weaponName then
            destination = ensureFolder(ensureFolder(package.Assets.Animations, "Weapons"), weaponName)
        else
            destination = ensureFolder(package.Assets.Animations, class)
        end
        for _, sequence in saves:GetChildren() do
            if not sequence:IsA("KeyframeSequence") then
                continue
            end
            local slot = slotFor(sequence.Name)
            if not slot then
                skipped += 1
                warn(`[Azazel] {current.Name}: "{sequence.Name}" is not a slot name, skipped. Slots: {table.concat(Manifest.AnimationSlots, ", ")}`)
                continue
            end
            local existing = destination:FindFirstChild(slot)
            if existing then
                existing:Destroy()
            end
            local copy = sequence:Clone()
            copy.Name = slot
            copy.Priority = Manifest.SlotPriority[slot] or Enum.AnimationPriority.Action
            copy.Loop = Manifest.SlotLoop[slot] == true
            copy.Parent = destination
            moved += 1
            print(`[Azazel] {slot} -> {destination:GetFullName()}`)
        end
    end
    print(`[Azazel] CollectAnimSaves: {moved} copied, {skipped} skipped`)
end

function Commands.ReportMissingAnimationIds()
    local missing = {}
    for _, class in Manifest.AnimationClasses do
        local ids = AnimationIds[class] or {}
        local folder = package.Assets:FindFirstChild("Animations")
        local classFolder = folder and folder:FindFirstChild(class)
        for _, slot in Manifest.AnimationSlots do
            local hasSequence = classFolder and classFolder:FindFirstChild(slot) ~= nil
            local id = ids[slot]
            local hasId = type(id) == "string" and id ~= ""
            if hasSequence and not hasId then
                table.insert(missing, `{class}.{slot}: KeyframeSequence present, no id in AnimationIds`)
            elseif hasId and not hasSequence then
                table.insert(missing, `{class}.{slot}: id in AnimationIds but no KeyframeSequence in Assets`)
            end
        end
    end
    if #missing == 0 then
        print("[Azazel] Animation ids: nothing missing")
    else
        for _, line in missing do
            warn("[Azazel] " .. line)
        end
    end
    return missing
end

function Commands.Doctor()
    local problems = {}
    local function report(text: string)
        table.insert(problems, text)
    end
    local assets = package:FindFirstChild("Assets")
    local weaponsFolder = assets and assets:FindFirstChild("Weapons")
    if not weaponsFolder then
        report("Assets/Weapons folder missing; run Setup()")
    end
    for _, name in WeaponConfig.All() do
        local ok, cfg = pcall(WeaponConfig.Get, name)
        if not ok then
            report(`Weapon {name}: {cfg}`)
            continue
        end
        for _, mode in cfg.FireModes do
            if not table.find(WeaponConfig.FireModes, mode) then
                report(`Weapon {name}: unknown fire mode {mode}`)
            end
        end
        if cfg.Model then
            local model = weaponsFolder and weaponsFolder:FindFirstChild(cfg.Model)
            if not model then
                report(`Weapon {name}: model {cfg.Model} not in Assets/Weapons (placeholder will be used)`)
            else
                local handle = model:FindFirstChild(WeaponModel.HandleName)
                if not handle or not handle:IsA("BasePart") then
                    report(`Weapon {name}: model has no Handle BasePart`)
                elseif not handle:FindFirstChild("Muzzle") then
                    report(`Weapon {name}: Handle has no Muzzle attachment`)
                end
            end
        else
            report(`Weapon {name}: no Model set (placeholder cube)`)
        end
    end
    for _, name in EquipmentConfig.All() do
        local ok, err = pcall(EquipmentConfig.Get, name)
        if not ok then
            report(`Equipment {name}: {err}`)
        end
    end
    if assets then
        for _, descendant in assets:GetDescendants() do
            if descendant:IsA("LuaSourceContainer") and not descendant:IsA("ModuleScript") then
                report(`Script found under Assets: {descendant:GetFullName()} (delete it)`)
            end
        end
    end
    for _, line in Commands.ReportMissingAnimationIds() do
        report(line)
    end
    if #problems == 0 then
        print("[Azazel] Doctor: all good")
    else
        for _, line in problems do
            warn("[Azazel] Doctor: " .. line)
        end
        print(`[Azazel] Doctor: {#problems} problem(s)`)
    end
    return problems
end

return Commands
