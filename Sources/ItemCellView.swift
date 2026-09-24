import AppKit

/// 列表行视图：左侧预览块（文本图标或图片缩略图），中间两行文本预览，右侧置顶标记
final class ItemCellView: NSView {
    private let previewBox = NSView()
    private let iconGlyph = NSImageView()
    private let thumbView = NSImageView()
    private let textLabel = NSTextField(wrappingLabelWithString: "")
    private let pinLabel = NSTextField(labelWithString: "📌")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        previewBox.wantsLayer = true
        previewBox.layer?.cornerRadius = 8
        previewBox.layer?.masksToBounds = true
        previewBox.translatesAutoresizingMaskIntoConstraints = false
        addSubview(previewBox)

        iconGlyph.imageScaling = .scaleNone
        iconGlyph.translatesAutoresizingMaskIntoConstraints = false
        previewBox.addSubview(iconGlyph)

        thumbView.imageScaling = .scaleProportionallyUpOrDown
        thumbView.translatesAutoresizingMaskIntoConstraints = false
        previewBox.addSubview(thumbView)

        textLabel.maximumNumberOfLines = 2
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.cell?.truncatesLastVisibleLine = true
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textLabel)

        pinLabel.font = NSFont.systemFont(ofSize: 11)
        pinLabel.translatesAutoresizingMaskIntoConstraints = false
        pinLabel.isHidden = true
        addSubview(pinLabel)

        NSLayoutConstraint.activate([
            previewBox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            previewBox.centerYAnchor.constraint(equalTo: centerYAnchor),
            previewBox.widthAnchor.constraint(equalToConstant: 38),
            previewBox.heightAnchor.constraint(equalToConstant: 38),

            iconGlyph.centerXAnchor.constraint(equalTo: previewBox.centerXAnchor),
            iconGlyph.centerYAnchor.constraint(equalTo: previewBox.centerYAnchor),

            thumbView.leadingAnchor.constraint(equalTo: previewBox.leadingAnchor),
            thumbView.trailingAnchor.constraint(equalTo: previewBox.trailingAnchor),
            thumbView.topAnchor.constraint(equalTo: previewBox.topAnchor),
            thumbView.bottomAnchor.constraint(equalTo: previewBox.bottomAnchor),

            textLabel.leadingAnchor.constraint(equalTo: previewBox.trailingAnchor, constant: 10),
            textLabel.trailingAnchor.constraint(lessThanOrEqualTo: pinLabel.leadingAnchor, constant: -8),
            textLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            pinLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            pinLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: ClipboardItem) {
        previewBox.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        if item.isImage {
            thumbView.image = item.thumb
            iconGlyph.isHidden = true
            thumbView.isHidden = false
            let summary = item.pixelWidth > 0
                ? "图片 · \(item.pixelWidth) × \(item.pixelHeight)"
                : "图片"
            textLabel.attributedStringValue = NSAttributedString(string: summary, attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
        } else {
            thumbView.image = nil
            iconGlyph.isHidden = false
            thumbView.isHidden = true
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            iconGlyph.image = NSImage(systemSymbolName: "doc.plaintext", accessibilityDescription: "文本")?
                .withSymbolConfiguration(config)
            iconGlyph.contentTintColor = .secondaryLabelColor
            textLabel.attributedStringValue = Self.previewText(item.text ?? "")
        }
        pinLabel.isHidden = !item.pinned
    }

    /// 文本预览：第一行正常字号，其余行小号灰字，最多两行
    private static func previewText(_ text: String) -> NSAttributedString {
        let clipped = String(text.prefix(400))
        let lines = clipped.components(separatedBy: "\n")
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: lines.first ?? "", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.labelColor,
        ]))
        let rest = lines.dropFirst().joined(separator: "  ")
        if !rest.isEmpty {
            result.append(NSAttributedString(string: "\n" + rest, attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]))
        }
        return result
    }
}
