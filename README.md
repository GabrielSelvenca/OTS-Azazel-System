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
- Over the shoulder camera with locked mouse, shoulder swap, aim down sights and a first person
  toggle. A viewmodel cloned from the player's own rig (planned, see Roadmap).
- Weapons are Models attached to the character by a Motor6D, so hand made animations can move
  the weapon inside the hand. No Tools, no Backpack.
- HUD built entirely in code: crosshair that opens with the spray, ammo panel, hitmarker.
- Closed remote registry with schema validation and rate limits on every request.
- Equipment (helmet, vest) that reduces damage by zone (planned, see Roadmap).

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
3. Press Play. The Output prints `[Azazel] <version> 3/3 systems started` on the server and
   `[Azazel] client <version> 5/5 controllers started` on the client. You spawn holding a
   placeholder rifle (`DebugRifle`).

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
  Shared/              Remotes, Accuracy, Rig, WeaponModel, UIKit
  Packages/            Vendored libraries (Trove, Signal, Spr, T, Shake, PartCache, Observers)
  Assets/              Weapons/, Animations/, Effects/, Sounds/ (hand placed in Studio)
  Client/              Client bus (init.luau) and Controllers/
  Dev/Commands.luau    Studio only helpers
ServerStorage/Azazel/
  init.luau            Server API
  Systems/             CharacterRig, Inventory, Combat
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
player whose inventory is empty when their character spawns. Turn it off and call
`SetLoadout`/`GiveWeapon` yourself if your game decides who gets what.

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

## Adding a weapon

1. Put the Model in Studio, select it, and run:
   ```lua
   require(game.ReplicatedStorage.Azazel.Dev.Commands).ImportWeapon(game.Selection:Get()[1], "AK47")
   ```
   This strips every script, welds all parts to a `Handle`, disables collisions and queries,
   adds a `Muzzle` attachment if missing and places the copy in `Assets/Weapons/AK47`. Free
   models are never trusted: the scripts are deleted on import and again every time the model is
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

Free model sources that work well: the Roblox Weapons Kit models (Creator Store, endorsed),
Quaternius and Kenney packs (CC0, import through Studio's 3D importer).

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

## Quality levels

Effects scale with the player. `ReplicatedStorage/Azazel/Client/Quality` reads the graphics
level saved in the Roblox settings (`Settings.Quality.SavedLevels` maps 1..10 to Low, Medium,
High). When the player leaves it on Automatic, the module measures the frame rate over
`SampleSeconds` and picks a level with hysteresis (`AutoFps`). Each level is a table in
`Settings.Quality.Levels` that the effect controllers read: tracer density, trail, max distance,
live part cap, casings, impacts, muzzle flash, camera shake.

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

`Settings.Debug.ServerTracers` draws a red line per shot from the server, Studio only, so the
Server view of a playtest shows where the server thinks bullets went. It never runs live.

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

1. Build the reference rig: `Dev.Commands.BuildAnimationRig("Rifle", "AK47")` (planned).
2. Animate in the Animation Editor and save. The editor stores the KeyframeSequence in the rig.
3. `Dev.Commands.CollectAnimSaves()` moves them into `Assets/Animations` (planned).
4. Play in Studio: the loader registers the KeyframeSequences on the fly.
5. To publish: right click each KeyframeSequence, Save to Roblox, paste the ids into
   `Config/AnimationIds.luau`. `Dev.Commands.ReportMissingAnimationIds()` lists what is missing.

The playback module and the commands above ship in the animation milestone (see Roadmap).

## Dev commands (Studio only)

```lua
local Dev = require(game.ReplicatedStorage.Azazel.Dev.Commands)
Dev.Setup()                      -- create Assets folders
Dev.Weapons()                    -- list configured weapons
Dev.SpawnDummy(3)                -- three R6 dummies in front of the first player (Play, server)
Dev.Give("DebugRifle")           -- give and equip to the first player (Play, server)
Dev.ImportWeapon(model, "Name")  -- sanitize a free model into Assets/Weapons
```

The module returns an empty table outside Studio.

## Roadmap

| Milestone | Content |
|---|---|
| 1 | Skeleton, remotes, config, server combat, camera, prediction, tracer, HUD (this version) |
| 2 | Real weapon models, hotbar, equip flow, helmet and vest, animation rig commands |
| 3 | Feel: recoil, aim down sights, shoulder swap, camera collision, scope, effects, sounds |
| 4 | Animation playback (Studio auto-register, id manifest) |
| 5 | First person viewmodel cloned from the rig |
| 6 | Hardening, R15 tables, first alpha tag |

## License

Vendored packages keep their original licenses (see the header of each file in `Packages/`).
