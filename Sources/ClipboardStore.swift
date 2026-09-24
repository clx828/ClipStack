import AppKit
import CryptoKit

/// 一条剪贴板记录：文本或图片
struct ClipboardItem {
    let id = UUID()
    let isImage: Bool
    let text: String?
    let imageData: Data?
    let thumb: NSImage?
    let pixelWidth: Int
    let pixelHeight: Int
    let fingerprint: String
    var date = Date()
    var pinned = false

    init(text: String) {
        isImage = false
        self.text = text
        imageData = nil
        thumb = nil
        pixelWidth = 0
        pixelHeight = 0
        fingerprint = ClipboardItem.fingerprint(Data(text.utf8))
    }

    init(imageData: Data) {
        isImage = true
        text = nil
        self.imageData = imageData
        thumb = ClipboardItem.makeThumbnail(from: imageData)
        let rep = NSBitmapImageRep(data: imageData)
        pixelWidth = rep?.pixelsWide ?? 0
        pixelHeight = rep?.pixelsHigh ?? 0
        fingerprint = ClipboardItem.fingerprint(imageData)
    }

    static func fingerprint(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// 生成列表用的小尺寸缩略图，避免每个单元格都持有原始大图
    private static func makeThumbnail(from data: Data) -> NSImage? {
        guard let image = NSImage(data: data) else { return nil }
        let size = image.size
        guard size.width > 1, size.height > 1 else { return nil }
        let maxSide: CGFloat = 160
        let scale = min(maxSide / size.width, maxSide / size.height, 1)
        let target = NSSize(width: (size.width * scale).rounded(),
                            height: (size.height * scale).rounded())
        let thumb = NSImage(size: target)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: target),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy, fraction: 1.0)
        thumb.unlockFocus()
        return thumb
    }
}

/// 剪贴板历史的内存存储。
/// items 始终按"最新在前"排序；展示时置顶条目排在最前。
final class ClipboardStore {
    private(set) var items: [ClipboardItem] = []
    var onUpdate: (() -> Void)?
    var maxItems = 200

    var count: Int { items.count }

    func add(text: String) {
        let item = ClipboardItem(text: text)
        if let index = items.firstIndex(where: { !$0.isImage && $0.text == item.text }) {
            touchExisting(at: index)
        } else {
            items.insert(item, at: 0)
            evictIfNeeded()
            notify()
        }
    }

    func add(imageData: Data) {
        let item = ClipboardItem(imageData: imageData)
        if let index = items.firstIndex(where: { $0.isImage && $0.fingerprint == item.fingerprint }) {
            touchExisting(at: index)
        } else {
            items.insert(item, at: 0)
            evictIfNeeded()
            notify()
        }
    }

    /// 再次复制同一条内容时，把它挪到未置顶区顶部
    private func touchExisting(at index: Int) {
        if items[index].pinned {
            items[index].date = Date()
        } else {
            var item = items.remove(at: index)
            item.date = Date()
            items.insert(item, at: 0)
        }
        notify()
    }

    /// 在面板里选中某条复制后，同样挪到顶部
    func touch(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if !items[index].pinned {
            var item = items.remove(at: index)
            item.date = Date()
            items.insert(item, at: 0)
        } else {
            items[index].date = Date()
        }
        notify()
    }

    func togglePin(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].pinned.toggle()
        notify()
    }

    func delete(id: UUID) {
        items.removeAll { $0.id == id }
        notify()
    }

    /// 清空未置顶记录，置顶条目保留
    func clearAll() {
        items.removeAll { !$0.pinned }
        notify()
    }

    /// 搜索过滤 + 置顶排序后的展示列表
    func displayed(searching query: String) -> [ClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let filtered: [ClipboardItem]
        if trimmed.isEmpty {
            filtered = items
        } else {
            filtered = items.filter { !$0.isImage && $0.text?.localizedCaseInsensitiveContains(trimmed) == true }
        }
        return filtered.enumerated()
            .sorted { a, b in
                if a.element.pinned != b.element.pinned { return a.element.pinned }
                return a.offset < b.offset
            }
            .map { $0.element }
    }

    /// 超出容量时只淘汰最早的未置顶条目
    private func evictIfNeeded() {
        while items.count > maxItems {
            guard let index = items.lastIndex(where: { !$0.pinned }) else { break }
            items.remove(at: index)
        }
    }

    private func notify() {
        onUpdate?()
    }
}
