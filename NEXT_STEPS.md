# LilJustin — Next Steps

This document covers the manual work that remains before LilJustin builds and ships, and the v2 cleanup tasks that are nice-to-have but not blocking.

## What's already done

- ✅ Lenny fork copied to `/Users/justin/LilJustin` (outside iCloud — required for stable Xcode builds).
- ✅ Heavy Lenny data deleted: `ExpertAvatars/` (16MB of headshots), `StarterArchive/` (~5MB of newsletter/podcast content), and Lenny demo media (`Lenny-Ads.mp4`, `LennyDemo.gif`, `hero-thumbnail.png`).
- ✅ All user-facing "Lil-Lenny" branding strings renamed to "LilJustin" / "Mini Justin".
- ✅ The Justin system prompt is wired into `LilAgents/Session/ClaudeSessionState.swift` — Australian voice, CRM/lifecycle/AI workflow expertise, no archive references, no expert handoffs, anti-sycophancy guards.
- ✅ Welcome copy and prompt chip suggestions rewritten for Justin's domain (CRM, lifecycle, Braze/HubSpot, AI workflows, trades vertical).
- ✅ The "Lenny source" Settings tab is hidden (the archive-mode toggle has no purpose without an archive). The pane file remains in the tree for upstream merge compatibility.
- ✅ Sparkle auto-update keys stripped from `Info.plist` — the upstream pointed at hbshih's GitHub release channel, which would have auto-updated LilJustin from someone else's repo. Security risk closed.
- ✅ `CFBundleDisplayName` and `CFBundleName` set to "LilJustin" in `Info.plist`.
- ✅ Placeholder Mini Justin sprites generated in `LilAgents/CharacterSprites/` so the app runs end-to-end before real art arrives.

## ⚠️ Required before first build (in Xcode)

These are easier in the Xcode UI than via hand-editing `project.pbxproj`. Open `/Users/justin/LilJustin/lil-agents.xcodeproj` and:

1. **Rename the scheme.**
   Product → Scheme → Manage Schemes → select `LilAgents` → rename to `LilJustin`.

2. **Set the bundle identifier.**
   Click the `LilAgents` target → Signing & Capabilities tab → set Bundle Identifier to something like `com.justinwilliames.LilJustin` or `ai.sophiie.LilJustin`. The current value is whatever Ben Shih had — you cannot ship under his identifier.

3. **Set the signing team.**
   Same tab → Team → select your Apple Developer account. Without this, the app will only run unsigned via Xcode (fine for local development).

