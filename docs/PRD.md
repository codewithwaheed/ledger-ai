# Ledger — Personal Budgeting for iOS
## Product Requirements & Architecture

**Version:** 0.2 (scaffold delivered) · **Date:** 16 Sep 2026
**Owner:** you · **Target:** iOS 26+ (AI features require iOS 27 + Apple Intelligence device)
**Distribution:** personal (Xcode sideload, free developer account); optional friends via AltStore/Sideloadly

> Working name is "Ledger". Rename whenever.

---

## 1. Problem & goals

Tracking spending manually dies within two weeks. Banks in Pakistan already push an SMS for most transactions, and every bank issues a PDF statement. The app should turn those two existing streams into a categorized ledger with as close to zero daily input as iOS allows.

**Goals**
1. Capture 90%+ of transactions automatically (SMS + statement import).
2. Manual entry for the rest takes under 10 seconds.
3. Every transaction gets a category, learned from your corrections.
4. A monthly view answers "where did the money go" in one screen.
5. All data and all AI processing stay on the phone.

**Non-goals for v1:** email ingestion, bank APIs, multi-user, App Store release, Android, cloud sync.

---

## 2. Platform constraints (drive the design)

| Constraint | Consequence |
|---|---|
| iOS apps cannot read SMS | Ingestion goes through Shortcuts Personal Automation → App Intent |
| App cannot create/edit Shortcuts automations | App stores trusted sender IDs and shows a guided setup; user creates one automation per sender |
| Free developer account | No CloudKit, no push, no TestFlight; 7-day re-sign; local storage + manual backup |
| Foundation Models needs Apple Intelligence device + iOS 27 | AI features are optional; regex parsers are the primary path, LLM is fallback + categorizer |
| Each bank formats SMS and PDFs differently | Parsers are per-sender templates, user-editable, not hardcoded |

---

## 3. Feature PRDs

Each feature: **Priority** (P0 = v1 must, P1 = v1 nice, P2 = later), **User stories**, **Requirements**, **Acceptance criteria**, **Open questions**.

### F1. Accounts — P0

**Stories**
- I can add my bank accounts, cards, wallets (JazzCash/Easypaisa), and cash.
- Each account shows its current balance and recent transactions.

**Requirements**
- Fields: name, type (bank / credit card / wallet / cash), currency (default PKR), opening balance, color, last-4 digits (optional, used to match SMS/statements to the account), linked sender IDs.
- Balance = opening balance + sum of transactions. If a bank SMS reports an available balance, store it as `reportedBalance` and show a discrepancy badge when it drifts from computed balance by more than a threshold.
- Archive (not delete) accounts with history.

**Acceptance**
- Create 3 accounts, add transactions, balances match hand calculation.
- Archived account hidden from pickers but its transactions still appear in reports.

---

### F2. Transactions & manual entry — P0

**Stories**
- I can add income or expense in under 10 seconds.
- I can edit anything the parser got wrong.
- I can see every transaction in a searchable, filterable list.

**Requirements**
- Fields: amount, type (expense / income / transfer), account, date-time, merchant/payee, category, subcategory (optional), note, tags, source (`manual`, `sms`, `pdf`, `ai`), `sourceRef` (raw SMS text or statement line, kept for audit), `isReviewed`.
- Transfer type debits one account and credits another as a single record (no double counting in reports).
- Quick-add sheet: amount keypad first, then account and category chips. Recently used categories float to the top.
- List: grouped by day, search across merchant/note, filters by account/category/type/date range/source/unreviewed.
- Swipe actions: change category, mark reviewed, delete.
- Bulk select → recategorize.

**Acceptance**
- Quick-add an expense: 3 taps + amount.
- A transfer of 5,000 between two accounts changes both balances and does not appear as expense or income in reports.

---

### F3. SMS ingestion via Shortcuts — P0

**Stories**
- When my bank texts me, the transaction appears in the app within seconds with no action from me.
- I can tell the app exactly which sender IDs to trust (e.g. `9220`) and it ignores everything else.
- Adding a new bank is a short guided process.

**Requirements**
- **Trusted senders**: a list in Settings. Each entry: sender ID (`9220`, `8558`, alphanumeric like `HBL`), display name, linked account (optional default), parser template. User adds/edits/deletes.
- **App Intent** `IngestBankMessage(sender: String, body: String, receivedAt: Date?)`. Runs in-process, no UI required, can run in background.
- Intent behavior:
  1. Reject if `sender` not in trusted list (log to an "Ignored" counter, do not store body).
  2. Run the sender's parser template. On success, create transaction with `source = sms`, `isReviewed = false`.
  3. On parser failure, and if Foundation Models is available, try LLM extraction (see F7). If that also fails, store as **Unparsed inbox** item with raw text so the user can convert it manually or fix the template.
  4. Deduplicate: skip if an existing transaction matches amount + account + timestamp within ±2 min, or has an identical `sourceRef` hash.
