import SwiftUI
import UIKit

// MARK: Shared form pieces

struct Field<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    init(_ label: String, @ViewBuilder content: () -> Content) { self.label = label; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(label)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .sticker(22)
    }
}

struct BigTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var body: some View {
        TextField(placeholder, text: $text)
            .font(.r(20, .heavy)).foregroundStyle(Ink.ink)
            .keyboardType(keyboard)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.ink.opacity(0.05)))
    }
}

struct Stepperish: View {
    @Binding var value: Int
    var range: ClosedRange<Int>
    var suffix: String = ""
    var body: some View {
        HStack(spacing: 14) {
            round("minus") { if value > range.lowerBound { value -= 1 } }
            Text("\(value)\(suffix)").font(.num(26)).foregroundStyle(Ink.ink).frame(minWidth: 70).contentTransition(.numericText())
            round("plus") { if value < range.upperBound { value += 1 } }
        }
    }
    private func round(_ icon: String, _ act: @escaping () -> Void) -> some View {
        Button { Haptic.tap(); withAnimation(.snappy) { act() } } label: {
            Image(systemName: icon).font(.system(size: 16, weight: .black)).foregroundStyle(Ink.ink)
                .frame(width: 44, height: 44).background(Circle().fill(Ink.ink.opacity(0.07)))
        }
        .buttonStyle(Bouncy())
    }
}

struct ChoiceChip: View {
    let text: String
    let on: Bool
    var tint: Color = Ink.ink
    var action: () -> Void
    var body: some View {
        Button { Haptic.tap(); withAnimation(.snappy) { action() } } label: {
            Text(text).font(.r(14, .heavy)).foregroundStyle(on ? Color.white : Ink.ink2)
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(Capsule().fill(on ? tint : Ink.ink.opacity(0.06)))
        }
        .buttonStyle(Bouncy())
    }
}

struct EmojiGrid: View {
    let options: [String]
    @Binding var pick: String
    var tint: Color
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
            ForEach(options, id: \.self) { e in
                Button { Haptic.tap(); withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pick = e } } label: {
                    Text(e).font(.system(size: 24)).frame(width: 38, height: 38)
                        .background(Circle().fill(pick == e ? tint.opacity(0.22) : Color.clear))
                        .overlay(Circle().strokeBorder(pick == e ? tint : Color.clear, lineWidth: 2))
                        .scaleEffect(pick == e ? 1.12 : 1)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SheetTop: View {
    let title: String
    var done: (() -> Void)? = nil
    var doneTitle = "Save"
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Ink.ink2)
                    .frame(width: 38, height: 38).background(Circle().fill(Ink.ink.opacity(0.07)))
            }
            .buttonStyle(Bouncy())
            .accessibilityLabel("Close")
            Spacer()
            Text(title).font(.r(18, .black)).foregroundStyle(Ink.ink)
            Spacer()
            if let done {
                Button(action: done) {
                    Text(doneTitle).font(.r(15, .heavy)).foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 9).background(Capsule().fill(Ink.tomato))
                }
                .buttonStyle(Bouncy())
            } else {
                Color.clear.frame(width: 38, height: 38)
            }
        }
        .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 6)
    }
}

func parseMoney(_ s: String) -> Double {
    let t = s.replacingOccurrences(of: ",", with: ".").filter { "0123456789.".contains($0) }
    return max(0, ((Double(t) ?? 0) * 100).rounded() / 100)
}
func moneyText(_ v: Double) -> String { v == 0 ? "" : String(format: "%.2f", v) }

// MARK: Kids

