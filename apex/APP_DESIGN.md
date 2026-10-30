# APEX application design: Vendor Onboarding & Compliance

Specification for building the APEX application on top of the `database/` objects.
Every data change goes through a PL/SQL package; pages never update `VOM_` tables directly
except the declarative child grids marked below.

| Setting | Value |
| --- | --- |
| Application name | Vendor Onboarding & Compliance |
| Theme | Universal Theme (Redwood Light theme style) |
| Authentication | APEX Accounts for demo; Oracle IDCS / OCI IAM Identity Domains (OpenID Connect) for production |
| Parsing schema | the schema where `database/install.sql` was run |
| Minimum APEX version | 23.2 |

## Authorization schemes

All schemes are *PL/SQL Function Returning Boolean*, evaluated once per session.

| Scheme | Function body |
| --- | --- |
| `IS_ADMIN` | `return vom_security.has_role('ADMIN');` |
| `IS_PROCUREMENT` | `return vom_security.has_role('PROCUREMENT');` |
| `IS_COMPLIANCE` | `return vom_security.has_role('COMPLIANCE');` |
| `IS_FINANCE` | `return vom_security.has_role('FINANCE');` |
| `IS_APPROVER` | `return vom_security.has_role('PROCUREMENT') or vom_security.has_role('COMPLIANCE') or vom_security.has_role('FINANCE');` |

## Shared components

| Component | Definition |
| --- | --- |
| LOV `CATEGORY_LOV` | `select meaning d, code r from vom_lookups where lookup_type = 'CATEGORY' and active_yn = 'Y' order by display_seq` |
| LOV `SPEND_BAND_LOV` | same pattern, `lookup_type = 'SPEND_BAND'` |
| LOV `ROLE_LOV` | same pattern, `lookup_type = 'ROLE'` |
| LOV `DOC_TYPE_LOV` | `select doc_type_name d, doc_type_code r from vom_document_types order by 1` |
| Navigation menu | Home · Vendors · My Approvals · Document Expiry · Administration (IS_ADMIN) |
| Application item | none (state is kept in page items) |

## Pages

| # | Page | Type | Source | Authorization |
| --- | --- | --- | --- | --- |
| 1 | Home | Dashboard | Cards + charts on `VOM_VENDOR_SUMMARY_V`, `VOM_EXPIRING_DOCUMENTS_V` | any user |
| 2 | Vendors | Interactive Report | `VOM_VENDOR_SUMMARY_V` | any user |
| 3 | Vendor | Form (modal) | `VOM_VENDORS` via `vom_vendor_api` | IS_PROCUREMENT |
| 4 | Vendor 360 | Detail page | vendor, documents, risk factors, approval steps, audit timeline | any user |
| 5 | Upload Document | Form (modal) | `VOM_VENDOR_DOCUMENTS` (file browse to BLOB) | IS_PROCUREMENT |
| 6 | My Approvals | Interactive Report | `VOM_APPROVAL_INBOX_V` filtered to the user's roles | IS_APPROVER |
| 7 | Approval Decision | Form (modal) | `vom_workflow.decide` | IS_APPROVER |
| 8 | Document Expiry | Calendar + report | `VOM_EXPIRING_DOCUMENTS_V` | IS_COMPLIANCE |
| 9 | Administration | Interactive Grids | lookups, document types, risk factors, approval rules, user roles | IS_ADMIN |

### Page 1: Home
- **Cards region** "Pipeline": count per `status` from `VOM_VENDOR_SUMMARY_V`; each card links to page 2 with an `IR_STATUS` filter.
- **Chart** "Vendors by risk level": donut, `select risk_level, count(*) from vom_vendors where risk_level is not null group by risk_level`.
- **Chart** "Documents expiring (60 days)": bar by week from `VOM_EXPIRING_DOCUMENTS_V`.
- **Badge list** "Waiting for me": `count(*)` from `VOM_APPROVAL_INBOX_V` where `vom_security.has_role_yn(approver_role) = 'Y'`.

### Page 2: Vendors
- Interactive Report on `VOM_VENDOR_SUMMARY_V`.
- `risk_level` and `status` columns use HTML badges (Template Directive `{case RISK_LEVEL/}`).
- Link column to page 4. "Create Vendor" button to page 3 (IS_PROCUREMENT).

