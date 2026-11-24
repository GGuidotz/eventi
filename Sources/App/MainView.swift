import SwiftUI
import UniformTypeIdentifiers

/// La finestra principale. L'accento e il fondo di Sguardo stanno qui, alla radice; il resto è in `MainContent`.
struct MainView: View {
    var body: some View {
        MainContent()
            .background(SGWindowBackground().ignoresSafeArea())
            .sguardoAccent(default: .eventi)
    }
}

private struct MainContent: View {
    @ObservedObject var model = AppModel.shared
    @State private var targeted = false
    @Environment(\.sgAccent) private var accent

    var body: some View {
        VStack(spacing: 0) {
            input
            results
            footer
        }
        .frame(minWidth: 620, minHeight: 560)
        .onDrop(of: [.fileURL, .plainText], isTargeted: $targeted) { providers in handleDrop(providers) }
        .overlay {
            if targeted {
                RoundedRectangle(cornerRadius: SG.Radius.row, style: .continuous)
                    .fill(accent.selectedWash)
                    .overlay(RoundedRectangle(cornerRadius: SG.Radius.row, style: .continuous)
                        .strokeBorder(accent.base, style: StrokeStyle(lineWidth: SG.Stroke.selectionRing, dash: [8])))
                    .padding(6).allowsHitTesting(false)
            }
        }
        .animation(SG.Motion.respecting(SG.Motion.snappy), value: targeted)
    }

    // MARK: Ingresso

    private var input: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.text)
                    .font(SG.Font.body)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                if model.text.isEmpty {
                    Text(L("Incolla un testo o trascina qui PDF, immagini, documenti Word, email."))
                        .font(SG.Font.body)
                        .foregroundStyle(SG.Ink.secondary)
                        .padding(.horizontal, 15).padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 130)
            .contentCard(padding: 0)
            .overlay(alignment: .bottomTrailing) {
                // L'avanzamento sta nell'angolo della scheda del testo: niente salti di layout quando compare.
                if model.isWorking {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(L("Analisi %d di %d…", model.progress.0 + 1, max(model.progress.1, 1)))
                            .font(SG.Font.caption).foregroundStyle(SG.Ink.secondary).monospacedDigit()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                }
            }

            if !model.fileNames.isEmpty {
                Text(model.fileNames.joined(separator: " · "))
                    .font(SG.Font.caption).foregroundStyle(SG.Ink.secondary).lineLimit(1)
                    .padding(.horizontal, SG.Space.sectionTitleInset)
            }

            HStack(spacing: 8) {
                Button(L("Scegli file…"), action: chooseFiles).buttonStyle(.sgSecondary)
                Button(L("Incolla"), action: model.pasteFromClipboard).buttonStyle(.sgSecondary)
                Button(L("Pulisci"), action: model.clear).buttonStyle(.sgSecondary)
                    .disabled(model.text.isEmpty && model.events.isEmpty)
                Spacer()
                SGPickerPill(model.title(model.choice)) {
                    Picker("", selection: Binding(get: { model.choice }, set: { model.choice = $0 })) {
                        ForEach(EngineChoice.allCases) { Text(model.title($0)).tag($0) }
                    }
                    .pickerStyle(.inline).labelsHidden()
                }
                Button(action: model.extract) {
                    Text(L("Estrai eventi")).frame(minWidth: 90)
                }
                // Una sola azione principale per vista: "Estrai" finché non ci sono eventi, poi "Salva .ics".
                .buttonStyle(SGCapsuleButtonStyle(model.events.isEmpty ? .primary : .secondary, size: .large))
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.isWorking || model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, SG.Space.contentPadding)
        .padding(.top, SG.Space.contentPadding)
        .padding(.bottom, SG.Space.m)
    }

    // MARK: Risultati

    @ViewBuilder private var results: some View {
        if model.events.isEmpty {
            VStack(spacing: SG.Space.m) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: SG.Size.emptyStateIcon))
                    .foregroundStyle(SG.Ink.secondary)
                Text(model.message.isEmpty ? L("Gli eventi trovati compariranno qui.") : model.message)
                    .font(SG.Font.body).foregroundStyle(SG.Ink.secondary)
                    .multilineTextAlignment(.center)
                ForEach(model.notes, id: \.self) {
                    Text($0).font(SG.Font.caption).foregroundStyle(SG.Ink.secondary).multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, SG.Space.contentPadding)
        } else {
            ScrollView {
                LazyVStack(spacing: SG.Space.rowSpacing) {
                    ForEach($model.events) { $e in EventRow(event: $e) }
                    ForEach(model.notes, id: \.self) { SGFootnote($0) }
                }
                .padding(.horizontal, SG.Space.contentPadding)
                .padding(.vertical, 4)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: Piede

    private var footer: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.events.isEmpty ? "" : L("%d di %d eventi selezionati", model.includedCount, model.events.count))
                    .font(SG.Font.body).foregroundStyle(SG.Ink.secondary).monospacedDigit().lineLimit(1)
                if !model.message.isEmpty && !model.events.isEmpty {
                    Text(model.message).font(SG.Font.caption).foregroundStyle(SG.Ink.secondary).lineLimit(1)
                }
            }
            .layoutPriority(-1)
            Spacer()
            Button(L("Apri in Calendario"), action: model.openInCalendar)
                .buttonStyle(SGCapsuleButtonStyle(.secondary, size: .large)).fixedSize()
                .disabled(model.includedCount == 0)
            Button(L("Un file per evento…"), action: model.saveSeparate)
                .buttonStyle(SGCapsuleButtonStyle(.secondary, size: .large)).fixedSize()
                .disabled(model.includedCount < 2)
            Button(L("Salva .ics…"), action: model.saveICS)
                .buttonStyle(SGCapsuleButtonStyle(model.events.isEmpty ? .secondary : .primary, size: .large)).fixedSize()
                .keyboardShortcut("s", modifiers: .command)
                .disabled(model.includedCount == 0)
        }
        .padding(.horizontal, SG.Space.contentPadding)
        .padding(.top, SG.Space.m)
        .padding(.bottom, SG.Space.l)
    }

    // MARK: Azioni

    private func chooseFiles() {
        let p = NSOpenPanel()
        p.allowsMultipleSelection = true
        p.canChooseDirectories = false
        if p.runModal() == .OK { model.add(urls: p.urls) }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for p in providers {
            if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    var url: URL?
                    if let d = item as? Data { url = URL(dataRepresentation: d, relativeTo: nil) }
                    else if let u = item as? URL { url = u }
                    if let url { Task { @MainActor in model.add(urls: [url]) } }
                }
            } else if p.canLoadObject(ofClass: String.self) {
                handled = true
                _ = p.loadObject(ofClass: String.self) { s, _ in
                    if let s { Task { @MainActor in model.add(text: s); model.extract() } }
                }
            }
        }
        return handled
    }
}

