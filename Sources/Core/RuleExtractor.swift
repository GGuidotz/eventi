// Estrazione a regole (istantanea, senza AI): NSDataDetector per le date, NLTagger per i luoghi, frasi per i titoli.
// Serve come motore di ripiego e come controllo dei motori AI (date e orari scritti nel testo battono quelli "inventati").

import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

struct RuleHit {
    var draft: EventDraft
    var explicitEnd: Bool
}

enum RuleExtractor {
    // MARK: Espressioni

    private static let timeRegex = try! NSRegularExpression(
        pattern: #"\d{1,2}[:.]\d{2}|\b(?:alle|ore|h|at)\s*\d{1,2}\b|\b\d{1,2}\s?(?:am|pm)\b|\b\d{1,2}\s?h\b"#, options: [.caseInsensitive])

    private static let dayRegex = try! NSRegularExpression(
        pattern: #"\b(?:gen(?:naio)?|feb(?:braio)?|mar(?:zo)?|apr(?:ile)?|mag(?:gio)?|giu(?:gno)?|lug(?:lio)?|ago(?:sto)?|set(?:tembre)?|ott(?:obre)?|nov(?:embre)?|dic(?:embre)?|jan(?:uary)?|march|april|may|june|july|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|december|lun(?:ed[iì])?|mart(?:ed[iì])?|mer(?:coled[iì])?|gio(?:ved[iì])?|ven(?:erd[iì])?|sab(?:ato)?|dom(?:enica)?|mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?|oggi|domani|dopodomani|stasera|stanotte|today|tomorrow|tonight|prossim[oa]|next)\b|(?<![\d:])(?:0?[1-9]|[12]\d|3[01])[/.\-](?:0?[1-9]|1[0-2])(?:[/.\-]\d{2,4})?(?![\d:])"#,
        options: [.caseInsensitive])

    /// "dalle 9:30 alle 13:00", "14:00-17:00", "from 9 to 11"
    private static let rangeRegex = try! NSRegularExpression(
        pattern: #"(?:dalle|dalle ore|da|from|ore)?\s*(\d{1,2})(?:[:.](\d{2}))?\s*(?:-|–|—|alle(?: ore)?|to|a)\s*(\d{1,2})(?:[:.](\d{2}))?"#,
        options: [.caseInsensitive])

    private static let locationCue = try! NSRegularExpression(
        pattern: #"(?:\bpresso\b|\bc/o\b|@|\bat\b|\bin\b|\ba\b|\bal\b|\balla\b|\ballo\b|\bnell[aeo']\b|\bnel\b)\s+((?:(?:sala|aula|via|viale|piazza|corso|room|hall|teatro|palazzo|università|studio|ristorante|bar|hotel|cinema|museo|biblioteca)\b|\p{Lu})[\p{L}0-9'’.\-]*(?:\s+(?:di|del|della|dei|e|de|da|d')?\s*[\p{L}0-9'’.\-]+){0,5})"#,
        options: [.caseInsensitive])

    // MARK: API

    static func extract(_ text: String, now: Date = Date(), tz: TimeZone = .current) -> [RuleHit] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return [] }
        let cal = EventBuilder.calendar(tz)
        var hits: [RuleHit] = []

