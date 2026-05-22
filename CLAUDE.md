# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Salesforce DX project, sourceApiVersion **65.0**, single default package directory `force-app`. Scratch org config in `config/project-scratch-def.json` (org name "Demo company", Developer edition). `mcp.json` is wired to the Salesforce DX MCP server (`@salesforce/mcp`) against `DEFAULT_TARGET_ORG` with toolsets `core,orgs,metadata,data,lwc-experts,testing,code-analysis` — use those tools where available instead of shelling out to `sf` for org reads. There is no LWC under `force-app/main/default/lwc/` and no custom objects under `force-app/main/default/objects/` — those directories exist but are currently empty placeholders.

## Commands

Node tooling (run from repo root):

- `npm run lint` — ESLint over Aura + LWC JS (`**/{aura,lwc}/**/*.js`).
- `npm run test` / `npm run test:unit` — `sfdx-lwc-jest`. Add `:watch`, `:debug`, or `:coverage`. To run a single LWC test file: `npx sfdx-lwc-jest -- <path-or-pattern>`.
- `npm run prettier` / `npm run prettier:verify` — formats/verifies Apex, LWC, Aura, XML, JSON, MD, etc. Apex uses `prettier-plugin-apex`.
- Husky `pre-commit` runs `npm run precommit` → `lint-staged` (prettier on changed files, ESLint on Aura/LWC JS, and `sfdx-lwc-jest --bail --findRelatedTests --passWithNoTests` on changed LWC paths).

