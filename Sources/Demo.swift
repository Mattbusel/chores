import Foundation

/// The sample family used for the store screenshots and the review recording.
enum Demo {
    static var now: Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 17, minute: 30)) ?? Date()
    }

    static func fill(_ s: Store) {
        let today = Day.today
        let start = Day.add(today, -28)
        s.settings = Prefs(pin: "1234", approval: true, currency: "$", allowanceDay: 7, reminder: false, remindHour: 16, remindMinute: 0)
        var ivy = Kid(name: "Ivy", age: 5, emoji: "🦄", color: 0, split: Split(spend: 60, save: 30, give: 10), allowance: 2, goalName: "Unicorn plush", goalEmoji: "🧸", goalAmount: 15)
        var leo = Kid(name: "Leo", age: 9, emoji: "🦖", color: 1, split: Split(spend: 50, save: 40, give: 10), allowance: 5, goalName: "LEGO spaceship", goalEmoji: "🚀", goalAmount: 60)
        var maya = Kid(name: "Maya", age: 13, emoji: "🎧", color: 2, split: Split(spend: 60, save: 30, give: 10), allowance: 10, goalName: "New headphones", goalEmoji: "🎧", goalAmount: 120)
        ivy.created = start; leo.created = start; maya.created = start
        s.kids = [ivy, leo, maya]

        func C(_ k: Kid, _ n: String, _ e: String, _ p: Int, _ m: Double = 0, _ r: Repeat = .daily, _ d: [Int] = []) -> Chore {
            Chore(kids: [k.id], name: n, emoji: e, points: p, money: m, rep: r, days: d, from: start)
        }
        s.chores = [
            C(ivy, "Make bed", "🛏️", 2), C(ivy, "Put toys away", "🧸", 2), C(ivy, "Feed the fish", "🐟", 1), C(ivy, "Set the napkins", "🍽️", 1, 0, .school),
            C(leo, "Make bed", "🛏️", 2), C(leo, "Feed the dog", "🐶", 2), C(leo, "Pack school bag", "🎒", 2, 0, .school),
            C(leo, "Take out the trash", "🗑️", 3, 0, .days, [2, 5]), C(leo, "Tidy bedroom", "🧹", 5, 1, .weekly, [7]),
            C(maya, "Walk the dog", "🐶", 4), C(maya, "Empty the dishwasher", "🍽️", 3), C(maya, "Homework done", "📚", 3, 0, .school),
            C(maya, "Do own laundry", "🧺", 5, 2, .weekly, [1]), C(maya, "Cook a family dinner", "🍳", 8, 3, .weekly, [6]),
        ]
        s.rewards = Store.starterRewards

        var rng: UInt64 = 20260924
        func rnd() -> Double { rng = rng &* 6364136223846793005 &+ 1442695040888963407; return Double((rng >> 33) % 10_000) / 10_000 }
        let streak: [UUID: Int] = [ivy.id: 2, leo.id: 5, maya.id: 13]
        let rate: [UUID: Double] = [ivy.id: 0.8, leo.id: 0.88, maya.id: 0.78]

        func tick(_ c: Chore, _ k: Kid, _ day: String, approved: Bool = true, hour: Int = 16) {
            let at = Calendar(identifier: .gregorian).date(byAdding: .minute, value: hour * 60 - 12 * 60 + Int(rnd() * 50), to: Day.date(day)) ?? Day.date(day)
            s.dones.append(Done(chore: c.id, kid: k.id, day: day, at: at, approved: approved, points: c.points, money: c.money))
        }

        // History: 28 days before today. The last N days are complete, to give each kid a streak.
        for k in s.kids {
            for back in stride(from: 28, through: 1, by: -1) {
                let day = Day.add(today, -back)
                let full = back <= (streak[k.id] ?? 0)
                for c in s.chores where c.kids.contains(k.id) && c.rep != .weekly && s.isScheduled(c, day) {
                    if full || rnd() < (rate[k.id] ?? 0.8) { tick(c, k, day) }
                }
            }
            // Weekly chores: done on some day of each past week.
            var ws = Day.weekStart(start)
            while ws < Day.weekStart(today) {
                for c in s.chores where c.kids.contains(k.id) && c.rep == .weekly {
                    if rnd() < 0.85 {
                        let off = max(0, (c.byDay + 5) % 7 - Int(rnd() * 2))
                        let day = Day.add(ws, off)
                        if day >= start { tick(c, k, day, hour: 11) }
                    }
                }
                ws = Day.add(ws, 7)
            }
        }

        // Today: Ivy is finished, Leo and Maya are part way, with a few ticks waiting for a grown-up.
        func named(_ k: Kid, _ n: String) -> Chore { s.chores.first { $0.kids.contains(k.id) && $0.name == n }! }
        for n in ["Make bed", "Put toys away", "Feed the fish", "Set the napkins"] { tick(named(ivy, n), ivy, today, hour: 8) }
        tick(named(leo, "Make bed"), leo, today, hour: 7)
        tick(named(leo, "Feed the dog"), leo, today, hour: 7)
        tick(named(leo, "Pack school bag"), leo, today, approved: false, hour: 16)
        tick(named(maya, "Walk the dog"), maya, today, hour: 7)
        tick(named(maya, "Empty the dishwasher"), maya, today, hour: 16)
        tick(named(maya, "Homework done"), maya, today, approved: false, hour: 17)
        tick(named(maya, "Do own laundry"), maya, Day.add(today, -2), hour: 18)

        // Money from ticks with a cash value.
        for d in s.dones where d.approved && d.money > 0 {
            guard let k = s.kid(d.kid) else { continue }
            let name = s.chore(d.chore)?.name ?? "Chore"
            for (j, v) in s.split(d.money, k.split) { s.entries.append(LedgerEntry(kid: k.id, day: d.day, kind: .chore, jar: j, amount: v, note: name, done: d.id)) }
        }
        // Four Saturdays of allowance.
        var sat = Day.add(today, -((Day.weekday(today) - 7 + 7) % 7))
        var sats: [String] = []
        while sat > start { sats.append(sat); sat = Day.add(sat, -7) }
        for k in s.kids {
            for d in sats {
                for (j, v) in s.split(k.allowance, k.split) { s.entries.append(LedgerEntry(kid: k.id, day: d, kind: .allowance, jar: j, amount: v, note: "Weekly allowance")) }
            }
            if let i = s.kids.firstIndex(where: { $0.id == k.id }) { s.kids[i].allowancePosted = sats.first ?? "" }
        }
        s.entries.append(LedgerEntry(kid: leo.id, day: Day.add(today, -9), kind: .spent, jar: .spend, amount: -6, note: "Pokémon cards"))
        s.entries.append(LedgerEntry(kid: leo.id, day: Day.add(today, -3), kind: .bonus, jar: .save, amount: 10, note: "Birthday money from Grandma"))
        s.entries.append(LedgerEntry(kid: maya.id, day: Day.add(today, -12), kind: .spent, jar: .give, amount: -5, note: "Animal shelter"))
        s.entries.append(LedgerEntry(kid: maya.id, day: Day.add(today, -6), kind: .bonus, jar: .save, amount: 20, note: "Helped clear the garage"))
        s.entries.append(LedgerEntry(kid: maya.id, day: Day.add(today, -4), kind: .spent, jar: .spend, amount: -12.5, note: "Movie with friends"))
        s.entries.append(LedgerEntry(kid: ivy.id, day: Day.add(today, -5), kind: .stars, points: 5, note: "Extra kind to her brother"))

        // Rewards already bought.
        func buy(_ k: Kid, _ name: String, _ back: Int, given: Bool) {
            guard let r = s.rewards.first(where: { $0.name == name }) else { return }
            let day = Day.add(today, -back)
            s.entries.append(LedgerEntry(kid: k.id, day: day, kind: .reward, points: -r.cost, note: r.name))
            s.redemptions.append(Redemption(kid: k.id, name: r.name, emoji: r.emoji, cost: r.cost, day: day, given: given))
        }
        buy(leo, "30 min screen time", 8, given: true)
        buy(leo, "Pick dinner", 2, given: true)
        buy(ivy, "Stay up 30 min", 6, given: true)
        buy(maya, "Choose movie night", 10, given: true)
        buy(maya, "Pick dinner", 1, given: false)
        buy(maya, "30 min screen time", 0, given: false)
    }
}
