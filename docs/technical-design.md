# Technical Design — AccountClaudePopulatedBatch

## 1. Purpose
One-time / repeatable backfill that sets `Account.Claude_Populated__c = true` on every Account where the flag is currently `false`. Implemented as an Apex batch so it scales beyond synchronous DML limits across the org's full Account volume.

## 2. Scope
- **In scope**: Account records where `Claude_Populated__c = false`.
- **Out of scope**: any field other than `Claude_Populated__c`; cascading work on child objects; reverting the flag.

## 3. Design

### 3.1 Class
`AccountClaudePopulatedBatch implements Database.Batchable<sObject>, Database.Stateful`

`Database.Stateful` is required so per-chunk counters and error messages survive across `execute` invocations and reach `finish`.

### 3.2 Methods
| Method | Behavior |
|---|---|
| `start` | Returns `Database.QueryLocator` for `SELECT Id, Claude_Populated__c FROM Account WHERE Claude_Populated__c = false`. The `WHERE` filter is the cheapest way to skip already-flagged rows — no per-row branching needed in `execute`. |
| `execute` | Performs FLS/CRUD checks once per chunk, builds a minimal update list (only `Id` + the flag), and calls `Database.update(records, false)` for **partial-success** semantics — one bad row does not abort the whole chunk. |
| `finish` | Logs `successCount` / `failureCount` and any failure detail via `System.debug` at `INFO`/`ERROR` level. |

### 3.3 Error handling
- **CRUD/FLS gate**: short-circuits a chunk if the running user lacks update permission, increments `failureCount` for the entire chunk, and records a single descriptive message. Avoids hitting `DmlException` later.
- **Partial DML**: `Database.update(records, false)` is used so individual row failures (validation rules, locking, triggers) surface as `Database.SaveResult.getErrors()` and accumulate in `failureMessages`. The batch keeps running.
- **No silent swallowing**: every failure increments a counter and appends a message keyed by record `Id`.

### 3.4 Bulkification
No SOQL or DML inside the per-record loop. The single `Database.update` call handles up to the chunk size (default 200).

### 3.5 Invocation
```apex
Database.executeBatch(new AccountClaudePopulatedBatch(), 200);
```
Chunk size of 200 balances heap and DML governor headroom. Increase only if Account triggers are light.

## 4. Test strategy
`AccountClaudePopulatedBatchTest` covers:
1. **Happy path** — 10 Accounts with the flag `false` → all flagged `true`, `successCount = 10`, `failureCount = 0`.
2. **Filter correctness** — Pre-flagging half the Accounts to `true` → `start` query excludes them; only the remaining 5 are touched.

State counters (`successCount`, `failureCount`, `failureMessages`) are `@TestVisible` so assertions can read them directly off the batch instance after `Test.stopTest()` drains the queue.

Target coverage ≥ 85% per project standard.

## 5. Deployment
Deploy via:
```
sf project deploy start \
  -d force-app/main/default/classes/AccountClaudePopulatedBatch.cls \
  -d force-app/main/default/classes/AccountClaudePopulatedBatchTest.cls \
  -o <alias>
```
No layout, permission set, or profile changes required — the field's FLS is already covered by `Claude_Populated_Access`.

## 6. Operational notes
- Run once after deploy. Subsequent runs are no-ops because the `WHERE` clause excludes already-populated rows.
- If a future requirement adds a way for the flag to flip back to `false`, this batch becomes the recovery mechanism — no code change needed.

---

# Technical Design — Account List LWC

## 1. Purpose
Read-only list view of Accounts surfaced as an LWC drop-in for App, Home, Record, and Tab pages. Displays the six fields most useful for at-a-glance triage: identification, classification, vertical, contact, qualitative score, and key financial metric.

## 2. Fields shown
| Column | Field | Type | Rationale |
|---|---|---|---|
| Name | `Name` | text | Primary identifier |
| Type | `Type` | text | Customer/Prospect classification |
| Industry | `Industry` | text | Vertical segmentation |
| Phone | `Phone` | phone | Direct contact |
| Rating | `Rating` | text | Hot/Warm/Cold qualifier |
| Annual Revenue | `AnnualRevenue` | currency | Sizing signal |

Six was the target ceiling — `BillingCity`, `Website`, `NumberOfEmployees` were considered but dropped to keep the table scannable on narrow viewports.

## 3. Apex
`AccountListController.getAccounts()` — `@AuraEnabled(cacheable=true)`, `with sharing`. Single SOQL with `WITH USER_MODE` so FLS/CRUD are enforced declaratively (modern alternative to `Schema.SObjectField.isAccessible()` loops). `LIMIT 200` caps payload at one chunk; pagination/infinite scroll is deliberately out of scope for v1. `ORDER BY Name` gives a deterministic UI.

Cacheable means the client uses Lightning Data Service caching — no DML, no `@AuraEnabled(continuation=true)`.

## 4. LWC `c-account-list`
- `@wire` to `getAccounts` — auto-refreshes when the cache invalidates.
- `lightning-datatable` for the grid; column definitions are a module-level constant.
- Three mutually exclusive view states driven by `lwc:if`/`lwc:elseif`:
  1. `hasAccounts` → render datatable
  2. `error` → render `errorMessage` (with safe nested-property fallback)
  3. `isEmpty` → render "No accounts to display."
- `accountList.js-meta.xml` exposes the component on App / Home / Record / Tab pages.

## 5. Test strategy

### 5.1 Apex (`AccountListControllerTest`)
1. **Ordering** — three named accounts → assert returned in alphabetical order.
2. **Field projection** — assert each of the six fields is populated on the returned record.
3. **LIMIT enforcement** — seed 250 accounts → assert exactly 200 returned.

### 5.2 LWC Jest (`accountList.test.js`)
The Apex import is mocked via `createApexTestWireAdapter` so wire emissions are driven synchronously from the test. Cases:
1. Datatable renders with correct row count, key field, and 6 columns.
2. Empty array emission → empty-state node present, no datatable.
3. Wire error with `body.message` → error region shows that message.
4. Wire error with empty body → falls back to the generic message.

DOM elements are tagged with `data-id` attributes so selectors are stable against SLDS class changes.

## 6. Deployment
Apex + LWC ship in a single `sf project deploy start` invocation. `__tests__/` is excluded from deploy by `.forceignore`; Jest runs locally via `npm run test` / `npx sfdx-lwc-jest`.
