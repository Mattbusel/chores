import SwiftUI
import UIKit

struct BankView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        @Bindable var router = router
        Page {
            HStack(alignment: .top) {
                ScreenTitle(eyebrow: "Allowance bank", title: store.kid(router.kid).map { "\($0.name)'s jars" } ?? "Jars")
                Spacer()
                ModePill()
            }
            .padding(.horizontal, 18)
            if store.kids.isEmpty {
                Welcome().padding(.horizontal, 18)
            } else {
                KidPicker(selection: $router.kid)
                if let k = store.kid(router.kid) {
                    JarShelf(kid: k).padding(.horizontal, 18)
                    GoalCard(kid: k).padding(.horizontal, 18)
                    if router.grownUp {
                        BigButton(title: "Add, spend or move money", icon: "plus.forwardslash.minus", fill: Ink.ink) { router.sheet = .money(k.id) }
                            .padding(.horizontal, 18)
                    } else {
                        LockedNote(text: "A grown-up adds and pays out money").padding(.horizontal, 18)
                    }
                    Ledger(kid: k).padding(.horizontal, 18)
                }
            }
        }
    }
}

/// Three glass jars that fill with coins.
struct JarShelf: View {
    @Environment(Store.self) private var store
    let kid: Kid
    var body: some View {
        let vals = Jar.allCases.map { store.balance(kid.id, $0) }
        let top = max(vals.max() ?? 0, 1)
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("In the bank")
                Spacer()
                Text(store.money(store.total(kid.id))).font(.num(30)).foregroundStyle(Ink.ink)
            }
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(Jar.allCases.enumerated()), id: \.element) { i, j in
                    VStack(spacing: 8) {
                        CoinJar(fill: vals[i] <= 0 ? 0 : 0.12 + 0.78 * vals[i] / top, color: Ink.jar(j), seed: UInt64(i + 3))
                            .frame(height: 176)
                        Text(store.money(vals[i])).font(.num(19)).foregroundStyle(Ink.ink).lineLimit(1).minimumScaleFactor(0.7)
                        HStack(spacing: 4) {
                            Circle().fill(Ink.jar(j)).frame(width: 8, height: 8)
                            Text(j.label).font(.r(13, .heavy)).foregroundStyle(Ink.ink2)
                            Text("\(kid.split.share(j))%").font(.r(11, .bold)).foregroundStyle(Ink.dim)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .sticker(28)
    }
}

struct JarShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let neckW = r.width * 0.62, neckH = r.height * 0.10
        let nx = r.midX - neckW / 2
        p.addRoundedRect(in: CGRect(x: nx, y: r.minY, width: neckW, height: neckH + 6), cornerSize: CGSize(width: 6, height: 6))
        let body = CGRect(x: r.minX, y: r.minY + neckH, width: r.width, height: r.height - neckH)
        p.addRoundedRect(in: body, cornerSize: CGSize(width: r.width * 0.26, height: r.width * 0.26), style: .continuous)
        return p
    }
}

struct CoinJar: View {
    let fill: Double
    let color: Color
    let seed: UInt64
    @State private var shown: Double = 0
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let lidH: CGFloat = 16
            ZStack(alignment: .top) {
                // Glass
                JarShape().fill(Color.white.opacity(0.7)).padding(.top, lidH - 4)
                // Coins, clipped to the glass
                Coins(level: shown, seed: seed, tint: color)
                    .clipShape(JarShape())
                    .padding(.top, lidH - 4)
                JarShape().stroke(Ink.ink.opacity(0.16), lineWidth: 2).padding(.top, lidH - 4)
                // Shine
                Capsule().fill(.white.opacity(0.75)).frame(width: 6, height: h * 0.42).offset(x: -w * 0.30, y: h * 0.30)
                // Lid
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(color)
                    .frame(width: w * 0.72, height: lidH)
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.white.opacity(0.25)).frame(height: 4).padding(.horizontal, 6), alignment: .top)
                    .shadow(color: color.opacity(0.4), radius: 4, y: 2)
            }
        }
        .onAppear { withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.1)) { shown = fill } }
        .onChange(of: fill) { _, v in withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) { shown = v } }
    }
}