- **Guided setup screen** per sender: step-by-step with screenshots — open Shortcuts → Automation → Message → Sender = `9220` → Run Immediately → action "Ingest Bank Message" with Shortcut Input as body and sender. Provide a "Copy sender ID" button and an "Open Shortcuts" deep link.
- **Test mode**: paste an SMS into the app to test a template without waiting for a real message.
- Local notification on ingest: "Rs 1,250 at Foodpanda — tap to categorize" (local notifications work on free account).

**Parser templates**
- Stored as a small JSON: a regex with named groups `amount`, `type`, `merchant`, `account_last4`, `balance`, `datetime`, plus keyword lists mapping to debit/credit ("debited", "withdrawn", "purchase" → expense; "credited", "received" → income).
- Ship with templates for your banks once you provide 5–10 sample messages each. Ship a **generic PK template** that handles common patterns (`Rs.`, `PKR`, `Rs`, comma amounts, `A/C ****1234`).
- Templates editable in-app (advanced) with live preview against sample messages.

**Acceptance**
- Real SMS from a trusted sender creates a transaction in under 5 seconds with correct amount, type, and account.
- SMS from an untrusted sender is never stored.
- Same SMS delivered twice creates one transaction.

**Open questions**
- Do your banks include the available balance in the SMS? (enables reconciliation)
- Any sender that mixes OTPs and transactions on the same ID? (needs a "contains" filter in the automation or template rejection rule)

---

### F4. PDF statement import — P0

**Stories**
- I can import a bank statement PDF and every line becomes a transaction.
- Lines I already have from SMS are not duplicated.
- The bank that sends no SMS is fully covered by monthly imports.

**Requirements**
- Import via Files picker and Share Sheet ("Open in Ledger").
- Pipeline: PDFKit text extraction → detect bank by header text → run that bank's statement parser → if extraction yields no text (scanned), run Vision OCR on rendered pages → same parser.
- Statement parser template: column detection (date, description, debit, credit, balance), date format, page header/footer skip rules. Per-bank templates; generic fallback attempts column inference.
- **Review screen before commit**: table of detected rows, each row marked New / Duplicate (with the matched transaction) / Needs attention. User can toggle rows, fix an amount, pick account. Commit creates transactions with `source = pdf`.
- Dedup against existing: same account, same amount, date within ±1 day, and fuzzy description match; or exact match against `reportedBalance` sequence when available.
- Store an `ImportBatch` record (file name, bank, date range, row counts) so an import can be undone in one tap.
- Password-protected PDFs: prompt for password, never store it.

**Acceptance**
- Import a statement covering a month where SMS already captured 80%: review screen shows those as Duplicate, only the rest are New.
- Undo import removes exactly the transactions it created.

**Open questions**
- Are your statements digital-text PDFs or scanned images? (send one with numbers masked)

---

### F5. Categories & rules — P0

**Stories**
- Every transaction lands in a sensible category without me touching it, most of the time.
- When I correct one, the app learns.

**Requirements**
- Default category tree for PK context: Food & Dining (Groceries, Restaurants, Delivery, Snacks), Transport (Fuel, Ride-hailing, Public), Bills & Utilities (Electricity, Gas, Internet, Mobile), Shopping, Health, Education, Rent, Family & Gifts, Charity/Zakat, Entertainment, Subscriptions, Fees & Charges, Salary, Business Income, Transfers, Uncategorized. Fully editable.
- **Rules engine**: ordered list of rules `if merchant contains "foodpanda" → Food & Dining / Delivery`. Rules match on merchant, note, amount range, account, sender.
- **Learning**: when the user recategorizes a transaction, offer "Always categorize [merchant] as X" → creates a rule. Silent auto-creation after the same correction twice.
- Subcategories are optional in v1 UI but exist in the model (so "which type of food" works later without migration).
- Uncategorized count shown as a badge; "Review" screen lists them for rapid triage with category chips.

**Acceptance**
- After categorizing "foodpanda" once and accepting the rule, the next foodpanda SMS auto-categorizes.

---

### F6. Dashboard & reports — P0

**Stories**
- One screen tells me this month's income, spending, and where it went.
- I can compare months and drill into a category.

**Requirements**
- Month selector (swipe). Cards: total income, total expense, net, per-account balances.
- Donut/bar of expense by category (Swift Charts); tap a slice → filtered transaction list.
- Trend: last 6 months income vs expense.
- Top merchants this month.
- Exclude transfers; toggle to include/exclude specific categories (e.g. Rent) from the breakdown.

**Acceptance**
- Numbers on dashboard equal the sum of the filtered transaction list for the same month.

