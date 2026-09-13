# Changelog

All notable changes to Azazel. Newest first. One entry per version.

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
