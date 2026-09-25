import SwiftUI

struct WeekView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State private var pdf: URL? = nil
    var start: String { Day.add(Day.weekStart(Day.today), router.weekOffset * 7) }
    var body: some View {
        @Bindable var router = router
        Page {
            HStack(alignment: .top) {
                ScreenTitle(eyebrow: "The week", title: weekTitle)
                Spacer()
                HStack(spacing: 8) {
                    arrow("chevron.left") { router.weekOffset -= 1 }
                    arrow("chevron.right") { router.weekOffset += 1 }.disabled(router.weekOffset >= 0).opacity(router.weekOffset >= 0 ? 0.35 : 1)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 18)
            if store.kids.isEmpty {
                Welcome().padding(.horizontal, 18)
            } else {
                KidPicker(selection: $router.kid)
                if let k = store.kid(router.kid) {
                    WeekStatsCard(kid: k, start: start).padding(.horizontal, 18)
                    WeekGrid(kid: k, start: start).padding(.horizontal, 18)
                    Legend().padding(.horizontal, 18)
                    share.padding(.horizontal, 18)
                }
            }
        }
        .task(id: "\(start)-\(store.kids.count)-\(store.chores.count)") { pdf = nil; pdf = await ChartPDF.make(store, start: start) }
    }

    private var weekTitle: String {
        if router.weekOffset == 0 { return "This week" }
        if router.weekOffset == -1 { return "Last week" }
        return Day.format(start, "d MMM")
    }

    private func arrow(_ icon: String, _ act: @escaping () -> Void) -> some View {
        Button { Haptic.tap(); withAnimation(.spring(response: 0.4)) { act() } } label: {
            Image(systemName: icon).font(.system(size: 15, weight: .heavy)).foregroundStyle(Ink.ink)
                .frame(width: 40, height: 40).background(Circle().fill(Ink.card).shadow(color: Ink.ink.opacity(0.08), radius: 5, y: 3))
                .overlay(Circle().strokeBorder(Ink.line))
        }
        .buttonStyle(Bouncy())
    }

    @ViewBuilder
    private var share: some View {
        VStack(spacing: 10) {
            if let pdf {
                ShareLink(item: pdf) {
                    HStack(spacing: 8) {
                        Image(systemName: "printer.fill").font(.system(size: 15, weight: .heavy))
                        Text("Print fridge charts").font(.r(17, .heavy))
                    }
                    .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Ink.ink))
                }
                .buttonStyle(Bouncy())
            }
            ShareLink(item: store.summaryText(start)) {
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble.fill").font(.system(size: 13, weight: .heavy))
                    Text("Send the week's summary").font(.r(14, .heavy))
                }
                .foregroundStyle(Ink.ink).frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Ink.ink.opacity(0.06)))
            }
            .buttonStyle(Bouncy())
        }
    }
}

struct WeekStatsCard: View {
    @Environment(Store.self) private var store
    let kid: Kid
    let start: String
    var body: some View {
        let w = store.week(kid.id, start)
        let c = Ink.kid(kid.color)
        let pct = w.due == 0 ? 0 : Double(w.done) / Double(w.due)
        HStack(spacing: 0) {
            stat("\(Int((pct * 100).rounded()))%", "done", c)
            divider
            stat("\(w.done)/\(w.due)", "chores", Ink.ink)
            divider
            stat("\(w.stars)", "stars", Ink.gold)
            divider
            stat(store.money(w.money), "earned", Ink.mint)
        }
        .padding(.vertical, 14)
        .sticker(24)
    }
    private var divider: some View { Rectangle().fill(Ink.line).frame(width: 1, height: 34) }
    private func stat(_ v: String, _ l: String, _ col: Color) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.num(20)).foregroundStyle(col).lineLimit(1).minimumScaleFactor(0.6)
            Text(l).font(.r(11, .bold)).foregroundStyle(Ink.dim)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WeekGrid: View {
    @Environment(Store.self) private var store
    let kid: Kid
    let start: String
    var body: some View {
        let days = Day.weekDays(start)
        let rows = store.chores.filter { $0.kids.contains(kid.id) }.sorted { ($0.rep == .weekly ? 1 : 0, $0.name) < ($1.rep == .weekly ? 1 : 0, $1.name) }
        let c = Ink.kid(kid.color)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer().frame(maxWidth: .infinity)
                ForEach(days, id: \.self) { d in
                    let today = d == Day.today
                    VStack(spacing: 1) {
                        Text(Day.letters[Day.weekday(d) - 1]).font(.r(11, .heavy))
                        Text(Day.format(d, "d")).font(.r(13, .heavy)).monospacedDigit()
                    }
                    .foregroundStyle(today ? Color.white : Ink.dim)
                    .frame(width: 32, height: 42)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(today ? c : Color.clear))
                }
            }
            .padding(.bottom, 6)
            ForEach(rows) { ch in
                HStack(spacing: 0) {
                    HStack(spacing: 7) {
                        Text(ch.emoji).font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(ch.name).font(.r(13, .heavy)).foregroundStyle(Ink.ink).lineLimit(1).minimumScaleFactor(0.75)
                            if ch.rep == .weekly { Text("by \(Day.short[ch.byDay - 1])").font(.r(10, .bold)).foregroundStyle(Ink.dim) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(days, id: \.self) { d in
                        CellDot(cell: store.cell(ch, kid.id, d), color: c).frame(width: 32, height: 36)
                    }
                }
                .padding(.vertical, 3)
                if ch.id != rows.last?.id { Rectangle().fill(Ink.line).frame(height: 1) }
            }
            if rows.isEmpty {
                Text("No chores yet").font(.r(14, .bold)).foregroundStyle(Ink.dim).padding(20)
            }
        }
        .padding(14)
        .sticker(26)
    }
}

