# Changelog

All notable changes to Azazel. Newest first. One entry per version.

## 0.2.0-alpha.15

- Dev: `ImportWeapons(container, options)` imports every Tool or Model in a container; module
  names drop anything outside `[A-Za-z0-9]` (`Glock 18A` -> `Glock18A`), the original name is
  the `DisplayName` in the printed stub.
- Dev: sound convention on import. A `Sound` named `Fire*` is the weapon's own and becomes
  `Assets/Sounds/<Weapon>/Fire`; every other name is shared and goes flat into
  `Assets/Sounds/<Name>`, the first imported copy wins.

## 0.2.0-alpha.14

- Dev: the import keeps only what the system reads. `Muzzle` attachment and `Magazine` Motor6D
  by default; `Bolt`, `Eject`, `LeftHand` and the Viethin particle emitters are no longer
  carried over. Everything not geometry or joint is destroyed. Lists in `Manifest.Import`.

## 0.2.0-alpha.13

- Dev: `ImportWeapon` grew into `Dev/WeaponImport`. Optional `{ Scale, Material }`, marker
  parts (`Muzzle`, `Casingg`/`Casing`, `Handle1`) become attachments on the `Handle` with their
  emitters, moving parts (`Magazine`, `Bolt`, `Bolt2`, `Slide`, `Pump`, `Lever`, `Cylinder`) get
  a `Motor6D` from the `Handle` pivoted on `<Name>Attachment` when present (Viethin rig), every
  `Sound` moves to `Assets/Sounds/<Weapon>/`, Values, scripts, hitboxes and helper parts are
  destroyed. Name lists in `Assets/Manifest.Import`. Viethin 1.8 Tools import in one call.

## 0.2.0-alpha.12

- Viewmodel: rest pose. While no animation plays, the viewmodel's shoulders hold `Pose` from
  the weapon config (`RightArm`/`LeftArm` as `Pitch`/`Yaw`/`Roll` degrees in torso space,
  defaults in `WeaponConfig.Defaults`, overridable per class or weapon), so the arms and the
  weapon are raised in front of the camera instead of hanging below the screen. Applied in
  `PreSimulation`, after the Animator, so an `Idle` animation replaces it once one exists.
  `Rig.PoseJoints` names the shoulder joints per rig. `Settings.Viewmodel.Offset` lowered to
  `(0, -1.9, -0.5)` so the raised arms come from below the screen edge.

## 0.2.0-alpha.11

- Docs: `CLAUDE.md` describes the Script Sync layout, the git rules, the architecture and the
  working conventions for Claude Code sessions. GitHub remote added.

## 0.2.0-alpha.10

- Ragdoll on death by an Azazel weapon, and only then. The server (`Systems/Ragdoll`) turns
  `BreakJointsOnDeath` off right before a lethal hit, anchors the dead character with
  collisions off and fires the new `Ragdoll` remote (character, hit part, shot direction) to
  every client. `Client/Controllers/RagdollController` hides the real character locally and
  builds its own copy with `Shared/Ragdoll.Build`: root dropped, limb Motor6Ds swapped for
  `BallSocketConstraint`s with `Settings.Ragdoll.Joints` limits, inherited velocity plus
  `Settings.Ragdoll.Impulse` on the hit part. Physics runs on each client, nothing replicates.
  `Lifetime`/`FadeTime` in `Settings.Ragdoll`, `RagdollMaxLive` per quality level.

## 0.2.0-alpha.9

- Viewmodel (Phase 5): `Client/Controllers/ViewmodelController` clones the player's rig into
  the camera (root, torso, arms, shirt), attaches the weapon with the same Motor6D `Handle`,
  and drives it with springs (`Shared/Spring`): mouse sway, walk bob, recoil kick from
  `Recoil.Viewmodel`. Aiming aligns the weapon's `Sight` attachment to the screen center, or
  `Ads.ViewmodelOffset` without one. Destroyed on death, third person or holster.
- Camera: mouse wheel zoom in third person between `Settings.Camera.MinDistance` and
  `MaxDistance` (2..30 studs, `ZoomStep` 1.5). It never enters first person; V does.
- Rig: `Rig.Detect` honors the `AzazelRig` attribute so a rig without a Humanoid (the
  viewmodel) resolves the same tables.

## 0.2.0-alpha.8

- Combat: damage by distance is a computed curve in `Shared/Damage.luau`: full damage until
  `FalloffStart`, eased by `FalloffCurve` to `FalloffMultiplier` at `FalloffEnd`, clamped to
  `Damage.Min`/`Max` per hit. Classes keep, at range: Shotgun 20%, Pistol 45%, SMG 50%,
  Rifle 65%, Sniper 85%, with their own `Range` (150 / 400 / 550 / 1100 / 2500 studs).
