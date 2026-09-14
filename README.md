# Azazel

A first and third person (over the shoulder) shooter system for Roblox, written in Luau and
built to be dropped into any experience. Server authoritative, data driven, UI built in code,
animations hand made and shipped with the package.

Current version: see `ReplicatedStorage/Azazel/Version.luau`. Channels and numbering are
explained in [COMMITS.md](COMMITS.md). Changes are listed in [CHANGELOG.md](CHANGELOG.md).

This README is about using Azazel **from code**, as a developer integrating it into a game.
It is not a player guide.

## What you get

- Hitscan combat with a Counter-Strike style accuracy model: every weapon has a base
  inaccuracy, the first shot is the most accurate, holding the trigger opens the spread, letting
  go recovers it. Spread is rolled on the server.
- Five weapon classes (Pistol, SMG, Rifle, Shotgun, Sniper) with per-weapon overrides. Fire
  modes Auto, Semi and Burst. Shotgun pellets. Damage zones (head, torso, limbs) and falloff.
- Over the shoulder camera with locked mouse, wheel zoom, shoulder swap, aim down sights and a
  first person toggle (V) with a viewmodel cloned from the player's own rig.
- Weapons are Models attached to the character by a Motor6D, so hand made animations can move
  the weapon inside the hand. The player's inventory is the plain Roblox Backpack: a Tool that
  names a weapon takes a slot, and the Roblox hotbar equips it (`Settings.Server.UseBackpack`;
  turn it off to drive slots with the number keys and the server API only).
- HUD built entirely in code: crosshair that opens with the spray, ammo panel, hitmarker.
- Closed remote registry with schema validation and rate limits on every request.
- Equipment (helmet, vest) that reduces damage by zone. Durability is supported by the config
  but the shipped pieces never break.

## Requirements

- Roblox Studio with **Script Sync** (native). The repository root maps 1:1 to the services:
  `ReplicatedStorage/`, `ServerStorage/`, `ServerScriptService/`, `StarterPlayer/`.
- The experience must use **R6** avatars (Game Settings > Avatar > R6). R15 support is planned.
- No build step, no Rojo, no Wally. Only ModuleScripts, Scripts, LocalScripts and Folders live
  on disk. Models, animations and sounds are placed by hand in Studio under
  `ReplicatedStorage/Azazel/Assets`.

## Install

1. Copy these into your place, keeping the paths:
   - `ReplicatedStorage/Azazel` (the whole folder)
   - `ServerStorage/Azazel` (the whole folder)
   - `ServerScriptService/Azazel.server.luau`
   - `StarterPlayer/StarterPlayerScripts/Azazel.local.luau`
2. In Studio, run once in the command bar to create the asset folders:
   ```lua
   require(game.ReplicatedStorage.Azazel.Dev.Commands).Setup()
   ```
3. Press Play. The Output prints `[Azazel] <version> 4/4 systems started` on the server and
   `[Azazel] client <version> 7/7 controllers started` on the client. You spawn unarmed: put a
   Tool named after a weapon in `StarterPack` (or give one from your own UI) and it shows up in
   the Roblox hotbar; `Settings.Server.GiveDefaultLoadoutOnSpawn` hands `DefaultLoadout` to
   everyone instead.

If you clone this repository to contribute, also run `git config core.hooksPath .githooks`.

## Layout

```
ReplicatedStorage/Azazel/
  init.luau            Facade: Version, Settings, WeaponConfig, Strings
  Version.luau         Single source of truth for the version
  Config/
    Settings.luau      Camera, keys, HUD, server limits, effects, debug flags, strings
    WeaponConfig.luau  Defaults <- Classes[class] <- Weapons/<Name>
    Weapons/<Name>.luau  One module per weapon
    AnimationIds.luau  Published animation ids per class and slot (see Animations)
  Shared/              Remotes, Accuracy, Damage, Rig, WeaponModel, Spring, Ragdoll, UIKit
  Packages/            Vendored libraries (Trove, Signal, Spr, T, Shake, PartCache, Observers)
  Assets/              Weapons/, Animations/, Effects/, Sounds/ (hand placed in Studio)
  Client/              Client bus (init.luau) and Controllers/
  Dev/Commands.luau    Studio only helpers
ServerStorage/Azazel/
  init.luau            Server API
  Systems/             CharacterRig, Inventory, Backpack, Combat, Ragdoll
```

## Server API

