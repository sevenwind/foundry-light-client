import AppKit

/// Список серверов и быстрое подключение по ссылке. Нативный AppKit без веб-движка
final class LauncherWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let store: ServerStore
    private let onConnect: (Server) -> Void
    private let onClose: () -> Void

    private let nameField = NSTextField()
    private let urlField = NSTextField()
    private let table = NSTableView()
    private let updateButton = NSButton(title: "Проверить обновления", target: nil, action: nil)

    func setUpdateButton(title: String, enabled: Bool = true) {
        updateButton.title = title
        updateButton.isEnabled = enabled
    }

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
            NSButton(title: "Добавить", target: self, action: #selector(add)),
            NSButton(title: "Сохранить", target: self, action: #selector(save)),
            connectButton,
        ])

        let version = NSTextField(labelWithString: "Версия \(Updater.currentVersion)")
        version.textColor = .secondaryLabelColor
        version.font = .systemFont(ofSize: 11)
        updateButton.bezelStyle = .inline
        updateButton.target = nil
        updateButton.action = #selector(AppDelegate.checkForUpdates(_:))
        let footerSpacer = NSView()
        footerSpacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        let footer = NSStackView(views: [version, footerSpacer, updateButton])

        let stack = NSStackView(views: [nameField, urlField, scroll, buttons, footer])
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
        return Server(name: typed, url: url.absoluteString)
    }

    @objc private func connect() {
        if let server = currentServer() { onConnect(server) }
    }

    @objc private func connectSelected() {
        guard table.clickedRow >= 0 else { return }
        onConnect(store.servers[table.clickedRow])
    }

    /// Обновляет выбранную строку; без выбора добавляет новую
    @objc private func save() {
        guard let server = currentServer() else { return }
        let row = table.selectedRow
        if row >= 0 {
            store.update(at: row, server)
            table.reloadData()
            table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        } else {
            addNew(server)
        }
    }

    /// Всегда создаёт новую запись, не трогая выбранную в списке
    @objc private func add() {
        if let server = currentServer() { addNew(server) }
    }

    private func addNew(_ server: Server) {
        store.add(server)
        table.reloadData()
        table.selectRowIndexes(IndexSet(integer: store.servers.count - 1), byExtendingSelection: false)
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
        return tableColumn?.identifier.rawValue == "name" ? s.displayName : s.url
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = table.selectedRow
        guard row >= 0 else { return }
        nameField.stringValue = store.servers[row].customName ?? ""
        urlField.stringValue = store.servers[row].url
    }
}