struct EventRow: View {
    @Binding var event: EventDraft

    var body: some View {
        HStack(alignment: .top, spacing: SG.Space.m) {
            SGToggle(isOn: $event.include).accessibilityLabel(event.title).padding(.top, 5)
            VStack(alignment: .leading, spacing: 8) {
                TextField(L("Titolo"), text: $event.title).sgField(font: SG.Font.bodyEmphasis)
                TextField(L("Luogo"), text: $event.location).sgField()
                if !event.details.isEmpty || event.kind != .generic {
                    TextField(L("Descrizione"), text: $event.details, axis: .vertical)
                        .lineLimit(2...6).sgField(multiline: true)
                }
                HStack(spacing: 12) {
                    DatePicker("", selection: startBinding, displayedComponents: event.allDay ? [.date] : [.date, .hourAndMinute])
                        .labelsHidden()
                    if !event.allDay {
                        Text(L("fino alle")).foregroundStyle(SG.Ink.secondary).font(SG.Font.field)
                        DatePicker("", selection: endBinding, displayedComponents: [.hourAndMinute]).labelsHidden()
                    }
                    Spacer(minLength: 8)
                    Text(L("Tutto il giorno")).font(SG.Font.field).foregroundStyle(SG.Ink.primary)
                    SGToggle(isOn: allDayBinding).accessibilityLabel(L("Tutto il giorno"))
                }
            }
        }
        .contentCard(padding: 14)
        .opacity(event.include ? 1 : 0.5)
    }

    private var startBinding: Binding<Date> {
        Binding(get: { event.start }, set: { new in
            let delta = new.timeIntervalSince(event.start)
            event.start = new
            event.end = event.end.addingTimeInterval(delta)   // la durata resta uguale
        })
    }

    /// La fine è solo un'ora: il giorno è quello dell'inizio.
    private var endBinding: Binding<Date> {
        Binding(get: { event.end }, set: { new in
            let cal = EventBuilder.calendar()
            let hm = cal.dateComponents([.hour, .minute], from: new)
            var e = cal.date(bySettingHour: hm.hour ?? 0, minute: hm.minute ?? 0, second: 0, of: event.start) ?? new
            if e <= event.start { e = e.addingTimeInterval(24 * 3600) }
            event.end = e
        })
    }

    private var allDayBinding: Binding<Bool> {
        Binding(get: { event.allDay }, set: { v in
            let cal = EventBuilder.calendar()
            if v {
                event.start = cal.startOfDay(for: event.start); event.end = event.start
            } else {
                event.start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: event.start) ?? event.start
                event.end = event.start.addingTimeInterval(EventBuilder.defaultDuration)
            }
            event.allDay = v
        })
    }
}
