# ACE submission notes

## Current status (be accurate in the submission)

This repository is a **reference implementation**: complete database layer, REST module, unit tests and APEX application design.
It has **not yet been deployed** to an APEX workspace, so it contains no application export or runtime screenshots.

- Suitable now as a **public reference project / technical write-up** about APEX application design.
- Suitable as a **Product Usage** contribution **after** deployment: install on apex.oracle.com or an Always Free Autonomous Database, build the pages, commit the export, and add screenshots with synthetic data.

## Suggested title

Vendor Onboarding & Compliance Management with Oracle APEX: Explainable Risk Scoring and Risk-Based Approvals

## Description (use after deployment)

> I designed and built a vendor onboarding and compliance application on Oracle APEX. Procurement teams register suppliers and upload compliance documents. A PL/SQL risk engine calculates an explainable, weighted risk score, and a configurable workflow routes each vendor through one to three sequential approvals based on that risk. A daily DBMS_SCHEDULER job tracks document expiry and sends renewal reminders through APEX_MAIL, every decision is audited, and approved vendor master data is exposed to ERP systems through a read-only ORDS REST API. Business rules live in PL/SQL packages with utPLSQL tests, and risk weights, document requirements and approval chains are maintained in the application without code changes.

## Evidence to attach (after deployment)

- Repository link
- Application export in `apex/`
- Screenshots: dashboard, vendor 360 with risk breakdown, approver inbox, document expiry calendar (synthetic data only)
- utPLSQL run output
