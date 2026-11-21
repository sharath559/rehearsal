# Validation

## Deterministic behavior

The XCTest suite covers slot selection, adjacency, overlapping intervals, decoded
input validation, stale approvals, explicit approval gates, cancellation, partial
failure, interruption and process restart, concurrent retries, corrupted journals,
write failure, private file permissions, and daylight-saving wall-clock behavior.
Expired approvals are also rejected before a new event is written.

Run `swift test` with a full Xcode installation. The CLI additionally exercises
approval rejection, interruption, recovery, and completed retries with fixed
synthetic dates. Neither path measures Apple model quality.

The development environment is macOS 13.7.8 / Intel / Swift 5.8.1 with Command Line
Tools only. SwiftPM cannot resolve its SDK platform path there. The direct compiler
script offers a core/demo check without full Xcode. GitHub Actions is configured
to build and test using a modern Xcode SDK and to compile the Apple integration.
Consult the actual workflow run for the current result rather than treating this
configuration as a passing result.

The direct compiler demo passed on the development machine: execution without
approval was blocked, an interruption was injected after the first sandbox write,
and recovery plus a repeated execution produced exactly two sandbox effects.

## Apple model evaluation: not run

`model-evaluation.json` defines six initial real-model cases. Record the complete
environment, prompt, extracted fields, model tool calls, latency, and outcome for
each run. A schema-valid result can still misunderstand the request. In particular,
test whether unsupported constraints are surfaced rather than silently discarded.

Measure extraction accuracy independently from scheduling/executor correctness.
Repeat cases across OS/model updates and language settings. Do not publish latency,
accuracy, battery, memory, or privacy-compliance figures without measurements.

Physical iPhone installation and device behavior are pending. No TestFlight or
App Store release is claimed. No real Calendar/Reminders integration exists yet.
