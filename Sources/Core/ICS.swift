// Esportazione in iCalendar (RFC 5545). Gli eventi con ora vanno in UTC (Z): ogni calendario li mostra nel fuso giusto.
// Gli eventi di giornata intera usano VALUE=DATE con fine esclusiva (giorno dopo).

import Foundation

enum ICS {
    static func make(_ events: [EventDraft], now: Date = Date(), tz: TimeZone = .current) -> String {
        var lines = [
            "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Eventi//IT", "CALSCALE:GREGORIAN", "METHOD:PUBLISH",
        ]
        let cal = EventBuilder.calendar(tz)
        for e in events where e.include {
            lines.append("BEGIN:VEVENT")
            lines.append("UID:\(UUID().uuidString.lowercased())@eventi.local")
            lines.append("DTSTAMP:\(utc(now))")
            if e.allDay {
                let next = cal.date(byAdding: .day, value: 1, to: e.start) ?? e.start
                lines.append("DTSTART;VALUE=DATE:\(day(e.start, cal))")
                lines.append("DTEND;VALUE=DATE:\(day(next, cal))")
            } else {
                lines.append("DTSTART:\(utc(e.start))")
                lines.append("DTEND:\(utc(max(e.end, e.start.addingTimeInterval(60))))")
            }
            lines.append("SUMMARY:\(escape(e.title))")
            if !e.location.isEmpty { lines.append("LOCATION:\(escape(e.location))") }
            if !e.details.isEmpty { lines.append("DESCRIPTION:\(escape(e.details))") }
            lines.append("STATUS:CONFIRMED")
            lines.append("TRANSP:\(e.allDay ? "TRANSPARENT" : "OPAQUE")")
            lines.append("END:VEVENT")
        }
        lines.append("END:VCALENDAR")
        return lines.map(fold).joined(separator: "\r\n") + "\r\n"
    }

    /// Un file per evento: nome numerato e leggibile ("1_Volo_SN3148.ics").
    static func files(_ events: [EventDraft], now: Date = Date(), tz: TimeZone = .current) -> [(name: String, content: String)] {
        let sel = events.filter(\.include)
        return sel.enumerated().map { i, e in
            let base = e.title.applyingTransform(.stripDiacritics, reverse: false) ?? e.title
            let safe = base.map { $0.isLetter || $0.isNumber ? String($0) : "_" }.joined()
                .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            var one = e; one.include = true
            return ("\(i + 1)_\(String(safe.prefix(60))).ics", make([one], now: now, tz: tz))
        }
    }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func utc(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return f.string(from: d)
    }

    private static func day(_ d: Date, _ cal: Calendar) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Righe lunghe al massimo 75 byte, continuate con uno spazio.
    private static func fold(_ line: String) -> String {
        var out = "", count = 0
        for ch in line {
            let n = String(ch).utf8.count
            if count + n > 75 { out += "\r\n "; count = 1 }
            out.append(ch); count += n
        }
        return out
    }
}
