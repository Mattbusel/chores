import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: alpha)
    }
}

/// Sticker-book palette: warm cream paper, deep grape ink, a tomato accent and a sunny star yellow.
enum Ink {
    static let bg = Color(hex: 0xFFF7EC)
    static let bg2 = Color(hex: 0xFCEBD5)
    static let card = Color.white
    static let ink = Color(hex: 0x241C44)
    static let ink2 = Color(hex: 0x241C44, alpha: 0.64)
    static let dim = Color(hex: 0x241C44, alpha: 0.40)
    static let line = Color(hex: 0x241C44, alpha: 0.09)
    static let line2 = Color(hex: 0x241C44, alpha: 0.16)
    static let tomato = Color(hex: 0xFF5A36)
    static let sun = Color(hex: 0xFFC22E)
    static let sunSoft = Color(hex: 0xFFF1C7)
    static let gold = Color(hex: 0xE9A100)
    static let mint = Color(hex: 0x16A870)
    static let red = Color(hex: 0xE5484D)
    static let palette: [Color] = [Color(hex: 0xEC4F97), Color(hex: 0x16A870), Color(hex: 0x8457F0), Color(hex: 0x2F8CEF), Color(hex: 0xFF8A1F), Color(hex: 0x0FB3A3), Color(hex: 0xE5484D), Color(hex: 0x4F5BD5)]
    static func kid(_ i: Int) -> Color { palette[((i % palette.count) + palette.count) % palette.count] }
    static func jar(_ j: Jar) -> Color {
        switch j { case .spend: return Color(hex: 0xFF7A2F); case .save: return Color(hex: 0x16A870); case .give: return Color(hex: 0xEC4F97) }
    }
    static let emojis = ["🦄", "🦖", "🎧", "🐯", "🦊", "🐼", "🐸", "🐙", "🦋", "🐶", "🐱", "🐰", "🦁", "🐨", "🐵", "🐳", "🚀", "⚽️", "🎨", "🎸", "🌈", "⭐️", "🍓", "🌻"]
    static let choreEmojis = ["🛏️", "🧸", "🐟", "🍽️", "🪴", "🧽", "🦷", "🧹", "🐶", "🎒", "👕", "🗑️", "🧺", "📚", "🥪", "🛁", "🍳", "🌿", "♻️", "🧼", "🚗", "🐱", "🎹", "🏃"]
}

extension Font {
    static func r(_ size: CGFloat, _ w: Font.Weight = .bold) -> Font { .system(size: size, weight: w, design: .rounded) }
    static func num(_ size: CGFloat, _ w: Font.Weight = .heavy) -> Font { .system(size: size, weight: w, design: .rounded).monospacedDigit() }
}

enum Haptic {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func tap() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func warn() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

// MARK: Background

struct Backdrop: View {
    var tint: Color
    var body: some View {
        ZStack {
            Ink.bg
            Circle().fill(tint.opacity(0.20)).frame(width: 420, height: 420).blur(radius: 90).offset(x: 150, y: -330)
            Circle().fill(Ink.sun.opacity(0.18)).frame(width: 360, height: 360).blur(radius: 90).offset(x: -170, y: -260)
            Canvas { ctx, size in
                var y: CGFloat = 10
                var row = 0
                while y < size.height {
                    var x: CGFloat = row % 2 == 0 ? 10 : 24
                    while x < size.width { ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2.4, height: 2.4)), with: .color(Ink.ink.opacity(0.07))); x += 28 }
                    y += 24; row += 1
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: tint)
    }
}

// MARK: Pieces

struct Eyebrow: View {
    let text: String
    var color: Color = Ink.dim
    init(_ t: String, color: Color = Ink.dim) { text = t; self.color = color }
    var body: some View { Text(text.uppercased()).font(.r(11, .heavy)).tracking(1.4).foregroundStyle(color) }
}

struct Bouncy: ButtonStyle {
    var scale: CGFloat = 0.94
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

extension View {
    func sticker(_ radius: CGFloat = 24, fill: Color = Ink.card, shadow: Color = Ink.ink) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
                .shadow(color: shadow.opacity(0.10), radius: 14, y: 8)
        )
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Ink.line, lineWidth: 1))
    }
}

