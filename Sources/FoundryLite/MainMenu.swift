import AppKit

enum MainMenu {
    static func build() -> NSMenu {
        let main = NSMenu()
        func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenu {
            let item = NSMenuItem()
            main.addItem(item)
            let menu = NSMenu(title: title)
            items.forEach(menu.addItem)
            item.submenu = menu
            return menu
        }
        func item(_ title: String, _ action: Selector, _ key: String = "",
                  _ mods: NSEvent.ModifierFlags = .command) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
            i.keyEquivalentModifierMask = mods
            return i
        }

        _ = submenu("Foundry Lite", [
            item("Скрыть Foundry Lite", #selector(NSApplication.hide(_:)), "h"),
            item("Скрыть остальные", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
            .separator(),
            item("Выйти", #selector(NSApplication.terminate(_:)), "q"),
        ])
        _ = submenu("Правка", [
            item("Вырезать", #selector(NSText.cut(_:)), "x"),
            item("Копировать", #selector(NSText.copy(_:)), "c"),
            item("Вставить", #selector(NSText.paste(_:)), "v"),
            item("Выделить всё", #selector(NSText.selectAll(_:)), "a"),
        ])
        _ = submenu("Вид", [
            item("Перезагрузить", #selector(GameWindowController.reloadPage(_:)), "r"),
            item("Перезагрузить без кэша", #selector(GameWindowController.reloadPageFromOrigin(_:)), "r", [.command, .shift]),
            .separator(),
            item("Увеличить", #selector(GameWindowController.zoomIn(_:)), "="),
            item("Уменьшить", #selector(GameWindowController.zoomOut(_:)), "-"),
            item("Обычный размер", #selector(GameWindowController.zoomReset(_:)), "0"),
            .separator(),
            item("Полный экран", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control]),
        ])
        let window = submenu("Окно", [
            item("Список серверов", #selector(AppDelegate.showLauncher(_:)), "l"),
            .separator(),
            item("Свернуть", #selector(NSWindow.performMiniaturize(_:)), "m"),
            item("Закрыть", #selector(NSWindow.performClose(_:)), "w"),
        ])
        NSApp.windowsMenu = window
        return main
    }
}
