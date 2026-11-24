// Modello dell'evento estratto e conversione dai campi testuali che producono i motori (Apple Intelligence, Gemma).

import Foundation

struct EventDraft: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var location: String
    /// Inizio. Se `allDay`, conta solo il giorno.
    var start: Date
    /// Fine (esclusa per gli eventi di giornata intera: l'esportazione aggiunge un giorno).
    var end: Date
    var allDay: Bool
    var include = true
    /// Descrizione dell'evento (codici di prenotazione, passeggero, bagaglio...), solo per i viaggi.
    var details: String = ""
    var kind: Kind = .generic
    enum Kind: String { case generic, flight, checkIn, checkOut }
    /// Il pezzo di testo da cui viene l'evento, per controllare a occhio.
    var source: String = ""
}

/// I cinque campi come li scrivono i motori: data AAAA-MM-GG, orari HH:MM, stringa vuota se mancano.
struct RawEvent: Equatable {
    var title = ""
    var location = ""
    var date = ""
    var start = ""
    var end = ""
}

enum EventBuilder {
    static let defaultDurationKey = "defaultDurationMinutes"

    static var defaultDuration: TimeInterval {
        let m = UserDefaults.standard.integer(forKey: defaultDurationKey)
        return TimeInterval(m > 0 ? m : 60) * 60
    }

    static func calendar(_ tz: TimeZone = .current) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        c.locale = Locale(identifier: "it_IT")
        return c
    }

    /// "2026-11-20" + "15:00" + "16:30" -> evento. Restituisce nil se la data non è valida.
    static func make(_ raw: RawEvent, source: String = "", tz: TimeZone = .current) -> EventDraft? {
        let cal = calendar(tz)
        guard let day = parseDay(raw.date, cal) else { return nil }
        let title = capitalized(raw.title)
        guard !title.isEmpty else { return nil }
        let loc = capitalized(raw.location)

        guard let s = parseTime(raw.start) else {
            return EventDraft(title: title, location: loc, start: day, end: day, allDay: true, source: source)
        }
        let start = cal.date(bySettingHour: s.h, minute: s.m, second: 0, of: day) ?? day
        var end = start.addingTimeInterval(defaultDuration)
        if let e = parseTime(raw.end),
           let candidate = cal.date(bySettingHour: e.h, minute: e.m, second: 0, of: day), candidate > start {
            end = candidate
        }
        return EventDraft(title: title, location: loc, start: start, end: end, allDay: false, source: source)
    }

    static func capitalized(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let f = t.first else { return t }
        return f.uppercased() + t.dropFirst()
    }

    static func parseDay(_ s: String, _ cal: Calendar) -> Date? {
        let p = s.trimmingCharacters(in: .whitespaces).split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, (1900...2200).contains(p[0]), (1...12).contains(p[1]), (1...31).contains(p[2]) else { return nil }
        var dc = DateComponents(); dc.year = p[0]; dc.month = p[1]; dc.day = p[2]
        guard let d = cal.date(from: dc), cal.component(.day, from: d) == p[2] else { return nil }
        return d
    }

    static func parseTime(_ s: String) -> (h: Int, m: Int)? {
        let t = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: ":")
        guard !t.isEmpty else { return nil }
        let p = t.split(separator: ":").compactMap { Int($0) }
        guard let h = p.first, (0...23).contains(h) else { return nil }
        let m = p.count > 1 ? p[1] : 0
        guard (0...59).contains(m) else { return nil }
        return (h, m)
    }

    static func dayString(_ d: Date, _ cal: Calendar = calendar()) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func timeString(_ d: Date, _ cal: Calendar = calendar()) -> String {
        let c = cal.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    static func raw(from e: EventDraft) -> RawEvent {
        RawEvent(title: e.title, location: e.location, date: dayString(e.start),
                 start: e.allDay ? "" : timeString(e.start), end: e.allDay ? "" : timeString(e.end))
    }
}
