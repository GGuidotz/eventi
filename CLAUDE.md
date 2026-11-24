# Eventi

App macOS (Swift/SwiftUI + AppKit, macOS 26+, finestra classica) che estrae eventi da testi e documenti e li esporta in .ics.
Stesso schema di GGuidotz/smartmemo e whats-going-on.

- Compilazione: `./build.sh` (swiftc diretto). Prova della logica senza interfaccia: `./tools/test-core.sh [rules|gemma]`.
- `Sources/Core` solo Foundation: modello, `RuleExtractor` (NSDataDetector/NLTagger), `Pipeline` (finestre, controllo con le regole),
  `GemmaEngine` (llama-completion come processo, grammatica GBNF), `ICS`. `Sources/App`: AppKit/SwiftUI, Apple Intelligence
  (`AppleEngine`, dietro `#if canImport(FoundationModels)`), `DocumentReader` (PDFKit, Vision, NSAttributedString).
- Gemma 1B base ("pt") è debole: va usato a finestre piccole, con grammatica, e il risultato si ancora al testo (`Pipeline.merge`).
- Testi: chiave = frase italiana, `L("…")`, traduzioni in `Localization/en.lproj`. Controllo: `python3 -I tools/check-strings.py`.
- Mai dati reali di Giulio nel repository (pubblico): solo esempi inventati.
