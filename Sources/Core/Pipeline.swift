// Pipeline di estrazione: divide il testo in finestre, chiede al motore (Apple Intelligence o Gemma) gli eventi di
// ciascuna, li controlla con le regole (date e orari scritti nel testo) e toglie i doppioni.
// I modelli piccoli reggono poco testo: per questo si lavora a finestre e non sul documento intero.

import Foundation

protocol EventEngine {
    var name: String { get }
    /// I modelli grandi possono riformulare il titolo; quelli piccoli (Gemma 1B) si ancorano alle regole.
    var trustsTitles: Bool { get }
    /// Eventi di un pezzo di testo. `today` serve a risolvere "giovedì prossimo", "domani", ecc.
    func extract(window: String, today: Date) async throws -> [RawEvent]
}

enum EngineChoice: String, CaseIterable, Identifiable {
    case apple, gemma, rules
    var id: String { rawValue }
}

struct ExtractionWindow {
    var text: String
    var rules: [RuleHit]
}

struct ExtractionResult {
    var events: [EventDraft]
    var notes: [String]
}

enum Pipeline {
    static let maxWindow = 900

    // MARK: Finestre

    static func windows(for text: String, now: Date = Date()) -> [ExtractionWindow] {
        let clean = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var out: [ExtractionWindow] = []
        let paragraphs = clean.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        for p in paragraphs {
            let hits = RuleExtractor.extract(p, now: now)
            if hits.isEmpty { continue }
            let distinctDays = Set(hits.map { EventBuilder.dayString($0.draft.start) + EventBuilder.timeString($0.draft.start) })
            if distinctDays.count <= 2 && p.count <= maxWindow {
                out.append(ExtractionWindow(text: p, rules: hits))
            } else {
                // Elenco di appuntamenti: una finestra per riga che contiene una data (con la riga prima se è un titolo).
                let lines = p.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
                var prev = ""
                for line in lines where !line.isEmpty {
                    let lh = RuleExtractor.extract(line, now: now)
                    if !lh.isEmpty {
                        let w = prev.isEmpty || prev.count > 120 ? line : prev + "\n" + line
                        out.append(ExtractionWindow(text: String(w.prefix(maxWindow)), rules: lh))
                    }
                    prev = RuleExtractor.extract(line, now: now).isEmpty ? line : ""
                }
                if lines.count == 1 && out.isEmpty { out.append(ExtractionWindow(text: String(p.prefix(maxWindow)), rules: hits)) }
            }
        }
        if out.isEmpty {
            // Nessuna data riconosciuta dalle regole: lascia provare al motore su blocchi di testo.
            var block = ""
            for p in paragraphs {
                if block.count + p.count > maxWindow, !block.isEmpty {
                    out.append(ExtractionWindow(text: block, rules: [])); block = ""
                }
                block += (block.isEmpty ? "" : "\n\n") + String(p.prefix(maxWindow))
            }
            if !block.isEmpty { out.append(ExtractionWindow(text: block, rules: [])) }
        }
        return out
    }

    // MARK: Esecuzione

    static func run(text: String, engine: EventEngine?, now: Date = Date(),
                    progress: @escaping (Int, Int) -> Void = { _, _ in }) async -> ExtractionResult {
        // Biglietti e voucher: regole dedicate (fusi orari degli aeroporti, finestre hotel), prima dei motori generici.
        let travel = TravelExtractor.extract(text, now: now)
        if !travel.events.isEmpty { return ExtractionResult(events: travel.events.sorted { $0.start < $1.start }, notes: travel.notes) }

        let wins = windows(for: text, now: now)
        var events: [EventDraft] = []
        var notes: [String] = []

        guard let engine else {
            for w in wins { events += w.rules.map(\.draft) }
            return ExtractionResult(events: finish(events), notes: notes)
        }

        for (i, w) in wins.enumerated() {
            progress(i, wins.count)
            if Task.isCancelled { break }
            do {
                let raws = try await engine.extract(window: w.text, today: now)
                let drafts = raws.compactMap { EventBuilder.make(fixDate($0, rules: w.rules), source: w.text) }
                if ProcessInfo.processInfo.environment["EVENTI_DEBUG"] != nil { FileHandle.standardError.write(Data("[pipe] raws=\(raws.count) drafts=\(drafts.count) rules=\(w.rules.count)\n".utf8)) }
                events += merge(model: drafts, rules: w.rules, source: w.text, trusted: engine.trustsTitles)
            } catch {
                notes.append("\(engine.name): \(error.localizedDescription)")
                events += w.rules.map(\.draft)   // ripiego su questa finestra
            }
        }
        progress(wins.count, wins.count)
        return ExtractionResult(events: finish(events), notes: Array(Set(notes)).sorted())
    }

    /// Se il modello non ha messo la data, la prende dalla regola della finestra (se è una sola).
    private static func fixDate(_ r: RawEvent, rules: [RuleHit]) -> RawEvent {
        var r = r
        if EventBuilder.parseDay(r.date, EventBuilder.calendar()) == nil, let h = rules.first, rules.count == 1 {
            r.date = EventBuilder.dayString(h.draft.start)
            if r.start.isEmpty, !h.draft.allDay { r.start = EventBuilder.timeString(h.draft.start) }
        }
        return r
    }

    // MARK: Controllo con le regole

