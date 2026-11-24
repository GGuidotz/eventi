# Eventi

App macOS che legge un testo o un documento e ne estrae gli eventi (titolo, luogo, data, ora di inizio e di fine) in formato .ics, pronto per Calendario.

- **Input:** testo incollato, PDF (anche scansionati), immagini (OCR), Word, RTF, HTML, email .eml, testo semplice. Trascina sulla finestra o sull'icona.
- **Motori, tutti sul Mac:** Apple Intelligence (consigliato), Gemma 1B (il modello GGUF già installato da Cotypist / Type with me, eseguito con llama.cpp), regole. Le date e gli orari scritti nel testo controllano sempre il risultato dei modelli.
- **Uscita:** salva un .ics o aprilo in Calendario; ogni evento si corregge prima.

Requisiti: macOS 26. Per Gemma: `brew install llama.cpp`.

Il codice è tutto qui: `--recursive` scarica anche Sguardo, il sistema di design comune (github.com/GGuidotz/sguardo), in
`Vendor/Sguardo`; se hai già clonato senza, esegui `git submodule update --init`.

```
git clone --recursive https://github.com/GGuidotz/eventi.git
cd eventi
./build.sh --install
```

Nessun dato lascia il Mac.
