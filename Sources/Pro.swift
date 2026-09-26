import SwiftUI
import StoreKit

/// Chores Pro: one non-consumable. Two kids with every chore, star, jar, approval and the
/// reward shop are free forever. Pro adds more kids, your own rewards and the weekly report.
///
/// Every way to buy sits in the grown-ups area, behind the parent PIN: kids never see a price.
/// Nothing already entered is ever hidden or locked, whatever happens to Pro.
///
/// Anyone whose first download was a build before `firstFreemiumBuild` got the app when it
/// cost money, so they keep everything. AppTransaction's originalAppVersion is that build
/// number. Only trusted in production: sandbox reports made-up values, and App Review must
/// see the real paywall.
@MainActor
@Observable
final class Pro {
    static let productID = "com.mattbusel.chores.pro"
    /// The first build that has Pro in it. Anything earlier was the paid app.
    static let firstFreemiumBuild = 2
    /// How many kids are free.
    static let freeKids = 2

    enum Reason: String, Identifiable { case kids, rewards, report, settings; var id: String { rawValue } }

    private(set) var unlocked: Bool
    private(set) var grandfathered = false
    private(set) var product: Product?
    var busy = false
    var message: String?

    private var updates: Task<Void, Never>?
    private let key = "chores.pro.unlocked"
    private let forced: Bool

    /// `forced` is for screenshots and the review recording, which must not touch StoreKit.
    init(forced: Bool? = nil) {
        self.forced = forced != nil
        if let forced { unlocked = forced; return }
        unlocked = UserDefaults.standard.bool(forKey: key)
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.apply(result) }
        }
        Task { await refresh() }
    }

    var price: String { product?.displayPrice ?? "$4.99" }

    func canAddKid(_ s: Store) -> Bool { unlocked || s.kids.count < Pro.freeKids }

    func refresh() async {
        guard !forced else { return }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        for await result in Transaction.currentEntitlements { await apply(result) }
        if case .verified(let app)? = try? await AppTransaction.shared,
           app.environment == .production, (Int(app.originalAppVersion) ?? Int.max) < Pro.firstFreemiumBuild {
            grandfathered = true
            grant()
        }
    }

    func buy() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        guard let product else {
            message = "The App Store did not answer. Check your connection and try again."
            return
        }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await apply(result)
                if !unlocked { message = "Apple could not confirm the purchase. Try Restore in a minute." }
            case .pending:
                message = "Waiting for approval. Pro unlocks by itself once it is approved."
            case .userCancelled:
                break
            @unknown default:
                message = "Something unexpected happened. You were not charged."
            }
        } catch {
            message = "The purchase did not go through: \(error.localizedDescription)"
        }
    }

    func restore() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do { try await AppStore.sync() } catch {
            if let e = error as? StoreKitError, case .userCancelled = e { return }
            message = "Could not reach the App Store. Check your connection and try again."
            return
        }
        await refresh()
        message = unlocked ? "Pro is unlocked. Welcome back." : "No Pro purchase found on this Apple ID."
    }

    private func apply(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result, t.productID == Pro.productID else { return }
        if t.revocationDate == nil { grant() } else if !grandfathered { revoke() }
        await t.finish()
    }

    private func grant() {
        guard !unlocked else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { unlocked = true }
        UserDefaults.standard.set(true, forKey: key)
    }

    private func revoke() {
        unlocked = false
        UserDefaults.standard.set(false, forKey: key)
    }
}

// MARK: - Paywall

/// A sticker chart for grown-ups: the whole family's faces, a gold star sticker slapped on top.
struct PaywallView: View {
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    let reason: Pro.Reason
    @State private var landed = false

