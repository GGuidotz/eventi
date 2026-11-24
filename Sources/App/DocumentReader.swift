// Lettura dei documenti in testo, tutto sul Mac: PDF (PDFKit, con OCR Vision sulle pagine scansionate), immagini
// (Vision), Word/RTF/HTML (NSAttributedString), email .eml, testo semplice.

import Foundation
import AppKit
import PDFKit
@preconcurrency import Vision
import UniformTypeIdentifiers

enum DocumentReader {
    enum Failure: LocalizedError {
        case unsupported(String), empty(String)
        var errorDescription: String? {
            switch self {
            case .unsupported(let n): L("Formato non supportato: %@", n)
            case .empty(let n): L("Nessun testo trovato in %@", n)
            }
        }
    }

    static func read(_ url: URL) async throws -> String {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent
        let text: String
        switch ext {
        case "pdf": text = try await readPDF(url)
        case "png", "jpg", "jpeg", "heic", "heif", "tif", "tiff", "gif", "bmp", "webp":
            guard let img = NSImage(contentsOf: url), let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
            else { throw Failure.unsupported(name) }
            text = try await ocr(cg)
        case "docx": text = try attributed(url, .officeOpenXML)
        case "doc": text = try attributed(url, .docFormat)
        case "rtf": text = try attributed(url, .rtf)
        case "rtfd": text = try attributed(url, .rtfd)
        case "html", "htm": text = try attributed(url, .html)
        case "eml": text = readEmail(url)
        case "txt", "md", "markdown", "csv", "text", "log", "":
            text = try readPlain(url)
        default:
            // Ultimo tentativo: se è testo, va bene.
            if let t = try? readPlain(url), !t.isEmpty, !t.contains("\u{0}") { text = t } else { throw Failure.unsupported(name) }
        }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { throw Failure.empty(name) }
        return t
    }

    // MARK: Formati

    private static func readPlain(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        for enc in [String.Encoding.utf8, .utf16, .isoLatin1, .macOSRoman] {
            if let s = String(data: data, encoding: enc) { return s }
        }
        return ""
    }

    private static func attributed(_ url: URL, _ type: NSAttributedString.DocumentType) throws -> String {
        let a = try NSAttributedString(url: url, options: [.documentType: type], documentAttributes: nil)
        return a.string
    }

    private static func readPDF(_ url: URL) async throws -> String {
        guard let doc = PDFDocument(url: url) else { throw Failure.unsupported(url.lastPathComponent) }
        var parts: [String] = []
        for i in 0..<min(doc.pageCount, 30) {
            guard let page = doc.page(at: i) else { continue }
            let t = (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if t.count >= 20 { parts.append(t); continue }
            // Pagina scansionata: la disegno e leggo con OCR.
            let box = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2
            let size = NSSize(width: box.width * scale, height: box.height * scale)
            let img = page.thumbnail(of: size, for: .mediaBox)
            if let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let o = try await ocr(cg)
                if !o.isEmpty { parts.append(o) }
            }
        }
        return parts.joined(separator: "\n\n")
    }

    static func ocr(_ image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            let req = VNRecognizeTextRequest { r, e in
                if let e { cont.resume(throwing: e); return }
                let lines = (r.results as? [VNRecognizedTextObservation])?.compactMap { $0.topCandidates(1).first?.string } ?? []
                cont.resume(returning: lines.joined(separator: "\n"))
            }
            req.recognitionLevel = .accurate
            req.usesLanguageCorrection = true
            req.recognitionLanguages = ["it-IT", "en-US", "fr-FR"]
            DispatchQueue.global(qos: .userInitiated).async {
                do { try VNImageRequestHandler(cgImage: image, options: [:]).perform([req]) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    /// .eml: oggetto + data + corpo (testo, quoted-printable decodificato alla buona).
    private static func readEmail(_ url: URL) -> String {
        guard let raw = try? readPlain(url) else { return "" }
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        let parts = normalized.components(separatedBy: "\n\n")
        let head = parts.first ?? ""
        var body = parts.dropFirst().joined(separator: "\n\n")
        var subject = "", date = ""
        for line in head.components(separatedBy: "\n") {
            if line.lowercased().hasPrefix("subject:") { subject = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces) }
            if line.lowercased().hasPrefix("date:") { date = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
        }
        if head.lowercased().contains("quoted-printable") || body.contains("=\n") {
            body = body.replacingOccurrences(of: "=\n", with: "")
            // =C3=A8 -> byte UTF-8
            var bytes: [UInt8] = []
            let u = Array(body.utf8)
            var i = 0
            while i < u.count {
                if u[i] == 0x3D, i + 2 < u.count, let h = UInt8(String(decoding: u[i+1...i+2], as: UTF8.self), radix: 16) {
                    bytes.append(h); i += 3
                } else { bytes.append(u[i]); i += 1 }
            }
            body = String(decoding: bytes, as: UTF8.self)
        }
        _ = date   // la data d'invio non entra nel testo: sarebbe presa per un evento
        return [subject.isEmpty ? "" : "Oggetto: \(subject)", body].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}
