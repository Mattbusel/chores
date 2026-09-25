import SwiftUI

/// One confetti burst. Particles are derived from the seed, so the same burst always looks the same.
struct Burst: Identifiable, Equatable {
    let id = UUID()
    var origin: CGPoint
    var colors: [Color]
    var start = Date()
    var big = false
    var label: String? = nil
    /// Screenshots freeze a burst at this many seconds in.
    var frozen: Double? = nil
    var seed: UInt64 = UInt64.random(in: 1...UInt64.max / 2)
}

/// Full-screen confetti layer. Drawn with Canvas inside a TimelineView, no hit testing.
struct ConfettiLayer: View {
    let bursts: [Burst]
    var body: some View {
        TimelineView(.animation(paused: bursts.isEmpty)) { tl in
            Canvas { ctx, size in
                for b in bursts { draw(b, now: tl.date, ctx: &ctx, size: size) }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func draw(_ b: Burst, now: Date, ctx: inout GraphicsContext, size: CGSize) {
        let t = b.frozen ?? now.timeIntervalSince(b.start)
        guard t >= 0, t < 3.2 else { return }
        var rng = b.seed
        func rnd() -> Double { rng = rng &* 6364136223846793005 &+ 1442695040888963407; return Double((rng >> 33) % 10_000) / 10_000 }
        let n = b.big ? 140 : 46
        let g: Double = b.big ? 900 : 1100
        for i in 0..<n {
            let ang = b.big ? (-Double.pi / 2 + (rnd() - 0.5) * 2.4) : (rnd() * 2 * .pi)
            let speed = (b.big ? 520 : 260) + rnd() * (b.big ? 560 : 320)
            let vx = cos(ang) * speed * (b.big ? 0.85 : 1)
            var vy = sin(ang) * speed
            if !b.big { vy -= 260 }
            let drag = 1.0 / (1 + t * 1.3)
            let x = b.origin.x + vx * t * drag
            let y = b.origin.y + vy * t * drag + 0.5 * g * t * t * 0.55
            let alpha = t < 2.2 ? 1 : max(0, 1 - (t - 2.2) / 1.0)
            let spin = (rnd() - 0.5) * 16 * t + rnd() * 6
            let w = 6 + rnd() * 7, h = 4 + rnd() * 5
            let color = b.colors[i % b.colors.count]
            var c = ctx
            c.opacity = alpha
            c.translateBy(x: x, y: y)
            c.rotate(by: .radians(spin))
            let flip = abs(cos(t * (4 + rnd() * 6)))
            let kind = i % 4
            if kind == 0 {
                c.fill(Path(ellipseIn: CGRect(x: -w / 2, y: -w / 2, width: w, height: w)), with: .color(color))
            } else if kind == 1 {
                c.fill(star(r: w * 0.85), with: .color(Ink.sun))
            } else {
                c.fill(Path(roundedRect: CGRect(x: -w / 2, y: -h * flip / 2, width: w, height: max(1, h * flip)), cornerRadius: 1.5), with: .color(color))
            }
        }
        if let label = b.label {
            let rise = min(1, t / 0.6)
            let a = t < 1.3 ? 1 : max(0, 1 - (t - 1.3) / 0.6)
            var c = ctx
            c.opacity = a
            let scale = 0.6 + 0.5 * sin(min(1, t / 0.35) * .pi / 2)
            c.translateBy(x: b.origin.x, y: b.origin.y - 70 * rise - 30)
            c.scaleBy(x: scale, y: scale)
            c.draw(Text(label).font(.r(30, .black)).foregroundStyle(Ink.gold), at: .zero)
        }
    }

    private func star(r: Double) -> Path {
        var p = Path()
        for k in 0..<10 {
            let rr = k % 2 == 0 ? r : r * 0.45
            let a = Double(k) * .pi / 5 - .pi / 2
            let pt = CGPoint(x: cos(a) * rr, y: sin(a) * rr)
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath(); return p
    }
}

/// The "all done for today" moment.
struct AllDoneCard: View {
    let kid: Kid
    let stars: Int
    let streak: Int
    var close: () -> Void
    @State private var pop = false
    var body: some View {
        let c = Ink.kid(kid.color)
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(c.opacity(0.16)).frame(width: 150, height: 150).scaleEffect(pop ? 1 : 0.4)
                    Circle().strokeBorder(c.opacity(0.35), style: StrokeStyle(lineWidth: 3, dash: [2, 9])).frame(width: 176, height: 176).rotationEffect(.degrees(pop ? 40 : 0))
                    Text(kid.emoji).font(.system(size: 84)).scaleEffect(pop ? 1 : 0.2).rotationEffect(.degrees(pop ? 0 : -30))
                    Image(systemName: "crown.fill").font(.system(size: 34, weight: .black)).foregroundStyle(Ink.sun)
                        .shadow(color: Ink.gold.opacity(0.5), radius: 4, y: 2)
                        .offset(y: -84).scaleEffect(pop ? 1 : 0).rotationEffect(.degrees(pop ? -8 : 0))
                }
                .padding(.top, 8)
                Text("All done, \(kid.name)!").font(.r(30, .black)).foregroundStyle(Ink.ink)
                Text("Every chore for today is finished.").font(.r(15, .semibold)).foregroundStyle(Ink.ink2)
                HStack(spacing: 10) {
                    stat("\(stars)", "stars today", "star.fill", Ink.gold)
                    stat("\(streak)", streak == 1 ? "day streak" : "days in a row", "flame.fill", Ink.tomato)
                }
                .padding(.top, 4)
                BigButton(title: "High five!", icon: "hand.raised.fill", fill: c, action: close).padding(.top, 6)
            }
            .padding(22)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(Ink.card).shadow(color: .black.opacity(0.2), radius: 30, y: 16))
            .scaleEffect(pop ? 1 : 0.7).opacity(pop ? 1 : 0)
        }
        .onAppear { withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { pop = true } }
    }
    private func stat(_ v: String, _ l: String, _ icon: String, _ col: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 16, weight: .heavy)).foregroundStyle(col)
                Text(v).font(.num(26)).foregroundStyle(Ink.ink)
            }
            Text(l).font(.r(12, .bold)).foregroundStyle(Ink.dim)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(col.opacity(0.10)))
    }
}