```lua
local Azazel = require(game.ServerStorage.Azazel)

Azazel.GiveWeapon(player, "DebugRifle")          -- first free slot, returns the slot index
Azazel.GiveWeapon(player, "DebugRifle", 2)       -- specific slot (1..Settings.Server.MaxSlots)
Azazel.RemoveWeapon(player, 2)
Azazel.SetLoadout(player, { Weapons = { "Pistol", "Rifle" }, Equipment = {} })
Azazel.Equip(player, 1)                          -- 0 holsters
Azazel.GetState(player)                          -- snapshot: Weapon, Slot, Slots, Ammo, Reserve, Magazine, FireMode, EquipState, Equipment

Azazel.WeaponEquipped:Connect(function(player, cfg) end)          -- cfg is nil when holstered
Azazel.Shot:Connect(function(player, cfg, origin, ends, hits) end)
Azazel.Hit:Connect(function(player, victimHumanoid, damage, zone, cfg) end)
Azazel.Kill:Connect(function(player, victimPlayer, victimHumanoid, cfg) end)
```

`Settings.Server.GiveDefaultLoadoutOnSpawn` hands `Settings.Server.DefaultLoadout` to every
player whose inventory is empty when their character spawns. Leave it off and call
`SetLoadout`/`GiveWeapon` yourself if your game decides who gets what.

### Backpack

With `Settings.Server.UseBackpack` on (the default) the player's Backpack is the inventory.
Any Tool whose attribute `AzazelWeapon` (or, failing that, its `Name`) matches a weapon config
`Name` or `DisplayName` takes the first free slot while it sits in the Backpack or in the
character, and frees it when it leaves. Put such Tools in `StarterPack`, or create them from
your shop, pickup or loadout UI; no Handle, no scripts needed, the package sets
`RequiresHandle = false` and `CanBeDropped = false`. The Roblox hotbar equips and unequips
(`Tool.Equipped`/`Tool.Unequipped` drive the weapon), the number keys belong to Roblox, and
`GiveWeapon`, `RemoveWeapon`, `SetLoadout` and `Equip` above create, destroy and equip the
Tools so the hotbar always agrees with the state. The weapon the player sees is still the
Model on the Motor6D. Turn `UseBackpack` off to get the previous behavior: slots on the number
keys, no Tools.

Kill credit is written on the victim `Humanoid` as attributes `AzazelLastAttackerUserId` and
`AzazelLastWeapon`, plus a classic `creator` ObjectValue that lives for two seconds.

## Client signals

Everything the client knows travels through `ReplicatedStorage/Azazel/Client` (a ModuleScript
that holds Signals). Controllers never require each other for state.

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

