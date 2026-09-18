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
- HUD built entirely in code: crosshair that opens with the spray (hidden while aiming in first
  person or through a scope), ammo panel (which reads
  `Reloading...` in place of the count while the weapon reloads), hitmarker. Firing on an empty
  magazine reloads.
- An armed character's arms and head follow the camera pitch, in third person and for the
  other players (`Settings.Look`).
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
2. In Studio, create the asset folders by hand under `ReplicatedStorage/Azazel/Assets`:
   `Weapons`, `Animations` (with a `Weapons` folder inside), `Effects`, `Sounds`. Models,
   KeyframeSequences and sounds go there; nothing in the package creates or edits instances.
3. Press Play. The Output prints `[Azazel] <version> 4/4 systems started` on the server and
   `[Azazel] client <version> 9/9 controllers started` on the client. To get a weapon, put a
   Tool named after one (`FNFNC`, or any name with the attribute `AzazelWeapon = "FNFNC"`) in
   `StarterPack`, with `RequiresHandle` off if it has no `Handle`; equip it from the Roblox
   hotbar and the weapon appears in the hand. See "Backpack" below. For targets, drop R6 dummies
   from the Rig Builder plugin in the map: any Humanoid takes damage.

If you clone this repository to contribute, also run `git config core.hooksPath .githooks`.

## Layout

```
ReplicatedStorage/Azazel/
  init.luau            Facade: Version, Settings, WeaponConfig, Strings
  Version.luau         Single source of truth for the version
  Config/
    Settings.luau      Camera, keys, HUD, server limits, effects, debug flags, strings
    WeaponConfig.luau  Defaults <- Classes[class] <- Weapons[Name]
    Weapons.luau       Every weapon, one entry per name
    AnimationIds.luau  Published animation ids per class and slot (see Animations)
  Shared/              Remotes, Accuracy, Damage, Rig, WeaponModel, Animations, Spring, Ragdoll, UIKit
  Packages/            Vendored libraries (Trove, Signal, Spr, T, Shake, PartCache, Observers)
  Assets/              Weapons/, Animations/, Effects/, Sounds/ (hand placed in Studio)
  Client/              Client bus (init.luau), Controllers/, ShotDebug (Settings.Debug drawer)
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
Azazel.SetRelaxed(player, true)                  -- lowers the weapon (Relaxed); false arms it (Ready)
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

With `Settings.Server.UseBackpack` on (the default) the weapon in the hand is simply the Tool
the player equipped, and **the package never touches the Backpack**: it creates no Tool,
destroys none, edits none, and equips and unequips nothing. It only watches what the character
holds. A Tool whose attribute `AzazelWeapon` (or, failing that, its `Name`) matches a weapon
config `Name` or `DisplayName` puts that weapon in the hand while it is held and takes it away
when it leaves; every other Tool is left alone.

Your Tool, your rules: put it in `StarterPack`, hand it out from your shop or pickup, name it,
give it an icon, destroy it when you want. Two things it needs, both its own settings, not the
package's: **`RequiresHandle` off** when it has no `Handle` (Roblox refuses to equip a
handleless Tool otherwise), and a name or an `AzazelWeapon` attribute that matches a weapon.
The weapon the player sees is still the Model on the Motor6D, cloned from `Assets/Weapons`, so
the Tool itself needs nothing inside it.

The slot a weapon takes is bookkeeping (ammo, fire mode, spray): it is claimed the first time
the Tool reaches the hand and kept while the Tool exists, so putting the weapon away and taking
it out again keeps the magazine. `GiveWeapon`, `RemoveWeapon`, `SetLoadout` and `Equip` above
work on those slots and never create a Tool. Turn `UseBackpack` off to get the other mode:
slots on the number keys, no Tools, `DefaultLoadout` and `AutoEquipSlot` on spawn.

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
Client.SightOffset -- Vector3: the held weapon's Sight relative to the first person eye; nil without one
Client.IsArmed()  -- Ready, or a reload started from Ready: the camera lock and the look pitch follow this
```