Salesforce CLI (org-side; this repo doesn't wrap these in npm scripts):

- Deploy source: `sf project deploy start -d force-app -o <alias>`
- Retrieve via the curated manifest: `sf project retrieve start -x manifest/package.xml -o <alias>` (manifest is wildcarded for ApexClass/Component/Page/TestSuite/Trigger, Aura, LWC, StaticResource only — extend it if retrieving other metadata types).
- Run Apex anonymously: `sf apex run -f scripts/apex/hello.apex -o <alias>`. SOQL: `sf data query -f scripts/soql/account.soql -o <alias>`.
- Run Apex tests: `sf apex run test -o <alias> -r human -w 10` (add `-n <ClassName>` for a single class).

`.forceignore` excludes `manifest/package.xml`, LWC `jsconfig.json`/`.eslintrc.json`, and `__tests__/` from source push/pull.

## Architecture

The Apex code is organized into two distinct feature suites plus a handful of small standalone classes. Knowing which suite a class belongs to is the fastest way to orient.

### 1. DataManager — Sales demo data loader

Loads the `DTC_*` static-resource CSVs (Account, Opportunity, OpportunityHistory, OpportunityLineItem, PriceBookEntry, Product2, Event, Task, Case, Telephony) into the org and refreshes related artefacts so the org looks "live today."

- `DataManager.page` (Visualforce) is the UI, driven by `DataManager_controller`. The page is a 3-step wizard (`step1`/`step2`/`step3` state) for: refresh sales data → download dataflow → download quota.
- `DataManager_controller` orchestrates jobs and tracks `*_isrunning` booleans plus job IDs. It constructs `DataManager_Quota` and `DataManager_Dataflow` for the file-download steps.
- The data-import classes (`DataManager_CleanUp`, `DataManager_Opportunity`, `DataManager_OpportunityRelated`, `DataManager_Activity`) implement `Queueable` and are chained in that order — CleanUp first, then Opportunities, then OpportunityRelated, then Activity (Events/Tasks/Telephony). Each reads its CSV via `DataManager_Utils.getCsv(...)`.
- `DataManager_Utils` is the shared helper: CSV parsing, the absolute days-difference math against the base date `2015-07-08` (CSV dates are shifted forward so close dates land near "today"), and rollback-window constants (`ROLLBACK_DAYS_ALL`, `ROLLBACK_DAYS_HALF`, etc.). Any change to date-shifting logic flows from here.
- `TestFactory` + `DataManager_TestUtils` provide fixtures for the `*Test` classes that mirror each Queueable.

### 2. EM Dataset Upload — Einstein/CRM Analytics dataset push

Uploads a CSV (`Report.csv` / `URI.csv` static resources) into a CRM Analytics dataset via `InsightsExternalData`.

- `EMDatasetUpload.page` (Visualforce) bound to `Upload_controller_EM`, which exposes `init_isrunning` / `process_isrunning` / `process_iscompleted` state and `checkIfRecentlyUploaded()` (queries `InsightsExternalData` for today's load).
- `Upload_Init_EM` creates the `InsightsExternalData` + `InsightsExternalDataPart` rows.
- `Upload_Process_EM` is the `Queueable` that flips `Action='Process'` to trigger the dataset build.
- `UploadEMUserNotFoundException` is thrown from this flow.
- `ServiceWaveConfigurationModifier` edits a `DataManager_SalesWave_WorkflowEdits.bin` static resource for the wave template (related to the same Analytics surface).

### 3. Standalone

- `changeOpportunityType` trigger (on `OpportunityLineItem`, after insert/update) sets parent `Opportunity.Type = 'Sponsor'` when the line's `Product2.Family == 'Sponsor'`.
- `ApexSecurityRest` — `@RestResource('/apexSecurityRest')` GET that demos `Security.stripInaccessible` against Contact, with custom `FunctionalException`/`SecurityException` inner classes. Note: the file has an apparent bug — `result` is declared but never assigned before `return`.
- `DisplayAccountandContact` is the `@AuraEnabled` controller for the `DisplayAccount` Aura component (the `DisplayAccountApp.app` simply hosts it).
- `MyIterable`, `QueryContact`, `CountryCodeHelper`, `DataGenerationTest` — small isolated utilities/examples.

### UI surfaces

- **Visualforce pages**: `DataManager`, `Manager_Overview`, `EMDatasetUpload`, `Opp_disco`, plus three throwaway test pages (`atutils`, `colorTest`, `typeTest`). VF component `loadinganalytics` is a shared loading spinner.
- **Aura**: `DisplayAccount` (table of accounts) and `DisplayAccountApp` (host app).
- **Static resources** carry both the demo CSV data (`DTC_*.csv`) and the page assets (`style.css`, `normalize.css`, `jscolor.js`, `atutils.js`, `upload_styles.css`, `trailhead_*.png`, `wave_template_assets/`).

## Conventions worth knowing

- ESLint config (`eslint.config.js`) applies **three** distinct rule sets keyed off file path: `**/aura/**` (recommended + locker), `**/lwc/**` (LWC recommended), `**/lwc/**/*.test.js` (LWC recommended with `@lwc/lwc/no-unexpected-wire-adapter-usages` off). Jest mocks under `**/jest-mocks/**` get a separate Node + Jest globals config.
- Apex test classes follow the `<Name>Test.cls` suffix and live alongside their subject in `force-app/main/default/classes/`.
- The DataManager suite assumes the org has a writable Document object for storing generated quota/dataflow files and assumes scratch-org defaults from `config/project-scratch-def.json`. Avoid hard-coding org-specific IDs.

## Coding Standards

- All Apex triggers MUST use a TriggerHandler pattern (one trigger per object, handler class for logic)
- Bulkify all code — never place SOQL or DML inside loops
- All Apex classes must have a corresponding test class with 85%+ coverage
- LWC components follow SLDS design system patterns
- Every LWC must have a Jest test file in __tests__ folder
- Field API names use __c suffix, relationships use __r

## Deployment Rules

- Always deploy to dev-sandbox first
- Run all tests before deploying: sf apex run test --test-level RunLocalTests
- Use: sf project deploy start --source-dir force-app --target-org dev-sandbox
- Verify deployment success before marking pipeline complete

## Security Rules

- No SOQL injection — always use bind variables
- Enforce FLS/CRUD checks in Apex using Schema.SObjectField.isAccessible()
- No hardcoded Ids or credentials anywhere

## Project Structure

- Apex classes: force-app/main/default/classes/
- LWC components: force-app/main/default/lwc/
- Objects/fields: force-app/main/default/objects/
- Flows: force-app/main/default/flows/

## Pipeline Output Files

- TDD output: docs/technical-design.docx
- Code review output: docs/review-report.json