4. **Replace the app icon.**
   `LilAgents/Assets.xcassets/AppIcon.appiconset/` currently contains the Lenny app icon. Drop your own `.png` files in (or remove the existing slots and add new ones) for sizes 16, 32, 64, 128, 256, 512, 1024 (×1 and ×2). You can generate a full set from a single 1024×1024 PNG using a tool like [appicon.co](https://appicon.co/).

5. **Optional: rename `lil-agents.xcodeproj` → `liljustin.xcodeproj`.**
   Cosmetic only. If you do, also rename inside Xcode (File → Rename Project) to keep the scheme references consistent. Skip if you don't care — the project filename is invisible to end users.

## Drop in your ChatGPT-generated sprites

When you have the real Mini Justin sprites, replace these files (exact filenames matter):

```
LilAgents/CharacterSprites/main-front.png             304 × 415 PNG, RGBA
LilAgents/CharacterSprites/main-back.png              304 × 415 PNG, RGBA
LilAgents/CharacterSprites/main-left.png              304 × 415 PNG, RGBA
LilAgents/CharacterSprites/main-right.png             304 × 415 PNG, RGBA
LilAgents/CharacterSprites/lil-justin-walk-left.gif   304 × 415 GIF, transparent, looped
LilAgents/CharacterSprites/lil-justin-walk-right.gif  304 × 415 GIF, transparent, looped
```

The placeholder generator script lives at `/tmp/lil_justin_placeholders.py` if you ever want to regenerate them. It uses Python PIL.

**Tip for ChatGPT prompting:** ask for one character in the HubSpot pixel-people aesthetic, generate one pose at a time using the same character reference, and ensure the output is on a transparent background. The walk GIF is the hardest part — you may want to generate two or three slightly different walking-pose PNGs and combine them into a GIF using `ffmpeg` or an online tool, since most image models won't produce animated GIFs natively.

## v2 cleanup (optional, not blocking)

The strip strategy was pragmatic: I removed user-facing Lenny presence and hid the archive-mode UI, but left the underlying Lenny archive Swift code in place so the project still compiles. None of it gets invoked at runtime now, but the dead code is still in the tree. When you have time:

- Remove `LilAgents/Session/LennyArchiveClient.swift`
- Remove `LilAgents/Session/LocalArchive.swift`
- Remove `LilAgents/Session/GuestTitles.swift`
- Remove `LilAgents/Session/ClaudeSessionExpertCatalog.swift`
- Remove `LilAgents/Session/ClaudeSessionExpertResolution.swift`
- Remove `LilAgents/Session/ClaudeSessionExpertTextResolution.swift`
- Remove `LilAgents/Session/ClaudeSessionOfficialArchive.swift`
- Remove `LilAgents/Session/ClaudeSessionTransport+Archive.swift`
- Remove `LilAgents/Character/WalkerCharacterExpertTag.swift`
- Remove `LilAgents/Terminal/MCPConnectionCards+OfficialMCP.swift`
- Remove `LilAgents/App/AppSettings+MCPConfig.swift`
- Remove `LilAgents/App/AppSettings+MCPInstaller.swift`
- Remove `LilAgents/App/SettingsView+SourcePane.swift`
- Then fix every compile error by removing the corresponding callers and import lines.

Expect this cleanup to take 2–3 hours of focused Swift refactoring. Don't bother unless you find yourself confused by the dead paths.

## Things to know about the system prompt

The prompt in `ClaudeSessionState.swift` deliberately:

- Tells the model to **never invent specific anecdotes** about your former employers ("at Linktree we did X..."). Without this guard, models hallucinate confidently. Keep this rule if you publish the repo.
- Tells the model to **never break character** when asked what model it is.
- **Mirrors the Caldwell working style** from your `CLAUDE.md` — direct, no sycophancy, willing to disagree. Side effect: Mini Justin will tell users when they're wrong, including potentially in ways that feel blunt to people who aren't expecting it.
- **Forces JSON output** with a single message in the `kind: "lenny"` schema. The string `"lenny"` is the internal parser key inherited from upstream and renaming it would break the transcript renderer. If you ever do v2 cleanup, you can rename the parser kind too.

If you want to test the prompt without rebuilding the app, paste the prompt into Claude or ChatGPT directly and chat — the personality will come through.

## Open questions worth deciding

1. **Is this open-source?** If yes, before pushing to GitHub: confirm you're comfortable with the personality file being public (it's mostly your CLAUDE.md profile distilled), and add a short personal note in `README.md`'s Credits section.
2. **App icon.** The dock-bar character is one thing — the macOS app icon (Finder, Launchpad) is another. You'll want a separate, recognisable icon. A simple "LJ" monogram or a Mini Justin headshot would both work.
3. **Eventually, voice grounding (#2 personality tier).** If Mini Justin starts feeling generic, the natural next step is RAG over your published CRM articles and Sophiie content. The Lenny fork's archive plumbing is still in the tree — you could repurpose it instead of deleting it.

## Verify the build

Once you've done the Xcode renames:

```bash
cd /Users/justin/LilJustin
xcodebuild -project lil-agents.xcodeproj -scheme LilJustin -configuration Debug build 2>&1 | tail -40
```

If the build succeeds, run the scheme in Xcode. Mini Justin should appear above your Dock. Click him to open the popover and ask a CRM question to verify the Justin voice is coming through.

If the build fails, the most likely culprits are:

- A scheme rename that didn't propagate (re-open the project after renaming the scheme).
- Missing signing identity (set Team in Signing & Capabilities).
- A reference in `project.pbxproj` to a file path that has changed (none should have changed, since we kept the `LilAgents/` source folder name).
