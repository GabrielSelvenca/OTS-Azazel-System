# Azazel

A first and third person (over the shoulder) shooter system for Roblox, written in Luau and
built to be dropped into any experience. Server authoritative, data driven, UI built in code,
animations hand made and shipped with the package.

Current version: see `ReplicatedStorage/Azazel/Version.luau`. Channels and numbering are
explained in [COMMITS.md](COMMITS.md). Changes are listed in [CHANGELOG.md](CHANGELOG.md).

This README is about using Azazel from code, as a developer integrating it into a game.

## What you get

- Hitscan combat with a Counter-Strike style accuracy model: every weapon has a base
  inaccuracy, the first shot is the most accurate, holding the trigger opens the spread, letting
  go recovers it. Spread is rolled on the server.
- Five weapon classes (Pistol, SMG, Rifle, Shotgun, Sniper) with per-weapon overrides. Fire
  modes Auto, Semi and Burst. Shotgun pellets. Damage zones (head, torso, limbs) and falloff.
- Over the shoulder camera with locked mouse, wheel zoom, shoulder swap, aim down sights and a
  first person toggle (V) with a viewmodel cloned from the player's own rig.
- Weapons are Models attached to the character by a Motor6D, so hand made animations can move
  the weapon inside the hand. The inventory is the plain Roblox Backpack: a Tool that names a
  weapon takes a slot and the Roblox hotbar equips it (`Settings.Server.UseBackpack`; turn it
  off to drive slots with the number keys and the server API).
- HUD built in code: a crosshair that opens with the spray, an ammo panel and a hitmarker.
  Firing on an empty magazine reloads.
- An armed character's arms and head follow the camera pitch, for every player (`Settings.Look`).
- Closed remote registry with schema validation and rate limits on every request.
- Equipment (helmet, vest) that reduces damage by zone, with optional durability.

## Requirements

- Roblox Studio with **Script Sync** (native). The repository root maps 1:1 to the services:
  `ReplicatedStorage/`, `ServerStorage/`, `ServerScriptService/`, `StarterPlayer/`.
- **R6** avatars (Game Settings > Avatar > R6). Other characters are skipped with a warning.
- No build step, no Rojo, no Wally. Models, animations and sounds are placed by hand in Studio
  under `ReplicatedStorage/Azazel/Assets`.

## Install

1. Copy these into your place, keeping the paths:
   - `ReplicatedStorage/Azazel` (the whole folder)
   - `ServerStorage/Azazel` (the whole folder)
   - `ServerScriptService/Azazel.server.luau`
   - `StarterPlayer/StarterPlayerScripts/Azazel.local.luau`
2. In Studio, create the asset folders under `ReplicatedStorage/Azazel/Assets`: `Weapons`,
   `Animations` (with a `Weapons` folder inside) and `Sounds`.
3. Press Play. The Output prints `[Azazel] <version> 4/4 systems started` on the server and
   `[Azazel] client <version> 9/9 controllers started` on the client. To get a weapon, put a
   Tool named after one (`FNFNC`, or any name with the attribute `AzazelWeapon = "FNFNC"`) in
   `StarterPack` with `RequiresHandle` off, and equip it from the hotbar. Any Humanoid takes
   damage, so R6 dummies from the Rig Builder make good targets.

If you clone this repository to contribute, also run `git config core.hooksPath .githooks`.

## Layout

```
ReplicatedStorage/Azazel/
  init.luau            Facade: Version, Settings, WeaponConfig, EquipmentConfig
  Version.luau         Single source of truth for the version
  Config/
    Settings.luau      Camera, keys, HUD, server limits, effects, debug flags, strings
    WeaponConfig.luau  Defaults <- Classes[class] <- Weapons[Name]
    Weapons.luau       Every weapon, one entry per name
    EquipmentConfig.luau, Equipment/   Armor pieces
    AnimationIds.luau  Published animation ids per class and slot
  Shared/              Remotes, Accuracy, Damage, Rig, WeaponModel, Animations, Spring, Ragdoll, UIKit
  Packages/            Vendored libraries (Trove, Signal, Spr, T, PartCache, Observers)
  Assets/              Manifest.luau, plus Weapons/, Animations/, Sounds/ placed in Studio
  Client/              Client bus (init.luau), Quality, Controllers/
ServerStorage/Azazel/
  init.luau            Server API
  Systems/             CharacterRig, Inventory, Backpack, Combat, Ragdoll
```