struct KidsList: View {
    @Environment(Store.self) private var store
    @Environment(Pro.self) private var pro
    @State private var showPro: Pro.Reason? = nil
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SheetTop(title: "Kids")
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(store.kids) { k in
                            NavigationLink(value: k) {
                                HStack(spacing: 14) {
                                    Avatar(kid: k, size: 52)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(k.name).font(.r(18, .heavy)).foregroundStyle(Ink.ink)
                                        Text("Age \(k.age) · \(store.chores.filter { $0.kids.contains(k.id) }.count) chores · \(k.allowance > 0 ? store.money(k.allowance) + " a week" : "no allowance")")
                                            .font(.r(13, .bold)).foregroundStyle(Ink.dim)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .heavy)).foregroundStyle(Ink.dim)
                                }
                                .padding(14).sticker(22)
                            }
                            .buttonStyle(Bouncy(scale: 0.97))
                        }
                        BigButton(title: "Add a kid", icon: pro.canAddKid(store) ? "plus" : "star.fill") {
                            guard pro.canAddKid(store) else { showPro = .kids; return }
                            add = Kid(name: "", age: 8, emoji: Ink.emojis[store.kids.count % Ink.emojis.count], color: store.kids.count) }
                            .padding(.top, 6)
                    }
                    .padding(18)
                }
            }
            .navigationDestination(for: Kid.self) { k in KidEditor(kid: k, isNew: false) }
            .navigationDestination(item: $add) { k in KidEditor(kid: k, isNew: true) }
            .toolbar(.hidden, for: .navigationBar)
            .background(Ink.bg)
        }
        .paywall($showPro, pro)
    }
    @State private var add: Kid? = nil
}

struct KidEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Kid
    @State private var allowance: String
    @State private var goal: String
    @State private var askDelete = false
    let isNew: Bool
    init(kid: Kid, isNew: Bool) {
        _draft = State(initialValue: kid); self.isNew = isNew
        _allowance = State(initialValue: moneyText(kid.allowance)); _goal = State(initialValue: moneyText(kid.goalAmount))
    }
    var body: some View {
        let c = Ink.kid(draft.color)
        VStack(spacing: 0) {
            SheetTop(title: isNew ? "New kid" : draft.name, done: save)
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 6) {
                        Avatar(kid: draft, size: 96)
                        Text(draft.name.isEmpty ? "Name" : draft.name).font(.r(24, .black)).foregroundStyle(draft.name.isEmpty ? Ink.dim : Ink.ink)
                    }
                    .padding(.vertical, 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: draft.emoji)
                    Field("Name") { BigTextField(placeholder: "First name", text: $draft.name) }
                    Field("Age") { Stepperish(value: $draft.age, range: 2...18) }
                    Field("Avatar") { EmojiGrid(options: Ink.emojis, pick: $draft.emoji, tint: c) }
                    Field("Colour") {
                        HStack(spacing: 10) {
                            ForEach(0..<Ink.palette.count, id: \.self) { i in
                                Button { Haptic.tap(); withAnimation(.snappy) { draft.color = i } } label: {
                                    Circle().fill(Ink.kid(i)).frame(width: 32, height: 32)
                                        .overlay(Circle().strokeBorder(.white, lineWidth: draft.color == i ? 3 : 0))
                                        .overlay(Circle().strokeBorder(Ink.kid(i), lineWidth: draft.color == i ? 2 : 0).padding(-3))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Field("Weekly allowance") {
                        HStack {
                            Text(store.settings.currency).font(.r(20, .heavy)).foregroundStyle(Ink.dim)
                            BigTextField(placeholder: "0.00", text: $allowance, keyboard: .decimalPad)
                        }
                        Text("Paid into the jars every \(Day.long[store.settings.allowanceDay - 1]).").font(.r(12, .bold)).foregroundStyle(Ink.dim)
                    }
                    Field("Split into jars (spend / save / give)") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Split.presets, id: \.self) { s in ChoiceChip(text: s.label, on: draft.split == s, tint: c) { draft.split = s } }
                            }
                        }
                    }
                    Field("Saving for") {
                        HStack(spacing: 8) {
                            TextField("🎯", text: $draft.goalEmoji).font(.system(size: 26)).frame(width: 52).multilineTextAlignment(.center)
                                .padding(.vertical, 8).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.ink.opacity(0.05)))
                            BigTextField(placeholder: "LEGO set, a bike…", text: $draft.goalName)
                        }
                        HStack {
                            Text(store.settings.currency).font(.r(20, .heavy)).foregroundStyle(Ink.dim)
                            BigTextField(placeholder: "Goal amount", text: $goal, keyboard: .decimalPad)
                        }
                    }
                    if !isNew {
                        Button("Remove \(draft.name)", role: .destructive) { askDelete = true }.font(.r(15, .heavy)).padding(.top, 8)
                    }
                }
                .padding(18).padding(.bottom, 40)
            }
        }
        .background(Ink.bg)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Remove \(draft.name) and their history?", isPresented: $askDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { store.delete(kid: draft); dismiss() }
        }
    }
    private func save() {
        draft.name = draft.name.trimmingCharacters(in: .whitespaces)
        guard !draft.name.isEmpty else { Haptic.warn(); return }
        draft.allowance = parseMoney(allowance); draft.goalAmount = parseMoney(goal)
        if draft.goalEmoji.isEmpty { draft.goalEmoji = "🎯" }
        store.upsert(draft); Haptic.success(); dismiss()
    }
}

