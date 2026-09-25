import SwiftUI
import UserNotifications

enum Reminders {
    static let id = "chores-daily"
    static func enable(hour: Int, minute: Int) async -> Bool {
        let c = UNUserNotificationCenter.current()
        guard (try? await c.requestAuthorization(options: [.alert, .sound, .badge])) == true else { return false }
        c.removePendingNotificationRequests(withIdentifiers: [id])
        let content = UNMutableNotificationContent()
        content.title = "Chore time"
        content.body = "Chores before screen time! Tap to see today's list."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
        try? await c.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        return true
    }
    static func disable() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id]) }
}

struct SettingsSheet: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State private var settingPin = false
    @State private var askErase = false
    @State private var time = Date()
    @State private var denied = false
    var body: some View {
        @Bindable var store = store
        NavigationStack {
            VStack(spacing: 0) {
                SheetTop(title: "Settings")
                ScrollView {
                    VStack(spacing: 12) {
                        Field("Parent PIN") {
                            Text(store.settings.pin.isEmpty ? "No PIN yet. Anyone can open Grown-ups and change things." : "Kids mode is on. Grown-ups, the bank and approvals need the PIN.")
                                .font(.r(14, .semibold)).foregroundStyle(Ink.ink2)
                            HStack(spacing: 8) {
                                SoftButton(title: store.settings.pin.isEmpty ? "Set a PIN" : "Change PIN", icon: "lock.fill") { settingPin = true }
                                if !store.settings.pin.isEmpty {
                                    SoftButton(title: "Remove", tint: Ink.red) { store.settings.pin = ""; store.settings.approval = false; router.grownUp = true; store.save() }
                                }
                            }
                        }
                        Field("Grown-up OK") {
                            Toggle(isOn: Binding(get: { store.settings.approval }, set: { store.settings.approval = $0; store.save() })) {
                                Text("Ticked chores wait for a grown-up before stars and money count").font(.r(14, .bold)).foregroundStyle(Ink.ink)
                            }
                            .tint(Ink.mint)
                            .disabled(store.settings.pin.isEmpty)
                            if store.settings.pin.isEmpty { Text("Set a PIN first, so kids can't OK their own chores.").font(.r(12, .bold)).foregroundStyle(Ink.dim) }
                        }
                        Field("Allowance day") {
                            HStack(spacing: 6) {
                                ForEach(Day.mondayFirst, id: \.self) { wd in
                                    let on = store.settings.allowanceDay == wd
                                    Button { Haptic.tap(); store.settings.allowanceDay = wd; store.save() } label: {
                                        Text(Day.letters[wd - 1]).font(.r(15, .heavy)).foregroundStyle(on ? Color.white : Ink.ink2)
                                            .frame(width: 38, height: 38).background(Circle().fill(on ? Ink.mint : Ink.ink.opacity(0.06)))
                                    }
                                    .buttonStyle(Bouncy())
                                }
                            }
                        }
                        Field("Money sign") {
                            HStack(spacing: 8) {
                                ForEach(["$", "£", "€", "A$", "C$", "₹"], id: \.self) { c in
                                    ChoiceChip(text: c, on: store.settings.currency == c, tint: Ink.ink) { store.settings.currency = c; store.save() }
                                }
                            }
                        }
                        Field("Daily reminder") {
                            Toggle(isOn: Binding(get: { store.settings.reminder }, set: { on in toggleReminder(on) })) {
                                Text("\"Chores before screen time!\"").font(.r(14, .bold)).foregroundStyle(Ink.ink)
                            }
                            .tint(Ink.mint)
                            if store.settings.reminder {
                                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                                    .font(.r(15, .bold))
                                    .onChange(of: time) { _, t in
                                        let c = Calendar.current.dateComponents([.hour, .minute], from: t)
                                        store.settings.remindHour = c.hour ?? 16; store.settings.remindMinute = c.minute ?? 0; store.save()
                                        Task { _ = await Reminders.enable(hour: store.settings.remindHour, minute: store.settings.remindMinute) }
                                    }
                            }
                            if denied { Text("Notifications are off for Chores. Turn them on in the Settings app.").font(.r(12, .bold)).foregroundStyle(Ink.red) }
                        }
                        Field("Privacy") {
                            Text("Everything stays on this phone. No accounts, no ads, nothing sent anywhere.").font(.r(14, .semibold)).foregroundStyle(Ink.ink2)
                        }
                        Button("Erase everything", role: .destructive) { askErase = true }.font(.r(15, .heavy)).padding(.top, 8)
                    }
                    .padding(18).padding(.bottom, 40)
                }
            }
            .background(Ink.bg)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $settingPin) { PinSetup() }
        }
        .onAppear {
            time = Calendar.current.date(from: DateComponents(hour: store.settings.remindHour, minute: store.settings.remindMinute)) ?? Date()
        }
        .confirmationDialog("Erase all kids, chores and money?", isPresented: $askErase, titleVisibility: .visible) {
            Button("Erase everything", role: .destructive) { store.eraseAll(); router.grownUp = true; Reminders.disable() }
        }
    }

    private func toggleReminder(_ on: Bool) {
        if !on { store.settings.reminder = false; store.save(); Reminders.disable(); return }
        Task { @MainActor in
            let ok = await Reminders.enable(hour: store.settings.remindHour, minute: store.settings.remindMinute)
            denied = !ok
            store.settings.reminder = ok; store.save()
        }
    }
}

/// Enter a new PIN twice.
struct PinSetup: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var first: String? = nil
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 15, weight: .black)).foregroundStyle(Ink.ink2)
                        .frame(width: 38, height: 38).background(Circle().fill(Ink.ink.opacity(0.07)))
                }
                .buttonStyle(Bouncy())
                Spacer()
            }
            .padding(.horizontal, 18).padding(.top, 18)
            if let f = first {
                PinPad(title: "Once more", subtitle: "Type the same PIN again") { p in
                    if p == f { store.settings.pin = p; store.save(); Haptic.success(); dismiss(); return true }
                    first = nil; return false
                }
                .id("confirm")
            } else {
                PinPad(title: "New PIN", subtitle: "Pick 4 digits the kids don't know") { p in first = p; return true }
                    .id("first")
            }
        }
        .background(Ink.bg)
        .toolbar(.hidden, for: .navigationBar)
    }
}
