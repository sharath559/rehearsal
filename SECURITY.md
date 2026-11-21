# Privacy and security

The on-device Apple model requires no API key. Do not add an Apple account password,
signing key, App Store Connect key, or other credential to source code or prompts.
App signing credentials and on-device model availability are separate concerns.

## Data flow

The manual demo makes no model or network calls. Apple mode uses only the system
on-device model; there is no server model or HTTP client in this project.
The application does not request Calendar, Reminders, Contacts, or microphone
permissions. Busy intervals come from its sandbox. No analytics SDK is included.

Native journal files contain titles, proposed dates, receipts, and sandbox busy
intervals. They are private files (0600) in Application Support, not a secret vault.
This code does not implement encryption or alter OS backup policies. No prompts
or model transcripts are persisted by the app. The system model's processing is
subject to Apple's platform behavior and availability.

## Execution boundary

The model cannot approve a proposal or call a write tool. Typed output is validated,
then shown for review. Prompt instructions are not treated as a sufficient
authorization control. Model-generated content remains untrusted even when it
matches the output schema. An approval is local UI consent, not a signed capability.

## Before publishing

`.gitignore` excludes all `.env` variants, key/certificate files, signing profiles,
runtime data, and build products. There is deliberately no `.env.example`: no
configuration secret is required. Run `python3 scripts/check_publication.py` and
inspect the staged file list before every push. The scan is a heuristic and does
not guarantee the absence of all possible secrets.

For future cloud providers, use Keychain for user credentials and GitHub Actions
Secrets for CI credentials; do not bundle a shared secret into an application.

Report security issues privately through the maintainer's GitHub profile rather
than posting credentials or personal journal content in an issue.