// MARK: Chores

struct ChoresList: View {
    @Environment(Store.self) private var store
    @State private var add: Chore? = nil
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SheetTop(title: "Chores")
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(store.kids) { k in
                            let mine = store.chores.filter { $0.kids.contains(k.id) }
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) { Avatar(kid: k, size: 30); Text(k.name).font(.r(17, .black)).foregroundStyle(Ink.ink) }
                                ForEach(mine) { c in
                                    NavigationLink(value: c) { ChoreRow(chore: c) }.buttonStyle(Bouncy(scale: 0.97))
                                }
                                if mine.isEmpty { Text("No chores yet").font(.r(13, .bold)).foregroundStyle(Ink.dim) }
                            }
                        }
                        BigButton(title: "New chore", icon: "plus") {
                            add = Chore(kids: store.kids.first.map { [$0.id] } ?? [], name: "", emoji: "🧹", points: 2)
                        }
                        .padding(.top, 4)
                        .disabled(store.kids.isEmpty)
                    }
                    .padding(18)
                }
            }
            .navigationDestination(for: Chore.self) { c in ChoreEditor(chore: c, isNew: false) }
            .navigationDestination(item: $add) { c in ChoreEditor(chore: c, isNew: true) }
            .toolbar(.hidden, for: .navigationBar)
            .background(Ink.bg)
        }
    }
}

struct ChoreRow: View {
    @Environment(Store.self) private var store
    let chore: Chore
    var body: some View {
        HStack(spacing: 12) {
            Text(chore.emoji).font(.system(size: 26)).frame(width: 46, height: 46).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.sun.opacity(0.2)))
            VStack(alignment: .leading, spacing: 2) {
                Text(chore.name).font(.r(16, .heavy)).foregroundStyle(Ink.ink)
                Text(chore.when).font(.r(12, .bold)).foregroundStyle(Ink.dim)
            }
            Spacer()
            if chore.money > 0 { Text(store.money(chore.money)).font(.r(13, .heavy)).foregroundStyle(Ink.mint) }
            StarChip(n: chore.points)
        }
        .padding(12).sticker(20)
    }
}

