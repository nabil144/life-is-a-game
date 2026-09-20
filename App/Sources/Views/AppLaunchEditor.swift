import SwiftUI
import LifeEngine

struct AppLaunchEditor: View {
    @Binding var launch: AppLaunch?

    private var method: Binding<String> {
        Binding(get: { launch?.kind.rawValue ?? "none" }, set: { value in
            launch = AppLaunch.Kind(rawValue: value).map { AppLaunch(kind: $0) }
        })
    }
    private func field(_ key: WritableKeyPath<AppLaunch, String>) -> Binding<String> {
        Binding(get: { launch?[keyPath: key] ?? "" }, set: { launch?[keyPath: key] = $0 })
    }
    var body: some View {
        Section("Open an app (optional)") {
            PixelMenuPicker("Launch with", selection: method, options: [
                .init(title: "None", value: "none"),
                .init(title: "Apple Shortcut", value: "shortcut"),
                .init(title: "App link", value: "appLink")
            ])
            if let launch {
                TextField("App name (optional)", text: field(\.name))
                TextField(launch.kind == .shortcut ? "Shortcut name" : "App link", text: field(\.target))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(launch.kind == .appLink ? .URL : .default)
                if launch.url != nil { AppLaunchButton(launch: launch, testing: true) }
            }
        }
        if let launch {
            Text(launch.kind == .shortcut
                 ? "In Apple Shortcuts, create a shortcut with the Open App action, choose your app, and enter that shortcut’s name here. Test it before saving."
                 : "Paste a launch link supported by the app. Test it before saving; some apps open through Apple Shortcuts instead.")
                .font(.caption).foregroundStyle(Color.gray.opacity(0.85))
                .listRowBackground(Color.clear)
            if launch.kind == .shortcut {
                Link("Open Shortcuts", destination: URL(string: "shortcuts://")!)
                    .font(.caption).listRowBackground(Color.clear)
            }
            if launch.url == nil && !launch.target.isEmpty {
                Text("Enter a valid app link or choose None to remove it.")
                    .font(.caption).foregroundStyle(Ink.muted).listRowBackground(Color.clear)
            }
        }
    }
}

struct AppLaunchButton: View {
    @Environment(\.openURL) private var openURL
    let launch: AppLaunch
    var testing = false
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                failed = false
                guard let url = launch.url else { failed = true; return }
                openURL(url) { accepted in failed = !accepted }
            } label: {
                Label(testing ? "Test opening app" : launch.label, systemImage: "arrow.up.right.square")
            }
            .buttonStyle(PixelButtonStyle(compact: true))
            if failed {
                Text("Couldn’t open it. Check that the app is installed and the link is correct.")
                    .font(.caption).foregroundStyle(Ink.muted)
            }
        }
    }
}
