# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Azazel: a first/third person (over the shoulder) shooter package for Roblox, written in Luau,
meant to be dropped into any experience. Server authoritative, data driven, UI in code, R6 only
for now. Repository: https://github.com/GabrielSelvenca/OTS-Azazel-System

`README.md` is the integrator manual (server/client API, config shape, dev commands, animation
pipeline) and is the first place to look for how a feature is meant to be used. `Docs/PLANO.md`
is the phase plan and current status. `COMMITS.md` is the commit/version/tag contract.

## No toolchain

There is no build, lint, test runner, Rojo or Wally. The repository root maps 1:1 to Roblox
services through Studio's native **Script Sync**: `ReplicatedStorage/`, `ServerStorage/`,
`ServerScriptService/`, `StarterPlayer/`. Only `.luau` files and folders exist on disk:

- `Name.luau` -> ModuleScript, `Name.server.luau` -> Script, `Name.local.luau` -> LocalScript,
  `Folder/init.luau` -> the folder itself becomes the ModuleScript.
- Models, KeyframeSequences, sounds and remotes never live on disk. Assets are placed by hand in
  Studio under `ReplicatedStorage/Azazel/Assets/`; remotes are created at runtime by
  `Remotes.EnsureAll()`; `Assets/Manifest.luau` holds the animation slot tables (names,
  priority, loop).

Verification is Play in Roblox Studio (Play Solo, or Test with 2 players for replication). Boot
prints `[Azazel] <version> 4/4 systems started` (server) and `... 9/9 controllers started`
(client).

**No Studio commands, by Gabriel's rule (2026-09-15).** There is no `Dev/` folder, no
importer, no scaffolding and no "run this in the command bar" step. Nothing in the package
creates, imports or edits instances: Gabriel places models, attachments, joints,
KeyframeSequences and sounds by hand under `Assets/` and the code only reads them. When a
feature needs an asset, document the shape in the README and keep the loader tolerant (for
example priority and loop by slot name from the Manifest). `Settings.Debug` toggles are fine;
`Client/ShotDebug` is config driven, not a command.

## Git rules (enforced by a hook)

Enable once after cloning: `git config core.hooksPath .githooks`.

- **Every commit** bumps `ReplicatedStorage/Azazel/Version.luau` and adds an entry to
  `CHANGELOG.md` (newest first, one section per version). The pre-commit hook blocks the commit
  otherwise, and it only looks at the index, so stage both files with the change. Inside a
  `dev`/`alpha`/`beta` channel a planned feature only bumps `Build`.
