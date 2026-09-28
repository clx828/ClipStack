// ClipStack 应用图标生成脚本
// 用法: swift Scripts/make_icon.swift <输出iconset目录>
// 绘制 1024x1024 母版：蓝色渐变圆角底 + 三张堆叠卡片 + 顶部夹子 + 文本行，
// 再缩放出 iconset 要求的全部尺寸，最后由 iconutil -c icns 打包。
import AppKit

guard CommandLine.arguments.count > 1 else {
    print("用法: swift Scripts/make_icon.swift <输出iconset目录>")
    exit(1)
}
let outDir = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let master = NSImage(size: NSSize(width: 1024, height: 1024))
master.lockFocus()

// ---- 背景：带阴影的圆角方块 + 上下渐变 ----
let bgRect = NSRect(x: 64, y: 64, width: 896, height: 896)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 200, yRadius: 200)
NSGraphicsContext.saveGraphicsState()
let bgShadow = NSShadow()
bgShadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
bgShadow.shadowBlurRadius = 56
bgShadow.shadowOffset = NSSize(width: 0, height: -22)
bgShadow.set()
NSColor(calibratedRed: 0.23, green: 0.36, blue: 0.86, alpha: 1).setFill()
bgPath.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: NSColor(calibratedRed: 0.23, green: 0.36, blue: 0.86, alpha: 1),
           ending: NSColor(calibratedRed: 0.38, green: 0.51, blue: 0.98, alpha: 1))?
    .draw(in: bgPath, angle: 90)

// ---- 三张堆叠卡片（越靠后越淡，向左上错开）----
let cardRect = NSRect(x: 232, y: 232, width: 560, height: 600)
let cardRadius: CGFloat = 36
let stackOffsets: [(dx: CGFloat, dy: CGFloat, alpha: CGFloat)] = [(-44, 44, 0.22), (-22, 22, 0.45)]
for offset in stackOffsets {
    let path = NSBezierPath(roundedRect: cardRect.offsetBy(dx: offset.dx, dy: offset.dy),
                            xRadius: cardRadius, yRadius: cardRadius)
    NSColor.white.withAlphaComponent(offset.alpha).setFill()
    path.fill()
}

// ---- 前卡片（带阴影的白色主体）----
let frontPath = NSBezierPath(roundedRect: cardRect, xRadius: cardRadius, yRadius: cardRadius)
NSGraphicsContext.saveGraphicsState()
let cardShadow = NSShadow()
cardShadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
cardShadow.shadowBlurRadius = 34
cardShadow.shadowOffset = NSSize(width: 0, height: -12)
cardShadow.set()
NSColor.white.setFill()
frontPath.fill()
NSGraphicsContext.restoreGraphicsState()

// ---- 文本行：一条强调色 + 三条灰条 ----
let lineX = cardRect.minX + 70
let lineWidth = cardRect.width - 140
let lineRects: [(rect: NSRect, color: NSColor)] = [
    (NSRect(x: lineX, y: 636, width: lineWidth * 0.55, height: 42),
     NSColor(calibratedRed: 0.26, green: 0.39, blue: 0.92, alpha: 1)),
    (NSRect(x: lineX, y: 520, width: lineWidth, height: 42), NSColor(calibratedRed: 0.85, green: 0.88, blue: 0.94, alpha: 1)),
    (NSRect(x: lineX, y: 404, width: lineWidth * 0.85, height: 42), NSColor(calibratedRed: 0.85, green: 0.88, blue: 0.94, alpha: 1)),
    (NSRect(x: lineX, y: 288, width: lineWidth * 0.7, height: 42), NSColor(calibratedRed: 0.85, green: 0.88, blue: 0.94, alpha: 1)),
]
for (rect, color) in lineRects {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2).fill()
}

// ---- 顶部夹子：银色渐变小方块，压在卡片上沿 ----
let clipRect = NSRect(x: cardRect.midX - 105, y: cardRect.maxY - 46, width: 210, height: 96)
let clipPath = NSBezierPath(roundedRect: clipRect, xRadius: 26, yRadius: 26)
NSGraphicsContext.saveGraphicsState()
let clipShadow = NSShadow()
clipShadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
clipShadow.shadowBlurRadius = 18
clipShadow.shadowOffset = NSSize(width: 0, height: -6)
clipShadow.set()
NSGradient(starting: NSColor(calibratedRed: 0.96, green: 0.97, blue: 1.0, alpha: 1),
           ending: NSColor(calibratedRed: 0.68, green: 0.72, blue: 0.82, alpha: 1))?
    .draw(in: clipPath, angle: 90)
NSGraphicsContext.restoreGraphicsState()
NSColor(calibratedRed: 0.52, green: 0.56, blue: 0.66, alpha: 1).setStroke()
clipPath.lineWidth = 6
clipPath.stroke()
// 夹子中间的开槽
NSColor(calibratedRed: 0.45, green: 0.49, blue: 0.60, alpha: 1).setFill()
let slot = NSRect(x: clipRect.midX - 55, y: clipRect.maxY - 40, width: 110, height: 20)
NSBezierPath(roundedRect: slot, xRadius: 10, yRadius: 10).fill()

master.unlockFocus()

// ---- 缩放输出 iconset 全部尺寸 ----
func writePNG(_ pixel: Int, name: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixel, pixelsHigh: pixel,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    master.draw(in: NSRect(x: 0, y: 0, width: pixel, height: pixel))
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: outDir + "/" + name))
}

for base in [16, 32, 128, 256, 512] {
    writePNG(base, name: "icon_\(base)x\(base).png")
    writePNG(base * 2, name: "icon_\(base)x\(base)@2x.png")
}
print("iconset 已生成: \(outDir)")
