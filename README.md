<div align="center">

# LilJustin

### The founder of [Orbit](https://get.yourorbit.team), on your desktop.

A free macOS dock companion that talks like Justin Williames — the founder of Orbit. Click him, ask anything about lifecycle marketing, deliverability, Braze, retention. Direct, no-fluff answers in the founder voice, with real Orbit guides cited as sources.

[![Latest release](https://img.shields.io/github/v/release/justinwilliames-sketch/liljustin?include_prereleases&label=latest&color=6366F1)](https://github.com/justinwilliames-sketch/liljustin/releases/latest)
[![License](https://img.shields.io/badge/license-MIT-6366F1)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-6366F1)](https://www.apple.com/macos/)

[**↓ Download LilJustin**](https://github.com/justinwilliames-sketch/liljustin/releases/latest)

</div>

---

## Install in 3 steps

### 1. Download the `.dmg`

Grab the **latest** `.dmg` from [the Releases page](https://github.com/justinwilliames-sketch/liljustin/releases/latest) and open it.

### 2. Drag **LilJustin** into Applications

Drag the LilJustin icon into the **Applications** shortcut inside the mounted DMG window.

### 3. ⚠️ Run this in Terminal once

LilJustin is unsigned (free side-project, no Apple Developer ID), so macOS Gatekeeper will block it on first launch. Open **Terminal** and paste:

```bash
xattr -dr com.apple.quarantine /Applications/LilJustin.app
```

Then double-click LilJustin in Applications. Mini Justin appears above your Dock.

> **Don't want to use Terminal?** Right-click `LilJustin.app` in Applications → **Open** → confirm. Or System Settings → Privacy & Security → "Open Anyway". Either works.

---

## What you can ask

Click Mini Justin. The popover shows 4 random prompt chips drawn from Orbit's full guide library — try one, or type your own. He answers in the founder voice with sources from the Orbit guide library when relevant.

Some examples of what he'll handle well:

- **Lifecycle programs** — onboarding flows, win-back, abandoned cart, replenishment, post-purchase, sunset
- **Deliverability** — Apple MPP, Gmail clipping, SPF/DKIM/DMARC, BIMI, reputation recovery, list hygiene
- **Channel craft** — subject lines, preheaders, dark mode, mobile design, accessibility, Liquid templating
- **Strategy & economics** — retention ROI, LTV, CRM vs CDP, building a lifecycle team, cadence
- **Measurement** — A/B test sample sizes, holdouts, incrementality, false positives, churn cohorts
- **Tools** — Braze, Iterable, Customer.io, HubSpot — what each gets right and wrong

For deeper, structured Orbit tooling (95 guides, 50+ skills, native Braze API), install the full **[Orbit MCP for Claude Desktop](https://get.yourorbit.team/download)**. Mini Justin will use those tools when they're available.

## Connect a model provider

Mini Justin needs a model. Open **Settings → Models** and pick one:

| Provider | What you need |
|---|---|
| **Claude Code** | The CLI installed and logged in. Auto-detected. Free with your Claude.ai subscription. |
| **Codex / ChatGPT** | The Codex CLI installed and logged in. Auto-detected. Free with your ChatGPT Plus subscription. |
| **OpenAI API** | An API key. Pay-as-you-go via OpenAI. |

Automatic mode prefers Claude Code → Codex → OpenAI in that order, depending on what you have available.

## Privacy

- **No analytics, no telemetry, no backend** — LilJustin runs entirely on your Mac.
- **Settings stay local** — provider choice, API keys, onboarding state all live in macOS `UserDefaults`.
- **Conversation traffic** goes only to the provider you connected (Claude / Codex / OpenAI). Not to me.
- **MIT licensed** — fork it, audit it, change it.

---

<details>
<summary><b>Developer notes — building from source, customising the personality, releasing</b></summary>

### Build from source

Clone, open in Xcode 16+ on macOS 14+, run the `LilAgents` scheme. Or from the command line:

```bash
git clone https://github.com/justinwilliames-sketch/liljustin.git
cd liljustin
xcodebuild -project lil-agents.xcodeproj -scheme LilAgents -configuration Debug build
```

See [NEXT_STEPS.md](NEXT_STEPS.md) for the one-time Xcode setup (scheme rename, bundle identifier, signing team, app icon).

### Customise the personality

The system prompt lives in [`LilAgents/Session/ClaudeSessionState.swift`](LilAgents/Session/ClaudeSessionState.swift) (`func buildInstructions`). It encodes the Orbit founder framing, five voice pillars, nine writing rules, the slop-detector anti-patterns, and the full slug→title manifest of all 87 Orbit guides for source citation. The canonical voice document this is distilled from lives in [`get-orbit/lib/admin/voice-guidelines.ts`](https://github.com/justinwilliames-sketch/get-orbit/blob/main/lib/admin/voice-guidelines.ts).

To fork this for your own founder companion:

1. Swap the system prompt for your voice and domain.
2. Replace the GIFs in `LilAgents/CharacterSprites/` (front, back, walk-left, walk-right, sleeping — same filenames).
3. Update bundle display name in `LilAgents/Info.plist`, welcome copy in `LilAgents/Terminal/TerminalView+TranscriptBehavior.swift`, and Settings → About in `LilAgents/App/SettingsView+ModelsPane.swift`.

### Sprites

The runtime expects these GIF filenames in `LilAgents/CharacterSprites/`:

- `main-front.gif` — idle front-facing animation
- `main-back.gif` — idle back-facing animation
- `lil-justin-walk-left.gif` — walk cycle, left-facing
- `lil-justin-walk-right.gif` — walk cycle, right-facing
- `main-sleeping.gif` — idle sleeping animation (used after a stretch of inactivity)

`NSImageView.animates = true` is set so multi-frame GIFs play automatically. Drop replacements in and rebuild.

### Releasing

Releases are built and published automatically by [`.github/workflows/build.yml`](.github/workflows/build.yml):

- **Every push to `main`** → CI builds a fresh `.dmg` and refreshes the rolling `latest` release.
- **Every `v*.*.*` tag push** → CI publishes a new tagged release that becomes the canonical "Latest" on the homepage.

```bash
# From a clean main branch:
git tag v0.1.2
git push origin v0.1.2
```

The CI run takes ~3 minutes. The `.dmg` ships unsigned with the install instructions baked into each release body.

### Credits

LilJustin builds on two open-source predecessors, both MIT-licensed and credited in [LICENSE](LICENSE):

- **[lil-agents](https://github.com/ryanstephen/lil-agents)** by Ryan Stephen — original macOS dock companion concept.
- **[lenny-lil-agents](https://github.com/hbshih/lenny-lil-agents)** by Ben Shih — pixel-art sprite layer + terminal-style popover.

</details>

---

<div align="center">

**Made by [Justin Williames](https://get.yourorbit.team) · MIT licensed · macOS 14+**

</div>
