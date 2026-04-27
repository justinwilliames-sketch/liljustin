# LilJustin

The founder of [Orbit](https://get.yourorbit.team), on your desktop.

Mini Justin lives above your Dock as a small pixel-art character. Click him, and a terminal-style popover opens — ask anything about lifecycle marketing, deliverability, Braze, retention economics, or anything else from the Orbit playbook, and the response comes back in Justin's founder voice: direct, sharp, mechanism-first.

It's a **gimmick** — a downloadable easter-egg companion to the main Orbit MCP extension. The serious work happens inside Claude with the [Orbit MCP](https://get.yourorbit.team/download) installed (95+ guides, 50+ skills, native Braze integration, all the real tooling). Mini Justin is the dock-pinned, conversational version of "ask the founder a quick question."

Under the hood it's a personality layer on top of whichever model provider you connect in Settings (Claude Code, Codex, or OpenAI API) — no RAG, no archive baked into the app itself. If you have the Orbit MCP installed in Claude Code, Mini Justin will prefer those tools when grounding answers in current Orbit guide content.

## Credits

LilJustin is forked from two excellent open-source projects:

- **[lil-agents](https://github.com/ryanstephen/lil-agents)** by Ryan Stephen — the original macOS dock companion concept.
- **[lenny-lil-agents](https://github.com/hbshih/lenny-lil-agents)** by Ben Shih — the Lil-Lenny fork that introduced the pixel-art sprite layer and terminal-style popover.

LilJustin keeps the dock window plumbing, click hit-testing, popover UI, and multi-provider session layer from those projects, and replaces the Lenny-archive personality and content layer with an Orbit founder personality.

Licensed MIT, like both upstream projects.

## What it does

- Renders Mini Justin as an animated 36-frame dock-side character (4 directions: front, back, walk-left, walk-right).
- Opens a native macOS popover chat when you click him.
- Routes your messages through whichever provider you connect in Settings.
- Responds in Justin's founder voice — Australian English, lifecycle/CRM/deliverability expertise, mechanism over generality, no sycophancy.

## What it does NOT do

- No archive, no RAG, no retrieval inside this app itself. For deep grounding in the full Orbit guide library, install the [Orbit MCP](https://get.yourorbit.team/download) for Claude Desktop — Mini Justin will prefer those tools when they're available.
- No expert handoffs (the upstream Lenny "let Elena Verna take this one" feature was removed).
- No external auto-updates. Sparkle config was stripped from `Info.plist` because the upstream pointed at someone else's release channel.

## Provider setup

LilJustin does not run a model locally. Connect one provider in Settings → Models:

- **Claude Code** — answers via the Claude Code CLI if installed and logged in.
- **Codex / ChatGPT** — answers via the Codex CLI.
- **OpenAI API** — direct API calls; requires an API key.

Automatic mode prefers Claude Code or Codex when detected, otherwise falls back to OpenAI when `OPENAI_API_KEY` (or a saved key in Settings) is available.

## Install (recommended)

The easiest path for end users — no Xcode required:

1. Grab the latest `.dmg` from [GitHub Releases](https://github.com/justinwilliames-sketch/liljustin/releases).
2. Open it, drag **LilJustin** to your Applications folder.
3. **First-launch step.** This build is unsigned (free side-project, no Apple Developer ID), so macOS will refuse to launch it without one of these:

    ```bash
    # Easiest: paste this once in Terminal to remove the quarantine flag.
    xattr -dr com.apple.quarantine /Applications/LilJustin.app
    ```

    Or right-click the app → **Open** → confirm. Or System Settings → Privacy & Security → "Open Anyway".

4. Launch from Applications. Mini Justin appears above your Dock.

## Building from source (Xcode)

If you'd rather build it yourself — required if you want to change the personality, sprites, or anything else.

Open `lil-agents.xcodeproj` in Xcode 16+ on macOS 14+ and run the `LilAgents` scheme.

Or from the command line:

```bash
xcodebuild -project lil-agents.xcodeproj -scheme LilAgents -configuration Debug build
```

> See [NEXT_STEPS.md](NEXT_STEPS.md) for the manual Xcode tasks needed before the first build (target/scheme rename, bundle identifier, app icon).

## Releasing a new version (GitHub Actions)

Releases are built automatically by [`.github/workflows/build.yml`](.github/workflows/build.yml) on every `v*.*.*` tag push. The workflow runs on a stock GitHub-hosted macOS runner — no local Xcode required.

```bash
# From a clean main branch:
git tag v0.1.0
git push origin v0.1.0
```

CI will build an unsigned `LilJustin.app`, wrap it in `LilJustin-v0.1.0.dmg`, and publish a GitHub Release with the `.dmg` attached and install instructions in the body. Takes ~5–8 minutes.

To dry-run without tagging — go to the [Actions tab](https://github.com/justinwilliames-sketch/liljustin/actions) and use **Run workflow** on the Build workflow. The .dmg lands as a workflow artifact (downloadable for 30 days) but no Release is created.

## Sprites

`LilAgents/CharacterSprites/` ships four hand-authored 36-frame animated GIFs (idle front, idle back, walk-left, walk-right). The runtime expects these exact filenames:

| File | Purpose |
| --- | --- |
| `main-front.gif` | Idle front-facing animation (breathing, slight movement) |
| `main-back.gif` | Idle back-facing animation |
| `lil-justin-walk-left.gif` | Walk cycle, left-facing |
| `lil-justin-walk-right.gif` | Walk cycle, right-facing |

`NSImageView.animates = true` is set in `WalkerCharacterCore.swift`, so Cocoa plays the multi-frame GIFs automatically. To swap the character, drop replacement GIFs in with the same filenames.

## Where the personality lives

The Justin system prompt is in `LilAgents/Session/ClaudeSessionState.swift` (`func buildInstructions`). It encodes the Orbit founder framing, the five voice pillars (Linus Tech Tips, Marques Brownlee, Ricky Gervais, Lenny's Newsletter, Elena Verna — tone only, never their content), nine writing rules, and the slop-detector anti-patterns. The canonical voice document this is distilled from lives in the [get-orbit repo](https://github.com/justinwilliames-sketch/get-orbit) at `lib/admin/voice-guidelines.ts`.

If you want to fork this for *your own* founder companion:

1. Replace the system prompt with your voice and domain.
2. Replace the GIFs in `CharacterSprites/`.
3. Update bundle display name in `LilAgents/Info.plist` and the welcome copy in `LilAgents/Terminal/TerminalView+TranscriptBehavior.swift`.

## Privacy

LilJustin does not run its own backend, has no analytics pipeline, and stores nothing remotely. All settings (provider choice, API keys, onboarding state) live in macOS `UserDefaults` on this Mac. Provider traffic goes only to whichever provider you connected.

## License

MIT. See [LICENSE](LICENSE).
