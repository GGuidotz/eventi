## 0.2.1 · 2026-11-24

Una veste nuova: forme, colori e movimenti di Sguardo, il sistema di design comune alle nostre app.

### Novità
- **Colore d'accento a scelta.** In Impostazioni › Aspetto: il viola di Eventi, il colore d'accento di macOS o uno tuo.

### Miglioramenti
- **Finestra principale ridisegnata.** Il testo e gli eventi stanno su schede traslucide con un filo sottile; i pulsanti sono capsule e c'è una sola azione in evidenza: "Estrai eventi" prima, "Salva .ics…" quando gli eventi ci sono. Ogni evento ha campi più morbidi e interruttori al posto delle caselle.
- **Impostazioni nello stesso stile.** Righe raggruppate, menu a capsula, stato del motore con un segno verde o arancione e una nota sotto.
- **Si compila da un clone.** Sguardo arriva con `git clone --recursive`: chi compila dal codice ha tutto.

## 0.2.0 · 2026-11-16

Documenti di viaggio letti a regole: voli e hotel con orari locali corretti.

### Novità
- **Viaggi.** Voli (partenza e arrivo nel fuso di ciascun aeroporto) e check-in/check-out dell'hotel da biglietti, itinerari e voucher, con descrizione (PNR, biglietto, passeggero, bagaglio, voucher).
- **Un file per evento.** Salva ogni evento in un .ics numerato, oltre al file unico.
- **Descrizione.** Gli eventi hanno un campo descrizione modificabile; il file contiene stato e disponibilità.

### Correzioni
- **Titoli.** Tolte le parole residue sull'ora di fine ("finiamo verso le…").

## 0.1.0 · 2026-11-16

Prima versione: trascini un testo o un documento e ottieni gli eventi in formato .ics.

### Novità
- **Estrazione degli eventi.** Titolo, luogo, data, ora di inizio e di fine da testo, PDF, immagini (OCR), Word, RTF, HTML ed email.
- **Due motori sul Mac.** Apple Intelligence e Gemma 1B (il modello già presente per Cotypist), con le regole come ripiego e come controllo di date e orari.
- **Esportazione.** Salva un file .ics o aprilo direttamente in Calendario; ogni evento si corregge prima.
