# Technical Design Document

## ClosedWonOpportunities LWC — Closed Won Opportunity View

**Project:** PersonalDev_SFOrg  
**Author:** Akshun Kumar Singh  
**Email:** akshun.kumar.singh@accenture.com  
**Date:** 2026-06-02  
**Version:** 1.0  
**Branch / PR:** feature/closed-won-opportunities → PR #2  
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

This document describes the end-to-end technical design of the **ClosedWonOpportunities** feature — a Lightning Web Component that renders a read-only list of all Opportunity records in the `Closed Won` stage. The component displays Opportunity Name, Account Name, Amount, Opportunity Owner, and Stage for each record, giving sales managers and executives a consolidated view of closed business. The feature is backed by a dedicated Apex controller (`ClosedWonOpportunityController`) that enforces User Mode for field-level security and retrieves only `Closed Won` records. No custom objects or external integrations are required; the feature operates entirely within the standard Salesforce data model.

---

## 2. Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                     Salesforce Lightning Page                         │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │            c-closed-won-opportunities (LWC)                     │  │
│  │                                                                │  │
│  │  ┌──────────────────────────────────────────────────────────┐  │  │
│  │  │  lightning-card (title="Closed Won Opportunities")        │  │  │
│  │  │  ┌────────────────────────────────────────────────────┐  │  │  │
│  │  │  │  lightning-datatable (read-only, no inline edit)    │  │  │  │
│  │  │  │  • key-field: Id                                    │  │  │  │
│  │  │  │  • columns: Name (url), Account Name (text),        │  │  │  │
│  │  │  │             Amount (currency), Owner (text),         │  │  │  │
│  │  │  │             Stage (text)                             │  │  │  │
│  │  │  │  • hide-checkbox-column                              │  │  │  │
│  │  │  └────────────────────────────────────────────────────┘  │  │  │
│  │  │  [Empty state]  [Error state]                             │  │  │
│  │  └──────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
         │  @wire(getClosedWonOpportunities)
         ▼
