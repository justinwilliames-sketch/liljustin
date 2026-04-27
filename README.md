# LilJustin

A tiny macOS dock companion that talks like Justin Williames.

LilJustin lives above your Dock as a small pixel-art character (Mini Justin). Click him, and a terminal-style popover opens — ask anything about CRM, lifecycle marketing, AI workflows, or scaling a GTM function, and the response is shaped to mimic Justin's voice: direct, sharp, no fluff.

This is a **personality skin**, not a RAG system. There's no archive, no retrieval, no external knowledge base. It's a system prompt tuned to mimic Justin's voice and domain expertise on top of whichever model provider you connect (Claude Code, Codex, or the OpenAI API).

## Credits

LilJustin is forked from two excellent open-source projects:

- **[lil-agents](https://github.com/ryanstephen/lil-agents)** by Ryan Stephen — the original macOS dock companion concept.
- **[lenny-lil-agents](https://github.com/hbshih/lenny-lil-agents)** by Ben Shih — the Lil-Lenny fork that introduced the pixel-art sprite layer and terminal-style popover.

LilJustin keeps the dock window plumbing, click hit-testing, popover UI, and multi-provider session layer from those projects, and replaces the Lenny-archive personality and content layer with a Justin Williames personality skin.

Licensed MIT, like both upstream projects.

## What it does

- Renders Mini Justin as an animated dock-side character (currently placeholder sprites — see "Replacing the sprites" below).
- Opens a native macOS popover chat when you click him.
- Routes your messages through whichever provider you connect in Settings.
- Responds in Justin's voice — Australian English, CRM/lifecycle expertise, dry, opinionated, no sycophancy.

## What it does NOT do

- No archive, no RAG, no retrieval. It will not pretend to look things up.
- No expert handoffs (the upstream Lenny "let Elena Verna take this one" feature was removed).
- No external auto-updates. Sparkle config was stripped from `Info.plist` because the upstream pointed at someone else's release channel.

## Provider setup

LilJustin does not run a model locally. Connect one provider in Settings → Models:

- **Claude Code** — answers via the Claude Code CLI if installed and logged in.
- **Codex / ChatGPT** — answers via the Codex CLI.
- **OpenAI API** — direct API calls; requires an API key.

Automatic mode prefers Claude Code or Codex when detected, otherwise falls back to OpenAI when `OPENAI_API_KEY` (or a saved key in Settings) is available.

## Building

Open `lil-agents.xcodeproj` in Xcode 16+ on macOS 14+ and run the `LilAgents` scheme.

Or from the command line:

```bash
xcodebuild -project lil-agents.xcodeproj -scheme LilAgents -configuration Debug build
```

> See [NEXT_STEPS.md](NEXT_STEPS.md) for the manual Xcode tasks needed before the first build (target/scheme rename, bundle identifier, app icon).

## Replacing the sprites

The `LilAgents/CharacterSprites/` folder currently holds **placeholder** Mini Justin sprites — basic geometric figures with "PLACEHOLDER" labels so the app runs end-to-end before real art is ready.

The runtime expects exactly these six files:

| File | Purpose |
| --- | --- |
| `main-front.png` | Idle / front-facing pose |
| `main-back.png` | Back-facing pose (used when walking away) |
| `main-left.png` | Static left-facing fallback |
| `main-right.png` | Static right-facing fallback |
| `lil-justin-walk-left.gif` | Animated walk cycle, left-facing |
| `lil-justin-walk-right.gif` | Animated walk cycle, right-facing |

**Asset spec for the real sprites:**

- Canvas size: `304 × 415` pixels (RGBA, transparent background)
- Format: PNG for static poses, animated GIF for walk cycles
- Anchor: character vertically centered, feet roughly 16px above the bottom edge
- Style: HubSpot/Lenny-adjacent pixel-art aesthetic
- Walk GIF: 2–4 frame loop, ~240ms per frame, transparent background preserved

Drop replacement files into `LilAgents/CharacterSprites/` with the exact filenames above. No code changes needed — the runtime loads them by name from the bundle.

## Where the personality lives

The Justin system prompt is in:

```
LilAgents/Session/ClaudeSessionState.swift
```

Look for `func buildInstructions(...)`. To retune the voice, edit the prompt block. The function signature retains `expert` and `expectMCP` parameters for upstream compatibility but ignores them — LilJustin is single-persona and has no archive RAG.

If you want to fork this for *your own* personality:

1. Replace the system prompt with your voice and domain.
2. Replace the sprites in `CharacterSprites/`.
3. Update bundle display name in `LilAgents/Info.plist` and the welcome copy in `LilAgents/Terminal/TerminalView+TranscriptBehavior.swift`.

## Privacy

LilJustin does not run its own backend, has no analytics pipeline, and stores nothing remotely. All settings (provider choice, API keys, onboarding state) live in macOS `UserDefaults` on this Mac. Provider traffic goes only to whichever provider you connected.

## License

MIT. See [LICENSE](LICENSE).
