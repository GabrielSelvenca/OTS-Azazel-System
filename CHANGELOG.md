# Changelog

Newest first. One section per version.

## 0.2.0-alpha.37

- Fixed, combat: a shot whose origin sits behind a wall from the head is rejected.
- Fixed, combat: accessory hits take the zone of the body part they are welded to, so a backpack is no longer a headshot.
- Fixed, remotes: the `Equip` remote is ignored with `UseBackpack`; Tools that leave the player free their slot.
- Fixed, combat: Burst can no longer be fired as full auto; aim time resets on equip, relax and reload.
- Fixed, weapon: presses inside the shot interval are kept; the client cone uses the same aim time as the server.
- Fixed, weapon: ammo reconciliation accounts for shots still in flight (`LastSeq` in the snapshot).
- Combat: client and server share one spread pipeline in `Accuracy`.
- Remotes: rejection logs only with `Debug.Enabled`, throttled; violations decay over time. `Ready` is now `RequestState`.
- Config: dead fields, the R15 stub, the client shot debug and unused exports removed.
- Docs: README, COMMITS and CHANGELOG trimmed.

## 0.2.0-alpha

- Equipment: helmet and vest reduce damage by zone, with optional durability and weapon modifiers.
- Backpack: a held Tool that names a weapon decides the weapon in hand; the package never creates or edits Tools.
- Config: every weapon is one entry in `Config/Weapons.luau`; `FNFNC` and `HK` ship.
- Weapons: models ship their own joints from the animation rig and `Attach` only fills `Part0`; every clone is stripped of scripts.
- Weapons: `Muzzle` and `Sight` can be an Attachment or an invisible Part.
- Weapon states: a drawn weapon is `Relaxed`, the ready key arms it, a reload returns to the state it came from.
- Animations: per class slots from KeyframeSequences under `Assets/Animations`; the clip length is the reload timer.
- Camera: owned only while armed, with wheel zoom; aiming in first person moves the camera onto the `Sight`.
- Viewmodel: first person arms cloned from the player's rig, placed by the clip alone.
- Look: an armed character's arms and head follow the camera pitch for every player.
- Combat: damage falls off with distance on a curve; the yaw check forgives a body still turning after a flick.
- Effects and sounds: per weapon tracer look and light; `Fire`, `ModeSelect`, `RemoveMag`, `InsertMag` from `Assets/Sounds`.
- Ragdoll: a death by an Azazel weapon ragdolls locally on every client.
- HUD: ammo panel, crosshair and hitmarker only.
- Fixed, weapon: a reload request locks the trigger, so no shot is rejected behind it.

## 0.1.0-alpha

- Skeleton: vendored packages, closed remote registry, weapon and settings config.
- Combat: server authoritative ammo, fire rate, spread, raycast and zone damage.
- Client: over the shoulder camera, predicted fire, travelling tracer, HUD.
- Quality: Low, Medium and High from the graphics level or the measured frame rate.
- Debug: `ServerTracers` draws the server's shots in Studio.
- Config: `Settings.Server.InfiniteAmmo`.
- Fixed, weapon models: welded parts keep their offsets when attached.
- Fixed, effects: the tracer never extends behind the muzzle and its trail matches its width.
- Versioning, commit convention and git hooks.
