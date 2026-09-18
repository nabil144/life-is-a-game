import SwiftUI

/// Two square steps at each corner, drawn natively so the edges stay crisp.
struct PixelPanel: Shape {
    func path(in rect: CGRect) -> SwiftUI.Path {
        let s = min(4, min(rect.width, rect.height) / 6)
        let x = rect.minX, y = rect.minY, r = rect.maxX, b = rect.maxY
        let points: [CGPoint] = [
            .init(x: x + 2*s, y: y), .init(x: r - 2*s, y: y),
            .init(x: r - 2*s, y: y+s), .init(x: r-s, y: y+s),
            .init(x: r-s, y: y+2*s), .init(x: r, y: y+2*s),
            .init(x: r, y: b-2*s), .init(x: r-s, y: b-2*s),
            .init(x: r-s, y: b-s), .init(x: r-2*s, y: b-s),
            .init(x: r-2*s, y: b), .init(x: x+2*s, y: b),
            .init(x: x+2*s, y: b-s), .init(x: x+s, y: b-s),
            .init(x: x+s, y: b-2*s), .init(x: x, y: b-2*s),
            .init(x: x, y: y+2*s), .init(x: x+s, y: y+2*s),
            .init(x: x+s, y: y+s), .init(x: x+2*s, y: y+s),
        ]
        var path = SwiftUI.Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}

struct PixelButtonStyle: ButtonStyle {
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .monospaced).weight(.bold))
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .foregroundStyle(selected ? Ink.ground : Ink.brass)
            .background(selected ? Ink.brass : Ink.card, in: PixelPanel())
            .overlay(PixelPanel().stroke(Ink.brass.opacity(0.65), lineWidth: 1))
            .offset(y: configuration.isPressed ? 2 : 0)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// A deliberately coarse sprite, rather than a smoothed system symbol.
struct PixelQuestMark: View {
    var routine = false
    private var rows: [String] {
        routine ? ["0011100", "0100010", "1000001", "1001001", "1000101", "0100010", "0011100"]
                : ["0001000", "0011100", "0110110", "1100011", "0110110", "0011100", "0001000"]
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { y in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { x in
                        Rectangle().fill(Array(rows[y])[x] == "1" ? Ink.brass : .clear)
                            .frame(width: 3, height: 3)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}
