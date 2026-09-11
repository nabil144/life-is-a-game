import SwiftUI
import LifeEngine

struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(Notifier.self) private var notifier
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.morningKey) private var morningHour = 10
    @AppStorage(Prefs.eveningKey) private var eveningHour = 19
    @AppStorage(Prefs.todayStyleKey) private var style: TodayStyle = .objectiveAndPaths
    @State private var authorized = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section("Notifications") {
                    if authorized {
                        Label("Objectives can find you", systemImage: "checkmark.circle").foregroundStyle(.green)
                    } else {
                        Button("Allow notifications") { Task { authorized = await notifier.requestPermission() } }
                    }
                    Picker("Morning objectives at", selection: $morningHour) {
                        ForEach(6..<13, id: \.self) { Text("\($0):00").tag($0) }
                    }
                    Picker("Evening objectives at", selection: $eveningHour) {
                        ForEach(16..<23, id: \.self) { Text("\($0):00").tag($0) }
                    }
                }
                Section("Today screen (prototype weeks)") {
                    Picker("Style", selection: $style) {
                        ForEach(TodayStyle.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                }
                Section("Coming up") {
                    let up = store.upcoming()
                    if up.isEmpty { Text("Nothing planned yet.").foregroundStyle(.secondary) }
                    ForEach(up, id: \.self) { o in
                        if let (p, n) = store.node(o.nodeID) {
                            HStack {
                                Text(o.day.description).font(.caption.monospaced()).foregroundStyle(.secondary)
                                Text("\(p.identity): \(n.title)")
                                Spacer()
                                Text(o.window.rawValue).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Paths as JSON") {
                    Button("Export paths") {
                        if let data = try? store.exportBundle() {
                            let url = FileManager.default.temporaryDirectory.appendingPathComponent("paths.json")
                            try? data.write(to: url)
                            exportURL = url
                        }
                    }
                    if let url = exportURL { ShareLink(item: url) { Label("Share paths.json", systemImage: "square.and.arrow.up") } }
                }
                Section {
                    Text("One objective a day. Progress that cannot be lost.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { authorized = await notifier.authorized() }
            .onChange(of: morningHour) { _, _ in Task { await LifeIsAGameApp.replan(store: store, notifier: notifier) } }
            .onChange(of: eveningHour) { _, _ in Task { await LifeIsAGameApp.replan(store: store, notifier: notifier) } }
        }
    }
}