## Server API

```lua
local Azazel = require(game.ServerStorage.Azazel)

Azazel.GiveWeapon(player, "FNFNC")               -- first free slot, returns the slot index
Azazel.GiveWeapon(player, "HK", 2)               -- specific slot (1..Settings.Server.MaxSlots)
Azazel.RemoveWeapon(player, 2)
Azazel.SetLoadout(player, { Weapons = { "FNFNC", "HK" }, Equipment = { "VestLight" } })
Azazel.Equip(player, 1)                          -- 0 holsters
Azazel.SetRelaxed(player, true)                  -- lowers the weapon (Relaxed); false arms it (Ready)
Azazel.GetState(player)                          -- snapshot: Weapon, Slot, Slots, Ammo, Reserve, Magazine, FireMode, EquipState, Armed, Equipment, LastSeq

Azazel.WeaponEquipped:Connect(function(player, cfg) end)          -- cfg is nil when holstered
Azazel.Shot:Connect(function(player, cfg, origin, ends, hits) end)
Azazel.Hit:Connect(function(player, victimHumanoid, damage, zone, cfg) end)
Azazel.Kill:Connect(function(player, victimPlayer, victimHumanoid, cfg) end)
-- also exported: Azazel.Settings, Azazel.WeaponConfig, Azazel.EquipmentConfig, Azazel.Version
```

The systems themselves are not exported; everything a game needs goes through this table.
`Settings.Server.GiveDefaultLoadoutOnSpawn` hands `Settings.Server.DefaultLoadout` to every
player whose inventory is empty on spawn (only with `UseBackpack` off).

### Backpack

With `Settings.Server.UseBackpack` on (the default) the weapon in the hand is the Tool the
player holds. The package only watches the character; it never creates, edits, equips or
destroys a Tool. A Tool whose `AzazelWeapon` attribute (or, failing that, its `Name`) matches
a weapon `Name` or `DisplayName` puts that weapon in the hand; any other Tool is ignored.

The Tool needs `RequiresHandle` off when it has no `Handle`, and nothing inside it: the weapon
the player sees is the Model cloned from `Assets/Weapons`. The slot (ammo, fire mode, spray) is
claimed the first time the Tool is held and freed when the Tool is destroyed or leaves the
player's character and Backpack, so holstering keeps the magazine. With `UseBackpack` off the
number keys pick slots and the `Equip` remote is accepted.

### Kill credit

Every hit writes on the victim `Humanoid`:

| Attribute | Value |
|---|---|
| `AzazelLastAttackerUserId` | the shooter's `UserId` |
| `AzazelLastWeapon` | the weapon name |
| `AzazelLastAttackedAt` | `workspace:GetServerTimeNow()` of the hit |

The attributes are never cleared, so check freshness before crediting a death:
`workspace:GetServerTimeNow() - AzazelLastAttackedAt` under a few seconds. A classic `creator`
ObjectValue is also parented to the Humanoid for two seconds.

## Client signals

Everything the client knows travels through `ReplicatedStorage/Azazel/Client`.

```lua
local Client = require(game.ReplicatedStorage.Azazel.Client)

Client.Signals.WeaponChanged:Connect(function(cfg) end)             -- nil when holstered
Client.Signals.AmmoChanged:Connect(function(ammo, reserve, magazine) end)
Client.Signals.StateChanged:Connect(function(state) end)           -- authoritative snapshot
Client.Signals.SprayChanged:Connect(function(coneDegrees) end)
Client.Signals.AimChanged:Connect(function(aiming) end)
Client.Signals.ViewChanged:Connect(function(view) end)             -- "First" | "Third"
Client.Signals.HitConfirmed:Connect(function(zone, damage, killed) end)
Client.Signals.LocalShot:Connect(function(origin, ends, cfg) end)

Client.State       -- last snapshot from the server
Client.Config      -- WeaponConfig of the equipped weapon, with equipment modifiers applied
Client.View        -- "First" | "Third"
Client.Aiming      -- boolean
Client.SightOffset -- Vector3: the first person weapon's Sight relative to the eye; nil without one
Client.IsArmed()   -- Ready, or a reload started from Ready
```