struct CellDot: View {
    let cell: Cell
    let color: Color
    var body: some View {
        ZStack {
            switch cell {
            case .done:
                Circle().fill(color).frame(width: 24, height: 24)
                Image(systemName: "checkmark").font(.system(size: 11, weight: .black)).foregroundStyle(.white)
            case .waiting:
                Circle().fill(Ink.sun).frame(width: 24, height: 24)
                Image(systemName: "hourglass").font(.system(size: 10, weight: .black)).foregroundStyle(Ink.ink)
            case .missed:
                Circle().fill(Ink.red.opacity(0.10)).frame(width: 24, height: 24)
                Image(systemName: "xmark").font(.system(size: 9, weight: .black)).foregroundStyle(Ink.red.opacity(0.6))
            case .upcoming:
                Circle().strokeBorder(color.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [3, 3])).frame(width: 24, height: 24)
            case .off:
                Circle().fill(Ink.ink.opacity(0.08)).frame(width: 5, height: 5)
            }
        }
    }
}

struct Legend: View {
    var body: some View {
        HStack(spacing: 12) {
            item(.done, "Done"); item(.waiting, "Waiting"); item(.missed, "Missed"); item(.upcoming, "To do")
        }
        .frame(maxWidth: .infinity)
    }
    private func item(_ c: Cell, _ l: String) -> some View {
        HStack(spacing: 4) {
            CellDot(cell: c, color: Ink.kid(1)).scaleEffect(0.7).frame(width: 18, height: 18)
            Text(l).font(.r(11, .bold)).foregroundStyle(Ink.ink2)
        }
    }
}

// MARK: Printable chart

enum ChartPDF {
    @MainActor
    static func make(_ s: Store, start: String) -> URL? {
        guard !s.kids.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory.appending(path: "Chore charts \(start).pdf")
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { return nil }
        for k in s.kids {
            let r = ImageRenderer(content: ChartPage(store: s, kid: k, start: start).frame(width: 612, height: 792).background(Color.white))
            r.render { _, draw in ctx.beginPDFPage(nil); draw(ctx); ctx.endPDFPage() }
        }
        ctx.closePDF()
        return url
    }
}

struct ChartPage: View {
    let store: Store
    let kid: Kid
    let start: String
    var body: some View {
        let c = Ink.kid(kid.color)
        let days = Day.weekDays(start)
        let rows = store.chores.filter { $0.kids.contains(kid.id) }
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                Text(kid.emoji).font(.system(size: 54)).frame(width: 84, height: 84).background(Circle().fill(c.opacity(0.15))).overlay(Circle().strokeBorder(c, lineWidth: 4))
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(kid.name)'s chores").font(.r(34, .black)).foregroundStyle(Ink.ink)
                    Text("Week of \(Day.format(start, "MMMM d")) to \(Day.format(days[6], "MMMM d"))").font(.r(15, .bold)).foregroundStyle(Ink.ink2)
                }
                Spacer()
            }
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("Chore").font(.r(12, .heavy)).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 12)
                    ForEach(days, id: \.self) { d in Text(Day.short[Day.weekday(d) - 1]).font(.r(12, .heavy)).foregroundStyle(.white).frame(width: 52) }
                }
                .frame(height: 34).background(c)
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, ch in
                    HStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Text(ch.emoji).font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(ch.name).font(.r(14, .heavy)).foregroundStyle(Ink.ink)
                                Text("\(ch.points) stars" + (ch.money > 0 ? " · " + store.money(ch.money) : "")).font(.r(10, .bold)).foregroundStyle(Ink.dim)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 12)
                        ForEach(days, id: \.self) { d in
                            let on = ch.rep == .weekly || store.isScheduled(ch, d)
                            RoundedRectangle(cornerRadius: 6).strokeBorder(on ? Ink.ink.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                .background(RoundedRectangle(cornerRadius: 6).fill(on ? Color.clear : Ink.ink.opacity(0.06)))
                                .frame(width: 26, height: 26).frame(width: 52)
                        }
                    }
                    .frame(height: 44)
                    .background(i % 2 == 0 ? Color.white : c.opacity(0.05))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Ink.line2))
            if !kid.goalName.isEmpty {
                HStack(spacing: 10) {
                    Text(kid.goalEmoji).font(.system(size: 26))
                    Text("Saving for: \(kid.goalName) (\(store.money(kid.goalAmount)))").font(.r(15, .heavy)).foregroundStyle(Ink.ink)
                }
            }
            Spacer()
            HStack {
                Text("Tick a box for each chore you finish. Stars add up for rewards!").font(.r(12, .bold)).foregroundStyle(Ink.dim)
                Spacer()
                Text("Chores").font(.r(12, .black)).foregroundStyle(Ink.tomato)
            }
        }
        .padding(40)
    }
}
