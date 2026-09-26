import SwiftUI

struct GrownUpsView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        if router.grownUp { Hub() } else { PinPad(title: "Grown-ups only", subtitle: "Enter your 4-digit PIN") { pin in
            if pin == store.settings.pin { withAnimation(.spring(response: 0.45)) { router.grownUp = true }; return true }
            return false
        } }
    }
}

struct Hub: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        Page {
            HStack(alignment: .top) {
                ScreenTitle(eyebrow: "Grown-ups", title: "Family HQ")
                Spacer()
                if !store.settings.pin.isEmpty {
                    SoftButton(title: "Lock", icon: "lock.fill") { router.lock(store); withAnimation { router.tab = .today } }.padding(.top, 8)
                }
            }
            .padding(.horizontal, 18)
            if !store.waiting.isEmpty { Approvals().padding(.horizontal, 18) }
            if !store.kids.isEmpty { ThisWeek().padding(.horizontal, 18) }
            Manage().padding(.horizontal, 18)
            if store.kids.isEmpty {
                Button { router.sheet = .kid(Kid(name: "", age: 8, emoji: "🦄", color: 0)) } label: {
                    Label("Add your first kid", systemImage: "plus").font(.r(16, .heavy))
                }
                .padding(.horizontal, 18)
            }
        }
    }
}

struct Approvals: View {
    @Environment(Store.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "hourglass").font(.system(size: 14, weight: .heavy)).foregroundStyle(Ink.ink)
                        .frame(width: 30, height: 30).background(Circle().fill(Ink.sun))
                    Text("Waiting for your OK").font(.r(18, .black)).foregroundStyle(Ink.ink)
                }
                Spacer()
                Button {
                    Haptic.success(); withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { store.approveAll() }
                } label: {
                    Text("OK all").font(.r(14, .heavy)).foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 8).background(Capsule().fill(Ink.mint))
                }
                .buttonStyle(Bouncy())
            }
            ForEach(store.waiting) { d in
                if let k = store.kid(d.kid), let c = store.chore(d.chore) {
                    HStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            Text(c.emoji).font(.system(size: 26)).frame(width: 48, height: 48)
                                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Ink.kid(k.color).opacity(0.13)))
                            Text(k.emoji).font(.system(size: 14)).frame(width: 22, height: 22).background(Circle().fill(.white)).overlay(Circle().strokeBorder(Ink.kid(k.color), lineWidth: 1.5))
                                .offset(x: 5, y: 5)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c.name).font(.r(15, .heavy)).foregroundStyle(Ink.ink)
                            Text("\(k.name) · \(Day.nice(d.day)) \(d.at.formatted(date: .omitted, time: .shortened))").font(.r(12, .bold)).foregroundStyle(Ink.dim)
                        }
                        Spacer()
                        Button { Haptic.tap(); withAnimation(.spring) { store.reject(d) } } label: {
                            Image(systemName: "xmark").font(.system(size: 13, weight: .black)).foregroundStyle(Ink.ink2)
                                .frame(width: 38, height: 38).background(Circle().fill(Ink.ink.opacity(0.06)))
                        }
                        .buttonStyle(Bouncy())
                        .accessibilityLabel("Not done")
                        Button { Haptic.success(); withAnimation(.spring) { store.approve(d) } } label: {
                            Image(systemName: "checkmark").font(.system(size: 15, weight: .black)).foregroundStyle(.white)
                                .frame(width: 38, height: 38).background(Circle().fill(Ink.mint))
                        }
                        .buttonStyle(Bouncy())
                        .accessibilityLabel("OK")
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Ink.sunSoft))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Ink.sun, lineWidth: 1.5))
    }
}

struct ThisWeek: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    var body: some View {
        let start = Day.weekStart(Day.today)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This week so far").font(.r(18, .black)).foregroundStyle(Ink.ink)
                Spacer()
                if pro.unlocked {
                    ShareLink(item: store.summaryText(start)) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 14, weight: .heavy)).foregroundStyle(Ink.ink)
                            .frame(width: 34, height: 34).background(Circle().fill(Ink.ink.opacity(0.06)))
                    }
                } else {
                    Button { router.sheet = .pro(.report) } label: {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 14, weight: .heavy)).foregroundStyle(Ink.ink)
                            .frame(width: 34, height: 34).background(Circle().fill(Ink.ink.opacity(0.06)))
                    }
                    .accessibilityLabel("Share the weekly report")
                }
            }
            ForEach(store.kids) { k in
                let w = store.week(k.id, start)
                let frac = w.due == 0 ? 0 : Double(w.done) / Double(w.due)
                HStack(spacing: 12) {
                    Avatar(kid: k, size: 44)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(k.name).font(.r(15, .heavy)).foregroundStyle(Ink.ink)
                            Spacer()
                            Text("\(w.done) of \(w.due)").font(.r(13, .heavy)).monospacedDigit().foregroundStyle(Ink.ink2)
                        }
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Ink.line)
                                Capsule().fill(Ink.kid(k.color)).frame(width: max(8, g.size.width * frac))
                            }
                        }
                        .frame(height: 8)
                        HStack(spacing: 10) {
                            Label("\(w.stars)", systemImage: "star.fill").foregroundStyle(Ink.gold)
                            Label(store.money(w.money), systemImage: "banknote.fill").foregroundStyle(Ink.mint)
                            Label("\(store.streak(k.id))", systemImage: "flame.fill").foregroundStyle(Ink.tomato)
                        }
                        .font(.r(12, .heavy)).labelStyle(TightLabel())
                    }
                }
            }
        }
        .padding(16)
        .sticker(26)
    }
}

