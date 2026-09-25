import SwiftUI
import UIKit

struct TodayView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        @Bindable var router = router
        Page {
            header.padding(.horizontal, 18)
            if store.kids.isEmpty {
                Welcome().padding(.horizontal, 18)
            } else {
                KidPicker(selection: $router.kid)
                if let k = store.kid(router.kid) {
                    if router.grownUp && !store.waiting.isEmpty { waitingBanner.padding(.horizontal, 18) }
                    KidHero(kid: k).padding(.horizontal, 18)
                    TileGrid(kid: k).padding(.horizontal, 18)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            ScreenTitle(eyebrow: Day.format(Day.today, "MMMM d"), title: Day.long[Day.weekday(Day.today) - 1])
            Spacer()
            ModePill()
        }
    }

    private var waitingBanner: some View {
        Button {
            withAnimation(.spring(response: 0.4)) { router.tab = .grown }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "hourglass").font(.system(size: 15, weight: .heavy))
                Text("\(store.waiting.count) waiting for your OK").font(.r(15, .heavy))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .heavy))
            }
            .foregroundStyle(Ink.ink).padding(.horizontal, 16).padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Ink.sun))
        }
        .buttonStyle(Bouncy())
    }
}

/// Kids mode / grown-up mode switch. Hidden when no PIN is set.
struct ModePill: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        if !store.settings.pin.isEmpty {
            Button {
                Haptic.tap()
                if router.grownUp { router.lock(store) } else { withAnimation(.spring(response: 0.4)) { router.tab = .grown } }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: router.grownUp ? "lock.open.fill" : "lock.fill").font(.system(size: 12, weight: .heavy))
                    Text(router.grownUp ? "Grown-up" : "Kids mode").font(.r(13, .heavy))
                }
                .foregroundStyle(router.grownUp ? Color.white : Ink.ink)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Capsule().fill(router.grownUp ? Ink.ink : Ink.card).shadow(color: Ink.ink.opacity(0.1), radius: 6, y: 3))
                .overlay(Capsule().strokeBorder(Ink.line, lineWidth: router.grownUp ? 0 : 1))
            }
            .buttonStyle(Bouncy())
            .padding(.top, 6)
        }
    }
}

/// The big coloured card for the selected kid.
struct KidHero: View {
    @Environment(Store.self) private var store
    let kid: Kid
    var body: some View {
        let c = Ink.kid(kid.color)
        let p = store.progress(kid.id, Day.today)
        let frac = p.total == 0 ? 0 : Double(p.done) / Double(p.total)
        let left = p.total - p.done
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(kid.name).font(.r(30, .black)).foregroundStyle(.white)
                Text(p.total == 0 ? "No chores today. Enjoy it!" : left == 0 ? "Everything is done!" : "\(left) to go today")
                    .font(.r(15, .bold)).foregroundStyle(.white.opacity(0.9))
                HStack(spacing: 6) {
                    heroChip("flame.fill", "\(store.streak(kid.id))", "days")
                    heroChip("star.fill", "\(store.points(kid.id))", nil)
                    heroChip("banknote.fill", store.money(store.total(kid.id)), nil)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
            ZStack {
                Ring(value: frac, color: Color.white, width: 9, track: Color.white.opacity(0.25)).frame(width: 92, height: 92)
                VStack(spacing: -2) {
                    Text("\(p.done)").font(.num(32)).foregroundStyle(.white)
                    Text("of \(p.total)").font(.r(12, .heavy)).foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous).fill(LinearGradient(colors: [c, c.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Sprinkles().clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                Text(kid.emoji).font(.system(size: 120)).opacity(0.16).rotationEffect(.degrees(-14)).offset(x: 40, y: 36)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            }
            .shadow(color: c.opacity(0.35), radius: 18, y: 10)
        )
    }
    private func heroChip(_ icon: String, _ v: String, _ unit: String?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11, weight: .heavy))
            Text(unit == nil ? v : "\(v) \(unit!)").font(.r(13, .heavy)).monospacedDigit()
        }
        .foregroundStyle(.white).padding(.horizontal, 9).padding(.vertical, 5)
        .background(Capsule().fill(.white.opacity(0.2)))
    }
}

/// Little stars and dots scattered over the hero card.
struct Sprinkles: View {
    var body: some View {
        Canvas { ctx, size in
            var r: UInt64 = 9
            func rnd() -> Double { r = r &* 6364136223846793005 &+ 1442695040888963407; return Double((r >> 33) % 1000) / 1000 }
            for i in 0..<22 {
                let x = rnd() * size.width, y = rnd() * size.height, s = 3 + rnd() * 5
                let rect = CGRect(x: x, y: y, width: s, height: s)
                ctx.fill(i % 3 == 0 ? Path(roundedRect: rect, cornerRadius: 1) : Path(ellipseIn: rect), with: .color(.white.opacity(0.10 + rnd() * 0.12)))
            }
        }
    }
}

struct TileGrid: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    let kid: Kid
    var body: some View {
        let list = store.list(kid.id, Day.today)
        if list.isEmpty {
            VStack(spacing: 10) {
                Text("🌤️").font(.system(size: 54))
                Text("Nothing on the list today").font(.r(18, .heavy)).foregroundStyle(Ink.ink)
                Text(store.chores.contains { $0.kids.contains(kid.id) } ? "A free day. Chores come back tomorrow." : "A grown-up can add chores in Grown-ups, or pick from ideas by age.")
                    .font(.r(14, .semibold)).foregroundStyle(Ink.ink2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(28).sticker(28)
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(list) { c in ChoreTile(chore: c, kid: kid) }
            }
        }
    }
}