To drive the system from your own UI or input, fire the input signals: `FireInput(bool)`,
`AimInput(bool)`, `ReloadInput()`, `ReadyInput()`, `SprintInput(bool)`, `SlotInput(n)`,
`ToggleViewInput()`, `SwapShoulderInput()`, `FireModeInput()`. The default keys live in
`Settings.Keys`.

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

1. Build the weapon on your animation rig, then duplicate the weapon Model (Ctrl+D) and drag
   the copy into `ReplicatedStorage/Azazel/Assets/Weapons/AK47`. The model ships its own
   joints, so the clips made on the rig land the same way on the character and on the
   viewmodel. Everything the weapon needs must be inside that one Model before you duplicate:
   - a BasePart named `Handle` with the barrel along its negative Z axis, every other fixed
     part welded to it (a `WeldConstraint` is enough);
   - the grip: the `Motor6D` between the rig's `Right Arm` (`Part0`) and the part the hand
     holds (`Part1`, normally `Handle`), `C0`/`C1` as you built them. It has to live inside
     the model: if your weld plugin left it inside the arm, drag it under `Handle`;
   - parts of the weapon that move in animations (`Magazine`, `Bolt`) as their own BasePart
     on a `Motor6D` from the `Handle`;
   - a point named `Muzzle` at the end of the barrel, and one named `Sight` where the eye sits
     behind the rear sight (the camera goes there when aiming in first person). Either is an
     Attachment on the `Handle` or an invisible BasePart inside the model, whichever is easier
     to place; a loose part gets welded to the `Handle` like any other. Keep one of each: with
     two `Muzzle`s a Part wins over an Attachment, and both win over the default Attachment the
     loader adds at the front of the `Handle` when a model has none (it carries the attribute
     `AzazelDefault`; delete it from the asset if a played copy ever leaked back into it);
   - no scripts, Values, emitters, hitboxes or helper parts. Sounds live in `Assets/Sounds`
     (`Assets/Sounds/AK47/Fire` for the weapon's own shot; `ModeSelect`, `RemoveMag` and
     `InsertMag` shared at the root, see "Sounds"), not inside the model.
   A duplicated or dragged model keeps every motor's `Part0` pointing at the rig, and the game
   plugs the character part of that name in. Copy and paste loses `Part0`; then name each
   motor after the body part it belongs to (`Right Arm`, `Left Arm`, `Torso`).
   Rescale a pack with the Scale tool, one factor for every gun so they stay proportional.
   Free models are never trusted: every time the model is cloned, scripts are deleted, loose
   parts are welded to the `Handle`, welds to anything outside the model are dropped with a
   warning, collisions and queries are turned off and a missing `Muzzle` is placed at the
   front of the `Handle`. A model with no `Motor6D` to the character is held with a default
   grip and warns.
2. Add an entry to `Config/Weapons.luau`, the one module that lists every weapon:
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
   The key is the weapon name. Every key not present falls back to the class, then to
   `WeaponConfig.Defaults`; the full key list is in `WeaponConfig.luau`. `Effects.Tracer`
   (`Color`, `Light`, `Width`, `Length`...) gives the weapon its own tracer look; the defaults
   are `Settings.Effects.Tracer`. There is no grip value: the joint comes with the model.
3. Give it to a player (`Azazel.GiveWeapon`) or add it to `Settings.Server.DefaultLoadout`.

Weapon models need a `Handle` BasePart with the barrel pointing along its negative Z axis, a
`Muzzle` attachment and, optionally, `Sight` (aim point for first person aiming) and `Eject`.
A part that should move in animations (magazine, bolt) must be its own BasePart joined to the
`Handle` by a `Motor6D` named after the part. Meshes from the
Quaternius or Kenney packs come as one object: split the magazine off in Blender (Edit Mode,
hover it, `L`, `P` > Selection), name the objects `Handle` and `Magazine`, export FBX.

Free model sources that work well: the Roblox Weapons Kit models (Creator Store, endorsed),
Quaternius and Kenney packs (CC0, import through Studio's 3D importer).

## The grip

How a weapon sits in the hand is the `C0`/`C1` of the `Motor6D` that holds the `Handle`, and
that joint lives inside the weapon model, copied from the animation rig. To move the weapon
in the hand, adjust the joint on the rig and copy the model again: every character and the
viewmodel follow, and the clips stay valid because a pose is a transform on top of that joint.
The same goes for every other joint the model brings: the game
never invents a `C0` or `C1`, it only fills `Part0` with the character part named like the
one the motor still points at, or like the motor itself, or, for the `Handle`, the hand.

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
not scriptable). Turn the light off with
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
draw it: `Damage.Curve(cfg, step, zone)` returns the points of one weapon and zone.

