import Foundation
import Observation

// MARK: Days

/// Every date in the app is a day key "yyyy-MM-dd" in the phone's calendar. Weeks start on Monday.
enum Day {
    static var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.firstWeekday = 2; c.locale = Locale(identifier: "en_US_POSIX"); return c }()
    /// Pinned "now" for the demo family and the store screenshots.
    static var pinned: Date? = nil
    static var now: Date { pinned ?? Date() }
    static var today: String { key(now) }

    static func key(_ d: Date) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 2026, c.month ?? 1, c.day ?? 1)
    }
    static func date(_ k: String) -> Date {
        let p = k.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return now }
        return cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12)) ?? now
    }
    static func add(_ k: String, _ n: Int) -> String { key(cal.date(byAdding: .day, value: n, to: date(k)) ?? now) }
    /// 1 = Sunday ... 7 = Saturday.
    static func weekday(_ k: String) -> Int { cal.component(.weekday, from: date(k)) }
    static func weekStart(_ k: String) -> String { add(k, -((weekday(k) + 5) % 7)) }
    static func weekDays(_ start: String) -> [String] { (0..<7).map { add(start, $0) } }

    static let letters = ["S", "M", "T", "W", "T", "F", "S"]          // by weekday - 1
    static let short = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    static let long = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    /// Weekday numbers in Monday-first order.
    static let mondayFirst = [2, 3, 4, 5, 6, 7, 1]

    static func format(_ k: String, _ f: String) -> String {
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US"); df.dateFormat = f
        return df.string(from: date(k))
    }
    static func nice(_ k: String) -> String {
        if k == today { return "Today" }
        if k == add(today, -1) { return "Yesterday" }
        return format(k, "EEE d MMM")
    }
}

// MARK: Model

enum Jar: String, Codable, CaseIterable, Identifiable {
    case spend, save, give
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var blurb: String {
        switch self {
        case .spend: return "Treats and fun"
        case .save: return "For the goal"
        case .give: return "To help others"
        }
    }
}

struct Split: Codable, Hashable {
    var spend = 60, save = 30, give = 10
    func share(_ j: Jar) -> Int { j == .spend ? spend : j == .save ? save : give }
    var label: String { "\(spend) / \(save) / \(give)" }
    static let presets: [Split] = [Split(spend: 60, save: 30, give: 10), Split(spend: 50, save: 40, give: 10), Split(spend: 40, save: 40, give: 20), Split(spend: 70, save: 20, give: 10), Split(spend: 100, save: 0, give: 0)]
}

struct Kid: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var age: Int
    var emoji: String
    var color: Int
    var split = Split()
    var allowance: Double = 0
    var goalName = ""
    var goalEmoji = "🎯"
    var goalAmount: Double = 0
    var allowancePosted = ""
    var created = Day.today
}

enum Repeat: String, Codable, CaseIterable, Identifiable {
    case daily, school, days, weekly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .daily: return "Every day"
        case .school: return "School days"
        case .days: return "Pick days"
        case .weekly: return "Once a week"
        }
    }
}

struct Chore: Codable, Identifiable, Hashable {
    var id = UUID()
    var kids: [UUID]
    var name: String
    var emoji: String
    var points: Int
    var money: Double = 0
    var rep: Repeat = .daily
    /// Weekdays (1 = Sunday). For weekly chores the first entry is the "by" day.
    var days: [Int] = []
    var from = Day.today
    var byDay: Int { days.first ?? 7 }
    var when: String {
        switch rep {
        case .daily: return "Every day"
        case .school: return "Mon to Fri"
        case .days: return Day.mondayFirst.filter { days.contains($0) }.map { Day.short[$0 - 1] }.joined(separator: ", ")
        case .weekly: return "Once a week, by \(Day.short[byDay - 1])"
        }
    }
}

struct Done: Codable, Identifiable, Hashable {
    var id = UUID()
    var chore: UUID
    var kid: UUID
    var day: String
    var at: Date
    var approved: Bool
    var points: Int
    var money: Double
}

enum EntryKind: String, Codable { case chore, allowance, bonus, fine, spent, move, reward, stars }

struct LedgerEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var kid: UUID
    var day: String
    var kind: EntryKind
    var jar: Jar? = nil
    var amount: Double = 0
    var points: Int = 0
    var note: String
    var done: UUID? = nil
}

struct Reward: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var emoji: String
    var cost: Int
}

struct Redemption: Codable, Identifiable, Hashable {
    var id = UUID()
    var kid: UUID
    var name: String
    var emoji: String
    var cost: Int
    var day: String
    var given = false
}

