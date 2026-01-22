import Cocoa
import ApplicationServices

class KeyboardMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false
        
    func start() {
        guard !isRunning else {
            print("⚠️ Monitor already running")
            return
        }
        
        print("🎯 Starting keyboard monitor...")
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                if type == .keyDown {
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    
                    // Just check for Tab (keyCode 48)
                    if keyCode == 48 {
                        print("⌨️  TAB key pressed!")
                    }
                }
                        
                return Unmanaged.passRetained(event)
            },
            userInfo: nil
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
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let runLoopSource = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            }
        }
        
        isRunning = false
        print("⏹️  Keyboard monitor stopped")
    }
    
    deinit {
        stop()
    }
}
