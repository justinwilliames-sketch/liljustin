<div align="center">

# This project is now Orion by Orbit

### LilJustin moved to **[justinwilliames-sketch/orion-by-orbit](https://github.com/justinwilliames-sketch/orion-by-orbit)**.

</div>

---

## Why the rename?

LilJustin was a personal joke (Justin's name in the title) that didn't scale beyond his own machine. The macOS dock companion was rebranded to **Orion by Orbit** so any lifecycle marketer can install it on their own desktop without it reading as someone else's tool.

Orion is the same app — same Orbit voice, same guide-cited answers, same character walking on your dock — under a name that travels.

## Get Orion

[**↓ Download the latest Orion release**](https://github.com/justinwilliames-sketch/orion-by-orbit/releases/latest)

All future development, releases, issues, and discussion happen on the new repo:

**[github.com/justinwilliames-sketch/orion-by-orbit](https://github.com/justinwilliames-sketch/orion-by-orbit)**

## What about my existing LilJustin install?

Bundle identifier changed (`team.yourorbit.LilJustin` → `team.yourorbit.Orion`), so Sparkle can't auto-migrate across the rename. Manual install once:

1. Download `Orion-vX.X.X.dmg` from the [new repo's Releases page](https://github.com/justinwilliames-sketch/orion-by-orbit/releases/latest).
2. Drag **Orion** into Applications. You can leave or delete the old `LilJustin.app` — they're separate apps to macOS.
3. Run `xattr -dr com.apple.quarantine /Applications/Orion.app` in Terminal once.
4. Launch Orion.

From there, Sparkle auto-updates Orion normally for every future release.

## Repo status

This repo is **archived**. Tagged releases up to and including `v0.1.68` remain available for historical reference but receive no further updates. The Sparkle appcast on this repo stops at `v0.1.68` — it will not advertise newer versions.

For everything after that, see **[orion-by-orbit](https://github.com/justinwilliames-sketch/orion-by-orbit)**.
