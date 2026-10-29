import SwiftUI
import UIKit

/// Describes one wax seal. The same spec always renders the same seal.
struct WaxSealSpec: Hashable, Sendable {
    enum Emblem: Hashable, Sendable {
        case letter(String)
        case quill
        /// No die pressed in: a loose drop of wax.
        case plain
    }

    var ink: RubricInk
    var emblem: Emblem = .letter("S")
    var seed = "seal"
    var pixels: Int

    var cacheKey: String { "\(ink.rawValue)|\(emblem)|\(seed)|\(pixels)" }
}

/// Renders realistic sealing wax: an irregular puddle with drips, a pressed die
/// with a beaded border and raised emblem, fine texture and air bubbles, lit by
/// one light from the upper left with a glossy highlight.
enum WaxSealRenderer {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 160
        return cache
    }()

    static func cachedImage(_ spec: WaxSealSpec) -> UIImage? {
        cache.object(forKey: spec.cacheKey as NSString)
    }

    static func image(_ spec: WaxSealSpec) async -> UIImage {
        if let hit = cachedImage(spec) { return hit }
        let image = await Task.detached(priority: .userInitiated) { render(spec) }.value
        cache.setObject(image, forKey: spec.cacheKey as NSString)
        return image
    }

    // MARK: Rendering

    static func render(_ spec: WaxSealSpec) -> UIImage {
        let n = max(24, spec.pixels)
        let count = n * n
        let pressed = spec.emblem != .plain
        var rng = Mulberry(seed: fnv1a(spec.seed + ":" + "\(spec.emblem)"))

        let size = Float(n)
        let cx = size / 2, cy = size / 2
        let radius = size * (pressed ? 0.405 : 0.36)
        let phases = (0..<3).map { _ in rng.next() * 6.283 }
        var drips: [(angle: Float, width: Float, height: Float)] = []
        for _ in 0..<(4 + Int(rng.next() * 4)) {
            drips.append((rng.next() * 2 * .pi - .pi, 0.1 + rng.next() * 0.22, 0.025 + rng.next() * (pressed ? 0.075 : 0.05)))
        }
        let dieX = cx + (rng.next() - 0.5) * radius * 0.07
        let dieY = cy + (rng.next() - 0.5) * radius * 0.07
        let die = radius * 0.66
        let thickness = radius * 0.2
        let depth = thickness * 0.44

        let mask: [Float]? = pressed
            ? blur(emblemMask(n, CGFloat(dieX), CGFloat(dieY), CGFloat(die), spec.emblem), n, n, radius: max(1, n / 230), passes: 2)
            : nil
        let broad = ValueNoise(&rng, grid: 7)
        let fine = ValueNoise(&rng, grid: 46)
        let tint = ValueNoise(&rng, grid: 10)
        var bubbles: [(x: Float, y: Float, r: Float)] = []
        for _ in 0..<14 {
            let angle = rng.next() * 6.283, distance = rng.next().squareRoot() * radius * 0.97
            bubbles.append((cx + cos(angle) * distance, cy + sin(angle) * distance, size * (0.004 + rng.next() * 0.009)))
        }

        var height = [Float](repeating: 0, count: count)
        var alpha = [Float](repeating: 0, count: count)
        var edge = [Float](repeating: 0, count: count)

        for y in 0..<n {
            for x in 0..<n {
                let i = y * n + x
                let dx = Float(x) + 0.5 - cx, dy = Float(y) + 0.5 - cy
                let r = (dx * dx + dy * dy).squareRoot()
                let theta = atan2(dy, dx)
                let wave1: Float = 0.028 * sin(3 * theta + phases[0])
                let wave2: Float = 0.018 * sin(5 * theta + phases[1])
                let wave3: Float = 0.01 * sin(11 * theta + phases[2])
                var boundary = radius * (1 + wave1 + wave2 + wave3)
                for drip in drips {
                    var gap = abs(theta - drip.angle)
                    if gap > .pi { gap = 2 * .pi - gap }
                    let q = gap / drip.width
                    boundary += radius * drip.height * exp(-q * q)
                }
                let e = boundary - r
                alpha[i] = clamp01(e * 1.2 + 0.5)
                if e <= -1.5 { continue }
                edge[i] = e

                let t = clamp01(e / (radius * 0.22))
                var h = thickness * (1 - (1 - t) * (1 - t) * (1 - t))
                if pressed {
                    let sx = Float(x) + 0.5 - dieX, sy = Float(y) + 0.5 - dieY
                    let ds = (sx * sx + sy * sy).squareRoot()
                    let ridge = (ds - die * 1.06) / (radius * 0.06)
                    h += thickness * 0.34 * exp(-ridge * ridge)
                    let press = 1 - smoothstep(die - radius * 0.03, die + radius * 0.012, ds)
                    h -= press * depth
                    if let mask { h += mask[i] * depth * 0.84 * press }
                    h -= press * thickness * 0.05 * (ds / die) * (ds / die)
                }
                let u = Float(x) / size, v = Float(y) / size
                h += (broad(u, v) - 0.5) * thickness * 0.18 + (fine(u, v) - 0.5) * thickness * 0.035
                for bubble in bubbles {
                    let bx = Float(x) - bubble.x, by = Float(y) - bubble.y
                    let db = (bx * bx + by * by).squareRoot()
                    if db < bubble.r {
                        let q = 1 - db / bubble.r
                        h -= q * q * thickness * 0.16
                    }
                }
                height[i] = h * smoothstep(-1.5, 2, e)
            }
        }

        let surface = blur(height, n, n, radius: 1, passes: 1)
        let ambient = blur(surface, n, n, radius: max(2, n / 36), passes: 2)

        var light: (Float, Float, Float) = (-0.48, -0.62, 0.62)
        let lightLength = (light.0 * light.0 + light.1 * light.1 + light.2 * light.2).squareRoot()
        light = (light.0 / lightLength, light.1 / lightLength, light.2 / lightLength)
        var half = (light.0, light.1, light.2 + 1)
        let halfLength = (half.0 * half.0 + half.1 * half.1 + half.2 * half.2).squareRoot()
        half = (half.0 / halfLength, half.1 / halfLength, half.2 / halfLength)
        let base = spec.ink.wax

        var pixels = [UInt8](repeating: 0, count: count * 4)
        for y in 1..<(n - 1) {
            for x in 1..<(n - 1) {
                let i = y * n + x
                let a = alpha[i]
                if a <= 0 { continue }
                var nx = -(surface[i + 1] - surface[i - 1]) * 0.5
                var ny = -(surface[i + n] - surface[i - n]) * 0.5
                var nz: Float = 1
                let inverse = 1 / (nx * nx + ny * ny + nz * nz).squareRoot()
                nx *= inverse; ny *= inverse; nz *= inverse
                let diffuse = max(0, nx * light.0 + ny * light.1 + nz * light.2)
                let facing = max(0, nx * half.0 + ny * half.1 + nz * half.2)
                let gloss = pow(facing, 70) * 0.95 + pow(facing, 14) * 0.1
                let cavity = clamp01((ambient[i] - surface[i]) / (thickness * 0.32))
                let thin = 1 - smoothstep(0, radius * 0.07, edge[i])
                let tone = (0.36 + 0.86 * diffuse) * (1 - cavity * 0.55) * (0.94 + (tint(Float(x) / size, Float(y) / size) - 0.5) * 0.16)
                let lift = thin * 0.22
                let red = base.0 * tone * (1 + lift * 1.4) + gloss * 255
                let green = base.1 * tone * (1 + lift) + gloss * 236
                let blue = base.2 * tone * (1 + lift) + gloss * 214
                pixels[i * 4] = byte(red * a)
                pixels[i * 4 + 1] = byte(green * a)
                pixels[i * 4 + 2] = byte(blue * a)
                pixels[i * 4 + 3] = byte(a * 255)
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: n,
                height: n,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: n * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else { return UIImage() }
        return UIImage(cgImage: cgImage)
    }

    /// The die's raised parts: a rim, a ring of beads, and the emblem.
    private static func emblemMask(_ n: Int, _ cx: CGFloat, _ cy: CGFloat, _ die: CGFloat, _ emblem: WaxSealSpec.Emblem) -> [Float] {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let drawing = UIGraphicsImageRenderer(size: CGSize(width: n, height: n), format: format).image { context in
            let g = context.cgContext
            g.setFillColor(UIColor.white.cgColor)
            g.setStrokeColor(UIColor.white.cgColor)
            g.translateBy(x: cx, y: cy)
            g.setLineWidth(die * 0.045)
            g.strokeEllipse(in: CGRect(x: -die * 0.9, y: -die * 0.9, width: die * 1.8, height: die * 1.8))
            for index in 0..<36 {
                let angle = CGFloat(index) / 36 * .pi * 2
                let bead = die * 0.03
                g.fillEllipse(in: CGRect(x: cos(angle) * die * 0.785 - bead, y: sin(angle) * die * 0.785 - bead, width: bead * 2, height: bead * 2))
            }
            switch emblem {
            case .letter(let letter):
                let font = UIFont(name: Typeface.fraktur, size: die * 1.16) ?? .systemFont(ofSize: die, weight: .black)
                let text = NSAttributedString(string: letter, attributes: [.font: font, .foregroundColor: UIColor.white])
                let bounds = text.size()
                text.draw(at: CGPoint(x: -bounds.width / 2, y: -bounds.height / 2 + die * 0.04))
            case .quill:
                drawQuill(g, die)
            case .plain:
                break
            }
        }
        var values = [Float](repeating: 0, count: n * n)
        guard let cgImage = drawing.cgImage,
              let context = CGContext(
                data: nil,
                width: n,
                height: n,
                bitsPerComponent: 8,
                bytesPerRow: n * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return values }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: n, height: n))
        guard let data = context.data else { return values }
        let bytes = data.bindMemory(to: UInt8.self, capacity: n * n * 4)
        for i in 0..<(n * n) {
            values[i] = Float(bytes[i * 4 + 3]) / 255
        }
        return values
    }

    private static func drawQuill(_ g: CGContext, _ die: CGFloat) {
        g.saveGState()
        g.rotate(by: .pi / 4)
        let l = die * 1.32
        let vane = CGMutablePath()
        vane.move(to: CGPoint(x: 0, y: -0.52 * l))
        vane.addCurve(to: CGPoint(x: 0.025 * l, y: 0.2 * l), control1: CGPoint(x: 0.21 * l, y: -0.36 * l), control2: CGPoint(x: 0.18 * l, y: 0.04 * l))
        vane.addLine(to: CGPoint(x: -0.025 * l, y: 0.2 * l))
        vane.addCurve(to: CGPoint(x: 0, y: -0.52 * l), control1: CGPoint(x: -0.16 * l, y: 0.02 * l), control2: CGPoint(x: -0.17 * l, y: -0.33 * l))
        g.addPath(vane)
        g.fillPath()

        // Cut the barbs and the spine into the vane.
        g.setBlendMode(.clear)
        g.setLineCap(.round)
        g.setLineWidth(die * 0.026)
        for index in 0..<6 {
            let y = -0.36 * l + CGFloat(index) * 0.085 * l
            g.move(to: CGPoint(x: 0.02 * l, y: y + 0.02 * l))
            g.addLine(to: CGPoint(x: 0.24 * l, y: y - 0.08 * l))
            g.move(to: CGPoint(x: -0.02 * l, y: y + 0.05 * l))
            g.addLine(to: CGPoint(x: -0.24 * l, y: y - 0.04 * l))
        }
        g.strokePath()
        g.setLineWidth(die * 0.022)
        g.move(to: CGPoint(x: 0, y: -0.46 * l))
        g.addLine(to: CGPoint(x: 0, y: 0.2 * l))
        g.strokePath()

        // The bare shaft down to the nib.
        g.setBlendMode(.normal)
        g.setLineWidth(die * 0.055)
        g.move(to: CGPoint(x: 0, y: 0.17 * l))
        g.addLine(to: CGPoint(x: 0, y: 0.5 * l))
        g.strokePath()
        g.restoreGState()
    }

    // MARK: Helpers

    private static func blur(_ source: [Float], _ w: Int, _ h: Int, radius r: Int, passes: Int) -> [Float] {
        var a = source
        var b = [Float](repeating: 0, count: w * h)
        let width = Float(2 * r + 1)
        for _ in 0..<passes {
            for y in 0..<h {
                let row = y * w
                var sum: Float = 0
                for x in -r...r { sum += a[row + min(w - 1, max(0, x))] }
                for x in 0..<w {
                    b[row + x] = sum / width
                    sum += a[row + min(w - 1, x + r + 1)] - a[row + max(0, x - r)]
                }
            }
            for x in 0..<w {
                var sum: Float = 0
                for y in -r...r { sum += b[min(h - 1, max(0, y)) * w + x] }
                for y in 0..<h {
                    a[y * w + x] = sum / width
                    sum += b[min(h - 1, y + r + 1) * w + x] - b[max(0, y - r) * w + x]
                }
            }
        }
        return a
    }

    private static func clamp01(_ x: Float) -> Float { min(1, max(0, x)) }

    private static func smoothstep(_ e0: Float, _ e1: Float, _ x: Float) -> Float {
        let t = clamp01((x - e0) / (e1 - e0))
        return t * t * (3 - 2 * t)
    }

    private static func byte(_ value: Float) -> UInt8 {
        guard value.isFinite else { return 0 }
        return UInt8(min(255, max(0, value)).rounded())
    }

    private static func fnv1a(_ text: String) -> UInt32 {
        var hash: UInt32 = 2_166_136_261
        for unit in text.utf8 {
            hash ^= UInt32(unit)
            hash = hash &* 16_777_619
        }
        return hash
    }
}