/// Stacks of gold coins up to a fill level (0...1), drawn with Canvas.
struct Coins: View, Animatable {
    var level: Double
    let seed: UInt64
    let tint: Color
    var animatableData: Double { get { level } set { level = newValue } }
    var body: some View {
        Canvas { ctx, size in
            let top = size.height * (1 - level)
            // Tinted wash behind the coins
            ctx.fill(Path(CGRect(x: 0, y: top, width: size.width, height: size.height - top)), with: .color(tint.opacity(0.14)))
            guard level > 0.01 else { return }
            var r = seed
            func rnd() -> Double { r = r &* 6364136223846793005 &+ 1442695040888963407; return Double((r >> 33) % 1000) / 1000 }
            let cw: CGFloat = 26, ch: CGFloat = 9
            var y = size.height - ch - 2
            var row = 0
            while y > top - ch * 0.4 {
                let offset: CGFloat = row % 2 == 0 ? 0 : cw * 0.5
                var x: CGFloat = -cw * 0.5 + offset
                while x < size.width {
                    let jx = CGFloat(rnd() - 0.5) * 6, jy = CGFloat(rnd() - 0.5) * 3
                    let rect = CGRect(x: x + jx, y: y + jy, width: cw, height: ch)
                    let edge = rect.offsetBy(dx: 0, dy: 3)
                    ctx.fill(Path(ellipseIn: edge), with: .color(Color(hex: 0xC98A00)))
                    ctx.fill(Path(ellipseIn: rect), with: .linearGradient(Gradient(colors: [Color(hex: 0xFFE27A), Color(hex: 0xF5B800)]), startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
                    ctx.stroke(Path(ellipseIn: rect.insetBy(dx: 5, dy: 1.8)), with: .color(Color(hex: 0xD89A00).opacity(0.55)), lineWidth: 1)
                    x += cw * 0.92
                }
                y -= ch * 0.72; row += 1
            }
        }
    }
}

struct GoalCard: View {
    @Environment(Store.self) private var store
    let kid: Kid
    var body: some View {
        if kid.goalAmount > 0 {
            let saved = store.balance(kid.id, .save)
            let frac = min(1, saved / kid.goalAmount)
            let perWeek = kid.allowance * Double(kid.split.save) / 100 + weeklyChoreMoney * Double(kid.split.save) / 100
            let left = max(0, kid.goalAmount - saved)
            let weeks = perWeek > 0 ? Int(ceil(left / perWeek)) : nil
            HStack(spacing: 14) {
                Text(kid.goalEmoji).font(.system(size: 34)).frame(width: 60, height: 60)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Ink.jar(.save).opacity(0.12)))
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(kid.goalName).font(.r(17, .heavy)).foregroundStyle(Ink.ink).lineLimit(1)
                        Spacer()
                        Text("\(store.money(saved)) of \(store.money(kid.goalAmount))").font(.r(13, .heavy)).monospacedDigit().foregroundStyle(Ink.ink2)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Ink.line)
                            Capsule().fill(LinearGradient(colors: [Ink.jar(.save), Ink.jar(.save).opacity(0.75)], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(12, g.size.width * frac))
                        }
                    }
                    .frame(height: 12)
                    Text(left == 0 ? "Goal reached! Time to buy it." : weeks.map { "About \($0) more week\($0 == 1 ? "" : "s") of saving" } ?? "\(store.money(left)) to go")
                        .font(.r(12, .bold)).foregroundStyle(left == 0 ? Ink.mint : Ink.dim)
                }
            }
            .padding(16)
            .sticker(24)
        }
    }
    private var weeklyChoreMoney: Double {
        store.chores.filter { $0.kids.contains(kid.id) && $0.money > 0 }.reduce(0) { sum, c in
            let n: Double
            switch c.rep { case .daily: n = 7; case .school: n = 5; case .days: n = Double(c.days.count); case .weekly: n = 1 }
            return sum + c.money * n * 0.8
        }
    }
}

struct Ledger: View {
    @Environment(Store.self) private var store
    let kid: Kid
    var body: some View {
        let rows = Array(store.ledger(kid.id).prefix(40))
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("History").padding(.bottom, 8)
            if rows.isEmpty {
                Text("Money and stars will show up here.").font(.r(14, .semibold)).foregroundStyle(Ink.dim).padding(.vertical, 12)
            }
            ForEach(rows) { e in
                HStack(spacing: 12) {
                    Image(systemName: icon(e)).font(.system(size: 13, weight: .heavy)).foregroundStyle(color(e))
                        .frame(width: 34, height: 34).background(Circle().fill(color(e).opacity(0.12)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.note).font(.r(14, .heavy)).foregroundStyle(Ink.ink).lineLimit(1)
                        Text(Day.nice(e.day) + (e.jar.map { " · \($0.label)" } ?? "")).font(.r(11, .bold)).foregroundStyle(Ink.dim)
                    }
                    Spacer()
                    if e.jar != nil {
                        Text((e.amount >= 0 ? "+" : "") + store.money(e.amount)).font(.r(15, .heavy)).monospacedDigit().foregroundStyle(e.amount >= 0 ? Ink.mint : Ink.ink2)
                    } else {
                        Text((e.points >= 0 ? "+" : "") + "\(e.points) ★").font(.r(15, .heavy)).monospacedDigit().foregroundStyle(e.points >= 0 ? Ink.gold : Ink.ink2)
                    }
                }
                .padding(.vertical, 8)
                if e.id != rows.last?.id { Rectangle().fill(Ink.line).frame(height: 1).padding(.leading, 46) }
            }
        }
        .padding(16)
        .sticker(24)
    }
    private func icon(_ e: LedgerEntry) -> String {
        switch e.kind {
        case .chore: return "checkmark"
        case .allowance: return "calendar"
        case .bonus: return "sparkles"
        case .fine: return "minus"
        case .spent: return "bag.fill"
        case .move: return "arrow.left.arrow.right"
        case .reward: return "gift.fill"
        case .stars: return "star.fill"
        }
    }
    private func color(_ e: LedgerEntry) -> Color {
        switch e.kind {
        case .chore, .allowance: return Ink.mint
        case .bonus, .stars: return Ink.gold
        case .fine: return Ink.red
        case .spent: return Ink.jar(.spend)
        case .move: return Ink.kid(3)
        case .reward: return Ink.jar(.give)
        }
    }
}