To drive the system from your own UI or input, fire the input signals: `FireInput(bool)`,
`AimInput(bool)`, `ReloadInput()`, `ReadyInput()`, `SprintInput(bool)`, `SlotInput(n)`,
`ToggleViewInput()`, `SwapShoulderInput()`, `FireModeInput()`. The default keys live in
`Settings.Keys`; `Keys.AdsHold = false` makes the aim key a toggle.

## Equipment

`Config/Equipment/<Name>.luau` declares a `Zone` (`Head` or `Torso`), a `DamageMultiplier`, an
optional `Durability` (`Max` plus `LossPerHit`: a number, or `"Blocked"` to lose the damage it
prevented) and `Modifiers` stacked on the equipped weapon (`MagazineSize`, `Reserve`,
`Accuracy`, `RecoilCamera`, `ReloadTime`, each `{ Add, Mul }`). `ReloadTime` only changes
`Reload.Time`/`EmptyTime`, which only count for a weapon without a `Reload` clip. One piece per
zone; giving another replaces it, and a piece whose durability hits zero is removed.

```lua
Azazel.GiveEquipment(player, "HelmetLight")
Azazel.RemoveEquipment(player, "Head")
Azazel.EquipmentChanged:Connect(function(player, zone, cfg) end)   -- cfg nil when removed
```

## Adding a weapon

1. Build the weapon on your animation rig, duplicate the weapon Model (Ctrl+D) and drag the
   copy into `ReplicatedStorage/Azazel/Assets/Weapons/AK47`. The model ships its own joints, so
   the clips made on the rig land the same way on the character and on the viewmodel. Inside
   that one Model:
   - a BasePart named `Handle` with the barrel along its negative Z axis, every other fixed
     part welded to it (a `WeldConstraint` is enough);
   - the grip: the `Motor6D` between the rig's `Right Arm` (`Part0`) and the part the hand
     holds (`Part1`, normally `Handle`), kept inside the model;
   - parts that move in animations (`Magazine`, `Bolt`) as their own BasePart on a `Motor6D`
     from the `Handle`;
   - a point named `Muzzle` at the end of the barrel and one named `Sight` where the eye sits
     when aiming in first person, each an Attachment or an invisible BasePart;
   - no scripts, Values, emitters or sounds (sounds live in `Assets/Sounds`, see "Sounds").

   A duplicated model keeps every motor's `Part0` pointing at the rig, and the game plugs in
   the character part of that name. Copy and paste loses `Part0`; then name each motor after
   its body part (`Right Arm`, `Left Arm`, `Torso`). On every clone, scripts are deleted, loose
   parts are welded to the `Handle`, joints to anything outside the model are dropped with a
   warning and collisions and queries are turned off. Without a `Muzzle` tracers start at the
   `Handle`; without a `Handle` the weapon is a placeholder.
2. Add an entry to `Config/Weapons.luau`:
   ```lua
   AK47 = {
       DisplayName = "AK-47",
       Class = "Rifle",
       Model = "AK47",
       Rpm = 600,
       Damage = { Base = 36 },
       Effects = { Tracer = { Color = Color3.fromRGB(80, 200, 255) } },
   },
   ```
   Every key not present falls back to the class, then to `WeaponConfig.Defaults`, which lists
   every key. `Effects.Tracer` overrides any field of `Settings.Effects.Tracer`. A weapon that
   sets only `Reload.Time` gets an `EmptyTime` in its class's proportion.
3. Give it to a player (`Azazel.GiveWeapon`) or hand out a Tool named after it.

To split a magazine off a single mesh (Quaternius, Kenney packs): in Blender, Edit Mode, hover
it, `L`, `P` > Selection, name the objects `Handle` and `Magazine`, export FBX.

## The grip

How a weapon sits in the hand is the `C0`/`C1` of the `Motor6D` that holds the `Handle`, inside
the weapon model. To move the weapon in the hand, adjust the joint on the rig and copy the
model again; the clips stay valid because a pose is a transform on top of that joint. The game
never invents a `C0` or `C1`: it only fills `Part0` with the character part named like the one
the motor points at, or like the motor itself, or, for the `Handle`, the hand.

## Accuracy model

Per weapon, in degrees:

- `Accuracy.Base` is the cone of the first shot. A sniper is `0.02`, an SMG `0.6`.
- `HipMultiplier` and `AimMultiplier` scale it; aiming counts after `Ads.AimTime`.
- Each shot adds `PerShot` to the spray, capped at `Max`.
- After `RecoveryDelay` seconds without firing, the spray drains to zero over `RecoveryTime`.

`Shared/Accuracy` is the same code on both sides: the server rolls the real spread with its own
random generator, the client sizes the crosshair and draws its predicted tracers.

## Settings

Everything tunable that is not per weapon lives in `Config/Settings.luau`, one table per area:
`Camera`, `Viewmodel`, `Keys`, `Hud`, `Server`, `Animations`, `Look`, `Sounds`, `Quality`,
`Effects`, `Ragdoll`, `Debug`, `Strings`.

`Settings.Effects.Tracer` is the default look of every tracer (color, width, length, speed,
trail, light), read when a weapon config is first built. Tracers are drawn at any distance;
`MinPixelWidth` keeps a far one visible. The light is a `PointLight` without shadows and with a
fixed color. With `Lighting.Technology` on Voxel or Compatibility a moving light shows as
blocky patches; use ShadowMap or Future, or turn it off with `Tracer.Light.Enabled = false` or
`TracerLightDistance = 0`.

`Settings.Debug.Enabled` gates `LogRejections`, `LogInventory` and `ServerTracers` (Studio
only). `PrintBoot` is independent.

## Damage by distance

Every hit is `Base * Zones[zone] * falloff(distance)`, clamped to `Damage.Min`..`Damage.Max`.
Full damage until `FalloffStart`, then it eases to `FalloffMultiplier` at `FalloffEnd` with the
exponent `FalloffCurve` (1 linear, above 1 drops late, below 1 drops early), and stays there
until `Range`. Classes keep, at range: Shotgun 20% (150 studs), Pistol 45% (400), SMG 50%
(550), Rifle 65% (1100), Sniper 85% (2500). An accessory hit counts as the body part it is
welded to.

## First person viewmodel

Press V while armed. The viewmodel is a clone of the player's own torso and arms, placed exactly
where the real body stands and turned with the camera, so the clip alone places the arms.
Aiming slides the camera onto the weapon's `Sight` over `Ads.Time`; without a `Sight` it stays
at the head.

## Sounds

Sounds are placed by hand under `Assets/Sounds`, named by slot. The weapon's own go in a folder
named after its model (`Assets/Sounds/FN FNC/Fire`; the weapon `Name` or `DisplayName` works
too), the shared ones right under `Assets/Sounds`. A slot can be a Folder of Sounds played
together. `Sounds = { Fire = "AK47Fire" }` on a weapon points a slot at any child of
`Assets/Sounds`. A missing slot is silence.

| Slot | Plays |
|---|---|
| `Fire` | every shot, at the shooter's weapon |
| `ModeSelect` | when the fire mode changes |
| `RemoveMag`, `InsertMag` | on a reload, one after the other |

Every sound plays at the weapon's `Handle`. `Settings.Sounds.Enabled = false` mutes the package.

## Ragdoll

Only a death by an Azazel weapon ragdolls. The server freezes the dead character and tells
every client, which hides it and simulates its own copy with `BallSocketConstraint` joints
(`Settings.Ragdoll`), pushed along the killing shot and removed after `Lifetime`.

## Quality levels

`Client/Quality` picks Low, Medium or High from the Roblox graphics level
(`Settings.Quality.SavedLevels`), or from the measured frame rate when that is Automatic
(`AutoFps`). Each level in `Settings.Quality.Levels` sets tracer density, trail, light distance,
the live tracer cap and the live ragdoll cap.

```lua
local Quality = require(game.ReplicatedStorage.Azazel.Client.Quality)
Quality.Level                 -- "Low" | "Medium" | "High"
Quality.Get()                 -- the active level table
Quality.Set("Low")            -- force a level; Quality.Set(nil) goes back to automatic
```

Set `Settings.Quality.Source` to a level name to ignore the player setting.

## Security model

