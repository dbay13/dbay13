import AVFoundation
import UIKit

/// The soft tick and paper scratch of the quill while writing.
/// The scratch is synthesized, so the app ships no audio files.
@MainActor
final class QuillFeedback {
    static let shared = QuillFeedback()

    private let haptic = UIImpactFeedbackGenerator(style: .soft)
    private var lastStroke = Date.distantPast
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var scratches: [AVAudioPCMBuffer] = []

    private init() {}

    func stroke(haptics: Bool, sounds: Bool) {
        let now = Date()
        guard now.timeIntervalSince(lastStroke) > 0.05 else { return }
        lastStroke = now
        if haptics {
            haptic.impactOccurred(intensity: 0.4)
        }
        if sounds {
            playScratch()
        }
    }

    private func playScratch() {
        if engine == nil {
            prepareAudio()
        }
        guard let player, let buffer = scratches.randomElement() else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying {
            player.play()
        }
    }

    private func prepareAudio() {
        // Ambient: mixes with music and respects the silent switch.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else { return }
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        scratches = (0..<4).compactMap { Self.makeScratch(format: format, variant: $0) }
        do {
            try engine.start()
        } catch {
            return
        }
        self.engine = engine
        self.player = player
    }

    /// A short burst of high-passed noise with a fast attack: a nib on paper.
    private static func makeScratch(format: AVAudioFormat, variant: Int) -> AVAudioPCMBuffer? {
        let duration = 0.04 + Double(variant) * 0.008
        let frameCount = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        var previous: Float = 0
        for index in 0..<Int(frameCount) {
            let t = Float(index) / Float(frameCount)
            let envelope = min(1, t * 25) * powf(1 - t, 2.2)
            let noise = Float.random(in: -1...1)
            let papery = noise - previous * 0.85
            previous = noise
            samples[index] = papery * envelope * 0.12
        }
        return buffer
    }
}