struct ChoreEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Chore
    @State private var money: String
    @State private var askDelete = false
    let isNew: Bool
    init(chore: Chore, isNew: Bool) { _draft = State(initialValue: chore); _money = State(initialValue: moneyText(chore.money)); self.isNew = isNew }
    var body: some View {
        VStack(spacing: 0) {
            SheetTop(title: isNew ? "New chore" : "Edit chore", done: save)
            ScrollView {
                VStack(spacing: 12) {
                    Text(draft.emoji).font(.system(size: 64)).frame(width: 110, height: 110)
                        .background(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(Ink.sun.opacity(0.22)))
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: draft.emoji)
                    Field("What is it?") { BigTextField(placeholder: "Make bed", text: $draft.name) }
                    Field("Picture") { EmojiGrid(options: Ink.choreEmojis, pick: $draft.emoji, tint: Ink.tomato) }
                    Field("Who does it?") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(store.kids) { k in
                                    let on = draft.kids.contains(k.id)
                                    ChoiceChip(text: "\(k.emoji) \(k.name)", on: on, tint: Ink.kid(k.color)) {
                                        if on { draft.kids.removeAll { $0 == k.id } } else { draft.kids.append(k.id) }
                                    }
                                }
                            }
                        }
                    }
                    Field("Stars") { Stepperish(value: $draft.points, range: 1...30, suffix: " ★") }
                    Field("Pays money too (optional)") {
                        HStack {
                            Text(store.settings.currency).font(.r(20, .heavy)).foregroundStyle(Ink.dim)
                            BigTextField(placeholder: "0.00", text: $money, keyboard: .decimalPad)
                        }
                    }
                    Field("How often") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Repeat.allCases) { r in
                                    ChoiceChip(text: r.label, on: draft.rep == r, tint: Ink.tomato) {
                                        draft.rep = r
                                        if r == .days && draft.days.isEmpty { draft.days = [2, 4, 6] }
                                        if r == .weekly { draft.days = [draft.days.first ?? 7] }
                                    }
                                }
                            }
                        }
                        if draft.rep == .days || draft.rep == .weekly {
                            Text(draft.rep == .weekly ? "Done any day, by:" : "On these days:").font(.r(12, .bold)).foregroundStyle(Ink.dim).padding(.top, 4)
                            HStack(spacing: 6) {
                                ForEach(Day.mondayFirst, id: \.self) { wd in
                                    let on = draft.days.contains(wd)
                                    Button {
                                        Haptic.tap()
                                        withAnimation(.snappy) {
                                            if draft.rep == .weekly { draft.days = [wd] }
                                            else if on { draft.days.removeAll { $0 == wd } } else { draft.days.append(wd) }
                                        }
                                    } label: {
                                        Text(Day.letters[wd - 1]).font(.r(15, .heavy)).foregroundStyle(on ? Color.white : Ink.ink2)
                                            .frame(width: 38, height: 38).background(Circle().fill(on ? Ink.tomato : Ink.ink.opacity(0.06)))
                                    }
                                    .buttonStyle(Bouncy())
                                }
                            }
                        }
                    }
                    if !isNew {
                        Button("Delete this chore", role: .destructive) { askDelete = true }.font(.r(15, .heavy)).padding(.top, 8)
                    }
                }
                .padding(18).padding(.bottom, 40)
            }
        }
        .background(Ink.bg)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Delete \(draft.name)?", isPresented: $askDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { store.delete(chore: draft); dismiss() }
        }
    }
    private func save() {
        draft.name = draft.name.trimmingCharacters(in: .whitespaces)
        guard !draft.name.isEmpty, !draft.kids.isEmpty else { Haptic.warn(); return }
        if draft.rep == .days && draft.days.isEmpty { Haptic.warn(); return }
        draft.money = parseMoney(money)
        store.upsert(draft); Haptic.success(); dismiss()
    }
}

// MARK: Rewards

struct RewardsList: View {
    @Environment(Store.self) private var store
    @Environment(Pro.self) private var pro
    @State private var showPro: Pro.Reason? = nil
    @State private var editing: Reward? = nil
    var body: some View {
        VStack(spacing: 0) {
            SheetTop(title: "Rewards")
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(store.rewards.sorted { $0.cost < $1.cost }) { r in
                        Button { editing = r } label: {
                            HStack(spacing: 12) {
                                Text(r.emoji).font(.system(size: 28)).frame(width: 50, height: 50).background(Circle().fill(Ink.kid(2).opacity(0.12)))
                                Text(r.name).font(.r(16, .heavy)).foregroundStyle(Ink.ink)
                                Spacer()
                                StarChip(n: r.cost, big: true)
                            }
                            .padding(12).sticker(20)
                        }
                        .buttonStyle(Bouncy(scale: 0.97))
                    }
                    BigButton(title: "New reward", icon: pro.unlocked ? "plus" : "star.fill") {
                        if pro.unlocked { editing = Reward(name: "", emoji: "🎁", cost: 25) } else { showPro = .rewards }
                    }
                    .padding(.top, 6)
                    if !pro.unlocked {
                        Text("Rename these and change their star prices freely. Adding your own rewards is part of Chores Pro.")
                            .font(.r(12, .bold)).foregroundStyle(Ink.dim).multilineTextAlignment(.center)
                    }
                }
                .padding(18)
            }
        }
        .background(Ink.bg)
        .sheet(item: $editing) { r in RewardEditor(reward: r).presentationDetents([.medium, .large]).presentationBackground(Ink.bg) }
        .paywall($showPro, pro)
    }
}

