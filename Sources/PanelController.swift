import AppKit
import Carbon.HIToolbox

/// 无边框浮动面板；默认 NSPanel 无法成为 key window，必须重写 canBecomeKey
final class Panel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Win+V 风格的剪贴板历史面板：搜索框 + 记录列表 + 底部工具栏
final class PanelController: NSObject {
    private enum Layout {
        static let panelWidth: CGFloat = 560
        static let panelHeight: CGFloat = 460
        static let rowHeight: CGFloat = 56
    }

    private let store: ClipboardStore
    private let panel: Panel
    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private let emptyLabel = NSTextField(wrappingLabelWithString: "")
    private let countLabel = NSTextField(labelWithString: "")
    private var displayItems: [ClipboardItem] = []
    private var keyMonitor: Any?

    /// 用户在面板中选中条目时回调（由 AppDelegate 写回剪贴板）
    var onCopy: ((ClipboardItem) -> Void)?

    init(store: ClipboardStore) {
        self.store = store
        panel = Panel(contentRect: NSRect(x: 0, y: 0, width: Layout.panelWidth, height: Layout.panelHeight),
                      styleMask: [.borderless, .nonactivatingPanel],
                      backing: .buffered, defer: true)
        super.init()
        configurePanel()
        installKeyMonitor()
        store.onUpdate = { [weak self] in self?.refresh() }
    }

    deinit {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        if panel.isVisible { hide() } else { show() }
    }

    // MARK: - 显示 / 隐藏

    func show() {
        guard !panel.isVisible else { return }
        searchField.stringValue = ""
        refresh()
        positionPanel()
        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        _ = panel.makeFirstResponder(searchField)
        if !displayItems.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: { [panel] in
            panel.orderOut(nil)
        })
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.midY - size.height / 2 + visible.height * 0.05
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - UI 构建

    private func configurePanel() {
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let effect = NSVisualEffectView(frame: panel.frame)
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true
        effect.layer?.borderWidth = 1
        effect.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.25).cgColor
        panel.contentView = effect

        searchField.placeholderString = "搜索剪贴板内容"
        searchField.delegate = self
        effect.addSubview(searchField)

        let separator = NSBox()
        separator.boxType = .separator
        effect.addSubview(separator)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = Layout.rowHeight
        tableView.style = .sourceList
        tableView.backgroundColor = .clear
        tableView.allowsMultipleSelection = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(rowClicked(_:))
        tableView.menu = makeContextMenu()

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        effect.addSubview(scroll)

        emptyLabel.alignment = .center
        emptyLabel.textColor = .secondaryLabelColor
        effect.addSubview(emptyLabel)

        let clearButton = NSButton(title: "清空未置顶", target: self, action: #selector(clearAllClicked(_:)))
        clearButton.bezelStyle = .rounded
        clearButton.controlSize = .small
        clearButton.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        effect.addSubview(clearButton)

        let hintLabel = NSTextField(labelWithString: "↑↓ 选择 · ⏎ 复制 · ⌘⌫ 删除 · Esc 关闭")
        hintLabel.font = NSFont.systemFont(ofSize: 10)
        hintLabel.textColor = .tertiaryLabelColor
        effect.addSubview(hintLabel)

        countLabel.font = NSFont.systemFont(ofSize: 10)
        countLabel.textColor = .tertiaryLabelColor
        countLabel.alignment = .right
        effect.addSubview(countLabel)

        for view in [searchField, separator, scroll, emptyLabel, clearButton, hintLabel, countLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: effect.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 14),
            searchField.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -14),
            searchField.heightAnchor.constraint(equalToConstant: 30),