- The CHANGELOG entry is a `## <version>` heading with one bullet per change, each starting
  with the area (`- Animations: ...`, `- Config: ...`) or `- Fixed, <area>: ...` for a fix, and
  says what changed and why in plain words (Gabriel's decisions are attributed and dated).
- Every commit gets a tag equal to `Version.Tag()` (for example `v0.2.0-alpha.10`), created
  right after the commit: `git tag v0.2.0-alpha.10`.
- Message: `type(scope): what changed`, short body saying why, footer `Version: <version>`.
  Types and scopes are in `COMMITS.md`. English.
- `.gitattributes` forces LF on every file; never write CRLF.
- `Cons/` at the root is a local library catalog, gitignored. Libraries used by the package are
  vendored into `ReplicatedStorage/Azazel/Packages/` as they came upstream (their own headers,
  tab indentation); never reformat them and do not require anything from `Cons/` directly.

## Architecture

The package is one folder plus one server folder plus two bootstraps:

- `ReplicatedStorage/Azazel/` — everything shared and the whole client (nothing secret there).
  `init.luau` is a facade over `Version`, `Config/Settings`, `Config/WeaponConfig`,
  `Config/EquipmentConfig`.
- `ServerStorage/Azazel/` — server API (`init.luau`) and `Systems/`. It is in ServerStorage
  because ServerScriptService cannot hold a Script and a Folder both named `Azazel`.
- `ServerScriptService/Azazel.server.luau` calls `Azazel.Start()`;
  `StarterPlayer/StarterPlayerScripts/Azazel.local.luau` starts the client controllers.

### Server

`ServerStorage/Azazel/init.luau` starts systems in a fixed `BOOT_ORDER` (CharacterRig ->
Inventory -> Backpack -> Combat, each `Start()` in a pcall) and re-exports their Signals as the public API
(`GiveWeapon`, `SetLoadout`, `Equip`, `GetState`, `WeaponEquipped`, `Shot`, `Hit`, `Kill`...).

- `Inventory` is the source of truth for per-player state: slots, ammo, reserve, fire mode,
  equip state machine (`Holstered` -> `Equipping` -> `Relaxed`, the ready key asks for `Ready`,
  `Reloading` returns to the state it came from), equipment, accuracy/spray state,
  shot sequence. It pushes the `State` snapshot to the owner only on lifecycle events and
  rejections, never per shot.
- `Combat` handles `Fire`/`Reload`/`Aim`/`SetFireMode`: only accepts a shot and aiming in
  `Ready` (a `Relaxed` weapon is lowered), validates every request (see "Security" below), rolls the spread with its own RNG, raycasts per pellet, applies zone/falloff/armor
  damage, writes kill credit (`AzazelLastAttackerUserId`/`AzazelLastWeapon` attributes plus a
  `creator` ObjectValue), broadcasts `ShotFired` (unreliable) and `HitConfirmed`.
- `CharacterRig` attaches/detaches the replicated weapon Model on spawn and cleans up on death.
- `Ragdoll` is used by Combat on lethal hits (server freezes the real character and fires the
  `Ragdoll` remote; each client simulates its own copy).

### Client

`Azazel.local.luau` requires every ModuleScript in `Client/Controllers/` and calls `Start()`
on each in its own `task.spawn` + pcall, **with no ordering**. Adding a controller is dropping a
module with a `Start()` there. Controllers share state through the bus in `Client/init.luau`
(`Client.Signals.*`, `Client.State`, `Client.Config`, `Client.View`, `Client.Aiming`,
`Client.SightOffset`, `Client.IsReady()`/`IsHolding()`/`IsArmed()`) and must not depend on another controller having started. The
only direct cross-requires are `WeaponController -> CameraController.GetAimRay()` and
`ViewmodelController.GetAnimator()`/`GetModel()`, which it polls every Heartbeat because the
viewmodel is rebuilt on every view and weapon change.

Controllers: `Input` (ContextActionService -> input Signals), `Camera` (OTS, lock, ADS, zoom,
shoulder; it owns the camera only while armed, `Client.IsArmed()`: Relaxed and Holstered are the
plain Roblox camera), `Weapon` (predicted fire loop, reload/equip, reconciliation with `State`, and the
animation set: which stance the `EquipState` asks for, the reload action and its markers),
`Viewmodel` (first person arms cloned from the player's own rig, standing exactly where the
body stands: no code places the arms, the clip does, and while aiming the camera moves onto the
weapon's `Sight` through `Client.SightOffset`), `Effects` (tracers via
PartCache, per-quality LOD), `Hud` (built with `Shared/UIKit`; the only text is the ammo
panel, which reads `Strings.Reloading` during a reload), `Ragdoll`, `Look` (shoulders and
neck of every armed character follow the camera pitch on top of the clip; the local pitch is
relayed by the server on the unreliable `Look`/`LookUpdate` remotes), `Sound` (slots under
`Assets/Sounds`: `Fire` per weapon folder, `ModeSelect`/`RemoveMag`/`InsertMag` shared at the
root, cloned onto the weapon `Handle`).
`Client/Quality.luau` picks Low/Medium/High from the saved graphics level or measured FPS and
every effect reads `Settings.Quality.Levels[level]`.

### Data and config

- Weapons: `WeaponConfig.Get(name)` deep-merges `Defaults <- Classes[Class] <- Weapons[Name]`,
  freezes the result and derives `ShotInterval`/`BurstInterval` from `Rpm`. Every weapon is an
  entry in the single `Config/Weapons.luau`, keyed by name, listing only what differs from its
  class. Adding a weapon = one entry there plus the Model placed by hand in
  `Assets/Weapons/<Model>` (README "Adding a weapon" lists the shape). Class order is
  `Pistol, SMG, Rifle, Shotgun, Sniper`.
- Equipment: `Config/Equipment/<Name>.luau` with `Zone`, `DamageMultiplier`, optional
  `Durability`, and `Modifiers` (`{ Add, Mul }` per field) that `WeaponConfig.Resolve` stacks
  onto the equipped weapon.
- Everything else tunable is in `Config/Settings.luau`, one table per area (`Camera`,
  `Viewmodel`, `Keys`, `Hud`, `Server`, `Animations`, `Look`, `Sounds`, `Quality`, `Effects`,
  `Ragdoll`, `Debug`, `Strings`). Player-visible text goes in `Settings.Strings`, never inline.
- `Config/AnimationIds.luau` is the manifest of published animation ids per class/slot; in
  Studio the embedded KeyframeSequences under `Assets/Animations/<Class>/<Slot>` are registered
  on the fly instead.

### Shared modules

`Shared/` modules run on both sides. `Accuracy` and `Damage` are pure math: the server uses
them for the real roll, the client only to size the crosshair. `Rig` abstracts the avatar
(R6 tables live; R15 is a stub with `Enabled = false`) and maps parts to damage zones.
`Animations` is the playback: `NewSet(cfg)` resolves an id per slot (embedded KeyframeSequence
in Studio, `AnimationIds` in a published game), binds any number of Animators (character and
viewmodel) and plays a looped slot as a stance or anything else as an action over it, with
priority and loop from `Assets/Manifest`. A missing slot is skipped, never an error. Clips play
at their own speed and the clip is the timer: `Animations.ClipLength` reads the last keyframe of
the KeyframeSequence under `Assets` (on the server too) and `Combat` keeps `Reloading` exactly
that long (`Animations.ReloadTime`); `Reload.Time`/`EmptyTime` only count without a clip.
`WeaponModel.Attach` is the single place a weapon is joined to a character. The joints ship
inside the weapon model, copied from Gabriel's animation rig with their `C0`/`C1`: any
Motor6D whose `Part1` is a weapon part and whose `Part0` is empty or foreign is a rig joint,
and `Attach` only fills `Part0` with the character part named like the one the motor still
points at (a duplicated model keeps it), else like the motor itself, else by
`Rig.WeaponJoints[Part1.Name]` (`Handle` to the hand). Weapon part names are Gabriel's
(`Magazine`, `Bolt`...), never assumed by code. There is no grip value in the config; a model
with no joint to the character gets a default one on the `Handle`. The server character and the
first person viewmodel both go through `Attach`, so one animation set drives both. There are no
extra reload magazines: the `Reload` clip moves the arms and the weapon's own parts (Gabriel,
2026-09-16, after the kit in `Assets/Reload` was written and dropped).
Weapons are Models, never Tools with Handles. With `Settings.Server.UseBackpack` (default) the
weapon in the hand is whatever Tool the player equipped: `Systems/Backpack` only watches the
character for Tools that name a weapon and calls `Inventory.Equip`; by Gabriel's rule
(2026-09-16) it creates, destroys, edits and equips nothing, so a Tool needs `RequiresHandle`
off on its own. The slot is bookkeeping and belongs to the Tool until it is destroyed.

