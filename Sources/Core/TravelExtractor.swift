// Documenti di viaggio (e-ticket, itinerari, voucher hotel): voli e check-in/check-out a regole, perché sono molto
// strutturati e i modelli piccoli sbagliano orari e fusi. Schema della skill "viaggio-ics":
// volo = partenza -> arrivo (ora locale di ciascun aeroporto, convertita in UTC), hotel = finestre di 30 minuti.

import Foundation

enum TravelExtractor {
    struct Output { var events: [EventDraft] = []; var notes: [String] = [] }

    // MARK: Espressioni

    private static let flightRx = try! NSRegularExpression(pattern: #"\b([A-Z][A-Z0-9]|[A-Z0-9][A-Z])\s?(\d{2,4})\b"#)
    private static let iataRx = try! NSRegularExpression(pattern: #"\b[A-Z]{3}\b"#)
    private static let timeRx = try! NSRegularExpression(pattern: #"(?<![\d:.\/])([01]?\d|2[0-3])[:.h]([0-5]\d)(?![\d]|[.:\/]\d)"#)

    private static let months = ["gen": 1, "feb": 2, "mar": 3, "apr": 4, "mag": 5, "giu": 6, "lug": 7, "ago": 8, "set": 9, "ott": 10,
                                 "nov": 11, "dic": 12, "jan": 1, "may": 5, "jun": 6, "jul": 7, "aug": 8, "sep": 9, "oct": 10, "dec": 12]
    private static let dayMonthRx = try! NSRegularExpression(
        pattern: #"\b(\d{1,2})(?:st|nd|rd|th|°)?[\s/.\-]+(gen|feb|mar|apr|mag|giu|lug|ago|set|ott|nov|dic|jan|may|jun|jul|aug|sep|oct|dec)[a-z]*\.?(?:[\s/.\-,]+(\d{4}|\d{2})\b)?"#,
        options: [.caseInsensitive])
    private static let monthDayRx = try! NSRegularExpression(
        pattern: #"\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?(?:\s+(\d{4}))?\b"#,
        options: [.caseInsensitive])
    private static let numericDateRx = try! NSRegularExpression(pattern: #"\b(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4}|\d{2})\b"#)

    // MARK: Utilità

    private static func cal(_ id: String?) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = id.flatMap(TimeZone.init(identifier:)) ?? .current
        return c
    }

    private static func match(_ rx: NSRegularExpression, _ s: String, in range: NSRange? = nil) -> [NSTextCheckingResult] {
        rx.matches(in: s, options: [], range: range ?? NSRange(location: 0, length: (s as NSString).length))
    }

    private static func g(_ m: NSTextCheckingResult, _ i: Int, _ s: String) -> String? {
        let r = m.range(at: i); return r.location == NSNotFound ? nil : (s as NSString).substring(with: r)
    }

    private struct DayHit { var pos: Int; var y: Int; var m: Int; var d: Int }

    private static func days(in s: String, now: Date) -> [DayHit] {
        var out: [DayHit] = []
        let nowC = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: now)
        func fullYear(_ str: String?, month: Int, day: Int) -> Int {
            if let str, let y = Int(str) { return y < 100 ? 2000 + y : y }
            // Senza anno: il prossimo con quella data, restando vicino a oggi.
            let y = nowC.year ?? 2026
            let cur = (month, day) < (nowC.month ?? 1, nowC.day ?? 1)
            return cur ? y + 1 : y
        }
        for m in match(dayMonthRx, s) {
            guard let d = g(m, 1, s).flatMap(Int.init), let ms = g(m, 2, s)?.lowercased(), let mo = months[String(ms.prefix(3))] else { continue }
            out.append(DayHit(pos: m.range.location, y: fullYear(g(m, 3, s), month: mo, day: d), m: mo, d: d))
        }
        for m in match(monthDayRx, s) {
            guard let ms = g(m, 1, s)?.lowercased(), let mo = months[String(ms.prefix(3))], let d = g(m, 2, s).flatMap(Int.init) else { continue }
            out.append(DayHit(pos: m.range.location, y: fullYear(g(m, 3, s), month: mo, day: d), m: mo, d: d))
        }
        for m in match(numericDateRx, s) {
            guard let d = g(m, 1, s).flatMap(Int.init), let mo = g(m, 2, s).flatMap(Int.init), (1...31).contains(d), (1...12).contains(mo),
                  let y = g(m, 3, s).flatMap(Int.init) else { continue }
            out.append(DayHit(pos: m.range.location, y: y < 100 ? 2000 + y : y, m: mo, d: d))
        }
        return out.sorted { $0.pos < $1.pos }
    }

    private static func build(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, tz: String?) -> Date? {
        cal(tz).date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))
    }

