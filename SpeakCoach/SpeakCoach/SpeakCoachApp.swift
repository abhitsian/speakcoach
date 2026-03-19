//
//  SpeakCoachApp.swift
//  SpeakCoach
//
//
//

import SwiftUI

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let openAbout = Notification.Name("openAbout")
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        let launchedByURL: Bool
        if let event = NSAppleEventManager.shared().currentAppleEvent {
            launchedByURL = event.eventClass == kInternetEventClass
        } else {
            launchedByURL = false
        }
        if launchedByURL {
            SpeakCoachService.shared.launchedExternally = true
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = SpeakCoachService.shared
        NSUpdateDynamicServices()

        if SpeakCoachService.shared.launchedExternally {
            SpeakCoachService.shared.hideMainWindow()
        }

        // Silent update check on launch
        UpdateChecker.shared.checkForUpdates(silent: true)

        // Start browser server if enabled
        SpeakCoachService.shared.updateBrowserServer()

        // Set window delegate to intercept close, disable tabs and fullscreen
        DispatchQueue.main.async {
            for window in NSApp.windows where !(window is NSPanel) {
                window.delegate = self
                window.tabbingMode = .disallowed
                window.collectionBehavior.remove(.fullScreenPrimary)
                window.collectionBehavior.insert(.fullScreenNone)
                window.isMovableByWindowBackground = true
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                // Ensure the window is resizable
                window.styleMask.insert(.resizable)
                window.styleMask.insert(.miniaturizable)
                window.styleMask.insert(.closable)
                window.styleMask.insert(.titled)
                window.minSize = NSSize(width: 600, height: 400)
            }
            self.removeUnwantedMenus()
        }
    }

    private func removeUnwantedMenus() {
        guard let mainMenu = NSApp.mainMenu else { return }
        // Remove View and Window menus (keep Edit for copy/paste)
        let menusToRemove = ["View", "Window"]
        for title in menusToRemove {
            if let index = mainMenu.items.firstIndex(where: { $0.title == title }) {
                mainMenu.removeItem(at: index)
            }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide the window instead of closing it
        sender.orderOut(nil)
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if SpeakCoachService.shared.launchedExternally {
            SpeakCoachService.shared.launchedExternally = false
            NSApp.setActivationPolicy(.regular)
        }
        if !flag {
            // Show existing window instead of letting SwiftUI create a duplicate
            for window in NSApp.windows where !(window is NSPanel) {
                window.makeKeyAndOrderFront(nil)
                return false
            }
        }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.pathExtension == "speakcoach" {
                SpeakCoachService.shared.openFileAtURL(url)
                // Show the main window for file opens
                for window in NSApp.windows where !(window is NSPanel) {
                    window.makeKeyAndOrderFront(nil)
                }
                NSApp.activate(ignoringOtherApps: true)
            } else {
                let wasExternal = SpeakCoachService.shared.launchedExternally
                SpeakCoachService.shared.launchedExternally = true
                if !wasExternal {
                    NSApp.setActivationPolicy(.accessory)
                }
                SpeakCoachService.shared.hideMainWindow()
                SpeakCoachService.shared.handleURL(url)
            }
        }
    }
}

@main
struct SpeakCoachApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if url.pathExtension == "speakcoach" {
                        SpeakCoachService.shared.openFileAtURL(url)
                    } else {
                        SpeakCoachService.shared.handleURL(url)
                    }
                }
        }
        .windowResizability(.contentMinSize)

        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About SpeakCoach") {
                    NotificationCenter.default.post(name: .openAbout, object: nil)
                }
                Divider()
                Button("Check for Updates…") {
                    UpdateChecker.shared.checkForUpdates()
                }
            }
            CommandGroup(after: .appSettings) {
                Button("Settings…") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {
                Button("Open…") {
                    SpeakCoachService.shared.openFile()
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Save") {
                    SpeakCoachService.shared.saveFile()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Save As…") {
                    SpeakCoachService.shared.saveFileAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()

                Button("Save to Library…") {
                    SpeakCoachService.shared.saveToLibrary()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .windowArrangement) { }
            CommandGroup(replacing: .help) {
                Button("SpeakCoach Help") {
                    if let url = URL(string: "https://github.com/abhitsian/speakcoach") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