    var body: some View {
        ZStack {
            Backdrop(tint: Ink.sun)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Eyebrow("For grown-ups", color: Ink.tomato)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Ink.ink2)
                                .frame(width: 38, height: 38).background(Circle().fill(Ink.ink.opacity(0.07)))
                        }
                        .buttonStyle(Bouncy())
                        .accessibilityLabel("Close")
                    }
                    family.frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(headline).font(.r(32, .black)).foregroundStyle(Ink.ink).fixedSize(horizontal: false, vertical: true)
                        Text("Two kids with every chore, star, jar and the reward shop stay free for good. Pro is for bigger families and your own rewards.")
                            .font(.r(15, .semibold)).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(spacing: 10) {
                        feature("🧒", Ink.kid(0), "Every kid in the house", "Three, four, six: each with their own chores, stars and jars.")
                        feature("🎁", Ink.kid(2), "Your own rewards", "Add the rewards your kids actually want, at the star price you choose.")
                        feature("📋", Ink.kid(3), "The weekly report", "Share the week's chores, stars and money with the other grown-ups.")
                    }
                    VStack(spacing: 2) {
                        Text(pro.price).font(.num(40)).foregroundStyle(Ink.ink)
                        Text("once · no subscription · Family Sharing").font(.r(13, .heavy)).foregroundStyle(Ink.dim)
                    }
                    .frame(maxWidth: .infinity)
                    if let m = pro.message {
                        Text(m).font(.r(13, .bold)).foregroundStyle(Ink.red).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    }
                    BigButton(title: pro.busy ? "One moment" : "Unlock Pro for \(pro.price)", icon: "star.fill") {
                        Task { await pro.buy() }
                    }
                    .disabled(pro.busy)
                    HStack {
                        SoftButton(title: "Restore purchase", icon: "arrow.clockwise") { Task { await pro.restore() } }
                        Spacer()
                        SoftButton(title: "Not now") { dismiss() }
                    }
                    Text("Every kid, chore, star and coin you have already added stays, Pro or not.")
                        .font(.r(12, .semibold)).foregroundStyle(Ink.dim).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 40)
            }
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.45).delay(0.2)) { landed = true } }
        .onChange(of: pro.unlocked) { _, now in if now { dismiss() } }
    }

    var headline: String {
        switch reason {
        case .kids: return "Room for the whole crew."
        case .rewards: return "Rewards they'll work for."
        case .report: return "The week, in one message."
        case .settings: return "The whole family, one chart."
        }
    }

    /// Five kid faces in a fan, and a big gold star sticker that thumps down on them.
    var family: some View {
        let faces = ["🦄", "🦖", "🐸", "🚀", "🐼"]
        return ZStack {
            HStack(spacing: -14) {
                ForEach(Array(faces.enumerated()), id: \.offset) { i, e in
                    let c = Ink.kid(i)
                    Text(e).font(.system(size: 34)).frame(width: 66, height: 66)
                        .background(Circle().fill(Ink.card))
                        .background(Circle().fill(c.opacity(0.16)).padding(-1))
                        .overlay(Circle().strokeBorder(c, lineWidth: 3.5))
                        .shadow(color: Ink.ink.opacity(0.10), radius: 6, y: 4)
                        .rotationEffect(.degrees(Double(i - 2) * 5))
                        .offset(y: abs(CGFloat(i) - 2) * 8)
                }
            }
            StarSticker(text: "PRO")
                .scaleEffect(landed ? 1 : 1.9)
                .opacity(landed ? 1 : 0)
                .rotationEffect(.degrees(landed ? -12 : 20))
                .offset(x: 92, y: -46)
        }
        .frame(height: 150)
    }

    func feature(_ emoji: String, _ c: Color, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.system(size: 26)).frame(width: 50, height: 50)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(c.opacity(0.14)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.r(16, .heavy)).foregroundStyle(Ink.ink)
                Text(detail).font(.r(12.5, .bold)).foregroundStyle(Ink.dim).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12).sticker(22)
    }
}

/// A shiny gold star sticker with a white die-cut edge.
struct StarSticker: View {
    let text: String
    var size: CGFloat = 92
    var body: some View {
        ZStack {
            Image(systemName: "star.fill").font(.system(size: size)).foregroundStyle(.white)
                .shadow(color: Ink.ink.opacity(0.2), radius: 6, y: 4)
            Image(systemName: "star.fill").font(.system(size: size * 0.84))
                .foregroundStyle(LinearGradient(colors: [Ink.sun, Ink.gold], startPoint: .top, endPoint: .bottom))
            Text(text).font(.r(size * 0.19, .black)).foregroundStyle(Ink.ink).offset(y: size * 0.05)
        }
    }
}

/// In Settings, behind the PIN: what Pro adds, or a thank-you, and Restore.
struct ProField: View {
    @Environment(Pro.self) private var pro
    @Binding var show: Pro.Reason?
    var body: some View {
        Field("Chores Pro") {
            if pro.unlocked {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Ink.mint)
                    Text(pro.grandfathered ? "Unlocked. Thanks for buying early." : "Unlocked. Every kid, your own rewards, the weekly report.")
                        .font(.r(14, .bold)).foregroundStyle(Ink.ink)
                }
            } else {
                Text("Two kids are free. Pro adds more kids, your own rewards and the weekly report, \(pro.price) once.")
                    .font(.r(14, .semibold)).foregroundStyle(Ink.ink2)
                HStack(spacing: 8) {
                    SoftButton(title: "See Pro", icon: "star.fill", tint: Ink.tomato) { show = .settings }
                    SoftButton(title: "Restore purchase", icon: "arrow.clockwise") { Task { await pro.restore() } }
                }
                if let m = pro.message, show == nil { Text(m).font(.r(12, .bold)).foregroundStyle(Ink.red) }
            }
        }
    }
}

extension View {
    /// Presents the paywall from whichever sheet or screen asked for it.
    func paywall(_ item: Binding<Pro.Reason?>, _ pro: Pro) -> some View {
        sheet(item: item) { why in
            PaywallView(reason: why).environment(pro).presentationBackground(Ink.bg).presentationCornerRadius(32)
        }
    }
}