/// Small, fast, seedable random numbers (mulberry32).
struct Mulberry {
    private var state: UInt32

    init(seed: UInt32) {
        state = seed
    }

    mutating func next() -> Float {
        state = state &+ 0x6D2B_79F5
        var t = (state ^ (state >> 15)) &* (1 | state)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        // Top 24 bits, so the result stays strictly below 1.
        return Float((t ^ (t >> 14)) >> 8) / 16_777_216
    }
}

/// Smooth value noise on a coarse random grid.
struct ValueNoise {
    private let grid: [Float]
    private let size: Int

    init(_ rng: inout Mulberry, grid size: Int) {
        self.size = size
        grid = (0..<((size + 1) * (size + 1))).map { _ in rng.next() }
    }

    func callAsFunction(_ u: Float, _ v: Float) -> Float {
        let gx = u * Float(size), gy = v * Float(size)
        let ix = min(size - 1, max(0, Int(gx))), iy = min(size - 1, max(0, Int(gy)))
        let fx = gx - Float(ix), fy = gy - Float(iy)
        let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
        let stride = size + 1
        let a = grid[iy * stride + ix], b = grid[iy * stride + ix + 1]
        let c = grid[(iy + 1) * stride + ix], d = grid[(iy + 1) * stride + ix + 1]
        return a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy
    }
}

