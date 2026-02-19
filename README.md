<h1 align="center">
  <br>
  <img src="TabKeys/TabKeys/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" alt="TabKeys" width="150">
  <br>
  TabKeys
  <br>
</h1>

<p align="center">
  macOS menu bar app for <strong>system-wide AI completions</strong>. Type anywhere, pause or press Tab to get suggestions, accept with Tab.
</p>

---

## Demo

TabKeys suggests completions **system-wide**: type in any app, pause briefly or press **Tab** to trigger a suggestion, then accept with **Tab**.

|  |
| :---: |
| ![TabKeys Demo](assets/demo.mp4) |
| *Pause or press Tab to get a suggestion, Tab again to accept.* |


---

## Installation

**System Requirements:**

- macOS (tested on recent versions)
- **One** API key: **Anthropic** (Claude) or **OpenAI** (GPT-4o-mini) – set in the app via **Settings…**
- **Accessibility** permission (prompted on first run)

---

> [!IMPORTANT]
> I don't have an Apple Developer account yet. The app is not notarized and may show a popup on first launch that it is from an unidentified developer.
>
> 1. Click **OK** to close the popup.
> 2. Open **System Settings** > **Privacy & Security**.
> 3. Scroll down and click **Open Anyway** next to the warning about the app.
> 4. Confirm your choice if prompted.
>
> You only need to do this once.

### Option 1: Install via Homebrew

You can also install the app using [Homebrew](https://brew.sh):

```bash
brew install --cask MahitGtg/tap/tabkeys
```

TabKeys.app will be in **Applications**. To update later: `brew upgrade --cask tabkeys`.

### Option 2: Download and Install Manually

1. Go to the [Releases](https://github.com/MahitGtg/TabKeys/releases) page and download **TabKeys.zip**.
2. Unzip and move **TabKeys.app** to Applications (or leave it anywhere).
3. Open **TabKeys.app**. Grant **Accessibility** when macOS asks. If macOS blocks the app, use **Open Anyway** as in the steps above.

### After install

1. **Add an API key**: Click the **keyboard icon** in the menu bar → **Settings…** → paste an **Anthropic** or **OpenAI** API key → **Save**. The app will use it immediately (no restart needed).
2. Use **Restart Monitor** from the menu if completions don’t appear after saving.

**Privacy:** Your API key is stored only in **macOS Keychain** on your Mac. We don’t store or have access to it. Only the text before the cursor is sent to the provider you choose to generate completions.

API keys can be created at [Anthropic](https://console.anthropic.com/) or [OpenAI](https://platform.openai.com/api-keys).

---

## Usage

- **Pause** (~0.5s) while typing → AI completion is fetched and shown in a hover; press **Tab** to accept or keep typing to dismiss.
- **Tab** (with no suggestion showing) → passes through to your app as normal.
- **Context**: Uses text **before the cursor** in the focused app (via Accessibility) when available; otherwise the typed buffer. Context is cleared on **click** or **app switch**.

---

## Building from Source

### Prerequisites

- **macOS** (recent version)
- **Xcode** (from the Mac App Store) with Command Line Tools
- **API key** for development (set in the app **Settings…** or via environment variables below)
- **Accessibility** permission (macOS will prompt on first run)

### Installation

1. **Clone the Repository**:

   ```bash
   git clone https://github.com/MahitGtg/TabKeys.git
   cd TabKeys
   ```

2. **Open the Project in Xcode**:

   ```bash
   open TabKeys/TabKeys.xcodeproj
   ```

3. **Optional – Set API key via environment** (so you don’t have to paste it in Settings every run):
   - In Xcode: **Product** → **Scheme** → **Edit Scheme…** (or ⌘<).
   - Select **Run** → **Arguments** → **Environment Variables**.
   - Add `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` with your key as the value.

4. **Build and Run**:
   - Click the **Run** button or press **Cmd + R**. Grant **Accessibility** when macOS prompts.

5. **Signing (if needed)**: If Xcode complains about signing, select the **TabKeys** target → **Signing & Capabilities** → choose your **Team** (or “Sign to Run Locally” for development).

## Known Limitations

- Context reading via Accessibility API works best in native macOS apps (TextEdit, Notes, Mail)
- Some apps (VS Code, Chrome, Slack) may have limited context awareness
- Arrow key navigation currently clears context (coming soon: smarter navigation handling)

## Roadmap

- [ ] Faster model options (local/Groq)
- [ ] Smarter context preservation during navigation
- [ ] Completion quality metrics

---

## License

MIT – see [LICENSE](LICENSE).