    private static func first(_ pattern: String, in s: String, group: Int = 1, options: NSRegularExpression.Options = [.caseInsensitive]) -> String? {
        guard let rx = try? NSRegularExpression(pattern: pattern, options: options),
              let m = rx.firstMatch(in: s, options: [], range: NSRange(location: 0, length: (s as NSString).length)) else { return nil }
        return g(m, group, s)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Dati comuni del documento

    private struct Common {
        var passenger: String?, pnr: String?, ticket: String?, baggage: String?, cabin: String?
    }

    private static func common(_ text: String) -> Common {
        var c = Common()
        c.passenger = first(#"(?:passeggero|passenger|nome passeggero|intestatario)\s*[:\-]\s*([^\n]{3,40}?)(?:\s{2,}|\n|$)"#, in: text)
        c.pnr = first(#"(?:PNR|codice(?: di)? prenotazione|booking (?:reference|ref|code)|record locator|riferimento(?: prenotazione)?|reservation code|confirmation(?: code)?)\s*(?:\([^)]*\))?\s*[:#\-]?\s*([A-Z0-9]{5,8})\b"#, in: text, options: [])
        c.ticket = first(#"\b(\d{3}[ \-]?\d{10})\b"#, in: text)
        if let line = text.components(separatedBy: "\n").first(where: {
            let l = $0.lowercased(); return (l.contains("bagaglio") || l.contains("baggage") || l.contains("luggage")) && $0.count < 120
        }) { c.baggage = line.trimmingCharacters(in: .whitespaces) }
        c.cabin = first(#"(?:classe|class|cabin|cabina)\s*[:\-]?\s*(economy|business|premium economy|first|prima|turistica|economica)"#, in: text)
        return c
    }

    // MARK: Voli

    static func extract(_ text: String, now: Date = Date()) -> Output {
        var out = Output()
        let t = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\u{00A0}", with: " ")
        let com = common(t)
        let flights = flights(in: t, common: com, now: now)
        out.events += flights
        out.events += hotels(in: t, flights: flights, common: com, now: now, notes: &out.notes)
        if !flights.isEmpty || !out.events.isEmpty {
            out.notes.insert(L("Documento di viaggio riconosciuto: voli e hotel letti con regole sugli orari locali."), at: 0)
        }
        return out
    }

    private struct Parsed { var dep: Airport; var arr: Airport; var times: [(Int, Int)]; var start: Date; var end: Date }

    private static func parseLeg(_ win: String, now: Date) -> Parsed? {
        var aps: [Airport] = []
        for m in match(iataRx, win) {
            if let code = g(m, 0, win), let a = Travel.airports[code], !aps.contains(where: { $0.code == a.code }) { aps.append(a) }
        }
        if aps.count < 2 {
            let low = win.lowercased()
            let byName = Travel.airports.values
                .compactMap { a -> (Int, Airport)? in
                    guard let r = low.range(of: a.name.lowercased()) ?? low.range(of: a.city.lowercased()) else { return nil }
                    return (low.distance(from: low.startIndex, to: r.lowerBound), a)
                }.sorted { $0.0 < $1.0 }.map(\.1)
            for a in byName where !aps.contains(where: { $0.code == a.code }) { aps.append(a) }
        }
        guard aps.count >= 2 else { return nil }
        let dep = aps[0], arr = aps[1]
        let times = match(timeRx, win).compactMap { m -> (Int, Int)? in
            guard let h = g(m, 1, win).flatMap(Int.init), let mi = g(m, 2, win).flatMap(Int.init) else { return nil }
            return (h, mi)
        }
        guard times.count >= 2 else { return nil }
        let ds = days(in: win, now: now)
        guard let d0 = ds.first else { return nil }
        let d1 = ds.dropFirst().first(where: { ($0.y, $0.m, $0.d) != (d0.y, d0.m, d0.d) })
        guard let start = build(d0.y, d0.m, d0.d, times[0].0, times[0].1, tz: dep.tz) else { return nil }
        var end: Date?
        if let d1, let e = build(d1.y, d1.m, d1.d, times[1].0, times[1].1, tz: arr.tz), e > start { end = e }
        if end == nil, var e = build(d0.y, d0.m, d0.d, times[1].0, times[1].1, tz: arr.tz) {
            var n = 0
            while e <= start, n < 2 { e = e.addingTimeInterval(86400); n += 1 }   // arrivo il giorno dopo
            end = e
        }
        guard let end, end > start, end.timeIntervalSince(start) < 30 * 3600 else { return nil }
        return Parsed(dep: dep, arr: arr, times: times, start: start, end: end)
    }

    private static func flights(in t: String, common c: Common, now: Date) -> [EventDraft] {
        let ns = t as NSString
        struct F { var range: NSRange; var code: String; var num: String }
        let all: [F] = match(flightRx, t).compactMap { m in
            guard let code = g(m, 1, t), Travel.airlines[code] != nil, let num = g(m, 2, t) else { return nil }
            return F(range: m.range, code: code, num: num)
        }
        var out: [EventDraft] = []
        var seen = Set<String>()
        for (i, f) in all.enumerated() {
            let prevEnd = i > 0 ? all[i - 1].range.location + all[i - 1].range.length : 0
            let nextStart = all[(i + 1)...].first(where: { $0.code + $0.num != f.code + f.num })?.range.location ?? ns.length
            // Di solito i dati seguono il numero di volo; nelle tabelle a righe lo precedono: provo i due versi.
            let after = NSRange(location: f.range.location, length: 0)
            let afterWin = NSRange(location: after.location, length: max(0, min(nextStart, f.range.location + f.range.length + 800) - after.location))
            let beforeLo = max(prevEnd, f.range.location - 250)
            let beforeWin = NSRange(location: beforeLo, length: max(0, min(nextStart, f.range.location + f.range.length + 60) - beforeLo))
            var parsed: Parsed?
            var win = ""
            for r in [afterWin, beforeWin] where r.length > 0 {
                let w = ns.substring(with: r)
                if let p = parseLeg(w, now: now) { parsed = p; win = w; break }
            }
            guard let leg = parsed else { continue }
            let dep = leg.dep, arr = leg.arr, times = leg.times, start = leg.start, end = leg.end

            let key = "\(f.code)\(f.num)|\(Int(start.timeIntervalSince1970))"
            guard seen.insert(key).inserted else { continue }

            let airline = Travel.airlines[f.code] ?? f.code
            func hm(_ h: Int, _ m: Int) -> String { String(format: "%02d:%02d", h, m) }
            var lines = [airline + (c.cabin.map { " · " + $0.capitalized } ?? "")]
            lines.append("Partenza \(dep.code) \(hm(times[0].0, times[0].1)) (ora locale)")
            lines.append("Arrivo \(arr.code) \(hm(times[1].0, times[1].1)) (ora locale)")
            if let p = c.passenger { lines.append("Passeggero: \(p)") }
            if let p = c.pnr { lines.append("PNR: \(p)") }
            if let tk = c.ticket { lines.append("Biglietto: \(tk)") }
            if let b = c.baggage { lines.append(b) }

            var e = EventDraft(title: "Volo \(f.code)\(f.num) \(dep.city) \(dep.code) → \(arr.city) \(arr.code)",
                               location: dep.label, start: start, end: end, allDay: false, source: win)
            e.details = lines.joined(separator: "\n")
            e.kind = .flight
            out.append(e)
        }
        return out.sorted { $0.start < $1.start }
    }

    // MARK: Hotel

    private static let hotelWords = try! NSRegularExpression(
        pattern: #"\b(hotel|resort|b&b|bed and breakfast|residence|albergo|nh collection|ibis|hilton|marriott|hyatt|best western|novotel|mercure|holiday inn|radisson)\b"#,
        options: [.caseInsensitive])
    private static let addressWord = try! NSRegularExpression(
        pattern: #"\b(via|viale|piazza|corso|rue|avenue|boulevard|strasse|straße|platz|street|st\.|road|calle|plaza|paseo|\d{4,5})\b"#, options: [.caseInsensitive])

    private static func hotels(in t: String, flights: [EventDraft], common: Common, now: Date, notes: inout [String]) -> [EventDraft] {
        let ns = t as NSString
        let lower = t.lowercased()
        guard match(hotelWords, t).count > 0 || lower.contains("check-in") || lower.contains("check in") || lower.contains("voucher") else { return [] }

        func dayAfter(_ cue: String) -> (DayHit, String)? {
            guard let rx = try? NSRegularExpression(pattern: cue, options: [.caseInsensitive]) else { return nil }
            for m in match(rx, t) {
                let start = m.range.location + m.range.length
                let len = min(110, ns.length - start)
                guard len > 0 else { continue }
                let seg = ns.substring(with: NSRange(location: start, length: len))
                let line = seg.components(separatedBy: "\n").first ?? seg
                // Un check-in con un volo sulla stessa riga è un'intestazione di volo, non di hotel.
                if line.range(of: #"\b[A-Z]{3}\b"#, options: .regularExpression).map({ Travel.airports[String(line[$0])] != nil }) == true { continue }
                if let d = days(in: line + " ", now: now).first { return (d, seg) }
                if let d = days(in: seg, now: now).first { return (d, seg) }
            }
            return nil
        }
        guard let inHit = dayAfter(#"check[\s\-]?in|data di arrivo|arrival date|\bdal\b(?=\s+\d)|check in date"#),
              let outHit = dayAfter(#"check[\s\-]?out|data di partenza|departure date|\bal\b(?=\s+\d)|check out date"#) else { return [] }

        // Orari: scritti nel documento, altrimenti standard (e lo diciamo).
        func clock(_ seg: String, fallback: (Int, Int), label: String) -> (Int, Int) {
            let line = seg.components(separatedBy: "\n").first ?? seg
            if let m = match(timeRx, line).first, let h = g(m, 1, line).flatMap(Int.init), let mi = g(m, 2, line).flatMap(Int.init) { return (h, mi) }
            notes.append(L("Orario di %@ non indicato nel documento: uso quello standard (%@). Controllalo sul sito dell'hotel.", label, String(format: "%02d:%02d", fallback.0, fallback.1)))
            return fallback
        }
        let tIn = clock(inHit.1, fallback: (15, 0), label: "check-in")
        let tOut = clock(outHit.1, fallback: (12, 0), label: "check-out")

        // Fuso dell'hotel: quello dell'aeroporto d'arrivo del volo che arriva quel giorno, altrimenti del Mac.
        var tzID = TimeZone.current.identifier
        for f in flights {
            if let code = f.title.split(separator: " ").last.map(String.init), let a = Travel.airports[code] {
                let c = cal(a.tz)
                if let ci = build(inHit.0.y, inHit.0.m, inHit.0.d, 12, 0, tz: a.tz), c.isDate(ci, inSameDayAs: f.end) || abs(ci.timeIntervalSince(f.end)) < 36 * 3600 { tzID = a.tz; break }
            }
        }
        guard let inStart = build(inHit.0.y, inHit.0.m, inHit.0.d, tIn.0, tIn.1, tz: tzID),
              let outEnd = build(outHit.0.y, outHit.0.m, outHit.0.d, tOut.0, tOut.1, tz: tzID), outEnd > inStart else { return [] }

        // Nome e indirizzo.
        let lines = t.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        var name = "", address = ""
        if let i = lines.firstIndex(where: { !$0.isEmpty && $0.count <= 90 && match(hotelWords, $0).count > 0 && !$0.lowercased().contains("check") }) {
            name = lines[i].replacingOccurrences(of: #"^(?:struttura|alloggio|nome|hotel name)\s*[:\-]\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
            if let comma = name.firstIndex(of: ","), match(addressWord, String(name[comma...])).count > 0 {
                address = String(name[name.index(after: comma)...]).trimmingCharacters(in: .whitespaces)
                name = String(name[..<comma]).trimmingCharacters(in: .whitespaces)
            }
            if address.isEmpty {
                var parts: [String] = []
                for l in lines[(i + 1)...].prefix(3) where !l.isEmpty && l.count < 90 && !l.lowercased().contains("check") && match(addressWord, l).count > 0 { parts.append(l) }
                address = parts.joined(separator: ", ")
            }
        }
        let place = [name, address].filter { !$0.isEmpty }.joined(separator: ", ")

        var details: [String] = []
        if let r = first(#"(?:tipo camera|camera|room type|room)\s*[:\-]\s*([^\n]{3,40})"#, in: t) { details.append("Camera: \(r)") }
        if let n = first(#"(\d+)\s*(?:notti|notte|nights?)"#, in: t) { details.append("Notti: \(n)") }
        if let v = first(#"(?:voucher|conferma|confirmation|reservation|booking)(?:\s*(?:n\.?|no\.?|number|numero|#))?\s*[:#]?\s*([A-Z0-9][A-Z0-9\-]{4,14})\b"#, in: t, options: []) { details.append("Voucher: \(v)") }
        if let p = first(#"(?:tel(?:efono)?|phone)\s*[.:]?\s*(\+?[\d ()\-]{7,20})"#, in: t) { details.append("Telefono: \(p)") }
        if let p = common.passenger { details.append("Ospite: \(p)") }

        let label = name.isEmpty ? "hotel" : name
        var cin = EventDraft(title: "Check-in \(label)", location: place, start: inStart, end: inStart.addingTimeInterval(30 * 60), allDay: false, source: "")
        var cout = EventDraft(title: "Check-out \(label)", location: place, start: outEnd.addingTimeInterval(-30 * 60), end: outEnd, allDay: false, source: "")
        cin.details = details.joined(separator: "\n"); cin.kind = .checkIn
        cout.details = details.joined(separator: "\n"); cout.kind = .checkOut
        return [cin, cout]
    }
}
