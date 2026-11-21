import Foundation

public enum RehearsalError: Error, Equatable, LocalizedError {
    case invalidRequest, noSlot, missingProposal, notApproved, staleProposal
    case cancelled, injectedFailure, interrupted, unsupportedStore, expiredProposal

    public var errorDescription: String? {
        switch self {
        case .invalidRequest: return "Use a title, 15–240 minutes, and a valid time window on the selected day."
        case .noSlot: return "No free slot satisfies these constraints. Try a wider window."
        case .missingProposal: return "The proposal could not be found."
        case .notApproved: return "Review and approve this exact proposal before execution."
        case .staleProposal: return "The schedule changed. Generate and review a new proposal."
        case .cancelled: return "This proposal was cancelled."
        case .injectedFailure: return "Simulated reminder failure. The focus block is saved; retry to finish."
        case .interrupted: return "Simulated interruption after a write. Retry to reconcile the result."
        case .unsupportedStore: return "This journal version is unsupported. Keep a backup before upgrading."
        case .expiredProposal: return "The proposed start or reminder time has passed. Generate a fresh preview."
        }
    }
}

/// Minutes are wall-clock positions on the explicitly selected local day.
public struct PlanningRequest: Codable, Equatable, Sendable {
    public let title: String
    public let duration: Int
    public let earliestMinute: Int
    public let latestMinute: Int
    public let reminderLead: Int

    public init(title: String, duration: Int, earliestMinute: Int = 780,
                latestMinute: Int = 1020, reminderLead: Int = 15) throws {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, cleanTitle.count <= 120,
              (15...240).contains(duration), (0..<1440).contains(earliestMinute),
              (1...1440).contains(latestMinute), earliestMinute < latestMinute,
              duration <= latestMinute - earliestMinute, (0...60).contains(reminderLead)
        else { throw RehearsalError.invalidRequest }
        self.title = cleanTitle
        self.duration = duration
        self.earliestMinute = earliestMinute
        self.latestMinute = latestMinute
        self.reminderLead = reminderLead
    }
}

public struct BusyInterval: Codable, Equatable, Sendable {
    public let start: Date
    public let end: Date
    public init(start: Date, end: Date) { self.start = start; self.end = end }
}

public struct ScheduleSnapshot: Codable, Equatable, Sendable {
    public let revision: UUID
    public let busy: [BusyInterval]
    public init(revision: UUID = UUID(), busy: [BusyInterval]) {
        self.revision = revision; self.busy = busy
    }
}

public enum ProposalState: String, Codable, Sendable {
    case preview, approved, executing, partial, completed, cancelled, stale
}

/// Immutable proposal fields bind approval to the exact actions displayed.
public struct Proposal: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let sourceRevision: UUID
    public let title: String
    public let start: Date
    public let end: Date
    public let reminderAt: Date
    public let timeZoneIdentifier: String
    public internal(set) var state: ProposalState
    public internal(set) var eventReceipt: String?
    public internal(set) var reminderReceipt: String?
}

public enum Planner {
    /// Earliest fitting slot; all arithmetic and overlap checks stay outside the LLM.
    public static func propose(_ request: PlanningRequest, day: Date,
                               snapshot: ScheduleSnapshot, calendar: Calendar,
                               now: Date = Date()) throws -> Proposal {
        // Validate again because Codable decoding bypasses the public initializer.
        _ = try PlanningRequest(title: request.title, duration: request.duration,
                                earliestMinute: request.earliestMinute,
                                latestMinute: request.latestMinute, reminderLead: request.reminderLead)
        let midnight = calendar.startOfDay(for: day)
        func wallTime(_ minute: Int) -> Date? {
            if minute == 1440 { return calendar.date(byAdding: .day, value: 1, to: midnight) }
            return calendar.date(bySettingHour: minute / 60, minute: minute % 60,
                                 second: 0, of: midnight, matchingPolicy: .strict,
                                 repeatedTimePolicy: .first, direction: .forward)
        }
        guard let earliest = wallTime(request.earliestMinute),
              let latest = wallTime(request.latestMinute),
              calendar.isDate(earliest, inSameDayAs: day),
              request.latestMinute == 1440 || calendar.isDate(latest, inSameDayAs: day)
        else { throw RehearsalError.invalidRequest }
        var candidate = max(earliest, now)
        let duration = TimeInterval(request.duration * 60)
        for interval in snapshot.busy.sorted(by: { $0.start < $1.start }) {
            guard interval.end > interval.start else { continue }
            if candidate < interval.end && candidate.addingTimeInterval(duration) > interval.start {
                candidate = interval.end
            }
        }
        let end = candidate.addingTimeInterval(duration)
        guard end <= latest else { throw RehearsalError.noSlot }
        let reminder = candidate.addingTimeInterval(-TimeInterval(request.reminderLead * 60))
        guard reminder >= now else { throw RehearsalError.noSlot }
        return Proposal(id: UUID(), sourceRevision: snapshot.revision, title: request.title,
                        start: candidate, end: end, reminderAt: reminder,
                        timeZoneIdentifier: calendar.timeZone.identifier, state: .preview)
    }
}

public enum DemoSchedule {
    public static func snapshot(day: Date, calendar: Calendar) -> ScheduleSnapshot {
        let start = calendar.startOfDay(for: day)
        func at(_ hour: Int) -> Date { calendar.date(bySettingHour: hour, minute: 0, second: 0, of: start)! }
        return ScheduleSnapshot(busy: [BusyInterval(start: at(12), end: at(13)),
                                       BusyInterval(start: at(14), end: at(15))])
    }
}