        // Un blocco di righe consecutive condivide l'ultimo giorno citato ("lo stesso giorno 14:00-17:00").
        for block in text.components(separatedBy: "\n\n") {
            var lastDay: Date?
            for paragraph in block.components(separatedBy: "\n") {
                let p = paragraph.trimmingCharacters(in: .whitespaces)
                guard p.count > 3 else { continue }
                for sentence in sentences(in: p) {
                    let ns = sentence as NSString
                    let matches = detector.matches(in: sentence, options: [], range: NSRange(location: 0, length: ns.length))
                        .filter { $0.date != nil }
                    var consumed: [NSRange] = []
                    var mine: [Int] = []          // indici dei hit creati da questa frase
                    var usedStarts: [Date] = []

                    for m in matches {
                        guard let d0 = m.date else { continue }
                        let sub = ns.substring(with: m.range)
                        let range = NSRange(location: 0, length: (sub as NSString).length)
                        let timed = timeRegex.firstMatch(in: sub, options: [], range: range) != nil
                        let dayGiven = dayRegex.firstMatch(in: sub, options: [], range: range) != nil

                        var d = d0
                        if !dayGiven, let ld = lastDay {
                            // Solo un'ora: prende il giorno già citato prima.
                            let hm = cal.dateComponents([.hour, .minute], from: d0)
                            d = cal.date(bySettingHour: hm.hour ?? 0, minute: hm.minute ?? 0, second: 0, of: ld) ?? d0
                        }
                        if timed, !dayGiven, let li = mine.last, let prev = usedStarts.last, cal.isDate(d, inSameDayAs: prev) {
                            if hits[li].draft.allDay {
                                // "3 febbraio ore 10": l'ora completa il giorno appena letto.
                                hits[li].draft.allDay = false
                                hits[li].draft.start = d
                                hits[li].draft.end = d.addingTimeInterval(m.duration > 0 ? m.duration : EventBuilder.defaultDuration)
                                hits[li].explicitEnd = m.duration > 0
                                consumed.append(m.range); continue
                            } else if !hits[li].explicitEnd, d > hits[li].draft.start {
                                hits[li].draft.end = d; hits[li].explicitEnd = true
                                consumed.append(extendEndCue(sentence, m.range)); continue
                            }
                        }

                        var draft = EventDraft(title: "", location: "", start: d, end: d, allDay: !timed, source: sentence)
                        var explicitEnd = false
                        if timed {
                            draft.end = d.addingTimeInterval(m.duration > 0 ? m.duration : EventBuilder.defaultDuration)
                            explicitEnd = m.duration > 0
                            if let e = rangeEnd(in: sentence, day: d, start: d, cal: cal) { draft.end = e; explicitEnd = true }
                        } else {
                            draft.start = cal.startOfDay(for: d); draft.end = draft.start
                        }
                        lastDay = cal.startOfDay(for: d)
                        usedStarts.append(d)
                        consumed.append(m.range)
                        hits.append(RuleHit(draft: draft, explicitEnd: explicitEnd))
                        mine.append(hits.count - 1)
                    }
                    guard !mine.isEmpty else { continue }

                    // Ora di inizio scritta fuori dal match del detector ("3 febbraio 2027 ore 10", "14:00-17:00").
                    for i in mine where hits[i].draft.allDay {
                        if let (st, r) = spokenStart(in: sentence, day: hits[i].draft.start, cal: cal, skipping: consumed) {
                            hits[i].draft.allDay = false
                            hits[i].draft.start = st
                            hits[i].draft.end = st.addingTimeInterval(EventBuilder.defaultDuration)
                            consumed.append(r)
                            if let e = rangeEnd(in: sentence, day: st, start: st, cal: cal) { hits[i].draft.end = e; hits[i].explicitEnd = true }
                        }
                    }
                    // Ora di fine detta a parole ("finiamo verso le 16:30") non vista dal detector.
                    for i in mine where !hits[i].draft.allDay && !hits[i].explicitEnd {
                        if let (e, r) = spokenEnd(in: sentence, day: hits[i].draft.start, start: hits[i].draft.start, cal: cal, skipping: consumed) {
                            hits[i].draft.end = e; hits[i].explicitEnd = true; consumed.append(r)
                        }
                    }
                    let (title, loc) = describe(sentence, removing: consumed)
                    for i in mine { hits[i].draft.title = title; hits[i].draft.location = loc }
                }
            }
        }
        return dedupe(hits.filter { !$0.draft.title.isEmpty })
    }

    // MARK: Frasi, titolo, luogo

    static func sentences(in paragraph: String) -> [String] {
        #if canImport(NaturalLanguage)
        let t = NLTokenizer(unit: .sentence)
        t.string = paragraph
        var out: [String] = []
        t.enumerateTokens(in: paragraph.startIndex..<paragraph.endIndex) { r, _ in
            out.append(String(paragraph[r])); return true
        }
        return out.isEmpty ? [paragraph] : out
        #else
        return [paragraph]
        #endif
    }

    private static func rangeEnd(in sentence: String, day: Date, start: Date, cal: Calendar) -> Date? {
        let ns = sentence as NSString
        guard let m = rangeRegex.firstMatch(in: sentence, options: [], range: NSRange(location: 0, length: ns.length)) else { return nil }
        func num(_ i: Int) -> Int? {
            let r = m.range(at: i); return r.location == NSNotFound ? nil : Int(ns.substring(with: r))
        }
        // Serve almeno un minuto indicato (9:30) oppure un "alle": evita di leggere "12-15 gennaio" come orari.
        let whole = ns.substring(with: m.range).lowercased()
        let hasMinutes = num(2) != nil || num(4) != nil
        guard hasMinutes || whole.contains("alle") || whole.contains("to") || whole.contains("dalle") else { return nil }
        guard let h1 = num(1), let h2 = num(3), (0...23).contains(h1), (0...23).contains(h2) else { return nil }
        let startH = cal.component(.hour, from: start), startM = cal.component(.minute, from: start)
        guard h1 == startH, (num(2) ?? 0) == startM else { return nil }
        guard let e = cal.date(bySettingHour: h2, minute: num(4) ?? 0, second: 0, of: day), e > start else { return nil }
        return e
    }

    private static let endCue = try! NSRegularExpression(
        pattern: #"(?:(?:fino|verso|entro|finiamo|finisce|termina|until|till|ends?)\s*(?:alle|le|at|by|a)?\s*|\balle\s+|\bto\s+)(\d{1,2})[:.](\d{2})"#,
        options: [.caseInsensitive])

    private static let keywordPlace = try! NSRegularExpression(
        pattern: #"\b((?:sala|aula|room|via|viale|piazza|corso)\s+[\p{L}0-9'’.\-]+(?:\s+(?:di|del|della|dei)?\s*\p{Lu}[\p{L}0-9'’.\-]*){0,3})"#,
        options: [.caseInsensitive])

    private static func spokenEnd(in sentence: String, day: Date, start: Date, cal: Calendar, skipping: [NSRange]) -> (Date, NSRange)? {
        let ns = sentence as NSString
        for m in endCue.matches(in: sentence, options: [], range: NSRange(location: 0, length: ns.length)) {
            if skipping.contains(where: { NSIntersectionRange($0, m.range).length > 0 }) { continue }
            guard let h = Int(ns.substring(with: m.range(at: 1))), let mi = Int(ns.substring(with: m.range(at: 2))),
                  (0...23).contains(h), (0...59).contains(mi),
                  let e = cal.date(bySettingHour: h, minute: mi, second: 0, of: day), e > start else { continue }
            return (e, m.range)
        }
        return nil
    }

    private static let startCue = try! NSRegularExpression(
        pattern: #"(?:\b(?:alle ore|alle|ore|at|h)\s*)(\d{1,2})(?:[:.](\d{2}))?\b"#, options: [.caseInsensitive])
    private static let startBare = try! NSRegularExpression(
        pattern: #"(?<![\d:])(\d{1,2})[:.](\d{2})(?![\d])"#, options: [])

    private static func spokenStart(in sentence: String, day: Date, cal: Calendar, skipping: [NSRange]) -> (Date, NSRange)? {
        let ns = sentence as NSString
        for rx in [startCue, startBare] {
            for m in rx.matches(in: sentence, options: [], range: NSRange(location: 0, length: ns.length)) {
                if skipping.contains(where: { NSIntersectionRange($0, m.range).length > 0 }) { continue }
                func num(_ i: Int) -> Int? { let r = m.range(at: i); return r.location == NSNotFound ? nil : Int(ns.substring(with: r)) }
                guard let h = num(1), (0...23).contains(h), (0...59).contains(num(2) ?? 0),
                      let d = cal.date(bySettingHour: h, minute: num(2) ?? 0, second: 0, of: day) else { continue }
                return (d, m.range)
            }
        }
        return nil
    }

    private static func extendEndCue(_ sentence: String, _ range: NSRange) -> NSRange {
        let ns = sentence as NSString
        for m in endCue.matches(in: sentence, options: [], range: NSRange(location: 0, length: ns.length))
        where NSIntersectionRange(m.range, range).length > 0 { return NSUnionRange(m.range, range) }
        return range
    }

    private static let leadIn = try! NSRegularExpression(
        pattern: #"^(?:ciao|buongiorno|buonasera|salve|gentile|caro|cara|hi|hello|dear)\b[^,.!:]*[,.!:]\s*|^(?:ti|vi) (?:ricordo|scrivo|invito)\b[^,]*?\b(?:che|a|per)\b\s*|^(?:promemoria|reminder|invito|oggetto|subject)\s*:\s*|^(?:vi aspetto|ti aspetto|ci vediamo|ci vediamo per|ci sentiamo)\b\s*"#,
        options: [.caseInsensitive])

    static func describe(_ sentence: String, removing ranges: [NSRange]) -> (title: String, location: String) {
        var s = sentence as NSString
        for r in ranges.sorted(by: { $0.location > $1.location }) where r.location + r.length <= s.length {
            s = s.replacingCharacters(in: r, with: " ") as NSString
        }
        var text = s as String

        // Luogo
        var location = ""
        let ns = text as NSString
        if let m = locationCue.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)) {
            let cand = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            // Taglia alla prima virgola/punto e virgola e alle parole di giorno/ora rimaste.
            var place = cand.components(separatedBy: CharacterSet(charactersIn: ",;()")).first ?? cand
            place = place.trimmingCharacters(in: .whitespaces)
            if place.count >= 3, !startsWithTimeWord(place) {
                location = place
                // Il resto dopo la prima virgola (città) si tiene come parte del luogo.
                let rest = cand.dropFirst(place.count).trimmingCharacters(in: CharacterSet(charactersIn: ", "))
                if let city = rest.components(separatedBy: CharacterSet(charactersIn: ",;()")).first?
                    .trimmingCharacters(in: .whitespaces), city.count >= 3, city.first?.isUppercase == true, cand.contains(",") {
                    location += ", " + city
                }
                text = ns.replacingCharacters(in: m.range, with: " ")
            }
        }
        if location.isEmpty {
            let kn = text as NSString
            if let m = keywordPlace.firstMatch(in: text, options: [], range: NSRange(location: 0, length: kn.length)) {
                location = kn.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
                if let f = location.first { location = f.uppercased() + location.dropFirst() }
                text = kn.replacingCharacters(in: m.range, with: " ")
            }
        }
        #if canImport(NaturalLanguage)
        if location.isEmpty {
            let tagger = NLTagger(tagSchemes: [.nameType])
            tagger.string = text
            tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType,
                                 options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, r in
                if tag == .placeName || tag == .organizationName { location = String(text[r]); return false }
                return true
            }
        }
        #endif

        // Titolo
        var t = text
        let tn = t as NSString
        t = leadIn.stringByReplacingMatches(in: t, options: [], range: NSRange(location: 0, length: tn.length), withTemplate: "")
        t = t.replacingOccurrences(of: #"\b(?:lo stesso giorno|stesso giorno|il giorno stesso|same day)\b"#, with: "", options: [.regularExpression, .caseInsensitive])
        t = endCue.stringByReplacingMatches(in: t, options: [], range: NSRange(location: 0, length: (t as NSString).length), withTemplate: "")
        t = t.replacingOccurrences(of: #"[,;\s]*\b(?:finiamo|finisce|finisco|termina|si conclude|until|ends?)\b[\s.,;]*$"#, with: "", options: [.regularExpression, .caseInsensitive])
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:-–—()[]\"'"))
        t = t.replacingOccurrences(of: #"^(?:alle ore|alle|ore)\s+|\s+(?:alle ore|alle|ore)\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
        t = t.replacingOccurrences(of: #"\b(?:il|lo|la|del|dal|dalle|alle|ore|on|at|from|to|e|ed|per|il giorno|giorno)\s*(?=[,.;:\-–]|$)"#,
                                   with: "", options: [.regularExpression, .caseInsensitive])
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:-–—()[]\"'"))
        // Una sola idea: fino alla prima virgola/trattino lungo se il titolo è lungo.
        if t.count > 60, let cut = t.firstIndex(where: { ",;–—".contains($0) }), t.distance(from: t.startIndex, to: cut) > 8 {
            t = String(t[..<cut]).trimmingCharacters(in: .whitespaces)
        }
        if t.count > 90 { t = String(t.prefix(90)).trimmingCharacters(in: .whitespaces) + "…" }
        if let f = t.first { t = f.uppercased() + t.dropFirst() }
        location = location.trimmingCharacters(in: CharacterSet(charactersIn: " .,;:"))
        return (t, location)
    }

    private static func startsWithTimeWord(_ s: String) -> Bool {
        let range = NSRange(location: 0, length: (s as NSString).length)
        guard let m = dayRegex.firstMatch(in: s, options: [], range: range) else { return false }
        return m.range.location == 0
    }

    static func dedupe(_ hits: [RuleHit]) -> [RuleHit] {
        var seen = Set<String>(); var out: [RuleHit] = []
        for h in hits {
            let key = "\(h.draft.start.timeIntervalSince1970)|\(h.draft.title.lowercased())"
            if seen.insert(key).inserted { out.append(h) }
        }
        return out
    }
}