struct Prefs: Codable {
    var pin = ""
    var approval = false
    var currency = "$"
    var allowanceDay = 7
    var reminder = false
    var remindHour = 16
    var remindMinute = 0
}

enum Cell { case done, waiting, missed, upcoming, off }

// MARK: Store

@Observable
final class Store {
    var kids: [Kid] = []
    var chores: [Chore] = []
    var dones: [Done] = []
    var entries: [LedgerEntry] = []
    var rewards: [Reward] = []
    var redemptions: [Redemption] = []
    var settings = Prefs()
    let demo: Bool
    private var saveTask: Task<Void, Never>?
    private let url = URL.documentsDirectory.appending(path: "chores.json")
    struct Disk: Codable { var kids: [Kid]; var chores: [Chore]; var dones: [Done]; var entries: [LedgerEntry]; var rewards: [Reward]; var redemptions: [Redemption]; var settings: Prefs }

    init(demo: Bool) {
        self.demo = demo
        if demo { Demo.fill(self); postAllowances(); return }
        if let d = try? Data(contentsOf: url), let disk = try? JSONDecoder().decode(Disk.self, from: d) {
            kids = disk.kids; chores = disk.chores; dones = disk.dones; entries = disk.entries; rewards = disk.rewards; redemptions = disk.redemptions; settings = disk.settings
        } else {
            rewards = Store.starterRewards
        }
        postAllowances()
    }

    static var starterRewards: [Reward] {
        [Reward(name: "30 min screen time", emoji: "🎮", cost: 20), Reward(name: "Pick dinner", emoji: "🍕", cost: 30), Reward(name: "Stay up 30 min", emoji: "🌙", cost: 40),
         Reward(name: "Choose movie night", emoji: "🍿", cost: 50), Reward(name: "Trip to the park", emoji: "🛝", cost: 60), Reward(name: "A new book", emoji: "📚", cost: 80),
         Reward(name: "Friend sleepover", emoji: "🏕️", cost: 150), Reward(name: "Toy under $20", emoji: "🧸", cost: 200)]
    }

