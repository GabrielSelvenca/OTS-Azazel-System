# Changelog

All notable changes to Azazel. Newest first. One entry per version.

## 0.2.0-alpha.36

- Config: magazines, FN FNC 20 rounds and H&K 37 (the Rifle class default is 30).

## 0.2.0-alpha.35

- Config: second weapon, `HK` (`H&K`, Rifle): 750 rpm against the FN FNC's 600 and 28 base
  damage against 33; everything else, animations included, comes from the Rifle class. Model
  under `Assets/Weapons/H&K`.

## 0.2.0-alpha.34

- Fixed, ragdoll: bodies always fell toward the shooter. Only the torso (and the hit part) got
  the push, so it slid out from under the head and limbs, which stayed put on the shooter's
  side and tipped the body forward. Every part now gets `Settings.Ragdoll.BodyImpulse` along
  the shot and the hit part `Impulse` on top (`TorsoImpulse` is gone), so the body goes as one
  and tips over its feet, away from the shot.

## 0.2.0-alpha.33

- Fixed, effects: tracers could start mid weapon or mid body instead of at the muzzle. Two
  causes. `WeaponModel.FindPoint` took the first descendant named `Muzzle`, so an asset that
  carried both a `Muzzle` Part and the default Attachment the loader adds at the front of the
  `Handle` (a played copy pasted back into `Assets`) could start the tracer at the `Handle`
  front; now a Part wins over an Attachment and anything wins over the default, which is
  tagged `AzazelDefault`. And in first person the local tracer started from the character's
  hidden weapon, which does not pitch with the camera; it now starts from the viewmodel's
  weapon (`Client.ViewmodelWeapon`), the gun on screen.
- Debug: `[Azazel:Shot]` (`Settings.Debug.ClientShots.Print`) now names `muzzleSource`, the
  instance the muzzle came from, or says it fell back to the `Handle` center.

## 0.2.0-alpha.32

- Fixed, weapon: pressing R while holding the trigger got the next shot rejected with `weapon
  not ready`. The client kept predicting shots until the `Reloading` state came back, and a
  shot sent behind the reload request found the server already reloading. Asking for a reload
  now locks the trigger at once (the shots already sent still count) until the server answers,
  with a one second safety; the state push clears it.

## 0.2.0-alpha.31

- Ragdoll: the body stays on the floor. A Humanoid keeps its limbs non-collidable even dead,
  so only the torso rested on the ground and the arms, legs and head sank into it. Every part
  of the copy now carries an invisible collider welded inside it (`Settings.Ragdoll
  .ColliderScale` of its size) that does the colliding, with `NoCollisionConstraint`s between
  neighbours and their colliders so the joints do not fight themselves.
- Ragdoll: the push along the shot is a velocity set directly on the part that took the
  killing hit (`Impulse`) and, new, on the torso (`TorsoImpulse`), instead of an
  `ApplyImpulse` on a part that had just been parented; a chest shot from the front now visibly
  throws the body back with the limbs following.

## 0.2.0-alpha.30

- Viewmodel: a shot no longer kicks the arms. The viewmodel recoil spring (`Recoil.Viewmodel`:
  `Kick` back, `Rise` up) pushed the weapon off the camera, which now sits on the `Sight`, so
  every shot threw the sight off the eye. The recoil is the camera kick alone
  (`Recoil.Camera`); the spring and the config block are gone.

## 0.2.0-alpha.29

- HUD: the crosshair hides while aiming in first person, where the sights do the job
  (`Settings.Hud.Crosshair.HideWhenAimingFirstPerson`), next to the existing scope rule; one
  `refreshCrosshair` now decides from the state, the aim and the view.

## 0.2.0-alpha.28

