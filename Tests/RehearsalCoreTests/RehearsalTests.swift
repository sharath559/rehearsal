import XCTest
@testable import RehearsalCore

final class RehearsalTests: XCTestCase {
    var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: "America/New_York")!
        return result
    }
    var day: Date { calendar.date(from: DateComponents(year: 2030, month: 6, day: 10))! }
    func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }
    func proposal(_ snapshot: ScheduleSnapshot? = nil) throws -> Proposal {
        try Planner.propose(PlanningRequest(title: "Prepare", duration: 90), day: day,
            snapshot: snapshot ?? DemoSchedule.snapshot(day: day, calendar: calendar), calendar: calendar, now: day)
    }
    func setup() async throws -> (RehearsalJournal, Proposal) {
        let journal = try RehearsalJournal(initial: DemoSchedule.snapshot(day: day, calendar: calendar))
        let p = try proposal(await journal.snapshot())
        try await journal.stage(p)
        return (journal, p)
    }

    func testEarliestSlotAvoidsLunchAndAppointment() throws {
        let p = try proposal()
        XCTAssertEqual(p.start, at(15)); XCTAssertEqual(p.end, at(16, 30))
        XCTAssertEqual(p.reminderAt, at(14, 45))
    }
    func testAdjacentIntervalsDoNotOverlap() throws {
        let request = try PlanningRequest(title: "Work", duration: 60)
        let p = try Planner.propose(request, day: day,
            snapshot: DemoSchedule.snapshot(day: day, calendar: calendar), calendar: calendar, now: day)
        XCTAssertEqual(p.start, at(13)); XCTAssertEqual(p.end, at(14))
    }
    func testOverlappingUnsortedBusyIntervals() throws {
        let snapshot = ScheduleSnapshot(busy: [BusyInterval(start: at(14), end: at(16)),
            BusyInterval(start: at(13), end: at(15))])
        XCTAssertThrowsError(try proposal(snapshot)) { XCTAssertEqual($0 as? RehearsalError, .noSlot) }
    }
    func testInvalidConstraintsRejected() {
        for duration in [-1, 0, 14, 241] {
            XCTAssertThrowsError(try PlanningRequest(title: "Work", duration: duration))
        }
        XCTAssertThrowsError(try PlanningRequest(title: "  ", duration: 30))
        XCTAssertThrowsError(try PlanningRequest(title: "Work", duration: 30, earliestMinute: 1000, latestMinute: 800))
        XCTAssertThrowsError(try PlanningRequest(title: "Work", duration: 30, reminderLead: -1))
    }
    func testDecodedConstraintsAreRevalidated() throws {
        let raw = Data(#"{"title":"Work","duration":-60,"earliestMinute":780,"latestMinute":1020,"reminderLead":15}"#.utf8)
        let request = try JSONDecoder().decode(PlanningRequest.self, from: raw)
        XCTAssertThrowsError(try Planner.propose(request, day: day, snapshot: ScheduleSnapshot(busy: []), calendar: calendar, now: day))
    }
    func testNoPastReminder() throws {
        let request = try PlanningRequest(title: "Work", duration: 30)
        let p = try Planner.propose(request, day: day, snapshot: ScheduleSnapshot(busy: []), calendar: calendar, now: at(13))
        XCTAssertEqual(p.start, at(13, 16))
        XCTAssertEqual(p.reminderAt, at(13, 1))
    }
    func testZeroLeadStillLeavesTimeToReview() throws {
        let request = try PlanningRequest(title: "Work", duration: 30, reminderLead: 0)
        let p = try Planner.propose(request, day: day, snapshot: ScheduleSnapshot(busy: []), calendar: calendar, now: at(13))
        XCTAssertEqual(p.start, at(13, 1))
        XCTAssertEqual(p.reminderAt, p.start)
    }
    func testReminderLeadCanExhaustWindow() throws {
        let request = try PlanningRequest(title: "Work", duration: 30, earliestMinute: 780, latestMinute: 810)
        XCTAssertThrowsError(try Planner.propose(request, day: day, snapshot: ScheduleSnapshot(busy: []), calendar: calendar, now: at(13))) {
            XCTAssertEqual($0 as? RehearsalError, .noSlot)
        }
    }
    func testReminderAdjustmentStillAvoidsBusyIntervals() throws {
        let request = try PlanningRequest(title: "Work", duration: 30)
        let snapshot = ScheduleSnapshot(busy: [BusyInterval(start: at(13, 10), end: at(14))])
        let p = try Planner.propose(request, day: day, snapshot: snapshot, calendar: calendar, now: at(13))
        XCTAssertEqual(p.start, at(14))
        XCTAssertEqual(p.reminderAt, at(13, 45))
    }
    func testScheduleToolScopeIncludesOnlyOverlappingDay() throws {
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
        let previousDay = calendar.date(byAdding: .day, value: -1, to: day)!
        let crossing = BusyInterval(start: previousDay.addingTimeInterval(23 * 3600), end: at(1))
        let current = BusyInterval(start: at(14), end: at(15))
        let snapshot = ScheduleSnapshot(busy: [
            BusyInterval(start: nextDay, end: nextDay.addingTimeInterval(3600)),
            BusyInterval(start: previousDay, end: day),
            BusyInterval(start: at(15), end: at(14)), current, crossing
        ])
        XCTAssertEqual(snapshot.busy(on: day, calendar: calendar), [crossing, current])
    }
    func testDecodedTitleIsNormalizedBeforePreview() throws {
        let raw = Data(#"{"title":"  Work  ","duration":30,"earliestMinute":780,"latestMinute":1020,"reminderLead":15}"#.utf8)
        let request = try JSONDecoder().decode(PlanningRequest.self, from: raw)
        let p = try Planner.propose(request, day: day, snapshot: ScheduleSnapshot(busy: []), calendar: calendar, now: day)
        XCTAssertEqual(p.title, "Work")
    }
    func testCustomWindowAndReminder() throws {
        let request = try PlanningRequest(title: "Read", duration: 45, earliestMinute: 540, latestMinute: 660, reminderLead: 5)
        let p = try Planner.propose(request, day: day, snapshot: ScheduleSnapshot(busy: []), calendar: calendar, now: day)
        XCTAssertEqual(p.start, at(9)); XCTAssertEqual(p.end, at(9, 45))
        XCTAssertEqual(p.reminderAt, at(8, 55))
    }
    func testCannotExecuteWithoutApproval() async throws {
        let (journal, p) = try await setup()
        do { _ = try await journal.execute(p.id); XCTFail("Expected approval gate") }
        catch { XCTAssertEqual(error as? RehearsalError, .notApproved) }
        let effects = await journal.effectCount(); XCTAssertEqual(effects, 0)
    }
    func testApprovalDoesNotExecute() async throws {
        let (journal, p) = try await setup()
        try await journal.approve(p.id)
        let effects = await journal.effectCount(); XCTAssertEqual(effects, 0)
    }
    func testCompletedRetryDoesNotDuplicate() async throws {
        let (journal, p) = try await setup()
        try await journal.approve(p.id)
        let first = try await journal.execute(p.id)
        let second = try await journal.execute(p.id)
        XCTAssertEqual(first, second)
        let effects = await journal.effectCount(); XCTAssertEqual(effects, 2)
    }
    func testPartialWriteRecovery() async throws {
        let (journal, p) = try await setup()
        try await journal.approve(p.id)
        do { _ = try await journal.execute(p.id, fault: .reminderFailure); XCTFail("Expected simulated failure") }
        catch { XCTAssertEqual(error as? RehearsalError, .injectedFailure) }
        let partial = await journal.proposals(); XCTAssertEqual(partial[0].state, .partial)
        let count = await journal.effectCount(); XCTAssertEqual(count, 1)
        let done = try await journal.execute(p.id); XCTAssertEqual(done.state, .completed)
        let effects = await journal.effectCount(); XCTAssertEqual(effects, 2)
    }
    func testStaleBeforeApproval() async throws {
        let (journal, p) = try await setup()
        try await journal.addConflict(BusyInterval(start: p.start, end: p.end))
        do { try await journal.approve(p.id); XCTFail("Expected stale preview") }
        catch { XCTAssertEqual(error as? RehearsalError, .staleProposal) }
    }
    func testStaleAfterApprovalBlocksWrites() async throws {
        let (journal, p) = try await setup()
        try await journal.approve(p.id)
        try await journal.addConflict(BusyInterval(start: p.start, end: p.end))
        do { _ = try await journal.execute(p.id); XCTFail("Expected stale approval") }
        catch { XCTAssertEqual(error as? RehearsalError, .staleProposal) }
        let effects = await journal.effectCount(); XCTAssertEqual(effects, 0)
    }
    func testExpiredApprovalBlocksWrites() async throws {
        let (journal, p) = try await setup()
        try await journal.approve(p.id)
        do { _ = try await journal.execute(p.id, now: p.start); XCTFail("Expected expiration") }
        catch { XCTAssertEqual(error as? RehearsalError, .expiredProposal) }
        let effects = await journal.effectCount(); XCTAssertEqual(effects, 0)
    }
    func testCancelledProposalCannotExecute() async throws {
        let (journal, p) = try await setup()
        try await journal.approve(p.id); try await journal.cancel(p.id)
        do { _ = try await journal.execute(p.id); XCTFail("Expected cancellation") }
        catch { XCTAssertEqual(error as? RehearsalError, .cancelled) }
    }
    func testDuplicateStageRejected() async throws {
        let (journal, p) = try await setup()
        do { try await journal.stage(p); XCTFail("Expected duplicate stage rejection") }
        catch { XCTAssertEqual(error as? RehearsalError, .invalidRequest) }
    }
    func testMissingProposalRejected() async throws {
        let (journal, _) = try await setup()
        do { try await journal.approve(UUID()); XCTFail("Expected missing proposal") }
        catch { XCTAssertEqual(error as? RehearsalError, .missingProposal) }
    }
    func testConcurrentRetriesAreSerialized() async throws {
        let (journal, p) = try await setup()
        try await journal.approve(p.id)
        async let first = journal.execute(p.id)
        async let second = journal.execute(p.id)
        let results = try await [first, second]
        XCTAssertEqual(results[0], results[1])
        let effects = await journal.effectCount(); XCTAssertEqual(effects, 2)
    }
    func testRestartReconcilesWriteWithoutReceipt() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("journal.json")
        let journal = try RehearsalJournal(url: url, initial: DemoSchedule.snapshot(day: day, calendar: calendar))
        let p = try proposal(await journal.snapshot())
        try await journal.stage(p); try await journal.approve(p.id)
        do { _ = try await journal.execute(p.id, fault: .interruptionAfterEventWrite); XCTFail("Expected interruption") }
        catch { XCTAssertEqual(error as? RehearsalError, .interrupted) }
        let restarted = try RehearsalJournal(url: url, initial: ScheduleSnapshot(busy: []))
        let recovered = try await restarted.execute(p.id)
        XCTAssertEqual(recovered.state, .completed)
        let effects = await restarted.effectCount(); XCTAssertEqual(effects, 2)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }
    func testCorruptJournalFailsClosed() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not json".utf8).write(to: url)
        XCTAssertThrowsError(try RehearsalJournal(url: url, initial: ScheduleSnapshot(busy: [])))
    }
    func testPersistenceFailureDoesNotChangeMemory() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data().write(to: file)
        let journal = try RehearsalJournal(url: file.appendingPathComponent("journal.json"), initial: ScheduleSnapshot(busy: []))
        let p = try proposal(await journal.snapshot())
        do { try await journal.stage(p); XCTFail("Expected write failure") } catch { }
        let proposals = await journal.proposals(); XCTAssertTrue(proposals.isEmpty)
    }
    func testSpringDSTUsesWallClockWindow() throws {
        let dstDay = calendar.date(from: DateComponents(year: 2030, month: 3, day: 10))!
        let request = try PlanningRequest(title: "Work", duration: 60, earliestMinute: 780, latestMinute: 840)
        let p = try Planner.propose(request, day: dstDay, snapshot: ScheduleSnapshot(busy: []), calendar: calendar, now: dstDay)
        XCTAssertEqual(calendar.component(.hour, from: p.start), 13)
        XCTAssertEqual(calendar.component(.hour, from: p.end), 14)
    }
}
