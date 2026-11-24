// Stile di Eventi. Forme, riempimenti e movimenti vengono da Sguardo, il sistema di design comune (github.com/GGuidotz/sguardo,
// submodule in Vendor/Sguardo, compilato insieme all'app da build.sh): qui restano l'accento e i pochi pezzi che il kit non ha.
// Regola (HIG, Liquid Glass): il vetro solo sui controlli che galleggiano; il contenuto usa riempimenti traslucidi con un
// filo da 1 pt. Eventi non ha controlli che galleggiano (niente barra delle schede, niente popover), quindi non usa vetro.

import AppKit
import SwiftUI

extension SG.Accent {
    /// L'accento di Eventi per Sguardo: un viola-indaco (#6C4DE6). L'app non ha ancora un'icona né un colore del marchio:
    /// è un valore di partenza, che la persona può cambiare in Impostazioni › Aspetto. Il bianco sopra fa 5,5:1.
    static let eventi = SG.Accent(hex: 0x6C4DE6)
}

extension View {
    /// Una scheda del contenuto, come le righe di Sguardo: velo traslucido (più bianco della finestra in chiaro), filo da
    /// 1 pt, angoli continui da 16 pt. Niente vetro, niente ombre.
    func contentCard(padding: CGFloat = 12, radius: CGFloat = SG.Radius.row) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(ContentCardBackground(radius: radius))
    }

    /// Campo di testo dentro una scheda: velo leggero e filo, capsula (angoli più morbidi se il testo va a capo).
    /// Sguardo ha solo il campo scuro delle isole (`SGIslandField`): questo è il suo gemello per le finestre chiare.
    func sgField(font: Font = SG.Font.field, multiline: Bool = false) -> some View {
        modifier(SGFieldStyle(font: font, multiline: multiline))
    }
}

private struct ContentCardBackground: ViewModifier {
    var radius: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .sgRowSurface(in: shape)
            .overlay {
                // Aumenta contrasto: un bordo pieno sopra il filo.
                if contrast == .increased { shape.strokeBorder(Color.primary.opacity(0.35), lineWidth: 1) }
            }
    }
}

private struct SGFieldStyle: ViewModifier {
    var font: Font
    var multiline: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: multiline ? 14 : 15, style: .continuous)
        content
            .textFieldStyle(.plain)
            .font(font)
            .foregroundStyle(SG.Ink.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minHeight: 28)
            .background(shape.fill(SG.Fill.tile))
            .overlay(shape.strokeBorder(contrast == .increased ? Color.primary.opacity(0.35) : SG.Fill.rowBorder,
                                        lineWidth: SG.Stroke.hairline))
    }
}
