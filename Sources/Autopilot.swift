import SwiftUI

/// Drives the real screens for the App Review recording (-demoAutoplay).
@Observable
final class Autopilot {
    static let shared = Autopilot()
    static var on: Bool { ProcessInfo.processInfo.arguments.contains("-demoAutoplay") }
    private var running = false
    @MainActor private func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
    @MainActor
    func run(_ store: Store, _ router: Router) {
        guard Autopilot.on, !running else { return }
        running = true
        Task { @MainActor in
            await wait(3)
            guard let leo = store.kids.first(where: { $0.name == "Leo" }), let maya = store.kids.first(where: { $0.name == "Maya" }) else { return }
            withAnimation(.spring(response: 0.4)) { router.kid = leo.id }; await wait(2.5)
            // Leo ticks two chores, the second finishes his day.
            for c in store.list(leo.id, Day.today) where store.done(c, leo.id, Day.today) == nil {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { _ = store.toggle(c, leo.id, grownUp: false) }
                Haptic.success()
                router.celebrate(at: CGPoint(x: 215, y: 560), color: Ink.kid(leo.color), label: "+\(c.points) ★")
                await wait(2)
            }
            // Grown-up unlocks and approves.
            withAnimation(.spring(response: 0.4)) { router.grownUp = true; router.tab = .grown }; await wait(3)
            withAnimation(.spring(response: 0.45)) { store.approveAll() }; await wait(3)
            withAnimation(.spring(response: 0.4)) { router.tab = .today }; await wait(1)
            router.celebrate(at: CGPoint(x: 215, y: 300), color: Ink.kid(leo.color), label: nil, big: true)
            withAnimation(.spring(response: 0.4)) { router.allDone = leo }; await wait(4)
            withAnimation { router.allDone = nil }; await wait(1)
            withAnimation(.spring(response: 0.4)) { router.tab = .week }; await wait(4)
            withAnimation(.spring(response: 0.4)) { router.tab = .bank }; await wait(4)
            withAnimation(.spring(response: 0.4)) { router.kid = maya.id; router.tab = .shop }; await wait(4)
            if let r = store.rewards.sorted(by: { $0.cost < $1.cost }).first(where: { store.points(maya.id) >= $0.cost }) {
                _ = store.redeem(r, maya.id)
                router.celebrate(at: CGPoint(x: 215, y: 380), color: Ink.kid(maya.color), label: r.emoji, big: true)
                await wait(3.5)
            }
            withAnimation(.spring(response: 0.4)) { router.tab = .grown }; await wait(2)
            router.sheet = .chores; await wait(3.5)
            router.sheet = nil; await wait(1.2)
            router.sheet = .ideas; await wait(3.5)
            router.sheet = nil; await wait(1.5)
            try? Data("ok".utf8).write(to: URL.documentsDirectory.appending(path: "demo_done"))
        }
    }
}
