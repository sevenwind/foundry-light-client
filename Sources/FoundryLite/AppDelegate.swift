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
        checkForUpdates(nil, silent: true)
    }

    // Выход вручную: лаунчер скрывается на время игры, и система не должна считать это закрытием
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if games.isEmpty { launcher.showWindow(nil) }
        return true
    }

    @objc func checkForUpdates(_ sender: Any?) { checkForUpdates(sender, silent: false) }

    /// silent: при запуске молчим, если обновлений нет или нет сети
    private func checkForUpdates(_ sender: Any?, silent: Bool) {
        launcher.setUpdateButton(title: "Проверка…", enabled: false)
        Updater.fetchLatest { [weak self] result in
            guard let self else { return }
            launcher.setUpdateButton(title: "Проверить обновления")
            switch result {
            case .success(let release?) where Updater.isNewer(release.version, than: Updater.currentVersion):
                offerUpdate(release)
            case .success:
                if !silent { info("Установлена последняя версия", "Foundry Lite \(Updater.currentVersion)") }
            case .failure(let error):
                if !silent { info("Не удалось проверить обновления", error.localizedDescription) }
            }
        }
    }

    private func offerUpdate(_ release: Release) {
        let alert = NSAlert()
        alert.messageText = "Доступна новая версия \(release.version)"
        alert.informativeText = "Установлена версия \(Updater.currentVersion). Приложение скачает обновление, перезапустится и откроется уже новым."
        alert.addButton(withTitle: "Обновить")
        alert.addButton(withTitle: "Позже")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        launcher.setUpdateButton(title: "Загрузка…", enabled: false)
        Updater.install(release) { [weak self] error in
            self?.launcher.setUpdateButton(title: "Проверить обновления")
            if let error {
                self?.info("Не удалось обновиться", error.localizedDescription)
                NSWorkspace.shared.open(release.pageURL)
            }
        }
    }

    private func info(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
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