            separator.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            separator.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 14),
            separator.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -14),

            scroll.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 6),
            scroll.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -8),
            scroll.bottomAnchor.constraint(equalTo: clearButton.topAnchor, constant: -8),

            emptyLabel.centerXAnchor.constraint(equalTo: effect.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: effect.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: effect.trailingAnchor, constant: -24),

            clearButton.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 14),
            clearButton.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -10),

            hintLabel.centerXAnchor.constraint(equalTo: effect.centerXAnchor),
            hintLabel.centerYAnchor.constraint(equalTo: clearButton.centerYAnchor),

            countLabel.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -14),
            countLabel.centerYAnchor.constraint(equalTo: clearButton.centerYAnchor),
        ])
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        return menu
    }

    // MARK: - 键盘操作

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible, self.panel.isKeyWindow else { return event }
            return self.handleKeyDown(event)
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch event.keyCode {
        case UInt16(kVK_Escape):
            hide()
            return nil
        case UInt16(kVK_DownArrow):
            moveSelection(1)
            return nil
        case UInt16(kVK_UpArrow):
            moveSelection(-1)
            return nil
        case UInt16(kVK_Return), UInt16(kVK_ANSI_KeypadEnter):
            copySelected()
            return nil
        case UInt16(kVK_Delete):
            if flags.contains(.command) {
                deleteSelected()
                return nil
            }
            return event
        case UInt16(kVK_ANSI_F):
            if flags == .command {
                _ = panel.makeFirstResponder(searchField)
                searchField.currentEditor()?.selectAll(nil)
                return nil
            }
            return event
        default:
            return event
        }
    }

    private func moveSelection(_ delta: Int) {
        guard !displayItems.isEmpty else { return }
        let current = tableView.selectedRow
        let next: Int
        if current < 0 {
            next = delta > 0 ? 0 : displayItems.count - 1
        } else {
            next = min(max(current + delta, 0), displayItems.count - 1)
        }
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    private func copySelected() {
        let row = tableView.selectedRow
        guard row >= 0, row < displayItems.count else { return }
        copyToPasteboard(displayItems[row])
    }

    private func deleteSelected() {
        let row = tableView.selectedRow
        guard row >= 0, row < displayItems.count else { return }
        let id = displayItems[row].id
        store.delete(id: id)
        if !displayItems.isEmpty {
            let next = min(row, displayItems.count - 1)
            tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
            tableView.scrollRowToVisible(next)
        }
    }

    private func copyToPasteboard(_ item: ClipboardItem) {
        onCopy?(item)
        store.touch(id: item.id)
        hide()
    }

    // MARK: - 数据刷新

    private func refresh() {
        displayItems = store.displayed(searching: searchField.stringValue)
        tableView.reloadData()
        countLabel.stringValue = "\(store.count) 条记录"
        if store.count == 0 {
            emptyLabel.stringValue = "暂无剪贴板内容\n复制文字或图片后，会自动出现在这里"
        } else if displayItems.isEmpty {
            emptyLabel.stringValue = "没有与「\(searchField.stringValue)」匹配的结果"
        } else {
            emptyLabel.stringValue = ""
        }
        emptyLabel.isHidden = !displayItems.isEmpty
    }

    // MARK: - 动作

    @objc private func rowClicked(_ sender: NSTableView) {
        let row = sender.clickedRow
        guard row >= 0, row < displayItems.count else { return }
        copyToPasteboard(displayItems[row])
    }

    @objc private func clearAllClicked(_ sender: NSButton) {
        confirmClear()
    }

    private func confirmClear() {
        let alert = NSAlert()
        alert.messageText = "清空未置顶记录？"
        alert.informativeText = "所有未置顶的剪贴板记录将被删除，置顶条目会保留。"
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            store.clearAll()
        }
    }

    @objc private func pinClicked(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? NSUUID else { return }
        store.togglePin(id: uuid as UUID)
    }

    @objc private func deleteClicked(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? NSUUID else { return }
        store.delete(id: uuid as UUID)
    }
}

// MARK: - 窗口 / 搜索框 / 列表

extension PanelController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}

extension PanelController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        refresh()
    }
}

extension PanelController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        displayItems.count
    }
}

extension PanelController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("ItemCellView")
        let cell = (tableView.makeView(withIdentifier: identifier, owner: self) as? ItemCellView)
            ?? ItemCellView(frame: .zero)
        cell.identifier = identifier
        cell.configure(with: displayItems[row])
        return cell
    }
}

// MARK: - 右键菜单

extension PanelController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let row = tableView.clickedRow
        guard row >= 0, row < displayItems.count else {
            let placeholder = NSMenuItem(title: "右键点击某条记录进行操作", action: nil, keyEquivalent: "")
            placeholder.isEnabled = false
            menu.addItem(placeholder)
            return
        }
        let item = displayItems[row]
        let pin = NSMenuItem(title: item.pinned ? "取消置顶" : "置顶",
                             action: #selector(pinClicked(_:)), keyEquivalent: "")
        pin.target = self
        pin.representedObject = NSUUID(uuidString: item.id.uuidString)
        let delete = NSMenuItem(title: "删除此条",
                                action: #selector(deleteClicked(_:)), keyEquivalent: "")
        delete.target = self
        delete.representedObject = NSUUID(uuidString: item.id.uuidString)
        let clear = NSMenuItem(title: "清空未置顶记录…",
                               action: #selector(clearAllClicked(_:)), keyEquivalent: "")
        clear.target = self
        menu.addItem(pin)
        menu.addItem(delete)
        menu.addItem(.separator())
        menu.addItem(clear)
    }
}
