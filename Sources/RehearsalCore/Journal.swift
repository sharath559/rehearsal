import Foundation

public enum ExecutionFault { case none, reminderFailure, interruptionAfterEventWrite }

private struct JournalData: Codable {
    var version = 1
    var schedule: ScheduleSnapshot
    var proposals: [Proposal] = []
    // Sandbox side effects are separate from their execution receipts to exercise reconciliation.
    var effects: [String: String] = [:]
}

/// Single-process journal. Atomic file replacement is not cross-process locking.
/// All writes target the sandbox; no EventKit access or system calendar modification.
public actor RehearsalJournal {
    private let url: URL?
    private var data: JournalData

    public init(url: URL? = nil, initial: ScheduleSnapshot) throws {
        self.url = url
        if let url = url, FileManager.default.fileExists(atPath: url.path) {
            let loaded = try JSONDecoder().decode(JournalData.self, from: Data(contentsOf: url))
            guard loaded.version == 1 else { throw RehearsalError.unsupportedStore }
            data = loaded
        } else { data = JournalData(schedule: initial) }
    }

    public func snapshot() -> ScheduleSnapshot { data.schedule }
    public func proposals() -> [Proposal] { data.proposals }
    public func effectCount() -> Int { data.effects.count }

    public func stage(_ proposal: Proposal) throws {
        guard proposal.state == .preview, !data.proposals.contains(where: { $0.id == proposal.id })
        else { throw RehearsalError.invalidRequest }
        var next = data
        next.proposals.append(proposal)
        try commit(next)
    }

    public func approve(_ id: UUID) throws {
        let i = try index(id)
        guard data.proposals[i].state == .preview else { throw RehearsalError.notApproved }
        guard data.proposals[i].sourceRevision == data.schedule.revision else {
            try setState(i, .stale); throw RehearsalError.staleProposal
        }
        try setState(i, .approved)
    }

    public func cancel(_ id: UUID) throws {
        let i = try index(id)
        guard [.preview, .approved].contains(data.proposals[i].state) else {
            throw RehearsalError.notApproved
        }
        try setState(i, .cancelled)
    }

    /// Adds an external busy interval and changes the revision; used to demonstrate stale approval.
    public func addConflict(_ interval: BusyInterval) throws {
        guard interval.start < interval.end else { throw RehearsalError.invalidRequest }
        var next = data
        next.schedule = ScheduleSnapshot(busy: data.schedule.busy + [interval])
        try commit(next)
    }

    public func execute(_ id: UUID, fault: ExecutionFault = .none) throws -> Proposal {
        let i = try index(id)
        let proposal = data.proposals[i]
        if proposal.state == .completed { return proposal }
        if proposal.state == .cancelled { throw RehearsalError.cancelled }
        guard [.approved, .partial, .executing].contains(proposal.state) else {
            throw RehearsalError.notApproved
        }
        let eventKey = id.uuidString + ":event"
        let reminderKey = id.uuidString + ":reminder"
        // Once our event exists, completion only adds the approved reminder. Never recreate the event.
        if data.effects[eventKey] == nil && proposal.sourceRevision != data.schedule.revision {
            try setState(i, .stale); throw RehearsalError.staleProposal
        }
        try setState(i, .executing)
        if data.effects[eventKey] == nil {
            var next = data
            next.effects[eventKey] = "sandbox-event-" + id.uuidString
            next.schedule = ScheduleSnapshot(busy: data.schedule.busy + [
                BusyInterval(start: proposal.start, end: proposal.end)
            ])
            try commit(next)
            if fault == .interruptionAfterEventWrite { throw RehearsalError.interrupted }
        }
        var next = data
        next.proposals[i].eventReceipt = data.effects[eventKey]
        try commit(next)
        if fault == .reminderFailure && data.effects[reminderKey] == nil {
            try setState(i, .partial); throw RehearsalError.injectedFailure
        }
        next = data
        if next.effects[reminderKey] == nil {
            next.effects[reminderKey] = "sandbox-reminder-" + id.uuidString
        }
        next.proposals[i].reminderReceipt = next.effects[reminderKey]
        next.proposals[i].state = .completed
        try commit(next)
        return data.proposals[i]
    }

    private func index(_ id: UUID) throws -> Int {
        guard let i = data.proposals.firstIndex(where: { $0.id == id }) else {
            throw RehearsalError.missingProposal
        }
        return i
    }

    private func setState(_ index: Int, _ state: ProposalState) throws {
        var next = data; next.proposals[index].state = state; try commit(next)
    }

    private func commit(_ next: JournalData) throws {
        if let url = url {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let encoded = try JSONEncoder().encode(next)
            // Restrict permissions before any private content is written; rename the sibling atomically.
            let temp = url.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".tmp")
            guard FileManager.default.createFile(atPath: temp.path, contents: nil,
                attributes: [.posixPermissions: 0o600]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            defer { try? FileManager.default.removeItem(at: temp) }
            try encoded.write(to: temp)
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: temp)
            } else { try FileManager.default.moveItem(at: temp, to: url) }
        }
        data = next
    }
}
