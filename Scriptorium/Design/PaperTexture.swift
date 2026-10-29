import SwiftUI
import UIKit

/// Procedural parchment: fine grain, soft stains and a darker edge.
/// Generated once at launch, so the app ships no texture images.
enum PaperTexture {
    static let grainLight = grain(red: 84, green: 56, blue: 23, strength: 0.13, seed: 11)
    static let grainDark = grain(red: 242, green: 209, blue: 153, strength: 0.06, seed: 12)
    static let stains = mottle(seed: 7)

    /// A 128 × 128 pt tile of speckled grain.
    private static func grain(red: UInt8, green: UInt8, blue: UInt8, strength: Float, seed: UInt32) -> UIImage {
        let n = 256
        var rng = Mulberry(seed: seed)
        var pixels = [UInt8](repeating: 0, count: n * n * 4)
        for i in 0..<(n * n) {
            let speck = rng.next()
            let a = max(0, speck * 1.4 - 0.55) * strength + (speck > 0.985 ? strength * 1.4 : 0)
            let alpha = min(1, a)
            pixels[i * 4] = UInt8(Float(red) * alpha)
            pixels[i * 4 + 1] = UInt8(Float(green) * alpha)
            pixels[i * 4 + 2] = UInt8(Float(blue) * alpha)
            pixels[i * 4 + 3] = UInt8(alpha * 255)
        }
        return image(from: pixels, size: n, scale: 2)
    }

    /// A 320 × 320 pt tile of faint, uneven staining.
    private static func mottle(seed: UInt32) -> UIImage {
        let n = 320
        var rng = Mulberry(seed: seed)
        let broad = ValueNoise(&rng, grid: 4)
        let medium = ValueNoise(&rng, grid: 9)
        var pixels = [UInt8](repeating: 0, count: n * n * 4)
        for y in 0..<n {
            for x in 0..<n {
                // Wrap the coordinates so the tile repeats without a seam.
                let u = Float(x) / Float(n), v = Float(y) / Float(n)
                let value = seamless(broad, u, v) * 0.7 + seamless(medium, u, v) * 0.3
                let alpha = max(0, value - 0.48) * 0.42
                let i = (y * n + x) * 4
                pixels[i] = UInt8(120 * alpha)
                pixels[i + 1] = UInt8(80 * alpha)
                pixels[i + 2] = UInt8(26 * alpha)
                pixels[i + 3] = UInt8(alpha * 255)
            }
        }
        return image(from: pixels, size: n, scale: 1)
    }

    private static func seamless(_ noise: ValueNoise, _ u: Float, _ v: Float) -> Float {
        let a = noise(u, v), b = noise(1 - u, v), c = noise(u, 1 - v), d = noise(1 - u, 1 - v)
        let wu = abs(u - 0.5) * 2, wv = abs(v - 0.5) * 2
        let top = a * (1 - wu * 0.5) + b * (wu * 0.5)
        let bottom = c * (1 - wu * 0.5) + d * (wu * 0.5)
        return top * (1 - wv * 0.5) + bottom * (wv * 0.5)
    }

    private static func image(from pixels: [UInt8], size n: Int, scale: CGFloat) -> UIImage {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: n,
                height: n,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: n * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else { return UIImage() }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}

/// The parchment every screen sits on.
struct ParchmentBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Palette.ground
                if colorScheme == .light {
                    Image(uiImage: PaperTexture.stains)
                        .resizable(resizingMode: .tile)
                }
                Image(uiImage: colorScheme == .dark ? PaperTexture.grainDark : PaperTexture.grainLight)
                    .resizable(resizingMode: .tile)
                RadialGradient(
                    colors: [.clear, .clear, Palette.vignette],
                    center: UnitPoint(x: 0.5, y: 0.42),
                    startRadius: 0,
                    endRadius: max(geometry.size.width, geometry.size.height) * 0.75
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
