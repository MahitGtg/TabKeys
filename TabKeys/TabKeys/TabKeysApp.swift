import SwiftUI

@main
struct TabKeysApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var keyboardMonitor: KeyboardMonitor?
    private var permissionTimer: Timer?
    private var completionAPI: CompletionAPI?
    private var settingsWindowController: SettingsWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the menubar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "TabKeys")
        }
        
        // Create the menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About TabKeys", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Test AI Completion", action: #selector(testAICompletion), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Restart Monitor", action: #selector(restartMonitor), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Check Permissions", action: #selector(checkPermissions), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        
        reloadCompletionAPI()
        keyboardMonitor = KeyboardMonitor(completionAPI: completionAPI)

        // Check and ensure permissions
        ensurePermissions()

        print("✅ TabKeys launched successfully!")
    }
    
    private func ensurePermissions() {
        keyboardMonitor?.start()
        
        // Small delay to let macOS register the app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            if !AXIsProcessTrusted() {
                // Show the system prompt
                let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                _ = AXIsProcessTrustedWithOptions(options)
                
                // Start monitoring for when user actually grants permission
                self?.startPermissionMonitoring()
            } else {
                // Already have permissions
                print("✅ Already have permissions")
            }
        }
    }

    private func startPermissionMonitoring() {
        // Check every 1 second if permissions were granted
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            if AXIsProcessTrusted() {
                print("🎉 Permissions granted! Starting monitor...")
                self?.keyboardMonitor?.stop()
                self?.keyboardMonitor?.start()
                timer.invalidate()
                self?.permissionTimer = nil
            }
        }
    }
    
    /// Load API from Keychain first, then environment variables.
    private func reloadCompletionAPI() {
        let anthropicKey = KeychainHelper.load(key: "anthropic_api_key")
            ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        let openaiKey = KeychainHelper.load(key: "openai_api_key")
            ?? ProcessInfo.processInfo.environment["OPENAI_API_KEY"]

        if let key = anthropicKey, !key.isEmpty {
            completionAPI = AnthropicAPI(apiKey: key)
            print("✅ Anthropic API initialized")
        } else if let key = openaiKey, !key.isEmpty {
            completionAPI = OpenAIAPI(apiKey: key)
            print("✅ OpenAI API initialized")
        } else {
            completionAPI = nil
            print("⚠️ Open Settings from the menu to add an API key (Anthropic or OpenAI)")
        }

        keyboardMonitor?.setCompletionAPI(completionAPI)
    }

    @objc func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController { [weak self] in
                self?.reloadCompletionAPI()
                self?.keyboardMonitor?.stop()
                if AXIsProcessTrusted() {
                    self?.keyboardMonitor?.start()
                }
            }
        }
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "TabKeys"
        alert.informativeText = "Version 1.0\nSystem-wide AI completions"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func restartMonitor() {
        print("🔄 Restarting keyboard monitor...")
        keyboardMonitor?.stop()
        
        if AXIsProcessTrusted() {
            keyboardMonitor?.start()
        } else {
            print("⚠️  No accessibility permissions")
            ensurePermissions()
        }
    }

    @objc func checkPermissions() {
        let trusted = AXIsProcessTrusted()
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions"
        alert.informativeText = trusted ? "✅ Permissions are granted!" : "❌ Permissions not granted"
        alert.alertStyle = trusted ? .informational : .warning
        alert.addButton(withTitle: "OK")
        if !trusted {
            alert.addButton(withTitle: "Open Settings")
        }

        let response = alert.runModal()
        if !trusted && response == .alertSecondButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc func testAICompletion() {
        guard let completionAPI = completionAPI else {
            print("❌ No API key set. Use Settings… from the menu to add one.")
            return
        }

        print("🧪 Testing AI completion...")

        let testSentences = [
            "The quick brown fox",
            "In Swift programming, we can",
            "When debugging this issue, I need to",
            "The weather today is"
        ]

        let testSentence = testSentences.randomElement() ?? testSentences[0]
        print("📝 Input: \"\(testSentence)\"")

        Task {
            do {
                let completion = try await completionAPI.getCompletion(for: testSentence)
                print("🤖 Completion: \"\(completion)\"")
                print("📄 Full result: \"\(testSentence)\(completion)\"")
            } catch {
                print("❌ Error: \(error.localizedDescription)")
            }
        }
    }

    @objc func quit() {
        permissionTimer?.invalidate()
        NSApplication.shared.terminate(nil)
    }
}
