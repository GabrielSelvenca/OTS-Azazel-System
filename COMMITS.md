# How we commit

This file explains how commits, versions and tags work in Azazel. It is short on purpose.
If something here gets in your way, change the file together with the code.

## One commit, one version

Every commit changes `ReplicatedStorage/Azazel/Version.luau` and adds a line to `CHANGELOG.md`.
No exceptions, not even typos. The pre-commit hook in `.githooks/` enforces it. Enable it once
after cloning:

```
git config core.hooksPath .githooks
```

Why so strict? Anyone using the package in a game needs to point at an exact version and be
able to go back to it. If two commits share a version, "go back to 0.3.2" means nothing.

## Version numbers

`Major.Minor.Patch-channel.build`, for example `0.4.1-beta.3`.

- **Patch** goes up for fixes, tuning and small polish. Nothing new for the player.
- **Minor** goes up when a feature lands (a new system, a new weapon class, a new API function).
  Patch goes back to 0.
- **Major** goes up when games using the package need to change their own code to update.
  Minor and Patch go back to 0. Also used for the first public release (1.0.0).
- **Build** goes up on every commit inside the same channel and resets when the channel changes.

## Channels

| Channel | Meaning |
|---|---|
| `dev` | Work in progress. May not even run. Never ship this. |
| `alpha` | Runs in Studio, features missing or rough. |
| `beta` | Feature complete for this version. Being played and tuned. |
| `rc` | Release candidate. Only fixes go in. |
| `release` | Stable. The tag has no suffix, for example `v1.2.0`. |
| `hotfix` | A fix on top of a release, for example `v1.2.1-hotfix.1`. |

## Tags

Every commit gets a tag equal to `Version.Tag()`, for example `v0.1.0-alpha.1`.

```
git tag v0.1.0-alpha.1
git push --tags
```

To try an old version in a game: check out the tag, copy `ReplicatedStorage/Azazel` and the two
bootstrap scripts into the place.

## Commit message

```
type(scope): what changed, in plain words

Why it changed, if the title does not say it. One or two sentences.

Version: 0.1.0-alpha.1
```

Types: `feat` (new capability), `fix` (something was wrong), `feel` (tuning of numbers, camera,
recoil, timings), `refactor` (same behavior, better code), `docs`, `assets` (models, sounds,
animations, ids), `chore` (git, hooks, files that are not code).

Scopes are folder or system names: `combat`, `camera`, `viewmodel`, `hud`, `animations`,
`config`, `remotes`, `dev`, `packages`.

Examples that read well:

```
feat(combat): shotgun pellets with independent spread

Each pellet rolls its own cone on the server and does its own raycast.

Version: 0.3.0-alpha.1
```

```
feel(camera): softer recoil recovery on rifles

Players said the AK felt like it snapped back. Recovery went from 0.35s to 0.6s.

Version: 0.3.1-alpha.2
```

Write in English. Say what and why, not how. If you need three paragraphs, the commit is too big.
