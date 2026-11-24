import Foundation
// Prova da riga di comando: ./tools/test-core.sh [rules|gemma|apple]
let samples = [
 """
 ITA Airways - Ricevuta del biglietto elettronico
 Passeggero: ROSSI/MARTA MS
 Codice prenotazione (PNR): AB12CD
 Numero biglietto: 055 2345678901
 Volo AZ 1234   Classe: Economy   Bagaglio: solo bagaglio a mano
 Partenza: Milano Linate (LIN)  02 dic 2026  12:05
 Arrivo: Bruxelles (BRU)  02 dic 2026  14:00

 Volo SN 3149   Classe: Economy
 Partenza: Bruxelles (BRU)  05 dic 2026  17:30
 Arrivo: Milano Linate (LIN)  05 dic 2026  19:20

 Hotel Esempio Grand Place
 Rue Exemple 12, 1000 Bruxelles
 Check-in: 02/12/2026 dalle 15:00   Check-out: 05/12/2026 entro le 12:00
 Voucher n. 998877   Camera: Doppia   3 notti   Tel +32 2 000 00 00
 """,
 "Ciao Marta, riunione di progetto giovedì 20 novembre 2026 alle 15:00 in sala Rossi, finiamo verso le 16:30.",
 "Convegno sulla salute digitale, Università Bocconi, 12 gennaio 2027 dalle 9:30 alle 13:00.\nWorkshop pratico lo stesso giorno 14:00-17:00 aula 3.",
 "Programma:\n- 3 febbraio 2027 ore 10 Lancio del progetto ALFA, Milano\n- 4 febbraio 2027 ore 15:30 Revisione con Studio Rossi\n- 5 febbraio 2027 Consegna bozza",
]
let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "rules"
let now = EventBuilder.calendar().date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 12))!
var engine: EventEngine? = mode == "gemma" ? GemmaEngine.make() : nil
#if APPLE
if mode == "apple" { engine = EngineFactory.make(.apple) }
#endif

let sem = DispatchSemaphore(value: 0)
Task {
    for s in samples {
        let r = await Pipeline.run(text: s, engine: engine, now: now)
        print("---", mode, "\n" + s.prefix(60))
        for e in r.events {
            print("  \(e.title) | \(e.location) | \(e.start) -> \(e.end) | allDay=\(e.allDay)")
        }
        r.notes.forEach { print("  nota:", $0) }
    }
    print(ICS.make([EventBuilder.make(RawEvent(title: "Prova, con virgola", location: "Sala; 1", date: "2026-11-20", start: "15:00", end: "16:30"))!]))
    sem.signal()
}
sem.wait()
