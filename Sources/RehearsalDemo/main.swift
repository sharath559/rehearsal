import Foundation
import RehearsalCore

@main
struct Demo {
    static func main() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let day = calendar.date(from: DateComponents(year: 2030, month: 6, day: 10))!
        let journal = try RehearsalJournal(initial: DemoSchedule.snapshot(day: day, calendar: calendar))
        let request = try PlanningRequest(title: "Interview preparation", duration: 90)
        let proposal = try Planner.propose(request, day: day, snapshot: await journal.snapshot(),
                                           calendar: calendar, now: day)
        try await journal.stage(proposal)
        let formatter = DateFormatter()
        formatter.timeZone = calendar.timeZone; formatter.dateFormat = "HH:mm z"
        print("REHEARSAL · deterministic sandbox · no model inference")
        print("Preview: \(proposal.title), \(formatter.string(from: proposal.start))–\(formatter.string(from: proposal.end))")
        print("Busy: lunch 12–13, appointment 14–15. Earliest fitting slot: 15:00.")
        do {
            _ = try await journal.execute(proposal.id)
            fatalError("Execution without approval must fail")
        } catch RehearsalError.notApproved { print("PASS: unapproved execution blocked") }
        // This CLI explicitly simulates consent; only the native UI provides interactive approval.
        try await journal.approve(proposal.id)
        print("Demo harness simulates approval of this exact proposal.")
        do { _ = try await journal.execute(proposal.id, fault: .interruptionAfterEventWrite) }
        catch RehearsalError.interrupted { print("Injected interruption: event written, receipt not yet saved") }
        let recovered = try await journal.execute(proposal.id)
        _ = try await journal.execute(proposal.id)
        let effects = await journal.effectCount()
        guard recovered.state == .completed, effects == 2 else { fatalError("Recovery failed") }
        print("PASS: recovered and retried; exactly \(effects) sandbox effects (one event, one reminder)")
        print("No system calendar or reminder was changed.")
    }
}
