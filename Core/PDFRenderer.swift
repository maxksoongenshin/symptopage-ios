import CoreGraphics
import CoreText
import Foundation
import ImageIO

/// A4 report in the app's visual language: teal header band, summary tiles, symptom table,
/// daily-answer strip, then paginated text sections with running headers and page numbers.
/// Text is drawn with CoreText, so it stays selectable and searchable in the PDF.
public enum PDFRenderer {
  public enum Weight: String { case regular = "Regular", semibold = "SemiBold", bold = "Bold", heavy = "ExtraBold" }

  /// Manrope when the app registered it, otherwise Helvetica.
  public static func font(_ size: CGFloat, _ weight: Weight = .regular) -> CTFont {
    let name = "Manrope-" + weight.rawValue
    let font = CTFontCreateWithName(name as CFString, size, nil)
    if CTFontCopyPostScriptName(font) as String == name { return font }
    return CTFontCreateWithName(
      (weight == .regular ? "Helvetica" : "Helvetica-Bold") as CFString, size, nil)
  }

  static let page = CGSize(width: 595, height: 842)
  static let margin: CGFloat = 40
  static let teal = rgb(0x167374), ink = rgb(0x0F2A2E), muted = rgb(0x4A5F62)
  static let soft = rgb(0xDDF3F0), chip = rgb(0xCDEDE9), line = rgb(0xE3EEEC)
  static let navy = rgb(0x022E58)
  static let amber = rgb(0xF2B544), red = rgb(0xD32F2F), white = CGColor(gray: 1, alpha: 1)

  /// A graphic block placed by the layout pass; `draw` receives the block's top edge.
  struct Block {
    var height: CGFloat
    var draw: (CGContext, CGFloat) -> Void
  }

  public static func make(
    _ sections: [ReportSection], summary: ReportSummary? = nil, logo: Data? = nil, wordmark: Data? = nil
  ) throws -> Data {
    let drawnSymptoms = summary.map { !$0.symptoms.isEmpty } ?? false
    let drawnHealth = summary?.health != nil
    let visible = sections.filter { section in
      guard summary != nil else { return true }
      if section.kind == .header { return false }
      if section.kind == .symptoms && drawnSymptoms { return false }
      if section.kind == .health && drawnHealth { return false }
      return true
    }
    let (text, headings) = attributed(visible)
    let data = NSMutableData()
    guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
      throw DataError.invalid
    }
    var box = CGRect(origin: .zero, size: page)
    guard let context = CGContext(consumer: consumer, mediaBox: &box, nil) else {
      throw DataError.invalid
    }
    let subtitle =
      sections.first { $0.kind == .header }?.title.replacingOccurrences(of: "SymptoPage · ", with: "")
      ?? ""
    let firstTop = summary == nil ? page.height - margin : page.height - bandHeight - 18
    let laterTop = page.height - margin - (summary == nil ? 0 : 26)
    let bottom: CGFloat = 52

    // Pass 1a: place graphic blocks, moving to a new page when one does not fit.
    var placed: [(page: Int, top: CGFloat, block: Block)] = []
    var pageIndex = 0
    var y = firstTop
    for block in summary.map(blocks) ?? [] {
      if y - block.height < bottom && y < (pageIndex == 0 ? firstTop : laterTop) {
        pageIndex += 1
        y = laterTop
      }
      placed.append((pageIndex, y, block))
      y -= block.height
    }
    // Pass 1b: flow text after the last block.
    let framesetter = CTFramesetterCreateWithAttributedString(text)
    var frames: [Int: (range: CFRange, rect: CGRect)] = [:]
    var position = 0
    var textPage = pageIndex
    var top = summary == nil ? firstTop : y - 8
    var guardCount = 0
    while position < text.length {
      let rect = CGRect(x: margin, y: bottom, width: page.width - 2 * margin, height: max(top - bottom, 0))
      if rect.height >= 60 {
        let frame = CTFramesetterCreateFrame(
          framesetter, CFRange(location: position, length: 0), CGPath(rect: rect, transform: nil), nil)
        var range = CTFrameGetVisibleStringRange(frame)
        if range.length == 0 && top >= laterTop { throw DataError.invalid }
        // Keep a heading with its body: move a heading that ends the page to the next one.
        let end = range.location + range.length
        if end < text.length,
          let heading = headings.first(where: {
            $0.location > range.location && $0.location < end && end <= $0.location + $0.length + 1
          })
        {
          range.length = heading.location - range.location
        }
        frames[textPage] = (range, rect)
        position += range.length
      }
      if position < text.length {
        textPage += 1
        top = laterTop
      }
      guardCount += 1
      if guardCount > 2000 { throw DataError.tooLarge }
    }
    let pageCount = max(pageIndex, frames.keys.max() ?? 0) + 1
    if summary == nil && text.length == 0 {
      context.closePDF()
      return data as Data
    }

