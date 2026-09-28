import AppKit

/// 历史记录持久化：
/// - 元数据: ~/Library/Application Support/ClipStack/history.json（文本、置顶、时间）
/// - 图片:   ~/Library/Application Support/ClipStack/images/<内容指纹>.png
/// 图片按指纹命名，同一张图去重后天然只有一个文件；加载时校验指纹防止文件损坏混入。
final class HistoryPersistence {
    struct PersistedItem: Codable {
        let isImage: Bool
        let text: String?
        let fingerprint: String
        let pixelWidth: Int
        let pixelHeight: Int
        let date: Date
        let pinned: Bool
    }

    struct HistoryFile: Codable {
        let version: Int
        let items: [PersistedItem]
    }

    private let dir: URL
    private let imagesDir: URL
    private let fileURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        dir = support.appendingPathComponent("ClipStack", isDirectory: true)
        imagesDir = dir.appendingPathComponent("images", isDirectory: true)
        fileURL = dir.appendingPathComponent("history.json")
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
    }

    func load() -> [ClipboardItem] {
        guard let data = try? Data(contentsOf: fileURL),
              let file = try? JSONDecoder().decode(HistoryFile.self, from: data) else { return [] }
        var items: [ClipboardItem] = []
        for persisted in file.items {
            if persisted.isImage {
                let url = imagesDir.appendingPathComponent(persisted.fingerprint + ".png")
                guard let imageData = try? Data(contentsOf: url),
                      ClipboardItem.fingerprint(imageData) == persisted.fingerprint else { continue }
                var item = ClipboardItem(imageData: imageData)
                item.date = persisted.date
                item.pinned = persisted.pinned
                items.append(item)
            } else {
                guard let text = persisted.text else { continue }
                var item = ClipboardItem(text: text)
                item.date = persisted.date
                item.pinned = persisted.pinned
                items.append(item)
            }
        }
        return items
    }

    func save(_ items: [ClipboardItem]) {
        let persisted = items.map { item in
            PersistedItem(isImage: item.isImage,
                          text: item.text,
                          fingerprint: item.fingerprint,
                          pixelWidth: item.pixelWidth,
                          pixelHeight: item.pixelHeight,
                          date: item.date,
                          pinned: item.pinned)
        }
        guard let data = try? JSONEncoder().encode(HistoryFile(version: 1, items: persisted)) else { return }
        try? data.write(to: fileURL, options: .atomic)

        // 新图片落盘；顺带清理已不在历史里的孤儿图片文件
        let live = Set(items.filter(\.isImage).map(\.fingerprint))
        for item in items where item.isImage {
            let url = imagesDir.appendingPathComponent(item.fingerprint + ".png")
            if !FileManager.default.fileExists(atPath: url.path), let imageData = item.imageData {
                try? imageData.write(to: url, options: .atomic)
            }
        }
        if let files = try? FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil) {
            for url in files where url.pathExtension == "png" {
                if !live.contains(url.deletingPathExtension().lastPathComponent) {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }
}
