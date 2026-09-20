import SwiftUI

/// Provider, key, model. Pushed from Settings, or shown once as a sheet after onboarding when no key is saved.
struct KeySetupView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.talkKey) private var talk = false
    var prompt = false

    @State private var provider = Prefs.provider
    @State private var model = Prefs.model
    @State private var key = ""
    @State private var stored = false
    @State private var testing = false
    @State private var verdict: String?

    var body: some View {
        PixelList {
            Section {
                Text("Bring your own key. The app talks to the model you pay for, nothing in between. The key stays in this phone's keychain.")
                    .pixelHelper()
            }
            Section("Provider") {
                PixelChoices(title: "Provider", selection: $provider,
                             options: Provider.allCases.map { ($0.label, $0) })
                Link(destination: provider.keysURL) {
                    Label("Get a key from \(provider.label)", systemImage: "arrow.up.right.square")
                }
            }
            Section("Key") {
                SecureField(stored ? "A key is saved. Paste another to replace it." : provider.keyPlaceholder, text: $key)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField("Model", text: $model)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Section {
                Button(testing ? "Asking the model" : "Test") { test() }
                    .disabled(testing || effectiveKey.isEmpty)
                if let verdict {
                    Text(verdict).pixelHelper()
                }
            }
            Text("One tiny request. A fraction of a cent.").pixelHelper()
            if stored {
                Section {
                    Button("Remove key", role: .destructive) {
                        KeyStore.delete(provider.rawValue)
                        stored = false
                        key = ""
                        verdict = nil
                    }
                }
            }
        }
        .navigationTitle("Model")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            PixelToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }.disabled(effectiveKey.isEmpty)
            }
            if prompt {
                PixelToolbarItem(placement: .cancellationAction) { Button("Later") { dismiss() } }
            }
        }
        .onAppear { stored = KeyStore.read(provider.rawValue) != nil }
        .onChange(of: provider) { old, new in
            if model.isEmpty || model == old.defaultModel { model = new.defaultModel }
            key = ""
            verdict = nil
            stored = KeyStore.read(new.rawValue) != nil
        }
    }

    private var effectiveKey: String {
        let typed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? (KeyStore.read(provider.rawValue) ?? "") : typed
    }

    private var effectiveModel: String {
        let m = model.trimmingCharacters(in: .whitespaces)
        return m.isEmpty ? provider.defaultModel : m
    }

    private func test() {
        testing = true
        verdict = nil
        let probe = CloudPathModel(provider: provider, key: effectiveKey, model: effectiveModel)
        Task {
            defer { testing = false }
            do {
                let turn = try await probe.respond([ChatMessage(role: .user, text: "Testing the connection. Ask me your first question.")])
                verdict = "\(effectiveModel) answered: \(turn.question)"
            } catch let e as TalkError {
                verdict = e.sentence
            } catch {
                verdict = TalkError.unreadable.sentence
            }
        }
    }

    private func save() {
        KeyStore.write(effectiveKey, account: provider.rawValue)
        UserDefaults.standard.set(provider.rawValue, forKey: Prefs.providerKey)
        UserDefaults.standard.set(effectiveModel, forKey: Prefs.modelKey)
        talk = true
        dismiss()
    }
}
