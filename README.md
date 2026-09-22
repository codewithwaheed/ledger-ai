# Ledger

Personal budgeting for iOS that captures transactions from bank SMS (via Shortcuts automations) and PDF statements,
categorizes them with rules plus on-device AI, and keeps everything on the phone.

See `docs/PRD.md` for requirements and architecture. This README is the operator's manual.

## Requirements

- Mac with **Xcode 27** (iOS 27 SDK; needed for the Foundation Models features, everything else works on Xcode 26)
- iPhone on iOS 26 or later. On-device AI needs an Apple Intelligence device (iPhone 15 Pro or later) on iOS 27
- Free Apple Developer account is enough (see limits below)
- Homebrew, for `xcodegen`

## First build

```bash
scripts/bootstrap.sh          # installs xcodegen, generates Ledger.xcodeproj
open Ledger.xcodeproj
```

In Xcode: select the **Ledger** target → *Signing & Capabilities* → Team = your Personal Team. Edit `bundleIdPrefix` in
`project.yml` to something unique (`com.<yourname>`), re-run `scripts/bootstrap.sh`. Plug in the iPhone, pick it as the
run destination, press Run. On the phone: *Settings → General → VPN & Device Management → trust your developer certificate*.

### Free-account limits
- Builds expire after **7 days**; plug in and run from Xcode again to refresh. Data is kept.
- Max 3 sideloaded apps, no TestFlight, no iCloud sync, no push. Local notifications work.
- To share with a friend: `scripts/build-ipa.sh` then sideload with AltStore/Sideloadly using *their* Apple ID.

## Setting up automatic SMS capture

iOS does not let apps read SMS. Ledger receives messages through a Shortcuts **Personal Automation** that you create once per bank:

1. In Ledger: *Settings → Trusted SMS senders → +* — enter the sender ID exactly as it appears in Messages (e.g. `9220`), pick the message format (Standard Chartered), save.
2. Tap the sender → follow the 7-step guide. In short: Shortcuts → Automation → **Message** → Sender = `9220` → Run Immediately → action **Ingest Bank Message** with *Sender* = Shortcut Input › Sender and *Message Body* = Shortcut Input › Content.
3. Verify with *Settings → Test a message* (paste a real SMS; dry-run by default).

Messages from any sender not in the trusted list are dropped and never stored, even if an automation forwards them.

## Importing a statement

*Settings → Import PDF statement*, or share a PDF to Ledger from Files/Mail. Currently recognises **NayaPay** statements.
The review screen shows which rows are new vs already recorded (from SMS) and marks transfers between your own accounts
(matched on the counterparty's last-4). Imports are undoable from Settings.

To add a bank: implement `StatementParser` in `Packages/LedgerParsing/Sources/LedgerParsing/Statements/`, register it in
`StatementParserRegistry`, and drop a masked text fixture into `Fixtures/statements/`.

## Adding an SMS template

Templates are regexes with named groups (`amount`, `merchant`, `date`, `last4`, `account`, `balance`, `ref`, `channel`,
`cpLast4`) in `BuiltInTemplates.swift`. Add sample messages (masked) to `Fixtures/sms/` and a test in
`Packages/LedgerParsing/Tests`. Unmatched messages fall back to on-device AI extraction (flagged for review), then to the
Unparsed inbox.

## Layout

```
App/Ledger                 SwiftUI app: dashboard, transactions, accounts, settings, import review
Packages/LedgerCore        SwiftData models, rules engine, dedup, transfer matching, money formatting
Packages/LedgerParsing     SMS template engine + built-in templates; statement parsers
Packages/LedgerImport      PDFKit/Vision extraction, import pipeline with review + undo
Packages/LedgerIntents     App Intent called by Shortcuts, ingestion service, notifications
Packages/LedgerAI          Foundation Models wrappers (extraction, categorization, monthly summary), availability-gated
Packages/LedgerReports     Monthly aggregation and trends
Fixtures/                  Masked real-world samples used by tests
```

Run tests: select the `LedgerParsing` scheme in Xcode and press ⌘U, or `swift test` inside `Packages/LedgerParsing` on a Mac.

## Privacy

No network code exists in this app. SMS bodies are kept only as an audit trail on each transaction (`sourceRef`) and can be
inspected in the transaction detail. Export everything as JSON from Settings; there is no cloud backup in this build.
