import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ClipboardStore()
    private var monitor: ClipboardMonitor!
    private var panelController: PanelController!
    private var hotKey: HotKey?
    private var statusItem: NSStatusItem!
    private var persistence: HistoryPersistence?
    private var saveTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController = PanelController(store: store)

        // 从磁盘恢复上次的历史，之后数据一变就防抖落盘
        let persistence = HistoryPersistence()
        self.persistence = persistence
        store.replaceAll(persistence.load())
        store.addListener { [weak self] in self?.scheduleSave() }

        monitor = ClipboardMonitor(store: store)
        panelController.onCopy = { [weak self] item in
            self?.monitor.write(item)
        }

        // 全局快捷键 ⌥V（对应 Windows 的 Win+V）
        // 改快捷键示例：⌘⇧V → UInt32(cmdKey | shiftKey)
        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(optionKey)) { [weak self] in
            self?.panelController.toggle()
        }

        setupStatusItem()

        monitor.start()
        monitor.captureCurrent()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        saveNow()
    }

    /// 数据变化后延迟落盘，避免连续复制时频繁写文件
    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.saveNow()
        }
    }

    private func saveNow() {
        persistence?.save(store.items)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "剪贴板历史")
        }
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "打开剪贴板面板", action: #selector(openPanel), keyEquivalent: "v")
        openItem.keyEquivalentModifierMask = [.option]
        let clearItem = NSMenuItem(title: "清空未置顶记录…", action: #selector(clearHistory), keyEquivalent: "")
        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        openItem.target = self
        clearItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())
        menu.addItem(clearItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc private func openPanel() {
        panelController.show()
    }

    @objc private func clearHistory() {
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
}
