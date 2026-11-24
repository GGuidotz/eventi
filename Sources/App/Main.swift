// Avvio AppKit: finestra classica nel Dock, menu essenziale, trascinamento di file sull'icona.

import AppKit
import SwiftUI

@main
enum EventiMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let raw = UserDefaults.standard.string(forKey: "appLanguage"), let l = AppLanguage(rawValue: raw) {
            Localization.language = l
        }
        buildMenu()
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 680),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        w.title = "Eventi"
        w.contentView = NSHostingView(rootView: MainView())
        w.setFrameAutosaveName("EventiMain")
        w.center()
        w.makeKeyAndOrderFront(nil)
        window = w
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func application(_ sender: NSApplication, open urls: [URL]) {
        Task { @MainActor in AppModel.shared.add(urls: urls) }
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: NSRect(origin: .zero, size: SettingsView.size),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = L("Impostazioni")
            w.contentView = NSHostingView(rootView: SettingsView())
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func openFile() {
        let p = NSOpenPanel()
        p.allowsMultipleSelection = true
        if p.runModal() == .OK { Task { @MainActor in AppModel.shared.add(urls: p.urls) } }
    }

    private func buildMenu() {
        let main = NSMenu()
        func item(_ title: String, _ action: Selector?, _ key: String = "", target: AnyObject? = nil) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
            i.target = target
            return i
        }
        func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
            let m = NSMenu(title: title); items.forEach { m.addItem($0) }
            let i = NSMenuItem(title: title, action: nil, keyEquivalent: ""); i.submenu = m; return i
        }
        main.addItem(submenu("Eventi", [
            item(L("Informazioni su Eventi"), #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
            .separator(),
            item(L("Impostazioni…"), #selector(showSettings), ",", target: self),
            .separator(),
            item(L("Esci da Eventi"), #selector(NSApplication.terminate(_:)), "q"),
        ]))
        main.addItem(submenu(L("File"), [
            item(L("Apri…"), #selector(openFile), "o", target: self),
            item(L("Chiudi"), #selector(NSWindow.performClose(_:)), "w"),
        ]))
        main.addItem(submenu(L("Modifica"), [
            item(L("Annulla"), Selector(("undo:")), "z"),
            item(L("Ripeti"), Selector(("redo:")), "Z"),
            .separator(),
            item(L("Taglia"), #selector(NSText.cut(_:)), "x"),
            item(L("Copia"), #selector(NSText.copy(_:)), "c"),
            item(L("Incolla"), #selector(NSText.paste(_:)), "v"),
            item(L("Seleziona tutto"), #selector(NSText.selectAll(_:)), "a"),
        ]))
        NSApp.mainMenu = main
    }
}
