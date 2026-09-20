import SwiftUI
import UIKit

/// Native swipe actions accept an image, so draw the pixel badge once at screen scale.
@MainActor
enum PixelSwipeArtwork {
    static let done = badge(pixels: ["0000011", "0000110", "1001100", "1111000", "0110000"])
    static let cancel = badge(pixels: ["1100011", "0110110", "0011100", "0110110", "1100011"])

    private static func badge(pixels: [String]) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 36, height: 36)).image { renderer in
            let context = renderer.cgContext
            let panel = PixelPanel().path(in: CGRect(x: 1, y: 1, width: 34, height: 34)).cgPath
            context.setFillColor(UIColor(Ink.card).cgColor)
            context.addPath(panel)
            context.fillPath()
            context.setStrokeColor(UIColor(Ink.brass).cgColor)
            context.setLineWidth(2)
            context.addPath(panel)
            context.strokePath()
            context.setFillColor(UIColor(Ink.brass).cgColor)
            for (y, row) in pixels.enumerated() {
                for (x, pixel) in row.enumerated() where pixel == "1" {
                    context.fill(CGRect(x: 8 + x * 3, y: 11 + y * 3, width: 3, height: 3))
                }
            }
        }.withRenderingMode(.alwaysOriginal)
    }
}

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
    var fillsWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(compact ? .caption : .subheadline, design: .monospaced).weight(.bold))
            .padding(.horizontal, compact ? 8 : 12)
            .frame(minWidth: 28, maxWidth: fillsWidth ? .infinity : nil, minHeight: compact ? 30 : 44)
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
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
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
        .toggleStyle(PixelToggleStyle())
        .textFieldStyle(.plain)
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
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
        .listRowBackground(rowBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    @ViewBuilder private var rowBackground: some View {
        if fillsRow {
            PixelPanel().fill(Ink.card)
                .overlay(PixelPanel().stroke(Ink.line, lineWidth: 1))
                .padding(.vertical, 3)
        } else { Color.clear }
    }

    private var choices: some View {
        ForEach(options.indices, id: \.self) { index in
            Button { selection = options[index].1 } label: {
                Text(options[index].0).fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(PixelButtonStyle(selected: selection == options[index].1, compact: true, fillsWidth: fillsRow))
            .accessibilityAddTraits(selection == options[index].1 ? .isSelected : [])
        }
    }
}

/// A pixel field that opens a themed choice list instead of a system menu.
struct PixelOption<Value: Hashable> {
    let title: String
    let value: Value
    var glyph: String? = nil
}

struct PixelMenuPicker<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [PixelOption<Value>]
    @State private var expanded = false

    init(_ title: String, selection: Binding<Value>, options: [PixelOption<Value>]) {
        self.title = title
        self._selection = selection
        self.options = options
    }

    private var selected: PixelOption<Value>? { options.first { $0.value == selection } }

    var body: some View {
        Button { expanded = true } label: {
            HStack(spacing: 8) {
                Text(title).foregroundStyle(Ink.muted)
                Spacer(minLength: 8)
                if let glyph = selected?.glyph { Image(systemName: glyph) }
                Text(selected?.title ?? "Choose").multilineTextAlignment(.trailing)
                Image(systemName: "chevron.down").font(.caption.bold())
            }
            .font(.subheadline)
            .foregroundStyle(Ink.brass)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selected?.title ?? "Choose")
        .sheet(isPresented: $expanded) {
            VStack(spacing: 8) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    Button("Close") { expanded = false }
                        .buttonStyle(PixelButtonStyle(compact: true))
                }.padding(.horizontal, 12)
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(options.indices, id: \.self) { index in
                            let option = options[index]
                            Button {
                                selection = option.value
                                expanded = false
                            } label: {
                                HStack {
                                    if let glyph = option.glyph { Image(systemName: glyph) }
                                    Text(option.title).multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                    if option.value == selection { Image(systemName: "checkmark") }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(PixelButtonStyle(selected: option.value == selection, fillsWidth: true))
                            .accessibilityAddTraits(option.value == selection ? .isSelected : [])
                        }
                    }.padding(.horizontal, 12)
                }.scrollIndicators(.hidden)
            }
            .padding(.top, 12)
            .foregroundStyle(Ink.words)
            .background(Ink.ground)
            .presentationBackground(Ink.ground)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
    }
}

