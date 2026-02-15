import Cocoa
import ApplicationServices

class CompletionHoverWindow: NSWindow {
    private var completionText: String = ""
    private var textView: NSTextView?
    
    init() {
        // Create a borderless, floating window
        let contentRect = NSRect(x: 0, y: 0, width: 400, height: 60)
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Configure window properties
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.ignoresMouseEvents = true // Don't steal focus
        self.isMovable = false
        
        // Create the content view with rounded corners
        let contentView = NSView(frame: contentRect)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.95).cgColor
        contentView.layer?.cornerRadius = 8
        contentView.layer?.borderWidth = 1
        contentView.layer?.borderColor = NSColor.separatorColor.cgColor
        self.contentView = contentView
        
        // Create text view for completion text
        let textView = NSTextView(frame: NSRect(x: 12, y: 8, width: contentRect.width - 24, height: contentRect.height - 16))
        textView.isEditable = false
        textView.isSelectable = false
        textView.backgroundColor = .clear
        textView.textColor = .labelColor
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.alignment = .left
        contentView.addSubview(textView)
        self.textView = textView
        
        // Initially hidden
        self.alphaValue = 0
        self.orderOut(nil)
    }
    
    func showCompletion(_ text: String, at location: NSPoint) {
        guard !text.isEmpty else {
            hide()
            return
        }
        
        completionText = text
        
        // Update text view with completion text and hint
        let displayText = "\(text)  ⌨️ Press Tab to accept"
        let attributedString = NSMutableAttributedString(string: displayText)
        
        // Style the completion text
        let completionRange = NSRange(location: 0, length: text.count)
        attributedString.addAttribute(.foregroundColor, value: NSColor.labelColor, range: completionRange)
        attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 13), range: completionRange)
        
        // Style the hint text (gray, smaller)
        let hintRange = NSRange(location: text.count, length: displayText.count - text.count)
        attributedString.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: hintRange)
        attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 11), range: hintRange)
        
        textView?.textStorage?.setAttributedString(attributedString)
        
        // Adjust window height based on text
        let textWidth = self.frame.width - 24
        let textHeight = attributedString.boundingRect(with: NSSize(width: textWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin]).height
        let newHeight = max(50, textHeight + 20)
        var frame = self.frame
        frame.size.height = newHeight
        // Update text view frame
        textView?.frame = NSRect(x: 12, y: 8, width: textWidth, height: newHeight - 16)
        self.setFrame(frame, display: false)
        
        // Calculate window position (near cursor, slightly offset)
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        var windowOrigin = NSPoint(x: location.x + 20, y: location.y - 30)
        
        // Ensure window stays on screen
        if windowOrigin.x + self.frame.width > screenFrame.width {
            windowOrigin.x = location.x - self.frame.width - 20
        }
        if windowOrigin.y + self.frame.height > screenFrame.height {
            windowOrigin.y = location.y + 30
        }
        if windowOrigin.y < 0 {
            windowOrigin.y = 20
        }
        
        self.setFrameOrigin(windowOrigin)
        
        // Show with fade-in animation
        self.orderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().alphaValue = 1.0
        }
    }
    
    func hide() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            self.animator().alphaValue = 0.0
        } completionHandler: {
            self.orderOut(nil)
        }
    }
    
    func getCompletionText() -> String {
        return completionText
    }
    
    func isVisible() -> Bool {
        return self.alphaValue > 0 && self.isVisible
    }
}

