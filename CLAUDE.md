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
  `Remotes.EnsureAll()`; `Assets/Manifest.luau` lists what `Dev.Doctor()` expects to find.

Verification is Play in Roblox Studio (Play Solo, or Test with 2 players for replication). Boot
prints `[Azazel] <version> 4/4 systems started` (server) and `... 7/7 controllers started`
(client). Studio-only helpers live in `ReplicatedStorage/Azazel/Dev/Commands.luau` and are run
from the command bar (`Dev.Setup()`, `Dev.SpawnDummy(n)`, `Dev.Give(name)`, `Dev.Doctor()`,
`Dev.PrintFalloff()`, grip tuning, animation rig); the module returns `{}` outside Studio.

## Git rules (enforced by a hook)

Enable once after cloning: `git config core.hooksPath .githooks`.

- **Every commit** bumps `ReplicatedStorage/Azazel/Version.luau` and adds an entry to
  `CHANGELOG.md` (newest first, one section per version). The pre-commit hook blocks the commit
  otherwise. Inside a `dev`/`alpha`/`beta` channel a planned feature only bumps `Build`.
- Every commit gets a tag equal to `Version.Tag()` (for example `v0.2.0-alpha.10`).
- Message: `type(scope): what changed`, short body saying why, footer with the version. Types
  and scopes are in `COMMITS.md`. English.
- `Cons/` at the root is a local library catalog, gitignored. Libraries used by the package are
  vendored into `ReplicatedStorage/Azazel/Packages/` with an origin/license line at the top; do
  not require anything from `Cons/` directly.

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
  equip state machine (`Holstered`/`Equipping`/`Ready`...), equipment, accuracy/spray state,
  shot sequence. It pushes the `State` snapshot to the owner only on lifecycle events and
  rejections, never per shot.
- `Combat` handles `Fire`/`Reload`/`Aim`/`SetFireMode`: validates every request (see "Security"
  below), rolls the spread with its own RNG, raycasts per pellet, applies zone/falloff/armor
  damage, writes kill credit (`AzazelLastAttackerUserId`/`AzazelLastWeapon` attributes plus a
  `creator` ObjectValue), broadcasts `ShotFired` (unreliable) and `HitConfirmed`.
- `CharacterRig` attaches/detaches the replicated weapon Model on spawn and cleans up on death.
- `Ragdoll` is used by Combat on lethal hits (server freezes the real character and fires the
  `Ragdoll` remote; each client simulates its own copy).

### Client

`Azazel.local.luau` requires every ModuleScript in `Client/Controllers/` and calls `Start()`
on each in its own `task.spawn` + pcall, **with no ordering**. Adding a controller is dropping a
module with a `Start()` there. Controllers share state through the bus in `Client/init.luau`
(`Client.Signals.*`, `Client.State`, `Client.Config`, `Client.View`, `Client.Aiming`) and must
not depend on another controller having started. The only direct cross-requires are
`WeaponController -> CameraController.GetAimRay()` and the viewmodel's `GetAnimator()`.

Controllers: `Input` (ContextActionService -> input Signals), `Camera` (OTS, lock, ADS, zoom,
shoulder), `Weapon` (predicted fire loop, reload/equip, reconciliation with `State`),
`Viewmodel` (first person arms cloned from the player's own rig), `Effects` (tracers via
PartCache, per-quality LOD), `Hud` (built with `Shared/UIKit`), `Ragdoll`.
`Client/Quality.luau` picks Low/Medium/High from the saved graphics level or measured FPS and
every effect reads `Settings.Quality.Levels[level]`.

### Data and config

- Weapons: `WeaponConfig.Get(name)` deep-merges `Defaults <- Classes[Class] <- Weapons/<Name>`,
  freezes the result and derives `ShotInterval`/`BurstInterval` from `Rpm`. A weapon module lists
  only what differs from its class. Adding a weapon = one module in `Config/Weapons/` plus the
  Model in `Assets/Weapons/<Model>` imported through `Dev.ImportWeapon`. Class order is
  `Pistol, SMG, Rifle, Shotgun, Sniper`.
- Equipment: `Config/Equipment/<Name>.luau` with `Zone`, `DamageMultiplier`, optional
  `Durability`, and `Modifiers` (`{ Add, Mul }` per field) that `WeaponConfig.Resolve` stacks
  onto the equipped weapon.
- Everything else tunable is in `Config/Settings.luau`, one table per area (`Camera`,
  `Viewmodel`, `Keys`, `Hud`, `Server`, `Animations`, `Quality`, `Effects`, `Ragdoll`, `Debug`,
  `Strings`). Player-visible text goes in `Settings.Strings`, never inline.
- `Config/AnimationIds.luau` is the manifest of published animation ids per class/slot; in
  Studio the embedded KeyframeSequences under `Assets/Animations/<Class>/<Slot>` are registered
  on the fly instead.

### Shared modules

`Shared/` modules run on both sides. `Accuracy` and `Damage` are pure math: the server uses
them for the real roll, the client only to size the crosshair. `Rig` abstracts the avatar
(R6 tables live; R15 is a stub with `Enabled = false`) and maps parts to damage zones.
`WeaponModel.Attach` is the single place a weapon is welded to a hand (Motor6D named `Handle`,
`Part0 = Right Arm`, `C0 = Rig.HandOffset`, `C1 = cfg.Grip`); the server character, the first
person viewmodel and the animation rig all use it, so one animation set drives all three.
Weapons are Models, never Tools with Handles. With `Settings.Server.UseBackpack` (default) the
Roblox Backpack is the inventory: a marker Tool per weapon (`Systems/Backpack`) takes a slot
and its `Equipped`/`Unequipped` drive `Inventory.Equip`; the API routes through it.

### Remotes and security

`Shared/Remotes.luau` is a closed registry: every remote is declared in `DEFINITIONS` with
kind, direction, a `T` schema and a per-player token-bucket rate. `Remotes.Get` on an
undeclared name asserts; `OnServer` runs rate limit then schema before the handler and counts
violations (`Settings.Server.KickOnAbuse`). Adding a remote means adding a definition there.

Invariants to keep: the client sends only origin, unit direction and sequence number per shot;
the server owns ammo, timers, fire modes, spread RNG, raycasts, damage, armor and kill credit;
no RemoteFunctions, no HttpService, no DataStore. `ImportWeapon` deletes every script from a
free model and `WeaponModel.Clone` does it again. Weapon/tracer/casing parts have
`CanQuery = false` so raycasts ignore them.

## Working conventions

- Code, identifiers, comments, README, CHANGELOG and commit messages are in English. Comments
  are minimal. 4-space indentation. PascalCase for modules, instances and config keys; camelCase
  for locals. Prints and warns are prefixed `[Azazel]`.
- Every module exposes `Start()`; connections go in a Trove or are cleaned on
  `PlayerRemoving`/`CharacterRemoving`.
- Work follows `Docs/PLANO.md` phase by phase. A request that falls outside the current phase is
  written down in `Docs/<Topic>.md` (these notes are in Portuguese, with "Feito" / "Para depois"
  sections) and is not implemented until the plan reaches it, unless Gabriel asks for it
  directly. Update the "Estado" section of `PLANO.md` when a phase or extra lands.
- Free models are never trusted; anything from the Creator Store goes through `Dev.ImportWeapon`.
