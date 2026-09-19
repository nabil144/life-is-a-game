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
    @Environment(\.isEnabled) private var isEnabled
    var selected = false
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(compact ? .caption : .subheadline, design: .monospaced).weight(.bold))
            .padding(.horizontal, compact ? 8 : 12)
            .frame(minWidth: 28, minHeight: compact ? 30 : 44)
            .foregroundStyle(configuration.role == .destructive ? Color.red : (selected ? Ink.ground : Ink.brass))
            .background(selected ? Ink.brass : Ink.card, in: PixelPanel())
            .overlay(PixelPanel().stroke(Ink.brass.opacity(0.65), lineWidth: 1))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .offset(y: configuration.isPressed ? 2 : 0)
            .opacity(!isEnabled ? 0.4 : (configuration.isPressed ? 0.8 : 1))
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

/// Native list editing, navigation and form controls inside the compact pixel shell.
/// Only chrome is styled here; content keeps its normal readable type.
struct PixelList<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        List {
            content
                .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                .listRowSeparator(.hidden)
                .listRowBackground(
                    PixelPanel().fill(Ink.card)
                        .overlay(PixelPanel().stroke(Ink.line, lineWidth: 1))
                        .padding(.vertical, 3)
                )
        }
        .listStyle(.plain)
        .listRowSpacing(0)
        .listSectionSpacing(.compact)
        .contentMargins(.horizontal, 12, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .background(Ink.ground)
        .environment(\.defaultMinListRowHeight, 44)
    }
}

extension View {
    func pixelCard() -> some View {
        background(Ink.card, in: PixelPanel())
            .overlay(PixelPanel().stroke(Ink.line, lineWidth: 1))
    }
}

/// Wraps into a vertical choice list at larger text sizes instead of truncating labels.
struct PixelChoices<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [(String, Value)]
    var fillsRow = true

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { choices }
            VStack(spacing: 2) { choices }
        }
        .frame(maxWidth: fillsRow ? .infinity : nil, alignment: .center)
        .listRowBackground(Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private var choices: some View {
        ForEach(options.indices, id: \.self) { index in
            Button { selection = options[index].1 } label: {
                Text(options[index].0).fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(PixelButtonStyle(selected: selection == options[index].1, compact: true))
            .accessibilityAddTraits(selection == options[index].1 ? .isSelected : [])
        }
    }
}

/// A centered menu with its context retained above the selected value.
/// Explicitly clears PixelList's default card for this control's row only.
struct PixelMenuPicker<Value: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: Value
    let content: Content

    init(_ title: String, selection: Binding<Value>, @ViewBuilder content: () -> Content) {
        self.title = title
        self._selection = selection
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Picker(title, selection: $selection) { content }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .listRowBackground(Color.clear)
    }
}
