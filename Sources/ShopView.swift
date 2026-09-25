import SwiftUI
import UIKit

struct ShopView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        @Bindable var router = router
        Page {
            HStack(alignment: .top) {
                ScreenTitle(eyebrow: "Reward shop", title: "Spend your stars")
                Spacer()
                ModePill()
            }
            .padding(.horizontal, 18)
            if store.kids.isEmpty {
                Welcome().padding(.horizontal, 18)
            } else {
                KidPicker(selection: $router.kid)
                if let k = store.kid(router.kid) {
                    StarWallet(kid: k).padding(.horizontal, 18)
                    RewardGrid(kid: k).padding(.horizontal, 18)
                    Owed(kid: k).padding(.horizontal, 18)
                    if router.grownUp {
                        SoftButton(title: "Edit rewards", icon: "slider.horizontal.3") { router.sheet = .rewards }
                            .frame(maxWidth: .infinity).padding(.horizontal, 18)
                    }
                }
            }
        }
    }
}

struct StarWallet: View {
    @Environment(Store.self) private var store
    let kid: Kid
    @State private var spin = false
    var body: some View {
        let c = Ink.kid(kid.color)
        HStack(spacing: 16) {
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    Capsule().fill(Ink.sun.opacity(0.5)).frame(width: 4, height: 16).offset(y: -44).rotationEffect(.degrees(Double(i) * 45 + (spin ? 22 : 0)))
                }
                Image(systemName: "star.fill").font(.system(size: 54, weight: .black)).foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFD84D), Ink.gold], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Ink.gold.opacity(0.45), radius: 8, y: 4)
            }
            .frame(width: 100, height: 100)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(kid.name) has").font(.r(15, .bold)).foregroundStyle(Ink.ink2)
                Text("\(store.points(kid.id)) stars").font(.num(38, .black)).foregroundStyle(Ink.ink).contentTransition(.numericText())
                Text("Earn more by finishing chores").font(.r(12, .bold)).foregroundStyle(c)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous).fill(LinearGradient(colors: [Ink.sunSoft, Color.white], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Ink.gold.opacity(0.18), radius: 14, y: 8)
        )
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Ink.sun.opacity(0.5), lineWidth: 1.5))
        .onAppear { withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { spin = true } }
    }
}

struct RewardGrid: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    let kid: Kid
    @State private var pending: Reward? = nil
    var body: some View {
        let have = store.points(kid.id)
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(store.rewards.sorted { $0.cost < $1.cost }) { r in
                RewardCard(reward: r, have: have, color: Ink.kid(kid.color)) { pending = r }
            }
        }
        .confirmationDialog(pending.map { "Spend \($0.cost) stars on \($0.name)?" } ?? "", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), titleVisibility: .visible) {
            if let r = pending {
                Button("Yes, get it!") { buy(r) }
                Button("Not now", role: .cancel) { pending = nil }
            }
        }
    }
    private func buy(_ r: Reward) {
        guard store.redeem(r, kid.id) else { return }
        Haptic.success()
        router.celebrate(at: CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.height * 0.4), color: Ink.kid(kid.color), label: r.emoji, big: true)
        pending = nil
    }
}

struct RewardCard: View {
    let reward: Reward
    let have: Int
    let color: Color
    var buy: () -> Void
    var body: some View {
        let can = have >= reward.cost
        VStack(spacing: 10) {
            Text(reward.emoji).font(.system(size: 42)).frame(width: 74, height: 74)
                .background(Circle().fill(can ? color.opacity(0.14) : Ink.ink.opacity(0.05)))
                .saturation(can ? 1 : 0.5)
            Text(reward.name).font(.r(15, .heavy)).foregroundStyle(Ink.ink).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                .frame(height: 40)
            if can {
                Button(action: buy) {
                    HStack(spacing: 5) {
                        Image(systemName: "star.fill").font(.system(size: 11, weight: .heavy))
                        Text("\(reward.cost) · Get it").font(.r(14, .heavy))
                    }
                    .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Capsule().fill(Ink.tomato).shadow(color: Ink.tomato.opacity(0.3), radius: 6, y: 3))
                }
                .buttonStyle(Bouncy())
            } else {
                VStack(spacing: 5) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Ink.line)
                            Capsule().fill(Ink.sun).frame(width: max(8, g.size.width * Double(have) / Double(max(1, reward.cost))))
                        }
                    }
                    .frame(height: 8)
                    Text("\(reward.cost - have) more ★ needed").font(.r(12, .heavy)).foregroundStyle(Ink.dim)
                }
                .padding(.vertical, 6)
            }
        }
        .padding(14)
        .sticker(26)
    }
}

struct Owed: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    let kid: Kid
    var body: some View {
        let mine = store.redemptions.filter { $0.kid == kid.id }.sorted { $0.day > $1.day }
        let owed = mine.filter { !$0.given }
        let past = mine.filter { $0.given }.prefix(6)
        if !mine.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                if !owed.isEmpty {
                    Eyebrow("Still owed", color: Ink.tomato)
                    ForEach(owed) { r in
                        HStack(spacing: 12) {
                            Text(r.emoji).font(.system(size: 26))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(r.name).font(.r(15, .heavy)).foregroundStyle(Ink.ink)
                                Text("Bought \(Day.nice(r.day).lowercased()) for \(r.cost) ★").font(.r(12, .bold)).foregroundStyle(Ink.dim)
                            }
                            Spacer()
                            if router.grownUp {
                                SoftButton(title: "Given", icon: "checkmark", tint: Ink.mint) { withAnimation(.spring) { store.give(r) }; Haptic.tap() }
                            } else {
                                Image(systemName: "hourglass").font(.system(size: 15, weight: .heavy)).foregroundStyle(Ink.gold)
                            }
                        }
                    }
                }
                if !past.isEmpty {
                    Eyebrow("Enjoyed").padding(.top, owed.isEmpty ? 0 : 6)
                    ForEach(Array(past)) { r in
                        HStack(spacing: 10) {
                            Text(r.emoji).font(.system(size: 20))
                            Text(r.name).font(.r(14, .bold)).foregroundStyle(Ink.ink2)
                            Spacer()
                            Text(Day.nice(r.day)).font(.r(12, .bold)).foregroundStyle(Ink.dim)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sticker(24)
        }
    }
}