    // Pass 2: draw.
    let footerTitle = summary?.title ?? subtitle
    let pageLabel = summary?.pageLabel ?? ""
    for index in 0..<pageCount {
      context.beginPDFPage(nil)
      context.setFillColor(white)
      context.fill(CGRect(origin: .zero, size: page))
      if index == 0, let summary {
        drawBand(context, summary, subtitle: subtitle, logo: logo, wordmark: wordmark)
      } else if summary != nil {
        context.setFillColor(navy)
        context.fill(CGRect(x: 0, y: page.height - 8, width: page.width, height: 8))
        draw(context, "SymptoPage · " + footerTitle, font(8.5, .bold), teal,
          at: CGPoint(x: margin, y: page.height - 30))
        if let patient = summary?.patient {
          draw(context, patient, font(8.5), muted, at: CGPoint(x: page.width - margin, y: page.height - 30),
            align: .right)
        }
      }
      for item in placed where item.page == index { item.block.draw(context, item.top) }
      if let item = frames[index], item.range.length > 0 {
        let frame = CTFramesetterCreateFrame(
          framesetter, item.range, CGPath(rect: item.rect, transform: nil), nil)
        context.textMatrix = .identity
        CTFrameDraw(frame, context)
      }
      context.setFillColor(line)
      context.fill(CGRect(x: margin, y: 40, width: page.width - 2 * margin, height: 0.6))
      let left = summary == nil ? "SymptoPage · \(index + 1)" : "SymptoPage · " + footerTitle
      draw(context, left, font(8), muted, at: CGPoint(x: margin, y: 26))
      if summary != nil {
        draw(context, "\(pageLabel) \(index + 1) / \(pageCount)", font(8, .semibold), muted,
          at: CGPoint(x: page.width - margin, y: 26), align: .right)
      }
      context.endPDFPage()
    }
    context.closePDF()
    return data as Data
  }

  // MARK: Blocks

  static let bandHeight: CGFloat = 118
  static let maxTableRows = 10
  static let maxStripRows = 8
  static let maxActivityRows = 12
  static var width: CGFloat { page.width - 2 * margin }

  static func image(_ data: Data?) -> CGImage? {
    data.flatMap { CGImageSourceCreateWithData($0 as CFData, nil) }.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
  }
  /// The owner's white wordmark when supplied; otherwise icon + typeset name.
  static func drawBand(_ c: CGContext, _ s: ReportSummary, subtitle: String, logo: Data?, wordmark: Data? = nil) {
    // Brand navy (the owner's dark icon colour) keeps the gradient heart of the wordmark legible.
    c.setFillColor(navy)
    c.fill(CGRect(x: 0, y: page.height - bandHeight, width: page.width, height: bandHeight))
    c.setFillColor(rgb(0x35A5A0, alpha: 0.35))
    c.fillEllipse(in: CGRect(x: page.width - 170, y: page.height - 70, width: 220, height: 220))
    var textX = margin
    let title = s.title + (subtitle.isEmpty ? "" : " · " + subtitle)
    if let mark = image(wordmark), mark.height > 0 {
      let height: CGFloat = 46
      let width = min(height * CGFloat(mark.width) / CGFloat(mark.height), 260)
      c.interpolationQuality = .high
      c.draw(mark, in: CGRect(x: margin - 4, y: page.height - 76, width: width, height: width * CGFloat(mark.height) / CGFloat(mark.width)))
      draw(c, title, font(11.5, .semibold), white, at: CGPoint(x: margin, y: page.height - 96), maxWidth: 300)
      drawBandRight(c, s)
      return
    }
    if let logo, let source = CGImageSourceCreateWithData(logo as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    {
      let rect = CGRect(x: margin, y: page.height - 92, width: 60, height: 60)
      c.saveGState()
      c.addPath(CGPath(roundedRect: rect, cornerWidth: 14, cornerHeight: 14, transform: nil))
      c.clip()
      c.draw(image, in: rect)
      c.restoreGState()
      textX = margin + 74
    }
    draw(c, "SymptoPage", font(24, .heavy), white, at: CGPoint(x: textX, y: page.height - 58))
    draw(c, title, font(11.5, .semibold), white, at: CGPoint(x: textX, y: page.height - 78), maxWidth: 300)
    drawBandRight(c, s)
  }
  static func drawBandRight(_ c: CGContext, _ s: ReportSummary) {
    let right = page.width - margin
    var ry = page.height - 50
    if let patient = s.patient {
      draw(c, patient, font(13, .bold), white, at: CGPoint(x: right, y: ry), align: .right, maxWidth: 200)
      ry -= 18
    }
    draw(c, s.period, font(10, .semibold), white, at: CGPoint(x: right, y: ry), align: .right)
    draw(c, s.generated, font(8.5), rgb(0xFFFFFF, alpha: 0.85), at: CGPoint(x: right, y: ry - 15),
      align: .right)
  }

  static func blocks(_ s: ReportSummary) -> [Block] {
    var result: [Block] = []
    result.append(
      Block(height: 42) { c, y in
        let rect = CGRect(x: margin, y: y - 30, width: width, height: 30)
        fillRounded(c, rect, soft, radius: 10)
        draw(c, "ⓘ  " + s.disclaimer, font(8.8, .semibold), teal,
          at: CGPoint(x: margin + 12, y: rect.minY + 11), maxWidth: width - 24)
      })
    result.append(Block(height: 82) { c, y in tiles(c, s.tiles, top: y, tint: teal) })
    result.append(
      Block(height: 16) { c, y in
        draw(c, s.doctors, font(9, .semibold), muted, at: CGPoint(x: margin, y: y - 10), maxWidth: width)
      })
    if !s.symptoms.isEmpty {
      let rows = min(s.symptoms.count, maxTableRows)
      result.append(
        Block(height: 30 + 20 * CGFloat(rows + 1) + (s.symptoms.count > maxTableRows ? 20 : 6)) { c, y in
          symptomTable(c, s, top: y)
        })
    }
    if !s.strip.isEmpty {
      result.append(
        Block(height: 30 + 18 * CGFloat(min(s.strip.count, maxStripRows)) + 34) { c, y in strip(c, s, top: y) })
    }
    if let h = s.health {
      result.append(
        Block(height: 30 + 82) { c, y in
          let y = heading(c, h.title, y: y)
          tiles(c, h.tiles, top: y, tint: rgb(0xD32F2F))
        })
      let hasCharts = [h.resting, h.steps, h.sleep].contains { $0.contains { $0 != nil } }
      if hasCharts {
        result.append(Block(height: 132) { c, y in charts(c, h, s, top: y) })
      }
      if !h.activities.isEmpty {
        let rows = min(h.activities.count, maxActivityRows)
        result.append(
          Block(height: 30 + 22 * CGFloat(rows + 1) + (h.activities.count > maxActivityRows ? 20 : 6)) { c, y in
            activityTable(c, h, top: y)
          })
      }
      result.append(
        Block(height: 18) { c, y in
          draw(c, h.source, font(8, .semibold), muted, at: CGPoint(x: margin, y: y - 10), maxWidth: width)
        })
    }
    return result
  }

  static func tiles(_ c: CGContext, _ tiles: [(value: String, label: String)], top y: CGFloat, tint: CGColor) {
    let gap: CGFloat = 10
    let tileWidth = (width - gap * CGFloat(tiles.count - 1)) / CGFloat(max(tiles.count, 1))
    for (i, tile) in tiles.enumerated() {
      let rect = CGRect(x: margin + CGFloat(i) * (tileWidth + gap), y: y - 72, width: tileWidth, height: 72)
      fillRounded(c, rect, tint == teal ? chip : rgb(0xFBE3E3), radius: 14)
      draw(c, tile.value, font(20, .heavy), tint, at: CGPoint(x: rect.minX + 12, y: rect.maxY - 30),
        maxWidth: tileWidth - 24)
      paragraph(c, tile.label, font(8.2, .semibold), ink,
        in: CGRect(x: rect.minX + 12, y: rect.minY + 6, width: tileWidth - 24, height: 30))
    }
  }

  static func symptomTable(_ c: CGContext, _ s: ReportSummary, top: CGFloat) {
    var y = heading(c, s.symptomTitle, y: top)
    let columns: [CGFloat] = [190, 170, 75, 80]
    let rowHeight: CGFloat = 20
    tableHeader(c, s.symptomHeaders, columns, y: y, color: teal)
    y -= rowHeight
    let maxCount = CGFloat(s.symptoms.map(\.count).max() ?? 1)
    for (index, row) in s.symptoms.prefix(maxTableRows).enumerated() {
      zebra(c, index, y: y, height: rowHeight)
      var x = margin + 10
      draw(c, row.label, font(9.5, .semibold), ink, at: CGPoint(x: x, y: y - 13.5), maxWidth: columns[0] - 14)
      x += columns[0]
      draw(c, "\(row.count)", font(9.5, .bold), ink, at: CGPoint(x: x, y: y - 13.5))
      let barMax = columns[1] - 40
      fillRounded(c, CGRect(x: x + 24, y: y - 13, width: barMax, height: 7), chip, radius: 3.5)
      fillRounded(c, CGRect(x: x + 24, y: y - 13, width: max(4, barMax * CGFloat(row.count) / maxCount), height: 7), teal, radius: 3.5)
      x += columns[1]
      draw(c, row.intensity, font(9.5), ink, at: CGPoint(x: x, y: y - 13.5), maxWidth: columns[2] - 8)
      x += columns[2]
      draw(c, row.last, font(9), muted, at: CGPoint(x: x, y: y - 13.5), maxWidth: columns[3] - 8)
      y -= rowHeight
    }
    if s.symptoms.count > maxTableRows {
      draw(c, "+\(s.symptoms.count - maxTableRows) …", font(8.5, .semibold), muted, at: CGPoint(x: margin + 10, y: y - 12))
    }
  }

  static func strip(_ c: CGContext, _ s: ReportSummary, top: CGFloat) {
    var y = heading(c, s.stripTitle, y: top)
    let labelWidth: CGFloat = 140
    let step = min(14, (width - labelWidth) / CGFloat(max(s.days.count, 1)))
    let cell = max(step - 2.5, 3)
    for row in s.strip.prefix(maxStripRows) {
      draw(c, row.label, font(9, .semibold), ink, at: CGPoint(x: margin, y: y - 12), maxWidth: labelWidth - 10)
      for (i, value) in row.values.enumerated() {
        let rect = CGRect(x: margin + labelWidth + CGFloat(i) * step, y: y - 14, width: cell, height: cell)
        if let value {
          fillRounded(c, rect, color(value), radius: 2.5)
        } else {
          c.setStrokeColor(line)
          c.setLineWidth(0.8)
          c.addPath(CGPath(roundedRect: rect.insetBy(dx: 0.4, dy: 0.4), cornerWidth: 2.5, cornerHeight: 2.5, transform: nil))
          c.strokePath()
        }
      }
      y -= 18
    }
    if !s.days.isEmpty {
      draw(c, s.dayRange.first, font(7.5), muted, at: CGPoint(x: margin + labelWidth, y: y - 6))
      draw(c, s.dayRange.last, font(7.5), muted,
        at: CGPoint(x: margin + labelWidth + CGFloat(s.days.count - 1) * step + cell, y: y - 6), align: .right)
    }
    var lx = margin
    for (value, title) in s.legend {
      let rect = CGRect(x: lx, y: y - 25, width: 9, height: 9)
      if let value { fillRounded(c, rect, color(value), radius: 2) } else {
        c.setStrokeColor(muted)
        c.setLineWidth(0.6)
        c.stroke(rect)
      }
      draw(c, title, font(8), muted, at: CGPoint(x: lx + 13, y: y - 23.5))
      lx += 13 + textWidth(title, font(8)) + 16
    }
  }

  /// Three small charts: resting HR (line), steps (bars), sleep in hours (bars).
  static func charts(_ c: CGContext, _ h: HealthBlock, _ s: ReportSummary, top: CGFloat) {
    let gap: CGFloat = 12
    let w = (width - 2 * gap) / 3
    let specs: [(String, [Int?], CGColor, Bool, (Int) -> String)] = [
      (h.restingTitle, h.resting, rgb(0xD32F2F), true, { "\($0)" }),
      (h.stepsTitle, h.steps, teal, false, { $0 >= 1000 ? String(format: "%.1fk", Double($0) / 1000) : "\($0)" }),
      (h.sleepTitle, h.sleep, rgb(0x5AA9D6), false, { String(format: "%.1f", Double($0) / 60) }),
    ]
    for (i, spec) in specs.enumerated() {
      let rect = CGRect(x: margin + CGFloat(i) * (w + gap), y: top - 124, width: w, height: 120)
      fillRounded(c, rect, rgb(0xF4FAF9), radius: 14)
      draw(c, spec.0, font(9, .bold), ink, at: CGPoint(x: rect.minX + 12, y: rect.maxY - 18), maxWidth: w - 24)
      let values = spec.1
      let present = values.compactMap { $0 }
      let plot = CGRect(x: rect.minX + 12, y: rect.minY + 22, width: w - 24, height: rect.height - 52)
      guard let lo = present.min(), let hi = present.max() else {
        draw(c, "—", font(14, .bold), muted, at: CGPoint(x: plot.midX - 5, y: plot.midY))
        continue
      }
      let floor = spec.3 ? Double(lo) - 3 : 0
      let span = max(Double(hi) - floor, 1)
      let step = plot.width / CGFloat(max(values.count, 1))
      c.setFillColor(line)
      c.fill(CGRect(x: plot.minX, y: plot.minY, width: plot.width, height: 0.8))
      if spec.3 {
        c.setStrokeColor(spec.2)
        c.setLineWidth(1.6)
        c.setLineJoin(.round)
        var started = false
        for (index, value) in values.enumerated() {
          guard let value else { started = false; continue }
          let point = CGPoint(x: plot.minX + step * (CGFloat(index) + 0.5), y: plot.minY + plot.height * CGFloat((Double(value) - floor) / span))
          if started { c.addLine(to: point) } else { c.move(to: point); started = true }
        }
        c.strokePath()
        c.setFillColor(spec.2)
        for (index, value) in values.enumerated() {
          guard let value else { continue }
          let y = plot.minY + plot.height * CGFloat((Double(value) - floor) / span)
          c.fillEllipse(in: CGRect(x: plot.minX + step * (CGFloat(index) + 0.5) - 1.6, y: y - 1.6, width: 3.2, height: 3.2))
        }
      } else {
        for (index, value) in values.enumerated() {
          guard let value else { continue }
          let height = max(plot.height * CGFloat(Double(value) / span), 1.5)
          fillRounded(c, CGRect(x: plot.minX + step * CGFloat(index) + step * 0.15, y: plot.minY, width: max(step * 0.7, 1), height: height), spec.2, radius: min(step * 0.35, 2))
        }
      }
      let summary = "min \(spec.4(lo)) · max \(spec.4(hi))"
      draw(c, summary, font(7.5, .semibold), muted, at: CGPoint(x: rect.minX + 12, y: rect.minY + 8), maxWidth: w - 24)
    }
    if !s.days.isEmpty {
      draw(c, s.dayRange.first + " — " + s.dayRange.last, font(7.5), muted, at: CGPoint(x: page.width - margin, y: top - 132 + 2), align: .right)
    }
  }

  static func activityTable(_ c: CGContext, _ h: HealthBlock, top: CGFloat) {
    var y = heading(c, h.activitiesTitle, y: top)
    let columns: [CGFloat] = [72, 185, 62, 62, 56, 78]
    let rowHeight: CGFloat = 22
    tableHeader(c, h.activityHeaders, columns, y: y + 1, color: rgb(0x0F3B3D))
    y -= rowHeight
    for (index, row) in h.activities.prefix(maxActivityRows).enumerated() {
      zebra(c, index, y: y, height: rowHeight)
      var x = margin + 10
      draw(c, row.date, font(8.8), muted, at: CGPoint(x: x, y: y - 14.5), maxWidth: columns[0] - 8)
      x += columns[0]
      let title = row.name.isEmpty ? row.sport : row.sport + " · " + row.name
      draw(c, title, font(9.2, .semibold), ink, at: CGPoint(x: x, y: y - 14.5), maxWidth: columns[1] - 10)
      x += columns[1]
      for (value, w) in [(row.duration, columns[2]), (row.distance, columns[3]), (row.heartRate, columns[4])] {
        draw(c, value, font(9), ink, at: CGPoint(x: x, y: y - 14.5), maxWidth: w - 6)
        x += w
      }
      let label = row.source.title
      let badge = CGRect(x: x, y: y - 17, width: textWidth(label, font(7.5, .bold)) + 14, height: 13)
      fillRounded(c, badge, row.source == .strava ? rgb(0xFC4C02) : rgb(0xFF2D55), radius: 6.5)
      draw(c, label, font(7.5, .bold), white, at: CGPoint(x: badge.minX + 7, y: badge.minY + 3.6))
      y -= rowHeight
    }
    if h.activities.count > maxActivityRows {
      draw(c, "+\(h.activities.count - maxActivityRows) …", font(8.5, .semibold), muted, at: CGPoint(x: margin + 10, y: y - 12))
    }
  }

  static func tableHeader(_ c: CGContext, _ titles: [String], _ columns: [CGFloat], y: CGFloat, color: CGColor) {
    fillRounded(c, CGRect(x: margin, y: y - 20, width: width, height: 20), color, radius: 6)
    var x = margin + 10
    for (i, title) in titles.enumerated() where i < columns.count {
      draw(c, title.uppercased(), font(7.8, .bold), white, at: CGPoint(x: x, y: y - 13.5), maxWidth: columns[i] - 10)
      x += columns[i]
    }
  }
  static func zebra(_ c: CGContext, _ index: Int, y: CGFloat, height: CGFloat) {
    guard index % 2 == 1 else { return }
    c.setFillColor(rgb(0xF4FAF9))
    c.fill(CGRect(x: margin, y: y - height, width: width, height: height))
  }
  static func heading(_ c: CGContext, _ title: String, y: CGFloat) -> CGFloat {
    draw(c, title, font(12.5, .heavy), teal, at: CGPoint(x: margin, y: y - 18))
    c.setFillColor(line)
    c.fill(CGRect(x: margin, y: y - 25, width: page.width - 2 * margin, height: 0.8))
    return y - 30
  }
  static func color(_ value: Frequency) -> CGColor {
    switch value {
    case .none: return chip
    case .once: return amber
    case .several: return red
    }
  }

  // MARK: Text

  static func attributed(_ sections: [ReportSection]) -> (NSAttributedString, [NSRange]) {
    let text = NSMutableAttributedString()
    var headings: [NSRange] = []
    for section in sections {
      headings.append(NSRange(location: text.length, length: (section.title + "\n").utf16.count))
      text.append(
        NSAttributedString(
          string: section.title + "\n",
          attributes: attributes(font(12.5, .heavy), teal, before: text.length == 0 ? 0 : 14, after: 5)))
      // Blank lines separate entries; draw them as small gaps instead of full empty lines.
      let body = attributes(font(10), ink, before: 0, after: 2, lineSpacing: 2)
      let gap = attributes(font(5), ink, before: 0, after: 0)
      for line in section.body.components(separatedBy: "\n") {
        text.append(NSAttributedString(string: line + "\n", attributes: line.isEmpty ? gap : body))
      }
    }
    return (text, headings)
  }
  static func attributes(
    _ font: CTFont, _ color: CGColor, before: CGFloat, after: CGFloat, lineSpacing: CGFloat = 0
  ) -> [NSAttributedString.Key: Any] {
    var b = before, a = after, l = lineSpacing
    let style = withUnsafeBytes(of: &b) { pb in
      withUnsafeBytes(of: &a) { pa in
        withUnsafeBytes(of: &l) { pl in
          let settings = [
            CTParagraphStyleSetting(spec: .paragraphSpacingBefore, valueSize: MemoryLayout<CGFloat>.size, value: pb.baseAddress!),
            CTParagraphStyleSetting(spec: .paragraphSpacing, valueSize: MemoryLayout<CGFloat>.size, value: pa.baseAddress!),
            CTParagraphStyleSetting(spec: .lineSpacingAdjustment, valueSize: MemoryLayout<CGFloat>.size, value: pl.baseAddress!),
          ]
          return CTParagraphStyleCreate(settings, settings.count)
        }
      }
    }
    return [
      NSAttributedString.Key(kCTFontAttributeName as String): font,
      NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
      NSAttributedString.Key(kCTParagraphStyleAttributeName as String): style,
    ]
  }
  enum Align { case left, right }
  static func textWidth(_ string: String, _ font: CTFont) -> CGFloat {
    let line = CTLineCreateWithAttributedString(
      NSAttributedString(string: string, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
    return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
  }
  /// Draws one line; longer text is truncated with an ellipsis.
  static func draw(
    _ c: CGContext, _ string: String, _ font: CTFont, _ color: CGColor, at point: CGPoint,
    align: Align = .left, maxWidth: CGFloat? = nil
  ) {
    let attributes: [NSAttributedString.Key: Any] = [
      NSAttributedString.Key(kCTFontAttributeName as String): font,
      NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
    ]
    var line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
    if let maxWidth, CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)) > maxWidth {
      let token = CTLineCreateWithAttributedString(NSAttributedString(string: "…", attributes: attributes))
      line = CTLineCreateTruncatedLine(line, Double(maxWidth), .end, token) ?? line
    }
    let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    c.textMatrix = .identity
    c.textPosition = CGPoint(x: align == .right ? point.x - lineWidth : point.x, y: point.y)
    CTLineDraw(line, c)
  }
  static func paragraph(_ c: CGContext, _ string: String, _ font: CTFont, _ color: CGColor, in rect: CGRect) {
    let text = NSAttributedString(
      string: string,
      attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
      ])
    let frame = CTFramesetterCreateFrame(
      CTFramesetterCreateWithAttributedString(text), CFRange(location: 0, length: 0),
      CGPath(rect: rect, transform: nil), nil)
    c.textMatrix = .identity
    CTFrameDraw(frame, c)
  }
  static func fillRounded(_ c: CGContext, _ rect: CGRect, _ color: CGColor, radius: CGFloat) {
    let r = min(radius, rect.width / 2, rect.height / 2)
    c.setFillColor(color)
    c.addPath(CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil))
    c.fillPath()
  }
  static func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
      srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
  }
}
