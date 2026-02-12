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

    init(anthropicAPI: AnthropicAPI?) {
        self.anthropicAPI = anthropicAPI
    }
        
    func start() {
        guard !isRunning else {
            print("⚠️ Monitor already running")
            return
        }
        
        print("🎯 Starting keyboard monitor...")
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                if type == .keyDown {
                    let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

                    // Tab key (keyCode 48) - trigger completion
                    if keyCode == 48 {
                        print("⌨️  TAB key pressed!")
                        monitor.triggerCompletion()
                        return nil // Consume the tab event so it doesn't get passed through
                    }

                    // For other keys, capture the character and add to buffer
                    monitor.handleKeystroke(event: event)
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
        
        isRunning = true
        print("✅ Keyboard monitor started!")
    }
    
    func stop() {
        guard isRunning else { return }

        pauseTimer?.invalidate()
        pauseTimer = nil

        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let runLoopSource = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            }
        }

        isRunning = false
        print("⏹️  Keyboard monitor stopped")
    }
    
    private func handleKeystroke(event: CGEvent) {
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
        // Here we could trigger AI completion in the future
    }

    private func triggerCompletion() {
        guard let anthropicAPI = anthropicAPI else {
            print("❌ No AnthropicAPI available")
            return
        }

        guard !contextBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ Empty context buffer")
            return
        }

        print("🤖 Tab pressed - triggering AI completion with context: \"\(contextBuffer)\"")

        Task {
            do {
                let completion = try await anthropicAPI.getCompletion(for: contextBuffer)
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