- Sounds: the first ones play. New `Client/Controllers/SoundController` resolves a slot by the
  weapon override (`Sounds[slot]` names a child of `Assets/Sounds`), then the weapon's own
  folder (`Assets/Sounds/<Model>/<Slot>`, also by `Name` or `DisplayName`), then the shared
  `Assets/Sounds/<Slot>`; a slot is a Sound or a Folder of Sounds played as layers. `Fire` plays
  on every shot at the shooter's `Handle` (the local one from `LocalShot`, the others from
  `ShotFired`), `ModeSelect` when the fire mode changes, and a reload plays `RemoveMag` then,
  when it ends, `InsertMag` (animation markers later, by Gabriel's call). Clones are destroyed
  on `Ended`. `Settings.Sounds.Enabled` mutes the package. Boot now reports 9 controllers.

## 0.2.0-alpha.27

- Animations: the clip is the timer. The reload took longer than the animation because the
  server waited `Reload.Time` while the client tried to stretch the clip to it with
  `AdjustSpeed`, which depended on the track length arriving in time. Now every clip plays at
  the speed it was animated and `Animations.ClipLength` reads the last keyframe of the
  KeyframeSequence under `Assets/Animations`, on the server too, so `Combat` keeps `Reloading`
  exactly as long as the `Reload`/`ReloadEmpty` clip (`Animations.ReloadTime`); the config
  `Reload.Time`/`EmptyTime` only count for a weapon with no clip. Keep the sequences under
  `Assets` after publishing. Gone: `Settings.Animations.MatchConfigTime`, the `Duration` option
  of `Set:Play`, `EquipTime` in the weapon config.
- Weapons: `Sight` and `Muzzle` can be an Attachment or an invisible BasePart, whichever the
  model brought (`WeaponModel.FindPoint`). Gabriel's FN FNC carries a `Sight` Part and the code
  only looked for an Attachment, so the camera never left the head. Aiming in first person
  with a weapon that has neither warns once.
- HUD: the status text in the middle of the screen (`SAFE`, `UNARMED`, `EMPTY`, `RELOADING`)
  is gone, by Gabriel's call; the only text left is `Strings.Reloading`, which takes the place
  of the ammo count in the panel while the weapon reloads and gives it back after.
- Weapon: pulling the trigger on an empty magazine asks for the reload.
- Camera: the package only owns the camera while the weapon is armed (`Ready`, or a reload
  started there; `Armed` in the state snapshot, `Client.IsArmed()`). `Relaxed` is now plain
  Roblox camera and movement, like `Holstered`; arming comes back in the view (`V`) the player
  last chose.
- Look: an armed character's shoulders and neck follow the camera pitch on top of the clip, in
  third person and for the other players. New `Client/Controllers/LookController`,
  `Rig.LookJoints`, `Settings.Look`, and the unreliable remotes `Look` (client pitch, whole
  degrees, rate limited) and `LookUpdate` (server relay); the server clamps the value and never
  uses it for a shot. Boot now reports 8 controllers.
- Docs: `Docs/Mobile.md` holds the next request, HUD responsiveness and touch controls.

## 0.2.0-alpha.26

- Viewmodel: the arms are the clip and nothing else, by Gabriel's call. The clone stands
  exactly where the real body stands (its root at the eye minus `Camera.FirstPersonOffset`,
  turned with the camera about the eye) and no code places the arms any more:
  `Settings.Viewmodel.Offset`, the rest pose (`WeaponConfig.Defaults.Pose`, `Rig.PoseJoints`,
  the `PreSimulation` writer) and the aim repositioning (`Ads.SightDistance`,
  `Ads.ViewmodelOffset`, `sightCFrame`) are gone. A missing stance leaves the arms hanging,
  which says a clip is missing.
- Camera: aiming in first person moves the camera, not the arms. Over `Ads.Time` the eye slides
  from the head onto the exact point of the weapon's `Sight` attachment, which the
  `ViewmodelController` publishes on the bus as `Client.SightOffset` (relative to the eye, in
  its axes; nil without a `Sight`, and then the camera stays at the head). The rotation stays
  the mouse's, so the `Aim` clip holds the barrel parallel to the torso's front.
- Viewmodel: `Settings.Viewmodel.ShowBody` is off by default, so the real torso and legs no
  longer show in first person, and the clone draws only the arms and the weapon whatever the
  setting (with `ShowBody = false` it used to draw its own torso, pitched with the camera).

## 0.2.0-alpha.25

- Animations: `Shared/Animations` plays the slots. One set per equipped weapon, bound to the
  Animator of the character and, in first person, of the viewmodel, so one clip drives both.
  A looped slot from `Assets/Manifest` is a stance and replaces the one playing (`Relaxed`,
  `Idle`, `Aim`, `Sprint`); anything else is an action over it (`Reload`, `ReloadEmpty`,
  `Equip`), resampled with `AdjustSpeed` so it ends with the config timer. Priority and loop
  come from the slot name, a missing slot is skipped, and in Studio the KeyframeSequences under
  `Assets/Animations` are registered on the fly (`AnimationIds` outside Studio, or with
  `Settings.Animations.PreferManifestInStudio`).
- Weapon states: drawing a weapon lands on `Relaxed` (in the hand, lowered) instead of `Ready`.
  `Settings.Keys.Ready` (F, was `Inspect`) asks the server for `Ready` and lowers it again;
  `Combat` only accepts a shot and aiming in `Ready`, the reload works in both and returns to
  the state it started from. New remote `Relax(boolean)`, new server API
  `Azazel.SetRelaxed(player, relaxed)`, new client signal `ReadyInput`, `Client.IsHolding()`
  next to `Client.IsReady()`. The HUD shows `Strings.Relaxed` and hides the crosshair while the
  weapon is lowered.
- Reload parts: the extra magazines are dropped, by Gabriel's call. The reload is one clip on
  the arms and the weapon's own parts, so `Assets/Reload`, the hidden `Reload` sub-model,
  `WeaponModel.ReloadParts` and the visibility swap (markers or timers) are all gone from
  alpha.24 and never shipped. `Config/Weapons.luau` keeps `Reload` at `Mode`, `Time` and
  `EmptyTime`.
- Backpack: the tool track of the default `Animate` script is stopped while a stance plays, so
  the weapon animation wins the right arm (`Settings.Animations.OverrideToolTrack`,
  `ToolTracks`).
- Fixed, Backpack spawn: `CharacterRig.CharacterAdded` waits for the rig, so it fired after the
  Backpack had already equipped the spawn Tool and `Inventory` holstered it behind its back -
  the Tool stayed in the hand with no weapon model, no ammo and `UNARMED` on the HUD. With
  `UseBackpack` the spawn holster now only happens when the character holds no Tool, and the
  per slot accuracy state is reset in that mode too.
- Camera: with no weapon in the hand the package releases the camera. The default Roblox camera,
  its cursor and its zoom come back, the character faces where it walks, and `V` and the shoulder
  swap do nothing until a weapon is equipped; taking control back picks up the angles the Roblox
  camera was at, so equipping never snaps the view.
- Weapon states: `Equipping` is gone. Drawing a weapon is instant and lands on `Relaxed`, since
  the ready key is the only thing between a drawn weapon and a shot, so a timer added nothing.
  `EquipTime` stays as the length the optional `Equip` clip is resampled to.
- Fixed, animations: an action whose length the config owns (`Reload`, `Equip`) only got its
  `AdjustSpeed` when the clip happened to be loaded on the same frame it started, so a reload
  usually played at its own speed and ended well before the timer. It now adjusts the moment the
  length is known, however late. `Settings.Animations.LogSlots` prints each clip's real length,
  to copy into `Reload.Time` when the animation should keep its natural speed.
- Fixed, shot validation: a fast flick had its shots rejected with `yaw out of range`. The body
  follows the camera with a smoothing lag, so the server still saw it facing the old way. The
  yaw cone is now widened by how fast the body is actually turning (`Settings.Server.YawCatchUp`,
  `MaxYawCatchUp`), which forgives the catch-up and stays strict for someone standing still.
- Viewmodel: the clone now stands where the real body stands. Its root is placed at the inverse
  of `Camera.FirstPersonOffset` instead of a hand guessed `CFrame.new(0, -1.9, -0.5)`, so a clip
  made on the animation rig lands in first person exactly as it lands on the character, and the
  two offsets can no longer drift apart. `Settings.Viewmodel.Offset` is now a tweak on top,
  identity by default.
- HUD: the ammo panel, the status line and the crosshair only exist with a weapon in the hand,
  and the crosshair only in `Ready` (a lowered or reloading weapon has none).
- Backpack: the package no longer owns the Backpack, by Gabriel's call. `Systems/Backpack` is an
  observer: it creates no Tool, destroys none, edits none (no more `RequiresHandle`), equips and
  unequips nothing, and gives no spawn loadout in this mode. It watches the character for Tools
  that name a weapon and puts that weapon in the hand while one is held. The slot belongs to the
  Tool until the Tool is destroyed, so the magazine survives putting the weapon away. A Tool with
  no `Handle` needs `RequiresHandle` off, which is the Tool's own setting now. `Azazel.GiveWeapon`,
  `RemoveWeapon`, `SetLoadout` and `Equip` go straight to `Inventory` (`Inventory.EquipRouter` is
  gone). This also ends the spawn bug where the Tool was equipped and destroyed a millisecond
  later, leaving no weapon at all. `Settings.Debug.LogInventory` prints what takes and frees a
  slot.
- Config: the default loadout is `FNFNC`, and `DefaultLoadout`/`AutoEquipSlot`/
  `GiveDefaultLoadoutOnSpawn` are documented as the `UseBackpack = false` mode only.
- Weapons: a dropped joint now says why. A `Motor6D` whose `Part1` points outside the model (the
  rig's `Handle` instead of this model's, which looks identical in the Properties window) names
  the instance it points at and what to do about it.

## 0.2.0-alpha.24

- Viewmodel: first person keeps the real torso and legs visible below the camera
  (`Settings.Viewmodel.ShowBody`, replaces `HideCharacterInFirstPerson`). Only the head, the
  arms, what hangs from them and the held weapon are hidden; the viewmodel torso is invisible
  so its arms are the only clone on screen. `Rig.FirstPersonHidden` lists the parts per rig.
- Config: every weapon lives in one module, `Config/Weapons.luau`, keyed by name (`Name` comes
  from the key); the `Config/Weapons/` folder is gone. Per weapon `Effects.Tracer.Color`/`Light`
  were already honored and are documented there. `FNFNC` (FN FNC, Rifle) joins the weapons.
- Animations: no `Fire` slot, recoil is the camera kick and the viewmodel spring. Removed from
  the manifest, `AnimationIds` and the docs; notes in `Docs/Animacoes.md` and `Docs/Miras.md`.
- Weapons: the joints ship inside the weapon model. A `Motor6D` whose `Part1` is a weapon part
  and whose `Part0` is empty or outside the model is a rig joint: `WeaponModel.Sanitize` keeps
  it with its `C0`/`C1` and `Attach` fills `Part0` with the character part named like the one
  the motor still points at, else like the motor, else `Rig.WeaponJoints` (`Handle` to the
  hand), so the clips made on Gabriel's rig land identically on the character and the
  viewmodel, whatever the weapon parts are called. `Grip` is gone from the config; a model
  without a motor to the character gets the default grip on its `Handle` and a warning; a
  plain weld out of the model is dropped with a warning. `Detach` just destroys the model.
- Reload parts: the magazines the left hand carries during the reload are a per class Model
  in `Assets/Reload/<Class>` (or `Assets/Reload/Weapons/<Name>`), not weapon parts. `Clone`
  copies it into the equipped weapon as a hidden `Reload` sub-model, `Attach` plugs its
  motors like the weapon's; `WeaponModel.ReloadParts(model)` finds it for the animation
  milestone to show and hide at the clip markers.
- Dev: the `Dev/` folder is gone (`Commands`, `WeaponImport`), by Gabriel's rule that nothing
  in the package creates, imports or edits instances. Models, attachments, joints,
  KeyframeSequences and sounds are placed by hand in Studio and the code only reads them;
  `WeaponModel.Clone` still strips scripts and welds loose parts on every clone. The
  `Settings.Debug.ClientShots` drawer moved to `Client/ShotDebug`; `Assets/Manifest.luau`
  keeps only the animation slot tables.

## 0.2.0-alpha.23

- Docs: hand built animation rigs replace `BuildAnimationRig` once Gabriel delivers them;
  noted in `Docs/Animacoes.md` with what changes in code at that point.

## 0.2.0-alpha.22

- Config: `Grip` is now the `C1` of the `Handle` Motor6D itself (the hand seen from the
  Handle, like `Tool.Grip`) instead of its inverse, so a value read from a hand built rig pastes
  straight into the config. Default becomes `CFrame.Angles(math.rad(90), 0, 0)`; the weapon
  sits exactly where it did. `GripMove`/`GripRotate` keep their meaning.

## 0.2.0-alpha.21

- Animations: the slot set is `Relaxed`, `Idle`, `Aim`, `Fire`, `Reload` (`ReloadEmpty`
  optional); `Equip`, `Unequip`, `Sprint` and `Inspect` stay optional. The README describes the
  weapon states (drawn lowered, ready on F, aim from ready, reload from both) that the animation
  milestone implements; `AnimationIds` template updated.

## 0.2.0-alpha.20

- Animations: slot `Relaxed` (Idle priority, loop) joins the manifest for the lowered weapon
  pose; the README lists every slot with when it plays and how long it lasts.

## 0.2.0-alpha.19

- Inventory: the Roblox Backpack is the inventory (`Settings.Server.UseBackpack`, on by
  default). `Systems/Backpack` gives a slot to every Tool that names a weapon (attribute
  `AzazelWeapon`, or `Name` equal to a config `Name`/`DisplayName`) while it is in the Backpack
  or the character, and frees it when it leaves. The Tool stays equipped in the character
  without a Handle; `Tool.Equipped`/`Tool.Unequipped` drive `Inventory.Equip`, so the Roblox
  hotbar is always right. `GiveWeapon`, `RemoveWeapon`, `SetLoadout` and `Equip` create,
  destroy and equip Tools in this mode. Slot and holster keys are unbound on the client.
- Config: `GiveDefaultLoadoutOnSpawn` off, players spawn unarmed; `DefaultLoadout` lists the
  Viethin weapons. The Weapons Kit configs (`AutoRifle`, `Pistol`, `Shotgun`, `SniperRifle`,
  `SubmachineGun`) are removed; `DebugRifle` stays as the placeholder cube.

## 0.2.0-alpha.18

- Config: five weapons from the Viethin 1.8 packs, `FAL` (Rifle), `MP5A3` (SMG), `Beretta`
  (Pistol), `Remington700` and `BFG50` (Sniper), with light overrides on magazine, rate and
  the BFG's single round. Models are hand imported through `Dev.ImportWeapons`.

## 0.2.0-alpha.17

- Dev: several `Fire*` sounds on one weapon become the layers of an `Assets/Sounds/<Weapon>/Fire`
  folder instead of loose files; `FireSelect` is renamed `Selector` and shared
  (`Manifest.Import.SoundRenames`). Reimporting a weapon clears its sound folder first.

## 0.2.0-alpha.16

- Dev: `Handle1`, `ScopeRet` and `Retikle` (Viethin left hand and scope reticle markers) join
  the import discard list.

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
