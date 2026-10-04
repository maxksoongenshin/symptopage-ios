// Imports the owner's brand files into the asset catalog without redrawing them.
// Usage: swift scripts/import_brand_assets.swift <logo-white.png> <icons.png> <Assets.xcassets>
//   logo-white.png: transparent wordmark with white text (for teal/dark backgrounds)
//   icons.png: two rounded icons side by side on transparency (left: light, right: dark)
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count == 4 else { fatalError("usage: logo-white.png icons.png Assets.xcassets") }
let assets = URL(fileURLWithPath: args[3])

func load(_ path: String) -> NSBitmapImageRep {
  guard let rep = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: path))) else { fatalError("cannot read \(path)") }
  return rep
}
func opaque(_ rep: NSBitmapImageRep, _ x: Int, _ y: Int) -> Bool { (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 }
/// Bounding box (top-left origin) of opaque pixels inside the column range.
func box(_ rep: NSBitmapImageRep, columns: ClosedRange<Int>) -> NSRect {
  var minX = Int.max, maxX = 0, minY = Int.max, maxY = 0
  for y in 0..<rep.pixelsHigh { for x in columns where opaque(rep, x, y) {
    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
  } }
  return NSRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}
func segments(_ rep: NSBitmapImageRep) -> [ClosedRange<Int>] {
  var result: [ClosedRange<Int>] = []
  var start: Int?
  for x in 0..<rep.pixelsWide {
    let used = (0..<rep.pixelsHigh).contains { opaque(rep, x, $0) }
    if used, start == nil { start = x }
    if !used, let s = start { result.append(s...(x - 1)); start = nil }
  }
  if let s = start { result.append(s...(rep.pixelsWide - 1)) }
  return result
}
func crop(_ rep: NSBitmapImageRep, _ r: NSRect, pad: Int = 0) -> CGImage {
  let rect = CGRect(x: max(Int(r.minX) - pad, 0), y: max(Int(r.minY) - pad, 0),
                    width: min(Int(r.width) + 2 * pad, rep.pixelsWide), height: min(Int(r.height) + 2 * pad, rep.pixelsHigh))
  return rep.cgImage!.cropping(to: rect)!
}
func write(_ image: CGImage, _ url: URL) {
  let rep = NSBitmapImageRep(cgImage: image)
  try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
  try! rep.representation(using: .png, properties: [:])!.write(to: url)
  print("wrote \(url.lastPathComponent) \(image.width)×\(image.height)")
}
func imageset(_ name: String, _ file: String) {
  let json = "{\n  \"images\": [\n    {\n      \"filename\": \"\(file)\",\n      \"idiom\": \"universal\"\n    }\n  ],\n  \"info\": {\n    \"author\": \"xcode\",\n    \"version\": 1\n  }\n}\n"
  try! json.write(to: assets.appendingPathComponent("\(name).imageset/Contents.json"), atomically: true, encoding: .utf8)
}

// Icons: left = light, right = dark (used for the app icon).
let icons = load(args[2])
let parts = segments(icons).filter { $0.count > 40 }
guard parts.count == 2 else { fatalError("expected two icons, found \(parts.count)") }
let light = crop(icons, box(icons, columns: parts[0]))
let dark = crop(icons, box(icons, columns: parts[1]))
write(light, assets.appendingPathComponent("BrandIconWhite.imageset/SymptoPage_app_icon_white.png"))
write(dark, assets.appendingPathComponent("BrandIconBlue.imageset/SymptoPage_app_icon_blue.png"))

// Wordmark with white text.
let logo = load(args[1])
let all = segments(logo)
let logoBox = box(logo, columns: all.first!.lowerBound...all.last!.upperBound)
write(crop(logo, logoBox, pad: 6), assets.appendingPathComponent("BrandLogoWhite.imageset/SymptoPage_logo_white.png"))
imageset("BrandLogoWhite", "SymptoPage_logo_white.png")

// App icon: opaque 1024², background = the dark icon's own colour.
let darkRep = NSBitmapImageRep(cgImage: dark)
let bg = darkRep.colorAt(x: darkRep.pixelsWide / 2, y: 8)!.usingColorSpace(.sRGB)!
let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(bg.cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
ctx.interpolationQuality = .high
// Scale past the canvas so the source's own rounded rim is cropped; iOS applies its own mask.
let bleed: CGFloat = 1024 * 1.14
ctx.draw(dark, in: CGRect(x: (1024 - bleed) / 2, y: (1024 - bleed) / 2, width: bleed, height: bleed))
write(ctx.makeImage()!, assets.appendingPathComponent("AppIcon.appiconset/AppIcon.png"))
