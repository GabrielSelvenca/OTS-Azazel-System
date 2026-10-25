-- One set per weapon, bound to every Animator (character and viewmodel). Looped slots are
-- stances; others play over them. The clip length is the reload timer.

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local RunService = game:GetService("RunService")

local package = script.Parent.Parent
local Settings = require(package.Config.Settings)
local AnimationIds = require(package.Config.AnimationIds)
local Manifest = require(package.Assets.Manifest)

local Animations = {}

local TRACK_PREFIX = "Azazel"
local WEAPONS_FOLDER = "Weapons"

local slots: { [string]: boolean } = {}
for _, slot in Manifest.AnimationSlots do
    slots[slot] = true
end

local embedded: { [string]: { [string]: string } } = {}
local lengths: { [string]: { [string]: number } } = {}
local preloaded = false

local function keyframeLength(sequence: KeyframeSequence): number
    local last = 0
    for _, child in sequence:GetChildren() do
        if child:IsA("Keyframe") and child.Time > last then
            last = child.Time
        end
    end
    return last
end

local function isStance(slot: string): boolean
    return Manifest.SlotLoop[slot] == true
end

-- Lengths are read on both sides; a Studio client also registers the clips under a temporary id.
local function scanFolder(folder: Instance, key: string, register: boolean)
    local ids = {}
    local found = {}
    for _, child in folder:GetChildren() do
        if not child:IsA("KeyframeSequence") then
            if register then
                warn(`[Azazel] Assets/Animations/{key}/{child.Name} is a {child.ClassName}; only a KeyframeSequence plays`)
            end
        elseif not slots[child.Name] then
            if register then
                warn(`[Azazel] Assets/Animations/{key}/{child.Name} is not a slot; rename it to one of {table.concat(Manifest.AnimationSlots, ", ")}`)
            end
        else
            found[child.Name] = keyframeLength(child)
            if register then
                local ok, id = pcall(function()
                    return KeyframeSequenceProvider:RegisterKeyframeSequence(child)
                end)
                if ok and id then
                    ids[child.Name] = id
                else
                    warn(`[Azazel] Assets/Animations/{key}/{child.Name} could not be registered: {tostring(id)}`)
                end
            end
        end
    end
    embedded[key] = ids
    lengths[key] = found
end

function Animations.Preload()
    if preloaded then
        return
    end
    preloaded = true
    local register = RunService:IsClient() and RunService:IsStudio() and not Settings.Animations.PreferManifestInStudio
    local root = package.Assets:FindFirstChild("Animations")
    if not root then
        return
    end
    for _, child in root:GetChildren() do
        if child.Name == WEAPONS_FOLDER then
            for _, weapon in child:GetChildren() do
                scanFolder(weapon, `{WEAPONS_FOLDER}/{weapon.Name}`, register)
            end
        else
            scanFolder(child, child.Name, register)
        end
    end
    if Settings.Animations.LogSlots and RunService:IsClient() then
        for key, found in lengths do
            local list = {}
            for slot, length in found do
                table.insert(list, `{slot} ({string.format("%.2f", length)}s)`)
            end
            table.sort(list)
            print(`[Azazel] Animations {key}: {if #list > 0 then table.concat(list, ", ") else "none"}`)
        end
    end
end

local function clipLength(cfg, slot: string): number?
    Animations.Preload()
    local weapon = lengths[`{WEAPONS_FOLDER}/{cfg.Name}`]
    if weapon and weapon[slot] then
        return weapon[slot]
    end
    local class = lengths[cfg.Class]
    return if class then class[slot] else nil
end

-- The Reload/ReloadEmpty clip length, so the server timer and the animation end together.
function Animations.ReloadTime(cfg, empty: boolean): number
    local length = clipLength(cfg, if empty and clipLength(cfg, "ReloadEmpty") then "ReloadEmpty" else "Reload")
    if length and length > 0 then
        return length
    end
    return if empty then cfg.Reload.EmptyTime else cfg.Reload.Time
end

local function embeddedId(cfg, slot: string): string?
    local weapon = embedded[`{WEAPONS_FOLDER}/{cfg.Name}`]
    if weapon and weapon[slot] then
        return weapon[slot]
    end
    local class = embedded[cfg.Class]
    return if class then class[slot] else nil
end

local function publishedId(cfg, slot: string): string?
    local own = cfg.Animations[slot]
    if type(own) == "string" and own ~= "" then
        return own
    end
    local weapon = AnimationIds.Weapons[cfg.Name]
    local byWeapon = weapon and weapon[slot]
    if type(byWeapon) == "string" and byWeapon ~= "" then
        return byWeapon
    end
    local class = AnimationIds[cfg.Class]
    local byClass = class and class[slot]
    return if type(byClass) == "string" and byClass ~= "" then byClass else nil
