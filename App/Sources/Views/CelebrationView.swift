import SwiftUI
import LifeEngine

/// The one moment the app is allowed to be loud. A fact became true.
struct CelebrationView: View {
    @Environment(\.dismiss) private var dismiss
    let path: Path
    let milestone: Milestone
    @State private var grown = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: path.glyph)
                .font(.system(size: 96))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, value: grown)
                .scaleEffect(grown ? 1 : 0.6)
                .animation(.spring(duration: 0.7, bounce: 0.4), value: grown)
            Text("Milestone").font(.caption.weight(.bold)).textCase(.uppercase).tracking(1).foregroundStyle(.secondary)
            Text(milestone.text).font(.title.bold()).multilineTextAlignment(.center).padding(.horizontal, 24)
            Text(path.isEvolved ? "\(path.name) has evolved." : "\(path.identity). \(path.name) is evolving.")
                .foregroundStyle(.secondary)
            Spacer()
            Button { dismiss() } label: { Text("Continue").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large).padding(24)
        }
        .sensoryFeedback(.success, trigger: grown)
        .onAppear { grown = true }
    }
}