### Page 3: Vendor (modal form)
- Items: `P3_VENDOR_NAME`, `P3_COUNTRY_CODE`, `P3_CATEGORY_CODE` (CATEGORY_LOV), `P3_TAX_REGISTRATION_NO`, `P3_ANNUAL_SPEND_BAND` (SPEND_BAND_LOV), `P3_PRIMARY_CONTACT_NAME`, `P3_PRIMARY_EMAIL` (validation: e-mail format), `P3_PHONE`, `P3_WEBSITE`.
- Process "Create" (insert only):
  ```plsql
  :P3_VENDOR_ID := vom_vendor_api.create_vendor(
      p_vendor_name => :P3_VENDOR_NAME, p_country_code => :P3_COUNTRY_CODE,
      p_category_code => :P3_CATEGORY_CODE, p_primary_email => :P3_PRIMARY_EMAIL,
      p_tax_registration_no => :P3_TAX_REGISTRATION_NO, p_annual_spend_band => :P3_ANNUAL_SPEND_BAND,
      p_primary_contact_name => :P3_PRIMARY_CONTACT_NAME, p_phone => :P3_PHONE, p_website => :P3_WEBSITE);
  ```
- Close dialog, then branch to page 4.

### Page 4: Vendor 360
- **Hero region**: name, vendor number, status badge, risk score and level.
- **Documents** (Classic Report on `VOM_VENDOR_DOCUMENTS` + `VOM_DOCUMENT_TYPES`): status badge, expiry, download link (`apex_util.get_blob_file_src`), Verify / Reject buttons (IS_COMPLIANCE) calling `vom_document_mgr.verify_document` / `reject_document`.
- **Missing documents** alert: shown when `vom_document_mgr.missing_mandatory_docs(:P4_VENDOR_ID)` is not null.
- **Risk breakdown** (Chart, bar): `VOM_VENDOR_RISK` joined to `VOM_RISK_FACTORS`, with notes as tooltip, so every score is explainable.
- **Approval chain** (Timeline-style list): `VOM_APPROVAL_STEPS` ordered by `step_seq`.
- **Audit history** (Comments template): `VOM_AUDIT_LOG` for `entity_name = 'VENDOR'` and this vendor.
- Buttons:
  | Button | Condition | Process |
  | --- | --- | --- |
  | Submit for Approval | status in DRAFT, REJECTED | `vom_vendor_api.submit(:P4_VENDOR_ID);` |
  | Recalculate Risk | IS_COMPLIANCE | `vom_risk_engine.calculate(:P4_VENDOR_ID);` |
  | Suspend | status = APPROVED, IS_COMPLIANCE | `vom_vendor_api.suspend(:P4_VENDOR_ID, :P4_REASON);` |
  | Reactivate | status = SUSPENDED, IS_COMPLIANCE | `vom_vendor_api.reactivate(:P4_VENDOR_ID);` |
- Package errors (`raise_application_error -20xxx`) display as page errors through an Error Handling Function that strips the `ORA-` prefix.

### Page 5: Upload Document (modal)
- `P5_DOC_TYPE_CODE` (DOC_TYPE_LOV), `P5_FILE` (File Browse, storage *Table APEX_APPLICATION_TEMP_FILES*), `P5_ISSUED_ON`, `P5_EXPIRES_ON`.
- Process inserts into `VOM_VENDOR_DOCUMENTS` from `APEX_APPLICATION_TEMP_FILES` (`blob_content`, `filename`, `mime_type`) with `status = 'PENDING'`, `uploaded_by = :APP_USER`.
- Validation: file size up to 10 MB; MIME types PDF, PNG, JPEG.

### Page 6: My Approvals
- Interactive Report on `VOM_APPROVAL_INBOX_V where vom_security.has_role_yn(approver_role) = 'Y'`.
- `days_waiting` highlighted when over 3 days. Row link opens page 7.

### Page 7: Approval Decision (modal)
- Read-only summary: vendor, risk breakdown, documents.
- `P7_COMMENTS` (required when rejecting, enforced by the package).
- Buttons **Approve** / **Reject**: `vom_workflow.decide(:P7_STEP_ID, :REQUEST, :P7_COMMENTS);` with button names `APPROVED` and `REJECTED`.

### Page 8: Document Expiry
- Calendar region on `VOM_EXPIRING_DOCUMENTS_V` (`expires_on` as the date column, CSS class by status).
- Report below with "days_left" and vendor link.

### Page 9: Administration
- Five editable Interactive Grids (tabs): Lookups, Document Types, Risk Factors, Approval Rules, User Roles. These are the only pages with declarative DML, restricted to IS_ADMIN.

## Build order

1. Run `database/install.sql`, then optionally `database/data/02_sample_data.sql`.
2. Create the application (App Builder > Create > New Application) with pages 1, 2 and 9 from the wizard.
3. Add shared components (LOVs, authorization schemes), then pages 3 to 8 as specified.
4. Map your workspace users into `VOM_USER_ROLES` on page 9.
5. Export the application (see [README.md](README.md)) and commit it to this folder.