struct PixelToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 12) {
                configuration.label.foregroundStyle(Ink.words)
                Spacer(minLength: 8)
                Text(configuration.isOn ? "ON" : "OFF")
                    .font(.caption.monospaced().bold())
                    .foregroundStyle(configuration.isOn ? Ink.ground : Ink.muted)
                    .frame(width: 48, height: 28)
                    .background(configuration.isOn ? Ink.brass : Ink.ground, in: PixelPanel())
                    .overlay(PixelPanel().stroke(Ink.brass.opacity(0.65), lineWidth: 1))
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}

/// Prevent iOS from placing a glass capsule behind our own button outline.
struct PixelToolbarItem<Content: View>: ToolbarContent {
    let placement: ToolbarItemPlacement
    @ViewBuilder var content: Content

    var body: some ToolbarContent {
        ToolbarItem(placement: placement) {
            content.buttonStyle(PixelButtonStyle(compact: true))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .sharedBackgroundVisibility(.hidden)
    }
}

struct PixelActionMenu<Actions: View, Label: View>: View {
    @ViewBuilder var content: Actions
    @ViewBuilder var label: Label
    @State private var expanded = false

    var body: some View {
        Button { expanded = true } label: { label }
            .sheet(isPresented: $expanded) {
                VStack(spacing: 8) {
                    HStack {
                        label.font(.headline)
                        Spacer()
                        Button("Close") { expanded = false }
                            .buttonStyle(PixelButtonStyle(compact: true))
                    }
                    ScrollView {
                        VStack(spacing: 6) {
                            content.buttonStyle(PixelMenuActionStyle(close: { expanded = false }))
                        }
                    }.scrollIndicators(.hidden)
                }
                .padding(12)
                .foregroundStyle(Ink.words)
                .background(Ink.ground)
                .presentationBackground(Ink.ground)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
            }
    }
}

private struct PixelMenuActionStyle: PrimitiveButtonStyle {
    var close: () -> Void
    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role) {
            close()
            configuration.trigger()
        } label: {
            configuration.label.frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PixelButtonStyle(fillsWidth: true))
    }
}

/// Keep the form row pixel-styled; use the accessible date wheel only while editing.
struct PixelDatePicker: View {
    let title: String
    @Binding var selection: Date
    let range: ClosedRange<Date>
    let components: DatePickerComponents
    @State private var expanded = false

    init(_ title: String, selection: Binding<Date>, in range: ClosedRange<Date> = Date.distantPast...Date.distantFuture,
         displayedComponents: DatePickerComponents) {
        self.title = title
        self._selection = selection
        self.range = range
        self.components = displayedComponents
    }
    init(_ title: String, selection: Binding<Date>, in range: PartialRangeFrom<Date>, displayedComponents: DatePickerComponents) {
        self.init(title, selection: selection, in: range.lowerBound...Date.distantFuture, displayedComponents: displayedComponents)
    }
    init(_ title: String, selection: Binding<Date>, in range: PartialRangeThrough<Date>, displayedComponents: DatePickerComponents) {
        self.init(title, selection: selection, in: Date.distantPast...range.upperBound, displayedComponents: displayedComponents)
    }

    var body: some View {
        Button { expanded = true } label: {
            HStack(spacing: 8) {
                Text(title).foregroundStyle(Ink.muted)
                Spacer(minLength: 8)
                Text(selection.formatted(date: components.contains(.date) ? .abbreviated : .omitted,
                                         time: components.contains(.hourAndMinute) ? .shortened : .omitted))
                    .multilineTextAlignment(.trailing)
                Image(systemName: "calendar").font(.caption)
            }
            .font(.subheadline)
            .foregroundStyle(Ink.brass)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $expanded) {
            VStack(spacing: 8) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    Button("Done") { expanded = false }
                        .buttonStyle(PixelButtonStyle(compact: true))
                }
                DatePicker(title, selection: $selection, in: range, displayedComponents: components)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                Spacer(minLength: 0)
            }
            .padding(12)
            .foregroundStyle(Ink.words)
            .background(Ink.ground)
            .presentationBackground(Ink.ground)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
    }
}