- Dev: `PrintFalloff()` prints every weapon's damage at fixed distances; `PrintFalloff(name,
  step, zone)` prints one curve as CSV for graphs.

## 0.2.0-alpha.7

- Effects: tracers are no longer culled by distance from the camera; `MinPixelWidth` keeps a
  far tracer visible on screen. `TracerMaxDistance` per quality level is replaced by
  `TracerLightDistance`, the only thing cut by distance.
- Effects: `Style = "Beam"` draws the tracer as a flat camera-facing Beam with an optional
  bullet texture (`Beam.Texture`); `"Rod"` (Neon part) stays the default.
- Effects: tracer light dimmer (0.5, range 8) and with a fixed `Light.Color`, independent of
  the tracer color.
- Docs: Tracados.md updated; color customization per player noted for later.

## 0.2.0-alpha.6

- Fix: other players' tracers start at the muzzle of the weapon as rendered on the observer's
  client, instead of the server's copy of it (which lags behind the shooter). The server muzzle
  is only a fallback.
- Fix: a tracer's first frame shows the rod leaving the muzzle; before, the first step already
  moved it 20 studs ahead at 60 fps, so nobody ever saw it start at the barrel.
- Effects: `Settings.Effects.Tracer.Trail.Lifetime` (0.06 s) replaces the Length/Speed formula
  that made the trail vanish within a frame.
- Debug: `ClientShots` prints `[Azazel:Remote]` with the server and local muzzle of other
  players' shots and marks both.

## 0.2.0-alpha.5

- Settings: `Settings.Effects.Tracer` holds the default tracer look (color, width, length, speed,
  material, trail fade, light); `WeaponConfig.Defaults` reads from it. Default color is a
  stronger yellow.
- Effects: optional `PointLight` on tracers (`Tracer.Light`, no shadows), gated by `TracerLight`
  per quality level. Doctor warns when `Lighting.Technology` is Voxel or Compatibility, which
  renders moving lights as blocky patches.
- Debug: `Settings.Debug.Enabled` master switch, off by default. `ServerTracers` and
  `ClientShots` are now tables with their colors, sizes, lifetimes and print/draw toggles.
- HUD: hotbar and armor bars removed. Slots still switch with the number keys; the Roblox
  Backpack will list them (see Docs/Inventario.md).
- Equipment: `HelmetLight` and `VestLight` no longer have durability; they never break.
- Docs: section comments in `Settings.luau` and headers in `WeaponConfig`, `EquipmentConfig`,
  `AnimationIds` and every weapon/equipment module.

## 0.2.0-alpha.4

- Weapon: one `CanFire` gate on the client (ready, ammo, alive, not cycling). A trigger press
  while unavailable is discarded, and holding the trigger through a reload or equip does not
  resume fire; the player must press again. Server keeps discarding anything outside its own
  checks.

## 0.2.0-alpha.3

- Fix: clicking during the shot interval no longer queues a shot that fires when the interval
  ends (Semi and Burst). Input during the interval is ignored.
- Docs: Animacoes.md (animation-driven cadence, reload cancels Fire, for Phase 4).

## 0.2.0-alpha.2

- Fix: tracer Trail drew a segment from the previous shot end to the new muzzle when a pooled
  part was reused, looking like a bullet flying up. The Trail now enables one frame after
  placement and is cleared on return.
- Debug: `Settings.Debug.ClientShots` (Studio only) draws camera ray, aim target, head origin,
  muzzle and every pellet, and prints `[Azazel:Shot]` / `[Azazel:Tracer]` per shot.
- Dev: SpawnDummy respawns dummies 3 s after death; new ClearDummies.
- Docs: Inventario.md (Backpack without Tools, holster restores normal play), Municao.md
  (auto reload on empty), MelhoriasServer.md (falloff already exists).

## 0.2.0-alpha.1

- Milestone 2: equipment (helmet and vest by zone, damage multiplier, durability, stacked
  modifiers), server API GiveEquipment/RemoveEquipment/EquipmentChanged.
- Five Weapons Kit weapon configs (Pistol, SubmachineGun, AutoRifle, Shotgun, SniperRifle) in
  the default loadout together with HelmetLight and VestLight.
- HUD hotbar (slots 1-5, current highlighted) and armor bars.
- Dev commands: BuildAnimationRig, AttachToRig, CollectAnimSaves, ReportMissingAnimationIds,
  Doctor, GripMove/GripRotate/GripSet/GripReset/PrintGrip; ImportWeapon accepts Tools and the
  current selection; Give also hands out equipment.
- Manifest carries slot priorities and loop flags.

## 0.1.0-alpha.10

- Docs folder: the plan lives in the repo (Docs/PLANO.md) plus one note file per topic for
  requests that wait for the refinement pass.

## 0.1.0-alpha.9

- Client Quality module: Low/Medium/High from the saved graphics level or measured FPS; effects
  read per-level limits (tracer density, trail, distance, live cap; casings/impacts/flash/shake
  keys reserved for the effects milestone).
- Settings.Debug.ServerTracers: Studio-only red lines drawn by the server for the Server view.

## 0.1.0-alpha.8

- Thicker, brighter default tracer (0.2 studs wide, 5 long), closer to Phantom Forces.

## 0.1.0-alpha.7

- Tracer grows out of the muzzle and never extends behind it or past the impact point.

## 0.1.0-alpha.6

- Settings.Server.InfiniteAmmo (on by default): reserve never runs out, reload always fills
  the magazine, HUD shows the infinity sign.

## 0.1.0-alpha.5

- Weapon models are moved with PivotTo and parented before the Motor6D is created, so welded
  parts keep their offsets (the placeholder barrel no longer floats away).

## 0.1.0-alpha.4

- Tracer trail was 6 studs wide and ~100 studs long; the trail now matches the tracer width
  and its lifetime follows the configured length.

## 0.1.0-alpha.3

- WeaponConfig looked for the Weapons folder as its own child; it is a sibling under Config.

## 0.1.0-alpha.2

- HUD picks up the state that arrived before it started; Ready handshake is sent one
  frame later so every controller is listening.
- Line endings pinned to LF through .gitattributes.

## 0.1.0-alpha.1

- Project skeleton: vendored packages, closed remote registry, weapon and settings config,
  server authoritative combat (ammo, fire rate, server-rolled spread, raycast, zone damage,
  falloff), R6 rig attach via Motor6D, OTS camera, client prediction, traveling tracer, HUD.
- Versioning, commit convention and git hooks.
