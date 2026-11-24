// Motore Apple Intelligence (FoundationModels, on-device). Dietro #if canImport e #available: l'app funziona anche senza.

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleAvailability {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }
}

#if canImport(FoundationModels)
@available(macOS 26, *)
@Generable
struct AIEvent {
    @Guide(description: "Titolo breve dell'evento, senza data né luogo")
    var titolo: String
    @Guide(description: "Luogo (sala, indirizzo, città), stringa vuota se manca")
    var luogo: String
    @Guide(description: "Data nel formato AAAA-MM-GG; risolvi giorni relativi partendo dalla data di oggi indicata")
    var data: String
    @Guide(description: "Ora di inizio HH:MM in 24 ore, stringa vuota se non scritta")
    var inizio: String
    @Guide(description: "Ora di fine HH:MM in 24 ore, stringa vuota se non scritta")
    var fine: String
}

@available(macOS 26, *)
@Generable
struct AIEvents {
    @Guide(description: "Tutti gli eventi con una data nel testo; elenco vuoto se non ce ne sono")
    var eventi: [AIEvent]
}

@available(macOS 26, *)
struct AppleEngine: EventEngine {
    var name: String { "Apple Intelligence" }
    var trustsTitles: Bool { true }

    func extract(window: String, today: Date) async throws -> [RawEvent] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEEE d MMMM yyyy"
        let instructions = """
        Estrai dal testo gli eventi di calendario (appuntamenti, riunioni, scadenze con un giorno preciso). \
        Non inventare nulla: se un'informazione non è scritta, lascia il campo vuoto. \
        Oggi è \(f.string(from: today)) (\(EventBuilder.dayString(today))).
        """
        let session = LanguageModelSession(instructions: instructions)
        let r = try await session.respond(to: window, generating: AIEvents.self)
        return r.content.eventi.map {
            RawEvent(title: $0.titolo, location: $0.luogo, date: $0.data, start: $0.inizio, end: $0.fine)
        }
    }
}
#endif

enum EngineFactory {
    static func make(_ choice: EngineChoice) -> EventEngine? {
        switch choice {
        case .apple:
            #if canImport(FoundationModels)
            if #available(macOS 26, *), AppleAvailability.isAvailable { return AppleEngine() }
            #endif
            return nil
        case .gemma: return GemmaEngine.make()
        case .rules: return nil
        }
    }

    /// Motore da usare davvero: quello scelto, altrimenti il primo disponibile, infine le regole.
    static func resolve(_ choice: EngineChoice) -> (engine: EventEngine?, used: EngineChoice) {
        if choice == .rules { return (nil, .rules) }
        if let e = make(choice) { return (e, choice) }
        for c in [EngineChoice.apple, .gemma] where c != choice {
            if let e = make(c) { return (e, c) }
        }
        return (nil, .rules)
    }
}