/// A rendered wax seal. Shows a soft placeholder for the first moment while
/// the seal is rendered off the main thread, then caches it.
struct WaxSealImage: View {
    var size: CGFloat
    var emblem: WaxSealSpec.Emblem = .letter("S")
    var seed = "seal"
    /// Defaults to the reader's chosen ink.
    var ink: RubricInk?

    @Environment(\.scribe) private var scribe
    @Environment(\.displayScale) private var displayScale
    @State private var rendered: (key: String, image: UIImage)?

    private var spec: WaxSealSpec {
        WaxSealSpec(ink: ink ?? scribe.ink, emblem: emblem, seed: seed, pixels: Int((size * max(2, displayScale)).rounded()))
    }

    var body: some View {
        Group {
            if let image = WaxSealRenderer.cachedImage(spec) ?? (rendered?.key == spec.cacheKey ? rendered?.image : nil) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
            } else {
                Circle()
                    .fill(spec.ink.deep)
                    .padding(size * 0.14)
                    .opacity(0.8)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Color(hex: 0x280A04, opacity: 0.35), radius: max(1, size * 0.012), y: max(1, size * 0.012))
        .shadow(color: Color(hex: 0x280A04, opacity: 0.22), radius: max(2, size * 0.05), y: max(2, size * 0.04))
        .task(id: spec) {
            let current = self.spec
            let image = await WaxSealRenderer.image(current)
            rendered = (current.cacheKey, image)
        }
        .accessibilityHidden(true)
    }
}

/// One half of a broken seal, split along a jagged crack.
struct CrackHalf: Shape {
    var isLeft: Bool

    private static let crack: [CGFloat] = [0.52, 0.47, 0.56, 0.45, 0.55, 0.48, 0.54, 0.46, 0.5]

    func path(in rect: CGRect) -> Path {
        let points = Self.crack.enumerated().map { index, fraction in
            CGPoint(x: rect.minX + rect.width * fraction, y: rect.minY + rect.height * CGFloat(index) / CGFloat(Self.crack.count - 1))
        }
        let outside = isLeft ? rect.minX - 6 : rect.maxX + 6
        var path = Path()
        path.move(to: CGPoint(x: outside, y: rect.minY - 6))
        path.addLine(to: CGPoint(x: points[0].x, y: rect.minY - 6))
        for point in points { path.addLine(to: point) }
        path.addLine(to: CGPoint(x: points[points.count - 1].x, y: rect.maxY + 6))
        path.addLine(to: CGPoint(x: outside, y: rect.maxY + 6))
        path.closeSubpath()
        return path
    }
}