┌──────────────────────────────────────────────────────────────────────┐
│       ClosedWonOpportunityController (Apex, with sharing)             │
│                                                                        │
│  getClosedWonOpportunities()  ──►  SELECT Id, Name,                   │
│                                     Account.Name, Amount,             │
│                                     Owner.Name, StageName             │
│                                   FROM Opportunity                     │
│                                   WHERE StageName = 'Closed Won'      │
│                                   WITH USER_MODE                       │
│                                   ORDER BY Name                        │
│                                   LIMIT 1000                           │
└──────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────────────┐
│              Salesforce Database (Opportunity SObject)                 │
│                 Standard object — no custom schema required            │
└──────────────────────────────────────────────────────────────────────┘
```

### Data Flow — Read Path

1. LWC mounts; `@wire(getClosedWonOpportunities)` fires automatically.
2. Apex executes `SELECT Id, Name, Account.Name, Amount, Owner.Name, StageName FROM Opportunity WHERE StageName = 'Closed Won' WITH USER_MODE ORDER BY Name LIMIT 1000`.
3. Platform cache stores the result (`cacheable=true`); wire adapter populates `this.opportunities`.
4. `lightning-datatable` renders rows in read-only mode (no inline editing).

### Data Flow — Display Path

1. Wire result data is mapped to `displayOpportunities` getter which flattens relationship fields (`Account.Name` → `AccountName`, `Owner.Name` → `OwnerName`) for datatable column binding.
2. Columns render: Name (URL navigating to Opportunity record), Account Name, Amount (formatted as currency), Owner Name, Stage.
3. Empty state renders when wire returns zero records.
4. Error state renders when wire returns an error.

---

## 3. Component Inventory

| Layer           | Artifact                             | File Path                                                       | Purpose                                           |
| --------------- | ------------------------------------ | --------------------------------------------------------------- | ------------------------------------------------- |
| LWC             | `closedWonOpportunities`             | `force-app/main/default/lwc/closedWonOpportunities/`            | Renders read-only Closed Won list                 |
| LWC Template    | `closedWonOpportunities.html`        | `lwc/closedWonOpportunities/closedWonOpportunities.html`        | Card + datatable + conditional empty/error states |
| LWC Controller  | `closedWonOpportunities.js`          | `lwc/closedWonOpportunities/closedWonOpportunities.js`          | Wire wiring, data flattening, error reduction     |
| LWC Metadata    | `closedWonOpportunities.js-meta.xml` | `lwc/closedWonOpportunities/closedWonOpportunities.js-meta.xml` | Targets: AppPage, HomePage, RecordPage, Tab       |
| LWC Jest        | `closedWonOpportunities.test.js`     | `lwc/closedWonOpportunities/__tests__/`                         | 4 Jest test cases                                 |
| Apex Controller | `ClosedWonOpportunityController`     | `force-app/main/default/classes/`                               | `getClosedWonOpportunities`                       |
| Apex Test       | `ClosedWonOpportunityControllerTest` | `force-app/main/default/classes/`                               | 4 Apex test methods                               |

---

## 4. Apex Classes — Method Signatures & Contracts

### 4.1 `ClosedWonOpportunityController`

```apex
public with sharing class ClosedWonOpportunityController
```

**Sharing Model:** `with sharing` — respects the running user's record-sharing rules.  
**Security Enforcement:** `WITH USER_MODE` (SOQL) enforces FLS and CRUD automatically at the database level. No DML operations exist in this class (read-only component).

#### Method — `getClosedWonOpportunities`

```apex
@AuraEnabled(cacheable=true)
public static List<Opportunity> getClosedWonOpportunities()
```

| Property      | Value                                                                                                                                                  |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Visibility    | `public static`                                                                                                                                        |
| Return type   | `List<Opportunity>`                                                                                                                                    |
| AuraEnabled   | `cacheable=true`                                                                                                                                       |
| Parameters    | None                                                                                                                                                   |
| SOQL          | `SELECT Id, Name, Account.Name, Amount, Owner.Name, StageName FROM Opportunity WHERE StageName = 'Closed Won' WITH USER_MODE ORDER BY Name LIMIT 1000` |
| Error surface | `System.QueryException` if running user lacks FLS on any selected field (surfaces to LWC as wire error)                                                |
| Caching       | Platform response cache; stale after next page load                                                                                                    |

**Behaviour:** Returns up to 1,000 Opportunity records with `StageName = 'Closed Won'` visible to the running user, ordered by `Name` ascending. Fields returned: `Id`, `Name`, `Account.Name`, `Amount`, `Owner.Name`, `StageName`.

---

### 4.2 `ClosedWonOpportunityControllerTest`

```apex
@isTest
private class ClosedWonOpportunityControllerTest
```

| Method                                          | Scenario Tested                                                                                                       |
| ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `getClosedWonOpportunitiesReturnsOnlyClosedWon` | Happy-path read; asserts all returned records have `StageName = 'Closed Won'` and non-Closed-Won records are excluded |
| `getClosedWonOpportunitiesReturnsCorrectFields` | Field population; asserts `Name`, `Account.Name`, `Amount`, `Owner.Name`, `StageName` are populated                   |
| `getClosedWonOpportunitiesReturnsEmptyForNone`  | Empty-set path; asserts empty list when no Closed Won records exist                                                   |
| `getClosedWonOpportunitiesOrderedByName`        | Ordering; asserts results are returned in ascending Name order                                                        |

**`@testSetup`:** Inserts 1 Account, 3 Opportunity records with `StageName = 'Closed Won'` (Closed Won A/B/C), and 1 with `StageName = 'Prospecting'` to verify filter exclusion.

---

## 5. LWC Components

### 5.1 `closedWonOpportunities`

**Master Label:** Closed Won Opportunities  
**Description:** Displays a read-only list of all Closed Won Opportunities including Name, Account Name, Amount, Owner, and Stage.  
**API Version:** 65.0

#### Public API (Properties / Events)

| Property / Event | Direction | Type | Description                                        |
| ---------------- | --------- | ---- | -------------------------------------------------- |
| _(none)_         | —         | —    | Component has no `@api` properties; self-contained |

#### Internal State

| Property        | Type                  | Initial Value        | Description                                   |
| --------------- | --------------------- | -------------------- | --------------------------------------------- |
| `columns`       | `Array`               | `COLUMNS` constant   | Datatable column config — all read-only       |
| `opportunities` | `Array or undefined`  | `undefined`          | Raw wire result data                          |
| `error`         | `Object or undefined` | `undefined`          | Wire result error                             |
| `wiredResult`   | `Object`              | (wire result holder) | Stored for potential future `refreshApex` use |

#### Computed Getters

| Getter                 | Returns   | Logic                                                                                                               |
| ---------------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `hasOpportunities`     | `Boolean` | `Array.isArray(opportunities) && opportunities.length > 0`                                                          |
| `isEmpty`              | `Boolean` | `Array.isArray(opportunities) && opportunities.length === 0`                                                        |
| `errorMessage`         | `String`  | Calls `reduceError(this.error)`                                                                                     |
| `displayOpportunities` | `Array`   | Maps `opportunities` to flatten `Account.Name` → `AccountName` and `Owner.Name` → `OwnerName` for datatable binding |

#### Wire Adapters

| Wire                               | Method                       | Handler                                                                                           |
| ---------------------------------- | ---------------------------- | ------------------------------------------------------------------------------------------------- |
| `@wire(getClosedWonOpportunities)` | `wiredOpportunities(result)` | Populates `opportunities` on data; populates `error` on failure; stores `result` in `wiredResult` |

#### Private Methods

| Method        | Signature                  | Description                                                                                     |
| ------------- | -------------------------- | ----------------------------------------------------------------------------------------------- |
| `reduceError` | `reduceError(err): String` | Extracts a human-readable error message from `err.body.message`, `err.body[]`, or `err.message` |

#### Template Conditional Rendering

```
lwc:if={hasOpportunities}       → renders lightning-datatable with displayOpportunities
lwc:elseif={error}              → renders [data-id="error"] div with errorMessage
lwc:elseif={isEmpty}            → renders [data-id="empty"] div
```

#### Column Configuration

```js
const COLUMNS = [
  {
    label: "Opportunity Name",
    fieldName: "OpportunityUrl",
    type: "url",
    typeAttributes: { label: { fieldName: "Name" }, target: "_blank" }
  },
  { label: "Account Name", fieldName: "AccountName", type: "text" },
  {
    label: "Amount",
    fieldName: "Amount",
    type: "currency",
    typeAttributes: { currencyCode: "USD", minimumFractionDigits: 2 }
  },
  { label: "Opportunity Owner", fieldName: "OwnerName", type: "text" },
  { label: "Stage", fieldName: "StageName", type: "text" }
];
```

#### Targets (js-meta.xml)

| Target                  | Notes                                |
| ----------------------- | ------------------------------------ |
| `lightning__AppPage`    | Admin-droppable on custom App pages  |
| `lightning__HomePage`   | Admin-droppable on Home pages        |
| `lightning__RecordPage` | Admin-droppable on any Record page   |
| `lightning__Tab`        | Usable as a standalone Lightning Tab |

---

## 6. Custom Objects & Fields

**No custom objects or custom fields are required.** The feature uses only standard Salesforce Opportunity fields and standard relationships:

| Object        | Field API Name | Field Type | Usage                                   |
| ------------- | -------------- | ---------- | --------------------------------------- |
| `Opportunity` | `Id`           | ID         | Row key for datatable; URL construction |
| `Opportunity` | `Name`         | Text(120)  | Display in URL column label             |
| `Opportunity` | `Account.Name` | Text(255)  | Account Name display column             |
| `Opportunity` | `Amount`       | Currency   | Amount display column                   |
| `Opportunity` | `Owner.Name`   | Text(80)   | Owner Name display column               |
| `Opportunity` | `StageName`    | Picklist   | Stage display column; WHERE filter      |

The component does not create, modify, or depend on any custom metadata, permission sets, or field sets.

---

## 7. Integration Points

### 7.1 Internal Salesforce Platform Integrations

| Integration                                                | Type           | Direction               | Details                                               |
| ---------------------------------------------------------- | -------------- | ----------------------- | ----------------------------------------------------- |
| `ClosedWonOpportunityController.getClosedWonOpportunities` | Apex Wire      | Inbound (LWC from Apex) | Wire adapter auto-calls on component mount; cacheable |
| `lightning-datatable`                                      | Base Component | Internal                | Renders data; read-only (no save event)               |
| `ShowToastEvent`                                           | Platform Event | Outbound                | Not used (read-only component; errors shown inline)   |

### 7.2 External Integrations

None. The feature is self-contained within the Salesforce platform. There are no external API calls, named credentials, or connected apps involved.

### 7.3 Platform Cache Behaviour

`getClosedWonOpportunities` is marked `cacheable=true`, which means:

- Platform caches the response per user session.
- No `refreshApex` is called (read-only component; no mutations trigger stale cache).
- Data refreshes on next component mount (e.g., navigation away and back) or page refresh.

---

## 8. Security Model

| Concern                    | Implementation                                                     | Mechanism                                                              |
| -------------------------- | ------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| Record-level sharing       | `with sharing` on `ClosedWonOpportunityController`                 | Org sharing rules applied automatically                                |
| SOQL FLS enforcement       | `WITH USER_MODE` on all SOQL                                       | Fields inaccessible to running user excluded / `QueryException` thrown |
| DML FLS + CRUD enforcement | No DML (read-only component)                                       | N/A                                                                    |
| SOQL injection             | No dynamic SOQL; stage filter is a literal string constant in Apex | N/A                                                                    |
| Hardcoded IDs              | None                                                               | Complies with Security Rule 3                                          |
| XSS                        | LWC data binding (`{errorMessage}`) auto-encodes output            | Platform-managed                                                       |

**CRUD Requirements for End Users:**

| Permission                 | Required For                                        |
| -------------------------- | --------------------------------------------------- |
| Opportunity: Read          | Viewing the list                                    |
| `Name`: Field Read         | Displaying the Name column                          |
| `Account.Name`: Field Read | Displaying the Account Name column                  |
| `Amount`: Field Read       | Displaying the Amount column                        |
| `Owner.Name`: Field Read   | Displaying the Owner column                         |
| `StageName`: Field Read    | Displaying the Stage column and applying the filter |

---

## 9. Test Strategy

### 9.1 Apex Unit Tests

**File:** `ClosedWonOpportunityControllerTest.cls`  
**Framework:** Salesforce Apex Test Framework  
**Coverage target:** 85% or above (project standard)  
**Estimated actual coverage:** ~100% (all branches covered)

| #   | Test Method                                     | Type                | Assertions                                                                         |
| --- | ----------------------------------------------- | ------------------- | ---------------------------------------------------------------------------------- |
| 1   | `getClosedWonOpportunitiesReturnsOnlyClosedWon` | Happy path + filter | All results have `StageName == 'Closed Won'`; Prospecting record is excluded       |
| 2   | `getClosedWonOpportunitiesReturnsCorrectFields` | Field population    | `Name`, `AccountId`, `Amount`, `OwnerId`, `StageName` are non-null on first result |
| 3   | `getClosedWonOpportunitiesReturnsEmptyForNone`  | Empty-set path      | `result.isEmpty()` when only non-Closed-Won records exist                          |
| 4   | `getClosedWonOpportunitiesOrderedByName`        | Ordering            | `result[0].Name` comes before `result[1].Name` alphabetically                      |

**Run command:**

```bash
sf apex run test -o PersonalDevOrg -n ClosedWonOpportunityControllerTest -r human -w 10
```

### 9.2 LWC Jest Tests

**File:** `closedWonOpportunities/__tests__/closedWonOpportunities.test.js`  
**Framework:** `sfdx-lwc-jest` with `@salesforce/sfdx-lwc-jest` wire adapter utilities  
**Mocks:** `getClosedWonOpportunities` (createApexTestWireAdapter)

| #   | Test Case                                          | Assertions                                                                                            |
| --- | -------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| 1   | Renders datatable with Closed Won opportunities    | `lightning-datatable` exists, `data.length === 2`, `keyField === 'Id'`, Account/Owner columns present |
| 2   | Renders empty-state message for zero results       | No datatable, `[data-id="empty"]` present                                                             |
| 3   | Renders wire error message when Apex fails         | `[data-id="error"]` present and contains error text                                                   |
| 4   | Flattens relationship fields for datatable binding | `displayOpportunities[0].AccountName` equals expected Account Name value                              |

**Run command:**

```bash
npm run test:unit -- closedWonOpportunities
```

### 9.3 Integration / UAT Test Scenarios

| #   | Scenario                                            | Expected Result                                                             |
| --- | --------------------------------------------------- | --------------------------------------------------------------------------- |
| 1   | Admin places component on Home page                 | Component renders list of all Closed Won Opportunities visible to that user |
| 2   | Org has Closed Won and non-Closed-Won opportunities | Only Closed Won records appear in the list                                  |
| 3   | Clicking Opportunity Name                           | Navigates to the Opportunity record detail page in a new tab                |
| 4   | Org has zero Closed Won opportunities               | Empty state message "No Closed Won Opportunities found." renders            |
| 5   | User lacks read access to Amount field              | Component shows error state; FLS enforced via USER_MODE                     |
| 6   | Org has more than 1,000 Closed Won opportunities    | First 1,000 records displayed (silent truncation — see Known Limitations)   |

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
| All lint checks passing                            | `npm run lint`      |

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
  -d force-app/main/default/lwc/closedWonOpportunities \
     force-app/main/default/classes/ClosedWonOpportunityController.cls \
     force-app/main/default/classes/ClosedWonOpportunityController.cls-meta.xml \
     force-app/main/default/classes/ClosedWonOpportunityControllerTest.cls \
     force-app/main/default/classes/ClosedWonOpportunityControllerTest.cls-meta.xml \
  -o PersonalDevOrg
```