    func save() {
        guard !demo else { return }
        saveTask?.cancel()
        let disk = Disk(kids: kids, chores: chores, dones: dones, entries: entries, rewards: rewards, redemptions: redemptions, settings: settings)
        let u = url
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(for: .milliseconds(200)); if Task.isCancelled { return }
            if let d = try? JSONEncoder().encode(disk) { try? d.write(to: u, options: .atomic) }
        }
    }

    func eraseAll() {
        kids = []; chores = []; dones = []; entries = []; redemptions = []; rewards = Store.starterRewards; settings = Prefs(); save()
    }

    // MARK: Lookups
    func kid(_ id: UUID?) -> Kid? { kids.first { $0.id == id } }
    func chore(_ id: UUID) -> Chore? { chores.first { $0.id == id } }
    func money(_ v: Double) -> String {
        let s = String(format: "%.2f", abs(v))
        return (v < 0 ? "-" : "") + settings.currency + s
    }

    // MARK: Schedule
    func isScheduled(_ c: Chore, _ day: String) -> Bool {
        if day < c.from { return false }
        let wd = Day.weekday(day)
        switch c.rep {
        case .daily: return true
        case .school: return (2...6).contains(wd)
        case .days: return c.days.contains(wd)
        case .weekly: return true
        }
    }

    func done(_ c: Chore, _ kid: UUID, _ day: String) -> Done? {
        if c.rep == .weekly {
            let ws = Day.weekStart(day), we = Day.add(ws, 6)
            return dones.first { $0.chore == c.id && $0.kid == kid && $0.day >= ws && $0.day <= we }
        }
        return dones.first { $0.chore == c.id && $0.kid == kid && $0.day == day }
    }

    /// The chores a kid sees on a day. Weekly chores show every day until they are done, then only on the day they were done.
    func list(_ kid: UUID, _ day: String) -> [Chore] {
        chores.filter { c in
            guard c.kids.contains(kid), isScheduled(c, day) else { return false }
            if c.rep == .weekly, let d = done(c, kid, day), d.day != day { return false }
            return true
        }.sorted { a, b in
            if (a.rep == .weekly) != (b.rep == .weekly) { return b.rep == .weekly }
            return a.points < b.points
        }
    }

    func progress(_ kid: UUID, _ day: String) -> (done: Int, total: Int) {
        let l = list(kid, day)
        return (l.filter { done($0, kid, day) != nil }.count, l.count)
    }

    /// Days in a row where every daily chore got done. Today only counts once it is finished.
    func streak(_ kid: UUID) -> Int {
        var n = 0
        var d = Day.today
        let created = self.kid(kid)?.created ?? d
        for i in 0..<120 {
            let due = list(kid, d).filter { $0.rep != .weekly }
            if !due.isEmpty {
                let all = due.allSatisfy { done($0, kid, d) != nil }
                if all { n += 1 } else if i > 0 { break }
            }
            d = Day.add(d, -1)
            if d < created && i > 0 { break }
        }
        return n
    }

    func cell(_ c: Chore, _ kid: UUID, _ day: String) -> Cell {
        if c.rep == .weekly {
            if let d = done(c, kid, day) {
                if d.day == day { return d.approved ? .done : .waiting }
                return .off
            }
            if Day.weekday(day) != c.byDay || day < c.from { return .off }
            return day < Day.today ? .missed : .upcoming
        }
        guard isScheduled(c, day) else { return .off }
        if let d = done(c, kid, day) { return d.approved ? .done : .waiting }
        return day < Day.today ? .missed : .upcoming
    }

    // MARK: Balances
    func points(_ kid: UUID) -> Int {
        dones.filter { $0.kid == kid && $0.approved }.reduce(0) { $0 + $1.points } + entries.filter { $0.kid == kid }.reduce(0) { $0 + $1.points }
    }
    func balance(_ kid: UUID, _ jar: Jar) -> Double {
        let v = entries.filter { $0.kid == kid && $0.jar == jar }.reduce(0) { $0 + $1.amount }
        return (v * 100).rounded() / 100
    }
    func total(_ kid: UUID) -> Double { Jar.allCases.reduce(0) { $0 + balance(kid, $1) } }
    func ledger(_ kid: UUID) -> [LedgerEntry] { entries.filter { $0.kid == kid }.sorted { $0.day > $1.day } }
    var waiting: [Done] { dones.filter { !$0.approved }.sorted { $0.at < $1.at } }

    func split(_ amount: Double, _ s: Split) -> [(Jar, Double)] {
        let sp = (amount * Double(s.spend)).rounded() / 100
        let sv = (amount * Double(s.save)).rounded() / 100
        let gv = ((amount - sp - sv) * 100).rounded() / 100
        return [(.spend, sp), (.save, sv), (.give, gv)].filter { $0.1 != 0 }
    }

    // MARK: Actions
    /// Tick or untick. Returns true when the chore is now done.
    @discardableResult
    func toggle(_ c: Chore, _ kid: UUID, grownUp: Bool) -> Bool {
        let day = Day.today
        if let d = done(c, kid, day) {
            dones.removeAll { $0.id == d.id }
            entries.removeAll { $0.done == d.id }
            save(); return false
        }
        let d = Done(chore: c.id, kid: kid, day: day, at: Day.now, approved: !settings.approval, points: c.points, money: c.money)
        dones.append(d)
        if d.approved { pay(d) }
        save(); return true
    }

    private func pay(_ d: Done) {
        guard d.money > 0, let k = kid(d.kid) else { return }
        let name = chore(d.chore)?.name ?? "Chore"
        for (j, v) in split(d.money, k.split) { entries.append(LedgerEntry(kid: d.kid, day: d.day, kind: .chore, jar: j, amount: v, note: name, done: d.id)) }
    }

    func approve(_ d: Done) {
        guard let i = dones.firstIndex(where: { $0.id == d.id }), !dones[i].approved else { return }
        dones[i].approved = true; pay(dones[i]); save()
    }
    func approveAll() { for d in waiting { approve(d) } }
    func reject(_ d: Done) { dones.removeAll { $0.id == d.id }; entries.removeAll { $0.done == d.id }; save() }

    func postAllowances() {
        let today = Day.today
        let back = (Day.weekday(today) - settings.allowanceDay + 7) % 7
        let last = Day.add(today, -back)
        var changed = false
        for i in kids.indices where kids[i].allowance > 0 && kids[i].allowancePosted < last && last >= kids[i].created {
            for (j, v) in split(kids[i].allowance, kids[i].split) { entries.append(LedgerEntry(kid: kids[i].id, day: last, kind: .allowance, jar: j, amount: v, note: "Weekly allowance")) }
            kids[i].allowancePosted = last; changed = true
        }
        if changed { save() }
    }

    func addMoney(_ kid: UUID, _ amount: Double, jar: Jar?, note: String, kind: EntryKind = .bonus) {
        guard amount > 0, let k = self.kid(kid) else { return }
        if let jar { entries.append(LedgerEntry(kid: kid, day: Day.today, kind: kind, jar: jar, amount: amount, note: note)) }
        else { for (j, v) in split(amount, k.split) { entries.append(LedgerEntry(kid: kid, day: Day.today, kind: kind, jar: j, amount: v, note: note)) } }
        save()
    }
    func takeMoney(_ kid: UUID, _ amount: Double, jar: Jar, note: String, kind: EntryKind) {
        guard amount > 0 else { return }
        entries.append(LedgerEntry(kid: kid, day: Day.today, kind: kind, jar: jar, amount: -amount, note: note)); save()
    }
    func move(_ kid: UUID, _ amount: Double, from: Jar, to: Jar) {
        guard amount > 0, from != to else { return }
        entries.append(LedgerEntry(kid: kid, day: Day.today, kind: .move, jar: from, amount: -amount, note: "Moved to \(to.label)"))
        entries.append(LedgerEntry(kid: kid, day: Day.today, kind: .move, jar: to, amount: amount, note: "Moved from \(from.label)"))
        save()
    }
    func stars(_ kid: UUID, _ n: Int, note: String) {
        guard n != 0 else { return }
        entries.append(LedgerEntry(kid: kid, day: Day.today, kind: .stars, points: n, note: note)); save()
    }

    @discardableResult
    func redeem(_ r: Reward, _ kid: UUID) -> Bool {
        guard points(kid) >= r.cost else { return false }
        entries.append(LedgerEntry(kid: kid, day: Day.today, kind: .reward, points: -r.cost, note: r.name))
        redemptions.append(Redemption(kid: kid, name: r.name, emoji: r.emoji, cost: r.cost, day: Day.today))
        save(); return true
    }
    func give(_ r: Redemption) { if let i = redemptions.firstIndex(where: { $0.id == r.id }) { redemptions[i].given = true; save() } }

    // MARK: Editing
    func upsert(_ k: Kid) { if let i = kids.firstIndex(where: { $0.id == k.id }) { kids[i] = k } else { kids.append(k) }; postAllowances(); save() }
    func upsert(_ c: Chore) { if let i = chores.firstIndex(where: { $0.id == c.id }) { chores[i] = c } else { chores.append(c) }; save() }
    func upsert(_ r: Reward) { if let i = rewards.firstIndex(where: { $0.id == r.id }) { rewards[i] = r } else { rewards.append(r) }; save() }
    func delete(kid: Kid) {
        kids.removeAll { $0.id == kid.id }
        for i in chores.indices { chores[i].kids.removeAll { $0 == kid.id } }
        chores.removeAll { $0.kids.isEmpty }
        dones.removeAll { $0.kid == kid.id }; entries.removeAll { $0.kid == kid.id }; redemptions.removeAll { $0.kid == kid.id }
        save()
    }
    func delete(chore: Chore) { chores.removeAll { $0.id == chore.id }; save() }
    func delete(reward: Reward) { rewards.removeAll { $0.id == reward.id }; save() }

    // MARK: Week summary
    struct WeekStats { var done = 0, due = 0, stars = 0; var money: Double = 0 }
    func week(_ kid: UUID, _ start: String) -> WeekStats {
        var s = WeekStats()
        let days = Day.weekDays(start)
        for c in chores where c.kids.contains(kid) {
            if c.rep == .weekly {
                if days.contains(where: { $0 >= c.from }) { s.due += 1 }
                if done(c, kid, start) != nil { s.done += 1 }
            } else {
                for d in days where isScheduled(c, d) { s.due += 1; if done(c, kid, d) != nil { s.done += 1 } }
            }
        }
        let inWeek = dones.filter { $0.kid == kid && $0.day >= start && $0.day <= days[6] && $0.approved }
        s.stars = inWeek.reduce(0) { $0 + $1.points }
        s.money = inWeek.reduce(0) { $0 + $1.money }
        return s
    }

    func summaryText(_ start: String) -> String {
        var out = "Chores, week of \(Day.format(start, "d MMMM"))\n"
        for k in kids {
            let w = week(k.id, start)
            out += "\n\(k.emoji) \(k.name): \(w.done) of \(w.due) chores, \(w.stars) stars, \(money(w.money)) earned. Streak \(streak(k.id)) days. Bank \(money(total(k.id)))."
        }
        return out
    }
}
