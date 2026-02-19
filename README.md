# TabKeys

macOS menu bar app for **system-wide AI completions**. Type anywhere, pause or press Tab to get suggestions, accept with Tab.

## Requirements

- macOS (tested on recent versions)
- **One** API key: **Anthropic** (Claude) or **OpenAI** (GPT-4o-mini) – set in the app via **Settings…**
- **Accessibility** permission (prompted on first run)

---

## Download and run (no Xcode)

1. **Download** the latest release:
   - Go to your repo’s **Releases** page (e.g. `https://github.com/YOUR_USERNAME/TabKeys/releases`) and download `TabKeys.zip`.
   - Download `TabKeys.zip`, unzip it, and move **TabKeys.app** to your Applications folder (or leave it on your Mac).
2. **First run**: Open **TabKeys.app**. Grant **Accessibility** when macOS asks.
3. **Add your API key**: Click the **keyboard icon** in the menu bar → **Settings…** → paste your **Anthropic** or **OpenAI** API key → **Save**. The app will use it immediately (no restart needed).
4. Use **Restart Monitor** from the menu if completions don’t appear after saving.

You can get keys from [Anthropic](https://console.anthropic.com/) or [OpenAI](https://platform.openai.com/api-keys). Keys are stored in the system Keychain, not in the app.

---

## Build from source (developers)

1. Clone and open in Xcode: `open TabKeys.xcodeproj`
2. Optional: set env vars for development (Scheme → Run → Arguments → Environment Variables: `ANTHROPIC_API_KEY` or `OPENAI_API_KEY`). Or use **Settings…** in the app.
3. Build and run (⌘R). Grant **Accessibility** when asked.

## How it works

- **Pause** (~0.5s) → AI completion is fetched and shown in a hover; press **Tab** to accept or keep typing to dismiss.
- **Tab** (with no hover) → does nothing (Tab passes through to the app).
- **Context**: Uses text **before the cursor** in the focused app (via Accessibility) when available; otherwise the typed buffer. Context is cleared on **click** or **app switch**.

## How to distribute the app

1. In Xcode: **Product → Archive** → **Distribute App** → **Copy App** (or custom) and save the `.app`.
2. Zip the `.app` and upload to **GitHub Releases** (or your site). Users download, unzip, and run.
3. Optional: **Notarize** the app (Apple’s notarization) so macOS doesn’t show “unidentified developer” – see [Apple’s notarization docs](https://developer.apple.com/documentation/security/notarizing_mac_software_before_distribution).
4. In the release notes, point users to **Settings…** in the menu to add their API key (no Xcode or env vars needed).
