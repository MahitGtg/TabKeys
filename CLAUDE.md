# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TabKeys is a macOS menu bar application that provides system-wide AI-powered tab completions, similar to Cursor's completion feature. Built in Swift with SwiftUI, it monitors keyboard input across all applications and shows AI-generated completion suggestions that users can accept by pressing Tab.

## Commands

### Building and Running
```bash
cd TabKeys
xcodebuild -scheme TabKeys build                    # Build the project
xcodebuild -scheme TabKeys -configuration Debug build    # Build debug version
xcodebuild -scheme TabKeys -configuration Release build  # Build release version
```

### Testing and Development
```bash
# Open project in Xcode
open TabKeys.xcodeproj

# Build and run from command line
xcodebuild -scheme TabKeys -configuration Debug build
```

## Architecture

### Core Components

- **TabKeysApp.swift**: Main app entry point using SwiftUI App protocol with `@main` attribute
- **AppDelegate**: NSApplicationDelegate that manages:
  - Menu bar status item with keyboard icon
  - App menu with options (About, Restart Monitor, Check Permissions, Quit)
  - Accessibility permissions handling and monitoring
  - KeyboardMonitor lifecycle management

- **KeyboardMonitor.swift**: Core functionality for system-wide keyboard monitoring
  - Uses CGEvent.tapCreate with CGSessionEventTap for global key monitoring
  - Currently monitors Tab key (keyCode 48) for completion triggers
  - Requires Accessibility permissions to function
  - Manages CFMachPort and CFRunLoopSource for event handling

### Key Design Principles

1. **Single Context Window**: The app maintains one global context window that gets reset when the user switches between applications
2. **Application-Aware Completions**: Text context is captured from the currently active application only
3. **Global Accessibility**: Works across all macOS applications that support standard text input

### Technical Implementation Details

1. **Permissions**: App requires Accessibility permissions (declared in Info.plist with NSAccessibilityUsageDescription)
2. **Event Monitoring**: Uses Core Graphics Event Taps for low-level system keyboard monitoring
3. **Menu Bar Integration**: Implements NSStatusItem for menu bar presence
4. **Context Management**: Single shared context buffer that resets on application switches
5. **Future BYOK Support**: Architecture designed to support bring-your-own-key AI service integration

### Project Structure
```
TabKeys/
├── TabKeys.xcodeproj/          # Xcode project file
└── TabKeys/                    # Source code directory
    ├── TabKeysApp.swift        # Main app and AppDelegate
    ├── KeyboardMonitor.swift   # Keyboard monitoring implementation
    └── Info.plist             # App metadata and permissions
```

## Development Notes

- The app uses a hybrid approach: SwiftUI for app structure but AppKit/Cocoa for menu bar and system integration
- Keyboard monitoring requires careful permission handling - the app includes automatic prompts and retry logic
- Currently monitors Tab key presses but architecture supports monitoring any keyboard events for future features
- Event tap uses `headInsertEventTap` placement for early event interception before other apps process events
- Includes proper cleanup in KeyboardMonitor.deinit to prevent resource leaks
- Context window reset on app switching ensures completions remain relevant to current work context