struct RewardEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var reward: Reward
    var body: some View {
        VStack(spacing: 0) {
            SheetTop(title: "Reward", done: {
                reward.name = reward.name.trimmingCharacters(in: .whitespaces)
                guard !reward.name.isEmpty else { Haptic.warn(); return }
                store.upsert(reward); dismiss()
            })
            ScrollView {
                VStack(spacing: 12) {
                    Field("Reward") {
                        HStack(spacing: 8) {
                            TextField("🎁", text: $reward.emoji).font(.system(size: 26)).frame(width: 52).multilineTextAlignment(.center)
                                .padding(.vertical, 8).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.ink.opacity(0.05)))
                            BigTextField(placeholder: "Pick the movie", text: $reward.name)
                        }
                    }
                    Field("Costs") { Stepperish(value: $reward.cost, range: 1...999, suffix: " ★") }
                    if store.rewards.contains(where: { $0.id == reward.id }) {
                        Button("Delete reward", role: .destructive) { store.delete(reward: reward); dismiss() }.font(.r(15, .heavy))
                    }
                }
                .padding(18)
            }
        }
    }
}

// MARK: Ideas

struct IdeasSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var band = "6-8"
    @State private var kid: UUID? = nil
    @State private var picked: Set<String> = []
    struct Idea {
        let name: String, emoji: String, points: Int, rep: Repeat, days: [Int], money: Double
        init(_ n: String, _ e: String, _ p: Int, _ r: Repeat, _ d: [Int] = [], _ m: Double = 0) { name = n; emoji = e; points = p; rep = r; days = d; money = m }
    }
    static let ideas: [String: [Idea]] = [
        "3-5": [Idea("Make bed", "🛏️", 2, .daily, [], 0), Idea("Put toys away", "🧸", 2, .daily, [], 0), Idea("Feed the pet", "🐟", 1, .daily, [], 0), Idea("Clothes in the hamper", "🧺", 1, .daily, [], 0),
                Idea("Set the napkins", "🍽️", 1, .school, [], 0), Idea("Water the plants", "🪴", 1, .days, [3, 6], 0), Idea("Wipe the table", "🧽", 1, .daily, [], 0), Idea("Brush teeth", "🦷", 1, .daily, [], 0)],
        "6-8": [Idea("Make bed", "🛏️", 2, .daily, [], 0), Idea("Tidy bedroom", "🧹", 3, .days, [3, 6], 0), Idea("Set the table", "🍽️", 2, .daily, [], 0), Idea("Feed the dog", "🐶", 2, .daily, [], 0),
                Idea("Put away laundry", "👕", 3, .weekly, [7], 0), Idea("Pack school bag", "🎒", 2, .school, [], 0), Idea("Brush teeth", "🦷", 1, .daily, [], 0), Idea("Empty small bins", "🗑️", 2, .weekly, [1], 0)],
        "9-12": [Idea("Load the dishwasher", "🧽", 3, .daily, [], 0), Idea("Take out the trash", "🗑️", 3, .days, [2, 5], 0), Idea("Fold laundry", "🧺", 3, .days, [4, 7], 0), Idea("Vacuum a room", "🧹", 4, .weekly, [7], 0),
                 Idea("Clean the bathroom sink", "🧼", 3, .weekly, [7], 0), Idea("Walk the dog", "🐶", 4, .daily, [], 0), Idea("Homework done", "📚", 3, .school, [], 0), Idea("Pack own lunch", "🥪", 2, .school, [], 0)],
        "13+": [Idea("Do own laundry", "🧺", 5, .weekly, [1], 2), Idea("Cook a family dinner", "🍳", 8, .weekly, [6], 3), Idea("Mow the lawn", "🌿", 10, .weekly, [7], 5), Idea("Clean the bathroom", "🛁", 6, .weekly, [7], 2),
                Idea("Wash the dishes", "🍽️", 4, .daily, [], 0), Idea("Vacuum the house", "🧹", 6, .weekly, [7], 2), Idea("Bins to the curb", "♻️", 3, .days, [3], 0), Idea("Homework done", "📚", 3, .school, [], 0)],
    ]
    static func band(_ age: Int) -> String { age <= 5 ? "3-5" : age <= 8 ? "6-8" : age <= 12 ? "9-12" : "13+" }

    var body: some View {
        let list = IdeasSheet.ideas[band] ?? []
        VStack(spacing: 0) {
            SheetTop(title: "Chore ideas")
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if store.kids.isEmpty {
                        Text("Add a kid first, then come back for ideas.").font(.r(15, .bold)).foregroundStyle(Ink.ink2)
                    } else {
                        Field("For") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(store.kids) { k in
                                        ChoiceChip(text: "\(k.emoji) \(k.name)", on: kid == k.id, tint: Ink.kid(k.color)) { kid = k.id; band = IdeasSheet.band(k.age); picked = [] }
                                    }
                                }
                            }
                        }
                        HStack(spacing: 8) {
                            ForEach(["3-5", "6-8", "9-12", "13+"], id: \.self) { b in ChoiceChip(text: "Ages \(b)", on: band == b, tint: Ink.tomato) { band = b; picked = [] } }
                        }
                        VStack(spacing: 8) {
                            ForEach(list, id: \.name) { i in
                                let on = picked.contains(i.name)
                                let exists = store.chores.contains { $0.name == i.name && $0.kids.contains(kid ?? UUID()) }
                                Button {
                                    Haptic.tap()
                                    withAnimation(.snappy) { if on { picked.remove(i.name) } else { picked.insert(i.name) } }
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(i.emoji).font(.system(size: 26)).frame(width: 44, height: 44).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.sun.opacity(0.2)))
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(i.name).font(.r(15, .heavy)).foregroundStyle(Ink.ink)
                                            Text(exists ? "Already on the list" : "\(i.points) stars" + (i.money > 0 ? " · " + store.money(i.money) : "")).font(.r(12, .bold)).foregroundStyle(Ink.dim)
                                        }
                                        Spacer()
                                        Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 24, weight: .bold)).foregroundStyle(on ? Ink.mint : Ink.line2)
                                    }
                                    .padding(12).sticker(20)
                                }
                                .buttonStyle(Bouncy(scale: 0.97))
                                .disabled(exists)
                                .opacity(exists ? 0.5 : 1)
                            }
                        }
                        BigButton(title: picked.isEmpty ? "Tick a few chores" : "Add \(picked.count) chore\(picked.count == 1 ? "" : "s")", icon: "plus", fill: picked.isEmpty ? Ink.dim : Ink.tomato) { add(list) }
                            .disabled(picked.isEmpty)
                    }
                }
                .padding(18).padding(.bottom, 30)
            }
        }
        .background(Ink.bg)
        .onAppear { if kid == nil, let k = store.kids.first { kid = k.id; band = IdeasSheet.band(k.age) } }
    }
    private func add(_ list: [Idea]) {
        guard let kid else { return }
        for i in list where picked.contains(i.name) {
            store.upsert(Chore(kids: [kid], name: i.name, emoji: i.emoji, points: i.points, money: i.money, rep: i.rep, days: i.days))
        }
        Haptic.success(); dismiss()
    }
}

