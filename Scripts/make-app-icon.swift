import AppKit

// ---- Tweak these to recolor the icon, then re-run. ----
let bgTop    = NSColor(red: 0.20, green: 0.20, blue: 0.23, alpha: 1)   // squircle gradient top
let bgBottom = NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)   // squircle gradient bottom
let glyph    = NSColor.white                                            // symbol color
let symbolName = "play.rectangle.on.rectangle"
// -------------------------------------------------------

let canvas: CGFloat = 1024
let outPath = CommandLine.arguments[1]

func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
    let out = NSImage(size: image.size)
    out.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: image.size))
    color.set()
    NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
    out.unlockFocus()
    return out
}

let img = NSImage(size: NSSize(width: canvas, height: canvas))
img.lockFocus()

// Transparent canvas with an inset rounded-rect (squircle) background.
let pad = canvas * 0.085
let bgRect = NSRect(x: pad, y: pad, width: canvas - 2 * pad, height: canvas - 2 * pad)
let radius = bgRect.width * 0.225
let path = NSBezierPath(roundedRect: bgRect, xRadius: radius, yRadius: radius)
NSGradient(starting: bgTop, ending: bgBottom)!.draw(in: path, angle: -90)

// Centered SF Symbol, tinted.
let config = NSImage.SymbolConfiguration(pointSize: canvas * 0.40, weight: .regular)
if let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let symbol = tinted(base, glyph)
    let s = symbol.size
    symbol.draw(in: NSRect(x: (canvas - s.width) / 2, y: (canvas - s.height) / 2,
                           width: s.width, height: s.height))
}

img.unlockFocus()

if let tiff = img.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    try! png.write(to: URL(fileURLWithPath: outPath))
    print("wrote \(outPath)")
}