end

local function resolveId(cfg, slot: string): string?
    if RunService:IsStudio() and not Settings.Animations.PreferManifestInStudio then
        local id = embeddedId(cfg, slot)
        if id then
            return id
        end
    end
    return publishedId(cfg, slot)
end

local function isToolTrack(track: AnimationTrack): boolean
    local animation = track.Animation
    if not animation or string.sub(animation.Name, 1, #TRACK_PREFIX) == TRACK_PREFIX then
        return false
    end
    for _, name in Settings.Animations.ToolTracks do
        if animation.Name == name or animation.AnimationId == name then
            return true
        end
    end
    return false
end

local Set = {}
Set.__index = Set

-- A held Tool makes the default Animate script pose the right arm; a stance has to win it.
function Set:_dropToolTracks(animator: Animator)
    if not Settings.Animations.OverrideToolTrack or not self.Stance then
        return
    end
    for _, track in animator:GetPlayingAnimationTracks() do
        if isToolTrack(track) then
            track:Stop(0)
        end
    end
end

function Set:_track(animator: Animator, slot: string): AnimationTrack?
    local entry = self.Bound[animator]
    local animation = self.Animations[slot]
    if not entry or not animation then
        return nil
    end
    if entry.Tracks[slot] then
        return entry.Tracks[slot]
    end
    local ok, track = pcall(animator.LoadAnimation, animator, animation)
    if not ok or not track then
        warn(`[Azazel] {self.Config.Name}: slot {slot} could not be loaded ({tostring(track)})`)
        return nil
    end
    track.Priority = Manifest.SlotPriority[slot] or Enum.AnimationPriority.Action
    track.Looped = isStance(slot)
    entry.Tracks[slot] = track
    return track
end

function Set:_play(animator: Animator, slot: string, fade: number)
    local track = self:_track(animator, slot)
    if track then
        track:Play(fade)
    end
end

function Set:Has(slot: string?): boolean
    return slot ~= nil and self.Animations[slot] ~= nil
end

function Set:Pick(...: string): string?
    for _, slot in { ... } do
        if self.Animations[slot] then
            return slot
        end
    end
    return nil
end

function Set:Bind(animator: Animator?)
    if not animator or self.Bound[animator] then
        return
    end
    local entry = { Tracks = {}, Connections = {} }
    self.Bound[animator] = entry
    table.insert(entry.Connections, animator.AnimationPlayed:Connect(function(track)
        if self.Stance and Settings.Animations.OverrideToolTrack and isToolTrack(track) then
            track:Stop(0)
        end
    end))
    if self.Stance then
        self:_play(animator, self.Stance, 0)
        self:_dropToolTracks(animator)
    end
end

function Set:Unbind(animator: Animator?)
    local entry = animator and self.Bound[animator]
    if not entry then
        return
    end
    for _, connection in entry.Connections do
        connection:Disconnect()
    end
    for _, track in entry.Tracks do
        track:Stop(0)
        track:Destroy()
    end
    self.Bound[animator] = nil
end

-- A stance replaces the one playing; an action plays over it, at its own speed.
function Set:Play(slot: string?): boolean
    if not slot or not self.Animations[slot] then
        return false
    end
    local fade = Settings.Animations.FadeTime
    if not isStance(slot) then
        for animator in self.Bound do
            self:_play(animator, slot, fade)
        end
        return true
    end
    if self.Stance == slot then
        return true
    end
    local previous = self.Stance
    self.Stance = slot
    for animator, entry in self.Bound do
        local old = if previous then entry.Tracks[previous] else nil
        if old then
            old:Stop(fade)
        end
        self:_play(animator, slot, fade)
        self:_dropToolTracks(animator)
    end
    return true
end

function Set:StopStance()
    local stance = self.Stance
    self.Stance = nil
    for _, entry in self.Bound do
        local track = stance and entry.Tracks[stance]
        if track then
            track:Stop(Settings.Animations.FadeTime)
        end
    end
end

function Set:Destroy()
    for animator in self.Bound do
        self:Unbind(animator)
    end
    for _, animation in self.Animations do
        animation:Destroy()
    end
    table.clear(self.Animations)
    self.Stance = nil
end

function Animations.NewSet(cfg)
    Animations.Preload()
    local set = setmetatable({
        Config = cfg,
        Animations = {},
        Bound = {},
        Stance = nil,
    }, Set)
    for _, slot in Manifest.AnimationSlots do
        local id = resolveId(cfg, slot)
        if id then
            local animation = Instance.new("Animation")
            animation.Name = TRACK_PREFIX .. slot
            animation.AnimationId = id
            set.Animations[slot] = animation
        end
    end
    return set
end

return Animations