---

### F7. On-device AI — P1

**Stories**
- When a message doesn't match a template, the app still understands it.
- Once a month I get a plain-language summary of my spending.

**Requirements**
- Foundation Models framework, `SystemLanguageModel` availability check; every AI feature degrades gracefully when unavailable.
- **Extraction**: `@Generable struct ParsedTransaction { amount, isDebit, merchant, accountLast4?, balance? }` from raw SMS or statement line. Result flagged `source = ai`, always `isReviewed = false`.
- **Categorization**: for merchants with no rule match, ask the model to pick from the user's category list (constrained to existing names). Confidence shown; low confidence → Uncategorized.
- **Monthly summary**: prompt receives aggregated numbers only (category totals, deltas vs last month, top merchants), never raw transactions, returns 4–6 sentences. Cached per month.
- **Template drafting** (stretch): paste 3 sample SMS → model proposes a regex template → user tests and saves.
- No network calls. No third-party model providers in v1.

**Acceptance**
- With Apple Intelligence off, app fully works and AI entries in Settings show "Unavailable on this device".

---

### F8. Budgets & recurring — P1

- Monthly budget per category with progress bar and a local notification at 80% and 100%.
- Recurring detection: same merchant, similar amount, ~monthly cadence → suggest marking as recurring; recurring list shows upcoming expected charges.

### F9. Backup, export, privacy — P0

- Export all data as JSON and CSV to Files.
- Encrypted backup file (AES, passphrase) to Files; restore on a fresh install.
- Optional Face ID lock on app open.
- Privacy screen in Settings: what is stored (everything, locally), what leaves the device (nothing).
- Raw SMS bodies (`sourceRef`) can be purged after N days via a setting.

### F10. Setup & onboarding — P0

- First run: create accounts → add trusted senders → guided Shortcuts setup → paste a test SMS → done.
- Health check screen: last SMS received per sender, automation "last fired" timestamp, unparsed inbox count.

### Deferred (P2)
- Gmail/IMAP ingestion, bank aggregator APIs, iCloud sync (paid account), shared household ledger, widgets & Live Activities, Apple Watch quick-add, receipt photo OCR.

---

## 4. Architecture

### 4.1 Stack
- **Language/UI:** Swift 6, SwiftUI, iOS 26 deployment target
- **Persistence:** SwiftData (local store; schema designed for later CloudKit mirroring)
- **Ingestion bridge:** App Intents (`IngestBankMessage`), Shortcuts Personal Automations
- **Documents:** PDFKit (text), Vision (`VNRecognizeTextRequest` for scanned pages)
- **AI:** Foundation Models (`LanguageModelSession`, `@Generable`), availability-gated
- **Charts:** Swift Charts
- **Notifications:** UserNotifications (local only)
- **Security:** CryptoKit for backup encryption, LocalAuthentication for Face ID
- **Testing:** Swift Testing; parser tests run against a fixture corpus of sample SMS/statement lines
- **Project generation:** XcodeGen (`project.yml`) so the project is reproducible from the repo

### 4.2 Modules (Swift packages inside the workspace)

```
Ledger/
├── App/                    SwiftUI app target, scenes, navigation, DI wiring
├── Packages/
│   ├── LedgerCore/         Domain models, SwiftData schema, repositories, rules engine, dedup
│   ├── LedgerParsing/      SMS templates, statement templates, regex engine, PK generic parsers
│   ├── LedgerImport/       PDF pipeline (PDFKit → OCR fallback → parser → review model)
│   ├── LedgerIntents/      App Intents + Shortcuts setup content
│   ├── LedgerAI/           Foundation Models wrappers, @Generable types, prompts, availability
│   ├── LedgerReports/      Aggregation queries, chart view models
│   └── LedgerUI/           Shared components, design tokens, formatters (PKR)
└── Fixtures/               Sample SMS (masked), statement snippets, expected parse results
```

Dependency direction: `App → everything`; `LedgerIntents/Import/AI → Parsing → Core`; `Core` depends on nothing internal.

### 4.3 Data model (SwiftData)

```
Account        id, name, type, currency, openingBalance, colorHex, last4?, isArchived, createdAt
Transaction    id, amount(Decimal), type(expense|income|transfer), date, merchant, note,
               tags[String], source(manual|sms|pdf|ai), sourceRef?, sourceHash?, isReviewed,
               reportedBalance?, account→Account, toAccount→Account?, category→Category?,
               importBatch→ImportBatch?
Category       id, name, icon, colorHex, parent→Category?, sortOrder, isSystem
Rule           id, priority, field(merchant|note|sender|amount), op(contains|equals|regex|between),
               value, category→Category, isEnabled, hitCount, createdBy(user|learned)
TrustedSender  id, senderID, displayName, defaultAccount→Account?, template→SmsTemplate,
               lastReceivedAt?, receivedCount
SmsTemplate    id, name, regex, debitKeywords[], creditKeywords[], dateFormat?, sampleMessages[]
StatementTemplate  id, bankName, detectHeaderRegex, columnSpec(JSON), dateFormat, skipRules(JSON)
ImportBatch    id, fileName, bank, importedAt, dateRange, newCount, dupCount
UnparsedItem   id, sender, body, receivedAt, attempts, status(open|converted|dismissed)
Budget         id, category→Category, monthlyLimit, startMonth
```

