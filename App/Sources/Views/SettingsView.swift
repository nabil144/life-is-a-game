import SwiftUI
import LifeEngine

struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(Notifier.self) private var notifier
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.morningKey) private var morningHour = 10
    @AppStorage(Prefs.eveningKey) private var eveningHour = 19
    @AppStorage(Prefs.todayStyleKey) private var style: TodayStyle = .objectiveAndPaths
    @AppStorage(Prefs.talkKey) private var talk = false
    @State private var authorized = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                notificationsSection
                styleSection
                talkSection
                upcomingSection
                dataSection
                Section {
                    Text("One objective a day. Progress that cannot be lost.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))")
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { authorized = await notifier.authorized() }
            .onChange(of: morningHour) { _, _ in replan() }
            .onChange(of: eveningHour) { _, _ in replan() }
        }
    }

    private func replan() {
        Task { await LifeIsAGameApp.replan(store: store, notifier: notifier) }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            if authorized {
                Label("Objectives can find you", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            } else {
                Button("Allow notifications") {
                    Task { authorized = await notifier.requestPermission() }
                }
            }
            HourPicker(title: "Morning objectives at", hours: 6..<13, selection: $morningHour)
            HourPicker(title: "Evening objectives at", hours: 16..<23, selection: $eveningHour)
        }
    }

    private var styleSection: some View {
        Section("Today screen (prototype weeks)") {
            Picker("Style", selection: $style) {
                ForEach(TodayStyle.allCases) { s in
                    Text(s.label).tag(s)
                }
            }
            .pickerStyle(.inline)
        }
    }

    private var talkSection: some View {
        Section {
            let ready = Talk.state.reason == nil
            NavigationLink {
                KeySetupView()
            } label: {
                Label(ready ? "\(Prefs.provider.label), \(Prefs.model)" : "Add an API key", systemImage: "key")
            }
            if ready {
                Toggle("Start new paths by talking", isOn: $talk)
            }
        } header: {
            Text("New paths")
        } footer: {
            Text("Your own key, your own model. The model asks, you answer, it writes down your words. Either way, the New path screen offers the other.")
        }
    }

    private var upcomingSection: some View {
        let up = store.upcoming()
        return Section("Coming up") {
            if up.isEmpty {
                Text("Nothing planned yet.").foregroundStyle(.secondary)
            }
            ForEach(up, id: \.self) { o in
                UpcomingRow(objective: o)
            }
        }
    }

    private var dataSection: some View {
        Section {
            if store.keepsACopy {
                Label("A copy lives in Files. New installs can pick that folder and come back.", systemImage: "checkmark.icloud")
                    .foregroundStyle(.secondary)
                Button("Forget the folder", role: .destructive) { store.forgetCopy() }
            } else {
                KeepCopyButton()
            }
            Button("Save a copy now") { exportWorld() }
            if let url = exportURL {
                ShareLink(item: url) {
                    Label("Share world.json", systemImage: "square.and.arrow.up")
                }
            }
            RestoreFileButton()
        } header: {
            Text("Your data")
        } footer: {
            Text("Cmd+R keeps what is on the phone. Deleting the app, or installing it under a new name, does not. The Files copy is the one that survives.")
        }
    }

    private func exportWorld() {
        guard let data = try? store.exportWorld() else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("world.json")
        try? data.write(to: url)
        exportURL = url
    }
}

private struct HourPicker: View {
    let title: String
    let hours: Range<Int>
    @Binding var selection: Int

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(Array(hours), id: \.self) { h in
                Text("\(h):00").tag(h)
            }
        }
    }
}

private struct UpcomingRow: View {
    @Environment(Store.self) private var store
    let objective: Objective

    var body: some View {
        if let (p, n) = store.node(objective.nodeID) {
            HStack {
                Text(objective.day.description)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text("\(p.identity): \(n.title)")
                Spacer()
                Text(objective.window.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
