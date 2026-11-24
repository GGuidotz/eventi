import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var text = ""
    @Published var events: [EventDraft] = []
    @Published var isWorking = false
    @Published var progress: (Int, Int) = (0, 0)
    @Published var message = ""
    @Published var notes: [String] = []
    @Published var fileNames: [String] = []
    @Published var hasExtracted = false

    @AppStorage("engineChoice") var engineRaw = EngineChoice.apple.rawValue
    var choice: EngineChoice {
        get { EngineChoice(rawValue: engineRaw) ?? .apple }
        set { objectWillChange.send(); engineRaw = newValue.rawValue }
    }

    private var task: Task<Void, Never>?

    var includedCount: Int { events.filter(\.include).count }

    // MARK: Ingresso

    func add(urls: [URL]) {
        Task {
            for u in urls {
                do {
                    let t = try await DocumentReader.read(u)
                    append(t, name: u.lastPathComponent)
                } catch {
                    message = error.localizedDescription
                }
            }
            if !text.isEmpty { extract() }
        }
    }

    func add(text t: String) {
        append(t, name: nil)
    }

    private func append(_ t: String, name: String?) {
        text += (text.isEmpty ? "" : "\n\n") + t
        if let name { fileNames.append(name) }
    }

    func pasteFromClipboard() {
        if let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            add(urls: urls); return
        }
        if let img = NSImage(pasteboard: .general), let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            Task {
                if let t = try? await DocumentReader.ocr(cg), !t.isEmpty { append(t, name: L("Immagine incollata")); extract() }
            }
            return
        }
        if let s = NSPasteboard.general.string(forType: .string), !s.isEmpty { add(text: s); extract() }
    }

    func clear() {
        task?.cancel()
        text = ""; events = []; fileNames = []; notes = []; message = ""; hasExtracted = false; isWorking = false
    }

    // MARK: Estrazione

    func extract() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { message = L("Incolla un testo o trascina un documento."); return }
        task?.cancel()
        isWorking = true; message = ""; notes = []
        let (engine, used) = EngineFactory.resolve(choice)
        if used != choice { notes.append(L("%@ non è disponibile: uso %@.", title(choice), title(used))) }
        task = Task {
            let result = await Pipeline.run(text: t, engine: engine) { [weak self] i, n in
                Task { @MainActor in self?.progress = (i, n) }
            }
            if Task.isCancelled { return }
            events = result.events
            notes += result.notes
            hasExtracted = true
            isWorking = false
            if events.isEmpty { message = L("Nessun evento trovato.") }
        }
    }

    func title(_ c: EngineChoice) -> String {
        switch c {
        case .apple: "Apple Intelligence"
        case .gemma: "Gemma 1B"
        case .rules: L("Regole")
        }
    }

    // MARK: Uscita

    func saveICS() {
        let sel = events.filter(\.include)
        guard !sel.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "ics") ?? .data]
        panel.nameFieldStringValue = sel.count == 1 ? safeName(sel[0].title) + ".ics" : L("Eventi") + ".ics"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try ICS.make(sel).write(to: url, atomically: true, encoding: .utf8); message = L("Salvato: %@", url.lastPathComponent) }
        catch { message = error.localizedDescription }
    }

    /// Un file per evento (nome numerato e leggibile), in una cartella a scelta.
    func saveSeparate() {
        let sel = events.filter(\.include)
        guard !sel.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = L("Salva qui")
        guard panel.runModal() == .OK, let dir = panel.url else { return }
        do {
            for f in ICS.files(sel) { try f.content.write(to: dir.appendingPathComponent(f.name), atomically: true, encoding: .utf8) }
            message = L("Salvati %d file", sel.count)
        } catch { message = error.localizedDescription }
    }

    func openInCalendar() {
        let sel = events.filter(\.include)
        guard !sel.isEmpty else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Eventi-\(UUID().uuidString.prefix(6)).ics")
        do {
            try ICS.make(sel).write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(url)
        } catch { message = error.localizedDescription }
    }

    private func safeName(_ s: String) -> String {
        let bad = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        return s.components(separatedBy: bad).joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
}
