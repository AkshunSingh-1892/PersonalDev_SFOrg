# Technical Design Document

## OpportunityList LWC — Inline Stage Editing Feature

**Project:** PersonalDev_SFOrg  
**Author:** Akshun Kumar Singh  
**Email:** akshun.kumar.singh@accenture.com  
**Date:** 2026-06-02  
**Version:** 1.0  
**Branch / PR:** feature/opportunity-list-lwc → PR #1  
**API Version:** 65.0 (Salesforce Summer '25)

---

## Table of Contents

1. Executive Summary
2. Architecture Overview
3. Component Inventory
4. Apex Classes — Method Signatures & Contracts
5. LWC Components
6. Custom Objects & Fields
7. Integration Points
8. Security Model
9. Test Strategy
10. Deployment Plan
11. Known Limitations & Future Enhancements

---

## 1. Executive Summary

This document describes the end-to-end technical design of the **OpportunityList** feature — a Lightning Web Component that renders a paginated, inline-editable list of Opportunity records and persists `StageName` changes to the database in bulk. The feature is implemented as a single self-contained LWC (`opportunityList`) backed by an Apex controller (`OpportunityListController`) using Salesforce's User Mode enforcement model for field-level security. No custom objects or external integrations are required; the feature operates entirely within the standard Salesforce data model.

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Salesforce Lightning Page                     │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │            c-opportunity-list (LWC)                        │  │
│  │                                                           │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  lightning-card (title="Opportunities")              │  │  │
│  │  │  ┌─────────────────────────────────────────────┐    │  │  │
│  │  │  │  lightning-datatable                          │    │  │  │
│  │  │  │  • key-field: Id                              │    │  │  │
│  │  │  │  • columns: Name (read-only), StageName      │    │  │  │
│  │  │  │             (editable)                        │    │  │  │
│  │  │  │  • inline edit → onsave → handleSave()        │    │  │  │
│  │  │  └─────────────────────────────────────────────┘    │  │  │
│  │  │  [Empty state]  [Error state]                        │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
         │  @wire(getOpportunities)           │ updateOpportunities()
         ▼                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│           OpportunityListController (Apex, with sharing)         │
│                                                                   │
│  getOpportunities()  ──►  SELECT Id, Name, StageName             │
│                           FROM Opportunity WITH USER_MODE         │
│                           ORDER BY Name LIMIT 1000               │
│                                                                   │
│  updateOpportunities()  ──►  update as user [List<Opportunity>]  │
└─────────────────────────────────────────────────────────────────┘
         │                                    │
         ▼                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│              Salesforce Database (Opportunity SObject)           │
│                 Standard object — no custom schema required       │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow — Read Path

1. LWC mounts; `@wire(getOpportunities)` fires automatically.
2. Apex executes `SELECT Id, Name, StageName FROM Opportunity WITH USER_MODE ORDER BY Name LIMIT 1000`.
3. Platform cache stores the result (cacheable=true); wire adapter populates `this.opportunities`.
4. `lightning-datatable` renders rows; `StageName` column is editable.

### Data Flow — Write Path

1. User edits one or more `StageName` cells and clicks the datatable's **Save** button.
2. `handleSave(event)` collects `event.detail.draftValues` (only changed rows, each carrying `{ Id, StageName }`).
3. `updateOpportunities({ opportunities: draftValues })` is called imperatively (non-cacheable).
4. Apex executes `update as user opportunities` inside a try/catch; `DmlException` is re-thrown as `AuraHandledException`.
5. On success: `draftValues` is reset to `[]`, `refreshApex` re-fetches the wire result, a success toast fires.
6. On failure: an error toast shows the platform error message.

---

## 3. Component Inventory

| Layer           | Artifact                        | File Path                                         | Purpose                                           |
| --------------- | ------------------------------- | ------------------------------------------------- | ------------------------------------------------- |
| LWC             | `opportunityList`               | `force-app/main/default/lwc/opportunityList/`     | Renders list; handles inline edits                |
| LWC Template    | `opportunityList.html`          | `lwc/opportunityList/opportunityList.html`        | Card + datatable + conditional empty/error states |
| LWC Controller  | `opportunityList.js`            | `lwc/opportunityList/opportunityList.js`          | Wire wiring, save handler, error reduction        |
| LWC Metadata    | `opportunityList.js-meta.xml`   | `lwc/opportunityList/opportunityList.js-meta.xml` | Targets: AppPage, HomePage, RecordPage, Tab       |
| LWC Jest        | `opportunityList.test.js`       | `lwc/opportunityList/__tests__/`                  | 4 Jest test cases                                 |
| Apex Controller | `OpportunityListController`     | `force-app/main/default/classes/`                 | `getOpportunities` + `updateOpportunities`        |
| Apex Test       | `OpportunityListControllerTest` | `force-app/main/default/classes/`                 | 4 Apex test methods                               |

---

## 4. Apex Classes — Method Signatures & Contracts

### 4.1 `OpportunityListController`

```apex
public with sharing class OpportunityListController
```

**Sharing Model:** `with sharing` — respects the running user's record-sharing rules.
**Security Enforcement:** `WITH USER_MODE` (SOQL) and `as user` (DML) enforce FLS and CRUD automatically at the database level.

#### Method 1 — `getOpportunities`

```apex
@AuraEnabled(cacheable=true)
public static List<Opportunity> getOpportunities()
```

| Property      | Value                                                                                                   |
| ------------- | ------------------------------------------------------------------------------------------------------- |
| Visibility    | `public static`                                                                                         |
| Return type   | `List<Opportunity>`                                                                                     |
| AuraEnabled   | `cacheable=true`                                                                                        |
| Parameters    | None                                                                                                    |
| SOQL          | `SELECT Id, Name, StageName FROM Opportunity WITH USER_MODE ORDER BY Name LIMIT 1000`                   |
| Error surface | `System.QueryException` if running user lacks FLS on any selected field (surfaces to LWC as wire error) |
| Caching       | Platform response cache; `refreshApex` needed to invalidate after mutation                              |

**Behaviour:** Returns up to 1,000 Opportunity records visible to the running user, ordered by `Name` ascending. Fields returned: `Id`, `Name`, `StageName`.

#### Method 2 — `updateOpportunities`

```apex
@AuraEnabled
public static void updateOpportunities(List<Opportunity> opportunities)
```

| Property      | Value                                                                                 |
| ------------- | ------------------------------------------------------------------------------------- |
| Visibility    | `public static`                                                                       |
| Return type   | `void`                                                                                |
| AuraEnabled   | Non-cacheable (write operation)                                                       |
| Parameters    | `opportunities` — list of `Opportunity` records with `Id` and `StageName` set         |
| DML           | `update as user opportunities`                                                        |
| Guard         | Returns immediately if `opportunities` is `null` or empty                             |
| Error surface | Catches `DmlException`; re-throws as `AuraHandledException` with the original message |

**Behaviour:** Bulk-updates the provided Opportunity records. Enforces FLS/CRUD via `as user`. Invalid picklist values or missing permissions surface as `AuraHandledException` which the LWC error-toast handler consumes.

---

### 4.2 `OpportunityListControllerTest`

```apex
@isTest
private class OpportunityListControllerTest
```

| Method                                         | Scenario Tested                                                            |
| ---------------------------------------------- | -------------------------------------------------------------------------- |
| `getOpportunitiesReturnsAllOrderedByName`      | Happy-path read; asserts count, ordering, and StageName population         |
| `updateOpportunitiesPersistsStageChanges`      | Happy-path write; mutates 3 records to Qualification, re-queries to verify |
| `updateOpportunitiesHandlesNullAndEmptySafely` | Null guard; passes null and empty list without exception                   |
| `updateOpportunitiesThrowsOnInvalidStage`      | Error path; asserts `AuraHandledException` on invalid picklist value       |

**`@testSetup`:** Inserts 3 Opportunity records (`Test Opp 0/1/2`, `StageName='Prospecting'`, `CloseDate=today+30`).

---

## 5. LWC Components

### 5.1 `opportunityList`

**Master Label:** Opportunity List
**Description:** Lists Opportunities and allows inline editing of the Stage field.
**API Version:** 65.0

#### Public API (Properties / Events)

| Property / Event | Direction | Type | Description                                        |
| ---------------- | --------- | ---- | -------------------------------------------------- |
| _(none)_         | —         | —    | Component has no `@api` properties; self-contained |

#### Internal State

| Property        | Type                  | Initial Value        | Description                                                      |
| --------------- | --------------------- | -------------------- | ---------------------------------------------------------------- |
| `columns`       | `Array`               | `COLUMNS` constant   | Datatable column config — Name (read-only), StageName (editable) |
| `opportunities` | `Array or undefined`  | `undefined`          | Wire result data                                                 |
| `error`         | `Object or undefined` | `undefined`          | Wire result error                                                |
| `draftValues`   | `Array`               | `[]`                 | Pending inline edits; reset after save                           |
| `wiredResult`   | `Object`              | (wire result holder) | Stored for `refreshApex`                                         |

#### Computed Getters

| Getter             | Returns   | Logic                                                        |
| ------------------ | --------- | ------------------------------------------------------------ |
| `hasOpportunities` | `Boolean` | `Array.isArray(opportunities) && opportunities.length > 0`   |
| `isEmpty`          | `Boolean` | `Array.isArray(opportunities) && opportunities.length === 0` |
| `errorMessage`     | `String`  | Calls `reduceError(this.error)`                              |

#### Wire Adapters

| Wire                      | Method                       | Handler                                                                                                       |
| ------------------------- | ---------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `@wire(getOpportunities)` | `wiredOpportunities(result)` | Populates `opportunities` on data; populates `error` on failure; stores `result` in `wiredResult` for refresh |

#### Event Handlers

| Handler             | Trigger                            | Behaviour                                                                                                                     |
| ------------------- | ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `handleSave(event)` | `lightning-datatable` `save` event | Calls `updateOpportunities`; on success resets drafts + calls `refreshApex` + fires success toast; on error fires error toast |

#### Private Methods

| Method        | Signature                  | Description                                                                                     |
| ------------- | -------------------------- | ----------------------------------------------------------------------------------------------- |
| `reduceError` | `reduceError(err): String` | Extracts a human-readable error message from `err.body.message`, `err.body[]`, or `err.message` |

#### Template Conditional Rendering

```
lwc:if={hasOpportunities}       → renders lightning-datatable
lwc:elseif={error}              → renders [data-id="error"] div with errorMessage
lwc:elseif={isEmpty}            → renders [data-id="empty"] div
```

#### Column Configuration

```js
const COLUMNS = [
  { label: "Name", fieldName: "Name", type: "text", editable: false },
  { label: "Stage", fieldName: "StageName", type: "text", editable: true }
];
```

#### Targets (js-meta.xml)

| Target                  | Notes                                                                          |
| ----------------------- | ------------------------------------------------------------------------------ |
| `lightning__AppPage`    | Admin-droppable on custom App pages                                            |
| `lightning__HomePage`   | Admin-droppable on Home pages                                                  |
| `lightning__RecordPage` | Admin-droppable on any Record page (not object-scoped — see Known Limitations) |
| `lightning__Tab`        | Usable as a standalone Lightning Tab                                           |

---

## 6. Custom Objects & Fields

**No custom objects or custom fields are required.** The feature uses only standard Salesforce Opportunity fields:

| Object        | Field API Name | Field Type | Usage                                                    |
| ------------- | -------------- | ---------- | -------------------------------------------------------- |
| `Opportunity` | `Id`           | ID         | Row key for datatable; DML identifier                    |
| `Opportunity` | `Name`         | Text(120)  | Display column (read-only)                               |
| `Opportunity` | `StageName`    | Picklist   | Inline-editable column; values sourced from org picklist |

The component does not create, modify, or depend on any custom metadata, permission sets, or field sets.

---

## 7. Integration Points

### 7.1 Internal Salesforce Platform Integrations

| Integration                                     | Type            | Direction               | Details                                                             |
| ----------------------------------------------- | --------------- | ----------------------- | ------------------------------------------------------------------- |
| `OpportunityListController.getOpportunities`    | Apex Wire       | Inbound (LWC from Apex) | Wire adapter auto-calls on component mount; cacheable               |
| `OpportunityListController.updateOpportunities` | Apex Imperative | Outbound (LWC to Apex)  | Triggered on datatable save; non-cacheable                          |
| `refreshApex`                                   | Platform API    | Internal                | Invalidates `getOpportunities` wire cache after successful save     |
| `ShowToastEvent`                                | Platform Event  | Outbound                | Fires `lightning/platformShowToastEvent` for success/error feedback |
| `lightning-datatable`                           | Base Component  | Internal                | Renders data; emits `save` event with `draftValues`                 |

### 7.2 External Integrations

None. The feature is self-contained within the Salesforce platform. There are no external API calls, named credentials, or connected apps involved.

### 7.3 Platform Cache Behaviour

`getOpportunities` is marked `cacheable=true`, which means:

- Platform caches the response per user session.
- `refreshApex(this.wiredResult)` is called after every successful save to invalidate the cache and re-fetch.
- In multi-tab scenarios, a tab that has not performed a save will continue serving cached data until the wire fires again (e.g., on navigation or page refresh).

---

## 8. Security Model

| Concern                    | Implementation                                          | Mechanism                                                                  |
| -------------------------- | ------------------------------------------------------- | -------------------------------------------------------------------------- |
| Record-level sharing       | `with sharing` on `OpportunityListController`           | Org sharing rules applied automatically                                    |
| SOQL FLS enforcement       | `WITH USER_MODE` on all SOQL                            | Fields inaccessible to running user are excluded / `QueryException` thrown |
| DML FLS + CRUD enforcement | `update as user opportunities`                          | Running user's CRUD on `Opportunity.StageName` is enforced at DB level     |
| SOQL injection             | No dynamic SOQL used; all queries are static            | N/A                                                                        |
| Hardcoded IDs              | None                                                    | Complies with Security Rule 3                                              |
| XSS                        | LWC data binding (`{errorMessage}`) auto-encodes output | Platform-managed                                                           |

**CRUD Requirements for End Users:**

| Permission              | Required For                   |
| ----------------------- | ------------------------------ |
| Opportunity: Read       | Viewing the list               |
| Opportunity: Edit       | Saving inline edits            |
| `StageName`: Field Read | Displaying the Stage column    |
| `StageName`: Field Edit | Updating stage via inline edit |

---

## 9. Test Strategy

### 9.1 Apex Unit Tests

**File:** `OpportunityListControllerTest.cls`
**Framework:** Salesforce Apex Test Framework
**Coverage target:** 85% or above (project standard)
**Estimated actual coverage:** ~100% (all branches covered)

| #   | Test Method                                    | Type             | Assertions                                                                                     |
| --- | ---------------------------------------------- | ---------------- | ---------------------------------------------------------------------------------------------- |
| 1   | `getOpportunitiesReturnsAllOrderedByName`      | Happy path       | `result.size() == 3`, `result[0].Name == 'Test Opp 0'`, `result[0].StageName == 'Prospecting'` |
| 2   | `updateOpportunitiesPersistsStageChanges`      | Happy path       | All re-queried records have `StageName == 'Qualification'`                                     |
| 3   | `updateOpportunitiesHandlesNullAndEmptySafely` | Null/empty guard | No exception thrown                                                                            |
| 4   | `updateOpportunitiesThrowsOnInvalidStage`      | Error path       | `AuraHandledException` thrown for invalid picklist value                                       |

**Run command:**

```bash
sf apex run test -o PersonalDevOrg -n OpportunityListControllerTest -r human -w 10
```

### 9.2 LWC Jest Tests

**File:** `opportunityList/__tests__/opportunityList.test.js`
**Framework:** `sfdx-lwc-jest` with `@salesforce/sfdx-lwc-jest` wire adapter utilities
**Mocks:** `getOpportunities` (createApexTestWireAdapter), `updateOpportunities` (jest.fn returning Promise.resolve)

| #   | Test Case                                             | Assertions                                                                                            |
| --- | ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| 1   | Renders datatable with returned opportunities         | `lightning-datatable` exists, `data.length === 2`, `keyField === 'Id'`, `StageName.editable === true` |
| 2   | Calls `updateOpportunities` with draft values on save | `updateOpportunities` called once with `{ opportunities: draftValues }`                               |
| 3   | Renders empty-state message for zero opportunities    | No datatable, `[data-id="empty"]` present and contains correct text                                   |
| 4   | Renders wire error message when Apex fails            | `[data-id="error"]` present and contains error message text                                           |

**Run command:**

```bash
npm run test:unit -- opportunityList
```

### 9.3 Integration / UAT Test Scenarios

| #   | Scenario                                                                  | Expected Result                                                            |
| --- | ------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| 1   | Admin places component on Home page; user with Opportunity Read sees list | List renders; Save button not available for read-only users                |
| 2   | User edits StageName on 1 row and saves                                   | Row updates; success toast appears; datatable refreshes with new value     |
| 3   | User edits StageName on multiple rows and saves                           | All changed rows update in single DML call; success toast appears          |
| 4   | User types an invalid StageName and saves                                 | Error toast appears with DML error message; datatable retains draft values |
| 5   | User with no Opportunity Edit permission attempts save                    | Error toast shows FLS/CRUD error                                           |
| 6   | Org has 0 Opportunities                                                   | Empty state message "No opportunities to display." renders                 |
| 7   | Org has more than 1,000 Opportunities                                     | First 1,000 records displayed (silent truncation — see Known Limitations)  |

### 9.4 Deployment Validation Tests

Run all local tests post-deployment to validate no regressions:

```bash
sf apex run test -o PersonalDevOrg --test-level RunLocalTests -r human -w 30
```

---

## 10. Deployment Plan

### Prerequisites

| Requirement                                        | Check               |
| -------------------------------------------------- | ------------------- |
| Connected Salesforce org (alias: `PersonalDevOrg`) | `sf org list`       |
| `sf` CLI version 2.100 or above                    | `sf --version`      |
| Node.js + npm installed                            | `node --version`    |
| All Jest tests passing locally                     | `npm run test:unit` |

### Step 1 — Local Validation

```bash
npm run lint
npm run test:unit
npm run prettier:verify
```

Expected: zero errors, all tests pass.

### Step 2 — Deploy to Target Org

```bash
sf project deploy start \
  -d force-app/main/default/lwc/opportunityList \
     force-app/main/default/classes/OpportunityListController.cls \
     force-app/main/default/classes/OpportunityListController.cls-meta.xml \
     force-app/main/default/classes/OpportunityListControllerTest.cls \
     force-app/main/default/classes/OpportunityListControllerTest.cls-meta.xml \
  -o PersonalDevOrg
```

**Deploy ID (reference):** `0AfJ2000002wJwGKAU`
**Deployed:** 2026-06-02
**Status:** Succeeded — 3 components created (ApexClass x2, LightningComponentBundle x1)

### Step 3 — Run Apex Tests in Org

```bash
sf apex run test -o PersonalDevOrg -n OpportunityListControllerTest -r human -w 10
```

Expected: 4/4 tests pass, 0 failures.

### Step 4 — Smoke Test in UI

1. Open `PersonalDevOrg` in the browser.
2. Setup > Lightning App Builder > create or edit a Home page.
3. Drag **Opportunity List** from the component panel onto the canvas.
4. Save and activate the page.
5. Navigate to the page as an end user; verify the datatable renders and inline edit works end-to-end.

### Step 5 — Merge to Main

After successful deployment and smoke test:

```bash
git checkout main
git pull origin main
git merge feature/opportunity-list-lwc --no-ff -m "Merge pull request #1: Add OpportunityList LWC and Apex controller for inline stage editing"
git push origin main
```

**Status:** Completed 2026-06-02. PR #1 merged; `main` is at commit `8c18a56`.

### Rollback Plan

If a critical defect is discovered post-merge:

```bash
# Revert the merge commit on main
git revert -m 1 <merge-commit-sha>
git push origin main
```

Then remove the deployed metadata from the org via Setup > Apex Classes (delete `OpportunityListController` and `OpportunityListControllerTest`) and Setup > Lightning Components (delete `opportunityList`).

---

## 11. Known Limitations & Future Enhancements

| #   | Limitation                                                                                      | Severity | Recommended Enhancement                                                                                                              |
| --- | ----------------------------------------------------------------------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | `LIMIT 1000` silently truncates results in large orgs                                           | Medium   | Add server-side pagination with `OFFSET`/`LIMIT` `@api` properties, or show a warning banner when `opportunities.length === 1000`    |
| 2   | `StageName` column uses `type: 'text'` — allows free-form input instead of a picklist dropdown  | Medium   | Switch to `type: 'picklist'` with `typeAttributes.options` populated via `@wire(getPicklistValues)` wired to `Opportunity.StageName` |
| 3   | `lightning__RecordPage` target has no object scope — component can be placed on any record page | Low      | Add `<targetConfigs>` to restrict to Opportunity record pages, or remove the target if unintended                                    |
| 4   | Apex test assertion `result.size() == 3` breaks if org already has Opportunity records          | Low      | Change to `result.size() >= 3` or add a `WHERE Name LIKE 'Test Opp %'` filter for test isolation                                     |
| 5   | `flushPromises = () => Promise.resolve()` in Jest only flushes a single microtask tick          | Low      | Replace with `() => new Promise(resolve => setTimeout(resolve, 0))` for robust async flushing                                        |
| 6   | No columns for `CloseDate`, `Account`, or `Amount`                                              | Low      | Extend `COLUMNS` constant and SOQL to include additional display fields per business requirements                                    |
| 7   | Multi-tab stale cache — changes in one tab are not reflected in another until re-navigation     | Low      | Document the behaviour; consider removing `cacheable=true` if real-time freshness across tabs is required                            |
