import SwiftUI
import RehearsalCore

@main
struct RehearsalApp: App {
    var body: some Scene { WindowGroup { RehearsalView() } }
}

@MainActor
final class RehearsalModel: ObservableObject {
    @Published var proposals: [Proposal] = []
    @Published var message = "Your system calendar stays unchanged. All writes go to a local sandbox."
    @Published var working = false
    @Published var day = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    @Published var prompt = "Find 90 minutes for interview preparation between 1 pm and 5 pm. Remind me 15 minutes before."
    @Published var duration = 90
    @Published var earliestMinute = 780
    @Published var latestMinute = 1020
    @Published var reminderLead = 15
    @Published var title = "Interview preparation"
    @Published var reminderFailure = false
    private var journal: RehearsalJournal?
    private var generation: Task<Void, Never>?
    let calendar = Calendar.current

    func load() async {
        guard journal == nil else { return }
        do {
            let base = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: true)
            journal = try RehearsalJournal(url: base.appendingPathComponent("Rehearsal/journal.json"),
                initial: DemoSchedule.snapshot(day: day, calendar: calendar))
            await refresh()
        } catch { message = error.localizedDescription }
    }

    func preview(useApple: Bool) {
        guard let journal = journal, !working else { return }
        working = true
        generation = Task {
            defer { working = false; generation = nil }
            do {
                let snapshot = await journal.snapshot()
                let request: PlanningRequest
                if useApple {
                    request = try await ApplePlanner.extract(prompt, day: day, snapshot: snapshot, calendar: calendar)
                } else {
                    request = try PlanningRequest(title: title, duration: duration,
                        earliestMinute: earliestMinute, latestMinute: latestMinute,
                        reminderLead: reminderLead)
                }
                try Task.checkCancellation()
                let proposal = try Planner.propose(request, day: day, snapshot: snapshot, calendar: calendar)
                try await journal.stage(proposal)
                message = useApple ? "Apple model interpreted the request. Review all extracted details below." : "Manual demo generated. No model inference was used."
                await refresh()
            } catch { message = error.localizedDescription }
        }
    }

    func cancelGeneration() { generation?.cancel() }

    func act(_ proposal: Proposal, action: String) async {
        guard let journal = journal, !working else { return }
        working = true
        defer { working = false }
        do {
            switch action {
            case "approve": try await journal.approve(proposal.id); message = "Approved. Execution is a separate action."
            case "cancel": try await journal.cancel(proposal.id); message = "Proposal cancelled."
            case "conflict":
                try await journal.addConflict(BusyInterval(start: proposal.start, end: proposal.end))
                message = "Simulated a schedule change. This preview now needs regeneration."
            default:
                _ = try await journal.execute(proposal.id, fault: reminderFailure ? .reminderFailure : .none)
                message = "Completed in sandbox. No system calendar changes."
            }
        } catch { message = error.localizedDescription }
        await refresh()
    }

    private func refresh() async { proposals = await journal?.proposals() ?? [] }
}

@MainActor
struct RehearsalView: View {
    @StateObject private var model = RehearsalModel()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    Image(systemName: "play.rectangle.on.rectangle.fill")
                        .font(.largeTitle).foregroundStyle(.indigo)
                    VStack(alignment: .leading) {
                        Text("Rehearsal").font(.largeTitle.bold())
                        Text("Think it through. Then take action.").foregroundStyle(.secondary)
                    }
                }
                Label("Sandbox edition · v0.1", systemImage: "checkmark.shield")
                    .font(.caption.bold()).foregroundStyle(.indigo)
                Text(ApplePlanner.availability).font(.caption).foregroundStyle(.secondary)
                GroupBox("1 · Shape your request") {
                    VStack(alignment: .leading, spacing: 12) {
                        Group {
                            DatePicker("Selected day", selection: $model.day, in: Date()..., displayedComponents: .date)
                            TextField("Focus block title", text: $model.title).textFieldStyle(.roundedBorder)
                            Stepper("\(model.duration) minutes", value: $model.duration, in: 15...240, step: 15)
                            minutePicker("Earliest start", selection: $model.earliestMinute, values: Array(stride(from: 0, to: 1440, by: 15)))
                            minutePicker("Latest finish", selection: $model.latestMinute, values: Array(stride(from: 15, through: 1440, by: 15)))
                            Stepper("Reminder: \(model.reminderLead) minutes before", value: $model.reminderLead, in: 0...60, step: 5)
                        }
                        Text("Times use \(model.calendar.timeZone.identifier). 24:00 means the end of the selected day. Planning leaves at least one minute to review before the reminder. The first run seeds lunch 12:00–13:00 and a 14:00–15:00 appointment for tomorrow. Later dates use the same journal without new seed appointments.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Preview manual demo") { model.preview(useApple: false) }
                        Divider()
                        TextEditor(text: $model.prompt).frame(height: 80)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.25)))
                        Button("Interpret with Apple Foundation Models") { model.preview(useApple: true) }
                        Text("Apple mode uses the selected day and the text request. Title, duration, window, and reminder controls above apply only to the manual demo.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(8)
                }.disabled(model.working)
                if model.working {
                    HStack { ProgressView(); Button("Cancel generation") { model.cancelGeneration() } }
                }
                Text(model.message).font(.callout).textSelection(.enabled)
                    .padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                Toggle("Simulate reminder failure", isOn: $model.reminderFailure)
                Text("Enable, execute, then disable and retry to finish without duplicating the focus block.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("2 · Review, approve, execute").font(.headline)
                ForEach(model.proposals.reversed()) { proposal in
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Text(proposal.title).font(.headline); Spacer(); Text(proposal.state.rawValue.uppercased()).font(.caption.monospaced()) }
                            Text("\(proposal.start.formatted(date: .abbreviated, time: .shortened)) – \(proposal.end.formatted(date: .omitted, time: .shortened))")
                            Text("Reminder: \(proposal.reminderAt.formatted()) · Planned in \(proposal.timeZoneIdentifier)")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Creates one sandbox focus block and one sandbox reminder.").font(.caption)
                            HStack {
                                if proposal.state == .preview {
                                    action("Approve", proposal, "approve")
                                    action("Add conflict", proposal, "conflict")
                                }
                                if [.approved, .partial, .executing].contains(proposal.state) {
                                    action(proposal.state == .approved ? "Execute" : "Retry / reconcile", proposal, "execute")
                                }
                                if [.preview, .approved].contains(proposal.state) { action("Cancel", proposal, "cancel") }
                            }
                            if let receipt = proposal.eventReceipt { Text(receipt).font(.caption2.monospaced()).textSelection(.enabled) }
                            if let receipt = proposal.reminderReceipt { Text(receipt).font(.caption2.monospaced()).textSelection(.enabled) }
                        }.padding(8)
                    }
                }.disabled(model.working)
            }.padding(28).frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 700)
        #endif
        .task { await model.load() }
    }
    private func action(_ label: String, _ proposal: Proposal, _ operation: String) -> some View {
        Button(label) { Task { await model.act(proposal, action: operation) } }
    }

    private func minutePicker(_ label: String, selection: Binding<Int>, values: [Int]) -> some View {
        Picker(label, selection: selection) {
            ForEach(values, id: \.self) { minute in
                Text(String(format: "%02d:%02d", minute / 60, minute % 60)).tag(minute)
            }
        }
    }
}
