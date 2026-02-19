import AppKit

final class SettingsWindowController: NSWindowController {
    private let onSave: () -> Void

    private var anthropicField: NSSecureTextField!
    private var openaiField: NSSecureTextField!

    init(onSave: @escaping () -> Void) {
        self.onSave = onSave
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "TabKeys – API Keys"
        window.center()
        super.init(window: window)

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 180))
        window.contentView = content

        let label1 = NSTextField(labelWithString: "Anthropic API Key (optional):")
        label1.frame = NSRect(x: 20, y: 130, width: 380, height: 20)
        content.addSubview(label1)

        anthropicField = NSSecureTextField(frame: NSRect(x: 20, y: 95, width: 380, height: 24))
        anthropicField.placeholderString = "sk-ant-..."
        if let saved = KeychainHelper.load(key: "anthropic_api_key"), !saved.isEmpty {
            anthropicField.placeholderString = "(saved – enter new to replace)"
        }
        content.addSubview(anthropicField)

        let label2 = NSTextField(labelWithString: "OpenAI API Key (optional):")
        label2.frame = NSRect(x: 20, y: 68, width: 380, height: 20)
        content.addSubview(label2)

        openaiField = NSSecureTextField(frame: NSRect(x: 20, y: 33, width: 380, height: 24))
        openaiField.placeholderString = "sk-..."
        if let saved = KeychainHelper.load(key: "openai_api_key"), !saved.isEmpty {
            openaiField.placeholderString = "(saved – enter new to replace)"
        }
        content.addSubview(openaiField)

        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveTapped))
        saveButton.frame = NSRect(x: 320, y: 8, width: 80, height: 28)
        saveButton.bezelStyle = .rounded
        content.addSubview(saveButton)

        let hint = NSTextField(labelWithString: "Store one or both. Keys are saved in Keychain. Restart monitor after saving.")
        hint.frame = NSRect(x: 20, y: 0, width: 290, height: 20)
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        content.addSubview(hint)
    }

    required init?(coder: NSCoder) { nil }

    @objc private func saveTapped() {
        let anthropic = anthropicField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let openai = openaiField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if anthropic.isEmpty {
            KeychainHelper.delete(key: "anthropic_api_key")
        } else {
            _ = KeychainHelper.save(key: "anthropic_api_key", value: anthropic)
        }
        if openai.isEmpty {
            KeychainHelper.delete(key: "openai_api_key")
        } else {
            _ = KeychainHelper.save(key: "openai_api_key", value: openai)
        }

        onSave()
        window?.close()
    }
}