### Step 3 — Run Apex Tests in Org

```bash
sf apex run test -o PersonalDevOrg -n ClosedWonOpportunityControllerTest -r human -w 10
```

Expected: 4/4 tests pass, 0 failures.

### Step 4 — Smoke Test in UI

1. Open `PersonalDevOrg` in the browser.
2. Setup > Lightning App Builder > create or edit a Home page.
3. Drag **Closed Won Opportunities** from the component panel onto the canvas.
4. Save and activate the page.
5. Navigate to the page as an end user; verify the datatable renders with Opportunity Name, Account Name, Amount, Owner, and Stage columns.
6. Confirm that only `Closed Won` stage records are listed.
7. Click an Opportunity Name URL; confirm navigation to the Opportunity record.

### Step 5 — Merge to Main

After successful deployment and smoke test:

```bash
git checkout main
git pull origin main
git merge feature/closed-won-opportunities --no-ff -m "Merge pull request #2: Add ClosedWonOpportunities LWC"
git push origin main
```

### Rollback Plan

If a critical defect is discovered post-merge:

```bash
# Revert the merge commit on main
git revert -m 1 <merge-commit-sha>
git push origin main
```

Then remove the deployed metadata from the org via Setup > Apex Classes (delete `ClosedWonOpportunityController` and `ClosedWonOpportunityControllerTest`) and Setup > Lightning Components (delete `closedWonOpportunities`).