The client sends three things per shot: an origin, a unit direction and a sequence number. The
server owns ammo, timers, fire modes, spread, raycasts, damage, armor and kill credit, and
rejects a shot when the weapon is not `Ready`, the character is dead, the sequence is stale,
it comes faster than the fire rate (with `RateGrace`) or than the burst cadence, the last
second holds more shots than the weapon allows, the magazine is empty, the origin is more than
`MaxOriginDistance` from the head or behind a wall from it, the direction is not a finite unit
vector, or it points more than `MaxYawDelta` (plus the turn catch-up, at most 170) degrees away
from where the character faces or above `MaxPitch`. A rejection resyncs the client.

Every remote is declared in `Shared/Remotes.luau` with a payload schema and a per player rate
limit. `Settings.Server.KickOnAbuse` kicks after `AbuseThreshold` violations; the count halves
every minute. The package has no RemoteFunctions, no HTTP, no DataStore and no secrets.

## Animations

Animations are made by hand in the Animation Editor, one set per weapon class, and stored as
KeyframeSequences in `Assets/Animations/<Class>/<Slot>` (or `Assets/Animations/Weapons/<Name>/`
for one weapon). Every slot is optional; a missing one is skipped.

| Slot | Plays | Loop |
|---|---|---|
| `Relaxed` | the weapon drawn and lowered | yes |
| `Idle` | armed with the ready key (`Keys.Ready`, F), hip hold | yes |
| `Aim` | while aiming from `Idle` | yes |
| `Sprint` | in place of `Idle` while the sprint key is held (speed is the game's) | yes |
| `Reload` / `ReloadEmpty` | once, from `Relaxed` or `Idle`, back to the same state | no |
| `Equip` | once, over `Relaxed`, when a weapon is drawn | no |

The clip is the timer: every clip plays at the speed it was animated, and the server keeps the
weapon in `Reloading` for the length of the `Reload` (or `ReloadEmpty`) KeyframeSequence, its
last keyframe (`Animations.ReloadTime`). `Reload.Time` and `EmptyTime` only count for a weapon
with no clip, so keep the KeyframeSequences under `Assets/Animations` after publishing.
`Settings.Animations.LogSlots` prints the clips found and their lengths.

Animate only `Right Arm`, `Left Arm`, `Handle` and `Magazine` (plus `Torso` if you want); the
root, head and legs stay with the default `Animate`, so walking keeps working. A higher slot
only overrides the joints it keys. With a Tool held, the tool track of the default `Animate` is
stopped while a stance plays (`Settings.Animations.OverrideToolTrack`).

Roblox only plays KeyframeSequences directly in Studio. To publish: right click each
KeyframeSequence, Save to Roblox, and paste the ids into `Config/AnimationIds.luau`.

### Weapon states

`EquipState` in the snapshot is what the server allows; the client animates it.

| State | How it is reached | What it allows |
|---|---|---|
| `Holstered` | no weapon equipped | nothing |
| `Relaxed` | drawing a weapon, or the ready key from `Ready`. Plain Roblox camera and movement | reload, equip another weapon |
| `Ready` | the ready key from `Relaxed`. The package takes the camera; arms and head follow its pitch | fire, aim, reload |
| `Reloading` | reload from `Relaxed` or `Ready`, for the length of the clip | returns to the state it started from |

`Azazel.SetRelaxed(player, relaxed)` does the same from game code (a cutscene, a safe zone).
Arming takes the camera from the angles it was at, in the view (V) the player last chose, and
lowering gives back the field of view and cursor it had.

### Look pitch

While armed, the shoulders and neck turn with the camera pitch on top of the clip. Motor6D
transforms never replicate, so the client sends its pitch on the unreliable `Look` remote
(`Settings.Look.SendRate` a second, whole degrees, only when it moved) and the server relays it
as `LookUpdate`; each client eases the other characters over `Smoothing` and levels them out
after `Timeout`. `Settings.Look.Enabled = false` turns it off.

## Roadmap

| Milestone | Content |
|---|---|
| 1 | Skeleton, remotes, config, server combat, camera, prediction, tracer, HUD |
| 2 | Real weapon models, hotbar, equip flow, helmet and vest |
| 3 | Feel: recoil, aim down sights, shoulder swap, camera collision, scope, effects, sounds |
| 4 | Animation playback: slots, weapon states, reload markers |
| 5 | First person viewmodel cloned from the rig, client side ragdoll |
| 6 | Hardening, first alpha tag |

## License

Vendored packages keep their original licenses (see the header of each file in `Packages/`).