### 4.4 Key flows

**SMS →** Shortcuts automation fires on message from sender → runs `IngestBankMessage` with `Shortcut Input.Content` and `.Sender` → intent: trusted-sender check → template parse → (AI fallback) → dedup → save → rules engine assigns category → local notification.

**PDF →** file picked → `PDFDocument` text per page → bank detection → statement template → rows → dedup pass produces `New/Duplicate/Attention` → user review → commit as `ImportBatch`.

**Categorize →** on save: rules in priority order → first hit wins → else AI suggestion (if available, confidence ≥ threshold) → else Uncategorized. On user correction: prompt to create rule.

### 4.5 Security & privacy
- Everything in the app sandbox; SwiftData store protected by iOS data protection (complete-until-first-unlock).
- Raw SMS retained only for audit and template debugging; purge setting.
- No analytics, no network. `NSAppTransportSecurity` left default; no URL sessions in v1 code at all (easy to audit).

### 4.6 Distribution
- **You:** Xcode → Run on device. Free account: re-sign every 7 days, max 3 sideloaded apps. Add `Ledger` to Settings → General → VPN & Device Management → trust.
- **Friends (optional):** AltStore or Sideloadly with their own Apple ID; same 7-day limit. Provide an `.ipa` build script.
- **Later:** paid account unlocks TestFlight (90-day builds, 100 internal / 10,000 external testers) and iCloud sync.

---

## 5. Delivery plan

| Sprint | Scope | Done when |
|---|---|---|
| 0 (this week) | Approve PRD; collect 5–10 masked SMS per sender + one masked statement PDF per bank | Fixtures folder populated |
| 1 | Project scaffold, SwiftData models, Accounts, manual Transactions, list + quick-add, Dashboard v0 | App runs on your phone, you can log a day manually |
| 2 | `IngestBankMessage` intent, trusted senders, parser templates for your banks, guided Shortcuts setup, test-paste mode, notifications | A real bank SMS appears as a transaction hands-free |
| 3 | PDF import pipeline, statement templates, review screen, dedup, undo | Month-end statement import adds only the missing transactions |
| 4 | Rules engine + learning, review queue, charts, backup/export, Face ID | You stop touching most transactions |
| 5 | Foundation Models: fallback extraction, categorization, monthly summary | Unknown SMS still parse; summary reads correctly |
| 6 | Budgets, recurring detection, polish, `.ipa` script for friends | Stable daily use for two weeks |

---

## 6. Risks

| Risk | Mitigation |
|---|---|
| Shortcuts automation silently stops firing (iOS update, Focus mode) | Health-check screen showing last-fired per sender; weekly local reminder if a sender goes quiet |
| Bank changes SMS format | Unparsed inbox catches it; template editor + AI fallback; template test-paste |
| Small on-device model misreads amounts | AI output never bypasses review; regex is primary; amounts cross-checked against SMS balance when present |
| 7-day re-sign is annoying | Keep Mac nearby; script `xcodebuild` + `ios-deploy`; budget $99 later |
| Data loss on device loss | Encrypted backup to Files/iCloud Drive, reminder every 2 weeks |
| Scanned statements OCR poorly | Review screen mandatory; per-bank column hints; manual fix per row |

---

## 7. Decisions locked (16 Sep 2026)

- Banks: Standard Chartered (SMS sender `9220`, account ····5801, debit card ····4247) and NayaPay (PDF statement only, account ····8688). Currency PKR only.
- Own-account transfers detected by counterparty last-4; SCB→NayaPay top-ups are transfers, not income.
- Free developer account: local-only storage, JSON export, no iCloud, sideload distribution.
- Sender IDs are user-configurable in-app (Trusted Senders) and mirrored in per-sender Shortcuts automations.

## 8. Original open items

1. Approve or edit the feature list and priorities above.
2. Names of your banks/wallets and their sender IDs.
3. 5–10 real SMS per sender, with account numbers and any names masked (keep amounts, keywords, and structure intact).
4. One statement PDF per bank, masked, or a screenshot of its table layout.
5. Confirm: PKR only, or multi-currency needed?
6. App name and whether you want light/dark/system theme only (no custom theming in v1).