Classes are ordered by how much they keep at range: Shotgun (20%, 150 studs), Pistol (45%,
400), SMG (50%, 550), Rifle (65%, 1100), Sniper (85%, 2500). Any weapon overrides its class.

## First person viewmodel

Press V. `Client/Controllers/ViewmodelController` clones the player's own character, keeps only
the root, torso and arms (plus shirt and body colors), strips joints, scripts and accessories,
adds an `AnimationController` and parents it to the camera. Only the arms of that clone are
drawn: the root and torso are there to carry the joints. The weapon is a fresh
`WeaponModel.Clone` attached through the joints that ship inside the model, the same ones the
server plugs into the real character, so the same animations drive both. Each frame the clone
stands exactly where the real body stands, turned with the camera about the eye: the eye sits
`Camera.FirstPersonOffset` above the root (the head on R6), so the clone's root goes the same
distance back down and a clip made on the animation rig lands in first person exactly as it
lands on the character. Nothing in code places the arms: no offset, no rest pose, no
per-weapon tweak. What you see in first person is the clip seen from the head, so animate
`Relaxed`, `Idle` and `Aim` looking from there. On top come mouse sway and walk bob, both
springs, zero at rest; a shot moves only the camera (`Recoil.Camera`), never the arms, so the
sight stays on the eye while aiming. Aiming moves the camera, not
the arms: over `Ads.Time` the eye slides from the head onto the weapon's `Sight` attachment
(`Client.SightOffset`), so the sight line is wherever the `Aim` clip holds the weapon; the
camera keeps the mouse rotation, so the clip has to hold the barrel parallel to the torso's
front. Without a `Sight` the camera stays at the head.
The real character is hidden whole with `LocalTransparencyModifier`, and the clone draws only
the arms and the weapon. `Settings.Viewmodel.ShowBody = true` keeps the real torso and legs
visible below the camera instead and hides only the head, the arms, the accessories on them and
the held weapon (`Rig.FirstPersonHidden` names the parts). Third person has no viewmodel.

`ViewmodelController.GetAnimator()` returns the viewmodel's Animator for the animation set.

## Sounds

