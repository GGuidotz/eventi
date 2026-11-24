import SwiftUI
import AppKit

struct SettingsView: View {
    static let size = CGSize(width: 480, height: 560)

    @ObservedObject var model = AppModel.shared
    @AppStorage(EventBuilder.defaultDurationKey) private var duration = 60
    @AppStorage(GemmaEngine.modelDefaultsKey) private var modelPath = ""
    @AppStorage("appLanguage") private var languageRaw = AppLanguage.system.rawValue
    @State private var refresh = 0

    var body: some View {
        SGPage(topInset: SG.Space.l, hasTabBar: false) {
            SGSection(L("Motore")) {
                SGMenuRow(L("Motore predefinito"), selection: Binding(get: { model.choice }, set: { model.choice = $0 }),
                          options: EngineChoice.allCases.map { (value: $0, title: model.title($0)) })
                SGDivider()
                status(L("Apple Intelligence"), ok: AppleAvailability.isAvailable,
                       okText: L("disponibile"), koText: L("non disponibile: attivala in Impostazioni di Sistema"))
                SGDivider()
                status("llama.cpp", ok: GemmaEngine.findBinary() != nil,
                       okText: L("trovato"), koText: L("non trovato: brew install llama.cpp"))
                SGDivider()
                status(L("Modello Gemma"), ok: GemmaEngine.findModel() != nil,
                       okText: (GemmaEngine.findModel() as NSString?)?.lastPathComponent ?? "",
                       koText: L("non trovato (Cotypist o Type with me)")) {
                    Button(L("Scegli…")) { chooseModel() }.buttonStyle(.sgSecondary)
                }
                .id(refresh)
            }
            SGSection(L("Eventi")) {
                SGLabeledRow {
                    Text(L("Durata se manca la fine: %d min", duration))
                } trailing: {
                    Stepper("", value: $duration, in: 15...480, step: 15).labelsHidden()
                }
            }
            SGSection(L("Lingua")) {
                SGMenuRow(L("Lingua"), selection: $languageRaw,
                          options: AppLanguage.allCases.map { (value: $0.rawValue, title: $0.title) })
            }
            SGSection(L("Aspetto")) {
                SGAccentRow(L("Colore d'accento"),
                            options: (app: L("Colore dell'app"), system: L("Colore di sistema"), custom: L("Personalizzato")),
                            appDefault: .eventi)
            }
        }
        .onChange(of: languageRaw) { _, v in Localization.language = AppLanguage(rawValue: v) ?? .system }
        .background(SGWindowBackground().ignoresSafeArea())
        .sguardoAccent(default: .eventi)
        .frame(width: Self.size.width, height: Self.size.height)
    }

    /// Una riga di stato: segno verde o arancione, nome, dettaglio sotto e, se serve, un'azione a destra.
    private func status<Action: View>(_ name: String, ok: Bool, okText: String, koText: String,
                                      @ViewBuilder action: () -> Action) -> some View {
        SGLabeledRow {
            HStack(spacing: 10) {
                Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(ok ? SG.Status.success : SG.Status.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                    Text(ok ? okText : koText)
                        .font(SG.Font.caption).foregroundStyle(SG.Ink.secondary)
                        .lineLimit(2).truncationMode(.middle)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } trailing: {
            action()
        }
    }

    private func status(_ name: String, ok: Bool, okText: String, koText: String) -> some View {
        status(name, ok: ok, okText: okText, koText: koText) { EmptyView() }
    }

    private func chooseModel() {
        let p = NSOpenPanel()
        p.allowsMultipleSelection = false
        p.canChooseDirectories = false
        if p.runModal() == .OK, let u = p.url { modelPath = u.path; refresh += 1 }
    }
}
