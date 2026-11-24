import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @ObservedObject var model = AppModel.shared
    @State private var targeted = false

    var body: some View {
        VStack(spacing: 0) {
            input
            Divider()
            results
            Divider()
            footer
        }
        .frame(minWidth: 620, minHeight: 560)
        .onDrop(of: [.fileURL, .plainText], isTargeted: $targeted) { providers in handleDrop(providers) }
        .overlay {
            if targeted {
                RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .padding(6).allowsHitTesting(false)
            }
        }
    }

    // MARK: Ingresso

    private var input: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.25)))
                if model.text.isEmpty {
                    Text(L("Incolla un testo o trascina qui PDF, immagini, documenti Word, email."))
                        .foregroundStyle(.secondary).padding(.horizontal, 12).padding(.vertical, 14).allowsHitTesting(false)
                }
            }
            .frame(minHeight: 130)

            if !model.fileNames.isEmpty {
                Text(model.fileNames.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }

            HStack(spacing: 10) {
                Button(L("Scegli file…"), action: chooseFiles)
                Button(L("Incolla"), action: model.pasteFromClipboard)
                Button(L("Pulisci"), action: model.clear).disabled(model.text.isEmpty && model.events.isEmpty)
                Spacer()
                Picker("", selection: Binding(get: { model.choice }, set: { model.choice = $0 })) {
                    ForEach(EngineChoice.allCases) { Text(model.title($0)).tag($0) }
                }
                .pickerStyle(.menu).labelsHidden().fixedSize()
                Button(action: model.extract) {
                    Text(L("Estrai eventi")).frame(minWidth: 90)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.isWorking || model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if model.isWorking {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(L("Analisi %d di %d…", model.progress.0 + 1, max(model.progress.1, 1)))
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
        .padding(14)
    }

    // MARK: Risultati

    @ViewBuilder private var results: some View {
        if model.events.isEmpty {
            VStack(spacing: 6) {
                Spacer()
                Image(systemName: "calendar.badge.plus").font(.system(size: 30)).foregroundStyle(.secondary)
                Text(model.message.isEmpty ? L("Gli eventi trovati compariranno qui.") : model.message)
                    .foregroundStyle(.secondary)
                ForEach(model.notes, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            List {
                ForEach($model.events) { $e in EventRow(event: $e) }
                if !model.notes.isEmpty {
                    ForEach(model.notes, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                }
            }
            .listStyle(.inset)
        }
    }

    // MARK: Piede

    private var footer: some View {
        HStack(spacing: 10) {
            Text(model.events.isEmpty ? "" : L("%d di %d eventi selezionati", model.includedCount, model.events.count))
                .font(.callout).foregroundStyle(.secondary).monospacedDigit()
            if !model.message.isEmpty && !model.events.isEmpty {
                Text(model.message).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button(L("Apri in Calendario"), action: model.openInCalendar)
                .disabled(model.includedCount == 0)
            Button(L("Un file per evento…"), action: model.saveSeparate)
                .disabled(model.includedCount < 2)
            Button(L("Salva .ics…"), action: model.saveICS)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(model.includedCount == 0)
        }
        .padding(12)
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
        HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: $event.include).labelsHidden().padding(.top, 4)
            VStack(alignment: .leading, spacing: 6) {
                TextField(L("Titolo"), text: $event.title).textFieldStyle(.roundedBorder).font(.headline)
                TextField(L("Luogo"), text: $event.location).textFieldStyle(.roundedBorder)
                if !event.details.isEmpty || event.kind != .generic {
                    TextField(L("Descrizione"), text: $event.details, axis: .vertical)
                        .textFieldStyle(.roundedBorder).lineLimit(2...6).font(.callout)
                }
                HStack(spacing: 12) {
                    DatePicker("", selection: startBinding, displayedComponents: event.allDay ? [.date] : [.date, .hourAndMinute])
                        .labelsHidden()
                    if !event.allDay {
                        Text(L("fino alle")).foregroundStyle(.secondary).font(.callout)
                        DatePicker("", selection: endBinding, displayedComponents: [.hourAndMinute]).labelsHidden()
                    }
                    Toggle(L("Tutto il giorno"), isOn: allDayBinding).toggleStyle(.checkbox)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 6)
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