Sounds are Sound instances placed by hand under `ReplicatedStorage/Azazel/Assets/Sounds`,
named by slot. The weapon's own go in a folder named after its model (`Assets/Sounds/FN
FNC/Fire`; the weapon `Name` or `DisplayName` works too), the shared ones sit right under
`Assets/Sounds` (`Assets/Sounds/ModeSelect`). A slot can also be a Folder of Sounds, played
together as layers. `Sounds = { Fire = "AK47Fire" }` on a weapon entry points a slot at any
child of `Assets/Sounds` instead. Volume, rolloff and pitch are whatever the Sound carries; a
missing slot is silence.

| Slot | Plays |
|---|---|
| `Fire` | every shot, at the shooter's weapon: the local one from `LocalShot`, the others from `ShotFired` |
| `ModeSelect` | when the fire mode changes, for the player who changed it |
| `RemoveMag`, `InsertMag` | on a reload, one after the other: the second starts when the first ends. Animation markers will place them later |

Every sound is cloned onto the weapon's `Handle` and destroyed when it ends.
`Settings.Sounds.Enabled = false` mutes the package.

## Ragdoll

Only a death by an Azazel weapon ragdolls; any other death keeps the Roblox default. When a
hit is lethal the server sets `BreakJointsOnDeath = false` on the victim, applies the damage,
then anchors the real character with collisions off and fires the `Ragdoll` remote to every
client with the character, the part that took the hit and the shot direction. Each client
hides the real character locally and builds its own copy with `Shared/Ragdoll.Build`: the
root is dropped, every limb Motor6D becomes a `BallSocketConstraint` with the limits from
`Settings.Ragdoll.Joints`, and every part gets an invisible collider welded inside it
(`ColliderScale` of its size), because a Humanoid keeps its limbs from colliding even dead
and the body would sink into the floor without one. The copy inherits the character's
velocity plus `Settings.Ragdoll.BodyImpulse` along the shot on every part, and the part that
took the killing hit `Impulse` on top, so a chest shot from the front throws the body onto its
back. The copy lives under the effects folder, is simulated only on that client,
fades for `FadeTime` and is removed after `Lifetime`; `RagdollMaxLive` per quality level
drops the oldest one first. The rig is whatever the character was: R6 stays R6.

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
went, and `Settings.Debug.ClientShots` draws and prints the client side of every shot: with
`Print` on, `[Azazel:Shot]` lists the camera ray, the head origin, the muzzle the tracer starts
from and `muzzleSource`, the instance that muzzle came from (a Part, an Attachment, or the
`Handle` center fallback when the model has none); with `Draw` on, the muzzle is the point in
`Colors.Muzzle`. Neither runs live.

Every remote is declared in `Shared/Remotes.luau` with a payload schema and a per player rate
limit. `Settings.Server.KickOnAbuse` kicks after `AbuseThreshold` violations. The package has
no RemoteFunctions, no HTTP, no DataStore and no secrets.

## Animations

Animations are made by hand in the Animation Editor, one set per weapon class, and stored as
KeyframeSequence instances inside `Assets/Animations/<Class>/<Slot>`. The weapon has three
resting states and one action, one slot each: the rest is optional and skipped when absent.
There is no `Fire` slot: the shot is the camera kick, the viewmodel spring and the effects.

| Slot | Plays | Length | Loop |
|---|---|---|---|
| `Relaxed` | as soon as the weapon is drawn: in the hand, lowered, not armed. Aiming and firing are off; reloading works | free | yes |
| `Idle` | after the ready key (`Keys.Ready`, F): armed, hip hold, can fire. The key toggles back to `Relaxed` | free | yes |
| `Aim` | while the aim button is held from `Idle`; in first person the camera moves onto the `Sight` | free | yes |
| `Reload` / `ReloadEmpty` | once, from `Relaxed` or `Idle`, back to the same state; empty variant when the magazine was dry | the clip's own: it is the timer | no |
| `Equip`, `Unequip`, `Sprint`, `Inspect` | optional and unused by default: `Equip` plays when the weapon is drawn, `Sprint` replaces `Idle` while the sprint key is held, `Unequip` and `Inspect` have no trigger yet. Sprint only changes speed; the legs keep the Roblox `Animate` | free | no / no / yes / no |

The clip is the timer. Every clip plays at the speed it was animated, and for a reload the
server reads the length of the `Reload` (or `ReloadEmpty`) KeyframeSequence, its last keyframe,
and keeps the weapon in `Reloading` exactly that long, so the state and the animation end
together (`Animations.ClipLength`, `Animations.ReloadTime`). `Reload.Time` and `EmptyTime` in
the config only count for a weapon with no clip. Keep the KeyframeSequences under
`Assets/Animations` after publishing: the ids play, the sequences tell the timers how long.
`Settings.Animations.LogSlots` prints the slots found and their lengths. Higher slots only override the joints they key, so a clip that keys
just the `Handle` and `Magazine` keeps the arms of `Idle` underneath. Animate only `Right Arm`, `Left Arm`,
`Handle` and `Magazine` (plus `Torso` if you want); the root, head and legs stay with the
default `Animate`, so walking and jumping keep working under every slot.

Roblox only plays KeyframeSequences directly inside Studio. In a published experience the
animation must be uploaded by the experience owner. The workflow is:

1. A rig with the game's body part names (`Right Arm`, `Left Arm`, `Torso`) and the weapon
   Model inside it (`Handle` joined to `Right Arm` by a Motor6D kept inside the weapon model,
   `Magazine` joined to `Handle`). Only a part on a Motor6D gets a track. A KeyframeSequence
   stores poses by part name on top of the joint, and the models carry those joints into the
   game, so the same clip drives the character, the viewmodel and the rig.
2. Animate in the Animation Editor or Moon Animator, one clip per slot (`Relaxed`, `Idle`,
   `Aim`, `Reload`), keying `Right Arm`, `Left Arm`, `Handle` and `Magazine` (and `Torso` if
   you want). Only Motor6D joints become tracks. Export each clip as a KeyframeSequence.
3. Put the KeyframeSequence in `Assets/Animations/<Class>/`, named exactly by its slot (a clip
   for one weapon goes in `Assets/Animations/Weapons/<Name>/`). Priority and loop come from
   the slot name at load time (`Assets/Manifest.luau`), so the instance needs only the name.
4. Play in Studio: the loader registers the KeyframeSequences on the fly.
5. To publish: right click each KeyframeSequence, Save to Roblox, paste the ids into
   `Config/AnimationIds.luau`.

`Shared/Animations` does the playback: one set per equipped weapon, bound to the Animator of
the character and, in first person, to the Animator of the viewmodel, so one clip drives both.
A looped slot is a stance and replaces the one playing; anything else is an action over it.
Priority and loop come from the slot name (`Assets/Manifest`), a missing slot is skipped (the
arms then hang, since no code poses them), and with the Backpack on the tool track of the default `Animate`
script is stopped so the stance wins the right arm (`Settings.Animations.OverrideToolTrack`).
Nothing in the package runs from the command bar: every asset is placed by hand and the code
only reads it.

### Weapon states

`EquipState` in the state snapshot is what the server allows, and the client animates it:

| State | How it is reached | What it allows |
|---|---|---|
| `Holstered` | no weapon equipped | nothing |
| `Relaxed` | the moment a weapon is drawn: in the hand, lowered. Drawing is instant, and the optional `Equip` clip plays over it. Camera and movement are plain Roblox | reload, equip another weapon |
| `Ready` | the ready key (`Settings.Keys.Ready`, F) from `Relaxed`. The package takes the camera: locked cursor, the character faces the camera, arms and head follow its pitch | fire, aim, reload; the key lowers it again |
| `Reloading` | reload from `Relaxed` or `Ready`, for the length of the clip | returns to the state it started from; the camera stays as it was |

The server owns it: `Combat` only accepts a shot in `Ready`, only accepts aiming in `Ready`,
and the client does not even send them otherwise. `Azazel.SetRelaxed(player, relaxed)` does the
same from your own code (a cutscene, a safe zone). The HUD hides the crosshair while the weapon
is lowered and shows `Strings.Reloading` in place of the ammo count while it reloads; there is
no other text on screen.

With the weapon lowered (`Relaxed`) or away (`Holstered`) the package steps aside: the default
Roblox camera comes back with its cursor and its own zoom, the character faces where it walks,
`V` and the shoulder swap do nothing, and the crosshair is hidden (the ammo panel stays while a
weapon is in the hand). Arming takes the camera over from the angles it was already at, in the
view (`V`) the player last chose, so the view never snaps.

### Look pitch

While armed (`Ready`, `Idle` or `Aim`, and a reload started there) the character's shoulders
and neck turn with the camera pitch on top of the clip, so in third person the arms and head
aim where the player looks. Motor6D transforms never replicate, so the client sends its pitch
on the unreliable `Look` remote (`Settings.Look.SendRate` a second, whole degrees, only when it
moved) and the server relays it to everyone else as `LookUpdate`; each client turns the other
characters itself, easing over `Smoothing` and levelling out after `Timeout` without news.
`Rig.LookJoints` names the joints per rig. `Settings.Look.Enabled = false` turns it all off.

## Roadmap

| Milestone | Content |
|---|---|
| 1 | Skeleton, remotes, config, server combat, camera, prediction, tracer, HUD |
| 2 | Real weapon models, hotbar, equip flow, helmet and vest (this version) |
| 3 | Feel: recoil, aim down sights, shoulder swap, camera collision, scope, effects, sounds |
| 4 | Animation playback: slots, weapon states, reload markers (this version) |
| 5 | First person viewmodel cloned from the rig, client side ragdoll (this version) |
| 6 | Hardening, R15 tables, first alpha tag |

## License

Vendored packages keep their original licenses (see the header of each file in `Packages/`).
