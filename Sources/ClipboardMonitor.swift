import AppKit

/// 通过轮询 NSPasteboard.changeCount 监听剪贴板变化。
/// 写回剪贴板的操作会记录 changeCount 并跳过，避免把面板里复制的内容又存一遍。
final class ClipboardMonitor {
    private static let concealedTypes: Set<String> = [
        "org.nspasteboard.ConcealedType", // 密码管理器等标记为隐藏的内容
        "org.nspasteboard.TransientType", // 临时内容（如通用剪贴板中转）
    ]

    private let store: ClipboardStore
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var suppressChangeCount = -1

    init(store: ClipboardStore) {
        self.store = store
    }

    func start() {
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// 把启动时剪贴板里已有的内容收录为第一条
    func captureCurrent() {
        poll(force: true)
    }

    private func poll(force: Bool = false) {
        let pasteboard = NSPasteboard.general
        let count = pasteboard.changeCount
        if !force && count == lastChangeCount { return }
        lastChangeCount = count
        guard count != suppressChangeCount else { return }
        capture(from: pasteboard)
    }

    private func capture(from pasteboard: NSPasteboard) {
        if let types = pasteboard.types,
           types.contains(where: { Self.concealedTypes.contains($0.rawValue) }) {
            return
        }
        // 同时含文本和图片时（如网页复制）优先收录文本
        if let text = pasteboard.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            store.add(text: text)
            return
        }
        var imageData = pasteboard.data(forType: .png)
        if imageData == nil, let tiff = pasteboard.data(forType: .tiff) {
            imageData = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        }
        if let data = imageData {
            store.add(imageData: data)
        }
    }

    /// 把条目写回剪贴板（用户在面板里点击条目时调用）
    func write(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if item.isImage, let data = item.imageData {
            pasteboard.setData(data, forType: .png)
            if let tiff = NSBitmapImageRep(data: data)?.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
        } else if let text = item.text {
            pasteboard.setString(text, forType: .string)
        }
        suppressChangeCount = pasteboard.changeCount
    }
}