// MARK: Money

struct MoneySheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let kidID: UUID
    enum Mode: String, CaseIterable { case add = "Add", spend = "Spend", move = "Move", take = "Take away", stars = "Stars" }
    @State private var mode: Mode = .add
    @State private var amount = ""
    @State private var jar: Jar? = nil
    @State private var from: Jar = .spend
    @State private var to: Jar = .save
    @State private var note = ""
    @State private var stars = 5
    var body: some View {
        let k = store.kid(kidID)
        VStack(spacing: 0) {
            SheetTop(title: k.map { "\($0.name)'s money" } ?? "Money", done: save, doneTitle: "Done")
            ScrollView {
                VStack(spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) { ForEach(Mode.allCases, id: \.self) { m in ChoiceChip(text: m.rawValue, on: mode == m, tint: Ink.ink) { mode = m; if m != .add && jar == nil { jar = .spend } } } }
                    }
                    if mode == .stars {
                        Field("Bonus stars (use minus to take some back)") { Stepperish(value: $stars, range: -50...50, suffix: " ★") }
                    } else {
                        Field("Amount") {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(store.settings.currency).font(.num(34)).foregroundStyle(Ink.dim)
                                TextField("0.00", text: $amount).font(.num(44)).foregroundStyle(Ink.ink).keyboardType(.decimalPad)
                            }
                        }
                        if mode == .move {
                            Field("From") { jarChips($from) }
                            Field("To") { jarChips($to) }
                        } else {
                            Field(mode == .add ? "Into" : "From") {
                                HStack(spacing: 8) {
                                    if mode == .add, let k { ChoiceChip(text: "Split \(k.split.label)", on: jar == nil, tint: Ink.ink) { jar = nil } }
                                    ForEach(Jar.allCases) { j in ChoiceChip(text: j.label, on: jar == j, tint: Ink.jar(j)) { jar = j } }
                                }
                            }
                        }
                    }
                    if mode != .move {
                        Field("Note") { BigTextField(placeholder: placeholder, text: $note) }
                    }
                    if let k, mode != .stars {
                        HStack(spacing: 8) {
                            ForEach(Jar.allCases) { j in
                                VStack(spacing: 2) {
                                    Text(store.money(store.balance(k.id, j))).font(.num(16)).foregroundStyle(Ink.ink)
                                    Text(j.label).font(.r(11, .bold)).foregroundStyle(Ink.jar(j))
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 10).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Ink.jar(j).opacity(0.1)))
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
        .background(Ink.bg)
    }
    private var placeholder: String {
        switch mode { case .add: return "Birthday money"; case .spend: return "Pokémon cards"; case .take: return "Broken window"; case .stars: return "Extra helpful today"; case .move: return "" }
    }
    private func jarChips(_ b: Binding<Jar>) -> some View {
        HStack(spacing: 8) { ForEach(Jar.allCases) { j in ChoiceChip(text: j.label, on: b.wrappedValue == j, tint: Ink.jar(j)) { b.wrappedValue = j } } }
    }
    private func save() {
        let v = parseMoney(amount)
        let n = note.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .add:
            guard v > 0 else { Haptic.warn(); return }
            store.addMoney(kidID, v, jar: jar, note: n.isEmpty ? "Money added" : n)
        case .spend:
            guard v > 0 else { Haptic.warn(); return }
            store.takeMoney(kidID, v, jar: jar ?? .spend, note: n.isEmpty ? "Spent" : n, kind: .spent)
        case .take:
            guard v > 0 else { Haptic.warn(); return }
            store.takeMoney(kidID, v, jar: jar ?? .spend, note: n.isEmpty ? "Taken away" : n, kind: .fine)
        case .move:
            guard v > 0, from != to else { Haptic.warn(); return }
            store.move(kidID, v, from: from, to: to)
        case .stars:
            guard stars != 0 else { Haptic.warn(); return }
            store.stars(kidID, stars, note: n.isEmpty ? (stars > 0 ? "Bonus stars" : "Stars taken back") : n)
        }
        Haptic.success(); dismiss()
    }
}
