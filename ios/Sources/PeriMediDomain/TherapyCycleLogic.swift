import Foundation

public struct TherapyMatch: Equatable, Sendable {
    public var take: Bool
    public var dayInBlock: Int?
    public var phase: Phase
    public var doseLabel: String?
    public var slotIndex: Int?

    public enum Phase: String, Sendable {
        case apply, pause, continuous, before_start
    }

    public init(
        take: Bool,
        dayInBlock: Int? = nil,
        phase: Phase,
        doseLabel: String? = nil,
        slotIndex: Int? = nil
    ) {
        self.take = take
        self.dayInBlock = dayInBlock
        self.phase = phase
        self.doseLabel = doseLabel
        self.slotIndex = slotIndex
    }
}

public enum TherapyCycleLogic {
    public static func normalizeTime(_ t: String) -> String {
        let trimmed = t.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ":")
        guard parts.count >= 2, let h = Int(parts[0]) else { return trimmed }
        let mm = String(parts[1].prefix(2))
        return String(format: "%02d:%@", h, mm)
    }

    public static func getScheduleTimes(_ schedule: Schedule) -> [String] {
        if let times = schedule.times, !times.isEmpty {
            return times.map(normalizeTime).filter { !$0.isEmpty }
        }
        if !schedule.timeOfDay.isEmpty {
            return [normalizeTime(schedule.timeOfDay)]
        }
        return ["08:00"]
    }

    public static func getTherapyCycle(_ schedule: Schedule) -> TherapyCycle? {
        if let cycle = schedule.therapyCycle, cycle.enabled {
            return cycle
        }
        if let wp = schedule.weekPattern, wp.enabled, !wp.slots.isEmpty {
            return TherapyCycle(
                enabled: true,
                mode: .week_slots,
                anchorDate: wp.anchorDate.isEmpty
                    ? (schedule.startDate ?? DateKeys.todayKey())
                    : wp.anchorDate,
                onDays: wp.slots.filter(\.take).count * 7,
                offDays: wp.slots.filter { !$0.take }.count * 7,
                slots: wp.slots
            )
        }
        return nil
    }

    public static func resolveAnchor(schedule: Schedule, cycle: TherapyCycle) -> String {
        if !cycle.anchorDate.isEmpty { return DateKeys.toDateKey(cycle.anchorDate) }
        if let start = schedule.startDate { return DateKeys.toDateKey(start) }
        return DateKeys.todayKey()
    }

    public static func matchTherapyCycle(schedule: Schedule, dateKey: String) -> TherapyMatch? {
        guard let cycle = getTherapyCycle(schedule), cycle.enabled, cycle.mode != .continuous else {
            return nil
        }
        let day = DateKeys.toDateKey(dateKey)
        let anchor = resolveAnchor(schedule: schedule, cycle: cycle)
        let daysSince = DateKeys.differenceInCalendarDays(fromKey: anchor, toKey: day)

        if daysSince < 0 {
            return TherapyMatch(take: false, phase: .before_start)
        }

        if cycle.mode == .week_slots, let slots = cycle.slots, !slots.isEmpty {
            return matchWeekSlots(slots: slots, daysSince: daysSince)
        }

        let onDays = max(0, cycle.onDays)
        let offDays = max(0, cycle.offDays)
        if onDays <= 0 && offDays <= 0 { return nil }
        if offDays <= 0 {
            return TherapyMatch(take: true, dayInBlock: daysSince, phase: .continuous)
        }
        if onDays <= 0 {
            return TherapyMatch(take: false, dayInBlock: daysSince % offDays, phase: .pause)
        }

        let block = onDays + offDays
        let pos = daysSince % block
        let take = pos < onDays
        return TherapyMatch(
            take: take,
            dayInBlock: pos,
            phase: take ? .apply : .pause
        )
    }

    private static func matchWeekSlots(slots: [WeekPatternSlot], daysSince: Int) -> TherapyMatch {
        let weekNumber = daysSince / 7
        let slotIndex = weekNumber % slots.count
        let slot = slots[slotIndex]
        return TherapyMatch(
            take: slot.take,
            phase: slot.take ? .apply : .pause,
            doseLabel: slot.take ? slot.doseLabel : nil,
            slotIndex: slotIndex
        )
    }

    public static func describeTherapyCycle(_ schedule: Schedule, cycle: TherapyCycle? = nil) -> String {
        let c = cycle ?? getTherapyCycle(schedule)
        guard let c, c.enabled, c.mode != .continuous else { return "Continuous" }
        if c.mode == .week_slots, let slots = c.slots, !slots.isEmpty {
            let on = slots.filter(\.take).count
            let off = slots.count - on
            return "Week slots · \(on) on / \(off) off"
        }
        if c.offDays <= 0 { return "Apply \(c.onDays) days (no pause)" }
        return "Apply \(c.onDays) days · pause \(c.offDays) days"
    }

    public static func normalizeTherapyCycle(
        _ partial: TherapyCycle?,
        fallbackAnchor: String
    ) -> TherapyCycle? {
        guard let partial, partial.enabled else { return nil }
        let mode = partial.mode
        if mode == .continuous { return nil }

        if mode == .week_slots {
            let slots = (partial.slots ?? []).map {
                WeekPatternSlot(
                    take: $0.take,
                    doseLabel: $0.doseLabel?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    name: $0.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
            }
            if slots.isEmpty { return nil }
            return TherapyCycle(
                enabled: true,
                mode: .week_slots,
                anchorDate: DateKeys.toDateKey(partial.anchorDate.isEmpty ? fallbackAnchor : partial.anchorDate),
                onDays: slots.filter(\.take).count * 7,
                offDays: slots.filter { !$0.take }.count * 7,
                slots: slots
            )
        }

        let onDays = max(1, partial.onDays)
        let offDays = max(0, partial.offDays)
        if offDays == 0 { return nil }
        return TherapyCycle(
            enabled: true,
            mode: .on_off_days,
            anchorDate: DateKeys.toDateKey(partial.anchorDate.isEmpty ? fallbackAnchor : partial.anchorDate),
            onDays: onDays,
            offDays: offDays
        )
    }

    public static func normalizeTimes(_ times: [String], fallback: String) -> [String] {
        let cleaned = times.map(normalizeTime).filter { !$0.isEmpty }
        let unique = Array(Set(cleaned)).sorted()
        if unique.isEmpty { return [normalizeTime(fallback).isEmpty ? "08:00" : normalizeTime(fallback)] }
        return unique
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
