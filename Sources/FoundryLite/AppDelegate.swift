import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ServerStore()
    private var launcher: LauncherWindowController!
    private var games: [GameWindowController] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.build()
        launcher = LauncherWindowController(
            store: store,
            onConnect: { [weak self] in self?.open($0) },
            onClose: { [weak self] in if self?.games.isEmpty == true { NSApp.terminate(nil) } }
        )
        launcher.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // Выход вручную: лаунчер скрывается на время игры, и система не должна считать это закрытием
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if games.isEmpty { launcher.showWindow(nil) }
        return true
    }

    @objc func showLauncher(_ sender: Any?) {
        launcher.showWindow(nil)
    }

    private func open(_ server: Server) {
        guard let url = normalizedURL(server.url) else { return }
        let game = GameWindowController(server: server, url: url)
        game.onClose = { [weak self, weak game] in
            guard let self, let game else { return }
            games.removeAll { $0 === game }
            if games.isEmpty { launcher.showWindow(nil) }
        }
        game.onShowLauncher = { [weak self] in self?.launcher.showWindow(nil) }
        games.append(game)
        game.showWindow(nil)
        launcher.window?.orderOut(nil)
    }
}
