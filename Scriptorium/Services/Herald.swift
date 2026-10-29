import Observation
import SwiftUI

/// Short notices at the foot of the screen ("Scroll burned · Undo").
@MainActor
@Observable
final class Herald {
    struct Notice: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let symbol: String?
        let sealSeed: String?
        let undo: (() -> Void)?

        static func == (lhs: Notice, rhs: Notice) -> Bool { lhs.id == rhs.id }
    }

    private(set) var notice: Notice?

    func announce(_ text: String, symbol: String? = "checkmark", sealSeed: String? = nil, undo: (() -> Void)? = nil) {
        let notice = Notice(text: text, symbol: sealSeed == nil ? symbol : nil, sealSeed: sealSeed, undo: undo)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.notice = notice
        }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3.6))
            guard let self, self.notice?.id == notice.id else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                self.notice = nil
            }
        }
    }

    func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            notice = nil
        }
    }
}

/// The dark pill that shows a Herald notice.
struct HeraldBanner: View {
    @Environment(Herald.self) private var herald
    @Environment(\.scribe) private var scribe

    var body: some View {
        if let notice = herald.notice {
            HStack(spacing: 10) {
                if let seed = notice.sealSeed {
                    WaxSealImage(size: 28, seed: seed)
                } else if let symbol = notice.symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xEBC66C))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                Text(notice.text)
                    .font(scribe.body(17))
                    .foregroundStyle(Color(hex: 0xF3E7CC))
                    .padding(.trailing, notice.undo == nil ? 8 : 2)
                if let undo = notice.undo {
                    Button {
                        undo()
                        herald.dismiss()
                    } label: {
                        Text("UNDO")
                            .font(Typeface.display(11, .bold))
                            .tracking(1.4)
                            .foregroundStyle(Color(hex: 0xF3E7CC))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 34)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .background(Capsule().fill(Color(hex: 0x241A12)))
            .shadow(color: .black.opacity(0.3), radius: 14, y: 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
        }
    }
}
