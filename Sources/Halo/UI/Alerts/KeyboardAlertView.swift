import SwiftUI

/// Left wing of a keyboard alert: the globe for a layout change, the Caps Lock arrow.
struct KeyboardAlertGlyph: View {
    let alert: KeyboardAlert

    var body: some View {
        Image(systemName: symbol)
            .font(Glyph.wing)
            .foregroundStyle(tint)
            .contentTransition(.symbolEffect(.replace))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }

    private var symbol: String {
        switch alert {
        case .layout: "globe"
        case .capsLock(let on): on ? "capslock.fill" : "capslock"
        }
    }

    private var tint: Color {
        switch alert {
        case .layout: .white
        case .capsLock(let on): on ? Color(red: 0.4, green: 0.9, blue: 0.5) : Ink.secondary
        }
    }
}

/// Right wing of a keyboard alert: the layout's name, or Caps Lock's state.
struct KeyboardAlertValue: View {
    let alert: KeyboardAlert

    var body: some View {
        HStack(spacing: 5) {
            switch alert {
            case .layout(let source):
                if let language = source.language {
                    Text(language.uppercased())
                        .font(.system(size: 9, weight: .bold).monospaced())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 3)
                        .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Color.white.opacity(0.85)))
                }
                Text(source.name)
                    .font(Typography.callout.weight(.semibold))
                    .foregroundStyle(.white)
            case .capsLock(let on):
                Text(on ? "Maiusc attivo" : "Maiusc spento")
                    .font(Typography.callout.weight(.semibold))
                    .foregroundStyle(on ? Color(red: 0.4, green: 0.9, blue: 0.5) : Ink.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