Client.State      -- last snapshot from the server
Client.Config     -- WeaponConfig of the equipped weapon
Client.View       -- "First" | "Third"
Client.Aiming     -- boolean
```

To drive the system from your own UI or input, fire the input signals: `FireInput(bool)`,
`AimInput(bool)`, `ReloadInput()`, `SlotInput(n)`, `ToggleViewInput()`, `SwapShoulderInput()`,
`FireModeInput()`. The default keys live in `Settings.Keys`.

## Equipment

Armor pieces are data too. `Config/Equipment/<Name>.luau` declares a `Zone` (`Head` or `Torso`),
a `DamageMultiplier`, an optional `Durability` (`Max` plus `LossPerHit`, either `"Blocked"` to
lose the damage it prevented or a fixed number) and a `Modifiers` table stacked on the equipped
weapon (`MagazineSize`, `Reserve`, `Accuracy`, `RecoilCamera`, `ReloadTime`, each `{ Add, Mul }`).
One piece per zone; giving another replaces it. A piece whose durability hits zero is removed;
the shipped `HelmetLight` and `VestLight` have no durability and last forever.

```lua
Azazel.GiveEquipment(player, "HelmetLight")
Azazel.RemoveEquipment(player, "Head")
Azazel.EquipmentChanged:Connect(function(player, zone, cfg) end)   -- cfg nil when removed
```

## Adding a weapon

1. Put the Model in Studio, select it, and run:
   ```lua
   require(game.ReplicatedStorage.Azazel.Dev.Commands).ImportWeapon(game.Selection:Get()[1], "AK47")
   ```
   The first argument may be a Model or a Tool (the Roblox Weapons Kit and Viethin packs ship
   Tools); with no argument the current Studio selection is used. A third argument tunes the
   import: `{ Scale = 0.03, Material = "SmoothPlastic" }` (`Scale` is `Model:ScaleTo`, use the
   same factor for a whole pack so the guns stay proportional; `Material` is for flat colored
   meshes).
   The import keeps only what Azazel reads: a part named `Muzzle` becomes the `Muzzle`
   attachment on the `Handle`, a part named `Magazine` gets a `Motor6D` from the `Handle` so
   the Animation Editor can move it (a part named `MagazineAttachment` marks the pivot, as in
   the Viethin rig), sounds leave the model (a `Sound` named `Fire*` is the weapon's own and
   becomes `Assets/Sounds/AK47/Fire`, several of them become the layers inside a `Fire` folder
   there; any other name is shared by every weapon and lands in `Assets/Sounds/<Name>`, first
   import wins; `Manifest.Import.SoundRenames` fixes names first), and everything else that is
   not geometry
   (scripts, Values, emitters, hitboxes, helper parts) is destroyed. The rest is welded to the `Handle` with collisions and queries off, and the copy
   lands in `Assets/Weapons/AK47`. The name lists live in `Assets/Manifest.luau` under
   `Import`; add `Bolt` or `Eject` there the day an animation or effect needs them. Free models
   are never trusted: the scripts are deleted on import and again every time the model is
   cloned.
2. Create `Config/Weapons/AK47.luau`:
   ```lua
   return {
       Name = "AK47",
       DisplayName = "AK-47",
       Class = "Rifle",
       Model = "AK47",
       Grip = CFrame.new(0, 0.1, -0.3) * CFrame.Angles(math.rad(-90), 0, 0),
       Rpm = 600,
       Damage = { Base = 36 },
   }
   ```
   Every key not present falls back to the class, then to `WeaponConfig.Defaults`. The full key
   list is in `WeaponConfig.luau`. `Grip` is the Handle offset relative to the hand.
3. Give it to a player (`Azazel.GiveWeapon`) or add it to `Settings.Server.DefaultLoadout`.

Weapon models need a `Handle` BasePart with the barrel pointing along its negative Z axis, a
`Muzzle` attachment and, optionally, `Sight` (aim point for first person aiming) and `Eject`.
A part that should move in animations (magazine, bolt) must be its own BasePart joined to the
`Handle` by a `Motor6D`; the import creates that joint from the names above. Meshes from the
Quaternius or Kenney packs come as one object: split the magazine off in Blender (Edit Mode,
hover it, `L`, `P` > Selection), name the objects `Handle` and `Magazine`, export FBX.

Free model sources that work well: the Roblox Weapons Kit models (Creator Store, endorsed),
Quaternius and Kenney packs (CC0, import through Studio's 3D importer).

## Tuning the grip

With the weapon equipped in Play, use the client command bar:

```lua
local Dev = require(game.ReplicatedStorage.Azazel.Dev.Commands)
Dev.GripMove(0, 0.1, -0.2)      -- studs, relative to the current grip
Dev.GripRotate(0, 15, 0)        -- degrees
Dev.GripReset()                 -- back to the config value
Dev.PrintGrip()                 -- prints the Grip line to paste into the weapon config
```

## Accuracy model

Per weapon, in degrees:

- `Accuracy.Base` is the cone of the first shot standing still. A sniper is `0.02`, an SMG `0.6`.
- `HipMultiplier` and `AimMultiplier` scale it when firing from the hip or aiming.
- Each shot adds `PerShot` to the spray, capped at `Max`.
- After `RecoveryDelay` seconds without firing, the spray drains back to zero over
  `RecoveryTime` seconds.
- `Movement` multipliers exist for Stand/Walk/Run/Air/Crouch and are all `1` for now.

The client runs the same math only to size the crosshair. The server rolls the actual
direction, per pellet, with its own random generator.

## Settings

Everything tunable that is not per weapon lives in `ReplicatedStorage/Azazel/Config/Settings.luau`,
one table per area: `Camera`, `Viewmodel`, `Keys`, `Hud`, `Server`, `Animations`, `Quality`,
`Effects`, `Debug`, `Strings`. Weapons and equipment have their own modules under `Config/`.

`Settings.Effects.Tracer` is the default look of every tracer (color, width, length, speed, style,
trail fade, light). A weapon or class overrides any of those fields in `Effects.Tracer`. Tracers
are drawn at any distance so players can see where a shot came from; `MinPixelWidth` keeps a far
one at least that wide on screen. `Style` is `"Rod"` (Neon part) or `"Beam"` (flat strip that can
carry a bullet texture from `Beam.Texture`).

The tracer light is a `PointLight` without shadows. With `Lighting.Technology` on Voxel or
Compatibility, Roblox computes point lights on a 4 stud grid and a moving light shows up as
blocky patches on the ground; set it to ShadowMap or Future (Studio, Lighting properties; it is
not scriptable). `Doctor()` warns about it. Turn the light off with
`Settings.Effects.Tracer.Light.Enabled = false`, or limit it per quality level with
`TracerLightDistance` (studs from the camera; 0 disables). The light color is fixed
(`Light.Color`) so a colored tracer never tints the map.

`Settings.Debug.Enabled` is the master switch for the visual debug helpers (`ServerTracers`,
`ClientShots`), which are Studio only either way. `PrintBoot` and `LogRejections` are independent
of it and safe to leave on.

## Damage by distance

Every hit is `Base * Zones[zone] * falloff(distance)`, clamped to `Damage.Min`..`Damage.Max`.
The falloff is a curve, not a table: full damage until `FalloffStart`, then it eases to
`FalloffMultiplier` at `FalloffEnd` with the exponent `FalloffCurve` (1 linear, above 1 holds
full damage longer and drops late, below 1 drops early and levels out), and stays there until
`Range`, where the bullet stops existing. The math lives in `Shared/Damage.luau` so the game can
draw it: `Damage.Curve(cfg, step, zone)` returns points, and in Studio
`Dev.Commands.PrintFalloff()` prints every weapon side by side, or
`PrintFalloff("Shotgun", 10, "Torso")` prints one curve as CSV.

Classes are ordered by how much they keep at range: Shotgun (20%, 150 studs), Pistol (45%,
400), SMG (50%, 550), Rifle (65%, 1100), Sniper (85%, 2500). Any weapon overrides its class.

## First person viewmodel

Press V. `Client/Controllers/ViewmodelController` clones the player's own character, keeps only
the root, torso and arms (plus shirt and body colors), strips joints, scripts and accessories,
adds an `AnimationController` and parents it to the camera. The weapon is a fresh
`WeaponModel.Clone` attached with the same Motor6D `Handle` the server uses, so the same
animations drive both. Each frame the root follows the camera with `Settings.Viewmodel.Offset`,
plus mouse sway, walk bob and a recoil kick (`Recoil.Viewmodel` per weapon), all springs. Aiming
lerps to a pose that puts the weapon's `Sight` attachment at the screen center
(`Ads.SightDistance` in front of the camera); without a `Sight`, `Ads.ViewmodelOffset` is used.
The real character is hidden with `LocalTransparencyModifier`. Third person has no viewmodel.

`ViewmodelController.GetAnimator()` returns the viewmodel's Animator for the animation set.

## Ragdoll

Only a death by an Azazel weapon ragdolls; any other death keeps the Roblox default. When a
hit is lethal the server sets `BreakJointsOnDeath = false` on the victim, applies the damage,
then anchors the real character with collisions off and fires the `Ragdoll` remote to every
client with the character, the part that took the hit and the shot direction. Each client
hides the real character locally and builds its own copy with `Shared/Ragdoll.Build`: the
root is dropped, every limb Motor6D becomes a `BallSocketConstraint` with the limits from
`Settings.Ragdoll.Joints`, the copy inherits the character's velocity and gets
`Settings.Ragdoll.Impulse` along the shot on the hit part. The copy lives under the effects
folder, is simulated only on that client, fades for `FadeTime` and is removed after
`Lifetime`; `RagdollMaxLive` per quality level drops the oldest one first.

## Quality levels

Effects scale with the player. `ReplicatedStorage/Azazel/Client/Quality` reads the graphics
level saved in the Roblox settings (`Settings.Quality.SavedLevels` maps 1..10 to Low, Medium,
High). When the player leaves it on Automatic, the module measures the frame rate over
`SampleSeconds` and picks a level with hysteresis (`AutoFps`). Each level is a table in
`Settings.Quality.Levels` that the effect controllers read: tracer density, trail, light
distance, live part cap, casings, impacts, muzzle flash, camera shake.

```lua
local Quality = require(game.ReplicatedStorage.Azazel.Client.Quality)
Quality.Level                 -- "Low" | "Medium" | "High"
Quality.Get()                 -- the active level table
Quality.Set("Low")            -- force a level; Quality.Set(nil) goes back to automatic
Quality.Changed:Connect(function(level, values) end)
```

Set `Settings.Quality.Source` to a fixed level to ignore the player setting entirely.

## Security model

The client sends three things per shot: an origin, a unit direction and a sequence number.
The server owns ammo, timers, fire modes, spread, raycasts, damage, armor and kill credit, and
rejects a request when any of these fail: weapon not ready, character dead, stale sequence,
faster than the fire rate (with a small latency grace), more shots in a second than the weapon
allows, no ammo, origin farther than `Settings.Server.MaxOriginDistance` studs from the head,
direction not unit or not finite, direction more than `MaxYawDelta` degrees away from where the
character faces, pitch above `MaxPitch`. Rejections resync the client and, with
`Settings.Debug.LogRejections`, print to the Output.

With `Settings.Debug.Enabled`, `Settings.Debug.ServerTracers` draws a line per shot from the
server, Studio only, so the Server view of a playtest shows where the server thinks bullets
went, and `Settings.Debug.ClientShots` draws and prints the client side of every shot. Neither
runs live.

Every remote is declared in `Shared/Remotes.luau` with a payload schema and a per player rate
limit. `Settings.Server.KickOnAbuse` kicks after `AbuseThreshold` violations. The package has
no RemoteFunctions, no HTTP, no DataStore and no secrets.

## Animations

Animations are made by hand in the Animation Editor, one set per weapon class, and stored as
KeyframeSequence instances inside `Assets/Animations/<Class>/<Slot>`. Slots are `Idle`, `Fire`,
`Reload`, `Equip` (required) and `Aim`, `ReloadEmpty`, `Sprint`, `Inspect`, `Unequip`
(optional). A missing slot is skipped.

Roblox only plays KeyframeSequences directly inside Studio. In a published experience the
animation must be uploaded by the experience owner. The workflow is:

1. Build the reference rig: `Dev.BuildAnimationRig("AutoRifle")`. It spawns an R6 dummy in front
   of the camera with the weapon attached by the same Motor6D used in game and selects it.
2. Open the Animation Editor on the rig, animate `Right Arm`, `Left Arm` and `Handle` (and
   `Torso` if you want), and save each animation named exactly by its slot (`Idle`, `Fire`,
   `Reload`, `Equip`). The editor stores them as KeyframeSequences in `rig.AnimSaves`.
3. `Dev.CollectAnimSaves()` copies them into `Assets/Animations/<Class>/<Slot>` with the right
   priority and loop flag (`Dev.CollectAnimSaves(rig, true)` stores per weapon instead).
4. Play in Studio: the loader registers the KeyframeSequences on the fly.
5. To publish: right click each KeyframeSequence, Save to Roblox, paste the ids into
   `Config/AnimationIds.luau`. `Dev.Commands.ReportMissingAnimationIds()` lists what is missing.

The playback module ships in the animation milestone (see Roadmap); the rig commands work now.

## Dev commands (Studio only)

```lua
local Dev = require(game.ReplicatedStorage.Azazel.Dev.Commands)
Dev.Setup()                      -- create Assets folders
Dev.Weapons()                    -- list configured weapons
Dev.SpawnDummy(3)                -- three R6 dummies in front of the first player (Play, server)
Dev.Give("DebugRifle")           -- give and equip to the first player (Play, server)
Dev.ImportWeapon(model, "Name", { Scale = 0.03 })  -- free model (Model or Tool) into Assets/Weapons
Dev.ImportWeapons(workspace.Guns, { Scale = 1 })   -- every Tool/Model in a container, names stripped to [A-Za-z0-9]
Dev.BuildAnimationRig("AutoRifle")  -- R6 dummy with the weapon attached, for the Animation Editor
Dev.CollectAnimSaves()           -- move saved KeyframeSequences into Assets/Animations
Dev.ReportMissingAnimationIds()  -- KeyframeSequences without ids and ids without sequences
Dev.Doctor()                     -- validate configs against assets
Dev.GripMove / GripRotate / GripReset / PrintGrip   -- tune the weapon offset in Play
```

The module returns an empty table outside Studio.

## Roadmap

| Milestone | Content |
|---|---|
| 1 | Skeleton, remotes, config, server combat, camera, prediction, tracer, HUD |
| 2 | Real weapon models, hotbar, equip flow, helmet and vest, animation rig commands (this version) |
| 3 | Feel: recoil, aim down sights, shoulder swap, camera collision, scope, effects, sounds |
| 4 | Animation playback (Studio auto-register, id manifest) |
| 5 | First person viewmodel cloned from the rig, client side ragdoll (this version) |
| 6 | Hardening, R15 tables, first alpha tag |

## License

Vendored packages keep their original licenses (see the header of each file in `Packages/`).
