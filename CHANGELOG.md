# Changelog

All notable changes to Azazel. Newest first. One entry per version.

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