struct TightLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) { configuration.icon.font(.system(size: 10, weight: .heavy)); configuration.title.foregroundStyle(Ink.ink2) }
    }
}

struct Manage: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                tile("Kids", "\(store.kids.count)", "face.smiling.inverse", Ink.kid(0)) { router.sheet = .kids }
                tile("Chores", "\(store.chores.count)", "checklist", Ink.kid(1)) { router.sheet = .chores }
            }
            HStack(spacing: 12) {
                tile("Rewards", "\(store.rewards.count)", "gift.fill", Ink.kid(2)) { router.sheet = .rewards }
                tile("Settings", store.settings.pin.isEmpty ? "No PIN" : "PIN on", "gearshape.fill", Ink.kid(3)) { router.sheet = .settings }
            }
            Button { router.sheet = .ideas } label: {
                HStack(spacing: 12) {
                    Text("💡").font(.system(size: 28)).frame(width: 52, height: 52).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Ink.sun.opacity(0.25)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Chore ideas by age").font(.r(16, .heavy)).foregroundStyle(Ink.ink)
                        Text("Fill a kid's list in a few taps").font(.r(12, .bold)).foregroundStyle(Ink.dim)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .heavy)).foregroundStyle(Ink.dim)
                }
                .padding(14).sticker(24)
            }
            .buttonStyle(Bouncy(scale: 0.97))
        }
    }
    private func tile(_ t: String, _ v: String, _ icon: String, _ c: Color, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).font(.system(size: 20, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: 46, height: 46).background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(c))
                VStack(alignment: .leading, spacing: 0) {
                    Text(t).font(.r(17, .heavy)).foregroundStyle(Ink.ink)
                    Text(v).font(.r(13, .bold)).foregroundStyle(Ink.dim)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16).sticker(24)
        }
        .buttonStyle(Bouncy(scale: 0.96))
    }
}

/// Four dots and a round keypad. `check` returns true when the PIN is accepted.
struct PinPad: View {
    let title: String
    let subtitle: String
    var check: (String) -> Bool
    @State private var entry = ""
    @State private var shake: CGFloat = 0
    @Environment(Store.self) private var store
    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 20)
            ZStack {
                Circle().fill(Ink.ink).frame(width: 78, height: 78)
                Image(systemName: "lock.fill").font(.system(size: 30, weight: .heavy)).foregroundStyle(Ink.sun)
            }
            VStack(spacing: 4) {
                Text(title).font(.r(28, .black)).foregroundStyle(Ink.ink)
                Text(subtitle).font(.r(15, .semibold)).foregroundStyle(Ink.ink2)
                if store.demo { Text("Demo family PIN: 1234").font(.r(13, .heavy)).foregroundStyle(Ink.tomato).padding(.top, 4) }
            }
            HStack(spacing: 18) {
                ForEach(0..<4, id: \.self) { i in
                    Circle().fill(i < entry.count ? Ink.ink : Color.clear).frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(Ink.ink.opacity(0.35), lineWidth: 2))
                        .scaleEffect(i < entry.count ? 1.1 : 1)
                        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: entry.count)
                }
            }
            .offset(x: shake)
            .padding(.vertical, 6)
            VStack(spacing: 14) {
                ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                    HStack(spacing: 22) { ForEach(row, id: \.self) { n in key("\(n)") } }
                }
                HStack(spacing: 22) {
                    Color.clear.frame(width: 78, height: 78)
                    key("0")
                    Button { if !entry.isEmpty { entry.removeLast(); Haptic.tap() } } label: {
                        Image(systemName: "delete.left.fill").font(.system(size: 24, weight: .bold)).foregroundStyle(Ink.ink2).frame(width: 78, height: 78)
                    }
                    .buttonStyle(Bouncy())
                    .accessibilityLabel("Delete")
                }
            }
            Spacer(minLength: 120)
        }
        .frame(maxWidth: .infinity)
    }
    private func key(_ d: String) -> some View {
        Button {
            guard entry.count < 4 else { return }
            Haptic.tap(); entry += d
            if entry.count == 4 {
                let e = entry
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(160))
                    if !check(e) {
                        Haptic.warn()
                        withAnimation(.spring(response: 0.08, dampingFraction: 0.2)) { shake = 14 }
                        try? await Task.sleep(for: .milliseconds(90))
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) { shake = 0 }
                    }
                    entry = ""
                }
            }
        } label: {
            Text(d).font(.r(32, .bold)).foregroundStyle(Ink.ink).frame(width: 78, height: 78)
                .background(Circle().fill(Ink.card).shadow(color: Ink.ink.opacity(0.08), radius: 6, y: 3))
                .overlay(Circle().strokeBorder(Ink.line))
        }
        .buttonStyle(Bouncy(scale: 0.88))
    }
}
