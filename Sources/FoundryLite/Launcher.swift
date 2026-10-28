import AppKit

/// Список серверов и быстрое подключение по ссылке. Нативный AppKit без веб-движка
final class LauncherWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let store: ServerStore
    private let onConnect: (Server) -> Void
    private let onClose: () -> Void

    private let nameField = NSTextField()
    private let urlField = NSTextField()
    private let table = NSTableView()

    init(store: ServerStore, onConnect: @escaping (Server) -> Void, onClose: @escaping () -> Void) {
        self.store = store
        self.onConnect = onConnect
        self.onClose = onClose
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 440),
                           styleMask: [.titled, .closable, .miniaturizable, .resizable],
                           backing: .buffered, defer: false)
        win.title = "Foundry Lite"
        win.minSize = NSSize(width: 380, height: 360)
        win.center()
        win.setFrameAutosaveName("Launcher")
        super.init(window: win)
        win.delegate = self
        build(in: win)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build(in win: NSWindow) {
        nameField.placeholderString = "Название (необязательно)"
        urlField.placeholderString = "Адрес сервера, например http://192.168.1.10:30000"
        urlField.target = self
        urlField.action = #selector(connect)

        for (id, title) in [("name", "Название"), ("url", "Адрес")] {
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            col.title = title
            col.isEditable = false
            col.width = id == "name" ? 150 : 250
            table.addTableColumn(col)
        }
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(connectSelected)
        table.usesAlternatingRowBackgroundColors = true
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true

        let spacer = NSView()
        spacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        let connectButton = NSButton(title: "Подключиться", target: self, action: #selector(connect))
        connectButton.keyEquivalent = "\r"
        let buttons = NSStackView(views: [
            NSButton(title: "Удалить", target: self, action: #selector(removeSelected)),
            spacer,
            NSButton(title: "Сохранить", target: self, action: #selector(save)),
            connectButton,
        ])

        let stack = NSStackView(views: [nameField, urlField, scroll, buttons])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        win.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: win.contentView!.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: win.contentView!.trailingAnchor),
            stack.topAnchor.constraint(equalTo: win.contentView!.topAnchor),
            stack.bottomAnchor.constraint(equalTo: win.contentView!.bottomAnchor),
        ])
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(urlField)
    }

    func windowWillClose(_ notification: Notification) { onClose() }

    // MARK: - Форма

    private func currentServer() -> Server? {
        guard let url = normalizedURL(urlField.stringValue) else {
            NSSound.beep()
            window?.makeFirstResponder(urlField)
            return nil
        }
        let typed = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return Server(name: typed.isEmpty ? (url.host ?? url.absoluteString) : typed, url: url.absoluteString)
    }

    @objc private func connect() {
        if let server = currentServer() { onConnect(server) }
    }

    @objc private func connectSelected() {
        guard table.clickedRow >= 0 else { return }
        onConnect(store.servers[table.clickedRow])
    }

    @objc private func save() {
        guard let server = currentServer() else { return }
        let row = table.selectedRow
        if row >= 0 {
            store.update(at: row, server)
        } else {
            store.add(server)
        }
        table.reloadData()
        let target = row >= 0 ? row : store.servers.count - 1
        table.selectRowIndexes(IndexSet(integer: target), byExtendingSelection: false)
    }

    @objc private func removeSelected() {
        let row = table.selectedRow
        guard row >= 0 else { return }
        store.remove(at: row)
        table.reloadData()
        nameField.stringValue = ""
        urlField.stringValue = ""
    }

    // MARK: - Таблица

    func numberOfRows(in tableView: NSTableView) -> Int { store.servers.count }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let s = store.servers[row]
        return tableColumn?.identifier.rawValue == "name" ? s.name : s.url
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = table.selectedRow
        guard row >= 0 else { return }
        nameField.stringValue = store.servers[row].name
        urlField.stringValue = store.servers[row].url
    }
}
