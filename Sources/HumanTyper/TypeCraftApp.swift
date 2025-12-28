import SwiftUI
import AppKit

@main
struct TypeCraftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem!
    private var floatingPanel: FloatingPanel?
    @Published var typerService = TypeCraftService()
    
    // energy efficiency: activity token to prevent/allow App Nap
    private var activityToken: NSObjectProtocol?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            // try to load custom icon from bundle (prefer MenuBarIcon, then AppIcon)
            if let iconPath = Bundle.main.path(forResource: "MenuBarIcon", ofType: "png"),
               let icon = NSImage(contentsOfFile: iconPath) {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = false  // keep original colors, don't adapt to theme
                button.image = icon
            } else if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
               let icon = NSImage(contentsOfFile: iconPath) {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = false  // keep original colors
                button.image = icon
            } else if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "png"),
                      let icon = NSImage(contentsOfFile: iconPath) {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = false  // keep original colors
                button.image = icon
            } else {
                // fallback to system symbol (this one can be template)
                let img = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: "TypeCraft")
                img?.isTemplate = true
                button.image = img
            }
            button.imagePosition = .imageOnly
        }
        
        setupMenu()
        
        checkAccessibilityPermissions()
        
        // enable energy efficiency by default (allow App Nap)
        enableEnergyEfficiency()
        
        // listen for typing state changes to manage energy
        setupEnergyManagement()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        let openItem = NSMenuItem(title: "Open TypeCraft", action: #selector(openPanel), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let accessItem = NSMenuItem(title: "Accessibility Info...", action: #selector(showAccessibilityInfo), keyEquivalent: "")
        accessItem.target = self
        menu.addItem(accessItem)
        
        let openSettingsItem = NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        openSettingsItem.target = self
        menu.addItem(openSettingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit TypeCraft", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    private func setupEnergyManagement() {
        typerService.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .typing, .waitingForClicks:
                    // disable App Nap while actively typing or waiting
                    self?.disableEnergyEfficiency()
                case .idle, .paused:
                    // re-enable App Nap when idle
                    self?.enableEnergyEfficiency()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func enableEnergyEfficiency() {
        // end any existing activity
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
        // app Nap is now allowed - system can throttle the app when not visible
    }
    
    private func disableEnergyEfficiency() {
        // prevent App Nap while typing for consistent performance
        guard activityToken == nil else { return }
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical],
            reason: "TypeCraft is actively typing"
        )
    }
    
    @objc func openPanel() {
        if floatingPanel == nil {
            floatingPanel = FloatingPanel(typerService: typerService)
        }
        
        floatingPanel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func showAccessibilityInfo() {
        let trusted = AXIsProcessTrusted()
        let bundlePath = Bundle.main.bundlePath
        let execPath = Bundle.main.executablePath ?? "unknown"
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        let pid = ProcessInfo.processInfo.processIdentifier
        
        let alert = NSAlert()
        alert.messageText = trusted ? "✅ Accessibility Granted" : "❌ Accessibility NOT Granted"
        alert.informativeText = """
        Process ID: \(pid)
        Bundle ID: \(bundleId)
        
        App Path:
        \(bundlePath)
        
        Executable:
        \(execPath)
        
        To fix permissions:
        1. Open System Settings → Privacy & Security → Accessibility
        2. Remove ALL "TypeCraft" entries
        3. Click + and add THIS app
        4. Quit and relaunch this app
        
        Or click "Request Permission" to trigger the prompt.
        """
        alert.alertStyle = trusted ? .informational : .warning
        alert.addButton(withTitle: "Request Permission")
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Copy Path")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            requestAccessibilityPermission()
        } else if response == .alertSecondButtonReturn {
            openAccessibilitySettings()
        } else if response == .alertThirdButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(bundlePath, forType: .string)
        }
    }
    
    @objc func requestAccessibilityPermission() {
        // force the system prompt by requesting with prompt option
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if trusted {
            let alert = NSAlert()
            alert.messageText = "✅ Permission Granted!"
            alert.informativeText = "Accessibility is now enabled. You can start typing."
            alert.runModal()
        }
    }
    
    @objc func quitApp() {
        // clean up energy management
        enableEnergyEfficiency()
        typerService.stop()
        NSApp.terminate(nil)
    }
    
    func checkAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if !trusted {
            print("⚠️ Accessibility permissions required. Please enable in System Preferences > Privacy & Security > Accessibility")
        }
    }
    
    // clean up on termination
    func applicationWillTerminate(_ notification: Notification) {
        enableEnergyEfficiency()
        typerService.stop()
    }
}

import Combine