### Remotes and security

`Shared/Remotes.luau` is a closed registry: every remote is declared in `DEFINITIONS` with
kind, direction, a `T` schema and a per-player token-bucket rate. `Remotes.Get` on an
undeclared name asserts; `OnServer` runs rate limit then schema before the handler and counts
violations (`Settings.Server.KickOnAbuse`). Adding a remote means adding a definition there.

Invariants to keep: the client sends only origin, unit direction and sequence number per shot;
the server owns ammo, timers, fire modes, spread RNG, raycasts, damage, armor and kill credit;
no RemoteFunctions, no HttpService, no DataStore. `WeaponModel.Clone` deletes every script
from a weapon model on every clone. Weapon/tracer/casing parts have
`CanQuery = false` so raycasts ignore them.

## Working conventions

- Code, identifiers, comments, README, CHANGELOG and commit messages are in English. Comments
  are minimal. 4-space indentation. PascalCase for modules, instances and config keys; camelCase
  for locals. Prints and warns are prefixed `[Azazel]`.
- Luau as the package writes it: no `--!strict`, generalized iteration (`for k, v in t do`, no
  `pairs`/`ipairs`), backtick interpolation (`` `[Azazel] {name}` ``), type annotations on public
  signatures (`function X.Give(player: Player, name: string): number?`), `ALL_CAPS` for module
  level constants. Modules are plain tables of functions; the only metatable classes are the
  per-instance objects (`Shared/Spring`, the set returned by `Animations.NewSet`).
- Every module exposes `Start()`; connections go in a Trove or are cleaned on
  `PlayerRemoving`/`CharacterRemoving`. Anything that can fail at boot runs in a `pcall` and
  `warn`s, so one broken system or controller never stops the others.
- The README is the integrator contract: a new setting, API function, signal, remote or asset
  shape is documented there in the same change that adds it.
- Work follows `Docs/PLANO.md` phase by phase. A request that falls outside the current phase is
  written down in `Docs/<Topic>.md` (these notes are in Portuguese, with "Feito" / "Para depois"
  sections) and is not implemented until the plan reaches it, unless Gabriel asks for it
  directly. Update the "Estado" section of `PLANO.md` when a phase or extra lands.
- Free models are never trusted: Gabriel cleans them by hand and `WeaponModel.Sanitize` strips
  scripts again on every clone.
