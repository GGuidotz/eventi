// Motore Gemma 1B: usa il modello GGUF già presente sul Mac (Cotypist / Type with me) tramite llama.cpp, chiamato come
// processo separato (licenza MIT, non incluso). Niente rete, niente copie del modello. L'output è vincolato da una
// grammatica GBNF, quindi è sempre JSON valido nei cinque campi.

import Foundation

struct GemmaEngine: EventEngine {
    var name: String { "Gemma 1B" }
    var trustsTitles: Bool { false }
    let binary: String
    let model: String

    enum Failure: LocalizedError {
        case timeout, failed(Int32)
        var errorDescription: String? {
            switch self {
            case .timeout: L("tempo scaduto")
            case .failed(let c): L("errore di llama.cpp (%d)", Int(c))
            }
        }
    }

    // MARK: Ricerca di modello e programma

    static var modelDefaultsKey: String { "gemmaModelPath" }

    static func findModel() -> String? {
        let fm = FileManager.default
        if let p = UserDefaults.standard.string(forKey: modelDefaultsKey), fm.fileExists(atPath: p) { return p }
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        var found: [String] = []
        for sub in ["app.cotypist.Cotypist/Models", "TypeWithMe/Models", "Cotypist/Models"] {
            let dir = support.appendingPathComponent(sub)
            if let files = try? fm.contentsOfDirectory(atPath: dir.path) {
                found += files.filter { $0.lowercased().hasSuffix(".gguf") && $0.lowercased().contains("gemma") }
                    .map { dir.appendingPathComponent($0).path }
            }
        }
        // Meglio un modello piccolo: 1b prima di tutto.
        return found.sorted { ($0.contains("1b") ? 0 : 1, $0) < ($1.contains("1b") ? 0 : 1, $1) }.first
    }

    static func findBinary() -> String? {
        let fm = FileManager.default
        for p in ["/opt/homebrew/bin/llama-completion", "/usr/local/bin/llama-completion"]
        where fm.isExecutableFile(atPath: p) { return p }
        return nil
    }

    static func make() -> GemmaEngine? {
        guard let b = findBinary(), let m = findModel() else { return nil }
        return GemmaEngine(binary: b, model: m)
    }

    // MARK: Prompt

    static let grammar = #"""
    root ::= "[" ws ev (ws "," ws ev)* ws "]"
    ev ::= "{" ws "\"titolo\":" ws str "," ws "\"luogo\":" ws str "," ws "\"data\":" ws str "," ws "\"inizio\":" ws str "," ws "\"fine\":" ws str ws "}"
    str ::= "\"" [^"\\\n]* "\""
    ws ::= [ \n]*
    """#

    static func prompt(window: String, today: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEEE d MMMM yyyy"
        let t = EventBuilder.dayString(today)
        return """
        Estrai gli eventi dal testo in JSON. Campi: titolo, luogo, data (AAAA-MM-GG), inizio e fine (HH:MM). Stringa vuota se un campo manca. Oggi è \(f.string(from: today)) (\(t)).

        Testo: Ciao Marta, riunione di progetto giovedì 20 novembre 2026 alle 15:00 in sala Rossi, finiamo verso le 16:30.
        JSON: [{"titolo":"Riunione di progetto","luogo":"Sala Rossi","data":"2026-11-20","inizio":"15:00","fine":"16:30"}]

        Testo: Cena con Luca il 5 dicembre 2026 ore 20 al ristorante Nexa, Milano.
        JSON: [{"titolo":"Cena con Luca","luogo":"Ristorante Nexa, Milano","data":"2026-12-05","inizio":"20:00","fine":""}]

        Testo: Workshop pratico lo stesso giorno 14:00-17:00 aula 3. Il corso di Studio Rossi inizia il 3 febbraio 2027.
        JSON: [{"titolo":"Workshop pratico","luogo":"Aula 3","data":"","inizio":"14:00","fine":"17:00"},{"titolo":"Corso di Studio Rossi","luogo":"","data":"2027-02-03","inizio":"","fine":""}]

        Testo: \(window.replacingOccurrences(of: "\n", with: " "))
        JSON:
        """
    }

    // MARK: Esecuzione

    func extract(window: String, today: Date) async throws -> [RawEvent] {
        let prompt = Self.prompt(window: window, today: today)
        let binary = self.binary, model = self.model
        let out = try await Task.detached(priority: .userInitiated) { () -> String in
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("eventi-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: dir) }
            let pf = dir.appendingPathComponent("p.txt"), gf = dir.appendingPathComponent("g.gbnf")
            try prompt.write(to: pf, atomically: true, encoding: .utf8)
            try Self.grammar.write(to: gf, atomically: true, encoding: .utf8)

            let p = Process()
            p.executableURL = URL(fileURLWithPath: binary)
            p.arguments = ["-m", model, "-f", pf.path, "--grammar-file", gf.path, "-n", "400", "--temp", "0",
                           "-c", "4096", "-no-cnv", "--no-display-prompt", "-ngl", "99"]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = FileHandle.nullDevice
            try p.run()
            let killer = DispatchWorkItem { if p.isRunning { p.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + 90, execute: killer)
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            killer.cancel()
            if p.terminationReason == .uncaughtSignal { throw Failure.timeout }
            if p.terminationStatus != 0 && data.isEmpty { throw Failure.failed(p.terminationStatus) }
            return String(decoding: data, as: UTF8.self)
        }.value
        if ProcessInfo.processInfo.environment["EVENTI_DEBUG"] != nil { FileHandle.standardError.write(Data(("[gemma] " + out + "\n").utf8)) }
        return Self.parse(out)
    }

    static func parse(_ output: String) -> [RawEvent] {
        // L'output finisce con "[end of text]": prendo dalla prima "[" alla prima "]" dopo l'ultima "}".
        guard let a = output.firstIndex(of: "["), let lastBrace = output.lastIndex(of: "}"),
              let b = output[lastBrace...].firstIndex(of: "]"), a < b,
              let data = String(output[a...b]).data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.map {
            RawEvent(title: $0["titolo"] as? String ?? "", location: $0["luogo"] as? String ?? "",
                     date: $0["data"] as? String ?? "", start: $0["inizio"] as? String ?? "", end: $0["fine"] as? String ?? "")
        }
    }
}
