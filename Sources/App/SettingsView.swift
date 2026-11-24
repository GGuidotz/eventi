import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var model = AppModel.shared
    @AppStorage(EventBuilder.defaultDurationKey) private var duration = 60
    @AppStorage(GemmaEngine.modelDefaultsKey) private var modelPath = ""
    @AppStorage("appLanguage") private var languageRaw = AppLanguage.system.rawValue
    @State private var refresh = 0

    var body: some View {
        Form {
            Section(L("Motore")) {
                Picker(L("Motore predefinito"), selection: Binding(get: { model.choice }, set: { model.choice = $0 })) {
                    ForEach(EngineChoice.allCases) { Text(model.title($0)).tag($0) }
                }
                status(L("Apple Intelligence"), ok: AppleAvailability.isAvailable,
                       okText: L("disponibile"), koText: L("non disponibile: attivala in Impostazioni di Sistema"))
                status("llama.cpp", ok: GemmaEngine.findBinary() != nil,
                       okText: L("trovato"), koText: L("non trovato: brew install llama.cpp"))
                HStack {
                    status(L("Modello Gemma"), ok: GemmaEngine.findModel() != nil,
                           okText: (GemmaEngine.findModel() as NSString?)?.lastPathComponent ?? "",
                           koText: L("non trovato (Cotypist o Type with me)"))
                    Spacer()
                    Button(L("Scegli…")) { chooseModel() }
                }
                .id(refresh)
            }
            Section(L("Eventi")) {
                Stepper(L("Durata se manca la fine: %d min", duration), value: $duration, in: 15...480, step: 15)
            }
            Section(L("Lingua")) {
                Picker(L("Lingua"), selection: $languageRaw) {
                    ForEach(AppLanguage.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .onChange(of: languageRaw) { _, v in Localization.language = AppLanguage(rawValue: v) ?? .system }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 400)
    }

    private func status(_ name: String, ok: Bool, okText: String, koText: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? Color.green : Color.orange)
            Text(name).fontWeight(.medium)
            Text(ok ? okText : koText).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
        }
        .font(.callout)
    }

    private func chooseModel() {
        let p = NSOpenPanel()
        p.allowsMultipleSelection = false
        p.canChooseDirectories = false
        if p.runModal() == .OK, let u = p.url { modelPath = u.path; refresh += 1 }
    }
}