struct ChoreTile: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    let chore: Chore
    let kid: Kid
    @State private var wiggle = false
    @State private var askUndo = false

    var body: some View {
        let d = store.done(chore, kid.id, Day.today)
        let c = Ink.kid(kid.color)
        let isDone = d?.approved == true
        let isWaiting = d != nil && d?.approved == false
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(chore.emoji).font(.system(size: 40))
                    .frame(width: 66, height: 66)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(isDone ? Color.white.opacity(0.22) : isWaiting ? Color.white.opacity(0.6) : c.opacity(0.12)))
                    .rotationEffect(.degrees(wiggle ? -10 : 0))
                Spacer()
                check(isDone: isDone, isWaiting: isWaiting, c: c)
            }
            Spacer(minLength: 10)
            Text(chore.name).font(.r(17, .heavy)).foregroundStyle(isDone ? Color.white : Ink.ink).lineLimit(2).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 5) {
                if isWaiting {
                    Text("Waiting for OK").font(.r(12, .heavy)).foregroundStyle(Ink.ink.opacity(0.7))
                } else {
                    starTag(isDone)
                    if chore.money > 0 { Text("+" + store.money(chore.money)).font(.r(12, .heavy)).foregroundStyle(isDone ? Color.white.opacity(0.9) : Ink.mint) }
                    if chore.rep == .weekly && !isDone { Text("by \(Day.short[chore.byDay - 1])").font(.r(12, .bold)).foregroundStyle(Ink.dim) }
                }
            }
            .padding(.top, 5)
        }
        .padding(14)
        .frame(height: 172)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(isDone ? AnyShapeStyle(LinearGradient(colors: [c, c.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(isWaiting ? Ink.sunSoft : Ink.card))
                .shadow(color: (isDone ? c : Ink.ink).opacity(isDone ? 0.32 : 0.08), radius: isDone ? 12 : 10, y: 6)
        )
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(isWaiting ? Ink.sun : isDone ? Color.clear : Ink.line, style: StrokeStyle(lineWidth: isWaiting ? 2 : 1, dash: isWaiting ? [6, 5] : [])))
        .scaleEffect(wiggle ? 1.05 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture(coordinateSpace: .global) { loc in tap(at: loc, done: d) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(d == nil ? "Marks the chore done" : "Marks the chore not done")
        .confirmationDialog("Undo \(chore.name)?", isPresented: $askUndo, titleVisibility: .visible) {
            Button("Not done yet", role: .destructive) { _ = store.toggle(chore, kid.id, grownUp: router.grownUp); Haptic.tap() }
        }
    }

    private func starTag(_ onColor: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill").font(.system(size: 10, weight: .heavy)).foregroundStyle(onColor ? Color.white : Ink.gold)
            Text("\(chore.points)").font(.r(12, .heavy)).foregroundStyle(onColor ? Color.white : Ink.ink)
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(onColor ? Color.white.opacity(0.22) : Ink.sunSoft))
    }

    @ViewBuilder
    private func check(isDone: Bool, isWaiting: Bool, c: Color) -> some View {
        ZStack {
            if isDone {
                Circle().fill(.white).frame(width: 34, height: 34)
                Image(systemName: "checkmark").font(.system(size: 16, weight: .black)).foregroundStyle(c)
            } else if isWaiting {
                Circle().fill(Ink.sun).frame(width: 34, height: 34)
                Image(systemName: "hourglass").font(.system(size: 14, weight: .black)).foregroundStyle(Ink.ink)
            } else {
                Circle().strokeBorder(c.opacity(0.45), style: StrokeStyle(lineWidth: 2.5, dash: [5, 4])).frame(width: 34, height: 34)
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    private func tap(at loc: CGPoint, done d: Done?) {
        if let d {
            // Kids can take back a tick that is still waiting; approved ticks need a grown-up.
            if d.approved && !router.grownUp { Haptic.warn(); return }
            askUndo = true
            return
        }
        let now = withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { store.toggle(chore, kid.id, grownUp: router.grownUp) }
        guard now else { return }
        Haptic.success()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { wiggle = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { wiggle = false }
        }
        router.celebrate(at: loc, color: Ink.kid(kid.color), label: "+\(chore.points) ★")
        let p = store.progress(kid.id, Day.today)
        if p.total > 0 && p.done == p.total {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(650))
                router.celebrate(at: CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.height * 0.32), color: Ink.kid(kid.color), label: nil, big: true)
                withAnimation(.spring(response: 0.4)) { router.allDone = kid }
            }
        }
    }
}

struct Welcome: View {
    @Environment(Router.self) private var router
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: -12) {
                ForEach(["🦄", "🦖", "🎧"], id: \.self) { e in
                    Text(e).font(.system(size: 40)).frame(width: 74, height: 74).background(Circle().fill(Ink.card)).overlay(Circle().strokeBorder(Ink.line2, lineWidth: 1.5))
                }
            }
            Text("Chores that get done").font(.r(26, .black)).foregroundStyle(Ink.ink)
            Text("Add your kids, pick their chores, and let them tap their way to stars, pocket money and rewards.").font(.r(15, .semibold)).foregroundStyle(Ink.ink2).multilineTextAlignment(.center)
            BigButton(title: "Add your first kid", icon: "plus") {
                router.sheet = .kid(Kid(name: "", age: 8, emoji: "🦄", color: 0))
            }
            .padding(.top, 6)
        }
        .padding(24).sticker(30)
        .padding(.top, 20)
    }
}