    static func merge(model: [EventDraft], rules: [RuleHit], source: String, trusted: Bool) -> [EventDraft] {
        if model.isEmpty { return rules.map(\.draft) }
        let cal = EventBuilder.calendar()
        var out: [EventDraft] = []
        var usedRules = Set<Int>()

        for var m in model {
            // Giorno inventato (es. "lo stesso giorno" letto male): se l'ora coincide con una regola, vale il giorno scritto nel testo.
            if !rules.isEmpty, !rules.contains(where: { cal.isDate($0.draft.start, inSameDayAs: m.start) }) {
                let hm = cal.dateComponents([.hour, .minute], from: m.start)
                let same = rules.filter { !$0.draft.allDay && cal.dateComponents([.hour, .minute], from: $0.draft.start) == hm && !m.allDay }
                let days = Set(rules.map { cal.startOfDay(for: $0.draft.start) })
                if same.count == 1 || (days.count == 1 && rules.count == 1) {
                    let r = (same.first ?? rules[0]).draft
                    let delta = cal.startOfDay(for: r.start).timeIntervalSince(cal.startOfDay(for: m.start))
                    m.start = cal.date(byAdding: .day, value: Int((delta / 86400).rounded()), to: m.start) ?? m.start
                    m.end = cal.date(byAdding: .day, value: Int((delta / 86400).rounded()), to: m.end) ?? m.end
                }
            }
            if let idx = rules.firstIndex(where: { r in
                cal.isDate(r.draft.start, inSameDayAs: m.start) && (m.allDay || r.draft.allDay || timeClose(m.start, r.draft.start))
            }) ?? rules.firstIndex(where: { cal.isDate($0.draft.start, inSameDayAs: m.start) }) {
                let r = rules[idx]
                usedRules.insert(idx)
                if !r.draft.allDay {
                    // L'ora scritta nel testo vince su quella del modello.
                    m.allDay = false
                    m.start = r.draft.start
                    m.end = r.explicitEnd ? r.draft.end : (m.end > m.start && !m.allDay ? max(m.end, r.draft.end) : r.draft.end)
                    if !r.explicitEnd, m.end <= m.start { m.end = r.draft.end }
                }
                if r.draft.allDay, !m.allDay, !timeAppears(m.start, in: source) {
                    m.allDay = true; m.start = cal.startOfDay(for: m.start); m.end = m.start   // ora inventata dal modello
                }
                if m.location.isEmpty || !grounded(m.location, in: source) { m.location = r.draft.location }
                if !trusted, !r.draft.title.isEmpty, overlap(m.title, r.draft.title) == 0 || !grounded(m.title, in: source) {
                    m.title = r.draft.title
                }
            } else {
                // Nessuna regola corrisponde: orario e luogo vanno comunque verificati sul testo.
                if !m.allDay, !timeAppears(m.start, in: source) {
                    let cal = EventBuilder.calendar()
                    m.allDay = true; m.start = cal.startOfDay(for: m.start); m.end = m.start
                }
                if !grounded(m.location, in: source) { m.location = "" }
            }
            out.append(m)
        }
        // Appuntamenti con data nel testo che il modello ha lasciato fuori.
        for (i, r) in rules.enumerated() where !usedRules.contains(i) {
            let covered = out.contains { cal.isDate($0.start, inSameDayAs: r.draft.start) && (r.draft.allDay || timeClose($0.start, r.draft.start)) }
            if !covered { out.append(r.draft) }
        }
        return out
    }

    /// Quasi tutte le parole (di 3+ lettere) del campo si trovano nel testo di partenza.
    static func grounded(_ field: String, in source: String) -> Bool {
        let words = field.lowercased().split { !$0.isLetter && !$0.isNumber }.filter { $0.count >= 3 }
        if words.isEmpty { return field.isEmpty }
        let src = source.lowercased()
        let hit = words.filter { src.contains($0) }.count
        return Double(hit) / Double(words.count) >= 0.7
    }

    private static func overlap(_ a: String, _ b: String) -> Int {
        let wa = Set(a.lowercased().split { !$0.isLetter }.filter { $0.count >= 3 })
        let wb = Set(b.lowercased().split { !$0.isLetter }.filter { $0.count >= 3 })
        return wa.intersection(wb).count
    }

    private static func timeAppears(_ d: Date, in source: String) -> Bool {
        let c = EventBuilder.calendar().dateComponents([.hour, .minute], from: d)
        let h = c.hour ?? 0, m = c.minute ?? 0
        let s = source.lowercased()
        return s.contains(String(format: "%d:%02d", h, m)) || s.contains(String(format: "%02d:%02d", h, m))
            || s.contains(String(format: "%d.%02d", h, m)) || (m == 0 && (s.contains("ore \(h)") || s.contains("alle \(h)") || s.contains("\(h)h") || s.contains("\(h) am") || s.contains("\(h) pm")))
    }

    private static func timeClose(_ a: Date, _ b: Date) -> Bool { abs(a.timeIntervalSince(b)) < 30 * 60 }

    private static func finish(_ events: [EventDraft]) -> [EventDraft] {
        var seen = Set<String>(); var out: [EventDraft] = []
        for e in events {
            let key = "\(Int(e.start.timeIntervalSince1970))|\(e.title.lowercased().prefix(24))"
            if seen.insert(key).inserted { out.append(e) }
        }
        return out.sorted { $0.start < $1.start }
    }
}