---

## 11. Known Limitations & Future Enhancements

| #   | Limitation                                                                                                               | Severity | Recommended Enhancement                                                                                              |
| --- | ------------------------------------------------------------------------------------------------------------------------ | -------- | -------------------------------------------------------------------------------------------------------------------- |
| 1   | `LIMIT 1000` silently truncates results in orgs with many Closed Won records                                             | Medium   | Add server-side pagination or show a banner when `opportunities.length === 1000`                                     |
| 2   | `Amount` column uses `currencyCode: 'USD'` hardcoded; multi-currency orgs will show incorrect currency symbol            | Medium   | Use `@wire(getRecord)` on `User.DefaultCurrencyIsoCode` or pass currency as an `@api` property                       |
| 3   | Opportunity Name column links open in a new tab (`target: '_blank'`); not consistent with standard Salesforce navigation | Low      | Use `lightning/navigation` `NavigationMixin.Navigate` with `standard__recordPage` reference type                     |
| 4   | No search or filter controls — user cannot filter by Account Name, date range, or Amount                                 | Low      | Add `lightning-input` search field and client-side filtering via getter on `displayOpportunities`                    |
| 5   | `displayOpportunities` getter re-maps the array on every render cycle                                                    | Low      | Memoize via a dedicated `_displayOpportunities` backing field set only when wire data changes                        |
| 6   | `lightning__RecordPage` target has no object scope — component can be placed on any record page                          | Low      | Add `<targetConfigs>` to restrict to Opportunity record pages, or remove the target if unintended                    |
| 7   | No sorting controls — datatable is fixed ORDER BY Name                                                                   | Low      | Enable `sortable: true` on columns and implement `handleSort` with client-side sort or re-wire with dynamic ORDER BY |
