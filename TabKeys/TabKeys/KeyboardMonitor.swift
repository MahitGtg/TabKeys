import Cocoa
import ApplicationServices
import Carbon


class KeyboardMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false
    private var contextBuffer = ""
    private var lastKeystrokeTime = Date()
    private var pauseTimer: Timer?
    private let pauseThreshold: TimeInterval = 0.5 // 0.5 seconds of pause
    private weak var anthropicAPI: AnthropicAPI?
    private var hoverWindow: CompletionHoverWindow?
    private var pendingCompletion: String? = nil
    private var appSwitchObserver: NSObjectProtocol?

    init(anthropicAPI: AnthropicAPI?) {
        self.anthropicAPI = anthropicAPI
        self.hoverWindow = CompletionHoverWindow()
    }
        
    func start() {
        guard !isRunning else {
            print("⚠️ Monitor already running")
            return
        }
        
        print("🎯 Starting keyboard monitor...")
        
        // Key down + mouse down (clicks) so we can clear context on click
        let eventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon!).takeUnretainedValue()

                switch type {
                case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                    // Pointer click: clear context so we stay context-aware
                    monitor.clearContextOnFocusChange()
                case .keyDown:
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

                    // Tab key (keyCode 48) - only insert completion if hover has one; otherwise let Tab through
                    if keyCode == 48 {
                        if monitor.acceptPendingCompletion() {
                            return nil // Consume the tab event (we inserted text)
                        }
                        // No completion in hover: let Tab pass through to the app
                    }

                    // For other keys, capture the character and add to buffer
                    monitor.handleKeystroke(event: event)
                default:
                    break
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: selfPointer
        ) else {
            print("❌ Failed to create event tap")
            return
        }
        
        self.eventTap = eventTap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        // Clear context when user switches app
        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearContextOnFocusChange()
        }
        
        isRunning = true
        print("✅ Keyboard monitor started!")
    }
    
    func stop() {
        guard isRunning else { return }

        pauseTimer?.invalidate()
        pauseTimer = nil
        
        dismissHover()

        if let observer = appSwitchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appSwitchObserver = nil
        }

        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let runLoopSource = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            }
        }

        isRunning = false
        print("⏹️  Keyboard monitor stopped")
    }
    
    /// Clears context buffer and dismisses hover when focus changes (click or app switch).
    /// Keeps completions context-aware: only continuous typing in the same place is used.
    private func clearContextOnFocusChange() {
        guard !contextBuffer.isEmpty || pendingCompletion != nil else { return }
        contextBuffer = ""
        dismissHover()
        pauseTimer?.invalidate()
        pauseTimer = nil
        print("🧹 Context cleared (click or app switch)")
    }
    
    private func handleKeystroke(event: CGEvent) {
        // Dismiss hover window if user continues typing
        if hoverWindow?.isVisible() == true {
            dismissHover()
        }
        
        // Convert the key event to a character
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Handle special keys
        if keyCode == 51 { // Backspace
            if !contextBuffer.isEmpty {
                contextBuffer.removeLast()
                print("⌫ Backspace - buffer now: \"\(contextBuffer.suffix(20))...\"")
            }
            resetPauseTimer()
            return
        }

        if keyCode == 36 { // Return/Enter
            contextBuffer += "\n"
            print("↵ Enter - buffer now: \"\(contextBuffer.suffix(20))...\"")
            resetPauseTimer()
            return
        }

        // Extract the character from the CGEvent
        if let nsEvent = NSEvent(cgEvent: event) {
            let character = nsEvent.characters ?? ""
            if !character.isEmpty {
                contextBuffer += character
                print("⌨️  '\(character)' - buffer: \"\(contextBuffer.suffix(30))...\"")
            }
        }

        resetPauseTimer()
    }

    private func resetPauseTimer() {
        lastKeystrokeTime = Date()
        pauseTimer?.invalidate()

        pauseTimer = Timer.scheduledTimer(withTimeInterval: pauseThreshold, repeats: false) { [weak self] _ in
            self?.onTypingPaused()
        }
    }

    private func onTypingPaused() {
        guard !contextBuffer.isEmpty else { return }

        print("⏸️  Typing paused. Context buffer (\(contextBuffer.count) chars): \"\(contextBuffer)\"")
        
        // Trigger AI completion and show in hover
        triggerCompletionForHover()
    }

    private func triggerCompletionForHover() {
        guard let anthropicAPI = anthropicAPI else {
            print("❌ No AnthropicAPI available")
            return
        }

        Task {
            let context = await MainActor.run { getCompletionContext() }
            guard let context = context else {
                print("❌ No context (empty buffer and no Accessibility text)")
                return
            }

            print("🤖 Typing paused - triggering AI completion with context (\(context.count) chars)")

            do {
                let completion = try await anthropicAPI.getCompletion(for: context)
                print("✨ AI Completion: \"\(completion)\"")

                // Add leading space for completion
                let completionWithSpace = " " + completion

                // Show completion in hover window
                await showCompletionInHover(completionWithSpace)
                
                // Store as pending completion
                pendingCompletion = completionWithSpace

            } catch {
                print("❌ AI Completion error: \(error.localizedDescription)")
            }
        }
    }
    
    private func triggerCompletion() {
        guard let anthropicAPI = anthropicAPI else {
            print("❌ No AnthropicAPI available")
            return
        }

        Task {
            let context = await MainActor.run { getCompletionContext() }
            guard let context = context else {
                print("❌ No context (empty buffer and no Accessibility text)")
                return
            }

            print("🤖 Tab pressed - triggering AI completion with context (\(context.count) chars)")

            do {
                let completion = try await anthropicAPI.getCompletion(for: context)
                print("✨ AI Completion: \"\(completion)\"")

                // Insert the completion into the active application
                await insertText(completion)
                
                // Update our buffer to reflect what was typed
                contextBuffer += completion
                print("📝 Updated buffer: \"\(contextBuffer)\"")

            } catch {
                print("❌ AI Completion error: \(error.localizedDescription)")
            }
        }
    }
    
    private func showCompletionInHover(_ completion: String) async {
        await MainActor.run {
            guard let hoverWindow = hoverWindow else { return }
            
            // Try to get text cursor position, fallback to mouse position
            var location: NSPoint
            
            if let cursorLocation = getTextCursorLocation() {
                location = cursorLocation
            } else {
                // Fallback to mouse position
                let mouseLocation = NSEvent.mouseLocation
                let screenHeight = NSScreen.main?.frame.height ?? 1080
                location = NSPoint(x: mouseLocation.x, y: screenHeight - mouseLocation.y)
            }
            
            hoverWindow.showCompletion(completion, at: location)
        }
    }
    
    /// Phase 2: Full text from the current app via Accessibility API.
    /// Uses system-wide focused element first (per Apple docs / public repos), then app-based; searches descendants for AXValue.
    private func getFocusedElementText() -> String? {
        // 1) System-wide focused element
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let sysResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef)
        if sysResult == .success, let ref = focusedRef {
            let element = unsafeBitCast(ref, to: AXUIElement.self)
            if let text = getTextBeforeCursor(from: element, maxDepth: 6), !text.isEmpty {
                return text
            }
        }
        
        // 2) Fallback: focused element from frontmost application
        guard let focusedApp = NSWorkspace.shared.frontmostApplication,
              let pid = focusedApp.processIdentifier as pid_t? else {
            return nil
        }
        var appFocusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            AXUIElementCreateApplication(pid),
            kAXFocusedUIElementAttribute as CFString,
            &appFocusedRef
        ) == .success, let appRef = appFocusedRef else { return nil }
        let appElement = unsafeBitCast(appRef, to: AXUIElement.self)
        if let text = getTextBeforeCursor(from: appElement, maxDepth: 6), !text.isEmpty {
            return text
        }
        return nil
    }
    
    /// Returns text from this element (or a descendant) up to the insertion point only.
    private func getTextBeforeCursor(from element: AXUIElement, maxDepth: Int) -> String? {
        guard maxDepth > 0 else { return nil }
        if let fullText = getAXValueString(from: element), !fullText.isEmpty {
            guard let cursorIndex = getInsertionPointIndex(from: element) else {
                return fullText // No range support – use full text as fallback
            }
            if cursorIndex == 0 {
                return nil // Cursor at start – no context before
            }
            if cursorIndex >= fullText.count {
                return fullText
            }
            return String(fullText.prefix(cursorIndex))
        }
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef,
              let arr = children as? NSArray else {
            return nil
        }
        for i in 0..<arr.count {
            let childRef = arr.object(at: i)
            let child = unsafeBitCast(childRef, to: AXUIElement.self)
            if let text = getTextBeforeCursor(from: child, maxDepth: maxDepth - 1), !text.isEmpty {
                return text
            }
        }
        return nil
    }
    
    /// Insertion point character index (AXSelectedTextRange.location).
    private func getInsertionPointIndex(from element: AXUIElement) -> Int? {
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let ref = rangeRef,
              CFGetTypeID(ref) == AXValueGetTypeID() else {
            return nil
        }
        let axValue = unsafeBitCast(ref, to: AXValue.self)
        var cfRange = CFRange(location: 0, length: 0)
        guard AXValueGetValue(axValue, .cfRange, &cfRange) else {
            return nil
        }
        return cfRange.location
    }
    
    /// Recursively search element and its descendants for kAXValueAttribute (and kAXTitleAttribute fallback); maxDepth avoids infinite recursion.
    private func findAXValueInElement(_ element: AXUIElement, maxDepth: Int) -> String? {
        if maxDepth <= 0 { return nil }
        if let text = getAXValueString(from: element), !text.isEmpty { return text }
        if let text = getAXTitleString(from: element), !text.isEmpty { return text }
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef,
              let arr = children as? NSArray else {
            return nil
        }
        for i in 0..<arr.count {
            let childRef = arr.object(at: i)
            let child = unsafeBitCast(childRef, to: AXUIElement.self)
            if let text = findAXValueInElement(child, maxDepth: maxDepth - 1), !text.isEmpty {
                return text
            }
        }
        return nil
    }
    
    private func getAXValueString(from element: AXUIElement) -> String? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let value = valueRef else {
            return nil
        }
        if CFGetTypeID(value) == CFStringGetTypeID() {
            let str = (value as! CFString) as String
            return str.isEmpty ? nil : str
        }
        if let str = value as? String, !str.isEmpty {
            return str
        }
        return nil
    }
    
    private func getAXTitleString(from element: AXUIElement) -> String? {
        var titleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef) == .success,
              let title = titleRef,
              CFGetTypeID(title) == CFStringGetTypeID() else { return nil }
        let str = (title as! CFString) as String
        return str.isEmpty ? nil : str
    }
    
    /// Context for completion: prefer full text from current app (Accessibility), else typed buffer.
    /// Trims to last maxChars to stay within API limits.
    private func getCompletionContext(maxChars: Int = 4000) -> String? {
        let fromAccessibility = getFocusedElementText()
        let fromBuffer = contextBuffer
        
        let raw: String
        if let ax = fromAccessibility, !ax.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            raw = ax
        } else {
            raw = fromBuffer
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        if raw.count <= maxChars { return raw }
        return String(raw.suffix(maxChars))
    }
    
    private func getTextCursorLocation() -> NSPoint? {
        // Try to get the text insertion point using Accessibility API
        guard let focusedApp = NSWorkspace.shared.frontmostApplication,
              let pid = focusedApp.processIdentifier as pid_t? else {
            return nil
        }
        
        // Get the focused UI element (usually a text field)
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            AXUIElementCreateApplication(pid),
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        guard result == .success, let elementRef = focusedElement else {
            return nil
        }
        
        // Cast CFTypeRef to AXUIElement (AXUIElement is a typealias for CFTypeRef)
        let element = unsafeBitCast(elementRef, to: AXUIElement.self)
        
        // Try to get the insertion point position
        var pointValue: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(
            element,
            kAXInsertionPointLineNumberAttribute as CFString,
            &pointValue
        )
        
        // Get the bounds of the focused element as fallback
        var boundsValue: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &boundsValue
        )
        
        // Get window position
        var windowValue: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &windowValue)
        
        if let windowRef = windowValue {
            // Cast CFTypeRef to AXUIElement
            let window = unsafeBitCast(windowRef, to: AXUIElement.self)
            var positionValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
               let positionRef = positionValue {
                // Cast CFTypeRef to AXValue (AXValue is a typealias for CFTypeRef)
                let position = unsafeBitCast(positionRef, to: AXValue.self)
                var point = CGPoint.zero
                if AXValueGetValue(position, .cgPoint, &point) {
                    // Use window position + offset for text field
                    return NSPoint(x: point.x + 50, y: point.y - 20)
                }
            }
        }
        
        return nil
    }
    
    private func dismissHover() {
        hoverWindow?.hide()
        pendingCompletion = nil
    }
    
    private func acceptPendingCompletion() -> Bool {
        guard let completion = pendingCompletion, let hoverWindow = hoverWindow, hoverWindow.isVisible() else {
            return false
        }
        
        print("✅ Accepting completion: \"\(completion)\"")
        
        Task {
            // Dismiss hover first
            await MainActor.run {
                dismissHover()
            }
            
            // Insert completion (already includes leading space)
            await insertText(completion)
            
            // Update buffer
            contextBuffer += completion
            print("📝 Updated buffer: \"\(contextBuffer)\"")
        }
        
        return true
    }
    
    private func insertText(_ text: String) async {
        // Use the main thread to post keyboard events
        await MainActor.run {
            guard !text.isEmpty else { return }
            
            // Save current pasteboard contents
            let pasteboard = NSPasteboard.general
            let previousContents = pasteboard.string(forType: .string)
            
            // Put the completion text on the pasteboard
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            
            // Simulate Cmd+V (paste) to insert the text
            let source = CGEventSource(stateID: .hidSystemState)
            
            // Cmd key (0x37) and V key (0x09)
            if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
               let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
               let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false),
               let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) {
                
                cmdDown.flags = .maskCommand
                vDown.flags = .maskCommand
                vUp.flags = .maskCommand
                cmdUp.flags = .maskCommand
                
                // Post the events
                cmdDown.post(tap: .cghidEventTap)
                vDown.post(tap: .cghidEventTap)
                vUp.post(tap: .cghidEventTap)
                cmdUp.post(tap: .cghidEventTap)
            }
            
            // Restore previous pasteboard contents after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let previous = previousContents {
                    pasteboard.clearContents()
                    pasteboard.setString(previous, forType: .string)
                }
            }
        }
    }

    func getContextBuffer() -> String {
        return contextBuffer
    }

    func clearContext() {
        contextBuffer = ""
        print("🧹 Context buffer cleared")
    }

    deinit {
        stop()
    }
}


