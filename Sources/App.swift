import SwiftUI
import Observation

@main
struct ChoresApp: App {
    @State private var store: Store
    @State private var router: Router
    @State private var pro: Pro
    init() {
        let a = ProcessInfo.processInfo.arguments
        let demo = a.contains("-shot") || a.contains("-demoAutoplay")
        if demo { Day.pinned = Demo.now }
        let s = Store(demo: demo)
        _store = State(initialValue: s)
        _router = State(initialValue: Router(store: s))
        // Screenshots and the review recording never touch StoreKit; `-shot paywall` shows the real, locked paywall.
        let shot = a.firstIndex(of: "-shot").flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil }
        _pro = State(initialValue: shot == "paywall" ? Pro(forced: false) : demo ? Pro(forced: true) : Pro())
    }
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).environment(router).environment(pro).preferredColorScheme(.light).tint(Ink.tomato)
                .onAppear { router.applyShotArgs(store); Autopilot.shared.run(store, router) }
        }
    }
}

enum Tab: String, CaseIterable {
    case today = "Today", week = "Week", bank = "Bank", shop = "Shop", grown = "Grown-ups"
    var icon: String {
        switch self {
        case .today: return "sun.max.fill"
        case .week: return "calendar"
        case .bank: return "banknote.fill"
        case .shop: return "gift.fill"
        case .grown: return "person.2.fill"
        }
    }
}

enum Sheet: Identifiable {
    case kids, chores, rewards, settings, ideas, money(UUID), kid(Kid), chore(Chore), pro(Pro.Reason)
    var id: String {
        switch self {
        case .pro(let r): return "pro-\(r.rawValue)"
        case .kids: return "kids"
        case .chores: return "chores"
        case .rewards: return "rewards"
        case .settings: return "settings"
        case .ideas: return "ideas"
        case .money(let k): return "money-\(k)"
        case .kid(let k): return "kid-\(k.id)"
        case .chore(let c): return "chore-\(c.id)"
        }
    }
}

@Observable
final class Router {
    var tab: Tab = .today
    var kid: UUID?
    var grownUp: Bool
    var bursts: [Burst] = []
    var allDone: Kid? = nil
    var sheet: Sheet? = nil
    var weekOffset = 0

    init(store: Store) {
        kid = store.kids.first?.id
        grownUp = store.settings.pin.isEmpty
    }

    func celebrate(at p: CGPoint, color: Color, label: String?, big: Bool = false) {
        let b = Burst(origin: p, colors: [color, Ink.sun, Ink.tomato, Ink.kid(3), Ink.mint, color.opacity(0.7)], big: big, label: label)
        bursts.append(b)
        let id = b.id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.3))
            self.bursts.removeAll { $0.id == id }
        }
    }

    func lock(_ store: Store) { if !store.settings.pin.isEmpty { withAnimation(.snappy) { grownUp = false } } }

    func applyShotArgs(_ s: Store) {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-shot"), i + 1 < a.count else { return }
        func named(_ n: String) -> Kid? { s.kids.first { $0.name == n } }
        grownUp = false
        switch a[i + 1] {
        case "today":
            kid = named("Leo")?.id
            bursts = [Burst(origin: CGPoint(x: 330, y: 452), colors: [Ink.kid(1), Ink.sun, Ink.tomato, Ink.kid(3), Ink.mint], label: "+2 ★", frozen: 0.34, seed: 77)]
        case "kid":
            if let ivy = named("Ivy") { kid = ivy.id; allDone = ivy }
            bursts = [Burst(origin: CGPoint(x: 215, y: 250), colors: [Ink.kid(0), Ink.sun, Ink.tomato, Ink.kid(3), Ink.mint, Ink.kid(2)], big: true, frozen: 0.62, seed: 4242)]
        case "bank": kid = named("Leo")?.id; tab = .bank
        case "shop": kid = named("Maya")?.id; tab = .shop
        case "week": kid = named("Leo")?.id; tab = .week
        case "parent": grownUp = true; tab = .grown
        case "paywall": grownUp = true; tab = .grown; sheet = .pro(.kids)
        default: break
        }
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .bottom) {
            Backdrop(tint: Ink.kid(store.kid(router.kid)?.color ?? 0))
            Group {
                switch router.tab {
                case .today: TodayView()
                case .week: WeekView()
                case .bank: BankView()
                case .shop: ShopView()
                case .grown: GrownUpsView()
                }
            }
            .transition(.opacity)
            TabBar(selection: $router.tab).padding(.bottom, 4)
            if let k = router.allDone {
                AllDoneCard(kid: k, stars: todayStars(k), streak: store.streak(k.id)) { withAnimation(.spring(response: 0.35)) { router.allDone = nil } }
                    .transition(.opacity).zIndex(5)
            }
            ConfettiLayer(bursts: router.bursts).zIndex(10)
        }
        .sheet(item: $router.sheet) { s in sheetView(s).environment(pro).presentationBackground(Ink.bg).presentationCornerRadius(32) }
        .onAppear { if router.kid == nil { router.kid = store.kids.first?.id } }
        .onChange(of: store.kids.map(\.id)) { _, ids in if router.kid == nil || !ids.contains(router.kid!) { router.kid = ids.first } }
    }

    private func todayStars(_ k: Kid) -> Int {
        store.dones.filter { $0.kid == k.id && $0.day == Day.today }.reduce(0) { $0 + $1.points }
    }

    @ViewBuilder
    private func sheetView(_ s: Sheet) -> some View {
        switch s {
        case .kids: KidsList()
        case .chores: ChoresList()
        case .rewards: RewardsList()
        case .settings: SettingsSheet()
        case .pro(let r): PaywallView(reason: r)
        case .ideas: IdeasSheet()
        case .money(let k): MoneySheet(kidID: k)
        case .kid(let k): NavigationStack { KidEditor(kid: k, isNew: !store.kids.contains { $0.id == k.id }) }
        case .chore(let c): NavigationStack { ChoreEditor(chore: c, isNew: !store.chores.contains { $0.id == c.id }) }
        }
    }
}

/// Floating tab bar: a white capsule with a grape pill behind the current tab.
struct TabBar: View {
    @Binding var selection: Tab
    @Namespace private var ns
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button {
                    Haptic.tap()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) { selection = t }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: t.icon).font(.system(size: 17, weight: .heavy))
                        Text(t == .grown ? "Grown-ups" : t.rawValue).font(.r(10, .heavy)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selection == t ? Color.white : Ink.dim)
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background {
                        if selection == t {
                            Capsule().fill(Ink.ink).matchedGeometryEffect(id: "pill", in: ns)
                        }
                    }
                }
                .buttonStyle(Bouncy(scale: 0.9))
            }
        }
        .padding(6)
        .background(Capsule().fill(Ink.card).shadow(color: Ink.ink.opacity(0.18), radius: 20, y: 10))
        .overlay(Capsule().strokeBorder(Ink.line, lineWidth: 1))
        .padding(.horizontal, 14)
    }
}