struct Chip: View {
    let text: String
    var icon: String? = nil
    var fg: Color = Ink.ink
    var bg: Color = Ink.card
    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 10, weight: .heavy)) }
            Text(text).font(.r(12, .heavy)).monospacedDigit()
        }
        .foregroundStyle(fg).padding(.horizontal, 9).padding(.vertical, 5)
        .background(Capsule().fill(bg))
    }
}

struct StarChip: View {
    let n: Int
    var big = false
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill").font(.system(size: big ? 13 : 10, weight: .heavy)).foregroundStyle(Ink.gold)
            Text("\(n)").font(.r(big ? 15 : 12, .heavy)).monospacedDigit().foregroundStyle(Ink.ink)
        }
        .padding(.horizontal, big ? 11 : 8).padding(.vertical, big ? 6 : 4)
        .background(Capsule().fill(Ink.sunSoft))
    }
}

struct Ring: View {
    let value: Double
    var color: Color
    var width: CGFloat = 6
    var track: Color = Ink.line
    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: width)
            Circle().trim(from: 0, to: max(0.001, min(1, value))).stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round)).rotationEffect(.degrees(-90))
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: value)
    }
}

struct Avatar: View {
    let kid: Kid
    var size: CGFloat = 56
    var ring = true
    var body: some View {
        let c = Ink.kid(kid.color)
        ZStack {
            Circle().fill(LinearGradient(colors: [c.opacity(0.22), c.opacity(0.10)], startPoint: .top, endPoint: .bottom))
            Text(kid.emoji).font(.system(size: size * 0.52))
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(ring ? c : Color.clear, lineWidth: max(2, size * 0.05)))
    }
}

/// The row of kid bubbles at the top of the kid screens.
struct KidPicker: View {
    @Environment(Store.self) private var store
    @Binding var selection: UUID?
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(store.kids) { k in bubble(k) }
            }
            .padding(.horizontal, 18).padding(.vertical, 4)
        }
    }
    @ViewBuilder
    private func bubble(_ k: Kid) -> some View {
        let on = selection == k.id
        let p = store.progress(k.id, Day.today)
        let c = Ink.kid(k.color)
        Button {
            Haptic.tap()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { selection = k.id }
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Ring(value: p.total == 0 ? 0 : Double(p.done) / Double(p.total), color: on ? Color.white : c, width: 3.5, track: on ? Color.white.opacity(0.3) : Ink.line)
                        .frame(width: 44, height: 44)
                    Text(k.emoji).font(.system(size: 22))
                }
                if on {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(k.name).font(.r(16, .heavy)).foregroundStyle(.white)
                        Text("\(p.done) of \(p.total) today").font(.r(11, .bold)).foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.trailing, 8)
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                }
            }
            .padding(5)
            .background(Capsule().fill(on ? c : Ink.card).shadow(color: (on ? c : Ink.ink).opacity(on ? 0.35 : 0.08), radius: on ? 10 : 6, y: 4))
            .overlay(Capsule().strokeBorder(on ? Color.clear : Ink.line, lineWidth: 1))
        }
        .buttonStyle(Bouncy())
    }
}

struct BigButton: View {
    let title: String
    var icon: String? = nil
    var fill: Color = Ink.tomato
    var fg: Color = .white
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .heavy)) }
                Text(title).font(.r(17, .heavy))
            }
            .foregroundStyle(fg).frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(fill).shadow(color: fill.opacity(0.35), radius: 10, y: 6))
        }
        .buttonStyle(Bouncy())
    }
}

struct SoftButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = Ink.ink
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .heavy)) }
                Text(title).font(.r(14, .heavy))
            }
            .foregroundStyle(tint).padding(.horizontal, 14).padding(.vertical, 10)
            .background(Capsule().fill(tint.opacity(0.10)))
        }
        .buttonStyle(Bouncy())
    }
}

struct ScreenTitle: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Eyebrow(eyebrow, color: Ink.tomato)
            Text(title).font(.r(34, .black)).foregroundStyle(Ink.ink).lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

/// Scrolling page with room for the floating tab bar.
struct Page<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) { content }.padding(.top, 8).padding(.bottom, 130)
        }
    }
}

/// "Kids can't do this" hint.
struct LockedNote: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill").font(.system(size: 12, weight: .heavy))
            Text(text).font(.r(13, .bold))
        }
        .foregroundStyle(Ink.ink2).frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Ink.ink.opacity(0.05)))
    }
}
